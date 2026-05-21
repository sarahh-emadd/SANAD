const pool = require('../config/database.config');
const logger = require('../utils/logger');

const dataCleanupJob = async () => {
  try {
    logger.info('Running data cleanup job...');
    
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');

      const qrResult = await client.query(`
        DELETE FROM qr_tokens
        WHERE revoked_at < NOW() - INTERVAL '90 days'
        RETURNING id
      `);
      
      logger.info(`  ✓ Deleted ${qrResult.rowCount} old QR tokens`);

      const connResult = await client.query(`
        DELETE FROM elderly_connections
        WHERE disconnected_at < NOW() - INTERVAL '1 year'
        RETURNING id
      `);

      logger.info(`  ✓ Deleted ${connResult.rowCount} old connections`);

      // Clean up "Send Once" voice messages older than 24 hours
      const tempVoiceResult = await client.query(`
        DELETE FROM voice_messages
        WHERE is_saved = false AND created_at < NOW() - INTERVAL '24 hours'
        RETURNING id
      `);

      logger.info(`  ✓ Deleted ${tempVoiceResult.rowCount} expired send-once voice messages`);

      await client.query('COMMIT');
      
      return {
        qrTokensDeleted: qrResult.rowCount,
        connectionsDeleted: connResult.rowCount,
      };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  } catch (error) {
    logger.error('❌ Data cleanup job failed:', error);
    throw error;
  }
};

module.exports = dataCleanupJob;