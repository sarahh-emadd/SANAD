/**
 * notification.service.js
 *
 * Sends FCM push notifications to caregivers.
 *
 * Public API:
 *   sendEventAlert(elderlyId, eventType, confidence, eventId, snapshotUrl?)
 *   sendSosAlert(elderlyId, sosId)
 *
 * Internal:
 *   _getCaregiverRow(elderlyId)  — single DB query shared by both methods
 *   _send(token, message)        — actual FCM dispatch, shared by both methods
 *
 * Requires in .env:
 *   FIREBASE_PROJECT_ID
 *   FIREBASE_CLIENT_EMAIL
 *   FIREBASE_PRIVATE_KEY
 */

const admin  = require('firebase-admin');
const pool   = require('../config/database.config');
const logger = require('../utils/logger');

class NotificationService {

  // ── Public: fall / inactivity / sleeping ──────────────────────────────────

  /**
   * Send a push notification when the AI camera detects an event.
   *
   * @param {string} elderlyId
   * @param {string} eventType   'fall' | 'inactivity' | 'sleeping'
   * @param {number} confidence  0.0 – 1.0
   * @param {string} eventId
   * @param {string|null} snapshotUrl
   * @returns {{ success: boolean, messageId?: string }}
   */
  async sendEventAlert(elderlyId, eventType, confidence, eventId, snapshotUrl = null) {
    const row = await this._getCaregiverRow(elderlyId);
    if (!row) return { success: false };

    const title = this._eventTitle(eventType);
    const body  = this._eventBody(eventType, row.elderly_name, confidence);

    const message = {
      token: row.fcm_token,
      notification: { title, body },
      data: {
        // FCM data values must all be strings
        type:         'event_alert',
        event_id:     String(eventId),
        elderly_id:   String(elderlyId),
        event_type:   eventType,
        confidence:   String(Math.round(confidence * 100)),
        snapshot_url: snapshotUrl ?? '',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId:  'sanad_alerts',
          sound:      'default',
          priority:   'max',
          visibility: 'public',
        },
      },
      apns: {
        payload: {
          aps: {
            sound:            'default',
            badge:            1,
            contentAvailable: true,
          },
        },
      },
    };

    return this._send(message, `event:${eventType} | caregiver: ${row.caregiver_id}`);
  }

  // ── Public: SOS ───────────────────────────────────────────────────────────

  /**
   * Send an urgent push notification when the elder presses SOS.
   * Independent from sendEventAlert — different channel, different data shape.
   *
   * @param {string} elderlyId
   * @param {string} sosId
   * @returns {{ success: boolean, messageId?: string }}
   */
  // source = 'manual' | 'auto_fall'
  async sendSosAlert(elderlyId, sosId, source = 'manual') {
    const row = await this._getCaregiverRow(elderlyId);
    if (!row) return { success: false };

    const name      = row.elderly_name ?? 'Your elder';
    const isAutoFall = source === 'auto_fall';

    const title = isAutoFall
      ? '🚨 FALL DETECTED — Auto SOS!'
      : '🆘 SOS Emergency!';
    const body  = isAutoFall
      ? `${name}'s phone detected a fall. They may be unconscious — respond immediately!`
      : `${name} needs help right now! Tap to respond.`;

    const message = {
      token: row.fcm_token,
      notification: { title, body },
      data: {
        type:         'sos_alert',
        sos_id:       String(sosId),
        elderly_id:   String(elderlyId),
        elderly_name: row.elderly_name ?? '',
        source:       source,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId:  'sanad_sos',
          sound:      isAutoFall ? 'fall_alarm' : 'sos_alarm',
          priority:   'max',
          visibility: 'public',
        },
      },
      apns: {
        payload: {
          aps: {
            sound:            isAutoFall ? 'fall_alarm.aiff' : 'sos_alarm.aiff',
            badge:            1,
            contentAvailable: true,
          },
        },
        headers: { 'apns-priority': '10' },
      },
    };

    return this._send(message, `sos[${source}] | caregiver: ${row.caregiver_id}`);
  }

  // ── Public: Geofence breach ───────────────────────────────────────────────
  async sendGeofenceAlert(elderlyId, distanceMeters) {
    const row = await this._getCaregiverRow(elderlyId);
    if (!row) return { success: false };

    const name = row.elderly_name ?? 'Your elder';
    const km   = (distanceMeters / 1000).toFixed(1);

    const message = {
      token: row.fcm_token,
      notification: {
        title: '📍 Safe Zone Alert!',
        body:  `${name} has left the safe zone (${km} km away). Check their location now.`,
      },
      data: {
        type:         'geofence_alert',
        elderly_id:   String(elderlyId),
        elderly_name: row.elderly_name ?? '',
        distance_m:   String(Math.round(distanceMeters)),
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      android: {
        priority: 'high',
        notification: {
          channelId:  'sanad_alerts',
          sound:      'default',
          priority:   'max',
          visibility: 'public',
        },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1, contentAvailable: true } },
        headers: { 'apns-priority': '10' },
      },
    };

    return this._send(message, `geofence | caregiver: ${row.caregiver_id}`);
  }

  // ── Public: Battery low alert ─────────────────────────────────────────────
  async sendBatteryAlert(elderlyId, batteryLevel) {
    const row = await this._getCaregiverRow(elderlyId);
    if (!row) return { success: false };
    const message = {
      token: row.fcm_token,
      notification: {
        title: '🔋 Low Battery Warning',
        body: `${row.elderly_name}'s phone battery is at ${batteryLevel}%. Please remind them to charge.`,
      },
      data: { type: 'battery_alert', elderly_id: String(elderlyId), battery_level: String(batteryLevel), click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      android: { priority: 'high', notification: { channelId: 'sanad_alerts', sound: 'default' } },
      apns: { payload: { aps: { sound: 'default', badge: 1 } } },
    };
    return this._send(message, `battery_alert | caregiver: ${row.caregiver_id}`);
  }

  // ── Public: SOS escalation (not acknowledged in 5 min) ───────────────────
  async sendSosEscalation(elderlyId, sosId, emergencyContactName) {
    const row = await this._getCaregiverRow(elderlyId);
    if (!row) return { success: false };
    const name = row.elderly_name ?? 'Your elder';
    const contact = emergencyContactName ? ` Emergency contact: ${emergencyContactName}.` : '';
    const message = {
      token: row.fcm_token,
      notification: {
        title: '🚨 URGENT: SOS Not Acknowledged!',
        body: `${name}'s SOS has been waiting 5+ minutes.${contact} Please respond immediately!`,
      },
      data: { type: 'sos_escalation', sos_id: String(sosId), elderly_id: String(elderlyId), elderly_name: row.elderly_name ?? '', click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      android: { priority: 'high', notification: { channelId: 'sanad_sos', sound: 'default', priority: 'max', visibility: 'public' } },
      apns: { payload: { aps: { sound: 'default', badge: 1, contentAvailable: true } }, headers: { 'apns-priority': '10' } },
    };
    return this._send(message, `sos_escalation | caregiver: ${row.caregiver_id}`);
  }

  // ── Public: Raw notification (used by pillbox for pill taken/missed) ────────
  /**
   * Send an FCM notification with a known FCM token (no DB lookup needed).
   * @param {string} fcmToken
   * @param {{ title, body, data }} payload
   */
  async sendRawNotification(fcmToken, { title, body, data = {} }) {
    const message = {
      token: fcmToken,
      notification: { title, body },
      data: { ...data, click_action: 'FLUTTER_NOTIFICATION_CLICK' },
      android: {
        priority: 'high',
        notification: {
          channelId:  'sanad_alerts',
          sound:      'default',
          priority:   'high',
          visibility: 'public',
        },
      },
      apns: {
        payload: { aps: { sound: 'default', badge: 1, contentAvailable: true } },
      },
    };
    return this._send(message, `pill_notification | token: ${fcmToken.slice(0, 10)}…`);
  }

  // ── Private: shared DB lookup ─────────────────────────────────────────────

  /**
   * Fetch caregiver FCM token + elderly name in one query.
   * Returns null (and logs a warning) if anything is missing.
   *
   * @param {string} elderlyId
   * @returns {{ fcm_token, caregiver_id, elderly_name } | null}
   */
  async _getCaregiverRow(elderlyId) {
    const result = await pool.query(
      `SELECT
         c.fcm_token,
         c.id         AS caregiver_id,
         e.first_name AS elderly_name
       FROM elderly e
       JOIN caregivers c ON c.id = e.caregiver_id
       WHERE e.id = $1`,
      [elderlyId]
    );

    const row = result.rows[0];

    if (!row) {
      logger.warn(`⚠ FCM: no caregiver found for elderly ${elderlyId}`);
      return null;
    }
    if (!row.fcm_token) {
      logger.warn(`⚠ FCM: caregiver ${row.caregiver_id} has no FCM token`);
      return null;
    }

    return row;
  }

  // ── Private: shared FCM dispatch ─────────────────────────────────────────

  /**
   * Send one FCM message and return a normalised result object.
   * All error handling lives here — callers never need try/catch.
   *
   * @param {object} message   — fully-formed FCM message object
   * @param {string} logLabel  — human label for the log line
   * @returns {{ success: boolean, messageId?: string }}
   */
  async _send(message, logLabel) {
    try {
      const messageId = await admin.messaging().send(message);
      logger.info(`✅ FCM sent — ${logLabel} | id: ${messageId}`);
      return { success: true, messageId };
    } catch (error) {
      logger.error(`❌ FCM send failed — ${logLabel}: ${error.message}`);
      return { success: false, error: error.message };
    }
  }

  // ── Private: event alert copy helpers ────────────────────────────────────

  _eventTitle(eventType) {
    switch (eventType) {
      case 'fall':       return '🚨 Fall Detected!';
      case 'inactivity': return '⚠️ Inactivity Alert';
      case 'sleeping':   return '💤 Sleeping Alert';
      default:           return '⚠️ SANAD Alert';
    }
  }

  _eventBody(eventType, elderlyName, confidence) {
    const pct  = Math.round(confidence * 100);
    const name = elderlyName ?? 'your elder';

    switch (eventType) {
      case 'fall':
        return `${name} may have fallen (${pct}% confidence). Check now.`;
      case 'inactivity':
        return `${name} has not moved for a while (${pct}% confidence).`;
      case 'sleeping':
        return `${name} appears to be sleeping during awake hours (${pct}% confidence).`;
      default:
        return `Alert detected for ${name} (${pct}% confidence).`;
    }
  }
}

module.exports = new NotificationService();
