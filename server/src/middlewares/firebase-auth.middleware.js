const { auth } = require('../config/firebase.config');
const pool     = require('../config/database.config');
const ApiError = require('../utils/ApiError');
const logger   = require('../utils/logger');

const verifyFirebaseToken = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new ApiError(401, 'No token provided');
    }

    const idToken     = authHeader.split('Bearer ')[1];
    const decodedToken = await auth.verifyIdToken(idToken);
    const firebaseUid  = decodedToken.uid;

    // ── Look up caregiver in PostgreSQL ──────────────────────────────────────
    let result = await pool.query(
      "SELECT * FROM caregivers WHERE firebase_uid = $1 AND status != 'deleted'",
      [firebaseUid]
    );

    // ── Auto-create if this is a known Firebase user not yet in our DB ───────
    // This handles:
    //   • First login after a fresh DB (tables wiped / re-migrated)
    //   • Race condition where signup completed in Firebase but sync call failed
    if (result.rows.length === 0) {
      const email      = decodedToken.email || '';
      const name       = decodedToken.name  || '';
      const parts      = name.trim().split(/\s+/);
      const firstName  = parts[0]               || email.split('@')[0] || 'User';
      const lastName   = parts.slice(1).join(' ') || '';
      const emailVerified = decodedToken.email_verified || false;

      logger.warn(`Auto-creating caregiver for Firebase UID ${firebaseUid} (${email})`);

      result = await pool.query(
        `INSERT INTO caregivers (firebase_uid, email, first_name, last_name, email_verified)
         VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (firebase_uid) DO UPDATE
           SET email          = EXCLUDED.email,
               email_verified = EXCLUDED.email_verified,
               updated_at     = NOW()
         RETURNING *`,
        [firebaseUid, email, firstName, lastName, emailVerified]
      );

      logger.success(`Caregiver auto-created: ${email}`);
    }

    req.user      = result.rows[0];
    req.firebaseUid = firebaseUid;
    next();

  } catch (error) {
    if (error.code === 'auth/id-token-expired')  return next(new ApiError(401, 'Token expired'));
    if (error.code === 'auth/argument-error')    return next(new ApiError(401, 'Invalid token'));
    next(error);
  }
};

module.exports = { verifyFirebaseToken };
