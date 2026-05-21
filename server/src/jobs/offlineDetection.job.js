const pool = require('../config/database.config');
const { messaging } = require('../config/firebase.config');
const logger = require('../utils/logger');

const offlineDetectionJob = async () => {
  try {
    logger.info('Running offline detection job...');
    
    const result = await pool.query(
      `SELECT 
        e.id,
        CONCAT(e.first_name, ' ', e.last_name) as name,
        e.last_seen,
        c.fcm_token as caregiver_fcm_token,
        CONCAT(c.first_name, ' ', c.last_name) as caregiver_name
       FROM elderly e
       JOIN caregivers c ON e.caregiver_id = c.id
       WHERE e.is_connected = true
       AND e.last_seen < NOW() - INTERVAL '24 hours'
       AND e.status = 'active'`
    );

    if (result.rows.length === 0) {
      logger.info('✓ All connected devices are online (or no devices exist)');
      return { offlineCount: 0 };
    }

    logger.warn(`⚠ Found ${result.rows.length} offline devices`);

    for (const elderly of result.rows) {
      try {
        await pool.query(
          `UPDATE elderly SET is_connected = false WHERE id = $1`,
          [elderly.id]
        );

        await pool.query(
          `UPDATE elderly_connections 
           SET disconnected_at = NOW(), disconnection_reason = 'offline_timeout'
           WHERE elderly_id = $1 AND disconnected_at IS NULL`,
          [elderly.id]
        );

        if (elderly.caregiver_fcm_token) {
          await messaging.send({
            token: elderly.caregiver_fcm_token,
            notification: {
              title: 'Device Offline',
              body: `${elderly.name}'s device has been offline for 24 hours`,
            },
            data: {
              type: 'ELDERLY_OFFLINE',
              elderly_id: String(elderly.id),
            },
          });

          logger.info(`  ✓ Notification sent for ${elderly.name}`);
        }
      } catch (error) {
        logger.error(`  ❌ Failed to process ${elderly.name}:`, error.message);
      }
    }

    return { offlineCount: result.rows.length };
  } catch (error) {
    // Don't log full error object if it's just empty database
    if (error.message && error.message.includes('relation')) {
      logger.warn('⚠ Database tables not yet created. Skipping offline detection.');
      return { offlineCount: 0 };
    }
    logger.error('❌ Offline detection job failed:', error.message);
    return { offlineCount: 0, error: error.message };
  }
};

module.exports = offlineDetectionJob;