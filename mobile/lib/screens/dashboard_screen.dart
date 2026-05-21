import 'dart:math' as math;
import 'package:flutter/material.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const primary    = Color(0xFF2FA884);
  static const primaryBg  = Color(0xFFE6F4F0);
  static const dangerRed  = Color(0xFFE53935);
  static const lightRed   = Color(0xFFFFF0EE);
  static const okGreen    = Color(0xFF388E3C);
  static const lightGreen = Color(0xFFEEF7EE);
  static const infoBlue   = Color(0xFF1976D2);
  static const infoBlueBg = Color(0xFFEBF3FD);
  static const warnOrange = Color(0xFFF57C00);
  static const warnBg     = Color(0xFFFFF8EE);
  static const purpleC    = Color(0xFF8B5CF6);
  static const purpleBg   = Color(0xFFF3EEFF);
  static const bgColor    = Color(0xFFF5F7F6);
  static const textDark   = Color(0xFF1A1A1A);
  static const textGrey   = Color(0xFFAAAAAA);

  static TextStyle m(double sz, FontWeight w, Color c) =>
      TextStyle(fontFamily: 'Montserrat', fontSize: sz, fontWeight: w, color: c);

  // Weekly adherence data — today is index 0 (Mon) up to Sun
  static const List<_DayBar> _week = [
    _DayBar('Mon', 0.75),
    _DayBar('Tue', 1.00),
    _DayBar('Wed', 0.33),
    _DayBar('Thu', 0.67),
    _DayBar('Fri', 1.00),
    _DayBar('Sat', 0.50),
    _DayBar('Sun', 0.00),
  ];

  @override
  Widget build(BuildContext context) {
    final todayIdx = DateTime.now().weekday - 1; // 0=Mon … 6=Sun

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        title: Text('Dashboard', style: m(18, FontWeight.w700, textDark)),
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new, size: 18, color: textDark),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Elder Profile Card ─────────────────────────────────────────────
          _whiteCard(child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: const BoxDecoration(color: primaryBg, shape: BoxShape.circle),
              child: const Icon(Icons.person, color: primary, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Margaret Johnson', style: m(15, FontWeight.w700, textDark)),
              const SizedBox(height: 4),
              Text('Last seen 2 mins ago', style: m(11, FontWeight.w500, textGrey)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: lightGreen, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: okGreen, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Online', style: m(11, FontWeight.w700, okGreen)),
              ]),
            ),
          ])),

          const SizedBox(height: 20),

          // ── Medication Tracking ────────────────────────────────────────────
          Text('Medication Tracking', style: m(15, FontWeight.w700, textDark)),
          const SizedBox(height: 10),
          _whiteCard(child: Column(children: [
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              // Donut chart
              SizedBox(
                width: 110, height: 110,
                child: CustomPaint(
                  painter: _DonutPainter(pct: 0.85, color: primary, bg: primaryBg),
                  child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('85%', style: m(18, FontWeight.w700, textDark)),
                    Text('Adherence', style: m(8, FontWeight.w500, textGrey)),
                  ])),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _dotStat(okGreen,   'Taken',   '18 doses'),
                const SizedBox(height: 10),
                _dotStat(dangerRed, 'Skipped', '3 doses'),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: 0.85, minHeight: 8,
                    backgroundColor: const Color(0xFFEEEEEE),
                    color: primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text('85% weekly adherence', style: m(10, FontWeight.w500, textGrey)),
              ])),
            ]),
          ])),

          const SizedBox(height: 20),

          // ── Weekly Adherence ───────────────────────────────────────────────
          Text('Weekly Adherence', style: m(15, FontWeight.w700, textDark)),
          const SizedBox(height: 10),
          _whiteCard(child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('This week', style: m(12, FontWeight.w500, textGrey)),
              Text('85% avg', style: m(12, FontWeight.w700, primary)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              height: 130,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _week.asMap().entries.map((e) =>
                    _bar(e.value, isToday: e.key == todayIdx)).toList(),
              ),
            ),
          ])),

          const SizedBox(height: 20),

          // ── Sleep / Falls / Activity ────────────────────────────────────────
          Text('Health Overview', style: m(15, FontWeight.w700, textDark)),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _healthTile(
              icon: Icons.bedtime_outlined,
              label: 'Sleep',
              value: '7h 15m',
              sub: 'Last night',
              iconColor: purpleC,
              iconBg: purpleBg,
            )),
            const SizedBox(width: 12),
            Expanded(child: _healthTile(
              icon: Icons.warning_amber_rounded,
              label: 'Falls',
              value: '0',
              sub: 'All Good',
              iconColor: okGreen,
              iconBg: lightGreen,
              badge: true,
            )),
          ]),
          const SizedBox(height: 12),
          _whiteCard(child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: infoBlueBg, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.directions_walk, color: infoBlue, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Activity Level', style: m(12, FontWeight.w500, textGrey)),
              Text('Normal', style: m(16, FontWeight.w700, infoBlue)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: infoBlueBg, borderRadius: BorderRadius.circular(20)),
              child: Text('On Track', style: m(11, FontWeight.w700, infoBlue)),
            ),
          ])),

          const SizedBox(height: 20),

          // ── Insights ────────────────────────────────────────────────────────
          Text('Insights', style: m(15, FontWeight.w700, textDark)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2FA884), Color(0xFF1D7D62)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.emoji_events_outlined, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Great improvement!', style: m(14, FontWeight.w700, Colors.white)),
                const SizedBox(height: 6),
                Text(
                  "Margaret's medication adherence has improved by 12% compared to last week. Keep encouraging her!",
                  style: m(12, FontWeight.w500, Colors.white70).copyWith(height: 1.5),
                ),
              ])),
            ]),
          ),

          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _dotStat(Color color, String label, String value) =>
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: m(10, FontWeight.w500, textGrey)),
          Text(value,  style: m(13, FontWeight.w700, textDark)),
        ]),
      ]);

  Widget _healthTile({
    required IconData icon,
    required String label,
    required String value,
    required String sub,
    required Color iconColor,
    required Color iconBg,
    bool badge = false,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 12),
          Text(label, style: m(11, FontWeight.w500, textGrey)),
          const SizedBox(height: 2),
          Text(value, style: m(20, FontWeight.w700, textDark)),
          const SizedBox(height: 6),
          if (badge)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(20)),
              child: Text(sub, style: m(10, FontWeight.w700, iconColor)),
            )
          else
            Text(sub, style: m(10, FontWeight.w500, textGrey)),
        ]),
      );

  Widget _bar(_DayBar d, {required bool isToday}) {
    final barH = d.pct * 90;
    Color col;
    if (d.pct >= 0.9)      col = okGreen;
    else if (d.pct >= 0.5) col = primary;
    else if (d.pct > 0)    col = warnOrange;
    else                   col = const Color(0xFFEEEEEE);

    return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
      if (d.pct > 0)
        Text('${(d.pct * 100).round()}%', style: m(8, FontWeight.w600, col))
      else
        const SizedBox(height: 12),
      const SizedBox(height: 4),
      Container(
        width: isToday ? 32 : 26,
        height: d.pct > 0 ? barH : 6,
        decoration: BoxDecoration(
          color: col,
          borderRadius: BorderRadius.circular(6),
          border: isToday ? Border.all(color: textDark, width: 2) : null,
        ),
      ),
      const SizedBox(height: 6),
      Text(d.day, style: m(9, FontWeight.w700, isToday ? textDark : textGrey)),
    ]);
  }

  Widget _whiteCard({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4))],
    ),
    child: child,
  );
}

// ── Donut chart painter ────────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final double pct;
  final Color color;
  final Color bg;
  const _DonutPainter({required this.pct, required this.color, required this.bg});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = math.min(cx, cy) - 8;
    const stroke = 12.0;
    const startAngle = -math.pi / 2;

    final bgPaint = Paint()
      ..color = bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(rect, 0, math.pi * 2, false, bgPaint);
    canvas.drawArc(rect, startAngle, math.pi * 2 * pct, false, fgPaint);
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.pct != pct;
}

class _DayBar {
  final String day;
  final double pct;
  const _DayBar(this.day, this.pct);
}
