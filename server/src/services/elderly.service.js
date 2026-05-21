const pool = require('../config/database.config');
const qrService = require('./qr.service');
const ApiError = require('../utils/ApiError');
const logger = require('../utils/logger');

class ElderlyService {
  /**
   * Create elderly profile (all 4 steps)
   */
  async createElderly(caregiverId, data) {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      const result = await client.query(
        `INSERT INTO elderly (
          caregiver_id,
          first_name, last_name, date_of_birth, gender, blood_type, phone, photo_url,
          emergency_contact_name, emergency_contact_phone,
          emergency_contact_relationship, emergency_contact_email,
          address, city, state, postal_code, country,
          medical_conditions, allergies, current_medications,
          doctor_name, doctor_phone, hospital_preference,
          mobility_level, typical_sleep_time, typical_wake_time
        ) VALUES (
          $1,
          $2, $3, $4, $5, $6, $7, $8,
          $9, $10, $11, $12,
          $13, $14, $15, $16, $17,
          $18, $19, $20,
          $21, $22, $23,
          $24, $25, $26
        ) RETURNING *`,
        [
          caregiverId,
          data.first_name, data.last_name, data.date_of_birth, data.gender,
          data.blood_type || null, data.phone || null, data.photo_url || null,
          data.emergency_contact_name, data.emergency_contact_phone,
          data.emergency_contact_relationship || null, data.emergency_contact_email || null,
          data.address || null, data.city || null, data.state || null,
          data.postal_code || null, data.country || 'Egypt',
          data.medical_conditions || null, data.allergies || null, data.current_medications || null,
          data.doctor_name || null, data.doctor_phone || null, data.hospital_preference || null,
          data.mobility_level || null, data.typical_sleep_time || null, data.typical_wake_time || null,
        ]
      );

      const elderly = result.rows[0];

      // COMMIT first so elderly exists in DB before QR generation
      await client.query('COMMIT');

      logger.success(`Elderly created: ${elderly.first_name} ${elderly.last_name} (ID: ${elderly.id})`);

      const qrData = await qrService.generateQRToken(elderly.id);

      return {
        elderly,
        qrToken: qrData.qrToken,
        qrCodeData: qrData.qrCodeData,
        qrCodeImage: qrData.qrCodeImage,
        manualCode: qrData.manualCode,
        expiresAt: qrData.expiresAt,
        expiresIn: qrData.expiresIn,
      };
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('Failed to create elderly:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Get all elderly for a caregiver
   */
  async getAllByCaregiver(caregiverId) {
    const result = await pool.query(
      `SELECT 
        e.*,
        CASE WHEN ec.id IS NOT NULL THEN true ELSE false END as has_active_connection,
        ec.connected_at as last_connected_at
       FROM elderly e
       LEFT JOIN elderly_connections ec ON e.id = ec.elderly_id AND ec.disconnected_at IS NULL
       WHERE e.caregiver_id = $1 AND e.status = 'active'
       ORDER BY e.created_at DESC`,
      [caregiverId]
    );

    return result.rows;
  }

  /**
   * Get elderly by ID (with connection status)
   */
  async getById(elderlyId, caregiverId) {
    const result = await pool.query(
      `SELECT 
        e.*,
        ec.id as connection_id,
        ec.connected_at,
        qt.manual_code,
        qt.expires_at as qr_expires_at,
        qt.is_active as qr_is_active
       FROM elderly e
       LEFT JOIN elderly_connections ec ON e.id = ec.elderly_id AND ec.disconnected_at IS NULL
       LEFT JOIN qr_tokens qt ON e.id = qt.elderly_id AND qt.is_active = true AND qt.expires_at > NOW()
       WHERE e.id = $1 AND e.caregiver_id = $2`,
      [elderlyId, caregiverId]
    );

    if (result.rows.length === 0) {
      throw new ApiError(404, 'Elderly not found');
    }

    return result.rows[0];
  }

  /**
   * Get elderly with active QR code (for QR display screen)
   */
  async getElderlyWithQR(elderlyId, caregiverId) {
    const elderly = await this.getById(elderlyId, caregiverId);
    const activeQR = await qrService.getActiveQRToken(elderlyId);

    return {
      elderly,
      qr: activeQR,
      needsRegeneration: !activeQR,
    };
  }

  /**
   * Regenerate QR code for elderly
   */
  async regenerateQRCode(elderlyId, caregiverId) {
    const elderly = await this.getById(elderlyId, caregiverId);
    const qrData = await qrService.generateQRToken(elderlyId);

    logger.info(`QR code regenerated for elderly: ${elderly.first_name} ${elderly.last_name}`);

    return {
      elderly,
      qrToken: qrData.qrToken,
      qrCodeData: qrData.qrCodeData,
      qrCodeImage: qrData.qrCodeImage,
      manualCode: qrData.manualCode,
      expiresAt: qrData.expiresAt,
      expiresIn: qrData.expiresIn,
    };
  }

  /**
   * Update elderly profile (partial update — any field)
   */
  async updateElderly(elderlyId, caregiverId, updates) {
    const result = await pool.query(
      `UPDATE elderly SET
        first_name                    = COALESCE($1,  first_name),
        last_name                     = COALESCE($2,  last_name),
        date_of_birth                 = COALESCE($3,  date_of_birth),
        gender                        = COALESCE($4,  gender),
        blood_type                    = COALESCE($5,  blood_type),
        phone                         = COALESCE($6,  phone),
        photo_url                     = COALESCE($7,  photo_url),
        emergency_contact_name        = COALESCE($8,  emergency_contact_name),
        emergency_contact_phone       = COALESCE($9,  emergency_contact_phone),
        emergency_contact_relationship= COALESCE($10, emergency_contact_relationship),
        emergency_contact_email       = COALESCE($11, emergency_contact_email),
        address                       = COALESCE($12, address),
        city                          = COALESCE($13, city),
        state                         = COALESCE($14, state),
        postal_code                   = COALESCE($15, postal_code),
        country                       = COALESCE($16, country),
        medical_conditions            = COALESCE($17, medical_conditions),
        allergies                     = COALESCE($18, allergies),
        current_medications           = COALESCE($19, current_medications),
        doctor_name                   = COALESCE($20, doctor_name),
        doctor_phone                  = COALESCE($21, doctor_phone),
        hospital_preference           = COALESCE($22, hospital_preference),
        mobility_level                = COALESCE($23, mobility_level),
        typical_sleep_time            = COALESCE($24, typical_sleep_time),
        typical_wake_time             = COALESCE($25, typical_wake_time),
        updated_at                    = NOW()
       WHERE id = $26 AND caregiver_id = $27
       RETURNING *`,
      [
        updates.first_name, updates.last_name, updates.date_of_birth,
        updates.gender, updates.blood_type, updates.phone, updates.photo_url,
        updates.emergency_contact_name, updates.emergency_contact_phone,
        updates.emergency_contact_relationship, updates.emergency_contact_email,
        updates.address, updates.city, updates.state, updates.postal_code, updates.country,
        updates.medical_conditions, updates.allergies, updates.current_medications,
        updates.doctor_name, updates.doctor_phone, updates.hospital_preference,
        updates.mobility_level, updates.typical_sleep_time, updates.typical_wake_time,
        elderlyId, caregiverId,
      ]
    );

    if (result.rows.length === 0) {
      throw new ApiError(404, 'Elderly not found');
    }

    logger.info(`Elderly updated: ${result.rows[0].first_name} ${result.rows[0].last_name}`);

    return result.rows[0];
  }

  /**
   * Soft delete (archive) elderly
   */
  async deleteElderly(elderlyId, caregiverId) {
    await qrService.disconnectElderlyDevice(elderlyId, 'elderly_deleted');

    const result = await pool.query(
      `UPDATE elderly 
       SET status = 'archived', updated_at = NOW()
       WHERE id = $1 AND caregiver_id = $2
       RETURNING *`,
      [elderlyId, caregiverId]
    );

    if (result.rows.length === 0) {
      throw new ApiError(404, 'Elderly not found');
    }

    logger.info(`Elderly archived: ${result.rows[0].first_name} ${result.rows[0].last_name}`);

    return { message: 'Elderly archived successfully' };
  }

  /**
   * Update last seen timestamp (from elderly device heartbeat)
   */
  async updateLastSeen(elderlyId) {
    const result = await pool.query(
      `UPDATE elderly 
       SET last_seen = NOW(), updated_at = NOW()
       WHERE id = $1
       RETURNING id, first_name, last_name, last_seen`,
      [elderlyId]
    );

    if (result.rows.length === 0) {
      throw new ApiError(404, 'Elderly not found');
    }

    return result.rows[0];
  }

  /**
   * Get connection statistics for caregiver dashboard
   */
  async getConnectionStats(caregiverId) {
    const result = await pool.query(
      `SELECT 
        COUNT(*) FILTER (WHERE e.status = 'active')                          AS total_elderly,
        COUNT(*) FILTER (WHERE e.is_connected = true)                        AS connected_count,
        COUNT(*) FILTER (WHERE e.is_connected = false)                       AS disconnected_count,
        COUNT(*) FILTER (WHERE e.last_seen > NOW() - INTERVAL '1 hour')      AS active_last_hour,
        COUNT(*) FILTER (WHERE e.last_seen > NOW() - INTERVAL '24 hours')    AS active_last_day
       FROM elderly e
       WHERE e.caregiver_id = $1 AND e.status = 'active'`,
      [caregiverId]
    );

    return result.rows[0];
  }
}

module.exports = new ElderlyService();
