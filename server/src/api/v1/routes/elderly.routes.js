const express = require('express');
const router  = express.Router();
const elderlyController = require('../controllers/elderly.controller');
const { verifyFirebaseToken } = require('../../../middlewares/firebase-auth.middleware');
const pool                = require('../../../config/database.config');
const ApiResponse         = require('../../../utils/ApiResponse');
const ApiError            = require('../../../utils/ApiError');
const asyncHandler        = require('../../../utils/asyncHandler');
const notificationService = require('../../../services/notification.service');
const logger              = require('../../../utils/logger');

// ── Haversine distance between two GPS points (returns metres) ────────────
function haversineMetres(lat1, lng1, lat2, lng2) {
  const R    = 6_371_000;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a    = Math.sin(dLat / 2) ** 2
             + Math.cos(lat1 * Math.PI / 180)
             * Math.cos(lat2 * Math.PI / 180)
             * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

// ── No-auth: Elder device needs caregiver_id after QR connect ─
// Called by Flutter elder app on startup to look up its caregiver
router.get('/:id/caregiver-id', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT e.caregiver_id,
              e.first_name || ' ' || e.last_name AS elderly_name,
              c.first_name || ' ' || c.last_name AS caregiver_name
       FROM elderly e
       JOIN caregivers c ON c.id = e.caregiver_id
       WHERE e.id = $1`,
      [req.params.id]
    );
    if (!result.rows[0]) return res.status(404).json({ message: 'Not found' });
    const r = result.rows[0];
    res.json({ data: {
      caregiver_id:   r.caregiver_id,
      caregiver_name: r.caregiver_name,
      elderly_name:   r.elderly_name,
    }});
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ── No-auth: Elder device pushes its GPS location + battery ───
router.put('/:id/location', async (req, res) => {
  const { latitude, longitude, address, is_home, battery_level } = req.body;
  if (latitude == null || longitude == null) {
    return res.status(400).json({ message: 'latitude and longitude are required' });
  }
  try {
    await pool.query(
      `INSERT INTO elder_locations (elderly_id, latitude, longitude, address, is_home, battery_level, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, NOW())
       ON CONFLICT (elderly_id) DO UPDATE SET
         latitude      = EXCLUDED.latitude,
         longitude     = EXCLUDED.longitude,
         address       = EXCLUDED.address,
         is_home       = EXCLUDED.is_home,
         battery_level = EXCLUDED.battery_level,
         updated_at    = NOW()`,
      [req.params.id, latitude, longitude, address || '', is_home ?? false, battery_level ?? null]
    );
    // Update last_seen on elderly record
    pool.query(`UPDATE elderly SET last_seen = NOW() WHERE id = $1`, [req.params.id]).catch(() => {});

    res.json({ success: true });

    // ── Geofence check (non-blocking — runs after response sent) ─────────
    setImmediate(async () => {
      try {
        const zoneRow = await pool.query(
          `SELECT * FROM elder_safe_zones
           WHERE elderly_id = $1 AND is_active = true`,
          [req.params.id]
        );
        if (zoneRow.rows.length === 0) return;

        const zone     = zoneRow.rows[0];
        const distance = haversineMetres(latitude, longitude,
                                         zone.center_lat, zone.center_lng);

        if (distance <= zone.radius_meters) return; // elder is safe

        // 5-minute cooldown — don't spam notifications
        if (zone.last_alerted_at) {
          const msSinceLast = Date.now() - new Date(zone.last_alerted_at).getTime();
          if (msSinceLast < 5 * 60 * 1000) return;
        }

        // Stamp cooldown timestamp first so parallel requests don't double-fire
        await pool.query(
          `UPDATE elder_safe_zones SET last_alerted_at = NOW()
           WHERE elderly_id = $1`,
          [req.params.id]
        );

        // Socket.IO — caregiver app open
        const io = req.app && req.app.get('io');
        if (io) {
          const cgRow = await pool.query(
            `SELECT caregiver_id FROM elderly WHERE id = $1`, [req.params.id]
          );
          if (cgRow.rows[0]) {
            io.to(`caregiver_${cgRow.rows[0].caregiver_id}`).emit('geofence_alert', {
              elderly_id:  req.params.id,
              distance_m:  Math.round(distance),
            });
          }
        }

        // FCM push — caregiver app in background / closed
        await notificationService.sendGeofenceAlert(req.params.id, distance);

      } catch (err) {
        logger.error('Geofence check error:', err.message);
      }

      // ── Battery low alert ─────────────────────────────────────────────────────
      if (battery_level != null && battery_level <= 15) {
        try {
          const locRow = await pool.query(
            `SELECT battery_alerted_at FROM elder_locations WHERE elderly_id = $1`,
            [req.params.id]
          );
          const lastAlert = locRow.rows[0]?.battery_alerted_at;
          const hourAgo = Date.now() - 60 * 60 * 1000;
          if (!lastAlert || new Date(lastAlert).getTime() < hourAgo) {
            await pool.query(
              `UPDATE elder_locations SET battery_alerted_at = NOW() WHERE elderly_id = $1`,
              [req.params.id]
            );
            await notificationService.sendBatteryAlert(req.params.id, battery_level);
          }
        } catch (err) {
          logger.error('Battery alert error:', err.message);
        }
      }
    });

  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ── All caregiver routes require Firebase auth ────────────────
router.use(verifyFirebaseToken);

// Stats must come BEFORE /:id to avoid being caught as an ID
router.get('/stats', elderlyController.getStats);

// ── CRUD ──────────────────────────────────────────────────────
router.post('/',                 elderlyController.create);
router.get('/',                  elderlyController.getAll);
router.get('/:id',               elderlyController.getById);
router.get('/:id/qr',            elderlyController.getWithQR);
router.post('/:id/regenerate-qr', elderlyController.regenerateQR);
router.put('/:id',               elderlyController.update);
router.delete('/:id',            elderlyController.deleteElderly);
router.post('/:id/disconnect',   elderlyController.disconnectDevice);

// ── Caregiver gets elder's latest location ────────────────────
router.get('/:id/location', asyncHandler(async (req, res) => {
  const result = await pool.query(
    `SELECT el.latitude, el.longitude, el.address, el.is_home, el.battery_level,
            el.updated_at AS last_updated,
            e.last_seen
     FROM elder_locations el
     JOIN elderly e ON e.id = el.elderly_id
     WHERE el.elderly_id = $1`,
    [req.params.id]
  );
  if (result.rows.length === 0) {
    throw new ApiError(404, 'Location not yet reported by elder device');
  }
  res.json(new ApiResponse(200, { location: result.rows[0] }));
}));

// ── Safe Zone: caregiver sets / gets / removes the geofence ──────────────
router.post('/:id/safe-zone', asyncHandler(async (req, res) => {
  const caregiverId = req.user.id;
  const { center_lat, center_lng, radius_meters } = req.body;

  if (center_lat == null || center_lng == null) {
    throw new ApiError(400, 'center_lat and center_lng are required');
  }
  const radius = parseInt(radius_meters) || 200;

  // Verify ownership
  const check = await pool.query(
    `SELECT id FROM elderly WHERE id = $1 AND caregiver_id = $2`,
    [req.params.id, caregiverId]
  );
  if (check.rows.length === 0) throw new ApiError(403, 'Elderly not found for this caregiver');

  const result = await pool.query(
    `INSERT INTO elder_safe_zones
       (elderly_id, caregiver_id, center_lat, center_lng, radius_meters, is_active, updated_at)
     VALUES ($1, $2, $3, $4, $5, true, NOW())
     ON CONFLICT (elderly_id) DO UPDATE SET
       caregiver_id  = EXCLUDED.caregiver_id,
       center_lat    = EXCLUDED.center_lat,
       center_lng    = EXCLUDED.center_lng,
       radius_meters = EXCLUDED.radius_meters,
       is_active     = true,
       last_alerted_at = NULL,
       updated_at    = NOW()
     RETURNING *`,
    [req.params.id, caregiverId, center_lat, center_lng, radius]
  );

  res.json(new ApiResponse(200, { safe_zone: result.rows[0] }, 'Safe zone saved'));
}));

router.get('/:id/safe-zone', asyncHandler(async (req, res) => {
  const result = await pool.query(
    `SELECT * FROM elder_safe_zones WHERE elderly_id = $1`,
    [req.params.id]
  );
  if (result.rows.length === 0) {
    return res.json(new ApiResponse(200, { safe_zone: null }, 'No safe zone set'));
  }
  res.json(new ApiResponse(200, { safe_zone: result.rows[0] }));
}));

router.delete('/:id/safe-zone', asyncHandler(async (req, res) => {
  await pool.query(
    `UPDATE elder_safe_zones SET is_active = false, updated_at = NOW()
     WHERE elderly_id = $1 AND caregiver_id = $2`,
    [req.params.id, req.user.id]
  );
  res.json(new ApiResponse(200, null, 'Safe zone removed'));
}));

// ── Schedule endpoint — called by Python on startup ───────────
// BUG FIX: was placed AFTER module.exports so Express never registered it.
// No Firebase auth — Python has no token, this is an internal service call.
router.get('/:id/schedule', async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, first_name, last_name, typical_wake_time, typical_sleep_time
       FROM elderly
       WHERE id = $1`,
      [req.params.id]
    );

    if (!result.rows[0]) {
      return res.status(404).json({ success: false, message: 'Elderly not found' });
    }

    const e = result.rows[0];

    res.json(new ApiResponse(200, {
      elderly_id:         e.id,
      name:               `${e.first_name} ${e.last_name}`,
      typical_wake_time:  e.typical_wake_time  || '08:00',
      typical_sleep_time: e.typical_sleep_time || '22:00',
    }, 'Schedule retrieved'));

  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;