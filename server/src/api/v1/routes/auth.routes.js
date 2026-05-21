const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { verifyFirebaseToken } = require('../../../middlewares/firebase-auth.middleware');

// ===== PUBLIC ROUTES =====
router.post('/sync', authController.syncUser);
router.post('/check-email', authController.checkEmail);

// ===== PROTECTED ROUTES =====
router.get('/me', verifyFirebaseToken, authController.getMe);
router.put('/profile', verifyFirebaseToken, authController.updateProfile);
router.post('/fcm-token', verifyFirebaseToken, authController.updateFCMToken);
router.post('/verify-email', verifyFirebaseToken, authController.verifyEmail);
router.post('/refresh', verifyFirebaseToken, authController.refreshUser);
router.delete('/account', verifyFirebaseToken, authController.deleteAccount);

module.exports = router;