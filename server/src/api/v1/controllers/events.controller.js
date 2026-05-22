/**
 * events.controller.js
 *
 * Flow when Python detects a fall/inactivity/sleeping:
 *   1. Save event + upload snapshot to MinIO
 *   2. Lookup caregiver_id from DB (single query)
 *   3. Socket.IO real-time alert  → app is open
 *   4. FCM push notification      → app is in background/closed  (non-blocking)
 *   5. Mark alert_sent = true after FCM confirms
 */

const eventsService       = require('../../../services/events.service');
const notificationService = require('../../../services/notification.service');
const socketService       = require('../../../services/socket.service');
const sosService          = require('../../../services/sos.service');
const ApiResponse         = require('../../../utils/ApiResponse');
const ApiError            = require('../../../utils/ApiError');
const asyncHandler        = require('../../../utils/asyncHandler');
const logger              = require('../../../utils/logger');
const pool                = require('../../../config/database.config');

/**
 * @route   POST /api/v1/events
 * @desc    Python AI detection sends detected event here.
 * @access  Public (Python internal — no Firebase auth required)
 */
const createEvent = asyncHandler(async (req, res) => {
  const { elderly_id, event_type, confidence, snapshot_base64, pose_data } = req.body;

  // ── Validation ─────────────────────────────────────────────
  if (!elderly_id)              throw new ApiError(400, 'elderly_id is required');
  if (!event_type)              throw new ApiError(400, 'event_type is required');
  if (confidence === undefined) throw new ApiError(400, 'confidence is required');

  if (!['fall', 'inactivity', 'sleeping', 'night_restlessness'].includes(event_type)) {
    throw new ApiError(400, 'event_type must be: fall | inactivity | sleeping | night_restlessness');
  }

  // ── 1. Save event + upload snapshot to MinIO ───────────────
  const event = await eventsService.createEvent(elderly_id, {
    event_type,
    confidence,
    snapshot_base64,
    pose_data,
  });

  // ── 2. Lookup caregiver_id (reused by both alert paths) ────
  const cgResult = await pool.query(
    `SELECT caregiver_id FROM elderly WHERE id = $1`,
    [elderly_id]
  );
  const caregiver_id = cgResult.rows[0]?.caregiver_id ?? null;

  // ── 3. Socket.IO real-time alert (instant, if app is open) ─
  if (caregiver_id) {
    const io = req.app.get('io');
    if (io) {
      socketService.emitAlert(io, caregiver_id, {
        event_id:     event.id,
        elderly_id:   event.elderly_id,
        caregiver_id,
        event_type:   event.event_type,
        confidence:   event.confidence,
        snapshot_url: event.snapshot_url,
        created_at:   event.created_at,
      });
      logger.info(`✅ Socket.IO alert → caregiver: ${caregiver_id}`);
    }
  }

  // ── 4. FCM push notification (non-blocking — Python must not wait) ──
  if (caregiver_id) {
    notificationService
      .sendEventAlert(elderly_id, event_type, confidence, event.id, event.snapshot_url)
      .then((result) => {
        if (result.success) return eventsService.markAlertSent(event.id);
      })
      .catch((err) => {
        logger.error(`FCM pipeline error (non-fatal): ${err.message}`);
      });
  }

  // ── 5. Auto-SOS on confirmed fall (non-blocking) ──────────────────────────
  // A confirmed fall from the AI automatically opens the SOS incoming-call
  // screen on the caregiver's device, identical to a manually triggered SOS.
  if (event_type === 'fall' && caregiver_id) {
    sosService.createSos(elderly_id, 'auto_fall')
      .then((sos) => {
        const io = req.app.get('io');
        if (io) {
          socketService.emitSosAlert(io, caregiver_id, {
            sos_id:       sos.id,
            elderly_id,
            elderly_name: sos.elderly_name ?? 'Elder',
            source:       'auto_fall',
            created_at:   sos.created_at,
          });
        }
        return notificationService.sendSosAlert(elderly_id, sos.id, 'auto_fall');
      })
      .catch((err) => {
        logger.error(`Auto-SOS pipeline error (non-fatal): ${err.message}`);
      });
  }

  // Respond immediately — do not make Python wait for FCM
  res.status(201).json(
    new ApiResponse(201, { event }, 'Event created — alert dispatched')
  );
});

/**
 * @route   GET /api/v1/events/:elderlyId
 * @desc    Get all events for an elderly (caregiver dashboard)
 * @access  Private (Caregiver)
 */
const getEventsByElderly = asyncHandler(async (req, res) => {
  const { elderlyId }              = req.params;
  const { limit = 20, offset = 0 } = req.query;

  const events = await eventsService.getEventsByElderly(
    elderlyId, parseInt(limit), parseInt(offset)
  );

  res.json(new ApiResponse(200, { events, count: events.length }, 'Events retrieved'));
});

/**
 * @route   GET /api/v1/events/unverified
 * @desc    Get all unverified events for the logged-in caregiver
 * @access  Private (Caregiver)
 */
const getUnverifiedEvents = asyncHandler(async (req, res) => {
  const events = await eventsService.getUnverifiedEvents(req.user.id);
  res.json(new ApiResponse(200, { events, count: events.length }, 'Unverified events retrieved'));
});

/**
 * @route   PUT /api/v1/events/:eventId/verify
 * @desc    Caregiver marks event as verified or false positive
 * @access  Private (Caregiver)
 */
const verifyEvent = asyncHandler(async (req, res) => {
  const { eventId }                   = req.params;
  const { is_false_positive = false } = req.body;

  const event = await eventsService.verifyEvent(eventId, req.user.id, is_false_positive);
  res.json(new ApiResponse(200, { event }, 'Event verified successfully'));
});

/**
 * @route   GET /api/v1/events/detail/:eventId
 * @desc    Get a single event by ID
 * @access  Private (Caregiver)
 */
const getEventById = asyncHandler(async (req, res) => {
  const event = await eventsService.getEventById(req.params.eventId);
  res.json(new ApiResponse(200, { event }, 'Event retrieved'));
});

/**
 * @route   GET /api/v1/events/notifications
 * @desc    Get combined event + SOS notifications for the logged-in caregiver
 * @access  Private (Caregiver)
 */
const getNotifications = asyncHandler(async (req, res) => {
  const caregiverId = req.user.id;
  const limit = Math.min(parseInt(req.query.limit) || 30, 50);

  const result = await pool.query(`
    SELECT 'event' AS type,
           e.id,
           e.event_type,
           ROUND(e.confidence::numeric, 2) AS confidence,
           e.snapshot_url,
           e.created_at,
           el.first_name || ' ' || el.last_name AS elderly_name,
           el.id AS elderly_id
    FROM events e
    JOIN elderly el ON el.id = e.elderly_id
    WHERE el.caregiver_id = $1 AND e.is_false_positive = false

    UNION ALL

    SELECT 'sos' AS type,
           s.id,
           CASE WHEN s.source = 'auto_fall' THEN 'auto_fall' ELSE 'sos' END AS event_type,
           1.0 AS confidence,
           NULL AS snapshot_url,
           s.created_at,
           el.first_name || ' ' || el.last_name AS elderly_name,
           el.id AS elderly_id
    FROM sos_requests s
    JOIN elderly el ON el.id = s.elderly_id
    WHERE s.caregiver_id = $1

    ORDER BY created_at DESC
    LIMIT $2
  `, [caregiverId, limit]);

  res.json(new ApiResponse(200, { notifications: result.rows }, 'Notifications retrieved'));
});

/**
 * @route   GET /api/v1/events/today-stats/:elderlyId
 * @desc    Get today's event stats for an elderly person
 * @access  Private (Caregiver)
 */
const getTodayStats = asyncHandler(async (req, res) => {
  const stats = await eventsService.getTodayStats(req.params.elderlyId);

  // Activity level string
  let activityLevel = 'Normal';
  if (stats.fall > 0)                    activityLevel = 'Alert 🚨';
  else if (stats.inactivity > 0)         activityLevel = 'Low Activity';
  else if (stats.night_restlessness > 0) activityLevel = 'Restless Night 🌙';
  else if (stats.sleeping > 0)           activityLevel = 'Sleeping 💤';

  res.json(new ApiResponse(200, { stats, activityLevel }, 'Today stats retrieved'));
});

module.exports = {
  createEvent,
  getEventsByElderly,
  getUnverifiedEvents,
  verifyEvent,
  getEventById,
  getNotifications,
  getTodayStats,
};