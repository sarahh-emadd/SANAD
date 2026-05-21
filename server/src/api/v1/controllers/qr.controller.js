const qrService = require('../../../services/qr.service');
const ApiResponse = require('../../../utils/ApiResponse');
const asyncHandler = require('../../../utils/asyncHandler');
const ApiError = require('../../../utils/ApiError'); // ⭐ ADD THIS
const logger = require('../../../utils/logger'); // ⭐ ADD THIS

/**
 * @route   POST /api/v1/qr/connect
 * @desc    Connect elderly device using QR token
 * @access  Public (Elderly Device)
 */
const connectDevice = asyncHandler(async (req, res) => {
  const { token, deviceToken } = req.body;

  // ⭐ ADD: Validation
  if (!token) {
    throw new ApiError(400, 'QR token is required');
  }

  if (!deviceToken) {
    throw new ApiError(400, 'Device token (FCM token) is required');
  }

  // Validate token format (should be 64 character hex string)
  if (!/^[a-f0-9]{64}$/i.test(token)) {
    throw new ApiError(400, 'Invalid QR token format');
  }

  logger.info(`QR scan attempt with token: ${token.substring(0, 10)}...`);

  const result = await qrService.connectElderlyDevice(token, deviceToken);

  // ⭐ ADD: Log successful connection
  logger.success(`Device connected successfully for elderly: ${result.elderly.name} (ID: ${result.elderly.id})`);

  res.json(
    new ApiResponse(200, result, 'Device connected successfully')
  );
});

/**
 * @route   POST /api/v1/qr/connect-manual
 * @desc    Connect using 6-digit manual code
 * @access  Public (Elderly Device)
 */
const connectWithCode = asyncHandler(async (req, res) => {
  const { manualCode, deviceToken } = req.body;

  // ⭐ ADD: Validation
  if (!manualCode) {
    throw new ApiError(400, 'Manual code is required');
  }

  if (!deviceToken) {
    throw new ApiError(400, 'Device token (FCM token) is required');
  }

  // ⭐ ADD: Validate manual code format (6 digits)
  if (!/^\d{6}$/.test(manualCode)) {
    throw new ApiError(400, 'Manual code must be exactly 6 digits');
  }

  logger.info(`Manual code connection attempt: ${manualCode}`);

  const result = await qrService.connectWithManualCode(manualCode, deviceToken);

  logger.success(`Device connected via manual code for elderly: ${result.elderly.name} (ID: ${result.elderly.id})`);

  res.json(
    new ApiResponse(200, result, 'Device connected successfully')
  );
});

/**
 * ⭐ NEW: Verify QR token validity (without connecting)
 * @route   POST /api/v1/qr/verify
 * @desc    Check if QR token is valid (for preview/validation)
 * @access  Public (Elderly Device)
 */
const verifyToken = asyncHandler(async (req, res) => {
  const { token } = req.body;

  if (!token) {
    throw new ApiError(400, 'QR token is required');
  }

  // Validate token format
  if (!/^[a-f0-9]{64}$/i.test(token)) {
    throw new ApiError(400, 'Invalid QR token format');
  }

  // Check if token exists and is valid
  const isValid = await qrService.verifyTokenValidity(token);

  if (!isValid) {
    throw new ApiError(400, 'Invalid or expired QR token');
  }

  res.json(
    new ApiResponse(200, { valid: true }, 'QR token is valid')
  );
});

/**
 * ⭐ NEW: Verify manual code validity (without connecting)
 * @route   POST /api/v1/qr/verify-manual
 * @desc    Check if manual code is valid (for preview/validation)
 * @access  Public (Elderly Device)
 */
const verifyManualCode = asyncHandler(async (req, res) => {
  const { manualCode } = req.body;

  if (!manualCode) {
    throw new ApiError(400, 'Manual code is required');
  }

  // Validate format
  if (!/^\d{6}$/.test(manualCode)) {
    throw new ApiError(400, 'Manual code must be exactly 6 digits');
  }

  // Check if code exists and is valid
  const isValid = await qrService.verifyManualCodeValidity(manualCode);

  if (!isValid) {
    throw new ApiError(400, 'Invalid or expired manual code');
  }

  res.json(
    new ApiResponse(200, { valid: true }, 'Manual code is valid')
  );
});

module.exports = {
  connectDevice,
  connectWithCode,
  verifyToken,        // ⭐ NEW
  verifyManualCode,   // ⭐ NEW
};