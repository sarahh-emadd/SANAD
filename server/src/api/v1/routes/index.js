const express = require('express');
const router  = express.Router();

const authRoutes          = require('./auth.routes');
const elderlyRoutes       = require('./elderly.routes');
const qrRoutes            = require('./qr.routes');
const eventsRoutes        = require('./events.routes');
const sosRoutes           = require('./sos.routes');
const voiceMessagesRoutes = require('./voice-messages.routes');
const pillboxRoutes       = require('./pillbox.routes');
const devRoutes           = require('./dev.routes');

// Core routes
router.use('/auth',           authRoutes);
router.use('/elderly',        elderlyRoutes);
router.use('/qr',             qrRoutes);
router.use('/events',         eventsRoutes);
router.use('/sos',            sosRoutes);
router.use('/voice-messages', voiceMessagesRoutes);
router.use('/pillbox',        pillboxRoutes);

// Dev routes
router.use('/dev', devRoutes);

// Health check
router.get('/health', (req, res) => {
  res.json({
    success:   true,
    message:   'SANAD API is running',
    timestamp: new Date().toISOString(),
    version:   '1.0.0',
  });
});

module.exports = router;