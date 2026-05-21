import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'caregiver_home_screen.dart';
import '../services/elderly_service.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ElderConnectQRScreen extends StatefulWidget {
  final Map<String, dynamic> elderData;

  const ElderConnectQRScreen({super.key, required this.elderData});

  @override
  State<ElderConnectQRScreen> createState() => _ElderConnectQRScreenState();
}

class _ElderConnectQRScreenState extends State<ElderConnectQRScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  String? _qrCodeImage; // base64 PNG
  String? _manualCode;
  DateTime? _expiresAt;
  String? _elderlyId;

  Timer? _countdownTimer;
  int _remainingSeconds = 300; // 5 minutes

  @override
  void initState() {
    super.initState();
    _createProfile();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ── Create profile and get QR from backend ─────────────────────────────────
  Future<void> _createProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await ElderlyService.createProfile(widget.elderData);
      final elderly = result['elderly'];

      if (!mounted) return;

      // Save elderly_id BEFORE setState — await is not allowed inside setState()
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('elderly_id', elderly.id as String);
      // Save caregiver_id so elder can call caregiver during SOS
      final caregiverId = elderly.caregiverId ?? result['caregiver_id'];
      if (caregiverId != null)
        await prefs.setString('caregiver_id', caregiverId as String);

      setState(() {
        _elderlyId = elderly.id;
        _qrCodeImage = result['qrCodeImage'];
        _manualCode = result['manualCode'];
        _expiresAt = result['expiresAt'] != null
            ? DateTime.parse(result['expiresAt'])
            : DateTime.now().add(const Duration(minutes: 5));
        _remainingSeconds =
            _expiresAt!.difference(DateTime.now()).inSeconds.clamp(0, 300);
        _isLoading = false;
      });
      _startCountdown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to create profile. Please try again.';
        _isLoading = false;
      });
    }
  }

  // ── Regenerate QR ──────────────────────────────────────────────────────────
  Future<void> _regenerateQR() async {
    if (_elderlyId == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await ElderlyService.regenerateQR(_elderlyId!);
      _countdownTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _qrCodeImage = result['qrCodeImage'];
        _manualCode = result['manualCode'];
        _expiresAt = result['expiresAt'] != null
            ? DateTime.parse(result['expiresAt'])
            : DateTime.now().add(const Duration(minutes: 5));
        _remainingSeconds = 300;
        _isLoading = false;
      });
      _startCountdown();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _remainingSeconds =
            (_expiresAt!.difference(DateTime.now()).inSeconds).clamp(0, 300);
      });
      if (_remainingSeconds <= 0) t.cancel();
    });
  }

  void _copyCode() {
    if (_manualCode == null) return;
    Clipboard.setData(ClipboardData(text: _manualCode!));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Pairing code copied!',
          style: GoogleFonts.inter(color: Colors.white)),
      backgroundColor: AppTheme.primaryGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  String get _timerText {
    final m = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get _elderFirstName =>
      widget.elderData['firstName']?.toString() ?? 'Elder';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha(15),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ]),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: AppTheme.textDark),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          : _errorMessage != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.inter(fontSize: 15, color: AppTheme.textDark)),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: _createProfile, child: const Text('Try Again')),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 200,
              height: 160,
              decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withAlpha(25),
                  shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset('assets/images/qr_elder.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                        Icons.people_alt_outlined,
                        size: 80,
                        color: AppTheme.primaryGreen.withAlpha(120))),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Connect Elder',
              style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark)),
          const SizedBox(height: 8),
          Text('Share this code with $_elderFirstName',
              style:
                  GoogleFonts.inter(fontSize: 14.5, color: AppTheme.textLight)),
          const SizedBox(height: 28),

          // ── QR Code Image from backend ─────────────────────────────────────
          if (_qrCodeImage != null)
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(18),
                        blurRadius: 16,
                        offset: const Offset(0, 4))
                  ]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.memory(
                  base64Decode(_qrCodeImage!.split(',').last),
                  fit: BoxFit.contain,
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ── Countdown timer ────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.timer_outlined,
                  size: 16,
                  color: _remainingSeconds < 60
                      ? AppTheme.errorRed
                      : AppTheme.textLight),
              const SizedBox(width: 6),
              Text(
                _remainingSeconds > 0
                    ? 'Expires in $_timerText'
                    : 'QR Code Expired',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _remainingSeconds < 60
                      ? AppTheme.errorRed
                      : AppTheme.textLight,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          if (_remainingSeconds <= 0) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _regenerateQR,
              icon: const Icon(Icons.refresh, color: AppTheme.primaryGreen),
              label: Text('Generate New QR Code',
                  style: GoogleFonts.inter(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w600)),
            ),
          ],

          const SizedBox(height: 16),
          Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Divider(color: AppTheme.borderColor.withAlpha(180))),
          const SizedBox(height: 12),
          Text('OR Enter Code Manually',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textDark)),
          const SizedBox(height: 12),

          // ── Manual code ────────────────────────────────────────────────────
          if (_manualCode != null)
            GestureDetector(
              onTap: _copyCode,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withAlpha(20),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.primaryGreen.withAlpha(80), width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Pairing Code : ',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark)),
                    Text(_manualCode!,
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primaryGreen,
                            letterSpacing: 2)),
                    const SizedBox(width: 10),
                    const Icon(Icons.copy_rounded,
                        size: 18, color: AppTheme.primaryGreen),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),
          Text('Show this QR to Elder or Enter this\nCode Manually',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13.5, color: AppTheme.textLight, height: 1.6)),
          const SizedBox(height: 36),

          // ── Finish button ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: OutlinedButton(
              onPressed: () {
                // Pop all screens and land on CaregiverHomeScreen
                // (not isFirst which would go back to OnboardingWrapper)
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CaregiverHomeScreen()),
                  (route) => false,
                );
              },
              style: OutlinedButton.styleFrom(
                side:
                    const BorderSide(color: AppTheme.primaryGreen, width: 1.8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50)),
                minimumSize: const Size(double.infinity, 54),
              ),
              child: Text('Finish Set Up',
                  style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
