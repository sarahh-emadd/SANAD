const express = require('express');
const { v4: uuidv4 } = require('uuid');
const router = express.Router();
const pool = require('../../../config/database.config');
const elderlyService = require('../../../services/elderly.service');
const qrService = require('../../../services/qr.service');
const ApiResponse = require('../../../utils/ApiResponse');
const asyncHandler = require('../../../utils/asyncHandler');

router.post('/create-test-caregiver', asyncHandler(async (req, res) => {
  const { email, first_name, last_name, phone } = req.body;
  const fakeFirebaseUid = `dev-${Date.now()}`;
  const uuid = uuidv4();
  const result = await pool.query(
    `INSERT INTO caregivers (id, firebase_uid, email, first_name, last_name, phone, email_verified)
     VALUES ($1, $2, $3, $4, $5, $6, true)
     ON CONFLICT (email) DO UPDATE
     SET first_name = EXCLUDED.first_name, last_name = EXCLUDED.last_name
     RETURNING *`,
    [uuid, fakeFirebaseUid, email || `test-${Date.now()}@sanad.dev`, first_name || 'Test', last_name || 'Caregiver', phone || null]
  );
  res.json(new ApiResponse(200, { caregiver: result.rows[0], note: 'Dev caregiver created. Use caregiver.id for next step.' }));
}));

router.post('/create-elderly', asyncHandler(async (req, res) => {
  const { caregiver_id, first_name, last_name, date_of_birth, typical_sleep_time, typical_wake_time } = req.body;
  if (!caregiver_id) return res.status(400).json({ message: 'caregiver_id is required' });
  const result = await elderlyService.createElderly(caregiver_id, {
    first_name: first_name || 'Test',
    last_name: last_name || 'Elderly',
    date_of_birth: date_of_birth || '1950-01-01',
    emergency_contact_name: 'Test Contact',
    emergency_contact_phone: '0500000000',
    typical_sleep_time: typical_sleep_time || null,
    typical_wake_time: typical_wake_time || null,
  });
  res.json(new ApiResponse(200, { ...result, note: 'Test elderly created.', instructions: { elderlyId: result.elderly.id, viewQR: `GET /api/v1/dev/view-qr/${result.elderly.id}`, manualCode: result.manualCode } }));
}));

router.get('/caregivers', asyncHandler(async (req, res) => {
  const result = await pool.query(`SELECT id, firebase_uid, email, first_name, last_name, phone, created_at FROM caregivers WHERE firebase_uid LIKE 'dev-%' ORDER BY created_at DESC`);
  res.json(new ApiResponse(200, { caregivers: result.rows }));
}));

// ── Camera device registration ─────────────────────────────────────────────
// Python calls this on startup to register its MAC address → elderly mapping.
// This lets any camera work with any elder — no hardcoding needed.
router.post('/camera-device/register', asyncHandler(async (req, res) => {
  const { camera_device_id, elderly_id } = req.body;
  if (!camera_device_id || !elderly_id) {
    return res.status(400).json({ message: 'camera_device_id and elderly_id are required' });
  }
  // Upsert into cameras table
  await pool.query(
    `INSERT INTO cameras (camera_device_id, elderly_id, status, updated_at)
     VALUES ($1, $2, 'online', NOW())
     ON CONFLICT (camera_device_id)
     DO UPDATE SET elderly_id = EXCLUDED.elderly_id, status = 'online', updated_at = NOW()`,
    [camera_device_id, elderly_id]
  );
  res.json(new ApiResponse(200, { camera_device_id, elderly_id }, 'Camera registered'));
}));

// Python calls this on startup to look up its elderly by MAC address
router.get('/camera-device/:camera_device_id', asyncHandler(async (req, res) => {
  const { camera_device_id } = req.params;
  const result = await pool.query(
    `SELECT elderly_id FROM cameras WHERE camera_device_id = $1 LIMIT 1`,
    [camera_device_id]
  );
  if (result.rows.length === 0) {
    return res.status(404).json(new ApiResponse(404, null, 'Camera device not registered'));
  }
  res.json(new ApiResponse(200, { elderly_id: result.rows[0].elderly_id }));
}));

router.get('/elderly', asyncHandler(async (req, res) => {
  const result = await pool.query(`SELECT e.id, e.first_name, e.last_name, e.is_connected, e.status, e.typical_wake_time, e.typical_sleep_time, e.created_at, c.first_name AS caregiver_first_name, c.email AS caregiver_email FROM elderly e JOIN caregivers c ON e.caregiver_id = c.id ORDER BY e.created_at DESC`);
  res.json(new ApiResponse(200, { elderly: result.rows, count: result.rows.length }));
}));

router.get('/elderly/:id/qr', asyncHandler(async (req, res) => {
  const qr = await qrService.getActiveQRToken(req.params.id);
  if (!qr) return res.json(new ApiResponse(200, { message: 'No active QR.', tip: `POST /api/v1/dev/regenerate-qr/${req.params.id}` }));
  res.json(new ApiResponse(200, { ...qr }));
}));

router.post('/regenerate-qr/:id', asyncHandler(async (req, res) => {
  const qrData = await qrService.generateQRToken(req.params.id);
  res.json(new ApiResponse(200, { ...qrData }));
}));

router.post('/test-connect', asyncHandler(async (req, res) => {
  const { token, manualCode } = req.body;
  if (!token && !manualCode) return res.status(400).json({ message: 'Provide token or manualCode' });
  const fakeDeviceToken = `dev-fcm-${Date.now()}`;
  const result = token ? await qrService.connectElderlyDevice(token, fakeDeviceToken) : await qrService.connectWithManualCode(manualCode, fakeDeviceToken);
  res.json(new ApiResponse(200, { ...result, note: 'Device connected!', deviceToken: fakeDeviceToken }));
}));

router.get('/view-qr/:elderlyId', asyncHandler(async (req, res) => {
  const qr = await qrService.getActiveQRToken(req.params.elderlyId);
  if (!qr) return res.send(`<html><body style="text-align:center;padding:50px"><h1>No Active QR</h1><p>POST /api/v1/dev/regenerate-qr/${req.params.elderlyId}</p></body></html>`);
  res.send(`<html><head><style>body{font-family:Arial;text-align:center;padding:50px;background:#f5f5f5}.card{background:white;padding:40px;border-radius:12px;display:inline-block}.code{font-size:36px;font-weight:bold;letter-spacing:8px;color:#007bff;padding:15px;background:#f0f8ff;border-radius:8px;margin:20px 0}.expiry{color:#dc3545;font-weight:bold}</style></head><body><div class="card"><h1>🔗 Elder Pairing QR</h1><img src="${qr.qrCodeImage}" width="280" height="280"/><p>Scan with elder phone</p><hr/><p>Manual code:</p><div class="code">${qr.manualCode}</div><p class="expiry">Expires in: ${qr.remainingMinutes} minutes</p></div></body></html>`);
}));

router.delete('/reset', asyncHandler(async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(`DELETE FROM elderly_connections WHERE elderly_id IN (SELECT id FROM elderly WHERE caregiver_id IN (SELECT id FROM caregivers WHERE firebase_uid LIKE 'dev-%'))`);
    await client.query(`DELETE FROM qr_tokens WHERE elderly_id IN (SELECT id FROM elderly WHERE caregiver_id IN (SELECT id FROM caregivers WHERE firebase_uid LIKE 'dev-%'))`);
    await client.query(`DELETE FROM elderly WHERE caregiver_id IN (SELECT id FROM caregivers WHERE firebase_uid LIKE 'dev-%')`);
    await client.query(`DELETE FROM caregivers WHERE firebase_uid LIKE 'dev-%'`);
    await client.query('COMMIT');
    res.json(new ApiResponse(200, { message: '✅ All dev test data deleted' }));
  } catch (e) { await client.query('ROLLBACK'); throw e; } finally { client.release(); }
}));

module.exports = router;