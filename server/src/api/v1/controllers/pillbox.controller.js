/**
 * pillbox.controller.js
 *
 * Caregiver endpoints (Firebase auth required):
 *   GET  /pillbox/slots/:elderlyId         — get 3 slots with schedules
 *   PUT  /pillbox/slots/:elderlyId/:slotNo — update slot medication info
 *   POST /pillbox/schedules                — add a scheduled time to a slot
 *   PUT  /pillbox/schedules/:scheduleId    — update a schedule
 *   DEL  /pillbox/schedules/:scheduleId    — remove a schedule
 *   GET  /pillbox/logs/:elderlyId          — dose history
 *   GET  /pillbox/today/:elderlyId         — today's schedule + status
 *
 * ESP32 endpoints (no Firebase auth — identified by device_mac):
 *   POST /pillbox/device/register          — register ESP32
 *   GET  /pillbox/device/schedule          — get today's schedule
 *   POST /pillbox/device/report            — report dose taken / missed
 */

const pillboxService      = require('../../../services/pillbox.service');
const notificationService = require('../../../services/notification.service');
const ApiResponse         = require('../../../utils/ApiResponse');
const ApiError            = require('../../../utils/ApiError');
const asyncHandler        = require('../../../utils/asyncHandler');
const logger              = require('../../../utils/logger');

// ══════════════════════════════════════════════════════════════════════════════
// CAREGIVER — SLOTS
// ══════════════════════════════════════════════════════════════════════════════

/**
 * @route  GET /api/v1/pillbox/slots/:elderlyId
 * @desc   Get all 3 slots with their scheduled times.
 * @access Caregiver (Firebase auth)
 */
const getSlots = asyncHandler(async (req, res) => {
  const { elderlyId } = req.params;
  const slots = await pillboxService.getSlots(elderlyId);
  res.json(new ApiResponse(200, { slots }, 'Slots retrieved'));
});

/**
 * @route  PUT /api/v1/pillbox/slots/:elderlyId/:slotNumber
 * @desc   Update a slot's medication name, notes, is_active flag.
 * @access Caregiver (Firebase auth)
 * @body   { medication_name, notes, is_active }
 */
const updateSlot = asyncHandler(async (req, res) => {
  const { elderlyId, slotNumber } = req.params;
  const n = parseInt(slotNumber);
  if (![1, 2, 3].includes(n)) throw new ApiError(400, 'slot_number must be 1, 2, or 3');

  const slot = await pillboxService.updateSlot(elderlyId, n, req.body);
  res.json(new ApiResponse(200, { slot }, 'Slot updated'));
});

// ══════════════════════════════════════════════════════════════════════════════
// CAREGIVER — SCHEDULES
// ══════════════════════════════════════════════════════════════════════════════

/**
 * @route  POST /api/v1/pillbox/schedules
 * @desc   Add a new daily schedule to a slot.
 * @access Caregiver (Firebase auth)
 * @body   { slot_id, elderly_id, time: 'HH:MM', label }
 */
const addSchedule = asyncHandler(async (req, res) => {
  const { slot_id, elderly_id, time, label } = req.body;
  if (!slot_id || !elderly_id || !time) {
    throw new ApiError(400, 'slot_id, elderly_id, and time are required');
  }

  const schedule = await pillboxService.addSchedule(slot_id, elderly_id, time, label);
  res.status(201).json(new ApiResponse(201, { schedule }, 'Schedule added'));
});

/**
 * @route  PUT /api/v1/pillbox/schedules/:scheduleId
 * @desc   Update time / label / active state of an existing schedule.
 * @access Caregiver (Firebase auth)
 * @body   { time?, label?, is_active? }
 */
const updateSchedule = asyncHandler(async (req, res) => {
  const schedule = await pillboxService.updateSchedule(req.params.scheduleId, req.body);
  res.json(new ApiResponse(200, { schedule }, 'Schedule updated'));
});

/**
 * @route  DELETE /api/v1/pillbox/schedules/:scheduleId
 * @desc   Soft-delete a scheduled time (is_active = false).
 * @access Caregiver (Firebase auth)
 */
const deleteSchedule = asyncHandler(async (req, res) => {
  await pillboxService.deleteSchedule(req.params.scheduleId);
  res.json(new ApiResponse(200, {}, 'Schedule removed'));
});

// ══════════════════════════════════════════════════════════════════════════════
// CAREGIVER — LOGS & TODAY
// ══════════════════════════════════════════════════════════════════════════════

/**
 * @route  GET /api/v1/pillbox/logs/:elderlyId
 * @desc   Dose history (taken / missed / pending) for the caregiver dashboard.
 * @access Caregiver (Firebase auth)
 */
const getLogs = asyncHandler(async (req, res) => {
  const { limit = 30, offset = 0 } = req.query;
  const logs = await pillboxService.getLogs(
    req.params.elderlyId,
    parseInt(limit),
    parseInt(offset),
  );
  res.json(new ApiResponse(200, { logs, count: logs.length }, 'Dose logs retrieved'));
});

/**
 * @route  GET /api/v1/pillbox/today/:elderlyId
 * @desc   Today's full schedule with live dose status — for caregiver + elder screens.
 * @access Caregiver (Firebase auth)
 */
const getTodaySchedule = asyncHandler(async (req, res) => {
  const schedule = await pillboxService.getTodaySchedule(req.params.elderlyId);
  res.json(new ApiResponse(200, { schedule }, 'Today\'s schedule retrieved'));
});

// ══════════════════════════════════════════════════════════════════════════════
// ESP32 — DEVICE ENDPOINTS  (no Firebase auth)
// ══════════════════════════════════════════════════════════════════════════════

/**
 * @route  POST /api/v1/pillbox/device/register
 * @desc   ESP32 calls this on boot to register itself.
 * @access Public (ESP32 only)
 * @body   { elderly_id, device_mac, firmware_version? }
 */
const registerDevice = asyncHandler(async (req, res) => {
  const { elderly_id, device_mac, firmware_version } = req.body;
  if (!elderly_id || !device_mac) {
    throw new ApiError(400, 'elderly_id and device_mac are required');
  }

  const device = await pillboxService.registerDevice(elderly_id, device_mac, firmware_version);
  res.status(201).json(new ApiResponse(201, { device }, 'Device registered'));
});

/**
 * @route  GET /api/v1/pillbox/device/schedule?device_mac=XX:XX:XX&elderly_id=uuid
 * @desc   ESP32 polls this every 60s to get today's active schedule.
 *         Returns slot_number, scheduled_time (HH:MM), medication_name, status.
 * @access Public (ESP32 only)
 */
const getDeviceSchedule = asyncHandler(async (req, res) => {
  const { device_mac, elderly_id } = req.query;

  let resolvedElderlyId = elderly_id;

  // If elderly_id not provided, look it up by MAC
  if (!resolvedElderlyId && device_mac) {
    const device = await pillboxService.getElderlyByMac(device_mac);
    if (!device) throw new ApiError(404, 'Device not registered');
    resolvedElderlyId = device.elderly_id;
  }

  if (!resolvedElderlyId) throw new ApiError(400, 'elderly_id or device_mac required');

  const schedule = await pillboxService.getTodaySchedule(resolvedElderlyId);
  res.json(new ApiResponse(200, { schedule }, 'Schedule retrieved'));
});

/**
 * @route  POST /api/v1/pillbox/device/report
 * @desc   ESP32 reports when elder takes or misses a dose.
 *         This writes to pill_logs and sends FCM to caregiver.
 * @access Public (ESP32 only)
 * @body   { device_mac, elderly_id, schedule_id, slot_id, slot_number,
 *           scheduled_at, status: 'taken'|'missed' }
 */
const reportDose = asyncHandler(async (req, res) => {
  const {
    device_mac,
    elderly_id,
    schedule_id,
    slot_id,
    slot_number,
    scheduled_at,
    status,
  } = req.body;

  if (!elderly_id || !slot_id || !status || !scheduled_at) {
    throw new ApiError(400, 'elderly_id, slot_id, scheduled_at, and status are required');
  }
  if (!['taken', 'missed'].includes(status)) {
    throw new ApiError(400, 'status must be taken or missed');
  }

  // Write dose log
  const log = await pillboxService.upsertLog(
    schedule_id ?? null,
    slot_id,
    elderly_id,
    status,
    new Date(scheduled_at),
  );

  logger.info(`💊 Dose ${status}: slot ${slot_number} | elderly ${elderly_id}`);

  // Send FCM notification to caregiver (non-blocking)
  pillboxService.getCaregiverFcm(elderly_id)
    .then(async (row) => {
      if (!row?.fcm_token) return;

      const title = status === 'taken'
        ? `✅ Dose Taken — Slot ${slot_number}`
        : `⚠️ Dose Missed — Slot ${slot_number}`;

      const body = status === 'taken'
        ? `${row.elderly_name} took their medication from slot ${slot_number}.`
        : `${row.elderly_name} missed the dose from slot ${slot_number}. Please follow up.`;

      await notificationService.sendRawNotification(row.fcm_token, {
        title,
        body,
        data: {
          type:        'pill_dose',
          status,
          elderly_id,
          slot_number: String(slot_number),
          log_id:      String(log?.id ?? ''),
        },
      });

      if (log?.id) await pillboxService.markNotified(log.id);
    })
    .catch((err) => {
      logger.error(`Pill FCM error (non-fatal): ${err.message}`);
    });

  res.status(201).json(new ApiResponse(201, { log }, `Dose ${status} recorded`));
});

module.exports = {
  getSlots,
  updateSlot,
  addSchedule,
  updateSchedule,
  deleteSchedule,
  getLogs,
  getTodaySchedule,
  registerDevice,
  getDeviceSchedule,
  reportDose,
};
