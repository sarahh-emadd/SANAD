/**
 * messages.routes.js
 *
 * Base path: /api/v1/messages
 *
 * Elder routes (no Firebase auth — identified by elderly_id in body):
 *   POST /preset         — elder sends a preset message
 *
 * Caregiver routes (Firebase auth):
 *   GET  /              — get all messages
 *   PUT  /:id/read      — mark as read
 *   GET  /unread-count  — count unread
 */

const express = require('express');
const router  = express.Router();

const { verifyFirebaseToken } = require('../../../middlewares/firebase-auth.middleware');
const { sendPreset, getMessages, markRead, unreadCount } = require('../controllers/messages.controller');

// Elder endpoint (no auth — elder app uses elderly_id from shared prefs)
router.post('/preset', sendPreset);

// Caregiver endpoints
router.get('/',               verifyFirebaseToken, getMessages);
router.put('/:id/read',       verifyFirebaseToken, markRead);
router.get('/unread-count',   verifyFirebaseToken, unreadCount);

module.exports = router;
