import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sanad_app/screens/caregiver_reconnect_screen.dart';
import 'dart:convert';
import 'dart:async';
import '../models/caregiver_models.dart';
import 'live_camera_screen.dart';
import 'notifications_history_screen.dart';
import '../services/sos_service.dart';
import '../config/api_config.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'sos_incoming_call_screen.dart';
import 'caregiver_settings_screen.dart';
import 'elder_location_screen.dart';
import 'manage_pills_screen.dart';
import 'voice_reminder_screen.dart';
import 'dashboard_screen.dart';
import 'geofencing_screen.dart';
import 'camera_alerts_screen.dart';

class CaregiverHomeScreen extends StatefulWidget {
  const CaregiverHomeScreen({super.key});

  @override
  State<CaregiverHomeScreen> createState() => _CaregiverHomeScreenState();
}

class _CaregiverHomeScreenState extends State<CaregiverHomeScreen> {
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
  static const purpleC = Color(0xFF8B5CF6);
  static const purpleBg = Color(0xFFF3EEFF);
  static const tealC  = Color(0xFF00838F);
  static const tealBg = Color(0xFFE0F7FA);
  static const bgColor = Color(0xFFF5F7F6);
  static const textDark = Color(0xFF1A1A1A);
  static const textGrey = Color(0xFFAAAAAA);

  // Server URL comes from ApiConfig so it works on real devices too

  static TextStyle m(double size, FontWeight weight, Color color) => TextStyle(
      fontFamily: 'Montserrat',
      fontSize: size,
      fontWeight: weight,
      color: color);

  // ── State ──────────────────────────────────────────
  String? _caregiverId;
  String? _elderlyId;
  String? _elderlyName;
  String? _caregiverName;
  bool _loadingIds = true;
  bool _sosBannerVisible = false;
  String? _sosBannerElderly;
  String? _pendingSosId;
  int? _elderBatteryLevel;
  IO.Socket? _sosSocket;
  Timer? _vibrateTimer;
  Timer? _ringTimer;

  // ── Real data from API ─────────────────────────────────────
  List<Map<String, dynamic>> _notifications = [];
  bool _loadingNotifs = false;
  int _fallsToday = 0;
  String _activityLevel = 'Normal';
  String? _elderLastSeenStr;   // ISO string returned from location endpoint

  final List<SlotData> slots = [
    SlotData('Slot 1', '8:00 AM', 'Taken', SlotStatus.taken),
    SlotData('Slot 2', '12:00 PM', 'Due Soon', SlotStatus.dueSoon),
    SlotData('Slot 3', '8:00 PM', 'Scheduled', SlotStatus.scheduled),
  ];

  @override
  void initState() {
    super.initState();
    _loadCaregiverData();
  }

  @override
  void dispose() {
    _sosSocket?.dispose();
    _vibrateTimer?.cancel();
    super.dispose();
  }

  // ── Socket: connect + listen for SOS ──────────────
  void _connectSosSocket(String caregiverId) {
    _sosSocket?.dispose();
    _sosSocket = IO.io(
      ApiConfig.socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(2000)
          .build(),
    );
    _sosSocket!.connect();
    _sosSocket!.onConnect((_) {
      _sosSocket!.emit('join_caregiver_room', {
        'sender_id': caregiverId,
        'caregiver_id': caregiverId,
      });
      _saveFcmToken();
    });
    _sosSocket!.on('sos_alert', (data) {
      if (data is Map) _onSosAlert(Map<String, dynamic>.from(data));
    });

    // Elder left the safe zone while app is open
    _sosSocket!.on('geofence_alert', (data) {
      if (!mounted || data == null) return;
      final name     = data['elderly_name'] as String? ?? 'Your elder';
      final distance = data['distance_meters'];
      final distStr  = distance != null
          ? '${(distance as num).round()} m outside the zone'
          : 'outside the safe zone';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '📍 $name is $distStr',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ]),
          backgroundColor: tealC,
          duration: const Duration(seconds: 6),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              if (_elderlyId == null) return;
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => GeofencingScreen(
                      elderlyId: _elderlyId!,
                      elderlyName: _elderlyName ?? 'Elder')));
            },
          ),
        ),
      );
    });

    // Incoming voice call from elder via WebRTC
    _sosSocket!.on('sos_incoming_call', (data) {
      if (!mounted || data == null) return;
      _ringTimer?.cancel(); // stop alert vibration if any
      final elderlyId = data['elderly_id'] as String? ?? '';
      final elderlyName = data['elderly_name'] as String? ?? 'Your elder';
      final offer = data['offer'] as Map?;
      if (offer == null || _caregiverId == null) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SosIncomingCallScreen(
            elderlyId: elderlyId,
            elderlyName: elderlyName,
            caregiverId: _caregiverId!,
            offer: Map<String, dynamic>.from(offer),
            socket: _sosSocket!,
          ),
        ),
      );
    });
    _sosSocket!.onDisconnect((_) => debugPrint('SOS socket disconnected'));
    _sosSocket!.onConnectError((e) => debugPrint('SOS socket error: $e'));
  }

  // ── Save FCM token so push notifications work ──────
  Future<void> _saveFcmToken() async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final token = await user.getIdToken();
      await http
          .put(
            Uri.parse(ApiConfig.updateFcmToken),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json'
            },
            body: jsonEncode({'fcm_token': fcmToken}),
          )
          .timeout(ApiConfig.timeout);
    } catch (e) {
      debugPrint('FCM token error: $e');
    }
  }

  // ── SOS alert received — vibrate + show dialog ─────
  void _onSosAlert(Map<String, dynamic> data) {
    if (!mounted) return;
    final sosId       = data['sos_id']       as String?;
    final elderlyName = data['elderly_name'] as String? ?? 'Your elder';
    final source      = data['source']       as String? ?? 'manual';
    final isAutoFall  = source == 'auto_fall';

    // Vibrate repeatedly until dismissed (faster for auto_fall)
    _vibrateTimer?.cancel();
    _vibrateTimer = Timer.periodic(
      Duration(milliseconds: isAutoFall ? 500 : 1000),
      (_) => HapticFeedback.heavyImpact(),
    );

    setState(() {
      _sosBannerVisible = true;
      _sosBannerElderly = elderlyName;
      _pendingSosId = sosId;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SosDialog(
        elderlyName: elderlyName,
        sosId:       sosId ?? '',
        isAutoFall:  isAutoFall,
        onAcknowledge: () async {
          _vibrateTimer?.cancel();
          Navigator.pop(context);
          setState(() => _sosBannerVisible = false);
          if (sosId != null) {
            await SosService.acknowledgeSos(sosId);
            // Notify elder via socket
            _sosSocket?.emit('sos_acknowledged', {
              'sos_id': sosId,
              'caregiver_id': _caregiverId,
              'elderly_id': _elderlyId,
            });
          }
        },
        onDismiss: () {
          _vibrateTimer?.cancel();
          Navigator.pop(context);
          setState(() => _sosBannerVisible = false);
        },
      ),
    );
  }

  // ── Load caregiver + elderly IDs from backend ──────
  Future<void> _loadCaregiverData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await user.getIdToken();

      // Get caregiver profile (includes id)
      final meRes = await http.get(
        Uri.parse(ApiConfig.getMe),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (meRes.statusCode == 200) {
        final meData = jsonDecode(meRes.body)['data'];
        final caregiverId = meData['user']['id'] as String;
        final caregiverName =
            meData['user']['first_name'] as String? ?? 'Caregiver';

        // Get first elderly for this caregiver
        final elderlyRes = await http.get(
          Uri.parse(ApiConfig.getAllElderly),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (elderlyRes.statusCode == 200) {
          final elderlyList =
              jsonDecode(elderlyRes.body)['data']['elderly'] as List;
          if (elderlyList.isNotEmpty) {
            final elderly = elderlyList[0];
            final elderlyId = elderly['id'] as String;
            final elderlyName = elderly['first_name'] as String? ?? 'Elder';

            // Persist IDs so VoiceReminderScreen (and other screens) can read them
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('elderly_id',   elderlyId);
            await prefs.setString('caregiver_id',  caregiverId);
            await prefs.setString('elderly_name',  elderlyName);
            await prefs.setString('caregiver_name', caregiverName);

            if (mounted) {
              setState(() {
                _caregiverId = caregiverId;
                _elderlyId = elderlyId;
                _caregiverName = caregiverName;
                _elderlyName = elderlyName;
                _loadingIds = false;
              });
              _connectSosSocket(caregiverId);
              _fetchElderBattery(elderlyId, token);
              _fetchNotifications(token);
              _fetchTodayStats(elderlyId, token);
            }
            return;
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading caregiver data: $e');
    }

    if (mounted) setState(() => _loadingIds = false);
  }

  // ── Fetch elder's battery + last_seen from location endpoint ──
  Future<void> _fetchElderBattery(String elderlyId, String? token) async {
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.elderlyLocation(elderlyId)),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.timeout);
      if (res.statusCode == 200) {
        final loc      = jsonDecode(res.body)['data']['location'];
        final level    = loc['battery_level'] as int?;
        final lastSeen = loc['last_seen'] as String?;
        if (mounted) setState(() {
          _elderBatteryLevel = level;
          _elderLastSeenStr  = lastSeen;
        });
      }
    } catch (_) {
      // Non-fatal — battery display is best-effort
    }
  }

  // ── Fetch real notifications (events + SOS) ─────────────────
  Future<void> _fetchNotifications(String? token) async {
    if (token == null) return;
    setState(() => _loadingNotifs = true);
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.caregiverNotifications),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data']['notifications'] as List;
        if (mounted) setState(() {
          _notifications = data.map((n) => Map<String, dynamic>.from(n)).toList();
          _loadingNotifs = false;
        });
      } else {
        if (mounted) setState(() => _loadingNotifs = false);
      }
    } catch (e) {
      debugPrint('[Home] Notifications error: $e');
      if (mounted) setState(() => _loadingNotifs = false);
    }
  }

  // ── Fetch today's event stats (falls count + activity level) ─
  Future<void> _fetchTodayStats(String elderlyId, String? token) async {
    if (token == null) return;
    try {
      final res = await http.get(
        Uri.parse(ApiConfig.eventsTodayStats(elderlyId)),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.timeout);
      if (res.statusCode == 200) {
        final data   = jsonDecode(res.body)['data'];
        final stats  = (data['stats'] as Map<String, dynamic>?) ?? {};
        final level  = data['activityLevel'] as String? ?? 'Normal';
        if (mounted) setState(() {
          _fallsToday    = (stats['fall'] as int?) ?? 0;
          _activityLevel = level;
        });
      }
    } catch (e) {
      debugPrint('[Home] Today stats error: $e');
    }
  }

  // ── "X ago" formatter ──────────────────────────────────────
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

  // ── Activity level color helpers ───────────────────────────
  Color _activityColor() {
    if (_activityLevel.startsWith('Alert'))    return dangerRed;
    if (_activityLevel.startsWith('Low'))      return warnOrange;
    if (_activityLevel.startsWith('Sleeping')) return infoBlue;
    return okGreen;
  }
  Color _activityBg() {
    if (_activityLevel.startsWith('Alert'))    return lightRed;
    if (_activityLevel.startsWith('Low'))      return warnBg;
    if (_activityLevel.startsWith('Sleeping')) return infoBlueBg;
    return lightGreen;
  }

  // ── Build ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    final dateStr =
        '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Text('Sanad', style: m(20, FontWeight.w700, textDark)),
        centerTitle: true,
        actions: [
          // ── QR Reconnect — tap to regenerate QR for elder device ──
          if (_elderlyId != null)
            IconButton(
              icon: const Icon(Icons.qr_code_rounded, color: primary),
              tooltip: 'Reconnect elder device',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CaregiverReconnectScreen(
                    elderlyId: _elderlyId!,
                    elderlyName: _elderlyName ?? 'Elder',
                  ),
                ),
              ),
            ),
          IconButton(
              icon: const Icon(Icons.settings_outlined, color: textDark),
              onPressed: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const CaregiverSettingsScreen()));
                // Refresh displayed name after returning from settings
                _loadCaregiverData();
              }),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Good Morning Card ──────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                color: primary, borderRadius: BorderRadius.circular(22)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dateStr, style: m(12, FontWeight.w500, Colors.white60)),
              const SizedBox(height: 6),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Good morning,\n${_caregiverName ?? 'Caregiver'}!',
                              style: m(20, FontWeight.w700, Colors.white)
                                  .copyWith(height: 1.3),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _elderlyName != null
                                  ? "You're ${_elderlyName}'s Sanad 💚"
                                  : "You're their Sanad 💚",
                              style: m(13, FontWeight.w500, Colors.white70),
                            ),
                            if (_elderLastSeenStr != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${_elderlyName ?? "Elder"} was active ${_timeAgo(_elderLastSeenStr)}',
                                style: m(11, FontWeight.w400, Colors.white54),
                              ),
                            ],
                          ]),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: dangerRed,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        minimumSize: Size.zero,
                      ),
                      icon: const Icon(Icons.phone, size: 16),
                      label: Text('Call',
                          style: m(13, FontWeight.w700, dangerRed)),
                    ),
                  ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: _heroStatBox(
                        Icons.check_circle, 'Meds Today', '2 / 3')),
                const SizedBox(width: 10),
                Expanded(
                    child: _heroStatBox(
                        _batteryIcon(_elderBatteryLevel),
                        'Elder Battery',
                        _elderBatteryLevel != null
                            ? '$_elderBatteryLevel%'
                            : '--')),
              ]),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Quick Actions ──────────────────────────
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.75,
            children: [
              _actionCard(
                icon: Icons.camera_alt_outlined,
                label: 'Live Cameras',
                color: primary,
                bg: primaryBg,
                onTap: _openCamera,
              ),
              _actionCard(
                icon: Icons.notifications_outlined,
                label: 'View Alerts',
                color: dangerRed,
                bg: lightRed,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NotificationsHistoryScreen())),
              ),
              _actionCard(
                  icon: Icons.medication,
                  label: 'Medications',
                  color: warnOrange,
                  bg: warnBg,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ManagePillsScreen()))),
              _actionCard(
                  icon: Icons.graphic_eq,
                  label: 'Voice Reminder',
                  color: okGreen,
                  bg: lightGreen,
                  onTap: () {
                    if (_elderlyId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No elder connected yet')));
                      return;
                    }
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => VoiceReminderScreen(elderlyId: _elderlyId!)));
                  }),
              _actionCard(
                  icon: Icons.bar_chart_rounded,
                  label: 'Dashboard',
                  color: infoBlue,
                  bg: infoBlueBg,
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const DashboardScreen()))),
              _actionCard(
                  icon: Icons.location_on_outlined,
                  label: 'Elder Location',
                  color: purpleC,
                  bg: purpleBg,
                  onTap: () {
                    if (_elderlyId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No elderly profile found')));
                      return;
                    }
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => ElderLocationScreen(
                            elderId: _elderlyId!, elderName: _elderlyName)));
                  }),
              _actionCard(
                  icon: Icons.shield_outlined,
                  label: 'Safe Zone',
                  color: tealC,
                  bg: tealBg,
                  onTap: () {
                    if (_elderlyId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No elder connected yet')));
                      return;
                    }
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => GeofencingScreen(
                            elderlyId: _elderlyId!,
                            elderlyName: _elderlyName ?? 'Elder')));
                  }),
              _actionCard(
                  icon: Icons.photo_library_outlined,
                  label: 'Camera Alerts',
                  color: dangerRed,
                  bg: lightRed,
                  onTap: () {
                    if (_elderlyId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No elder connected yet')));
                      return;
                    }
                    Navigator.push(context, MaterialPageRoute(
                        builder: (_) => CameraAlertsScreen(
                            elderlyId: _elderlyId!,
                            elderlyName: _elderlyName ?? 'Elder')));
                  }),
            ],
          ),

          const SizedBox(height: 20),

          // ── Medication Adherence ───────────────────
          _sectionTitle('Medication Adherence', 'Manage →', () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ManagePillsScreen()))),
          const SizedBox(height: 10),
          _whiteCard(
              child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Today', style: m(13, FontWeight.w500, textGrey)),
              Text('89%', style: m(13, FontWeight.w700, textDark)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                  value: 0.89,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFEEEEEE),
                  color: primary),
            ),
            const SizedBox(height: 14),
            ...slots.map(_buildSlotRow),
          ])),

          const SizedBox(height: 20),

          // ── Notifications ──────────────────────────
          _sectionTitle('Notifications', 'All History →', () {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationsHistoryScreen()));
          }),
          const SizedBox(height: 10),
          _whiteCard(
              child: _loadingNotifs
                  ? const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
                  : _notifications.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text('No recent alerts',
                                style: m(13, FontWeight.w500, textGrey)),
                          ),
                        )
                      : Column(
                          children: _notifications
                              .take(4)
                              .map(_buildApiNotifRow)
                              .toList())),

          const SizedBox(height: 20),

          // ── Camera Monitoring ──────────────────────
          _sectionTitle('Camera Monitoring', _elderlyId != null ? 'View Alerts →' : null,
              _elderlyId == null ? null : () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => CameraAlertsScreen(
                      elderlyId: _elderlyId!,
                      elderlyName: _elderlyName ?? 'Elder')))),
          const SizedBox(height: 10),
          _whiteCard(
              child: Row(children: [
            Expanded(
                child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                  color: _fallsToday > 0 ? lightRed : lightGreen,
                  borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text('Falls Today', style: m(12, FontWeight.w500, textGrey)),
                const SizedBox(height: 4),
                Text('$_fallsToday',
                    style: m(26, FontWeight.w700,
                        _fallsToday > 0 ? dangerRed : okGreen)),
              ]),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                  color: _activityBg(), borderRadius: BorderRadius.circular(14)),
              child: Column(children: [
                Text('Activity Level', style: m(12, FontWeight.w500, textGrey)),
                const SizedBox(height: 4),
                Text(_activityLevel,
                    style: m(
                        _activityLevel.length > 8 ? 14 : 18,
                        FontWeight.w700,
                        _activityColor()),
                    textAlign: TextAlign.center),
              ]),
            )),
          ])),

          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  // ── Open Camera (with real IDs) ────────────────────
  void _openCamera() {
    if (_loadingIds) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading data, please wait...')),
      );
      return;
    }
    if (_caregiverId == null || _elderlyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No elderly found. Please add an elderly profile first.')),
      );
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LiveCameraScreen(
            caregiverId: _caregiverId!,
            elderlyId: _elderlyId!,
          ),
        ));
  }

  // ── Battery icon helper ────────────────────────────
  IconData _batteryIcon(int? level) {
    if (level == null) return Icons.battery_unknown;
    if (level >= 90)  return Icons.battery_full;
    if (level >= 60)  return Icons.battery_5_bar;
    if (level >= 40)  return Icons.battery_3_bar;
    if (level >= 20)  return Icons.battery_2_bar;
    return Icons.battery_alert;           // < 20% — warn caregiver
  }

  // ── UI Helpers ─────────────────────────────────────
  Widget _heroStatBox(IconData icon, String label, String value) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: m(11, FontWeight.w500, Colors.white70)),
            Text(value, style: m(16, FontWeight.w700, Colors.white)),
          ]),
        ]),
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

  Widget _sectionTitle(String title, String? action, VoidCallback? onTap) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: m(15, FontWeight.w700, textDark)),
          if (action != null)
            GestureDetector(
                onTap: onTap,
                child: Text(action, style: m(13, FontWeight.w700, primary))),
        ],
      );

  Widget _actionCard(
          {required IconData icon,
          required String label,
          required Color color,
          required Color bg,
          required VoidCallback onTap}) =>
      Material(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: color.withValues(alpha: 0.15),
          highlightColor: color.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 6),
              Text(label,
                  style: m(12, FontWeight.w700, color),
                  textAlign: TextAlign.center),
            ]),
          ),
        ),
      );

  Widget _buildSlotRow(SlotData slot) {
    Color bg;
    Color tc;
    IconData ic;
    Color icC;
    switch (slot.status) {
      case SlotStatus.taken:
        bg = lightGreen;
        tc = okGreen;
        ic = Icons.check_circle;
        icC = okGreen;
        break;
      case SlotStatus.dueSoon:
        bg = infoBlueBg;
        tc = infoBlue;
        ic = Icons.radio_button_checked;
        icC = infoBlue;
        break;
      case SlotStatus.scheduled:
        bg = const Color(0xFFF5F5F5);
        tc = textGrey;
        ic = Icons.radio_button_unchecked;
        icC = textGrey;
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(ic, color: icC, size: 20),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(slot.label, style: m(13, FontWeight.w700, textDark)),
          Text('${slot.time} · ${slot.statusLabel}',
              style: m(11, FontWeight.w500, tc)),
        ]),
      ]),
    );
  }

  // ── Real notification row (from API) ───────────────────────
  Widget _buildApiNotifRow(Map<String, dynamic> n) {
    final type  = n['event_type'] as String? ?? '';
    final time  = _timeAgo(n['created_at'] as String?);
    final name  = n['elderly_name'] as String? ?? '';

    IconData icon;
    Color bc, bgC, ic;
    String title, subtitle;

    switch (type) {
      case 'fall':
        icon = Icons.warning_amber_rounded; bc = dangerRed; bgC = lightRed; ic = dangerRed;
        title = 'Fall Detected';
        subtitle = name.isNotEmpty ? '$name · $time' : time;
        break;
      case 'auto_fall':
        icon = Icons.warning_amber_rounded; bc = dangerRed; bgC = lightRed; ic = dangerRed;
        title = 'Auto-Fall SOS';
        subtitle = name.isNotEmpty ? '$name · $time' : time;
        break;
      case 'sos':
        icon = Icons.sos; bc = dangerRed; bgC = lightRed; ic = dangerRed;
        title = 'SOS Alert';
        subtitle = name.isNotEmpty ? '$name · $time' : time;
        break;
      case 'inactivity':
        icon = Icons.hourglass_empty; bc = const Color(0xFFFFCC80); bgC = warnBg; ic = warnOrange;
        title = 'Inactivity Alert';
        subtitle = name.isNotEmpty ? '$name · $time' : time;
        break;
      case 'sleeping':
        icon = Icons.bedtime_outlined; bc = const Color(0xFF90CAF9); bgC = infoBlueBg; ic = infoBlue;
        title = 'Sleeping Alert';
        subtitle = name.isNotEmpty ? '$name · $time' : time;
        break;
      default:
        icon = Icons.notifications_outlined; bc = const Color(0xFFFFCC80); bgC = warnBg; ic = warnOrange;
        title = 'Alert';
        subtitle = time;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: bgC,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bc, width: 1.2)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: ic, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: m(13, FontWeight.w700, textDark)),
          const SizedBox(height: 2),
          Text(subtitle, style: m(11, FontWeight.w500, textGrey)),
        ])),
      ]),
    );
  }

}

class _SosDialog extends StatelessWidget {
  final String elderlyName;
  final String sosId;
  final bool   isAutoFall;
  final VoidCallback onAcknowledge;
  final VoidCallback onDismiss;

  const _SosDialog({
    required this.elderlyName,
    required this.sosId,
    required this.onAcknowledge,
    required this.onDismiss,
    this.isAutoFall = false,
  });

  @override
  Widget build(BuildContext context) {
    final emoji   = isAutoFall ? '🚨' : '🆘';
    final title   = isAutoFall ? 'Fall Detected — Auto SOS!' : 'SOS Emergency!';
    final body    = isAutoFall
        ? '$elderlyName\'s phone detected a fall.\nThey may be unconscious. Respond immediately!'
        : '$elderlyName needs your help right now!';
    final color   = isAutoFall ? const Color(0xFFB71C1C) : Colors.red;
    final btnText = isAutoFall ? 'Going now — call 911 if needed' : "I'm on my way";

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Column(children: [
        Text(emoji, style: const TextStyle(fontSize: 48)),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          textAlign: TextAlign.center,
        ),
      ]),
      content: Text(
        body,
        style: const TextStyle(fontSize: 15),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: onAcknowledge,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(btnText,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onDismiss,
          child: const Text('Dismiss', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
