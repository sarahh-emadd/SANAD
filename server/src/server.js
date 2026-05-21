/**
 * server.js
 *
 * Responsibilities:
 *   1. Create HTTP server
 *   2. Attach Socket.IO
 *   3. Delegate ALL socket logic to socket.service.js
 *   4. Start server + initialize background jobs
 */

require('dotenv').config();

const http          = require('http');
const { Server }    = require('socket.io');
const app           = require('./app');
const socketService = require('./services/socket.service');
const { initializeJobs } = require('./jobs');
const minioService  = require('./services/minio.service');
const logger        = require('./utils/logger');
const { runMigrations } = require('./db/migrate');

const PORT = process.env.PORT || 3000;

// ── HTTP server ──────────────────────────────────────────────
const server = http.createServer(app);

// ── Socket.IO ────────────────────────────────────────────────
const io = new Server(server, {
  cors: {
    origin:  process.env.CORS_ORIGIN ?? '*',
    methods: ['GET', 'POST'],
  },
  // Ping every 25s, disconnect after 60s of silence.
  // Prevents ghost connections when Python/Flutter crash silently.
  pingInterval: 25000,
  pingTimeout:  60000,
});

// Make io accessible in controllers via req.app.get('io')
app.set('io', io);

// ── Wire ALL socket events via the service ───────────────────
socketService.init(io);

// ── Start server ─────────────────────────────────────────────
server.listen(PORT, async () => {
  logger.success(`🚀 Server running on port ${PORT}`);
  logger.info(`📍 Environment: ${process.env.NODE_ENV ?? 'development'}`);
  logger.info(`🔌 Socket.IO ready`);

  // Run DB migrations (CREATE TABLE IF NOT EXISTS — safe to run every boot)
  try {
    await runMigrations();
  } catch (error) {
    logger.warn(`⚠ Migration warning: ${error.message}`);
  }

  // FIXED: MinIO failure is non-fatal.
  // MinIO only runs inside Docker — don't crash the dev server without it.
  try {
    await minioService.initialize();
    logger.success('✓ MinIO connected');
  } catch (error) {
    logger.warn(`⚠ MinIO unavailable: ${error.message}`);
    logger.warn('  Snapshots will not be saved. Run: docker-compose up minio');
  }

  initializeJobs();
});

// ── Process error guards ──────────────────────────────────────
process.on('uncaughtException', (error) => {
  logger.error('Uncaught Exception:', error);
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  logger.error('Unhandled Rejection:', reason);
  process.exit(1);
});