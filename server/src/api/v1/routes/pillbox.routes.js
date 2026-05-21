/**
 * pillbox.routes.js
 *
 * Base path: /api/v1/pillbox
 *
 * Caregiver routes (Firebase auth):
 *   GET  /slots/:elderlyId
 *   PUT  /slots/:elderlyId/:slotNumber
 *   POST /schedules
 *   PUT  /schedules/:scheduleId
 *   DEL  /schedules/:scheduleId
 *   GET  /logs/:elderlyId
 *   GET  /today/:elderlyId
 *
 * ESP32 routes (no auth — hardware device):
 *   POST /device/register
 *   GET  /device/schedule
 *   POST /device/report
 */

const express = require('express');
const router  = express.Router();

const { verifyFirebaseToken } = require('../../../middlewares/firebase-auth.middleware');
const {
  getSlots,
  updateSlot,
  addSchedule,
  updateSchedule,
  deleteSchedule,
  getLogs,
  getTodaySchedule,
  registerDevice,
  getDeviceSchedule,
  reportDose,
} = require('../controllers/pillbox.controller');

// ── Caregiver routes (Firebase auth) ────────────────────────────────────────
router.get('/slots/:elderlyId',              verifyFirebaseToken, getSlots);
router.put('/slots/:elderlyId/:slotNumber',  verifyFirebaseToken, updateSlot);
router.post('/schedules',                    verifyFirebaseToken, addSchedule);
router.put('/schedules/:scheduleId',         verifyFirebaseToken, updateSchedule);
router.delete('/schedules/:scheduleId',      verifyFirebaseToken, deleteSchedule);
router.get('/logs/:elderlyId',               verifyFirebaseToken, getLogs);
router.get('/today/:elderlyId',              verifyFirebaseToken, getTodaySchedule);

// ── ESP32 routes (no auth — hardware device) ─────────────────────────────────
router.post('/device/register',  registerDevice);
router.get('/device/schedule',   getDeviceSchedule);
router.post('/device/report',    reportDose);

module.exports = router;
