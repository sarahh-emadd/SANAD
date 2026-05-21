const pool = require('../config/database.config');
const logger = require('../utils/logger');

const deviceHealthJob = async () => {
  try {
    logger.info('Running device health check...');
    
    const stats = await pool.query(`
      SELECT 
        COUNT(*) FILTER (WHERE is_connected = true) as connected_count,
        COUNT(*) FILTER (WHERE is_connected = false) as disconnected_count,
        COUNT(*) FILTER (WHERE status = 'active') as total_active
      FROM elderly
    `);

    const health = stats.rows[0];

    logger.info('Device Health Report:');
    logger.info(`  Total Active: ${health.total_active}`);
    logger.info(`  Connected: ${health.connected_count}`);
    logger.info(`  Disconnected: ${health.disconnected_count}`);

    return health;
  } catch (error) {
    logger.error('❌ Device health job failed:', error);
    throw error;
  }
};

module.exports = deviceHealthJob;