import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/api_config.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import 'home_elder_page.dart'; // ✅ ADD THIS

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final MobileScannerController _cameraController = MobileScannerController();

  bool _isConnecting = false;
  bool _connected = false;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _connectWithToken(String token) async {
    if (_isConnecting || _connected) return;

    setState(() => _isConnecting = true);

    try {
      final res = await ApiService.post(
        ApiConfig.connectQR,
        {'token': token, 'deviceToken': 'simulator-device-token'},
        auth: false,
      );

      if (!mounted) return;

      await _onSuccess(res);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      if (!mounted) return;
      _showError('Connection failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _connectWithCode(String code, BuildContext dialogContext) async {
    if (_isConnecting) return;

    setState(() => _isConnecting = true);

    final navigator = Navigator.of(dialogContext);

    try {
      final res = await ApiService.post(
        ApiConfig.connectManual,
        {'manualCode': code, 'deviceToken': 'simulator-device-token'},
        auth: false,
      );

      navigator.pop();

      if (!mounted) return;

      await _onSuccess(res);
    } on ApiException catch (e) {
      navigator.pop();
      if (!mounted) return;
      _showError(e.message);
    } catch (e) {
      navigator.pop();
      if (!mounted) return;
      _showError('Connection failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  // ✅ FIXED FUNCTION
  Future<void> _onSuccess(Map<String, dynamic> res) async {
    if (!mounted) return;

    setState(() => _connected = true);

    // ✅ Stop camera (important)
    _cameraController.stop();

    final elderly = res['data']?['elderly'];
    final name = elderly?['first_name'] ?? 'Elder';
    final elderlyId = elderly?['id'];

    // Save elderly_id AND caregiver_id for SOS call
    if (elderlyId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('elderly_id', elderlyId);
      final caregiverId = elderly?['caregiver_id']?.toString();
      if (caregiverId != null && caregiverId.isNotEmpty) {
        await prefs.setString('caregiver_id', caregiverId);
      }
    }

    // ✅ Show success message (UNCHANGED UI)
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '✓ Connected! Welcome $name',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    // ✅ Navigate to HomeElderPage
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeElderPage()),
        (route) => false,
      );
    });
  }

  void _showError(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: AppTheme.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showEnterCodeDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Enter Caregiver Code',
            style: GoogleFonts.inter(
                color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: codeController,
          decoration: InputDecoration(
            hintText: '6-digit code',
            hintStyle: GoogleFonts.inter(color: AppTheme.hintGrey),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppTheme.primaryGreen, width: 1.8),
            ),
          ),
          keyboardType: TextInputType.number,
          maxLength: 6,
          autofocus: true,
          style: GoogleFonts.inter(
              fontSize: 20, letterSpacing: 4, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppTheme.hintGrey)),
          ),
          TextButton(
            onPressed: _isConnecting
                ? null
                : () => _connectWithCode(codeController.text.trim(), ctx),
            child: _isConnecting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryGreen))
                : Text('Connect',
                    style: GoogleFonts.inter(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.lightBackground,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: AppTheme.textDark),
          ),
        ),
        title: Text('Scan QR Code',
            style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryGreen)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Connect with\nCaregiver',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textDark,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Scan the QR code or enter the code manually',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                    fontSize: 13.5, color: AppTheme.textLight),
              ),
              const SizedBox(height: 36),

              // ✅ YOUR ORIGINAL SCANNER BOX (UNCHANGED)
              Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.primaryGreen, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withAlpha(30),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: MobileScanner(
                    controller: _cameraController,
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        if (barcode.rawValue != null) {
                          _connectWithToken(barcode.rawValue!);
                        }
                      }
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              if (_isConnecting) ...[
                const CircularProgressIndicator(color: AppTheme.primaryGreen),
                const SizedBox(height: 8),
                Text('Connecting...',
                    style: GoogleFonts.inter(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w500)),
              ] else
                Text('Point camera at the QR code',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppTheme.textLight)),

              const SizedBox(height: 40),

              Row(children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('OR',
                      style: GoogleFonts.inter(
                          color: AppTheme.hintGrey,
                          fontWeight: FontWeight.w600)),
                ),
                const Expanded(child: Divider()),
              ]),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showEnterCodeDialog,
                  icon: const Icon(Icons.keyboard_outlined),
                  label: Text('Enter Code Manually',
                      style: GoogleFonts.inter(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
