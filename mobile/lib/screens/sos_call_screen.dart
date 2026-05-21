import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class SosCallScreen extends StatefulWidget {
  final String elderlyId;
  final String caregiverId;
  final String caregiverName;
  final IO.Socket socket;
  final RTCPeerConnection pc;
  final MediaStream localStream;

  const SosCallScreen({
    super.key,
    required this.elderlyId,
    required this.caregiverId,
    required this.caregiverName,
    required this.socket,
    required this.pc,
    required this.localStream,
  });

  @override
  State<SosCallScreen> createState() => _SosCallScreenState();
}

class _SosCallScreenState extends State<SosCallScreen>
    with TickerProviderStateMixin {
  // ── Palette — matches SosIncomingCallScreen exactly ──────
  static const _green = Color(0xFF2FA884);
  static const _red = Color(0xFFE53935);
  static const _bgTop = Color(0xFF0D2B24);
  static const _bgBottom = Color(0xFF060F0C);
  static const _orange = Color(0xFFFF9800);

  // ── Original logic fields — UNTOUCHED ────────────────────
  bool _muted = false;
  bool _speaker = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;
  String _status = 'Calling caregiver...';

  // ── Animation controllers ─────────────────────────────────
  late AnimationController _fadeCtrl;
  late AnimationController _dotsCtrl; // animated "..." while calling
  late AnimationController _connCtrl; // fade-in when connected
  late Animation<double> _fadeIn;
  late Animation<double> _connIn;
  int _dotCount = 1;
  Timer? _dotTimer;

  @override
  void initState() {
    super.initState();

    // Screen entrance fade
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    // Connected state fade-in
    _connCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _connIn = CurvedAnimation(parent: _connCtrl, curve: Curves.easeOut);

    // Animate the "..." dots while calling
    _dotTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted && _status == 'Calling caregiver...') {
        setState(() => _dotCount = (_dotCount % 3) + 1);
      }
    });

    // ── ALL ORIGINAL LOGIC — UNTOUCHED ────────────────────

    widget.socket.on('sos_call_answered', (data) async {
      if (!mounted) return;
      _dotTimer?.cancel();
      setState(() => _status = 'Connected');
      _connCtrl.forward();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
      });
      final answer = data['answer'];
      if (answer != null) {
        await widget.pc.setRemoteDescription(
          RTCSessionDescription(answer['sdp'], answer['type']),
        );
      }
    });

    widget.socket.on('sos_call_ended', (data) {
      if (!mounted) return;
      _dotTimer?.cancel();
      final reason = data?['reason'] ?? 'ended';
      if (reason == 'declined') {
        setState(() => _status = 'Caregiver unavailable');
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
        });
      } else {
        if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });

    widget.socket.on('sos_ice_candidate', (data) async {
      final c = data['candidate'];
      if (c == null) return;
      try {
        await widget.pc.addCandidate(RTCIceCandidate(
          c['candidate'],
          c['sdpMid'],
          c['sdpMLineIndex'],
        ));
      } catch (_) {}
    });
  }

  Future<void> _hangUp() async {
    _dotTimer?.cancel();
    _timer?.cancel();
    widget.socket.emit('sos_call_end', {
      'elderly_id': widget.elderlyId,
      'caregiver_id': widget.caregiverId,
    });
    await widget.pc.close();
    widget.localStream.dispose();
    widget.socket.off('sos_call_answered');
    widget.socket.off('sos_call_ended');
    widget.socket.off('sos_ice_candidate');
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  String get _elapsedStr {
    final m = _elapsed.inMinutes.toString().padLeft(2, '0');
    final s = (_elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _dotTimer?.cancel();
    _timer?.cancel();
    _fadeCtrl.dispose();
    _connCtrl.dispose();
    widget.socket.off('sos_call_answered');
    widget.socket.off('sos_call_ended');
    widget.socket.off('sos_ice_candidate');
    super.dispose();
  }

  // ── BUILD ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final initial = widget.caregiverName.isNotEmpty
        ? widget.caregiverName[0].toUpperCase()
        : 'C';

    final isCalling = _status == 'Calling caregiver...';
    final isConnected = _status == 'Connected';
    final isDeclined = _status == 'Caregiver unavailable';

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
            child: Column(
              children: [
                // ── Status badge ─────────────────────────
                const SizedBox(height: 48),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isCalling
                      ? _statusBadge(
                          key: const ValueKey('calling'),
                          dot: _orange,
                          border: _orange,
                          label: 'CALLING',
                        )
                      : isConnected
                          ? _statusBadge(
                              key: const ValueKey('connected'),
                              dot: _green,
                              border: _green,
                              label: 'CONNECTED',
                            )
                          : _statusBadge(
                              key: const ValueKey('unavailable'),
                              dot: _red,
                              border: _red,
                              label: 'UNAVAILABLE',
                            ),
                ),

                // ── Avatar + name + status ────────────────
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                                _green.withValues(
                                    alpha: isConnected ? 0.25 : 0.12),
                                _green.withValues(
                                    alpha: isConnected ? 0.08 : 0.04),
                              ],
                            ),
                            border: Border.all(
                              color: isConnected
                                  ? _green.withValues(alpha: 0.55)
                                  : Colors.white.withValues(alpha: 0.15),
                              width: 2,
                            ),
                            boxShadow: isConnected
                                ? [
                                    BoxShadow(
                                      color: _green.withValues(alpha: 0.18),
                                      blurRadius: 24,
                                      spreadRadius: 4,
                                    )
                                  ]
                                : [],
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

                        // Caregiver name
                        Text(widget.caregiverName,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -0.5,
                            )),

                        const SizedBox(height: 14),

                        // Dynamic status line
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: isCalling
                              ? Row(
                                  key: const ValueKey('dots'),
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Calling',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w300,
                                        )),
                                    const SizedBox(width: 2),
                                    Text('.' * _dotCount,
                                        style: const TextStyle(
                                          color: _orange,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w300,
                                          letterSpacing: 2,
                                        )),
                                    // Spinner
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        color: _orange.withValues(alpha: 0.7),
                                        strokeWidth: 1.5,
                                      ),
                                    ),
                                  ],
                                )
                              : isConnected
                                  ? FadeTransition(
                                      key: const ValueKey('timer'),
                                      opacity: _connIn,
                                      child: Text(_elapsedStr,
                                          style: const TextStyle(
                                            color: _green,
                                            fontSize: 26,
                                            fontWeight: FontWeight.w200,
                                            fontFeatures: [
                                              FontFeature.tabularFigures()
                                            ],
                                            letterSpacing: 3,
                                          )),
                                    )
                                  : Text(_status,
                                      key: const ValueKey('declined'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: _red,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      )),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Controls ─────────────────────────────
                Padding(
                  padding: const EdgeInsets.only(bottom: 56),
                  child: Column(
                    children: [
                      // Mute + Speaker row
                      AnimatedOpacity(
                        opacity: isConnected ? 1.0 : 0.35,
                        duration: const Duration(milliseconds: 400),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _toggleButton(
                              icon: _muted
                                  ? Icons.mic_off_rounded
                                  : Icons.mic_rounded,
                              label: _muted ? 'Unmute' : 'Mute',
                              active: _muted,
                              activeColor: _orange,
                              onTap: () {
                                setState(() => _muted = !_muted);
                                widget.localStream
                                    .getAudioTracks()
                                    .forEach((t) => t.enabled = !_muted);
                              },
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
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // End call button
                      GestureDetector(
                        onTap: _hangUp,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _red,
                            boxShadow: [
                              BoxShadow(
                                color: _red.withValues(alpha: 0.35),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.call_end_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text('End Call',
                          style:
                              TextStyle(color: Colors.white38, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── UI helpers ────────────────────────────────────────────

  Widget _statusBadge({
    required Key key,
    required Color dot,
    required Color border,
    required String label,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: dot.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              color: dot,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            )),
      ]),
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
