const express    = require('express');
const multer     = require('multer');
const router     = express.Router();
const pool       = require('../../../config/database.config');
const { verifyFirebaseToken } = require('../../../middlewares/firebase-auth.middleware');
const minioService  = require('../../../services/minio.service');
const ApiResponse   = require('../../../utils/ApiResponse');
const ApiError      = require('../../../utils/ApiError');
const asyncHandler  = require('../../../utils/asyncHandler');

const upload = multer({
  storage: multer.memoryStorage(),
  limits:  { fileSize: 20 * 1024 * 1024 }, // 20 MB
});

// ── No-auth: Elder device fetches messages sent to it ─────────────────────
router.get('/elder/:elderlyId', asyncHandler(async (req, res) => {
  const result = await pool.query(
    `SELECT id, title, file_path, duration_secs, used_times, created_at
     FROM voice_messages
     WHERE elderly_id = $1
     ORDER BY created_at DESC`,
    [req.params.elderlyId]
  );
  res.json(new ApiResponse(200, { messages: result.rows }));
}));

// ── All caregiver routes require auth ─────────────────────────────────────
router.use(verifyFirebaseToken);

// GET /voice-messages — caregiver lists their saved messages (is_saved = true only)
router.get('/', asyncHandler(async (req, res) => {
  const result = await pool.query(
    `SELECT vm.id, vm.title, vm.file_path, vm.duration_secs,
            vm.used_times, vm.created_at,
            e.first_name AS elderly_name
     FROM voice_messages vm
     JOIN elderly e ON e.id = vm.elderly_id
     WHERE vm.caregiver_id = $1 AND vm.is_saved = true
     ORDER BY vm.created_at DESC`,
    [req.user.id]
  );
  res.json(new ApiResponse(200, { messages: result.rows }));
}));

// POST /voice-messages — upload a new voice message (multipart: audio + title + elderly_id + is_saved?)
// is_saved=false → "Send Once" (uploaded & sent but hidden from caregiver library)
// is_saved=true  → "Save & Send" (default — appears in library)
router.post('/', upload.single('audio'), asyncHandler(async (req, res) => {
  const caregiverId = req.user.id;
  const { title, elderly_id, duration_secs, is_saved } = req.body;

  if (!title)       throw new ApiError(400, 'title is required');
  if (!elderly_id)  throw new ApiError(400, 'elderly_id is required');
  if (!req.file)    throw new ApiError(400, 'audio file is required');

  // Verify this elderly belongs to the caregiver
  const check = await pool.query(
    `SELECT id FROM elderly WHERE id = $1 AND caregiver_id = $2`,
    [elderly_id, caregiverId]
  );
  if (check.rows.length === 0) throw new ApiError(403, 'Elderly not found for this caregiver');

  const fileUrl = await minioService.uploadVoiceMessage(
    caregiverId, req.file.buffer, req.file.mimetype || 'audio/aac'
  );

  // is_saved defaults to true unless explicitly set to 'false'
  const isSaved = is_saved === 'false' ? false : true;

  const result = await pool.query(
    `INSERT INTO voice_messages (caregiver_id, elderly_id, title, file_path, duration_secs, is_saved)
     VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
    [caregiverId, elderly_id, title, fileUrl, parseInt(duration_secs) || 0, isSaved]
  );

  res.status(201).json(new ApiResponse(201, { message: result.rows[0] }, 'Voice message saved'));
}));

// POST /voice-messages/:id/send — push message to elder via Socket.IO
router.post('/:id/send', asyncHandler(async (req, res) => {
  const caregiverId = req.user.id;

  const result = await pool.query(
    `UPDATE voice_messages
     SET used_times = used_times + 1
     WHERE id = $1 AND caregiver_id = $2
     RETURNING *`,
    [req.params.id, caregiverId]
  );
  if (result.rows.length === 0) throw new ApiError(404, 'Message not found');
  const msg = result.rows[0];

  // Fetch caregiver name for the push payload
  const cgRow = await pool.query(
    `SELECT first_name FROM caregivers WHERE id = $1`, [caregiverId]
  );
  const caregiverName = cgRow.rows[0]?.first_name || 'Caregiver';

  // Emit to elder's socket room
  const io = req.app.get('io');
  if (io) {
    io.to(`elder_${msg.elderly_id}`).emit('voice_message', {
      id:            msg.id,
      title:         msg.title,
      file_path:     msg.file_path,
      from:          caregiverName,
      duration_secs: msg.duration_secs,
      used_times:    msg.used_times,
      last_used:     '',
      created_at:    msg.created_at,
    });
  }

  res.json(new ApiResponse(200, { message: msg }, 'Message sent to elder'));
}));

// DELETE /voice-messages/:id
router.delete('/:id', asyncHandler(async (req, res) => {
  const caregiverId = req.user.id;

  const result = await pool.query(
    `DELETE FROM voice_messages WHERE id = $1 AND caregiver_id = $2 RETURNING file_path`,
    [req.params.id, caregiverId]
  );
  if (result.rows.length === 0) throw new ApiError(404, 'Message not found');

  // Best-effort MinIO cleanup
  try { await minioService.deleteFile(result.rows[0].file_path); } catch (_) {}

  res.json(new ApiResponse(200, null, 'Message deleted'));
}));

module.exports = router;
