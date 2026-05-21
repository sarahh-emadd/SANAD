const elderlyService = require('../../../services/elderly.service');
const qrService = require('../../../services/qr.service');
const ApiResponse = require('../../../utils/ApiResponse');
const asyncHandler = require('../../../utils/asyncHandler');
const ApiError = require('../../../utils/ApiError');

/**
 * @route   POST /api/v1/elderly
 * @desc    Create elderly profile and generate QR code
 * @access  Private (Caregiver)
 */
const create = asyncHandler(async (req, res) => {
  const caregiverId = req.user.id;
  const {
    // Step 1 — Basic Info
    first_name,
    last_name,
    date_of_birth,
    gender,
    blood_type,
    phone,
    photo_url,
    // Step 2 — Emergency Contact
    emergency_contact_name,
    emergency_contact_phone,
    emergency_contact_relationship,
    emergency_contact_email,
    // Step 3 — Address
    address,
    city,
    state,
    postal_code,
    country,
    // Step 4 — Medical & Routine
    medical_conditions,
    allergies,
    current_medications,
    doctor_name,
    doctor_phone,
    hospital_preference,
    mobility_level,
    typical_sleep_time,
    typical_wake_time,
  } = req.body;

  // Validation
  if (!first_name || first_name.trim().length === 0) {
    throw new ApiError(400, 'First name is required');
  }
  if (!last_name || last_name.trim().length === 0) {
    throw new ApiError(400, 'Last name is required');
  }
  if (!date_of_birth) {
    throw new ApiError(400, 'Date of birth is required');
  }
  if (!emergency_contact_name || !emergency_contact_phone) {
    throw new ApiError(400, 'Emergency contact name and phone are required');
  }

  const result = await elderlyService.createElderly(caregiverId, {
    first_name: first_name.trim(),
    last_name: last_name.trim(),
    date_of_birth,
    gender,
    blood_type,
    phone,
    photo_url,
    emergency_contact_name,
    emergency_contact_phone,
    emergency_contact_relationship,
    emergency_contact_email,
    address,
    city,
    state,
    postal_code,
    country,
    medical_conditions,
    allergies,
    current_medications,
    doctor_name,
    doctor_phone,
    hospital_preference,
    mobility_level,
    typical_sleep_time,
    typical_wake_time,
  });

  res.status(201).json(
    new ApiResponse(201, result, 'Elderly profile created. QR code is valid for 5 minutes.')
  );
});

/**
 * @route   GET /api/v1/elderly
 * @desc    Get all elderly for logged-in caregiver
 * @access  Private (Caregiver)
 */
const getAll = asyncHandler(async (req, res) => {
  const caregiverId = req.user.id;
  const elderly = await elderlyService.getAllByCaregiver(caregiverId);

  res.json(new ApiResponse(200, { elderly, count: elderly.length }, 'Elderly list retrieved'));
});

/**
 * @route   GET /api/v1/elderly/:id
 * @desc    Get single elderly with connection status
 * @access  Private (Caregiver)
 */
const getById = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const caregiverId = req.user.id;

  const elderly = await elderlyService.getById(id, caregiverId);

  res.json(new ApiResponse(200, { elderly }, 'Elderly retrieved'));
});

/**
 * @route   GET /api/v1/elderly/:id/qr
 * @desc    Get elderly with current QR code (for displaying)
 * @access  Private (Caregiver)
 */
const getWithQR = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const caregiverId = req.user.id;

  const result = await elderlyService.getElderlyWithQR(id, caregiverId);

  res.json(
    new ApiResponse(
      200,
      result,
      result.needsRegeneration
        ? 'No active QR code. Please generate a new one.'
        : 'QR code retrieved successfully'
    )
  );
});

/**
 * @route   POST /api/v1/elderly/:id/regenerate-qr
 * @desc    Regenerate QR code for elderly
 * @access  Private (Caregiver)
 */
const regenerateQR = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const caregiverId = req.user.id;

  const result = await elderlyService.regenerateQRCode(id, caregiverId);

  res.json(new ApiResponse(200, result, 'New QR code generated. Valid for 5 minutes.'));
});

/**
 * @route   PUT /api/v1/elderly/:id
 * @desc    Update elderly profile
 * @access  Private (Caregiver)
 */
const update = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const caregiverId = req.user.id;

  const {
    first_name, last_name, date_of_birth, gender, blood_type, phone, photo_url,
    emergency_contact_name, emergency_contact_phone, emergency_contact_relationship, emergency_contact_email,
    address, city, state, postal_code, country,
    medical_conditions, allergies, current_medications,
    doctor_name, doctor_phone, hospital_preference,
    mobility_level, typical_sleep_time, typical_wake_time,
  } = req.body;

  if (first_name !== undefined && first_name.trim().length === 0) {
    throw new ApiError(400, 'First name cannot be empty');
  }
  if (last_name !== undefined && last_name.trim().length === 0) {
    throw new ApiError(400, 'Last name cannot be empty');
  }

  const elderly = await elderlyService.updateElderly(id, caregiverId, {
    first_name: first_name?.trim(),
    last_name: last_name?.trim(),
    date_of_birth, gender, blood_type, phone, photo_url,
    emergency_contact_name, emergency_contact_phone, emergency_contact_relationship, emergency_contact_email,
    address, city, state, postal_code, country,
    medical_conditions, allergies, current_medications,
    doctor_name, doctor_phone, hospital_preference,
    mobility_level, typical_sleep_time, typical_wake_time,
  });

  res.json(new ApiResponse(200, { elderly }, 'Elderly profile updated successfully'));
});

/**
 * @route   DELETE /api/v1/elderly/:id
 * @desc    Archive elderly
 * @access  Private (Caregiver)
 */
const deleteElderly = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const caregiverId = req.user.id;

  await elderlyService.deleteElderly(id, caregiverId);

  res.json(new ApiResponse(200, null, 'Elderly archived successfully'));
});

/**
 * @route   POST /api/v1/elderly/:id/disconnect
 * @desc    Disconnect elderly device
 * @access  Private (Caregiver)
 */
const disconnectDevice = asyncHandler(async (req, res) => {
  const { id } = req.params;
  const caregiverId = req.user.id;

  await elderlyService.getById(id, caregiverId);
  await qrService.disconnectElderlyDevice(id, 'manual_disconnect');

  res.json(new ApiResponse(200, null, 'Device disconnected successfully'));
});

/**
 * @route   GET /api/v1/elderly/stats
 * @desc    Get connection stats for caregiver dashboard
 * @access  Private (Caregiver)
 */
const getStats = asyncHandler(async (req, res) => {
  const caregiverId = req.user.id;
  const stats = await elderlyService.getConnectionStats(caregiverId);

  res.json(new ApiResponse(200, { stats }, 'Statistics retrieved successfully'));
});

/**
 * @route   POST /api/v1/elderly/:id/heartbeat
 * @desc    Update elderly device last seen timestamp
 * @access  Public (Elderly Device)
 */
const updateHeartbeat = asyncHandler(async (req, res) => {
  const { id } = req.params;

  const result = await elderlyService.updateLastSeen(id);

  res.json(new ApiResponse(200, { last_seen: result.last_seen }, 'Heartbeat updated'));
});

module.exports = {
  create,
  getAll,
  getById,
  getWithQR,
  regenerateQR,
  update,
  deleteElderly,
  disconnectDevice,
  getStats,
  updateHeartbeat,
};
