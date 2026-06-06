const cron = require('node-cron');
const logger = require('../utils/logger');

const qrExpiryJob = require('./qrExpiry.job');
const offlineDetectionJob = require('./offlineDetection.job');
const deviceHealthJob = require('./deviceHealth.job');
const dataCleanupJob = require('./dataCleanup.job');
const sosEscalationJob = require('./sosEscalation.job');
const weeklyReportJob = require('./weeklyReport.job');
const scheduleExpiryJob = require('./scheduleExpiry.job');

const initializeJobs = () => {
  logger.info('🕐 Initializing scheduled jobs...');

  // QR Token Expiry - Every hour
  cron.schedule('0 * * * *', async () => {
    logger.info('[CRON] QR Expiry Job triggered');
    try {
      await qrExpiryJob();
    } catch (error) {
      logger.error('[CRON] QR Expiry Job error:', error);
    }
  });
  logger.info('  ✓ QR Expiry Job scheduled (every hour)');

  // Offline Detection - Every 15 minutes
  cron.schedule('*/15 * * * *', async () => {
    logger.info('[CRON] Offline Detection Job triggered');
    try {
      await offlineDetectionJob();
    } catch (error) {
      logger.error('[CRON] Offline Detection Job error:', error);
    }
  });
  logger.info('  ✓ Offline Detection Job scheduled (every 15 minutes)');

  // Device Health - Every 6 hours
  cron.schedule('0 */6 * * *', async () => {
    logger.info('[CRON] Device Health Job triggered');
    try {
      await deviceHealthJob();
    } catch (error) {
      logger.error('[CRON] Device Health Job error:', error);
    }
  });
  logger.info('  ✓ Device Health Job scheduled (every 6 hours)');

  // Data Cleanup - Daily at 2 AM
  cron.schedule('0 2 * * *', async () => {
    logger.info('[CRON] Data Cleanup Job triggered');
    try {
      await dataCleanupJob();
    } catch (error) {
      logger.error('[CRON] Data Cleanup Job error:', error);
    }
  });
  logger.info('  ✓ Data Cleanup Job scheduled (daily at 2 AM)');

  // SOS Escalation - Every minute
  cron.schedule('* * * * *', async () => {
    try { await sosEscalationJob(); } catch (error) { logger.error('[CRON] SOS Escalation error:', error); }
  });
  logger.info('  ✓ SOS Escalation Job scheduled (every minute)');

  // Schedule Expiry - Daily at midnight
  cron.schedule('0 0 * * *', async () => {
    logger.info('[CRON] Schedule Expiry Job triggered');
    try { await scheduleExpiryJob(); } catch (error) { logger.error('[CRON] Schedule Expiry error:', error); }
  });
  logger.info('  ✓ Schedule Expiry Job scheduled (daily at midnight)');

  // Weekly Health Report — Every Sunday at 08:00
  cron.schedule('0 8 * * 0', async () => {
    logger.info('[CRON] Weekly Report Job triggered');
    try { await weeklyReportJob(); } catch (error) { logger.error('[CRON] Weekly Report error:', error); }
  });
  logger.info('  ✓ Weekly Report Job scheduled (Sundays at 08:00)');

  logger.info('✓ All scheduled jobs initialized');
};

const runJob = async (jobName) => {
  const jobs = {
    qrExpiry: qrExpiryJob,
    offlineDetection: offlineDetectionJob,
    deviceHealth: deviceHealthJob,
    dataCleanup: dataCleanupJob,
    sosEscalation: sosEscalationJob,
  };

  const job = jobs[jobName];
  if (!job) throw new Error(`Job '${jobName}' not found`);

  logger.info(`Running job: ${jobName}`);
  return await job();
};

module.exports = { initializeJobs, runJob };