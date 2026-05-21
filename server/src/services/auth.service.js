const pool = require('../config/database.config');
const { auth } = require('../config/firebase.config');
const ApiError = require('../utils/ApiError');
const logger = require('../utils/logger');

class AuthService {
  /**
   * Create caregiver in database
   */
  async createCaregiver(caregiverData) {
    const { firebase_uid, email, first_name, last_name, phone } = caregiverData;

    const result = await pool.query(
      `INSERT INTO caregivers (firebase_uid, email, first_name, last_name, phone, email_verified)
       VALUES ($1, $2, $3, $4, $5, false)
       RETURNING id, firebase_uid, email, first_name, last_name, phone, email_verified, created_at`,
      [firebase_uid, email, first_name || null, last_name || null, phone || null]
    );

    logger.success(`New caregiver created: ${email} (ID: ${result.rows[0].id})`);

    return result.rows[0];
  }

  /**
   * Find caregiver by Firebase UID
   */
  async findByFirebaseUid(firebase_uid) {
    const result = await pool.query(
      `SELECT id, firebase_uid, email, first_name, last_name, phone, photo_url, email_verified, 
              fcm_token, status, created_at, updated_at
       FROM caregivers 
       WHERE firebase_uid = $1 AND status != 'deleted'`,
      [firebase_uid]
    );

    return result.rows[0] || null;
  }

  /**
   * Find caregiver by email
   */
  async findByEmail(email) {
    const result = await pool.query(
      `SELECT id, firebase_uid, email, first_name, last_name, phone, photo_url, email_verified, status
       FROM caregivers 
       WHERE LOWER(email) = LOWER($1) AND status != 'deleted'`,
      [email]
    );

    return result.rows[0] || null;
  }

  /**
   * Check if email exists
   */
  async emailExists(email) {
    const result = await pool.query(
      `SELECT id FROM caregivers 
       WHERE LOWER(email) = LOWER($1) AND status != 'deleted'`,
      [email]
    );

    return result.rows.length > 0;
  }

  /**
   * Update caregiver profile
   */
  async updateProfile(firebase_uid, updates) {
    const { first_name, last_name, phone, photo_url } = updates;

    const result = await pool.query(
      `UPDATE caregivers 
       SET first_name = COALESCE($1, first_name),
           last_name = COALESCE($2, last_name),
           phone = COALESCE($3, phone),
           photo_url = COALESCE($4, photo_url),
           updated_at = NOW()
       WHERE firebase_uid = $5 AND status != 'deleted'
       RETURNING id, firebase_uid, email, first_name, last_name, phone, photo_url, email_verified, created_at, updated_at`,
      [first_name, last_name, phone, photo_url, firebase_uid]
    );

    if (result.rows.length === 0) {
      throw new ApiError(404, 'User not found');
    }

    logger.info(`Profile updated: ${result.rows[0].email}`);

    return result.rows[0];
  }

  /**
   * Update FCM token
   */
  async updateFCMToken(firebase_uid, fcm_token) {
    const result = await pool.query(
      `UPDATE caregivers 
       SET fcm_token = $1, updated_at = NOW()
       WHERE firebase_uid = $2 AND status != 'deleted'
       RETURNING id, email`,
      [fcm_token, firebase_uid]
    );

    if (result.rows.length === 0) {
      throw new ApiError(404, 'User not found');
    }

    logger.info(`FCM token updated: ${result.rows[0].email}`);

    return result.rows[0];
  }

  /**
   * Update email verification status
   */
  async updateEmailVerification(firebase_uid, email_verified) {
    const result = await pool.query(
      `UPDATE caregivers 
       SET email_verified = $1, updated_at = NOW()
       WHERE firebase_uid = $2 AND status != 'deleted'
       RETURNING id, email, email_verified`,
      [email_verified, firebase_uid]
    );

    if (result.rows.length === 0) {
      throw new ApiError(404, 'User not found');
    }

    return result.rows[0];
  }

  /**
   * Verify Firebase UID is valid
   */
  async verifyFirebaseUser(firebase_uid) {
    try {
      const firebaseUser = await auth.getUser(firebase_uid);
      return firebaseUser;
    } catch (error) {
      logger.error(`Invalid Firebase UID: ${firebase_uid}`);
      throw new ApiError(400, 'Invalid Firebase user');
    }
  }

  /**
   * Get user statistics (elderly count)
   */
  async getUserStats(caregiver_id) {
    const result = await pool.query(
      `SELECT 
        COUNT(*) FILTER (WHERE status = 'active') as total_elderly,
        COUNT(*) FILTER (WHERE status = 'active' AND is_connected = true) as connected_elderly
       FROM elderly 
       WHERE caregiver_id = $1`,
      [caregiver_id]
    );

    return {
      total_elderly: parseInt(result.rows[0].total_elderly),
      connected_elderly: parseInt(result.rows[0].connected_elderly),
    };
  }

  /**
   * Soft delete user account
   */
  async deleteAccount(firebase_uid, caregiver_id) {
    const client = await pool.connect();

    try {
      await client.query('BEGIN');

      // Archive all elderly
      await client.query(
        `UPDATE elderly 
         SET status = 'archived', updated_at = NOW()
         WHERE caregiver_id = $1`,
        [caregiver_id]
      );

      // Soft delete caregiver
      const result = await client.query(
        `UPDATE caregivers 
         SET status = 'deleted', 
             email = CONCAT(email, '_deleted_', NOW()::text),
             fcm_token = NULL,
             updated_at = NOW()
         WHERE firebase_uid = $1
         RETURNING email`,
        [firebase_uid]
      );

      await client.query('COMMIT');

      logger.warn(`Account deleted: ${result.rows[0].email}`);

      return { message: 'Account deleted successfully' };
    } catch (error) {
      await client.query('ROLLBACK');
      throw error;
    } finally {
      client.release();
    }
  }

  /**
   * Refresh user data from Firebase
   */
  async refreshFromFirebase(firebase_uid) {
    // Get latest data from Firebase
    const firebaseUser = await this.verifyFirebaseUser(firebase_uid);

    // Update in database
    const result = await pool.query(
      `UPDATE caregivers 
       SET email = $1,
           email_verified = $2,
           updated_at = NOW()
       WHERE firebase_uid = $3 AND status != 'deleted'
       RETURNING id, firebase_uid, email, first_name, last_name, phone, photo_url, email_verified, created_at, updated_at`,
      [firebaseUser.email, firebaseUser.emailVerified, firebase_uid]
    );

    if (result.rows.length === 0) {
      throw new ApiError(404, 'User not found');
    }

    logger.info(`User data refreshed: ${firebaseUser.email}`);

    return result.rows[0];
  }
}

module.exports = new AuthService();