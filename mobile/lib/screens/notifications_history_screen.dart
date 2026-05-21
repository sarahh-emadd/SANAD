import 'package:flutter/material.dart';
import '../services/events_service.dart';

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
  Map<String, List<EventModel>> _grouped = {};

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    final events = await EventsService.getUnverifiedEvents();
    if (!mounted) return;
    setState(() {
      _grouped = _groupByDate(events);
      _loading = false;
    });
  }

  Map<String, List<EventModel>> _groupByDate(List<EventModel> events) {
    final Map<String, List<EventModel>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final e in events) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      final String label;
      if (d == today)
        label = 'Today';
      else if (d == yesterday)
        label = 'Yesterday';
      else
        label = '${_monthName(d.month)} ${d.day}';
      grouped.putIfAbsent(label, () => []).add(e);
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
        title: Text('Alerts', style: m(18, FontWeight.w700, textDark)),
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
                        Text('No alerts yet',
                            style: m(15, FontWeight.w600, textGrey)),
                        const SizedBox(height: 6),
                        Text('Alerts from AI detection will appear here',
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
                              padding:
                                  const EdgeInsets.only(bottom: 10, top: 4),
                              child: Text(entry.key,
                                  style: m(14, FontWeight.w700, textDark)),
                            ),
                            ...entry.value
                                .map((e) => _buildEventRow(context, e)),
                            const SizedBox(height: 12),
                          ]);
                    }).toList(),
                  ),
                ),
    );
  }

  Widget _buildEventRow(BuildContext context, EventModel e) {
    IconData icon;
    Color bc, bgC, ic;

    switch (e.eventType) {
      case 'fall':
        icon = Icons.warning_amber_rounded;
        bc = dangerRed;
        bgC = lightRed;
        ic = dangerRed;
        break;
      case 'inactivity':
        icon = Icons.do_not_disturb_on_outlined;
        bc = const Color(0xFFFFCC80);
        bgC = warnBg;
        ic = warnOrange;
        break;
      case 'sleeping':
        icon = Icons.bedtime_outlined;
        bc = const Color(0xFFFFCC80);
        bgC = warnBg;
        ic = warnOrange;
        break;
      default:
        icon = Icons.notifications_outlined;
        bc = const Color(0xFFA5D6A7);
        bgC = lightGreen;
        ic = okGreen;
    }

    final subtitle = '${e.confidencePercent} confidence · ${e.timeAgo}'
        '${e.elderlyName.isNotEmpty ? ' · ${e.elderlyName}' : ''}';

    return GestureDetector(
      onTap: () => _showEventDetail(context, e),
      child: Container(
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
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(e.title, style: m(13, FontWeight.w700, textDark)),
                const SizedBox(height: 2),
                Text(subtitle, style: m(11, FontWeight.w500, textGrey)),
              ])),
          // Snapshot thumbnail if available
          if (e.snapshotUrl != null) ...[
            const SizedBox(width: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                e.snapshotUrl!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: bc.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.image_not_supported_outlined,
                      color: ic, size: 20),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          if (!e.verified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: bc.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: Text('New', style: m(10, FontWeight.w700, ic)),
            ),
        ]),
      ),
    );
  }

  void _showEventDetail(BuildContext context, EventModel e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Handle ────────────────────────────────────
                  Center(
                      child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: const Color(0xFFEEEEEE),
                        borderRadius: BorderRadius.circular(2)),
                  )),
                  const SizedBox(height: 16),

                  // ── Title ─────────────────────────────────────
                  Text(e.title, style: m(17, FontWeight.w700, textDark)),
                  const SizedBox(height: 4),
                  Text('${e.confidencePercent} confidence · ${e.timeAgo}',
                      style: m(13, FontWeight.w500, textGrey)),
                  if (e.elderlyName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Person: ${e.elderlyName}',
                        style: m(13, FontWeight.w500, textGrey)),
                  ],

                  // ── Snapshot Image ─────────────────────────────
                  if (e.snapshotUrl != null) ...[
                    const SizedBox(height: 20),
                    Text('Snapshot', style: m(14, FontWeight.w700, textDark)),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        e.snapshotUrl!,
                        width: double.infinity,
                        height: 220,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            height: 220,
                            color: const Color(0xFFF5F5F5),
                            child: Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                                color: primary,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          height: 220,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.image_not_supported_outlined,
                                    color: textGrey, size: 40),
                                const SizedBox(height: 8),
                                Text('Snapshot unavailable',
                                    style: m(12, FontWeight.w500, textGrey)),
                              ]),
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      height: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt_outlined,
                                color: textGrey, size: 32),
                            const SizedBox(height: 8),
                            Text('No snapshot available',
                                style: m(12, FontWeight.w500, textGrey)),
                          ]),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Actions ────────────────────────────────────
                  if (!e.verified) ...[
                    Row(children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await EventsService.verifyEvent(e.id);
                            _loadEvents();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Confirm',
                              style: m(13, FontWeight.w700, Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await EventsService.verifyEvent(e.id,
                                isFalsePositive: true);
                            _loadEvents();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: textGrey,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFFEEEEEE)),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('False Alarm',
                              style: m(13, FontWeight.w700, textGrey)),
                        ),
                      ),
                    ]),
                  ] else
                    Text(
                      e.isFalsePositive
                          ? '✓ Marked as false alarm'
                          : '✓ Confirmed',
                      style: m(13, FontWeight.w500,
                          e.isFalsePositive ? textGrey : okGreen),
                    ),

                  const SizedBox(height: 8),
                ]),
          ),
        ),
      ),
    );
  }
}
