import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/camera_models.dart';
import '../services/webrtc_service.dart';
import '../services/events_service.dart';

class LiveCameraScreen extends StatefulWidget {
  final String caregiverId;
  final String elderlyId;

  const LiveCameraScreen({
    super.key,
    required this.caregiverId,
    required this.elderlyId,
  });

  @override
  State<LiveCameraScreen> createState() => _LiveCameraScreenState();
}

class _LiveCameraScreenState extends State<LiveCameraScreen> {
  // ── Colors ─────────────────────────────────────────
  static const primary = Color(0xFF2FA884);
  static const primaryBg = Color(0xFFE6F4F0);
  static const dangerRed = Color(0xFFE53935);
  static const lightRed = Color(0xFFFFF0EE);
  static const okGreen = Color(0xFF388E3C);
  static const lightGreen = Color(0xFFEEF7EE);
  static const infoBlue = Color(0xFF1976D2);
  static const infoBlueBg = Color(0xFFEBF3FD);
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
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  late final WebRTCService _webRTCService;

  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isMuted = false;
  bool _isFullscreen = false;
  bool _fallDetectionEnabled = true;

  // ── Real data state ────────────────────────────────
  TodayStats _todayStats =
      TodayStats(falls: 0, inactivity: 0, sleeping: 0, nightRestlessness: 0, total: 0);
  List<EventModel> _recentEvents = [];
  bool _cameraOffline = false;

  // ── Data (history stays static as placeholder) ─────
  final List<HistoryItem> cameraHistory = const [
    HistoryItem(
        title: 'Movement Detected',
        location: 'Living room',
        time: '2 minutes ago',
        type: HistoryType.info,
        resolved: false),
    HistoryItem(
        title: 'No Activity for 3 Hours',
        location: 'General',
        time: 'Yesterday at 2:00 PM',
        type: HistoryType.warning,
        resolved: true),
    HistoryItem(
        title: 'Possible Fall Detected',
        location: 'Bedroom',
        time: 'Nov 12 at 9:30 PM',
        type: HistoryType.danger,
        resolved: true,
        note: 'False alarm - dropped book'),
  ];

  // ── Lifecycle ──────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _webRTCService = WebRTCService(
      caregiverId: widget.caregiverId,
      elderlyId: widget.elderlyId,
      onConnected: (stream) {
        if (!mounted) return;
        setState(() {
          _remoteRenderer.srcObject = stream;
          _isConnected = true;
          _isConnecting = false;
          _cameraOffline = false;
        });
      },
      onDisconnected: () {
        if (!mounted) return;
        setState(() {
          _remoteRenderer.srcObject = null;
          _isConnected = false;
        });
      },
      onError: () {
        if (!mounted) return;
        setState(() {
          _isConnected = false;
          _isConnecting = false;
        });
      },
      // ── NEW: real-time alert from server ──────────
      onAlert: (alert) {
        if (!mounted) return;
        final eventType = alert['event_type'] as String? ?? 'alert';
        final confidence = (alert['confidence'] as num?)?.toDouble() ?? 0.0;
        final pct = (confidence * 100).round();

        // Refresh stats from the new event data
        setState(() {
          if (eventType == 'fall')
            _todayStats = TodayStats(
                falls:             _todayStats.falls + 1,
                inactivity:        _todayStats.inactivity,
                sleeping:          _todayStats.sleeping,
                nightRestlessness: _todayStats.nightRestlessness,
                total:             _todayStats.total + 1);
          if (eventType == 'inactivity')
            _todayStats = TodayStats(
                falls:             _todayStats.falls,
                inactivity:        _todayStats.inactivity + 1,
                sleeping:          _todayStats.sleeping,
                nightRestlessness: _todayStats.nightRestlessness,
                total:             _todayStats.total + 1);
          if (eventType == 'sleeping')
            _todayStats = TodayStats(
                falls:             _todayStats.falls,
                inactivity:        _todayStats.inactivity,
                sleeping:          _todayStats.sleeping + 1,
                nightRestlessness: _todayStats.nightRestlessness,
                total:             _todayStats.total + 1);
          if (eventType == 'night_restlessness')
            _todayStats = TodayStats(
                falls:             _todayStats.falls,
                inactivity:        _todayStats.inactivity,
                sleeping:          _todayStats.sleeping,
                nightRestlessness: _todayStats.nightRestlessness + 1,
                total:             _todayStats.total + 1);
        });

        // Show banner at top of screen
        _showAlertBanner(eventType, pct);
      },
      // ── NEW: camera went offline ──────────────────
      onCameraOffline: () {
        if (!mounted) return;
        setState(() {
          _cameraOffline = true;
          _isConnected = false;
          _remoteRenderer.srcObject = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera device went offline'),
            backgroundColor: Color(0xFFE53935),
            duration: Duration(seconds: 4),
          ),
        );
      },
    );
    _initRenderer();
    _loadTodayStats();
  }

  Future<void> _initRenderer() async {
    await _remoteRenderer.initialize();
    setState(() {});
  }

  /// Load today's real event stats from the API
  Future<void> _loadTodayStats() async {
    final events =
        await EventsService.getEventsByElderly(widget.elderlyId, limit: 50);
    if (!mounted) return;
    setState(() {
      _recentEvents = events.take(3).toList();
      _todayStats = EventsService.buildTodayStats(events);
    });
  }

  /// Show a red alert banner when Python detects a fall/inactivity/sleeping
  void _showAlertBanner(String eventType, int confidencePct) {
    String title;
    switch (eventType) {
      case 'fall':
        title = '🚨 Fall Detected ($confidencePct%)';
        break;
      case 'inactivity':
        title = '⚠️ Inactivity Alert ($confidencePct%)';
        break;
      case 'sleeping':
        title = '💤 Sleeping Alert ($confidencePct%)';
        break;
      case 'night_restlessness':
        title = '🌙 Night Restlessness ($confidencePct%)';
        break;
      default:
        title = '⚠️ Alert ($confidencePct%)';
        break;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFFE53935),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: _loadTodayStats,
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Don't call _exitFullscreen() here — it calls setState which crashes
    // when the widget is already being disposed. Reset orientation directly.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _remoteRenderer.dispose();
    _webRTCService.disconnect();
    super.dispose();
  }

  // ── Actions ────────────────────────────────────────
  void _connect() {
    setState(() {
      _isConnecting = true;
      _cameraOffline = false;
    });
    _webRTCService.connect();
  }

  void _disconnect() {
    _webRTCService.disconnect();
  }

  void _enterFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    setState(() => _isFullscreen = true);
  }

  void _exitFullscreen() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    if (mounted) setState(() => _isFullscreen = false);
  }

  // ── Build ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) return _buildFullscreenView();

    // Build activity rows from real events, fall back to placeholder if empty
    final activityRows = _recentEvents.isNotEmpty
        ? _recentEvents
            .map((e) => ActivityItem(
                  icon: e.eventType == 'fall'
                      ? Icons.warning_amber_rounded
                      : e.eventType == 'inactivity'
                          ? Icons.do_not_disturb_on_outlined
                          : e.eventType == 'night_restlessness'
                              ? Icons.nights_stay_outlined
                              : Icons.bedtime_outlined,
                  iconColor: e.eventType == 'fall'
                      ? dangerRed
                      : e.eventType == 'inactivity'
                          ? warnOrange
                          : e.eventType == 'night_restlessness'
                              ? warnOrange
                              : infoBlue,
                  iconBg: e.eventType == 'fall'
                      ? lightRed
                      : e.eventType == 'inactivity'
                          ? warnBg
                          : e.eventType == 'night_restlessness'
                              ? warnBg
                              : infoBlueBg,
                  title: '${e.title} · ${e.confidencePercent}',
                  time: e.timeAgo,
                ))
            .toList()
        : const [
            ActivityItem(
                icon: Icons.show_chart_rounded,
                iconColor: infoBlue,
                iconBg: infoBlueBg,
                title: 'Movement in living room',
                time: '2 minutes ago'),
            ActivityItem(
                icon: Icons.check_circle,
                iconColor: okGreen,
                iconBg: lightGreen,
                title: 'Normal activity pattern',
                time: '15 minutes ago'),
            ActivityItem(
                icon: Icons.do_not_disturb_on_outlined,
                iconColor: dangerRed,
                iconBg: lightRed,
                title: 'No movement detected',
                time: '1 hour ago'),
          ];

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
        title:
            Text('Camera Monitoring', style: m(18, FontWeight.w700, textDark)),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.settings_outlined, color: textDark),
              onPressed: () {})
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Camera Status + Feed ─────────────────────
          _whiteCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: primaryBg,
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.camera_alt_outlined,
                        color: primary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Camera Status',
                            style: m(14, FontWeight.w700, textDark)),
                        Text(
                          _cameraOffline
                              ? 'Camera went offline'
                              : _isConnecting
                                  ? 'Connecting...'
                                  : _isConnected
                                      ? 'Active & Monitoring'
                                      : 'Disconnected',
                          style: m(
                            12,
                            FontWeight.w500,
                            _cameraOffline
                                ? dangerRed
                                : _isConnected
                                    ? primary
                                    : _isConnecting
                                        ? warnOrange
                                        : textGrey,
                          ),
                        ),
                      ])),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _cameraOffline
                          ? dangerRed
                          : _isConnected
                              ? okGreen
                              : _isConnecting
                                  ? warnOrange
                                  : textGrey,
                      shape: BoxShape.circle,
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                _buildVideoFeed(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isConnecting
                        ? null
                        : (_isConnected ? _disconnect : _connect),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isConnected ? lightRed : primary,
                      foregroundColor: _isConnected ? dangerRed : Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: Icon(
                      _isConnecting
                          ? Icons.hourglass_top_rounded
                          : _isConnected
                              ? Icons.stop_circle_outlined
                              : Icons.play_circle_outline_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _isConnecting
                          ? 'Connecting...'
                          : _isConnected
                              ? 'Disconnect'
                              : 'Connect to Camera',
                      style: m(13, FontWeight.w700,
                          _isConnected ? dangerRed : Colors.white),
                    ),
                  ),
                ),
              ])),

          const SizedBox(height: 20),

          // ── AI Analysis — real stats ──────────────────
          Text('AI Analysis - Today', style: m(15, FontWeight.w700, textDark)),
          const SizedBox(height: 10),
          _whiteCard(
              child: Row(children: [
            Expanded(
                child: _analysisStat(
              icon: Icons.check_circle_rounded,
              iconColor: _todayStats.falls > 0 ? dangerRed : okGreen,
              label: 'Falls',
              value: '${_todayStats.falls}',
              valueColor: _todayStats.falls > 0 ? dangerRed : okGreen,
            )),
            _divider(),
            Expanded(
                child: _analysisStat(
              icon: Icons.show_chart_rounded,
              iconColor: infoBlue,
              label: 'Activity',
              value: _todayStats.activityLevel,
              valueColor: infoBlue,
            )),
            _divider(),
            Expanded(
                child: _analysisStat(
              icon: Icons.warning_amber_rounded,
              iconColor: _todayStats.total > 0 ? dangerRed : okGreen,
              label: 'Alerts',
              value: '${_todayStats.total}',
              valueColor: _todayStats.total > 0 ? dangerRed : okGreen,
            )),
          ])),

          const SizedBox(height: 20),

          // ── Recent Activity — real events ─────────────
          Text('Recent Activity', style: m(15, FontWeight.w700, textDark)),
          const SizedBox(height: 10),
          _whiteCard(
              child: Column(
                  children: activityRows.map(_buildActivityRow).toList())),

          const SizedBox(height: 20),

          // ── Camera History ───────────────────────────
          Text('Camera History', style: m(15, FontWeight.w700, textDark)),
          const SizedBox(height: 10),
          Column(children: cameraHistory.map(_buildHistoryCard).toList()),

          const SizedBox(height: 20),

          // ── Alert Settings ───────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: primaryBg, borderRadius: BorderRadius.circular(18)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Alert Settings', style: m(15, FontWeight.w700, textDark)),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Fall Detection',
                          style: m(13, FontWeight.w600, textDark)),
                      GestureDetector(
                        onTap: () => setState(() =>
                            _fallDetectionEnabled = !_fallDetectionEnabled),
                        child: Text(
                          _fallDetectionEnabled ? 'Enabled' : 'Disabled',
                          style: m(13, FontWeight.w700,
                              _fallDetectionEnabled ? primary : textGrey),
                        ),
                      ),
                    ]),
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Inactivity Alert',
                          style: m(13, FontWeight.w600, textDark)),
                      Text('After 3 Hours',
                          style: m(13, FontWeight.w700, primary)),
                    ]),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text('Save', style: m(14, FontWeight.w700, textDark)),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  // ── Fullscreen View ────────────────────────────────
  Widget _buildFullscreenView() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        SizedBox.expand(
          child: _isConnected
              ? RTCVideoView(_remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
              : Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(
                        _isConnecting
                            ? Icons.hourglass_top_rounded
                            : Icons.videocam_off_outlined,
                        color: Colors.white38,
                        size: 48,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _isConnecting
                            ? 'Connecting to camera...'
                            : 'Camera not connected',
                        style: m(14, FontWeight.w500, Colors.white38),
                      ),
                    ])),
        ),
        if (_isConnected)
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: dangerRed, borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Colors.white, shape: BoxShape.circle)),
                const SizedBox(width: 5),
                Text('LIVE', style: m(11, FontWeight.w700, Colors.white)),
              ]),
            ),
          ),
        Positioned(
          bottom: 24,
          left: 20,
          right: 20,
          child:
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            GestureDetector(
              onTap: () => setState(() => _isMuted = !_isMuted),
              child: Icon(
                  _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: Colors.white70,
                  size: 26),
            ),
            GestureDetector(
              onTap: _exitFullscreen,
              child: const Icon(Icons.fullscreen_exit_rounded,
                  color: Colors.white70, size: 26),
            ),
          ]),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: GestureDetector(
            onTap: _exitFullscreen,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Video Feed ─────────────────────────────────────
  Widget _buildVideoFeed() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 210,
        color: Colors.black,
        child: Stack(children: [
          _isConnected
              ? RTCVideoView(_remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
              : Center(
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      Icon(
                        _isConnecting
                            ? Icons.hourglass_top_rounded
                            : Icons.videocam_off_outlined,
                        color: Colors.white38,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isConnecting
                            ? 'Connecting to camera...'
                            : 'Camera not connected',
                        style: m(13, FontWeight.w500, Colors.white38),
                      ),
                    ])),
          if (_isConnected)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: dangerRed, borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text('LIVE', style: m(10, FontWeight.w700, Colors.white)),
                ]),
              ),
            ),
          if (_isConnected) ...[
            Positioned(
              bottom: 10,
              left: 10,
              child: GestureDetector(
                onTap: () => setState(() => _isMuted = !_isMuted),
                child: Icon(
                    _isMuted
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white70,
                    size: 22),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: GestureDetector(
                onTap: _enterFullscreen,
                child: const Icon(Icons.fullscreen_rounded,
                    color: Colors.white70, size: 22),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ── UI Helpers ─────────────────────────────────────
  Widget _analysisStat(
          {required IconData icon,
          required Color iconColor,
          required String label,
          required String value,
          required Color valueColor}) =>
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(height: 5),
        Text(label, style: m(11, FontWeight.w500, textGrey)),
        const SizedBox(height: 2),
        Text(value, style: m(16, FontWeight.w700, valueColor)),
      ]);

  Widget _divider() => Container(
        width: 1,
        height: 50,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: const Color(0xFFEEEEEE),
      );

  Widget _whiteCard({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: child,
      );

  Widget _buildActivityRow(ActivityItem a) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: a.iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(a.icon, color: a.iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(a.title, style: m(13, FontWeight.w600, textDark)),
                Text(a.time, style: m(11, FontWeight.w500, textGrey)),
              ])),
        ]),
      );

  Widget _buildHistoryCard(HistoryItem h) {
    Color borderColor;
    Color cardBg;
    Color titleColor;
    switch (h.type) {
      case HistoryType.info:
        borderColor = const Color(0xFF90CAF9);
        cardBg = infoBlueBg;
        titleColor = infoBlue;
        break;
      case HistoryType.warning:
        borderColor = const Color(0xFFFFCC80);
        cardBg = warnBg;
        titleColor = warnOrange;
        break;
      case HistoryType.danger:
        borderColor = const Color(0xFFEF9A9A);
        cardBg = lightRed;
        titleColor = dangerRed;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: 1.2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(h.title, style: m(13, FontWeight.w700, titleColor)),
          if (h.resolved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Text('Resolved', style: m(11, FontWeight.w600, textGrey)),
            ),
        ]),
        const SizedBox(height: 4),
        Text(h.location, style: m(12, FontWeight.w500, textGrey)),
        Text(h.time, style: m(11, FontWeight.w500, textGrey)),
        if (h.note != null) ...[
          const SizedBox(height: 4),
          Text('Note: ${h.note}', style: m(11, FontWeight.w500, textGrey)),
        ],
      ]),
    );
  }
}
