const pool   = require('../config/database.config');
const logger = require('../utils/logger');

const connectedSessions = new Map();
const waitingCameras    = new Map();
const pendingCaregivers = new Map();

async function markCameraOffline(elderlyId) {
  try {
    await pool.query(
      `UPDATE cameras SET status='offline', updated_at=NOW()
       WHERE elderly_id=$1 AND status='online'`,
      [elderlyId]
    );
    logger.info(`📴 Camera offline — elderly: ${elderlyId}`);
  } catch (err) {
    logger.error(`DB markCameraOffline error: ${err.message}`);
  }
}

function init(io) {
  io.on('connection', (socket) => {
    logger.info(`🔌 Connected: ${socket.id}`);

    // ── STEP 1: Python registers as unassigned camera ─────────
    socket.on('register_camera', (data) => {
      const camera_device_id = data?.camera_device_id;
      if (!camera_device_id) {
        logger.warn(`❌ register_camera — missing camera_device_id`);
        return;
      }

      // Kick ANY existing socket with the same device ID — pool or elder room.
      // This handles zombie Python processes (old code still reconnecting).
      if (waitingCameras.has(camera_device_id)) {
        const staleId = waitingCameras.get(camera_device_id);
        if (staleId !== socket.id) {
          connectedSessions.delete(staleId);
          const stale = io.sockets.sockets.get(staleId);
          if (stale) stale.disconnect(true);
          logger.info(`🔄 Replaced stale pool entry for device: ${camera_device_id}`);
        }
        waitingCameras.delete(camera_device_id);
      }
      for (const [sid, session] of connectedSessions.entries()) {
        if (session.user_type === 'camera' && session.camera_device_id === camera_device_id && sid !== socket.id) {
          logger.info(`🔄 Kicking zombie elder-room camera for device: ${camera_device_id}`);
          connectedSessions.delete(sid);
          const stale = io.sockets.sockets.get(sid);
          if (stale) stale.disconnect(true);
          break;
        }
      }

      socket.camera_device_id = camera_device_id;
      waitingCameras.set(camera_device_id, socket.id);
      logger.info(`📷 Camera waiting — device: ${camera_device_id} | pool: ${waitingCameras.size}`);

      // ── FIX: re-assign immediately if a caregiver is already pending ──
      // Handles Python reconnecting after a drop — caregiver was already waiting
      // but the old Python socket died so assignment was lost.
      for (const [elderly_id, pending] of pendingCaregivers.entries()) {
        logger.info(`🔄 Re-assigning reconnected camera to elderly: ${elderly_id}`);
        io.to(socket.id).emit('camera_assigned', { elderly_id });
        waitingCameras.delete(camera_device_id);
        pendingCaregivers.delete(elderly_id);
        break;
      }
    });

    // ── STEP 2: Flutter assigns a camera to an elderly ────────
    socket.on('assign_camera_to_elderly', (data) => {
      const { elderly_id, camera_device_id } = data ?? {};
      if (!elderly_id) {
        logger.warn(`❌ assign_camera_to_elderly — missing elderly_id`);
        return;
      }

      let targetSocketId   = null;
      let assignedDeviceId = null;

      if (camera_device_id && waitingCameras.has(camera_device_id)) {
        targetSocketId   = waitingCameras.get(camera_device_id);
        assignedDeviceId = camera_device_id;
      } else {
        const first = Array.from(waitingCameras.entries())[0];
        if (first) { [assignedDeviceId, targetSocketId] = first; }
      }

      const caregiver_id = data?.caregiver_id ?? data?.sender_id;

      if (!targetSocketId) {
        pendingCaregivers.set(elderly_id, { socket_id: socket.id, caregiver_id });
        logger.warn(`⚠ No camera yet for elderly: ${elderly_id} — stored as pending (waiting for Python)`);
        // Do NOT emit camera_assignment_failed — Flutter stays connected
        // and will receive 'registered' when Python connects via Strategy 1
        return;
      }

      pendingCaregivers.set(elderly_id, { socket_id: socket.id, caregiver_id });
      io.to(targetSocketId).emit('camera_assigned', { elderly_id });
      logger.info(`✅ Camera ${assignedDeviceId} → elderly: ${elderly_id}`);
      waitingCameras.delete(assignedDeviceId);
      logger.info(`📷 Pool size: ${waitingCameras.size}`);
    });

    // ── STEP 3: Python registers with its elderly_id ──────────
    socket.on('register_elder', async (data) => {
      const elderly_id       = data?.elderly_id ?? data?.sender_id;
      const camera_device_id = data?.camera_device_id ?? null;
      if (!elderly_id) {
        logger.warn(`❌ register_elder — missing elderly_id`);
        return;
      }

      // 🧟 ZOMBIE REJECTION: only applies to sockets claiming to be a camera
      // (i.e. payload includes camera_device_id). A legitimate Python camera
      // ALWAYS calls register_camera first before getting assigned and calling
      // register_elder, so socket.camera_device_id is set.
      //
      // The elderly mobile app also calls register_elder, but WITHOUT a
      // camera_device_id — that case must pass through, otherwise the elder
      // can't receive sos_seen / send sos_call_offer.
      if (camera_device_id && !socket.camera_device_id) {
        logger.warn(`🧟 Rejecting zombie register_elder from ${socket.id} — claims camera ${camera_device_id} but never registered as pool`);
        socket.disconnect(true);
        return;
      }

      // Kick any stale session of the SAME type (camera or elder_app) for this
      // elderly. This handles zombie Python reconnects AND a stale elderly-app
      // socket lingering after the app was force-killed.
      // We delete from connectedSessions FIRST so the disconnect handler won't fire camera_offline.
      const incoming_type = camera_device_id ? 'camera' : 'elder_app';
      for (const [sid, session] of connectedSessions.entries()) {
        if (session.user_type === incoming_type && session.elderly_id === elderly_id && sid !== socket.id) {
          logger.info(`🔄 Replacing stale ${incoming_type} session for elderly: ${elderly_id}`);
          connectedSessions.delete(sid);
          const stale = io.sockets.sockets.get(sid);
          if (stale) stale.disconnect(true);
          break;
        }
      }

      // Save MAC address to cameras table (UPDATE only — row already exists from DB init)
      if (camera_device_id) {
        try {
          await pool.query(
            `UPDATE cameras SET camera_device_id = $1, status = 'online', updated_at = NOW()
             WHERE elderly_id = $2`,
            [camera_device_id, elderly_id]
          );
          logger.info(`📷 MAC ${camera_device_id} saved for elderly ${elderly_id}`);
        } catch (err) {
          logger.warn(`register_elder cameras UPDATE: ${err.message}`);
        }
      }

      let resolved_caregiver_id = pendingCaregivers.get(elderly_id)?.caregiver_id ?? null;

      if (!resolved_caregiver_id) {
        try {
          const result = await pool.query(
            'SELECT caregiver_id FROM elderly WHERE id = $1', [elderly_id]
          );
          resolved_caregiver_id = result.rows[0]?.caregiver_id ?? null;
        } catch (err) {
          logger.error(`register_elder DB lookup for caregiver_id failed: ${err.message}`);
        }
      }

      // Distinguish between the Python camera process and the elderly mobile app:
      // - Camera sends camera_device_id and went through register_camera first.
      // - Elderly app sends only elderly_id (no device_id).
      // Both join the elder_<id> room so they can receive SOS / signaling events,
      // but request_stream must only target a real camera, not the app.
      const user_type = camera_device_id ? 'camera' : 'elder_app';
      connectedSessions.set(socket.id, {
        socket_id:        socket.id,
        user_id:          elderly_id,
        user_type,
        elderly_id,
        caregiver_id:     resolved_caregiver_id,
        camera_device_id: camera_device_id ?? null,
      });
      socket.join(`elder_${elderly_id}`);

      // ── Update last_seen whenever elder app connects ──────────
      if (!camera_device_id) {
        pool.query(
          `UPDATE elderly SET last_seen = NOW(), updated_at = NOW() WHERE id = $1`,
          [elderly_id]
        ).catch(err => logger.warn(`last_seen update failed: ${err.message}`));
      }
      logger.info(`📷 Camera in room elder_${elderly_id} | caregiver: ${resolved_caregiver_id}`);

      // ACK to Python
      socket.emit('registered', {
        sender_id: 'server', recipient_id: elderly_id, status: 'ok', elderly_id,
      });

      // Strategy 1: pending caregiver already sent request_stream — fire it now
      const pending = pendingCaregivers.get(elderly_id);
      if (pending) {
        // Python just joined the elder room — send start_stream directly
        io.to(`elder_${elderly_id}`).emit('start_stream', {
          sender_id:    pending.caregiver_id,
          recipient_id: elderly_id,
          caregiver_id: pending.caregiver_id,
        });
        logger.info(`🚀 Fired pending start_stream → elder_${elderly_id} for caregiver ${pending.caregiver_id}`);
        pendingCaregivers.delete(elderly_id);
        return;
      }

      // Strategy 2: notify caregiver room so Flutter fires request_stream
      if (resolved_caregiver_id) {
        io.to(`caregiver_${resolved_caregiver_id}`).emit('registered', {
          sender_id: 'server', recipient_id: elderly_id, status: 'ok', elderly_id,
        });
        logger.info(`📣 Notified caregiver room ${resolved_caregiver_id} — camera ready`);
      }
    });

    // ── Flutter joins caregiver alert room ────────────────────
    socket.on('join_caregiver_room', (data) => {
      const caregiver_id = data?.caregiver_id ?? data?.sender_id;
      if (!caregiver_id) {
        logger.warn(`❌ join_caregiver_room — missing caregiver_id`);
        return;
      }
      connectedSessions.set(socket.id, {
        socket_id:  socket.id,
        user_id:    caregiver_id,
        user_type:  'caregiver',
        elderly_id: null,
      });
      socket.join(`caregiver_${caregiver_id}`);
      logger.info(`👤 Caregiver joined — id: ${caregiver_id}`);

      // ACK — carries caregiver_id so Flutter ignores it for request_stream
      socket.emit('registered', {
        sender_id: 'server', recipient_id: caregiver_id, status: 'ok', caregiver_id,
      });

      // ── Re-notify if camera already online ────────────────────
      for (const [, session] of connectedSessions.entries()) {
        if (session.user_type === 'camera' &&
            session.caregiver_id === caregiver_id &&
            session.elderly_id) {
          socket.emit('registered', {
            sender_id:    'server',
            recipient_id: session.elderly_id,
            status:       'ok',
            elderly_id:   session.elderly_id,
            // no caregiver_id field → Flutter fires request_stream
          });
          logger.info(`📣 Re-notified caregiver ${caregiver_id} — camera already online for elderly: ${session.elderly_id}`);
          break;
        }
      }
    });

    // ── WebRTC signaling — pure relay ─────────────────────────

    socket.on('request_stream', (data) => {
      const { sender_id, recipient_id } = data ?? {};
      if (!sender_id || !recipient_id) { logger.warn(`❌ request_stream missing IDs`); return; }
      const session = connectedSessions.get(socket.id);
      if (session) session.elderly_id = recipient_id;
      logger.info(`📹 Stream requested — caregiver: ${sender_id} → elderly: ${recipient_id}`);

      // Path 1: Python camera already registered for this elderly — forward directly.
      // We look it up by user_type=camera in connectedSessions instead of by room
      // size, because the elderly mobile app is also in the elder_<id> room (for
      // SOS) and we must not send start_stream to it.
      let cameraSocketId = null;
      for (const [sid, sess] of connectedSessions.entries()) {
        if (sess.user_type === 'camera' && sess.elderly_id === recipient_id) {
          cameraSocketId = sid;
          break;
        }
      }
      if (cameraSocketId) {
        io.to(cameraSocketId).emit('start_stream', {
          sender_id, recipient_id, caregiver_id: sender_id,
        });
        logger.info(`📡 start_stream sent directly to camera ${cameraSocketId} for elder_${recipient_id}`);
        return;
      }

      // Always store pending so register_elder can fire start_stream when Python arrives
      pendingCaregivers.set(recipient_id, { socket_id: socket.id, caregiver_id: sender_id });

      // Path 2: Python is in the waiting pool — assign it now
      const first = Array.from(waitingCameras.entries())[0];
      if (first) {
        const [deviceId, cameraSocketId] = first;
        io.to(cameraSocketId).emit('camera_assigned', { elderly_id: recipient_id });
        waitingCameras.delete(deviceId);
        logger.info(`🎯 Assigned pool camera ${deviceId} → elderly: ${recipient_id} (triggered by request_stream)`);
        return;
      }

      // Path 3: No Python at all yet — pending stored above, will fire when Python connects
      logger.warn(`⏳ No Python online for elder_${recipient_id} — stored as pending`);
    });

    socket.on('webrtc_offer', (data) => {
      const { sender_id, recipient_id, offer } = data ?? {};
      if (!sender_id || !recipient_id || !offer) { logger.warn(`❌ webrtc_offer missing fields`); return; }
      logger.info(`📡 Offer — elderly: ${sender_id} → caregiver: ${recipient_id}`);
      io.to(`caregiver_${recipient_id}`).emit('webrtc_offer', {
        sender_id, recipient_id, elderly_id: sender_id, caregiver_id: recipient_id, offer,
      });
    });

    socket.on('webrtc_answer', (data) => {
      const { sender_id, recipient_id, answer } = data ?? {};
      if (!sender_id || !recipient_id || !answer) { logger.warn(`❌ webrtc_answer missing fields`); return; }
      logger.info(`📡 Answer — caregiver: ${sender_id} → elderly: ${recipient_id}`);
      io.to(`elder_${recipient_id}`).emit('webrtc_answer', {
        sender_id, recipient_id, caregiver_id: sender_id, answer,
      });
    });

    socket.on('ice_candidate', (data) => {
      const { sender_id, recipient_id, candidate } = data ?? {};
      if (!sender_id || !candidate || !recipient_id) { logger.warn(`❌ ice_candidate missing fields`); return; }
      const session    = connectedSessions.get(socket.id);
      const senderType = session?.user_type ?? null;
      let targetRoom;
      if      (senderType === 'camera')    targetRoom = `caregiver_${recipient_id}`;
      else if (senderType === 'caregiver') targetRoom = `elder_${recipient_id}`;
      else { logger.warn(`❌ ice_candidate — sender not registered`); return; }
      io.to(targetRoom).emit('ice_candidate', {
        sender_id, recipient_id,
        caregiver_id: senderType === 'camera' ? sender_id : recipient_id,
        from_id: sender_id, candidate,
      });
    });

    socket.on('stop_stream', (data) => {
      const { sender_id, recipient_id } = data ?? {};
      const elderly_id = recipient_id ?? data?.elderly_id;
      if (!elderly_id) { logger.warn(`❌ stop_stream missing recipient_id`); return; }
      logger.info(`🛑 Stream stopped — caregiver: ${sender_id} | elderly: ${elderly_id}`);
      io.to(`elder_${elderly_id}`).emit('stop_stream', {
        sender_id, recipient_id: elderly_id, caregiver_id: sender_id,
      });
    });

    socket.on('sos_acknowledged', (data) => {
      const { sos_id, caregiver_id, elderly_id } = data ?? {};
      if (!sos_id || !elderly_id) { logger.warn(`❌ sos_acknowledged — missing fields`); return; }
      logger.info(`✅ SOS acknowledged — sos: ${sos_id} | caregiver: ${caregiver_id}`);
      io.to(`elder_${elderly_id}`).emit('sos_seen', {
        sender_id: 'server', sos_id, caregiver_id, elderly_id,
      });
    });

    socket.on('sos_call_offer', (data) => {
      const { elderly_id, caregiver_id, offer, elderly_name } = data ?? {};
      if (!elderly_id || !caregiver_id || !offer) { logger.warn('❌ sos_call_offer missing fields'); return; }
      logger.info(`📞 SOS call offer — elderly: ${elderly_id} → caregiver: ${caregiver_id}`);
      io.to(`caregiver_${caregiver_id}`).emit('sos_incoming_call', {
        elderly_id, caregiver_id, offer, elderly_name,
      });
    });

    socket.on('sos_call_answer', (data) => {
      const { elderly_id, caregiver_id, answer } = data ?? {};
      if (!elderly_id || !answer) { logger.warn('❌ sos_call_answer missing fields'); return; }
      logger.info(`📞 SOS call answered — caregiver: ${caregiver_id}`);
      io.to(`elder_${elderly_id}`).emit('sos_call_answered', { elderly_id, caregiver_id, answer });
    });

    socket.on('sos_call_declined', (data) => {
      const { elderly_id, caregiver_id } = data ?? {};
      if (!elderly_id) { logger.warn('❌ sos_call_declined missing elderly_id'); return; }
      logger.info(`📞 SOS call declined — caregiver: ${caregiver_id}`);
      io.to(`elder_${elderly_id}`).emit('sos_call_ended', { reason: 'declined' });
    });

    socket.on('sos_ice_candidate', (data) => {
      const { sender_id, recipient_id, recipient_type, candidate } = data ?? {};
      if (!candidate || !recipient_id) return;
      const room = recipient_type === 'caregiver'
        ? `caregiver_${recipient_id}`
        : `elder_${recipient_id}`;
      io.to(room).emit('sos_ice_candidate', { sender_id, recipient_id, candidate });
    });

    socket.on('sos_call_end', (data) => {
      const { elderly_id, caregiver_id } = data ?? {};
      logger.info(`📞 SOS call ended`);
      if (elderly_id)   io.to(`elder_${elderly_id}`).emit('sos_call_ended', { reason: 'ended' });
      if (caregiver_id) io.to(`caregiver_${caregiver_id}`).emit('sos_call_ended', { reason: 'ended' });
    });

    // ── Disconnect ────────────────────────────────────────────
    socket.on('disconnect', async (reason) => {
      if (socket.camera_device_id) {
        waitingCameras.delete(socket.camera_device_id);
        logger.info(`📷 Unassigned camera removed | pool: ${waitingCameras.size}`);
      }
      const session = connectedSessions.get(socket.id);
      if (!session) { logger.info(`🔌 Unregistered socket disconnected: ${socket.id}`); return; }
      logger.info(`🔌 Disconnected — ${session.user_type} | ${session.user_id} | ${reason}`);

      if (session.user_type === 'camera' && session.elderly_id) {
        await markCameraOffline(session.elderly_id);
        if (session.caregiver_id) {
          io.to(`caregiver_${session.caregiver_id}`).emit('camera_offline', {
            sender_id:    'server',
            recipient_id: session.caregiver_id,
            elderly_id:   session.elderly_id,
            reason,
          });
          logger.info(`📴 camera_offline → caregiver: ${session.caregiver_id}`);
        } else {
          logger.warn(`⚠ camera_offline could not be sent — caregiver_id unknown for elderly: ${session.elderly_id}`);
        }
      }

      if (session.user_type === 'caregiver' && session.elderly_id) {
        io.to(`elder_${session.elderly_id}`).emit('stop_stream', {
          sender_id:    session.user_id,
          recipient_id: session.elderly_id,
          caregiver_id: session.user_id,
          reason:       'caregiver_disconnected',
        });
      }
      connectedSessions.delete(socket.id);
    });
  });

  logger.info('✅ Socket.IO service initialized');
}

function emitAlert(io, caregiverId, payload) {
  io.to(`caregiver_${caregiverId}`).emit('new_alert', {
    sender_id: 'server', recipient_id: caregiverId, ...payload,
  });
}

function emitSosAlert(io, caregiverId, payload) {
  io.to(`caregiver_${caregiverId}`).emit('sos_alert', {
    sender_id: 'server', recipient_id: caregiverId, ...payload,
  });
  logger.info(`🆘 Socket SOS → caregiver: ${caregiverId}`);
}

module.exports = { init, emitAlert, emitSosAlert, connectedSessions };