const pool = require('../config/database.config');
const minioService = require('./minio.service');
const ApiError = require('../utils/ApiError');
const logger = require('../utils/logger');

class EventsService {
  /**
   * Create a new event (called by Python AI detection)
   * Uploads snapshot to MinIO and saves event to DB
   */
  async createEvent(elderlyId, eventData) {
    const { event_type, confidence, snapshot_base64, pose_data } = eventData;

    let snapshot_url = null;

    // Upload snapshot to MinIO if provided
    if (snapshot_base64) {
      try {
        const imageBuffer = Buffer.from(snapshot_base64, 'base64');
        snapshot_url = await minioService.uploadSnapshot(
          elderlyId,
          imageBuffer,
          event_type
        );
      } catch (error) {
        logger.error('Snapshot upload failed, saving event without image:', error.message);
      }
    }

    // Save event to database
    const result = await pool.query(
      `INSERT INTO events
        (elderly_id, event_type, confidence, snapshot_url, pose_data)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING *`,
      [
        elderlyId,
        event_type,
        confidence,
        snapshot_url,
        pose_data ? JSON.stringify(pose_data) : null,
      ]
    );

    const event = result.rows[0];
    logger.warn(`⚠ Event created: ${event_type} for elderly_id: ${elderlyId}`);

    return event;
  }

  /**
   * Get all events for an elderly (for caregiver dashboard)
   * BUG FIX: was el.name — column doesn't exist, now uses first_name || last_name
   */
  async getEventsByElderly(elderlyId, limit = 20, offset = 0) {
    const result = await pool.query(
      `SELECT
        e.*,
        el.first_name || ' ' || el.last_name AS elderly_name
       FROM events e
       JOIN elderly el ON e.elderly_id = el.id
       WHERE e.elderly_id = $1
       ORDER BY e.created_at DESC
       LIMIT $2 OFFSET $3`,
      [elderlyId, limit, offset]
    );

    return result.rows;
  }

  /**
   * Get all unverified events for caregiver
   */
  async getUnverifiedEvents(caregiverId) {
    const result = await pool.query(
      `SELECT
        e.*,
        el.first_name || ' ' || el.last_name AS elderly_name
       FROM events e
       JOIN elderly el ON e.elderly_id = el.id
       WHERE el.caregiver_id = $1
       AND e.verified = false
       AND e.is_false_positive = false
       ORDER BY e.created_at DESC`,
      [caregiverId]
    );

    return result.rows;
  }

  /**
   * Mark event as verified or false positive
   */
  async verifyEvent(eventId, caregiverId, isFalsePositive = false) {
    const result = await pool.query(
      `UPDATE events
       SET verified = true,
           is_false_positive = $1,
           verified_by = $2,
           verified_at = NOW()
       WHERE id = $3
       RETURNING *`,
      [isFalsePositive, caregiverId, eventId]
    );

    if (result.rows.length === 0) {
      throw new ApiError(404, 'Event not found');
    }

    return result.rows[0];
  }

  /**
   * Mark alert as sent (called after FCM notification)
   */
  async markAlertSent(eventId) {
    await pool.query(
      `UPDATE events
       SET alert_sent = true,
           alert_sent_at = NOW()
       WHERE id = $1`,
      [eventId]
    );
  }

  /**
   * Get single event by ID
   * BUG FIX: was el.name — column doesn't exist, now uses first_name || last_name
   */
  async getEventById(eventId) {
    const result = await pool.query(
      `SELECT
        e.*,
        el.first_name || ' ' || el.last_name AS elderly_name,
        el.caregiver_id
       FROM events e
       JOIN elderly el ON e.elderly_id = el.id
       WHERE e.id = $1`,
      [eventId]
    );

    if (result.rows.length === 0) {
      throw new ApiError(404, 'Event not found');
    }

    return result.rows[0];
  }

  /**
   * Get event count by type for today — used by Flutter dashboard stats
   */
  async getTodayStats(elderlyId) {
    const result = await pool.query(
      `SELECT
        event_type,
        COUNT(*) AS count
       FROM events
       WHERE elderly_id = $1
       AND created_at >= CURRENT_DATE
       AND is_false_positive = false
       GROUP BY event_type`,
      [elderlyId]
    );

    const stats = { fall: 0, inactivity: 0, sleeping: 0, total: 0 };
    for (const row of result.rows) {
      stats[row.event_type] = parseInt(row.count);
      stats.total += parseInt(row.count);
    }
    return stats;
  }
}

module.exports = new EventsService();