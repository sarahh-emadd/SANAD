/**
 * sosEscalation.job.js
 *
 * Runs every minute. Finds SOS requests that:
 *   - are still 'pending'
 *   - were created more than 5 minutes ago
 *   - have not been escalated yet (escalated_at IS NULL)
 *
 * Sends an urgent second FCM to the caregiver and marks escalated_at.
 */

const pool                = require('../config/database.config');
const notificationService = require('../services/notification.service');
const logger              = require('../utils/logger');

module.exports = async function sosEscalationJob() {
  const result = await pool.query(`
    SELECT s.id, s.elderly_id, s.caregiver_id,
           e.emergency_contact_name
    FROM sos_requests s
    JOIN elderly e ON e.id = s.elderly_id
    WHERE s.status        = 'pending'
      AND s.created_at    < NOW() - INTERVAL '5 minutes'
      AND s.escalated_at  IS NULL
  `);

  if (result.rows.length === 0) return;

  logger.warn(`[SOS Escalation] ${result.rows.length} unacknowledged SOS request(s) found`);

  for (const row of result.rows) {
    try {
      // Mark escalated first to prevent double-firing
      await pool.query(
        `UPDATE sos_requests SET escalated_at = NOW() WHERE id = $1`,
        [row.id]
      );
      await notificationService.sendSosEscalation(
        row.elderly_id,
        row.id,
        row.emergency_contact_name
      );
      logger.warn(`[SOS Escalation] Escalated SOS ${row.id}`);
    } catch (err) {
      logger.error(`[SOS Escalation] Failed for SOS ${row.id}: ${err.message}`);
    }
  }
};
