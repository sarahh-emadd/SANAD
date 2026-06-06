/**
 * messages.service.js
 *
 * Elder → Caregiver quick preset messages.
 * The elder taps a preset chip ("I'm okay", "Need medicine", etc.)
 * and the caregiver sees it in real-time via socket + notifications history.
 */

const pool   = require('../config/database.config');
const logger = require('../utils/logger');

// Preset message definitions (key → English + Arabic text)
const PRESET_MESSAGES = {
  im_okay:       { en: "I'm okay 😊",          ar: "أنا بخير 😊" },
  need_medicine: { en: "I need my medicine 💊", ar: "أحتاج دوائي 💊" },
  hungry:        { en: "I'm hungry 🍽️",         ar: "أنا جائع 🍽️" },
  tired:         { en: "I'm tired 😴",           ar: "أنا متعب 😴" },
  not_well:      { en: "I don't feel well 🤒",   ar: "لا أشعر بتحسن 🤒" },
};

class MessagesService {

  getPresets() {
    return PRESET_MESSAGES;
  }

  /**
   * Send a preset message from elder to their caregiver.
   */
  async sendPreset(elderlyId, messageKey) {
    const preset = PRESET_MESSAGES[messageKey];
    if (!preset) throw new Error(`Unknown message key: ${messageKey}`);

    // Look up caregiver_id
    const caregiverRes = await pool.query(`
      SELECT caregiver_id FROM elderly WHERE id = $1
    `, [elderlyId]);

    const caregiverId = caregiverRes.rows[0]?.caregiver_id ?? null;

    const result = await pool.query(`
      INSERT INTO elder_messages
        (elderly_id, caregiver_id, message_key, message_en, message_ar)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *
    `, [elderlyId, caregiverId, messageKey, preset.en, preset.ar]);

    logger.info(`💬 Preset message sent: elderly ${elderlyId} → "${messageKey}"`);
    return result.rows[0];
  }

  /**
   * Get all messages for a caregiver's elder (newest first, last 50).
   */
  async getMessagesForCaregiver(caregiverId, limit = 50) {
    const result = await pool.query(`
      SELECT em.*,
             e.first_name || ' ' || e.last_name AS elderly_name
      FROM elder_messages em
      JOIN elderly e ON e.id = em.elderly_id
      WHERE em.caregiver_id = $1
      ORDER BY em.created_at DESC
      LIMIT $2
    `, [caregiverId, limit]);

    return result.rows;
  }

  /**
   * Mark a message as read.
   */
  async markRead(messageId) {
    await pool.query(`
      UPDATE elder_messages
      SET is_read = true, read_at = NOW()
      WHERE id = $1
    `, [messageId]);
  }

  /**
   * Count unread messages for a caregiver.
   */
  async unreadCount(caregiverId) {
    const r = await pool.query(`
      SELECT COUNT(*) AS cnt
      FROM elder_messages
      WHERE caregiver_id = $1 AND is_read = false
    `, [caregiverId]);
    return parseInt(r.rows[0]?.cnt ?? 0);
  }
}

module.exports = { messagesService: new MessagesService(), PRESET_MESSAGES };
