/**
 * sos.routes.js
 *
 * POST /api/v1/sos                      — elder triggers SOS (no caregiver auth)
 * PUT  /api/v1/sos/:sosId/acknowledge   — caregiver acknowledges (Firebase auth)
 * GET  /api/v1/sos/history              — caregiver history (Firebase auth)
 */

const express = require('express');
const router  = express.Router();

const { verifyFirebaseToken } = require('../../../middlewares/firebase-auth.middleware');
const { triggerSos, acknowledgeSos, getSosHistory } = require('../controllers/sos.controller');

// Elder hits this — no verifyFirebaseToken because that middleware only checks
// the `caregivers` table. The elder's identity is validated via elderly_id in body.
router.post('/', triggerSos);

// Caregiver routes — protected
router.get('/history',                verifyFirebaseToken, getSosHistory);
router.put('/:sosId/acknowledge',     verifyFirebaseToken, acknowledgeSos);

module.exports = router;
