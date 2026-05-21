import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/voice_reminder_model.dart';
import '../services/voice_reminder_service.dart';

class VoiceReminderScreen extends StatefulWidget {
  final String? elderlyId;
  const VoiceReminderScreen({super.key, this.elderlyId});
  @override
  State<VoiceReminderScreen> createState() => _VoiceReminderScreenState();
}

class _VoiceReminderScreenState extends State<VoiceReminderScreen>
    with SingleTickerProviderStateMixin {
  // ── Colors ────────────────────────────────────────────────────
  static const primary    = Color(0xFF2FA884);
  static const primaryBg  = Color(0xFFE6F4F0);
  static const dangerRed  = Color(0xFFE53935);
  static const okGreen    = Color(0xFF388E3C);
  static const warnBg     = Color(0xFFFFF8EE);
  static const warnOrange = Color(0xFFF57C00);
  static const bgColor    = Color(0xFFF5F7F6);
  static const textDark   = Color(0xFF1A1A1A);
  static const textGrey   = Color(0xFFAAAAAA);

  static TextStyle m(double size, FontWeight weight, Color color) =>
      TextStyle(fontFamily: 'Montserrat', fontSize: size, fontWeight: weight, color: color);

  // ── State ──────────────────────────────────────────────────────
  bool _isRecording  = false;
  bool _isLoading    = true;
  String? _elderlyId;
  String? _recordingPath;
  int    _recSecs    = 0;

  List<VoiceReminder> _messages = [];
  String? _playingId;

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer   _player   = AudioPlayer();

  late AnimationController _pulseController;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..addStatusListener((s) {
      if (s == AnimationStatus.completed) _pulseController.reverse();
      if (s == AnimationStatus.dismissed && _isRecording) _pulseController.forward();
    });
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingId = null);
    });

    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Prefer the ID passed via constructor; fall back to SharedPreferences
    if (widget.elderlyId != null) {
      _elderlyId = widget.elderlyId;
    } else {
      final prefs = await SharedPreferences.getInstance();
      _elderlyId  = prefs.getString('elderly_id');
    }
    if (_elderlyId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final msgs = await VoiceReminderService.listMessages();
      if (mounted) setState(() { _messages = msgs; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Recording ──────────────────────────────────────────────────
  Future<void> _toggleRecording() async {
    if (_isRecording) {
      _pulseController.stop();
      _pulseController.reset();
      final path = await _recorder.stop();
      setState(() { _isRecording = false; _recordingPath = path; });
      _showSaveDialog();
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        _showSnack('Microphone permission denied', isError: true);
        return;
      }
      final dir  = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      setState(() { _isRecording = true; _recSecs = 0; });
      _pulseController.forward();
      // Tick counter
      Future.doWhile(() async {
        await Future.delayed(const Duration(seconds: 1));
        if (!_isRecording || !mounted) return false;
        setState(() => _recSecs++);
        return true;
      });
    }
  }

  // ── After recording stops: show 3 options ──────────────────────────────────
  void _showSaveDialog() {
    if (_recordingPath == null) return;
    final path = _recordingPath!;
    final secs = _recSecs;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Recording info
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: primaryBg, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              const Icon(Icons.mic_rounded, color: primary, size: 22),
              const SizedBox(width: 12),
              Text('$secs sec recorded', style: m(14, FontWeight.w600, primary)),
            ]),
          ),
          const SizedBox(height: 20),
          Text('What would you like to do?', style: m(15, FontWeight.w700, textDark)),
          const SizedBox(height: 16),

          // ── Option 1: Discard ────────────────────────────────────
          _actionOption(
            icon: Icons.delete_outline_rounded,
            iconColor: textGrey,
            iconBg: const Color(0xFFF0F0F0),
            title: 'Discard',
            subtitle: 'Delete this recording',
            onTap: () => Navigator.pop(ctx),
          ),
          const SizedBox(height: 10),

          // ── Option 2: Send Once ──────────────────────────────────
          _actionOption(
            icon: Icons.send_rounded,
            iconColor: const Color(0xFF1976D2),
            iconBg: const Color(0xFFEBF3FD),
            title: 'Send Once',
            subtitle: 'Send now without saving to your library',
            onTap: () {
              Navigator.pop(ctx);
              if (_elderlyId == null) {
                _showSnack('No elder connected', isError: true);
                return;
              }
              _uploadAndSendOnce(path, secs);
            },
          ),
          const SizedBox(height: 10),

          // ── Option 3: Save & Send ────────────────────────────────
          _actionOption(
            icon: Icons.bookmark_add_outlined,
            iconColor: primary,
            iconBg: primaryBg,
            title: 'Save & Send',
            subtitle: 'Save to library and send to elder',
            onTap: () {
              Navigator.pop(ctx);
              if (_elderlyId == null) {
                _showSnack('No elder connected', isError: true);
                return;
              }
              _showTitleAndSend(path, secs);
            },
          ),
        ]),
      ),
    );
  }

  Widget _actionOption({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      Material(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: m(14, FontWeight.w700, textDark)),
                const SizedBox(height: 2),
                Text(subtitle, style: m(12, FontWeight.w500, textGrey)),
              ])),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFCCCCCC), size: 20),
            ]),
          ),
        ),
      );

  // ── Send Once: upload as non-saved → send → elder gets it immediately ──────
  Future<void> _uploadAndSendOnce(String path, int secs) async {
    _showSnack('Sending…');
    try {
      final msg = await VoiceReminderService.uploadMessage(
        title: 'Quick message – ${TimeOfDay.now().format(context)}',
        elderlyId: _elderlyId!,
        audioFile: File(path),
        durationSecs: secs,
        isSaved: false,            // hidden from library
      );
      await VoiceReminderService.sendMessage(msg.id);
      if (mounted) _showSnack('Sent!');
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    }
  }

  // ── Save & Send: ask for a title, then upload + send + add to list ──────────
  void _showTitleAndSend(String path, int secs) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Name this message', style: m(16, FontWeight.w700, textDark)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: m(13, FontWeight.w500, textDark),
          decoration: InputDecoration(
            hintText: 'e.g. Take your medicine',
            hintStyle: m(13, FontWeight.w400, textGrey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: m(13, FontWeight.w600, textGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              await _uploadSaveAndSend(name, path, secs);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Save & Send', style: m(13, FontWeight.w700, Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Upload with isSaved=true, send, and add to local list ───────────────────
  Future<void> _uploadSaveAndSend(String title, String path, int secs) async {
    try {
      final msg = await VoiceReminderService.uploadMessage(
        title: title,
        elderlyId: _elderlyId!,
        audioFile: File(path),
        durationSecs: secs,
        isSaved: true,
      );
      await VoiceReminderService.sendMessage(msg.id);
      if (mounted) {
        setState(() => _messages.insert(0, msg));
        _showSnack('Saved and sent!');
      }
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    }
  }

  // ── Playback ───────────────────────────────────────────────────
  Future<void> _togglePlay(VoiceReminder msg) async {
    if (_playingId == msg.id) {
      await _player.stop();
      setState(() => _playingId = null);
    } else {
      await _player.stop();
      setState(() => _playingId = msg.id);
      await _player.play(UrlSource(msg.filePath));
    }
  }

  // ── Send ───────────────────────────────────────────────────────
  void _showSendDialog(VoiceReminder msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Send Reminder', style: m(16, FontWeight.w700, textDark)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: primaryBg, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.volume_up_rounded, color: primary, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(msg.title, style: m(13, FontWeight.w600, textDark))),
            ]),
          ),
          const SizedBox(height: 12),
          Text('This message will be played on the elder\'s device immediately.',
              style: m(12, FontWeight.w500, textGrey), textAlign: TextAlign.center),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: m(13, FontWeight.w600, textGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await VoiceReminderService.sendMessage(msg.id);
                if (mounted) {
                  _showSnack('Reminder sent!');
                  // Update used_times locally
                  setState(() {
                    final idx = _messages.indexWhere((m) => m.id == msg.id);
                    if (idx >= 0) {
                      _messages[idx] = VoiceReminder(
                        id:           msg.id,
                        title:        msg.title,
                        filePath:     msg.filePath,
                        usedTimes:    msg.usedTimes + 1,
                        lastUsed:     'Just now',
                        createdAt:    msg.createdAt,
                      );
                    }
                  });
                }
              } catch (e) {
                if (mounted) _showSnack(e.toString(), isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primary, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Send Now', style: m(13, FontWeight.w700, Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Delete ─────────────────────────────────────────────────────
  void _deleteMessage(VoiceReminder msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Message', style: m(16, FontWeight.w700, textDark)),
        content: Text('Delete "${msg.title}"?', style: m(13, FontWeight.w500, textGrey)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: m(13, FontWeight.w600, textGrey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await VoiceReminderService.deleteMessage(msg.id);
                if (mounted) setState(() => _messages.removeWhere((m) => m.id == msg.id));
              } catch (e) {
                if (mounted) _showSnack(e.toString(), isError: true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: dangerRed, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: m(13, FontWeight.w700, Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: m(13, FontWeight.w600, Colors.white)),
      backgroundColor: isError ? dangerRed : okGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Voice Reminder', style: m(17, FontWeight.w700, textDark)),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // ── Record Card ───────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12, offset: const Offset(0, 4),
                    )],
                  ),
                  child: Column(children: [
                    Text('Record New Message', style: m(15, FontWeight.w700, textDark)),
                    const SizedBox(height: 24),
                    AnimatedBuilder(
                      animation: _pulseAnim,
                      builder: (context, child) => Transform.scale(
                        scale: _isRecording ? _pulseAnim.value : 1.0,
                        child: child,
                      ),
                      child: GestureDetector(
                        onTap: _toggleRecording,
                        child: Container(
                          width: 140, height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isRecording ? dangerRed.withValues(alpha: 0.12) : primaryBg,
                            border: Border.all(
                              color: _isRecording ? dangerRed : primary, width: 2.5,
                            ),
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                            size: 56,
                            color: _isRecording ? dangerRed : primary,
                          ),
                        ),
                      ),
                    ),
                    if (_isRecording) ...[
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(width: 8, height: 8,
                            decoration: const BoxDecoration(color: dangerRed, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('$_recSecs s  Recording...', style: m(12, FontWeight.w600, dangerRed)),
                      ]),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _toggleRecording,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecording ? dangerRed : primary,
                          foregroundColor: Colors.white, elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: Icon(_isRecording ? Icons.stop_rounded : Icons.mic_rounded, size: 18),
                        label: Text(
                          _isRecording ? 'Stop Recording' : 'Start Recording',
                          style: m(14, FontWeight.w700, Colors.white),
                        ),
                      ),
                    ),
                  ]),
                ),

                const SizedBox(height: 24),

                // ── Saved Messages ────────────────────────────
                Text('Saved Messages', style: m(15, FontWeight.w700, textDark)),
                const SizedBox(height: 10),

                if (_messages.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(children: [
                      const Icon(Icons.mic_off_outlined, color: textGrey, size: 40),
                      const SizedBox(height: 8),
                      Text('No messages yet.\nRecord your first reminder above.',
                          style: m(13, FontWeight.w500, textGrey), textAlign: TextAlign.center),
                    ]),
                  )
                else
                  ..._messages.map((msg) => _buildMessageTile(msg)),

                const SizedBox(height: 20),

                // ── Tips ──────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: warnBg, borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: warnOrange.withValues(alpha: 0.4), width: 1.2),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.lightbulb_outline_rounded, color: warnOrange, size: 18),
                      const SizedBox(width: 6),
                      Text('Tips for Voice Messages', style: m(13, FontWeight.w700, warnOrange)),
                    ]),
                    const SizedBox(height: 10),
                    ...[
                      'Speak slowly and clearly',
                      'Use a warm, loving tone – it makes them feel cared for',
                      'Keep messages under 20 seconds',
                      'Include specific instructions (e.g., "the blue pill")',
                    ].map((tip) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Container(width: 5, height: 5,
                              decoration: const BoxDecoration(color: warnOrange, shape: BoxShape.circle)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(tip, style: m(12, FontWeight.w500, textDark))),
                      ]),
                    )),
                  ]),
                ),

                const SizedBox(height: 30),
              ]),
            ),
    );
  }

  Widget _buildMessageTile(VoiceReminder msg) {
    final isPlaying = _playingId == msg.id;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
              color: isPlaying ? primary : primaryBg,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.volume_up_rounded,
              color: isPlaying ? Colors.white : primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(msg.title, style: m(13, FontWeight.w700, textDark)),
          const SizedBox(height: 2),
          Text(
            'Used ${msg.usedTimes}× · ${msg.durationSecs}s · ${msg.lastUsed}',
            style: m(11, FontWeight.w500, textGrey),
          ),
        ])),
        IconButton(
          onPressed: () => _togglePlay(msg),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: primary, size: 22,
          ),
        ),
        IconButton(
          onPressed: () => _showSendDialog(msg),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(Icons.send_rounded, color: primary, size: 20),
        ),
        IconButton(
          onPressed: () => _deleteMessage(msg),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          icon: const Icon(Icons.delete_outline, color: dangerRed, size: 20),
        ),
      ]),
    );
  }
}
