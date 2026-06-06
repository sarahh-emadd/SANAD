/**
 * pillbox.service.js
 *
 * All DB operations for the Smart Pillbox feature.
 *
 * Slots  — 3 fixed physical compartments (slot_number 1-3) per elderly.
 * Schedules — one or more daily times per slot (e.g. 08:00, 14:00, 21:00).
 * Logs   — one row per dose event created by the ESP32 (taken / missed).
 * Devices — ESP32 registration (identified by MAC address).
 */

const pool   = require('../config/database.config');
const logger = require('../utils/logger');

class PillboxService {

  // ══════════════════════════════════════════════════════════════════════════
  // SLOTS
  // ══════════════════════════════════════════════════════════════════════════

  /**
   * Get all 3 slots for an elderly person, each with its active schedules.
   * Creates the 3 default slot rows if they don't exist yet.
   */
  async getSlots(elderlyId) {
    // Auto-create the 3 slot rows on first call
    for (let n = 1; n <= 3; n++) {
      await pool.query(`
        INSERT INTO pill_slots (elderly_id, slot_number, medication_name, is_active)
        VALUES ($1, $2, '', false)
        ON CONFLICT (elderly_id, slot_number) DO NOTHING
      `, [elderlyId, n]);
    }

    const slots = await pool.query(`
      SELECT s.*,
             COALESCE(
               json_agg(
                 json_build_object(
                   'id',             sc.id,
                   'scheduled_time', TO_CHAR(sc.scheduled_time, 'HH24:MI'),
                   'label',          sc.label,
                   'is_active',      sc.is_active,
                   'start_date',     sc.start_date,
                   'end_date',       sc.end_date
                 ) ORDER BY sc.scheduled_time
               ) FILTER (WHERE sc.id IS NOT NULL),
               '[]'
             ) AS schedules
      FROM pill_slots s
      LEFT JOIN pill_schedules sc ON sc.slot_id = s.id AND sc.is_active = true
      WHERE s.elderly_id = $1
      GROUP BY s.id
      ORDER BY s.slot_number
    `, [elderlyId]);

    return slots.rows;
  }

  /**
   * Upsert a slot's medication name and active flag.
   */
  async updateSlot(elderlyId, slotNumber, { medication_name, notes, is_active }) {
    const result = await pool.query(`
      INSERT INTO pill_slots (elderly_id, slot_number, medication_name, notes, is_active, updated_at)
      VALUES ($1, $2, $3, $4, $5, NOW())
      ON CONFLICT (elderly_id, slot_number)
      DO UPDATE SET
        medication_name = EXCLUDED.medication_name,
        notes           = EXCLUDED.notes,
        is_active       = EXCLUDED.is_active,
        updated_at      = NOW()
      RETURNING *
    `, [elderlyId, slotNumber, medication_name ?? '', notes ?? null, is_active ?? true]);

    logger.info(`💊 Slot ${slotNumber} updated for elderly ${elderlyId}`);
    return result.rows[0];
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SCHEDULES
  // ══════════════════════════════════════════════════════════════════════════

  /**
   * Add a new daily schedule to a slot.
   * slotId  — UUID of the pill_slots row
   * time    — 'HH:MM' string  (e.g. '08:00')
   * label   — 'After Breakfast', 'After Dinner', …
   */
  async addSchedule(slotId, elderlyId, time, label, startDate, endDate) {
    const result = await pool.query(`
      INSERT INTO pill_schedules (slot_id, elderly_id, scheduled_time, label, start_date, end_date)
      VALUES ($1, $2, $3::TIME, $4, $5::DATE, $6::DATE)
      RETURNING id,
                slot_id,
                TO_CHAR(scheduled_time, 'HH24:MI') AS scheduled_time,
                label,
                is_active,
                start_date,
                end_date,
                created_at
    `, [slotId, elderlyId, time, label ?? null, startDate ?? null, endDate ?? null]);

    logger.info(`⏰ Schedule added: slot ${slotId} @ ${time} (${startDate ?? 'today'} → ${endDate ?? 'ongoing'})`);
    return result.rows[0];
  }

  /**
   * Update an existing schedule's time and/or label.
   */
  async updateSchedule(scheduleId, { time, label, is_active, start_date, end_date }) {
    const result = await pool.query(`
      UPDATE pill_schedules
      SET scheduled_time = COALESCE($2::TIME, scheduled_time),
          label          = COALESCE($3, label),
          is_active      = COALESCE($4, is_active),
          start_date     = COALESCE($5::DATE, start_date),
          end_date       = $6::DATE,
          updated_at     = NOW()
      WHERE id = $1
      RETURNING id,
                slot_id,
                TO_CHAR(scheduled_time, 'HH24:MI') AS scheduled_time,
                label,
                is_active,
                start_date,
                end_date
    `, [scheduleId, time ?? null, label ?? null, is_active ?? null,
        start_date ?? null, end_date ?? null]);

    if (!result.rows[0]) throw new Error('Schedule not found');
    return result.rows[0];
  }

  /**
   * Soft-delete a schedule (set is_active = false).
   */
  async deleteSchedule(scheduleId) {
    await pool.query(`
      UPDATE pill_schedules SET is_active = false, updated_at = NOW()
      WHERE id = $1
    `, [scheduleId]);
    logger.info(`🗑️ Schedule ${scheduleId} deactivated`);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TODAY'S SCHEDULE  (for ESP32 polling + elder home screen)
  // ══════════════════════════════════════════════════════════════════════════

  /**
   * Returns all active scheduled doses for today, merged with today's log status.
   * The ESP32 polls this every minute to know what LEDs/buzzer to activate.
   */
  async getTodaySchedule(elderlyId) {
    const result = await pool.query(`
      SELECT
        sc.id            AS schedule_id,
        sc.slot_id,
        ps.slot_number,
        ps.medication_name,
        TO_CHAR(sc.scheduled_time, 'HH24:MI') AS scheduled_time,
        sc.label,
        -- today's log for this schedule (NULL if not yet created by ESP32)
        pl.id            AS log_id,
        pl.status        AS dose_status,
        pl.scheduled_at,
        pl.taken_at
      FROM pill_schedules sc
      JOIN pill_slots ps ON ps.id = sc.slot_id
      LEFT JOIN pill_logs pl
        ON pl.schedule_id = sc.id
        AND DATE(pl.scheduled_at) = CURRENT_DATE
      WHERE sc.elderly_id = $1
        AND sc.is_active  = true
        AND ps.is_active  = true
        AND (sc.start_date IS NULL OR sc.start_date <= CURRENT_DATE)
        AND (sc.end_date   IS NULL OR sc.end_date   >= CURRENT_DATE)
      ORDER BY sc.scheduled_time
    `, [elderlyId]);

    return result.rows;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOGS  (written by ESP32)
  // ══════════════════════════════════════════════════════════════════════════

  /**
   * Create or update a pill_log row when the ESP32 reports a dose event.
   * status — 'taken' | 'missed'
   */
  async upsertLog(scheduleId, slotId, elderlyId, status, scheduledAt) {
    const result = await pool.query(`
      INSERT INTO pill_logs (schedule_id, slot_id, elderly_id, scheduled_at, status, taken_at)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT DO NOTHING
      RETURNING *
    `, [
      scheduleId,
      slotId,
      elderlyId,
      scheduledAt,
      status,
      status === 'taken' ? new Date() : null,
    ]);

    // If already exists, update status
    if (!result.rows[0]) {
      const upd = await pool.query(`
        UPDATE pill_logs
        SET status   = $2,
            taken_at = CASE WHEN $2 = 'taken' THEN NOW() ELSE taken_at END
        WHERE schedule_id = $1
          AND DATE(scheduled_at) = CURRENT_DATE
        RETURNING *
      `, [scheduleId, status]);
      return upd.rows[0];
    }

    return result.rows[0];
  }

  /**
   * Mark a log row as notified (so we don't double-notify).
   */
  async markNotified(logId) {
    await pool.query(`
      UPDATE pill_logs
      SET notified_caregiver = true, notified_at = NOW()
      WHERE id = $1
    `, [logId]);
  }

  /**
   * Get dose history for caregiver dashboard.
   */
  async getLogs(elderlyId, limit = 30, offset = 0) {
    const result = await pool.query(`
      SELECT
        pl.*,
        ps.slot_number,
        ps.medication_name,
        TO_CHAR(sc.scheduled_time, 'HH24:MI') AS scheduled_time,
        sc.label
      FROM pill_logs pl
      JOIN pill_slots     ps ON ps.id = pl.slot_id
      LEFT JOIN pill_schedules sc ON sc.id = pl.schedule_id
      WHERE pl.elderly_id = $1
      ORDER BY pl.scheduled_at DESC
      LIMIT $2 OFFSET $3
    `, [elderlyId, limit, offset]);

    return result.rows;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DEVICES  (ESP32 registration)
  // ══════════════════════════════════════════════════════════════════════════

  /**
   * Register or update an ESP32 device.
   */
  async registerDevice(elderlyId, deviceMac, firmwareVersion) {
    const result = await pool.query(`
      INSERT INTO pillbox_devices (elderly_id, device_mac, firmware_version, last_seen, is_online)
      VALUES ($1, $2, $3, NOW(), true)
      ON CONFLICT (device_mac)
      DO UPDATE SET
        elderly_id       = EXCLUDED.elderly_id,
        firmware_version = COALESCE(EXCLUDED.firmware_version, pillbox_devices.firmware_version),
        last_seen        = NOW(),
        is_online        = true,
        updated_at       = NOW()
      RETURNING *
    `, [elderlyId, deviceMac, firmwareVersion ?? null]);

    logger.info(`📦 Pillbox device registered: MAC ${deviceMac} → elderly ${elderlyId}`);
    return result.rows[0];
  }

  /**
   * Get the elderly_id linked to a device MAC (for ESP32 requests that
   * only send their MAC without knowing elderly_id yet).
   */
  async getElderlyByMac(deviceMac) {
    const result = await pool.query(`
      SELECT pd.*, e.first_name || ' ' || e.last_name AS elderly_name
      FROM pillbox_devices pd
      JOIN elderly e ON e.id = pd.elderly_id
      WHERE pd.device_mac = $1
    `, [deviceMac]);
    return result.rows[0] ?? null;
  }

  /**
   * Get caregiver FCM token for an elderly (needed to send pill notifications).
   */
  async getCaregiverFcm(elderlyId) {
    const result = await pool.query(`
      SELECT c.id AS caregiver_id, c.fcm_token,
             e.first_name || ' ' || e.last_name AS elderly_name
      FROM elderly e
      JOIN caregivers c ON c.id = e.caregiver_id
      WHERE e.id = $1
    `, [elderlyId]);
    return result.rows[0] ?? null;
  }
}

module.exports = new PillboxService();
