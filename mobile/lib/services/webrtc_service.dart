import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../config/api_config.dart';

typedef OnConnected = void Function(MediaStream stream);
typedef OnDisconnected = void Function();
typedef OnError = void Function();
typedef OnAlert = void Function(Map<String, dynamic> alert);
typedef OnCameraOffline = void Function();
typedef OnAssignFailed = void Function(String message);
typedef OnSosAlert = void Function(Map<String, dynamic> data);

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? _remoteStream;
  IO.Socket? _socket;
  Timer? _connectTimeout;

  // ICE candidates that arrived before setRemoteDescription completed
  bool _remoteDescSet = false;
  final List<RTCIceCandidate> _pendingCandidates = [];

  final String caregiverId;
  final String elderlyId;

  final OnConnected onConnected;
  final OnDisconnected onDisconnected;
  final OnError onError;
  final OnAlert? onAlert;
  final OnCameraOffline? onCameraOffline;
  final OnAssignFailed? onAssignFailed;
  final OnSosAlert? onSosAlert;

  WebRTCService({
    required this.caregiverId,
    required this.elderlyId,
    required this.onConnected,
    required this.onDisconnected,
    required this.onError,
    this.onAlert,
    this.onCameraOffline,
    this.onAssignFailed,
    this.onSosAlert,
  });

  Future<void> connect() async {
    // ── Clean up any previous state ───────────────────────────
    _connectTimeout?.cancel();
    _connectTimeout = null;
    _remoteDescSet = false;
    _pendingCandidates.clear();
    try {
      _peerConnection?.close();
    } catch (_) {}
    try {
      _peerConnection?.dispose();
    } catch (_) {}
    _peerConnection = null;
    try {
      _remoteStream?.dispose();
    } catch (_) {}
    _remoteStream = null;
    try {
      _socket?.dispose();
    } catch (_) {}
    _socket = null;

    try {
      // ── 1. Socket — listeners registered BEFORE connect() ───
      // forceNew=true is critical: socket_io_client caches the Manager per URL,
      // so a second connect() on the same URL was returning a dead cached
      // socket whose onConnect never fired (request_stream never sent).
      _socket = IO.io(
        ApiConfig.socketUrl,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .enableForceNew()
            .build(),
      );

      // ── 2. WebRTC peer connection ────────────────────────────
      // STUN servers help ICE gather valid candidates even on local network.
      // Same-Mac iOS Simulator: host candidates usually work, but STUN makes it reliable.
      _peerConnection = await createPeerConnection({
        'iceServers': [
          {
            'urls': [
              'stun:stun.l.google.com:19302',
              'stun:stun1.l.google.com:19302',
            ],
          },
        ],
        'iceTransportPolicy': 'all',
        'bundlePolicy': 'max-bundle',
        'rtcpMuxPolicy': 'require',
      });

      await _peerConnection!.addTransceiver(
        kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
        init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
      );

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          _connectTimeout?.cancel();
          onConnected(_remoteStream!);
        }
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        // Only send non-empty candidates
        if (candidate.candidate != null && candidate.candidate!.isNotEmpty) {
          _socket?.emit('ice_candidate', {
            'sender_id': caregiverId,
            'recipient_id': elderlyId,
            'candidate': candidate.toMap(),
          });
        }
      };

      _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
          _connectTimeout?.cancel();
        }
        if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
            state ==
                RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
          onDisconnected();
        }
      };

      // ── 3. Socket event listeners ────────────────────────────

      // 'registered' — no-op. We now ALWAYS emit request_stream in onConnect,
      // so re-acting to the server's re-notify would double-fire it and corrupt
      // Python's WebRTC state (two offers in a row → answer applies to wrong pc).
      _socket!.on('registered', (_) {});

      // NOTE: do NOT disconnect on camera_assignment_failed.
      // Server may emit this transiently while Python is still booting/registering.
      // We just keep waiting — the 60s overall timeout below handles real failures.
      _socket!.on('camera_assignment_failed', (_) {
        // Intentionally swallowed. Keep the socket alive so Python can register.
      });

      _socket!.on('webrtc_offer', (data) async {
        if (_peerConnection == null) return;
        try {
          final offer = RTCSessionDescription(
            data['offer']['sdp'],
            data['offer']['type'],
          );
          await _peerConnection!.setRemoteDescription(offer);
          // Mark remote description ready, then drain any queued ICE candidates.
          // Candidates arriving before this point were queued in _pendingCandidates.
          _remoteDescSet = true;
          for (final c in _pendingCandidates) {
            try {
              await _peerConnection!.addCandidate(c);
            } catch (_) {}
          }
          _pendingCandidates.clear();

          final answer = await _peerConnection!.createAnswer();
          await _peerConnection!.setLocalDescription(answer);
          _socket!.emit('webrtc_answer', {
            'sender_id': caregiverId,
            'recipient_id': elderlyId,
            'answer': answer.toMap(),
          });
        } catch (e) {
          onError();
        }
      });

      _socket!.on('ice_candidate', (data) async {
        if (_peerConnection == null) return;
        try {
          final c = data['candidate'];
          if (c == null) return;
          final candidate = RTCIceCandidate(
            c['candidate'] as String,
            c['sdpMid'] as String?,
            c['sdpMLineIndex'] is int ? c['sdpMLineIndex'] as int : null,
          );
          if (!_remoteDescSet) {
            // Remote description not set yet — queue the candidate
            _pendingCandidates.add(candidate);
            return;
          }
          await _peerConnection!.addCandidate(candidate);
        } catch (_) {}
      });

      _socket!.on('new_alert', (data) {
        if (onAlert != null && data is Map) {
          onAlert!(Map<String, dynamic>.from(data));
        }
      });

      _socket!.on('camera_offline', (_) => onCameraOffline?.call());

      _socket!.on('sos_alert', (data) {
        if (onSosAlert != null && data is Map) {
          onSosAlert!(Map<String, dynamic>.from(data));
        }
      });

      _socket!.onConnectError((err) {
        // ignore: avoid_print
        print('[WebRTC] socket connect error: $err');
        _connectTimeout?.cancel();
        onError();
      });

      _socket!.onDisconnect((_) => onDisconnected());

      // ── 4. onConnect: join room then request stream ──────────
      //
      // request_stream now handles all three cases on the server:
      //   • Python already in elder room  → start_stream forwarded directly
      //   • Python waiting in pool        → server assigns + camera_assigned sent
      //   • Python not running yet        → pending stored, fires when Python connects
      _socket!.onConnect((_) {
        // ignore: avoid_print
        print('[WebRTC] socket connected — joining + requesting stream');
        _socket!.emit('join_caregiver_room', {
          'sender_id': caregiverId,
          'caregiver_id': caregiverId,
        });

        // Emit immediately — socket.io guarantees event ordering on the wire,
        // so the 400 ms delay was unnecessary and was masking real failures.
        _socket!.emit('request_stream', {
          'sender_id': caregiverId,
          'recipient_id': elderlyId,
        });

        // Timeout: if no stream within 60s, give up.
        // Longer than before — Python may still be starting up, and ICE gathering
        // with STUN can take 5–10s on first run.
        _connectTimeout?.cancel();
        _connectTimeout = Timer(const Duration(seconds: 60), () {
          onAssignFailed?.call(
            'Camera did not respond. Make sure Python is running.',
          );
          onError();
        });
      });

      // ── 5. Connect ───────────────────────────────────────────
      _socket!.connect();
    } catch (e) {
      _connectTimeout?.cancel();
      onError();
    }
  }

  void disconnect() {
    _connectTimeout?.cancel();
    _connectTimeout = null;
    try {
      _socket?.emit('stop_stream', {
        'sender_id': caregiverId,
        'recipient_id': elderlyId,
      });
    } catch (_) {}
    try {
      _peerConnection?.close();
    } catch (_) {}
    try {
      _peerConnection?.dispose();
    } catch (_) {}
    _peerConnection = null;
    try {
      _remoteStream?.dispose();
    } catch (_) {}
    _remoteStream = null;
    try {
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    onDisconnected();
  }
}
