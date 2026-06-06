/**
 * scheduleExpiry.job.js
 *
 * Runs daily at midnight.
 * Soft-deactivates pill schedules whose end_date has passed.
 * This makes slots appear "empty" in the app after the prescription window ends.
 */

const pool   = require('../config/database.config');
const logger = require('../utils/logger');

module.exports = async function scheduleExpiryJob() {
  const result = await pool.query(`
    UPDATE pill_schedules
    SET is_active  = false,
        updated_at = NOW()
    WHERE is_active = true
      AND end_date IS NOT NULL
      AND end_date < CURRENT_DATE
    RETURNING id, elderly_id, slot_id
  `);

  if (result.rows.length > 0) {
    logger.info(`[ScheduleExpiry] Deactivated ${result.rows.length} expired schedule(s)`);
  }
};
