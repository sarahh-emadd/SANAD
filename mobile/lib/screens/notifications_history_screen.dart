import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../l10n/app_strings.dart';

class NotificationsHistoryScreen extends StatefulWidget {
  const NotificationsHistoryScreen({super.key});

  @override
  State<NotificationsHistoryScreen> createState() =>
      _NotificationsHistoryScreenState();
}

class _NotificationsHistoryScreenState
    extends State<NotificationsHistoryScreen> {
  // ── Colors ─────────────────────────────────────────
  static const primary = Color(0xFF2FA884);
  static const dangerRed = Color(0xFFE53935);
  static const lightRed = Color(0xFFFFF0EE);
  static const okGreen = Color(0xFF388E3C);
  static const lightGreen = Color(0xFFEEF7EE);
  static const warnBg = Color(0xFFFFF8EE);
  static const warnOrange = Color(0xFFF57C00);
  static const bgColor = Color(0xFFF5F7F6);
  static const textDark = Color(0xFF1A1A1A);
  static const textGrey = Color(0xFFAAAAAA);

  static TextStyle m(double size, FontWeight weight, Color color) => TextStyle(
      fontFamily: 'Montserrat',
      fontSize: size,
      fontWeight: weight,
      color: color);

  // ── State ──────────────────────────────────────────
  bool _loading = true;
  Map<String, List<Map<String, dynamic>>> _grouped = {};

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<String?> _token() async {
    try { return await FirebaseAuth.instance.currentUser?.getIdToken(); }
    catch (_) { return null; }
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final token = await _token();
      if (token == null) { setState(() => _loading = false); return; }

      final headers = {'Authorization': 'Bearer $token'};

      // Fetch both: system alerts + elder preset messages in parallel
      final results = await Future.wait([
        http.get(Uri.parse(ApiConfig.caregiverNotifications), headers: headers)
            .timeout(ApiConfig.timeout),
        http.get(Uri.parse(ApiConfig.caregiverMessages), headers: headers)
            .timeout(ApiConfig.timeout),
      ]);

      if (!mounted) return;

      final List<Map<String, dynamic>> all = [];

      // System alerts
      if (results[0].statusCode == 200) {
        final list = List<Map<String, dynamic>>.from(
            jsonDecode(results[0].body)['data']['notifications'] ?? []);
        all.addAll(list);
      }

      // Elder preset messages
      if (results[1].statusCode == 200) {
        final msgs = List<Map<String, dynamic>>.from(
            jsonDecode(results[1].body)['data']['messages'] ?? []);
        for (final m in msgs) {
          all.add({
            ...m,
            'type': 'preset_message',
            'event_type': 'preset_message',
            'title': m['message_en'] ?? 'Quick Message',
            'elderly_name': m['elderly_name'] ?? '',
            'created_at': m['created_at'],
          });
        }
      }

      // Sort by created_at descending
      all.sort((a, b) {
        final da = DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

      setState(() {
        _grouped = _groupByDate(all);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, List<Map<String, dynamic>>> _groupByDate(
      List<Map<String, dynamic>> items) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final item in items) {
      final createdStr = item['created_at'] as String?;
      if (createdStr == null) continue;
      final dt = DateTime.tryParse(createdStr)?.toLocal();
      if (dt == null) continue;
      final d = DateTime(dt.year, dt.month, dt.day);
      final String label;
      if (d == today)           label = 'Today';
      else if (d == yesterday)  label = 'Yesterday';
      else                      label = '${_monthName(d.month)} ${d.day}';
      grouped.putIfAbsent(label, () => []).add({...item, '_dt': dt});
    }
    return grouped;
  }

  String _monthName(int m) => const [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][m];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(S.of(context).alerts, style: m(18, FontWeight.w700, textDark)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: textDark, size: 22),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : _grouped.isEmpty
              ? Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_none_rounded,
                            size: 48, color: textGrey),
                        const SizedBox(height: 12),
                        Text(S.of(context).noAlerts,
                            style: m(15, FontWeight.w600, textGrey)),
                        const SizedBox(height: 6),
                        Text(S.of(context).alertsFromAI,
                            style: m(13, FontWeight.w400, textGrey)),
                      ]),
                )
              : RefreshIndicator(
                  color: primary,
                  onRefresh: _loadEvents,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _grouped.entries.map((entry) {
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10, top: 4),
                              child: Text(entry.key,
                                  style: m(14, FontWeight.w700, textDark)),
                            ),
                            ...entry.value.map((n) => _buildNotifRow(n)),
                            const SizedBox(height: 12),
                          ]);
                    }).toList(),
                  ),
                ),
    );
  }

  Widget _buildNotifRow(Map<String, dynamic> n) {
    final type      = n['type'] as String? ?? 'event';
    final eventType = n['event_type'] as String? ?? '';
    final elderName = n['elderly_name'] as String? ?? '';
    final dt        = n['_dt'] as DateTime?;
    final snapshotUrl = n['snapshot_url'] as String?;

    // Time ago
    String timeAgo = '';
    if (dt != null) {
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60)      timeAgo = '${diff.inMinutes}m ago';
      else if (diff.inHours < 24)   timeAgo = '${diff.inHours}h ago';
      else                          timeAgo = '${diff.inDays}d ago';
    }

    // Icon + colors based on type
    IconData icon;
    Color bc, bgC, ic;
    String title;

    final s = S.of(context);
    if (type == 'sos') {
      icon  = Icons.sos_rounded;
      bc    = dangerRed;
      bgC   = lightRed;
      ic    = dangerRed;
      title = s.sosAlert;
    } else {
      switch (eventType) {
        case 'fall':
          icon = Icons.warning_amber_rounded; bc = dangerRed; bgC = lightRed; ic = dangerRed;
          title = s.fallDetected;
          break;
        case 'inactivity':
          icon = Icons.do_not_disturb_on_outlined;
          bc = const Color(0xFFFFCC80); bgC = warnBg; ic = warnOrange;
          title = s.inactivityAlert;
          break;
        case 'sleeping':
          icon = Icons.bedtime_outlined;
          bc = const Color(0xFFFFCC80); bgC = warnBg; ic = warnOrange;
          title = s.sleepingAlert;
          break;
        case 'night_restlessness':
          icon = Icons.nights_stay_outlined;
          bc = const Color(0xFFFFB300); bgC = warnBg; ic = warnOrange;
          title = s.nightRestless;
          break;
        case 'pill_missed':
          icon = Icons.medication_outlined; bc = dangerRed; bgC = lightRed; ic = dangerRed;
          title = s.missedDose;
          break;
        case 'pill_taken':
          icon = Icons.check_circle_outline; bc = const Color(0xFFA5D6A7); bgC = lightGreen; ic = okGreen;
          title = s.doseTaken;
          break;
        case 'preset_message':
          icon = Icons.chat_bubble_outline_rounded;
          bc = const Color(0xFF90CAF9); bgC = const Color(0xFFE3F2FD); ic = const Color(0xFF1976D2);
          title = s.presenceMessage;
          break;
        default:
          icon = Icons.notifications_outlined;
          bc = const Color(0xFFA5D6A7); bgC = lightGreen; ic = okGreen;
          title = n['title'] as String? ?? s.alerts;
      }
    }

    // For preset messages show the actual message text as subtitle
    final messageText = (type == 'preset_message' || eventType == 'preset_message')
        ? (n['message_en'] as String? ?? '')
        : '';

    final subtitle = [
      if (messageText.isNotEmpty) messageText,
      if (elderName.isNotEmpty)   elderName,
      if (timeAgo.isNotEmpty)     timeAgo,
    ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgC,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bc, width: 1.2),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: ic, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,    style: m(13, FontWeight.w700, textDark)),
          const SizedBox(height: 2),
          Text(subtitle, style: m(11, FontWeight.w500, textGrey)),
        ])),
        if (snapshotUrl != null) ...[
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(snapshotUrl, width: 48, height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox()),
          ),
        ],
      ]),
    );
  }
}
