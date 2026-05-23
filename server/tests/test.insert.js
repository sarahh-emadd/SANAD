require('dotenv').config();
const pool = require('../src/config/database.config');

async function seed() {
  try {
    console.log('🌱 Starting database seed...');

    // ⚡ 1. Clean tables (order matters for FK constraints)
    await pool.query(`
      TRUNCATE
        dose_events,
        sos_events,
        notifications,
        camera_events,
        camera_health_logs,
        slots,
        schedules,
        pillboxes,
        elderly_connections,
        qr_tokens,
        cameras,
        elderly,
        caregivers
      RESTART IDENTITY CASCADE;
    `);
    console.log('🧹 Tables truncated');

    // 2️⃣ Insert Caregivers
    const caregiversRes = await pool.query(`
      INSERT INTO caregivers (firebase_uid, email, name, phone, auth_provider)
      VALUES
        ($1, $2, $3, $4, $5),
        ($6, $7, $8, $9, $10)
      RETURNING *;
    `, [
      'uid_001', 'caregiver1@example.com', 'Sara Hassan', '01012345678', 'email',
      'uid_002', 'caregiver2@example.com', 'Omar Ali', '01087654321', 'email'
    ]);
    console.log('✅ Caregivers inserted:', caregiversRes.rows);

    // 3️⃣ Insert Elderly (linked to caregivers)
    const elderlyRes = await pool.query(`
      INSERT INTO elderly (caregiver_id, name, status)
      VALUES
        ($1, $2, 'active'),
        ($3, $4, 'active')
      RETURNING *;
    `, [
      caregiversRes.rows[0].id, 'Ahmed Hassan',
      caregiversRes.rows[1].id, 'Mona Ali'
    ]);
    console.log('✅ Elderly inserted:', elderlyRes.rows);

    // 4️⃣ Insert Pillboxes (linked to elderly)
    const pillboxesRes = await pool.query(`
      INSERT INTO pillboxes (elderly_id, device_id, device_secret, status)
      VALUES
        ($1, $2, $3, 'online'),
        ($4, $5, $6, 'offline')
      RETURNING *;
    `, [
      elderlyRes.rows[0].id, 'ESP32_001', 'secret001',
      elderlyRes.rows[1].id, 'ESP32_002', 'secret002'
    ]);
    console.log('✅ Pillboxes inserted:', pillboxesRes.rows);

    // 5️⃣ Insert Slots (1-4 per pillbox)
    const slotsRes = [];
    for (let i = 0; i < pillboxesRes.rows.length; i++) {
      for (let slotNum = 1; slotNum <= 4; slotNum++) {
        const slot = await pool.query(`
          INSERT INTO slots (pillbox_id, slot_number, medication_name, dosage, current_count)
          VALUES ($1, $2, $3, $4, $5)
          RETURNING *;
        `, [
          pillboxesRes.rows[i].id,
          slotNum,
          `Medication ${slotNum}`,
          `${slotNum} pill(s)`,
          10
        ]);
        slotsRes.push(slot.rows[0]);
      }
    }
    console.log('✅ Slots inserted:', slotsRes.length);

    // 6️⃣ Insert Schedules for each slot
    const schedulesRes = [];
    for (const slot of slotsRes) {
      const schedule = await pool.query(`
        INSERT INTO schedules (slot_id, time, days_of_week)
        VALUES ($1, $2, $3)
        RETURNING *;
      `, [
        slot.id,
        '08:00',
        '1234567' // daily
      ]);
      schedulesRes.push(schedule.rows[0]);
    }
    console.log('✅ Schedules inserted:', schedulesRes.length);

    // 7️⃣ Insert Dose Events
    const doseEventsRes = [];
    for (const schedule of schedulesRes) {
      const slot = slotsRes.find(s => s.id === schedule.slot_id);
      const dose = await pool.query(`
        INSERT INTO dose_events (schedule_id, slot_id, scheduled_time, status)
        VALUES ($1, $2, NOW(), 'pending')
        RETURNING *;
      `, [schedule.id, slot.id]);
      doseEventsRes.push(dose.rows[0]);
    }
    console.log('✅ Dose events inserted:', doseEventsRes.length);

    // 8️⃣ QR Tokens
    const qrRes = await pool.query(`
      INSERT INTO qr_tokens (elderly_id, token, manual_code, expires_at)
      VALUES
        ($1, 'QR123TOKEN1', '123456', NOW() + INTERVAL '30 days'),
        ($2, 'QR123TOKEN2', '654321', NOW() + INTERVAL '30 days')
      RETURNING *;
    `, [elderlyRes.rows[0].id, elderlyRes.rows[1].id]);
    console.log('✅ QR tokens inserted:', qrRes.rows);

    // 9️⃣ Elderly Connections
    const connRes = await pool.query(`
      INSERT INTO elderly_connections (elderly_id, qr_token_id, connected_at)
      VALUES
        ($1, $2, NOW()),
        ($3, $4, NOW())
      RETURNING *;
    `, [elderlyRes.rows[0].id, qrRes.rows[0].id, elderlyRes.rows[1].id, qrRes.rows[1].id]);
    console.log('✅ Elderly connections inserted:', connRes.rows);

    // 10️⃣ Cameras
    const camerasRes = await pool.query(`
      INSERT INTO cameras (elderly_id, camera_id, camera_secret, name)
      VALUES
        ($1, 'CAM001', 'secret_cam_001', 'Living Room Camera'),
        ($2, 'CAM002', 'secret_cam_002', 'Bedroom Camera')
      RETURNING *;
    `, [elderlyRes.rows[0].id, elderlyRes.rows[1].id]);
    console.log('✅ Cameras inserted:', camerasRes.rows);

    // 11️⃣ Camera Events (sample)
    const camEventsRes = await pool.query(`
      INSERT INTO camera_events (camera_id, elderly_id, event_type, confidence)
      VALUES ($1, $2, 'fall_detected', 0.85),
             ($3, $4, 'person_detected', 0.95)
      RETURNING *;
    `, [camerasRes.rows[0].id, elderlyRes.rows[0].id, camerasRes.rows[1].id, elderlyRes.rows[1].id]);
    console.log('✅ Camera events inserted:', camEventsRes.rows);

    // 12️⃣ Notifications
    await pool.query(`
      INSERT INTO notifications (recipient_id, recipient_type, type, title, body)
      VALUES
        ($1, 'caregiver', 'missed_dose', 'Missed Dose', 'Ahmed Hassan missed a dose'),
        ($2, 'caregiver', 'refill_needed', 'Refill Needed', 'Mona Ali pillbox needs refill')
    `, [caregiversRes.rows[0].id, caregiversRes.rows[1].id]);
    console.log('✅ Notifications inserted');

    // 13️⃣ SOS Events
    await pool.query(`
      INSERT INTO sos_events (elderly_id, caregiver_id, location_lat, location_lng)
      VALUES
        ($1, $2, 30.0444, 31.2357),
        ($3, $4, 30.0500, 31.2333)
    `, [elderlyRes.rows[0].id, caregiversRes.rows[0].id, elderlyRes.rows[1].id, caregiversRes.rows[1].id]);
    console.log('✅ SOS events inserted');

    console.log('🎉 Database seeding complete!');
    process.exit(0);

  } catch (err) {
    console.error('❌ Seeding failed:', err);
    process.exit(1);
  }
}

seed();
