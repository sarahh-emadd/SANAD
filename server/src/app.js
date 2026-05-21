const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
require('./config/firebase.config');

const routes = require('./api/v1/routes');
const errorHandler = require('./middlewares/errorHandler.middleware');
const logger = require('./utils/logger');

const app = express();

// Security middleware
app.use(helmet());

// CORS configuration
app.use(cors({
  origin: '*', // For development - change in production
  credentials: true,
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Logging
if (process.env.NODE_ENV !== 'production') {
  app.use(morgan('dev'));
}

// Log all requests
app.use((req, res, next) => {
  logger.http(`${req.method} ${req.path}`);
  next();
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'SANAD API Server',
    version: '1.0.0',
    endpoints: {
      health: '/api/v1/health',
      auth: '/api/v1/auth',
      elderly: '/api/v1/elderly',
      qr: '/api/v1/qr',
    },
  });
});

// API Routes
app.use('/api/v1', routes);

// 404 handler - FIXED: Use (req, res, next) instead of app.use('*', ...)
app.use((req, res, next) => {
  res.status(404).json({
    success: false,
    message: `Route ${req.method} ${req.originalUrl} not found`,
    availableRoutes: [
      'GET /api/v1/health',
      'POST /api/v1/auth/sync',
      'GET /api/v1/auth/me',
      'POST /api/v1/elderly',
      'GET /api/v1/elderly',
      'POST /api/v1/qr/connect',
      'POST /api/v1/qr/connect-manual',
    ],
  });
});

// Error handling middleware (must be last)
app.use(errorHandler);

module.exports = app;