import 'dart:convert';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class DashboardScreen extends StatefulWidget {
  final String elderlyId;
  final String elderlyName;
  const DashboardScreen({
    super.key,
    required this.elderlyId,
    required this.elderlyName,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ── Colors ──────────────────────────────────────────────
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

  // ── State ────────────────────────────────────────────────
  bool _loading = true;

  // Medication stats
  int _takenTotal  = 0;
  int _missedTotal = 0;
  double _adherencePct = 0;

  // Weekly bars (Mon–Sun)
  final List<double> _weekPct = List.filled(7, 0);

  // Health
  int    _fallsToday    = 0;
  String _activityLevel = 'Normal';
  String _lastSeen      = '';
  bool   _isOnline      = false;

  // Insight message
  String _insightTitle   = '';
  String _insightMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<String?> _token() async {
    try { return await FirebaseAuth.instance.currentUser?.getIdToken(); }
    catch (_) { return null; }
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([_loadLogs(), _loadTodayStats(), _loadElderStatus()]);
    _buildInsight();
    if (mounted) setState(() => _loading = false);
  }

  // ── Pill logs — last 30 days ─────────────────────────────
  Future<void> _loadLogs() async {
    try {
      final token = await _token();
      final headers = token != null ? {'Authorization': 'Bearer $token'} : <String,String>{};
      final res = await http.get(
        Uri.parse(ApiConfig.pillboxLogs(widget.elderlyId)),
        headers: headers,
      ).timeout(ApiConfig.timeout);

      if (res.statusCode != 200) return;
      final logs = List<Map<String, dynamic>>.from(
          jsonDecode(res.body)['data']['logs'] ?? []);

      // Weekly bars — Mon=0 … Sun=6
      final Map<int, int> takenPerDay  = {};
      final Map<int, int> totalPerDay  = {};
      final now = DateTime.now();
      final weekStart = now.subtract(Duration(days: now.weekday - 1)); // Monday

      int takenAll = 0, totalAll = 0;

      for (final log in logs) {
        final dateStr = log['scheduled_at'] as String?;
        if (dateStr == null) continue;
        final date   = DateTime.tryParse(dateStr)?.toLocal();
        if (date == null) continue;

        final status = log['status'] as String? ?? '';
        totalAll++;
        if (status == 'taken') takenAll++;

        // Is this date within this week?
        final dayStart = DateTime(weekStart.year, weekStart.month, weekStart.day);
        final dayDate  = DateTime(date.year, date.month, date.day);
        final diff     = dayDate.difference(dayStart).inDays;
        if (diff >= 0 && diff < 7) {
          final idx = diff; // 0=Mon … 6=Sun
          totalPerDay[idx] = (totalPerDay[idx] ?? 0) + 1;
          if (status == 'taken') takenPerDay[idx] = (takenPerDay[idx] ?? 0) + 1;
        }
      }

      // Build weekly %
      for (int i = 0; i < 7; i++) {
        final t = totalPerDay[i] ?? 0;
        _weekPct[i] = t == 0 ? 0 : (takenPerDay[i] ?? 0) / t;
      }

      _takenTotal  = takenAll;
      _missedTotal = totalAll - takenAll;
      _adherencePct = totalAll == 0 ? 0 : takenAll / totalAll;
    } catch (e) {
      debugPrint('[Dashboard] Logs error: $e');
    }
  }

  // ── Today stats — falls + activity ──────────────────────
  Future<void> _loadTodayStats() async {
    try {
      final token = await _token();
      if (token == null) return;
      final res = await http.get(
        Uri.parse(ApiConfig.eventsTodayStats(widget.elderlyId)),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.timeout);

      if (res.statusCode != 200) return;
      final data  = jsonDecode(res.body)['data'];
      final stats = (data['stats'] as Map<String, dynamic>?) ?? {};
      _fallsToday    = (stats['fall'] as int?) ?? 0;
      _activityLevel = data['activityLevel'] as String? ?? 'Normal';
    } catch (e) {
      debugPrint('[Dashboard] Stats error: $e');
    }
  }

  // ── Elder online status + last seen ─────────────────────
  Future<void> _loadElderStatus() async {
    try {
      final token = await _token();
      if (token == null) return;
      final res = await http.get(
        Uri.parse(ApiConfig.elderlyById(widget.elderlyId)),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.timeout);

      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body)['data'];
      final lastSeenStr = data?['last_seen'] as String?;
      _isOnline  = data?['is_connected'] as bool? ?? false;
      _lastSeen  = _timeAgo(lastSeenStr);
    } catch (e) {
      debugPrint('[Dashboard] Elder status error: $e');
    }
  }

  void _buildInsight() {
    final pct = (_adherencePct * 100).round();
    if (pct >= 90) {
      _insightTitle   = 'Excellent adherence!';
      _insightMessage =
          "${widget.elderlyName}'s medication adherence is $pct%. Keep it up!";
    } else if (pct >= 70) {
      _insightTitle   = 'Good progress!';
      _insightMessage =
          "${widget.elderlyName}'s adherence is $pct% this period. A little more consistency would be great.";
    } else if (pct > 0) {
      _insightTitle   = 'Needs attention';
      _insightMessage =
          "${widget.elderlyName}'s adherence is only $pct%. Consider checking in and reminding them about medications.";
    } else {
      _insightTitle   = 'No data yet';
      _insightMessage =
          'No pill logs recorded yet. Make sure the pillbox is connected and schedules are set.';
    }
  }

  String _timeAgo(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown';
    try {
      final dt   = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60)  return 'Just now';
      if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24)  return '${diff.inHours}h ago';
      if (diff.inDays    < 7)   return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return 'Unknown'; }
  }

  // ── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final todayIdx = DateTime.now().weekday - 1; // 0=Mon … 6=Sun
    final days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final pctStr = '${(_adherencePct * 100).round()}%';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: primary),
            onPressed: _loadAll,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : RefreshIndicator(
              color: primary,
              onRefresh: _loadAll,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // ── Elder Profile Card ───────────────────────────────
                  _whiteCard(child: Row(children: [
                    Container(
                      width: 52, height: 52,
                      decoration: const BoxDecoration(color: primaryBg, shape: BoxShape.circle),
                      child: const Icon(Icons.person, color: primary, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.elderlyName, style: m(15, FontWeight.w700, textDark)),
                      const SizedBox(height: 4),
                      Text(
                        _lastSeen.isEmpty ? 'No activity recorded' : 'Last seen $_lastSeen',
                        style: m(11, FontWeight.w500, textGrey),
                      ),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isOnline ? lightGreen : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: _isOnline ? okGreen : textGrey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isOnline ? 'Online' : 'Offline',
                          style: m(11, FontWeight.w700, _isOnline ? okGreen : textGrey),
                        ),
                      ]),
                    ),
                  ])),

                  const SizedBox(height: 20),

                  // ── Medication Tracking ──────────────────────────────
                  Text('Medication Tracking', style: m(15, FontWeight.w700, textDark)),
                  const SizedBox(height: 10),
                  _whiteCard(child: Column(children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      SizedBox(
                        width: 110, height: 110,
                        child: CustomPaint(
                          painter: _DonutPainter(
                            pct: _adherencePct, color: primary, bg: primaryBg),
                          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(pctStr, style: m(18, FontWeight.w700, textDark)),
                            Text('Adherence', style: m(8, FontWeight.w500, textGrey)),
                          ])),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _dotStat(okGreen,   'Taken',   '$_takenTotal doses'),
                        const SizedBox(height: 10),
                        _dotStat(dangerRed, 'Missed',  '$_missedTotal doses'),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: _adherencePct, minHeight: 8,
                            backgroundColor: const Color(0xFFEEEEEE),
                            color: _adherencePct >= 0.8 ? okGreen
                                : _adherencePct >= 0.5 ? primary : dangerRed,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('$pctStr overall adherence',
                            style: m(10, FontWeight.w500, textGrey)),
                      ])),
                    ]),
                  ])),

                  const SizedBox(height: 20),

                  // ── Weekly Adherence ─────────────────────────────────
                  Text('Weekly Adherence', style: m(15, FontWeight.w700, textDark)),
                  const SizedBox(height: 10),
                  _whiteCard(child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('This week', style: m(12, FontWeight.w500, textGrey)),
                      Text(
                        _weekPct.any((v) => v > 0)
                            ? '${(_weekPct.where((v) => v > 0).reduce((a,b) => a+b) / _weekPct.where((v) => v > 0).length * 100).round()}% avg'
                            : 'No data',
                        style: m(12, FontWeight.w700, primary),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 130,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: List.generate(7, (i) {
                          final pct = _weekPct[i];
                          final barH = pct * 90;
                          Color col;
                          if (pct >= 0.9)      col = okGreen;
                          else if (pct >= 0.5) col = primary;
                          else if (pct > 0)    col = warnOrange;
                          else                 col = const Color(0xFFEEEEEE);
                          final isToday = i == todayIdx;
                          return Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                            if (pct > 0)
                              Text('${(pct * 100).round()}%', style: m(8, FontWeight.w600, col))
                            else
                              const SizedBox(height: 12),
                            const SizedBox(height: 4),
                            Container(
                              width: isToday ? 32 : 26,
                              height: pct > 0 ? barH : 6,
                              decoration: BoxDecoration(
                                color: col,
                                borderRadius: BorderRadius.circular(6),
                                border: isToday ? Border.all(color: textDark, width: 2) : null,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(days[i],
                                style: m(9, FontWeight.w700, isToday ? textDark : textGrey)),
                          ]);
                        }),
                      ),
                    ),
                  ])),

                  const SizedBox(height: 20),

                  // ── Health Overview ──────────────────────────────────
                  Text('Health Overview', style: m(15, FontWeight.w700, textDark)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _healthTile(
                      icon: Icons.warning_amber_rounded,
                      label: 'Falls Today',
                      value: '$_fallsToday',
                      sub: _fallsToday == 0 ? 'All Good' : '$_fallsToday detected',
                      iconColor: _fallsToday == 0 ? okGreen : dangerRed,
                      iconBg:    _fallsToday == 0 ? lightGreen : lightRed,
                      badge: true,
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _healthTile(
                      icon: Icons.medication_outlined,
                      label: 'Missed',
                      value: '$_missedTotal',
                      sub: _missedTotal == 0 ? 'Perfect' : 'doses missed',
                      iconColor: _missedTotal == 0 ? okGreen : dangerRed,
                      iconBg:    _missedTotal == 0 ? lightGreen : lightRed,
                      badge: true,
                    )),
                  ]),
                  const SizedBox(height: 12),
                  _whiteCard(child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: infoBlueBg,
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.directions_walk, color: infoBlue, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Activity Level', style: m(12, FontWeight.w500, textGrey)),
                      Text(_activityLevel, style: m(16, FontWeight.w700, infoBlue)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: infoBlueBg,
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        _activityLevel.startsWith('Alert') ? 'Alert!'
                        : _activityLevel.startsWith('Low') ? 'Low Activity'
                        : 'On Track',
                        style: m(11, FontWeight.w700, infoBlue),
                      ),
                    ),
                  ])),

                  const SizedBox(height: 20),

                  // ── Insight ──────────────────────────────────────────
                  Text('Insights', style: m(15, FontWeight.w700, textDark)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _adherencePct >= 0.8
                            ? [const Color(0xFF2FA884), const Color(0xFF1D7D62)]
                            : _adherencePct >= 0.5
                                ? [warnOrange, const Color(0xFFE65100)]
                                : [dangerRed, const Color(0xFFB71C1C)],
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
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _adherencePct >= 0.8
                              ? Icons.emoji_events_outlined
                              : _adherencePct >= 0.5
                                  ? Icons.trending_up
                                  : Icons.warning_amber_rounded,
                          color: Colors.white, size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_insightTitle,
                            style: m(14, FontWeight.w700, Colors.white)),
                        const SizedBox(height: 6),
                        Text(_insightMessage,
                            style: m(12, FontWeight.w500, Colors.white70)
                                .copyWith(height: 1.5)),
                      ])),
                    ]),
                  ),

                  const SizedBox(height: 30),
                ]),
              ),
            ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

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
    required IconData icon, required String label,
    required String value, required String sub,
    required Color iconColor, required Color iconBg, bool badge = false,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12, offset: const Offset(0, 4))],
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

  Widget _whiteCard({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: child,
  );
}

// ── Donut chart ──────────────────────────────────────────────────────────────
class _DonutPainter extends CustomPainter {
  final double pct;
  final Color color, bg;
  const _DonutPainter({required this.pct, required this.color, required this.bg});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r  = math.min(cx, cy) - 8;
    const stroke = 12.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
    canvas.drawArc(rect, 0, math.pi * 2, false,
        Paint()..color = bg..style = PaintingStyle.stroke
               ..strokeWidth = stroke..strokeCap = StrokeCap.round);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * pct, false,
        Paint()..color = color..style = PaintingStyle.stroke
               ..strokeWidth = stroke..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(_DonutPainter old) => old.pct != pct;
}
