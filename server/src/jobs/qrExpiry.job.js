const qrService = require('../services/qr.service');
const logger = require('../utils/logger');

const qrExpiryJob = async () => {
  try {
    logger.info('Running QR expiry job...');
    
    const result = await qrService.revokeExpiredTokens();
    
    if (result.revokedCount > 0) {
      logger.info(`✓ Revoked ${result.revokedCount} expired QR tokens`);
      result.tokens.forEach(token => {
        logger.info(`  - Token for elderly_id: ${token.elderly_id}`);
      });
    } else {
      logger.info('✓ No expired QR tokens found');
    }
    
    return result;
  } catch (error) {
    logger.error('❌ QR expiry job failed:', error);
    throw error;
  }
};

module.exports = qrExpiryJob;