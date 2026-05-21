// lib/screens/pages/home_elder_page.dart
//
// UI:    second design (Montserrat, green hero card, section titles with History →)
// Logic: all from first file (SOS WebRTC call, socket, SharedPrefs, backend) — UNTOUCHED

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../config/api_config.dart';
import '../../models/voice_reminder_model.dart';
import '../../services/location_service.dart';
import '../../services/sos_service.dart';
import '../../services/voice_reminder_service.dart';
import '../sos_call_screen.dart';
import 'elder_settings_screen.dart';
import 'medication_history_screen.dart';
import 'pill_box_alert_history_screen.dart';

// ── Local models ────────────────────────────────────────────────────────────
enum _SlotStatus { taken, dueSoon, scheduled }
class _SlotData {
  final String label, time, statusLabel;
  final _SlotStatus status;
  const _SlotData(this.label, this.time, this.statusLabel, this.status);
}
enum _AlertType { danger, warning, success }
class _AlertData {
  final IconData icon;
  final String title, subtitle, detail;
  final _AlertType type;
  const _AlertData({required this.icon, required this.title,
      required this.subtitle, required this.detail, required this.type});
}

// ════════════════════════════════════════════════════════════════════════════
class HomeElderPage extends StatefulWidget {
  const HomeElderPage({super.key});
  @override
  State<HomeElderPage> createState() => _HomeElderPageState();
}

class _HomeElderPageState extends State<HomeElderPage> {

  // ── Colors ──────────────────────────────────────────────────────────────
  static const primary    = Color(0xFF2FA884);
  static const dangerRed  = Color(0xFFE53935);
  static const lightRed   = Color(0xFFFFF0EE);
  static const okGreen    = Color(0xFF388E3C);
  static const lightGreen = Color(0xFFEEF7EE);
  static const infoBlue   = Color(0xFF1976D2);
  static const infoBlueBg = Color(0xFFEBF3FD);
  static const warnBg     = Color(0xFFFFF8EE);
  static const warnOrange = Color(0xFFF57C00);
  static const bgColor    = Color(0xFFF5F7F6);
  static const textDark   = Color(0xFF1A1A1A);
  static const textGrey   = Color(0xFFAAAAAA);

  static TextStyle m(double sz, FontWeight w, Color c) =>
      TextStyle(fontFamily: 'Montserrat', fontSize: sz, fontWeight: w, color: c);

  // ── UI state ─────────────────────────────────────────────────────────────
  bool _isPlayingVoice = false;
  String? _playingMessageId;
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ── Logic state ───────────────────────────────────────────────────────────
  bool    _sosLoading    = false;
  String? _elderlyId;
  String? _caregiverId;
  String? _caregiverName;
  String? _elderlyName;
  IO.Socket? _elderSocket;
  bool    _helpOnWay = false;
  final Battery _battery = Battery();

  // ── Periodic location update ─────────────────────────────────────────────
  Timer? _locationTimer;

  // ── Fall detection state machine ─────────────────────────────────────────
  StreamSubscription<AccelerometerEvent>? _accelSub;
  bool   _freefallActive   = false;
  DateTime? _freefallStart;
  bool   _fallDialogShown  = false;         // guard: one dialog at a time
  Timer? _fallCancelTimer;
  int    _fallCountdown    = 10;

  // Thresholds (m/s²):
  static const double _freefallThreshold = 2.5;   // near-zero g → phone in air
  static const double _impactThreshold   = 22.0;  // sudden spike → landed
  static const int    _impactWindowMs    = 2000;   // impact must happen within 2 s

  // ── Voice messages received ──────────────────────────────────────────────
  List<VoiceReminder> _voiceMessages = [];

  // ── Static data ──────────────────────────────────────────────────────────
  static const List<_SlotData> slots = [
    _SlotData('Slot 1', '8:00 AM',  'Taken',     _SlotStatus.taken),
    _SlotData('Slot 2', '12:00 PM', 'Due Soon',  _SlotStatus.dueSoon),
    _SlotData('Slot 3', '8:00 PM',  'Scheduled', _SlotStatus.scheduled),
  ];
  static const List<_AlertData> alerts = [
    _AlertData(icon: Icons.error_outline,       title: 'Missed Dose',   subtitle: 'from Slot 2',    detail: '12:00 PM  •  missed from 30 mins ago', type: _AlertType.danger),
    _AlertData(icon: Icons.autorenew,           title: 'Refill Needed', subtitle: 'Slot 1 is Empty',detail: '',                                     type: _AlertType.warning),
    _AlertData(icon: Icons.check_circle_outline,title: 'Taken',         subtitle: 'from slot 1',    detail: '8:00 AM  •  Taken from 30 mins ago',   type: _AlertType.success),
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadElderlyId();
    _startFallDetection();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _accelSub?.cancel();
    _fallCancelTimer?.cancel();
    _audioPlayer.dispose();
    _elderSocket?.dispose();
    super.dispose();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ALL LOGIC FROM FIRST FILE — COMPLETELY UNTOUCHED
  // ════════════════════════════════════════════════════════════════════════════

  // ════════════════════════════════════════════════════════════════════════════
  // FALL DETECTION — accelerometer state machine
  // ════════════════════════════════════════════════════════════════════════════

  void _startFallDetection() {
    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen(_onAccelerometer);
  }

  void _onAccelerometer(AccelerometerEvent e) {
    if (_fallDialogShown) return;

    final magnitude = sqrt(e.x * e.x + e.y * e.y + e.z * e.z);

    if (!_freefallActive) {
      // Phase 1: detect freefall (very low acceleration)
      if (magnitude < _freefallThreshold) {
        _freefallActive = true;
        _freefallStart  = DateTime.now();
      }
    } else {
      // Phase 2: waiting for impact spike
      final elapsed = DateTime.now().difference(_freefallStart!).inMilliseconds;

      if (elapsed > _impactWindowMs) {
        // Took too long — not a fall, reset
        _freefallActive = false;
        _freefallStart  = null;
        return;
      }

      if (magnitude > _impactThreshold) {
        // ✅ Fall signature matched: freefall → impact
        _freefallActive = false;
        _freefallStart  = null;
        _onFallDetected();
      }
    }
  }

  void _onFallDetected() {
    if (_fallDialogShown || !mounted) return;
    _fallDialogShown = true;

    HapticFeedback.heavyImpact();

    StateSetter? _dialogSetState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSS) {
          _dialogSetState = setSS;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: Colors.white,
            title: Column(children: [
              const Text('⚠️', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              Text(
                'Fall Detected!',
                style: m(20, FontWeight.w800, const Color(0xFFE53935)),
                textAlign: TextAlign.center,
              ),
            ]),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                'A fall was automatically detected.\nSOS will be sent in:',
                style: m(14, FontWeight.w500, const Color(0xFF444444)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                '$_fallCountdown',
                style: m(52, FontWeight.w800, const Color(0xFFE53935)),
              ),
              const SizedBox(height: 8),
              Text('seconds', style: m(13, FontWeight.w500, const Color(0xFFAAAAAA))),
            ]),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _fallCancelTimer?.cancel();
                    _fallDialogShown = false;
                    Navigator.of(context, rootNavigator: true).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2FA884),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text("I'm OK — Cancel SOS",
                      style: m(15, FontWeight.w700, Colors.white)),
                ),
              ),
            ],
          );
        },
      ),
    ).then((_) {
      _dialogSetState = null;
      _fallDialogShown = false;
    });

    // Re-wire timer to also call _dialogSetState so countdown updates inside dialog
    _fallCancelTimer?.cancel();
    _fallCountdown = 10;
    _fallCancelTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _fallCountdown--);
      _dialogSetState?.call(() {}); // rebuild dialog number
      if (_fallCountdown <= 0) {
        t.cancel();
        Navigator.of(context, rootNavigator: true).pop();
        _triggerAutoFallSos();
      }
    });
  }

  Future<void> _triggerAutoFallSos() async {
    _fallDialogShown = false;
    if (_elderlyId == null || !mounted) return;

    HapticFeedback.heavyImpact();

    final sosId = await SosService.triggerSos(
      _elderlyId!,
      source: 'auto_fall',
    );

    if (!mounted) return;

    if (sosId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Auto-SOS failed to send. Please press SOS manually.'),
        backgroundColor: Color(0xFFE53935),
      ));
      return;
    }

    // Also start the WebRTC call so caregiver can see/hear the elder
    await _startSosCall();
  }

  Future<void> _loadElderlyId() async {
    final prefs = await SharedPreferences.getInstance();
    final id  = prefs.getString('elderly_id');
    var   cid = prefs.getString('caregiver_id');
    if (id == null) return;
    try {
      final res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/elderly/$id/caregiver-id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(ApiConfig.timeout);
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body)['data'];
        cid = d['caregiver_id']?.toString() ?? cid;
        final cn = d['caregiver_name']?.toString();
        final en = d['elderly_name']?.toString();
        if (cid != null && cid.isNotEmpty) await prefs.setString('caregiver_id', cid);
        if (cn  != null && cn.isNotEmpty)  await prefs.setString('caregiver_name', cn);
        if (en  != null && en.isNotEmpty)  await prefs.setString('elderly_name', en);
      }
    } catch (e) { debugPrint('Could not fetch names: $e'); }
    final cn = prefs.getString('caregiver_name');
    final en = prefs.getString('elderly_name');
    setState(() { _elderlyId = id; _caregiverId = cid; _caregiverName = cn; _elderlyName = en; });
    _connectElderSocket(id);
    _reportLocationWithBattery(id);
    _loadElderMessages(id);
  }

  Future<void> _reportLocationWithBattery(String elderlyId) async {
    int? level;
    try { level = await _battery.batteryLevel; } catch (_) {}
    await LocationService.reportLocation(elderlyId, batteryLevel: level);

    // Start periodic updates every 3 minutes so caregiver always has fresh location
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(minutes: 3), (_) async {
      if (!mounted) return;
      int? bat;
      try { bat = await _battery.batteryLevel; } catch (_) {}
      LocationService.reportLocation(elderlyId, batteryLevel: bat);
    });
  }

  Future<void> _loadElderMessages(String elderlyId) async {
    try {
      final msgs = await VoiceReminderService.listElderMessages(elderlyId);
      if (mounted) setState(() => _voiceMessages = msgs);
    } catch (_) {}
  }

  void _connectElderSocket(String elderlyId) {
    _elderSocket?.dispose();
    _elderSocket = IO.io(ApiConfig.socketUrl,
        IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect()
            .enableReconnection().setReconnectionAttempts(999).setReconnectionDelay(2000).build());
    _elderSocket!.connect();
    _elderSocket!.onConnect((_) =>
        _elderSocket!.emit('register_elder', {'elderly_id': elderlyId}));
    _elderSocket!.on('voice_message', (data) {
      if (!mounted || data == null) return;
      try {
        final msg = VoiceReminder.fromJson(Map<String, dynamic>.from(data as Map));
        setState(() => _voiceMessages = [msg, ..._voiceMessages]);
        HapticFeedback.mediumImpact();
      } catch (_) {}
    });
    _elderSocket!.on('sos_seen', (data) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() => _helpOnWay = true);
      showDialog(
        context: context, barrierDismissible: true,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          title: const Column(children: [
            Text('💚', style: TextStyle(fontSize: 48)), SizedBox(height: 8),
            Text('Help is on the way!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF2FA884)),
                textAlign: TextAlign.center),
          ]),
          content: const Text('Your caregiver has been notified and is coming to help you.',
              style: TextStyle(fontSize: 15), textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [ElevatedButton(
            onPressed: () { Navigator.pop(context); setState(() => _helpOnWay = false); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2FA884), foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('OK', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          )],
        ),
      );
    });
  }

  Future<void> _triggerSos() async {
    if (_sosLoading) return;
    if (_elderlyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to send SOS: profile not loaded yet')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send SOS?'),
        content: const Text('This will immediately alert your caregiver.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Send SOS')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _sosLoading = true);
    final sosId = await SosService.triggerSos(_elderlyId!);
    setState(() => _sosLoading = false);
    if (!mounted) return;
    if (sosId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Failed to send SOS. Please try again or call directly.'),
        backgroundColor: Colors.orange));
      return;
    }
    await _startSosCall();
  }

  Future<void> _startSosCall() async {
    if (_elderSocket == null || _elderlyId == null || _caregiverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot call: not connected')));
      return;
    }
    try {
      final localStream = await navigator.mediaDevices.getUserMedia({'audio': true, 'video': false});
      final pc = await createPeerConnection({
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ]
      });
      localStream.getAudioTracks().forEach((t) => pc.addTrack(t, localStream));
      pc.onIceCandidate = (candidate) {
        _elderSocket!.emit('sos_ice_candidate', {
          'sender_id': _elderlyId, 'recipient_id': _caregiverId, 'recipient_type': 'caregiver',
          'candidate': {'candidate': candidate.candidate, 'sdpMid': candidate.sdpMid,
              'sdpMLineIndex': candidate.sdpMLineIndex},
        });
      };
      final offer = await pc.createOffer({'offerToReceiveAudio': true});
      await pc.setLocalDescription(offer);
      _elderSocket!.emit('sos_call_offer', {
        'elderly_id': _elderlyId, 'caregiver_id': _caregiverId,
        'elderly_name': _elderlyName ?? 'Elder',
        'offer': {'sdp': offer.sdp, 'type': offer.type},
      });
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => SosCallScreen(
          elderlyId: _elderlyId!, caregiverId: _caregiverId!,
          caregiverName: _caregiverName ?? 'Caregiver',
          socket: _elderSocket!, pc: pc, localStream: localStream,
        )));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call failed: $e'), backgroundColor: Colors.red));
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // BUILD — second file UI exactly
  // ════════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final now    = DateTime.now();
    final days   = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final months = ['January','February','March','April','May','June','July','August','September','October','November','December'];
    final date   = '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white, elevation: 0, surfaceTintColor: Colors.white,
        automaticallyImplyLeading: false,
        title: Text('Sanad', style: m(20, FontWeight.w700, textDark)),
        centerTitle: true,
        actions: [IconButton(
          icon: const Icon(Icons.settings_outlined, color: textDark),
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ElderSettingsScreen())),
        )],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Hero card ───────────────────────────────────────────
          Container(
            width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(date, style: m(12, FontWeight.w500, Colors.white60)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Good morning,\n${_elderlyName ?? 'Margaret'}!',
                        style: m(20, FontWeight.w700, Colors.white).copyWith(height: 1.3)),
                    const SizedBox(height: 6),
                    Text('Your Sanad is with you 💚',
                        style: m(13, FontWeight.w500, Colors.white70)),
                  ])),
                  const SizedBox(width: 12),

                  // ── SOS button — wired to _triggerSos ──────────
                  ElevatedButton.icon(
                    onPressed: _sosLoading ? null : _triggerSos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: dangerRed,
                      disabledBackgroundColor: Colors.white70,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      minimumSize: Size.zero,
                    ),
                    icon: _sosLoading
                        ? const SizedBox(width: 15, height: 15,
                            child: CircularProgressIndicator(color: dangerRed, strokeWidth: 2))
                        : const Icon(Icons.phone, size: 16, color: dangerRed),
                    label: Text(_sosLoading ? '' : 'SOS',
                        style: m(13, FontWeight.w700, dangerRed)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _heroStatBox(Icons.check_circle, 'Meds Today', '2 / 3')),
                const SizedBox(width: 10),
                Expanded(child: _heroStatBox(Icons.person_outline, 'Caregiver',
                    _caregiverName ?? 'Olivia')),
              ]),
            ]),
          ),

          const SizedBox(height: 20),

          // ── Today's Medications ─────────────────────────────────
          _sectionTitle("Today's Medications", 'History →', () =>
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const MedicationHistoryScreen()))),
          const SizedBox(height: 10),
          _whiteCard(child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Today', style: m(13, FontWeight.w500, textGrey)),
              Text('2 / 3', style: m(13, FontWeight.w700, primary)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: 2 / 3, minHeight: 8,
                  backgroundColor: const Color(0xFFEEEEEE), color: primary),
            ),
            const SizedBox(height: 14),
            ...slots.map(_buildSlotRow),
          ])),

          const SizedBox(height: 20),

          // ── Pill Box Alerts ─────────────────────────────────────
          _sectionTitle('Pill Box Alerts', 'History →', () =>
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const PillBoxAlertHistoryScreen()))),
          const SizedBox(height: 10),
          _whiteCard(child: Column(children: alerts.map(_buildAlertRow).toList())),

          const SizedBox(height: 20),

          // ── Messages ────────────────────────────────────────────
          _sectionTitle('Messages', null, null),
          const SizedBox(height: 10),
          if (_voiceMessages.isEmpty)
            _whiteCard(child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(children: [
                  Icon(Icons.graphic_eq, color: textGrey, size: 36),
                  const SizedBox(height: 8),
                  Text('No messages yet', style: m(13, FontWeight.w500, textGrey)),
                ]),
              ),
            ))
          else
            _whiteCard(child: Column(
              children: _voiceMessages.map((msg) => _buildVoiceMessageRow(msg)).toList(),
            )),

          const SizedBox(height: 30),
        ]),
      ),
    );
  }

  // ── UI helpers ─────────────────────────────────────────────────────────────

  // ⭐ FIXED: Added Expanded and overflow handling to prevent text overflow
  Widget _heroStatBox(IconData icon, String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14)
    ),
    child: Row(children: [
      Icon(icon, color: Colors.white, size: 22), 
      const SizedBox(width: 8),
      Expanded(  // ⭐ ADDED: Allows text to take available space
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Text(
              label, 
              style: m(11, FontWeight.w500, Colors.white70),
              overflow: TextOverflow.ellipsis,  // ⭐ ADDED: Handles overflow
              maxLines: 1,  // ⭐ ADDED: Single line only
            ),
            Text(
              value,  
              style: m(16, FontWeight.w700, Colors.white),
              overflow: TextOverflow.ellipsis,  // ⭐ ADDED: Shows "..." for long text
              maxLines: 1,  // ⭐ ADDED: Single line only
            ),
          ],
        ),
      ),
    ]),
  );

  Widget _whiteCard({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12, offset: const Offset(0, 4))]),
    child: child,
  );

  Widget _sectionTitle(String title, String? action, VoidCallback? onTap) =>
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(title, style: m(15, FontWeight.w700, textDark)),
        if (action != null)
          GestureDetector(onTap: onTap,
              child: Text(action, style: m(13, FontWeight.w700, primary))),
      ]);

  Widget _buildSlotRow(_SlotData slot) {
    Color bg, tc, icC; IconData ic;
    switch (slot.status) {
      case _SlotStatus.taken:     bg = lightGreen;              tc = okGreen;  ic = Icons.check_circle;           icC = okGreen;  break;
      case _SlotStatus.dueSoon:   bg = infoBlueBg;              tc = infoBlue; ic = Icons.radio_button_checked;   icC = infoBlue; break;
      case _SlotStatus.scheduled: bg = const Color(0xFFF5F5F5); tc = textGrey; ic = Icons.radio_button_unchecked; icC = textGrey; break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(ic, color: icC, size: 20), const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(slot.label, style: m(13, FontWeight.w700, textDark)),
          Text('${slot.time} · ${slot.statusLabel}', style: m(11, FontWeight.w500, tc)),
        ]),
      ]),
    );
  }

  Widget _buildVoiceMessageRow(VoiceReminder msg) {
    final isPlaying = _playingMessageId == msg.id && _isPlayingVoice;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
          child: Icon(Icons.account_circle, color: Colors.grey.shade500, size: 38),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(msg.title, style: m(14, FontWeight.w700, textDark)),
          Text('From ${_caregiverName ?? 'Caregiver'}',
              style: m(12, FontWeight.w500, textGrey)),
        ])),
        GestureDetector(
          onTap: () async {
            if (isPlaying) {
              await _audioPlayer.pause();
              setState(() => _isPlayingVoice = false);
            } else {
              setState(() { _playingMessageId = msg.id; _isPlayingVoice = true; });
              await _audioPlayer.play(UrlSource(msg.filePath));
              _audioPlayer.onPlayerComplete.listen((_) {
                if (mounted) setState(() { _isPlayingVoice = false; _playingMessageId = null; });
              });
            }
          },
          child: Container(
            width: 42, height: 42,
            decoration: const BoxDecoration(color: primary, shape: BoxShape.circle),
            child: Icon(isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white, size: 24),
          ),
        ),
      ]),
    );
  }

  Widget _buildAlertRow(_AlertData alert) {
    Color bc, bgC, ic;
    switch (alert.type) {
      case _AlertType.danger:  bc = dangerRed;               bgC = lightRed;   ic = dangerRed;   break;
      case _AlertType.warning: bc = const Color(0xFFFFCC80); bgC = warnBg;     ic = warnOrange;  break;
      case _AlertType.success: bc = const Color(0xFFA5D6A7); bgC = lightGreen; ic = okGreen;     break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bgC, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bc, width: 1.2)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(alert.icon, color: ic, size: 20), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(alert.title, style: m(13, FontWeight.w700, textDark)),
          const SizedBox(height: 2),
          Text(alert.subtitle, style: m(11, FontWeight.w500, textGrey)),
          if (alert.detail.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(alert.detail, style: m(11, FontWeight.w500, ic.withValues(alpha: 0.8))),
          ],
        ])),
      ]),
    );
  }
}