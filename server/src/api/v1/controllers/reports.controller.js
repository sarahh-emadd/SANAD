/**
 * reports.controller.js
 *
 * GET /api/v1/reports/weekly/:elderlyId   — weekly summary JSON
 *   Query param: ?week_end=YYYY-MM-DD     — optional, defaults to today
 */

const reportsService = require('../../../services/reports.service');
const ApiResponse    = require('../../../utils/ApiResponse');
const asyncHandler   = require('../../../utils/asyncHandler');

const getWeeklyReport = asyncHandler(async (req, res) => {
  const { elderlyId } = req.params;
  const weekEnd = req.query.week_end ? new Date(req.query.week_end) : new Date();
  const report  = await reportsService.weeklyReport(elderlyId, weekEnd);
  res.json(new ApiResponse(200, { report }, 'Weekly report generated'));
});

module.exports = { getWeeklyReport };
