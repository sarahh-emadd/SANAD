/**
 * reports.service.js
 *
 * Generates weekly health report data for a caregiver.
 * The Flutter app receives this JSON and renders a PDF using the `pdf` package.
 */

const pool   = require('../config/database.config');
const logger = require('../utils/logger');

class ReportsService {

  /**
   * Generate a weekly summary for the given elderly person.
   * Returns a plain JS object — Flutter turns it into a PDF.
   *
   * @param {string} elderlyId
   * @param {Date}   weekEnd   — end of the report week (defaults to today)
   */
  async weeklyReport(elderlyId, weekEnd = new Date()) {
    const end   = new Date(weekEnd);
    end.setHours(23, 59, 59, 999);
    const start = new Date(end);
    start.setDate(start.getDate() - 6);
    start.setHours(0, 0, 0, 0);

    // ── Elder info ──────────────────────────────────────────────────────────
    const elderRes = await pool.query(`
      SELECT e.first_name || ' ' || e.last_name AS name,
             e.date_of_birth,
             c.first_name || ' ' || c.last_name AS caregiver_name
      FROM elderly e
      LEFT JOIN caregivers c ON c.id = e.caregiver_id
      WHERE e.id = $1
    `, [elderlyId]);
    const elder = elderRes.rows[0] ?? {};

    // ── Per-day pill adherence ──────────────────────────────────────────────
    const logsRes = await pool.query(`
      SELECT DATE(scheduled_at)::TEXT AS day,
             COUNT(*)                AS total,
             COUNT(*) FILTER (WHERE status = 'taken') AS taken,
             COUNT(*) FILTER (WHERE status = 'missed') AS missed
      FROM pill_logs
      WHERE elderly_id = $1
        AND scheduled_at BETWEEN $2 AND $3
      GROUP BY DATE(scheduled_at)
      ORDER BY day
    `, [elderlyId, start, end]);

    const dailyPills = logsRes.rows; // [{day, total, taken, missed}]

    const totalDoses  = dailyPills.reduce((s, r) => s + parseInt(r.total), 0);
    const takenDoses  = dailyPills.reduce((s, r) => s + parseInt(r.taken), 0);
    const adherencePct = totalDoses > 0 ? Math.round((takenDoses / totalDoses) * 100) : null;

    // ── Events summary (falls / inactivity / sleeping) ─────────────────────
    const eventsRes = await pool.query(`
      SELECT event_type, COUNT(*) AS cnt
      FROM events
      WHERE elderly_id = $1
        AND created_at BETWEEN $2 AND $3
      GROUP BY event_type
    `, [elderlyId, start, end]);

    const eventMap = {};
    eventsRes.rows.forEach(r => { eventMap[r.event_type] = parseInt(r.cnt); });

    // ── SOS count ──────────────────────────────────────────────────────────
    const sosRes = await pool.query(`
      SELECT COUNT(*) AS cnt FROM sos_requests
      WHERE elderly_id = $1 AND created_at BETWEEN $2 AND $3
    `, [elderlyId, start, end]);
    const sosCount = parseInt(sosRes.rows[0]?.cnt ?? 0);

    // ── Missed-dose streak (consecutive days with any missed) ──────────────
    let currentMissStreak = 0;
    for (let i = dailyPills.length - 1; i >= 0; i--) {
      if (parseInt(dailyPills[i].missed) > 0) currentMissStreak++;
      else break;
    }

    logger.info(`📊 Weekly report generated for elderly ${elderlyId}`);

    return {
      generated_at:  new Date().toISOString(),
      week_start:    start.toISOString().split('T')[0],
      week_end:      end.toISOString().split('T')[0],
      elderly_name:  elder.name ?? 'Unknown',
      caregiver_name: elder.caregiver_name ?? '',
      pills: {
        total_doses:   totalDoses,
        taken_doses:   takenDoses,
        missed_doses:  totalDoses - takenDoses,
        adherence_pct: adherencePct,
        daily:         dailyPills,
        miss_streak:   currentMissStreak,
      },
      events: {
        falls:       eventMap['fall']       ?? 0,
        inactivity:  eventMap['inactivity'] ?? 0,
        sleeping:    eventMap['sleeping']   ?? 0,
        restlessness: eventMap['night_restlessness'] ?? 0,
      },
      sos_count: sosCount,
    };
  }
}

module.exports = new ReportsService();
