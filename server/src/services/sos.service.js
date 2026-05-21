/**
 * sos.service.js
 * DB operations for SOS requests.
 */

const pool   = require('../config/database.config');
const logger = require('../utils/logger');

class SosService {

  /**
   * Create a new SOS request and return it with caregiver_id + elderly_name.
   */
  async createSos(elderlyId, source = 'manual') {
    // Get caregiver_id from elderly table
    const elderlyResult = await pool.query(
      `SELECT e.id, e.caregiver_id,
              e.first_name || ' ' || e.last_name AS elderly_name
       FROM elderly e
       WHERE e.id = $1`,
      [elderlyId]
    );

    if (!elderlyResult.rows[0]) {
      throw new Error(`Elderly not found: ${elderlyId}`);
    }

    const { caregiver_id, elderly_name } = elderlyResult.rows[0];

    const validSource = ['manual', 'auto_fall'].includes(source) ? source : 'manual';

    // Insert SOS request
    const result = await pool.query(
      `INSERT INTO sos_requests (elderly_id, caregiver_id, status, source)
       VALUES ($1, $2, 'pending', $3)
       RETURNING *`,
      [elderlyId, caregiver_id, validSource]
    );

    const sos = result.rows[0];
    logger.info(`🆘 SOS created [${validSource}]: ${sos.id} — elderly: ${elderly_name}`);

    return { ...sos, caregiver_id, elderly_name };
  }

  /**
   * Caregiver acknowledges an SOS.
   */
  async acknowledgeSos(sosId, caregiverId) {
    const result = await pool.query(
      `UPDATE sos_requests
       SET status = 'acknowledged', acknowledged_at = NOW()
       WHERE id = $1 AND caregiver_id = $2
       RETURNING *`,
      [sosId, caregiverId]
    );

    if (!result.rows[0]) {
      throw new Error('SOS not found or not authorized');
    }

    logger.info(`✅ SOS acknowledged: ${sosId}`);
    return result.rows[0];
  }

  /**
   * Get SOS history for a caregiver.
   */
  async getSosHistory(caregiverId, limit = 20, offset = 0) {
    const result = await pool.query(
      `SELECT s.*,
              e.first_name || ' ' || e.last_name AS elderly_name
       FROM sos_requests s
       JOIN elderly e ON e.id = s.elderly_id
       WHERE s.caregiver_id = $1
       ORDER BY s.created_at DESC
       LIMIT $2 OFFSET $3`,
      [caregiverId, limit, offset]
    );

    return result.rows;
  }
}

module.exports = new SosService();