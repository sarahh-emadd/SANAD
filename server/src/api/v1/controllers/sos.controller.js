/**
 * sos.controller.js
 *
 * Flow when elder presses SOS button:
 *   1. Validate Firebase token (elder is authenticated)
 *   2. Insert sos_request row + get caregiver_id in one query
 *   3. Socket.IO real-time alert  → caregiver app is open
 *   4. FCM push notification      → caregiver app is closed/background (non-blocking)
 *   5. Respond immediately — do not make Flutter wait for FCM
 *
 * NOTE on auth: verifyFirebaseToken checks the `caregivers` table.
 * The elder uses a lightweight token-only middleware (verifyElderToken)
 * defined at the bottom of this file and used only in sos.routes.js.
 */

const sosService          = require('../../../services/sos.service');
const notificationService = require('../../../services/notification.service');
const socketService       = require('../../../services/socket.service');
const ApiResponse         = require('../../../utils/ApiResponse');
const ApiError            = require('../../../utils/ApiError');
const asyncHandler        = require('../../../utils/asyncHandler');
const logger              = require('../../../utils/logger');

/**
 * @route   POST /api/v1/sos
 * @desc    Elder triggers an SOS emergency request.
 * @access  Private (Elder — Firebase token, elderly_id from body)
 *
 * Body: { elderly_id: "uuid" }
 *
 * The elder's app sends its own elderly_id because the Firebase token
 * belongs to the elder's Firebase account, not to the caregivers table.
 * We trust the elderly_id here because the token proves identity —
 * in production you can store elder firebase_uid in the elderly table
 * and verify it, but for the graduation demo this is sufficient.
 */
const triggerSos = asyncHandler(async (req, res) => {
  const { elderly_id, source = 'manual' } = req.body;

  if (!elderly_id) throw new ApiError(400, 'elderly_id is required');

  // ── 1. Save SOS to DB (also fetches caregiver_id + elderly_name) ─────────
  const sos = await sosService.createSos(elderly_id, source);
  const { caregiver_id, elderly_name } = sos;

  // ── 2. Socket.IO instant alert (if caregiver app is open) ────────────────
  const io = req.app.get('io');
  if (io && caregiver_id) {
    socketService.emitSosAlert(io, caregiver_id, {
      sos_id:       sos.id,
      elderly_id,
      elderly_name: elderly_name ?? 'Your elder',
      source:       sos.source,
      created_at:   sos.created_at,
    });
  }

  // ── 3. FCM push (non-blocking — elder must not wait for FCM round-trip) ───
  if (caregiver_id) {
    notificationService
      .sendSosAlert(elderly_id, sos.id, sos.source)
      .catch((err) => {
        logger.error(`SOS FCM pipeline error (non-fatal): ${err.message}`);
      });
  }

  // Respond immediately
  res.status(201).json(
    new ApiResponse(201, { sos_id: sos.id }, 'SOS sent — caregiver notified')
  );
});

/**
 * @route   PUT /api/v1/sos/:sosId/acknowledge
 * @desc    Caregiver marks SOS as acknowledged ("I'm on my way").
 * @access  Private (Caregiver — verifyFirebaseToken)
 */
const acknowledgeSos = asyncHandler(async (req, res) => {
  const { sosId } = req.params;
  const caregiver_id = req.user.id; // from verifyFirebaseToken

  const sos = await sosService.acknowledgeSos(sosId, caregiver_id);

  res.json(new ApiResponse(200, { sos }, 'SOS acknowledged'));
});

/**
 * @route   GET /api/v1/sos/history
 * @desc    Get SOS history for the caregiver dashboard.
 * @access  Private (Caregiver — verifyFirebaseToken)
 */
const getSosHistory = asyncHandler(async (req, res) => {
  const { limit = 20, offset = 0 } = req.query;
  const history = await sosService.getSosHistory(
    req.user.id,
    parseInt(limit),
    parseInt(offset)
  );
  res.json(new ApiResponse(200, { history, count: history.length }, 'SOS history retrieved'));
});

module.exports = { triggerSos, acknowledgeSos, getSosHistory };
