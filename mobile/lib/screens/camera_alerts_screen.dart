import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

/// Snapshot history — lists every AI-camera event for an elderly person.
/// Each card shows the MinIO snapshot, event type, confidence, and time.
class CameraAlertsScreen extends StatefulWidget {
  final String elderlyId;
  final String elderlyName;

  const CameraAlertsScreen({
    super.key,
    required this.elderlyId,
    required this.elderlyName,
  });

  @override
  State<CameraAlertsScreen> createState() => _CameraAlertsScreenState();
}

class _CameraAlertsScreenState extends State<CameraAlertsScreen> {
  // ── Design tokens ──────────────────────────────────────────
  static const primary    = Color(0xFF2FA884);
  static const dangerRed  = Color(0xFFE53935);
  static const lightRed   = Color(0xFFFFF0EE);
  static const warnOrange = Color(0xFFF57C00);
  static const warnBg     = Color(0xFFFFF8EE);
  static const infoBlue   = Color(0xFF1976D2);
  static const infoBlueBg = Color(0xFFEBF3FD);
  static const okGreen    = Color(0xFF388E3C);
  static const lightGreen = Color(0xFFEEF7EE);
  static const textDark   = Color(0xFF1A1A1A);
  static const textGrey   = Color(0xFFAAAAAA);
  static const bgColor    = Color(0xFFF5F7F6);

  static TextStyle m(double size, FontWeight w, Color c) =>
      TextStyle(fontFamily: 'Montserrat', fontSize: size, fontWeight: w, color: c);

  // ── State ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  // ── Fetch events list from backend ─────────────────────────
  Future<void> _loadEvents() async {
    setState(() { _loading = true; _error = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) { setState(() => _loading = false); return; }
      final token = await user.getIdToken();

      final res = await http.get(
        Uri.parse(ApiConfig.eventsForElderly(widget.elderlyId)),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data']['events'] as List;
        setState(() {
          _events = data.map((e) => Map<String, dynamic>.from(e)).toList();
          _loading = false;
        });
      } else {
        setState(() { _error = 'Failed to load alerts (${res.statusCode})'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Helpers ────────────────────────────────────────────────
  String _timeAgo(String? isoStr) {
    if (isoStr == null || isoStr.isEmpty) return '';
    try {
      final dt   = DateTime.parse(isoStr).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return 'just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours   < 24) return '${diff.inHours}h ago';
      if (diff.inDays    < 7)  return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) { return ''; }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'fall':       return dangerRed;
      case 'inactivity': return warnOrange;
      case 'sleeping':   return infoBlue;
      default:           return primary;
    }
  }

  Color _typeBg(String? type) {
    switch (type) {
      case 'fall':       return lightRed;
      case 'inactivity': return warnBg;
      case 'sleeping':   return infoBlueBg;
      default:           return lightGreen;
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'fall':       return Icons.warning_amber_rounded;
      case 'inactivity': return Icons.hourglass_empty;
      case 'sleeping':   return Icons.bedtime_outlined;
      default:           return Icons.videocam_outlined;
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'fall':       return 'Fall';
      case 'inactivity': return 'Inactivity';
      case 'sleeping':   return 'Sleeping';
      default:           return type ?? 'Event';
    }
  }

  // ── Build ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text('Camera Alerts', style: m(18, FontWeight.w700, textDark)),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        iconTheme: const IconThemeData(color: Color(0xFF1A1A1A)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.wifi_off_rounded, size: 56, color: textGrey),
                      const SizedBox(height: 16),
                      Text(_error!, style: m(14, FontWeight.w500, textGrey), textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadEvents,
                        style: ElevatedButton.styleFrom(backgroundColor: primary),
                        child: const Text('Try again'),
                      ),
                    ]),
                  ),
                )
              : _events.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.videocam_off_outlined, size: 72,
                            color: textGrey.withValues(alpha: 0.4)),
                        const SizedBox(height: 20),
                        Text('No camera alerts yet', style: m(17, FontWeight.w700, textGrey)),
                        const SizedBox(height: 8),
                        Text(
                          'AI camera events for\n${widget.elderlyName} will appear here',
                          style: m(13, FontWeight.w400, textGrey),
                          textAlign: TextAlign.center,
                        ),
                      ]),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadEvents,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _events.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _buildEventCard(_events[i]),
                      ),
                    ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> e) {
    final type        = e['event_type'] as String?;
    final confidence  = (e['confidence'] as num?)?.toDouble() ?? 0.0;
    final snapshotUrl = e['snapshot_url'] as String?;
    final createdAt   = e['created_at'] as String?;
    final isFalse     = e['is_false_positive'] as bool? ?? false;
    final verified    = e['verified'] as bool? ?? false;
    final color       = _typeColor(type);
    final bg          = _typeBg(type);
    final pct         = (confidence * 100).round();
    final hasImage    = snapshotUrl != null && snapshotUrl.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Snapshot or placeholder ──────────────────────────
        if (hasImage)
          Image.network(
            snapshotUrl,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : const SizedBox(height: 180,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            errorBuilder: (_, __, ___) => _placeholderTile(color, bg, type),
          )
        else
          _placeholderTile(color, bg, type),

        // ── Details ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [

            // Type badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_typeIcon(type), color: color, size: 14),
                const SizedBox(width: 4),
                Text(_typeLabel(type), style: m(12, FontWeight.w700, color)),
              ]),
            ),

            const SizedBox(width: 10),

            // Confidence
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$pct%', style: m(12, FontWeight.w600, textDark)),
            ),

            const Spacer(),

            // Time
            Text(_timeAgo(createdAt), style: m(12, FontWeight.w500, textGrey)),
          ]),
        ),

        // ── Verification status ───────────────────────────────
        if (isFalse || verified)
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
            child: isFalse
                ? Row(children: [
                    Icon(Icons.close, size: 14, color: textGrey),
                    const SizedBox(width: 4),
                    Text('Marked as false positive',
                        style: m(11, FontWeight.w500, textGrey)),
                  ])
                : Row(children: [
                    Icon(Icons.check_circle_outline, size: 14, color: okGreen),
                    const SizedBox(width: 4),
                    Text('Verified by caregiver',
                        style: m(11, FontWeight.w600, okGreen)),
                  ]),
          ),
      ]),
    );
  }

  Widget _placeholderTile(Color color, Color bg, String? type) => Container(
    height: 100,
    color: bg,
    child: Center(
      child: Icon(_typeIcon(type), color: color, size: 48),
    ),
  );
}
