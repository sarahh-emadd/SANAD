/**
 * messages.controller.js
 *
 * Elder → Caregiver quick preset messages.
 *
 * Elder endpoints  (elderly Firebase auth or just elderly_id from shared_prefs):
 *   POST /messages/preset  — elder sends a preset message
 *
 * Caregiver endpoints (Firebase auth):
 *   GET  /messages          — get all messages for caregiver's elder
 *   PUT  /messages/:id/read — mark a message as read
 *   GET  /messages/unread-count — count of unread
 */

const { messagesService } = require('../../../services/messages.service');
const notificationService  = require('../../../services/notification.service');
const socketService         = require('../../../services/socket.service');
const ApiResponse           = require('../../../utils/ApiResponse');
const ApiError              = require('../../../utils/ApiError');
const asyncHandler          = require('../../../utils/asyncHandler');
const logger                = require('../../../utils/logger');
const pool                  = require('../../../config/database.config');

// ── Elder: send preset message ─────────────────────────────────────────────

const sendPreset = asyncHandler(async (req, res) => {
  const { elderly_id, message_key } = req.body;
  if (!elderly_id || !message_key) {
    throw new ApiError(400, 'elderly_id and message_key are required');
  }

  const message = await messagesService.sendPreset(elderly_id, message_key);

  // Real-time: emit to caregiver socket room
  const io = req.app.get('io');
  if (io && message.caregiver_id) {
    const elderRes = await pool.query(
      `SELECT first_name || ' ' || last_name AS name FROM elderly WHERE id = $1`,
      [elderly_id]
    );
    const elderlyName = elderRes.rows[0]?.name ?? 'Elder';

    io.to(`caregiver_${message.caregiver_id}`).emit('preset_message', {
      id:           message.id,
      elderly_id,
      caregiver_id: message.caregiver_id,
      message_key,
      message_en:   message.message_en,
      message_ar:   message.message_ar,
      elderly_name: elderlyName,
      created_at:   message.created_at,
    });
  }

  // FCM push to caregiver
  try {
    const cgRes = await pool.query(
      `SELECT c.fcm_token, e.first_name || ' ' || e.last_name AS elderly_name
       FROM elderly e JOIN caregivers c ON c.id = e.caregiver_id
       WHERE e.id = $1`,
      [elderly_id]
    );
    const row = cgRes.rows[0];
    if (row?.fcm_token) {
      await notificationService.sendRawNotification(row.fcm_token, {
        title: `💬 Message from ${row.elderly_name}`,
        body: message.message_en,
        data: { type: 'preset_message', message_key, elderly_id, message_id: message.id },
      });
    }
  } catch (e) {
    logger.error(`FCM preset message error (non-fatal): ${e.message}`);
  }

  res.status(201).json(new ApiResponse(201, { message }, 'Message sent'));
});

// ── Caregiver: list messages ───────────────────────────────────────────────

const getMessages = asyncHandler(async (req, res) => {
  const { uid } = req.user; // Firebase UID from auth middleware
  const cgRes = await pool.query(`SELECT id FROM caregivers WHERE firebase_uid = $1`, [uid]);
  if (!cgRes.rows[0]) throw new ApiError(404, 'Caregiver not found');
  const caregiverId = cgRes.rows[0].id;

  const messages = await messagesService.getMessagesForCaregiver(caregiverId);
  res.json(new ApiResponse(200, { messages, count: messages.length }, 'Messages retrieved'));
});

// ── Caregiver: mark read ───────────────────────────────────────────────────

const markRead = asyncHandler(async (req, res) => {
  await messagesService.markRead(req.params.id);
  res.json(new ApiResponse(200, {}, 'Marked as read'));
});

// ── Caregiver: unread count ────────────────────────────────────────────────

const unreadCount = asyncHandler(async (req, res) => {
  const { uid } = req.user;
  const cgRes = await pool.query(`SELECT id FROM caregivers WHERE firebase_uid = $1`, [uid]);
  if (!cgRes.rows[0]) throw new ApiError(404, 'Caregiver not found');
  const count = await messagesService.unreadCount(cgRes.rows[0].id);
  res.json(new ApiResponse(200, { count }, 'Unread count'));
});

module.exports = { sendPreset, getMessages, markRead, unreadCount };
