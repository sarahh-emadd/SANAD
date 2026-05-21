const pool = require('../config/database.config');
const { messaging } = require('../config/firebase.config');
const crypto = require('crypto');
const QRCode = require('qrcode');
const ApiError = require('../utils/ApiError');
const logger = require('../utils/logger');

class QRService {
  /**
   * Generate QR token when caregiver adds elderly
   */
  async generateQRToken(elderlyId) {
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');

      // Revoke any existing active tokens for this elderly
      await client.query(
        `UPDATE qr_tokens 
         SET is_active = false, revoked_at = NOW()
         WHERE elderly_id = $1 AND is_active = true`,
        [elderlyId]
      );

      // Generate unique token and manual code
      const token = crypto.randomBytes(32).toString('hex');
      const manualCode = this.generateManualCode();
      
      const expiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

      // Create new QR token
      const result = await client.query(
        `INSERT INTO qr_tokens (elderly_id, token, manual_code, expires_at)
         VALUES ($1, $2, $3, $4)
         RETURNING *`,
        [elderlyId, token, manualCode, expiresAt]
      );

      await client.query('COMMIT');

      logger.info(`QR token generated for elderly_id: ${elderlyId}, expires in 5 minutes`);

      const qrCodeData = this.generateQRCodeData(token, manualCode);
      const qrCodeImage = await this.generateQRCodeImage(qrCodeData);

      return {
        qrToken: result.rows[0],
        qrCodeData: qrCodeData,
        qrCodeImage: qrCodeImage,
        manualCode: manualCode,
        expiresAt: expiresAt,
        expiresIn: '5 minutes',
      };
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('Failed to generate QR token:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Generate 6-digit manual code
   */
  generateManualCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  /**
   * Generate QR code data string
   */
  generateQRCodeData(token, manualCode) {
    return JSON.stringify({
      type: 'SANAD_ELDERLY_PAIRING',
      token,
      manualCode,
      version: '1.0',
    });
  }

  /**
   * Generate actual QR code image (base64)
   */
  async generateQRCodeImage(data) {
    try {
      const qrCodeBase64 = await QRCode.toDataURL(data, {
        errorCorrectionLevel: 'H',
        type: 'image/png',
        quality: 0.95,
        margin: 1,
        color: {
          dark: '#000000',
          light: '#FFFFFF'
        },
        width: 300,
      });

      logger.info('QR code image generated successfully');
      return qrCodeBase64;
    } catch (error) {
      logger.error('QR code image generation failed:', error);
      throw new ApiError(500, 'Failed to generate QR code image');
    }
  }

  /**
   * Get active QR token info (for caregiver to view/regenerate)
   */
  async getActiveQRToken(elderlyId) {
    const result = await pool.query(
      `SELECT * FROM qr_tokens 
       WHERE elderly_id = $1 
       AND is_active = true 
       AND expires_at > NOW()
       ORDER BY created_at DESC
       LIMIT 1`,
      [elderlyId]
    );

    if (result.rows.length === 0) {
      return null;
    }

    const qrToken = result.rows[0];
    const qrCodeData = this.generateQRCodeData(qrToken.token, qrToken.manual_code);
    const qrCodeImage = await this.generateQRCodeImage(qrCodeData);

    const now = new Date();
    const expiresAt = new Date(qrToken.expires_at);
    const remainingMinutes = Math.floor((expiresAt - now) / (60 * 1000));

    return {
      qrToken,
      qrCodeData,
      qrCodeImage,
      manualCode: qrToken.manual_code,
      expiresAt: qrToken.expires_at,
      remainingMinutes: remainingMinutes,
      expiresIn: `${remainingMinutes} minutes`,
    };
  }

  /**
   * Verify token validity without connecting
   */
  async verifyTokenValidity(token) {
    const result = await pool.query(
      `SELECT id FROM qr_tokens 
       WHERE token = $1 
       AND is_active = true 
       AND expires_at > NOW()`,
      [token]
    );

    return result.rows.length > 0;
  }

  /**
   * Verify manual code validity without connecting
   */
  async verifyManualCodeValidity(manualCode) {
    const result = await pool.query(
      `SELECT id FROM qr_tokens 
       WHERE manual_code = $1 
       AND is_active = true 
       AND expires_at > NOW()`,
      [manualCode]
    );

    return result.rows.length > 0;
  }

  /**
   * Verify and connect elderly device using QR token
   */
  async connectElderlyDevice(token, deviceToken) {
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');

      // Find valid QR token
      const qrResult = await client.query(
        `SELECT * FROM qr_tokens 
         WHERE token = $1 
         AND is_active = true 
         AND expires_at > NOW()`,
        [token]
      );

      if (qrResult.rows.length === 0) {
        throw new ApiError(400, 'Invalid or expired QR code');
      }

      const qrToken = qrResult.rows[0];

      // Check if elderly is already connected
      const existingConnection = await client.query(
        `SELECT * FROM elderly_connections 
         WHERE elderly_id = $1 AND disconnected_at IS NULL`,
        [qrToken.elderly_id]
      );

      // Disconnect old connection if exists
      if (existingConnection.rows.length > 0) {
        await client.query(
          `UPDATE elderly_connections 
           SET disconnected_at = NOW(), 
               disconnection_reason = 'new_connection'
           WHERE id = $1`,
          [existingConnection.rows[0].id]
        );
        logger.info(`Old connection replaced for elderly_id: ${qrToken.elderly_id}`);
      }

      // Update elderly with device token and connection status
      await client.query(
        `UPDATE elderly 
         SET device_token = $1, 
             is_connected = true, 
             last_seen = NOW(),
             updated_at = NOW()
         WHERE id = $2`,
        [deviceToken, qrToken.elderly_id]
      );

      // Mark QR token as used
      await client.query(
        `UPDATE qr_tokens 
         SET used_at = NOW(), is_active = false
         WHERE id = $1`,
        [qrToken.id]
      );

      // Create new connection record
      const connectionResult = await client.query(
        `INSERT INTO elderly_connections (elderly_id, qr_token_id, connected_at)
         VALUES ($1, $2, NOW())
         RETURNING *`,
        [qrToken.elderly_id, qrToken.id]
      );

      // Get elderly and caregiver info for notification
      // ✅ FIXED: added missing parameter [qrToken.elderly_id]
      const elderlyResult = await client.query(
        `SELECT e.*, 
         c.first_name || ' ' || c.last_name as caregiver_name, 
         c.fcm_token as caregiver_fcm_token
         FROM elderly e
         JOIN caregivers c ON e.caregiver_id = c.id
         WHERE e.id = $1`,
        [qrToken.elderly_id]
      );

      await client.query('COMMIT');

      const elderly = elderlyResult.rows[0];

      logger.success(`Device connected for elderly: ${elderly.name} (ID: ${elderly.id})`);

      // Send notification to caregiver
      if (elderly.caregiver_fcm_token) {
        await this.sendConnectionNotification(
          elderly.caregiver_fcm_token,
          elderly.name
        );
      }

      return {
        connection: connectionResult.rows[0],
        elderly: {
          id: elderly.id,
          name: elderly.name,
          first_name: elderly.first_name,
          last_name: elderly.last_name,
          caregiver_id: elderly.caregiver_id,
          photo_url: elderly.photo_url,
          is_connected: elderly.is_connected,
          last_seen: elderly.last_seen,
        },
        message: 'Device connected successfully',
      };
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('Device connection failed:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Connect using manual 6-digit code
   */
  async connectWithManualCode(manualCode, deviceToken) {
    logger.info(`Attempting manual code connection with code: ${manualCode}`);

    // Use pool.query directly — no open transaction to interfere
    const result = await pool.query(
      `SELECT token FROM qr_tokens 
       WHERE manual_code = $1 
       AND is_active = true 
       AND expires_at > NOW()`,
      [manualCode]
    );

    if (result.rows.length === 0) {
      throw new ApiError(400, 'Invalid or expired manual code');
    }

    return await this.connectElderlyDevice(result.rows[0].token, deviceToken);
  }

  /**
   * Disconnect elderly device
   */
  async disconnectElderlyDevice(elderlyId, reason = 'manual_disconnect') {
    const client = await pool.connect();
    
    try {
      await client.query('BEGIN');

      await client.query(
        `UPDATE elderly 
         SET is_connected = false, 
             device_token = NULL,
             updated_at = NOW()
         WHERE id = $1`,
        [elderlyId]
      );

      await client.query(
        `UPDATE elderly_connections 
         SET disconnected_at = NOW(),
             disconnection_reason = $1
         WHERE elderly_id = $2 AND disconnected_at IS NULL`,
        [reason, elderlyId]
      );

      await client.query(
        `UPDATE qr_tokens 
         SET is_active = false, revoked_at = NOW()
         WHERE elderly_id = $1 AND is_active = true`,
        [elderlyId]
      );

      await client.query('COMMIT');

      logger.info(`Device disconnected for elderly_id: ${elderlyId}, reason: ${reason}`);

      return { message: 'Device disconnected successfully' };
    } catch (error) {
      await client.query('ROLLBACK');
      logger.error('Device disconnection failed:', error);
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Send connection notification to caregiver
   */
  async sendConnectionNotification(caregiverFcmToken, elderlyName) {
    try {
      await messaging.send({
        token: caregiverFcmToken,
        notification: {
          title: 'Device Connected',
          body: `${elderlyName}'s device has been connected successfully`,
        },
        data: {
          type: 'ELDERLY_CONNECTED',
          elderly_name: elderlyName,
          timestamp: new Date().toISOString(),
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'device_connection',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
      });
      
      logger.info(`Connection notification sent for ${elderlyName}`);
    } catch (error) {
      logger.error('Failed to send connection notification:', error.message);
      // Don't throw - notification failure shouldn't break connection
    }
  }

  /**
   * Check and revoke expired tokens (cron job)
   */
  async revokeExpiredTokens() {
    const result = await pool.query(
      `UPDATE qr_tokens 
       SET is_active = false, revoked_at = NOW()
       WHERE is_active = true AND expires_at < NOW()
       RETURNING elderly_id, token, expires_at`
    );

    if (result.rowCount > 0) {
      logger.info(`Revoked ${result.rowCount} expired QR tokens`);
    }

    return {
      revokedCount: result.rowCount,
      tokens: result.rows,
    };
  }
}

module.exports = new QRService();