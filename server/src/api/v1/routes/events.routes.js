const express = require('express');
const router = express.Router();
const { verifyFirebaseToken } = require('../../../middlewares/firebase-auth.middleware');

const {
  createEvent,
  getEventsByElderly,
  getUnverifiedEvents,
  verifyEvent,
  getEventById,
  getNotifications,
  getTodayStats,
} = require('../controllers/events.controller');

// Python AI detection sends event here (no auth - internal service)
router.post('/', createEvent);

// Caregiver routes (protected)
router.get('/notifications', verifyFirebaseToken, getNotifications);
router.get('/today-stats/:elderlyId', verifyFirebaseToken, getTodayStats);
router.get('/unverified', verifyFirebaseToken, getUnverifiedEvents);
router.get('/detail/:eventId', verifyFirebaseToken, getEventById);
router.get('/:elderlyId', verifyFirebaseToken, getEventsByElderly);
router.put('/:eventId/verify', verifyFirebaseToken, verifyEvent);

module.exports = router;