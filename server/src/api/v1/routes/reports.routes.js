/**
 * reports.routes.js — Base path: /api/v1/reports
 */

const express = require('express');
const router  = express.Router();

const { verifyFirebaseToken } = require('../../../middlewares/firebase-auth.middleware');
const { getWeeklyReport }     = require('../controllers/reports.controller');

router.get('/weekly/:elderlyId', verifyFirebaseToken, getWeeklyReport);

module.exports = router;
