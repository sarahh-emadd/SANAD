import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SosIncomingCallScreen extends StatefulWidget {
  final String elderlyId;
  final String elderlyName;
  final String caregiverId;
  final Map<String, dynamic> offer;
  final IO.Socket socket;

  const SosIncomingCallScreen({
    super.key,
    required this.elderlyId,
    required this.elderlyName,
    required this.caregiverId,
    required this.offer,
    required this.socket,
  });

  @override
  State<SosIncomingCallScreen> createState() => _SosIncomingCallScreenState();
}

class _SosIncomingCallScreenState extends State<SosIncomingCallScreen>
    with TickerProviderStateMixin {
  // ── Palette ─────────────────────────────────────────────
  static const _green = Color(0xFF2FA884);
  static const _red = Color(0xFFE53935);
  static const _bgTop = Color(0xFF0D2B24);
  static const _bgBottom = Color(0xFF060F0C);

  // ── Original logic fields — UNTOUCHED ───────────────────
  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  bool _callActive = false;
  bool _muted = false;
  bool _speaker = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  Timer? _ringTimer;

  // ── Animation controllers ────────────────────────────────
  late AnimationController _pulseCtrl;
  late AnimationController _rippleCtrl;
  late AnimationController _fadeCtrl;
  late AnimationController _activeCtrl;
  late Animation<double> _pulse;
  late Animation<double> _ripple;
  late Animation<double> _ripple2;
  late Animation<double> _fadeIn;
  late Animation<double> _activeIn;

  @override
  void initState() {
    super.initState();

    // Pulsing accept button scale
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.12)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    // Expanding ripple rings behind avatar
    _rippleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _ripple = CurvedAnimation(
        parent: _rippleCtrl,
        curve: const Interval(0.0, 0.85, curve: Curves.easeOut));
    _ripple2 = CurvedAnimation(
        parent: _rippleCtrl,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut));

    // Entrance fade
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    // Active call fade-in
    _activeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _activeIn = CurvedAnimation(parent: _activeCtrl, curve: Curves.easeOut);

    // ── ORIGINAL LOGIC ─────────────────────────────────────
    _startRinging();
    widget.socket.on('sos_call_ended', (_) => _hangUp(notify: false));
    widget.socket.on('sos_ice_candidate', (data) async {
      if (_pc == null) return;
      final c = data['candidate'];
      if (c == null) return;
      try {
        await _pc!.addCandidate(RTCIceCandidate(
          c['candidate'],
          c['sdpMid'],
          c['sdpMLineIndex'],
        ));
      } catch (_) {}
    });
  }

  // ── ALL ORIGINAL METHODS — UNTOUCHED ─────────────────────

  void _startRinging() {
    HapticFeedback.heavyImpact();
    _ringTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!_callActive) HapticFeedback.heavyImpact();
    });
  }

  Future<void> _acceptCall() async {
    _ringTimer?.cancel();
    _pulseCtrl.stop();
    _rippleCtrl.stop();
    setState(() => _callActive = true);
    _activeCtrl.forward();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });
    _pc = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
      ]
    });
    _localStream!
        .getAudioTracks()
        .forEach((t) => _pc!.addTrack(t, _localStream!));
    _pc!.onIceCandidate = (candidate) {
      widget.socket.emit('sos_ice_candidate', {
        'sender_id': widget.caregiverId,
        'recipient_id': widget.elderlyId,
        'recipient_type': 'elder',
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };
    await _pc!.setRemoteDescription(
        RTCSessionDescription(widget.offer['sdp'], widget.offer['type']));
    final answer = await _pc!.createAnswer({'offerToReceiveAudio': true});
    await _pc!.setLocalDescription(answer);
    widget.socket.emit('sos_call_answer', {
      'elderly_id': widget.elderlyId,
      'caregiver_id': widget.caregiverId,
      'answer': {'sdp': answer.sdp, 'type': answer.type},
    });
  }

  Future<void> _declineCall() async {
    _ringTimer?.cancel();
    widget.socket.emit('sos_call_declined', {
      'elderly_id': widget.elderlyId,
      'caregiver_id': widget.caregiverId,
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _hangUp({bool notify = true}) async {
    _ringTimer?.cancel();
    _timer?.cancel();
    if (notify) {
      widget.socket.emit('sos_call_end', {
        'elderly_id': widget.elderlyId,
        'caregiver_id': widget.caregiverId,
      });
    }
    await _pc?.close();
    _localStream?.dispose();
    if (mounted) Navigator.pop(context);
  }

  String get _elapsedStr {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _ringTimer?.cancel();
    _timer?.cancel();
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    _fadeCtrl.dispose();
    _activeCtrl.dispose();
    _pc?.close();
    _localStream?.dispose();
    widget.socket.off('sos_call_ended');
    widget.socket.off('sos_ice_candidate');
    super.dispose();
  }

  // ── BUILD ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeIn,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
          child: SafeArea(
            child: _callActive ? _buildActiveCall() : _buildIncoming(),
          ),
        ),
      ),
    );
  }

  // ── INCOMING CALL ────────────────────────────────────────
  Widget _buildIncoming() {
    final initial = widget.elderlyName.isNotEmpty
        ? widget.elderlyName[0].toUpperCase()
        : '?';

    return Column(
      children: [
        // ── Top spacer + SOS badge ────────────────────────
        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: _red.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _red.withValues(alpha: 0.35), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 7,
              height: 7,
              decoration:
                  const BoxDecoration(color: _red, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            const Text('SOS EMERGENCY',
                style: TextStyle(
                  color: _red,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                )),
          ]),
        ),

        // ── Avatar with ripple rings ───────────────────────
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(alignment: Alignment.center, children: [
                    // Ripple ring 1
                    AnimatedBuilder(
                      animation: _ripple,
                      builder: (_, __) => _rippleRing(_ripple.value, 220),
                    ),
                    // Ripple ring 2 (offset phase)
                    AnimatedBuilder(
                      animation: _ripple2,
                      builder: (_, __) => _rippleRing(_ripple2.value, 220),
                    ),
                    // Avatar
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _green.withValues(alpha: 0.25),
                            _green.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(
                          color: _green.withValues(alpha: 0.55),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _green.withValues(alpha: 0.18),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(initial,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 44,
                              fontWeight: FontWeight.w200,
                            )),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // Name — centered, large
                Text(
                  widget.elderlyName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.8,
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 10),

                const Text(
                  'needs your help right now',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 16,
                    fontWeight: FontWeight.w300,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        // ── Buttons — horizontally centered side by side ──
        Padding(
          padding: const EdgeInsets.only(bottom: 56),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Decline
              Column(children: [
                _circleButton(
                  size: 70,
                  color: _red,
                  icon: Icons.call_end_rounded,
                  onTap: _declineCall,
                ),
                const SizedBox(height: 10),
                const Text('Decline',
                    style: TextStyle(color: Colors.white38, fontSize: 13)),
              ]),

              const SizedBox(width: 64),

              // Accept (pulsing)
              Column(children: [
                ScaleTransition(
                  scale: _pulse,
                  child: _circleButton(
                    size: 80,
                    color: _green,
                    icon: Icons.call_rounded,
                    onTap: _acceptCall,
                    glow: true,
                  ),
                ),
                const SizedBox(height: 10),
                const Text('Accept',
                    style: TextStyle(color: Colors.white60, fontSize: 13)),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  // ── ACTIVE CALL ──────────────────────────────────────────
  Widget _buildActiveCall() {
    final initial = widget.elderlyName.isNotEmpty
        ? widget.elderlyName[0].toUpperCase()
        : '?';

    return FadeTransition(
      opacity: _activeIn,
      child: Column(
        children: [
          const SizedBox(height: 48),

          // Connected badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _green.withValues(alpha: 0.3)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 6,
                height: 6,
                decoration:
                    const BoxDecoration(color: _green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text('CONNECTED',
                  style: TextStyle(
                    color: _green,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  )),
            ]),
          ),

          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Static avatar
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green.withValues(alpha: 0.12),
                      border: Border.all(
                          color: _green.withValues(alpha: 0.4), width: 2),
                    ),
                    child: Center(
                      child: Text(initial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w200,
                          )),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(widget.elderlyName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center),

                  const SizedBox(height: 12),

                  // Elapsed time
                  Text(_elapsedStr,
                      style: const TextStyle(
                        color: _green,
                        fontSize: 24,
                        fontWeight: FontWeight.w200,
                        fontFeatures: [FontFeature.tabularFigures()],
                        letterSpacing: 2,
                      )),
                ],
              ),
            ),
          ),

          // Control row
          Padding(
            padding: const EdgeInsets.only(bottom: 56),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  _toggleButton(
                    icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    label: _muted ? 'Unmute' : 'Mute',
                    active: _muted,
                    activeColor: const Color(0xFFFF9800),
                    onTap: () => setState(() => _muted = !_muted),
                  ),
                  const SizedBox(width: 40),
                  _toggleButton(
                    icon: _speaker
                        ? Icons.volume_up_rounded
                        : Icons.volume_down_rounded,
                    label: 'Speaker',
                    active: _speaker,
                    activeColor: _green,
                    onTap: () => setState(() => _speaker = !_speaker),
                  ),
                ]),
                const SizedBox(height: 40),
                Column(children: [
                  _circleButton(
                    size: 72,
                    color: _red,
                    icon: Icons.call_end_rounded,
                    onTap: () => _hangUp(),
                  ),
                  const SizedBox(height: 10),
                  const Text('End Call',
                      style: TextStyle(color: Colors.white38, fontSize: 13)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────

  Widget _rippleRing(double t, double maxDiameter) {
    final size = maxDiameter * (0.45 + t * 0.55);
    final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.5;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: _green.withValues(alpha: opacity),
          width: 1.5,
        ),
      ),
    );
  }

  Widget _circleButton({
    required double size,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    bool glow = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: glow
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.5),
                    blurRadius: 28,
                    spreadRadius: 2,
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.42),
      ),
    );
  }

  Widget _toggleButton({
    required IconData icon,
    required String label,
    required bool active,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? activeColor.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.07),
            border: Border.all(
              color: active ? activeColor : Colors.white24,
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            color: active ? activeColor : Colors.white54,
            size: 26,
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: TextStyle(
              color: active ? activeColor : Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w400,
            )),
      ]),
    );
  }
}
