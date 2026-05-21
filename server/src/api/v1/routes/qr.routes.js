const express = require('express');
const router = express.Router();
const qrController = require('../controllers/qr.controller');

// Public routes (no auth required)
router.post('/connect', qrController.connectDevice);
router.post('/connect-manual', qrController.connectWithCode);
router.post('/verify', qrController.verifyToken);
router.post('/verify-manual', qrController.verifyManualCode);

module.exports = router;