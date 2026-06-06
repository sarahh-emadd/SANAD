/**
 * weeklyReport.job.js
 *
 * Runs every Sunday at 08:00.
 * Generates a weekly report for each active elderly person and sends
 * an FCM push notification to their caregiver so they know it's ready.
 */

const pool               = require('../config/database.config');
const reportsService     = require('../services/reports.service');
const notificationService = require('../services/notification.service');
const logger             = require('../utils/logger');

module.exports = async function weeklyReportJob() {
  logger.info('[WeeklyReport] Generating weekly reports...');

  // Get all active elderly with a caregiver that has an FCM token
  const res = await pool.query(`
    SELECT e.id AS elderly_id,
           e.first_name || ' ' || e.last_name AS elderly_name,
           c.fcm_token
    FROM elderly e
    JOIN caregivers c ON c.id = e.caregiver_id
    WHERE e.status = 'active'
      AND c.fcm_token IS NOT NULL
  `);

  let sent = 0;
  for (const row of res.rows) {
    try {
      // Generate report data (we don't need to store it — Flutter fetches on demand)
      const report = await reportsService.weeklyReport(row.elderly_id);
      const adherence = report.pills.adherence_pct;
      const adherenceText = adherence !== null ? `${adherence}% adherence` : 'No doses recorded';

      await notificationService.sendRawNotification(row.fcm_token, {
        title: `📊 Weekly Report — ${row.elderly_name}`,
        body:  `This week: ${adherenceText}. ${report.events.falls} falls, ${report.sos_count} SOS alerts. Tap to view.`,
        data: {
          type:       'weekly_report',
          elderly_id: row.elderly_id,
          week_end:   report.week_end,
        },
      });
      sent++;
    } catch (err) {
      logger.error(`[WeeklyReport] Error for elderly ${row.elderly_id}: ${err.message}`);
    }
  }

  logger.info(`[WeeklyReport] Sent ${sent}/${res.rows.length} weekly report notifications`);
};
