const authService = require('../../../services/auth.service'); // ⭐ Import service
const ApiResponse = require('../../../utils/ApiResponse');
const asyncHandler = require('../../../utils/asyncHandler');
const ApiError = require('../../../utils/ApiError');
const logger = require('../../../utils/logger');

/**
 * @route   POST /api/v1/auth/sync
 * @desc    Sync Firebase user to PostgreSQL after signup
 * @access  Public
 */
const syncUser = asyncHandler(async (req, res) => {
  const { firebase_uid, email, first_name, last_name, phone } = req.body;

  // Validation
  if (!firebase_uid || !email) {
    throw new ApiError(400, 'Firebase UID and email are required');
  }
  if (!first_name || !last_name) {
    throw new ApiError(400, 'First name and last name are required');
  }

  // ⭐ Use service instead of direct query
  // Verify Firebase user
  await authService.verifyFirebaseUser(firebase_uid);

  // Check if user already exists
  const existing = await authService.findByFirebaseUid(firebase_uid);
  if (existing) {
    logger.info(`User already exists: ${email}`);
    return res.json(
      new ApiResponse(200, { user: existing }, 'User already exists')
    );
  }

  // Check if email already exists
  const emailExists = await authService.emailExists(email);
  if (emailExists) {
    throw new ApiError(409, 'Email already registered with different account');
  }

  // ⭐ Create user via service
  const user = await authService.createCaregiver({
    firebase_uid,
    email,
    first_name,
    last_name,
    phone,
  });

  res.status(201).json(
    new ApiResponse(201, { user }, 'User synced successfully')
  );
});

/**
 * @route   GET /api/v1/auth/me
 * @desc    Get current user profile
 * @access  Private
 */
const getMe = asyncHandler(async (req, res) => {
  // ⭐ Get stats via service
  const stats = await authService.getUserStats(req.user.id);

  res.json(
    new ApiResponse(200, {
      user: req.user,
      stats
    }, 'User profile retrieved')
  );
});

/**
 * @route   PUT /api/v1/auth/profile
 * @desc    Update user profile
 * @access  Private
 */
const updateProfile = asyncHandler(async (req, res) => {
  const { first_name, last_name, phone, photo_url } = req.body;

  // Validate phone format (optional) — accept local (0x) and international (+x) formats
  if (phone && !/^\+?[\d\s\-\(\)]{6,20}$/.test(phone)) {
    throw new ApiError(400, 'Invalid phone number format');
  }

  // ⭐ Update via service
  const user = await authService.updateProfile(req.firebaseUid, {
    first_name,
    last_name,
    phone,
    photo_url,
  });

  res.json(
    new ApiResponse(200, { user }, 'Profile updated successfully')
  );
});

/**
 * @route   POST /api/v1/auth/fcm-token
 * @desc    Update FCM token for push notifications
 * @access  Private
 */
const updateFCMToken = asyncHandler(async (req, res) => {
  const { fcm_token } = req.body;

  if (!fcm_token) {
    throw new ApiError(400, 'FCM token is required');
  }

  // ⭐ Update via service
  await authService.updateFCMToken(req.firebaseUid, fcm_token);

  res.json(
    new ApiResponse(200, null, 'FCM token updated successfully')
  );
});

/**
 * @route   POST /api/v1/auth/verify-email
 * @desc    Sync email verification status from Firebase
 * @access  Private
 */
const verifyEmail = asyncHandler(async (req, res) => {
  // ⭐ Get Firebase user via service
  const firebaseUser = await authService.verifyFirebaseUser(req.firebaseUid);

  // ⭐ Update via service
  const result = await authService.updateEmailVerification(
    req.firebaseUid,
    firebaseUser.emailVerified
  );

  res.json(
    new ApiResponse(
      200,
      { email_verified: result.email_verified },
      firebaseUser.emailVerified
        ? 'Email verified successfully'
        : 'Email not yet verified'
    )
  );
});

/**
 * @route   DELETE /api/v1/auth/account
 * @desc    Delete user account (soft delete)
 * @access  Private
 */
const deleteAccount = asyncHandler(async (req, res) => {
  // ⭐ Delete via service
  await authService.deleteAccount(req.firebaseUid, req.user.id);

  res.json(
    new ApiResponse(200, null, 'Account deleted successfully')
  );
});

/**
 * @route   POST /api/v1/auth/refresh
 * @desc    Refresh user data from Firebase
 * @access  Private
 */
const refreshUser = asyncHandler(async (req, res) => {
  // ⭐ Refresh via service
  const user = await authService.refreshFromFirebase(req.firebaseUid);

  res.json(
    new ApiResponse(200, { user }, 'User data refreshed')
  );
});

/**
 * @route   POST /api/v1/auth/check-email
 * @desc    Check if email is already registered
 * @access  Public
 */
const checkEmail = asyncHandler(async (req, res) => {
  const { email } = req.body;

  if (!email) {
    throw new ApiError(400, 'Email is required');
  }

  // ⭐ Check via service
  const exists = await authService.emailExists(email);

  res.json(
    new ApiResponse(200, { exists }, 'Email check completed')
  );
});

module.exports = {
  syncUser,
  getMe,
  updateProfile,
  updateFCMToken,
  verifyEmail,
  deleteAccount,
  refreshUser,
  checkEmail,
};