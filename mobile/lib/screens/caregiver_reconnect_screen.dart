import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class CaregiverReconnectScreen extends StatefulWidget {
  final String elderlyId;
  final String elderlyName;

  const CaregiverReconnectScreen({
    super.key,
    required this.elderlyId,
    required this.elderlyName,
  });

  @override
  State<CaregiverReconnectScreen> createState() =>
      _CaregiverReconnectScreenState();
}

class _CaregiverReconnectScreenState extends State<CaregiverReconnectScreen> {
  static const primary = Color(0xFF2FA884);
  static const textDark = Color(0xFF1A1A1A);
  static const textGrey = Color(0xFF888888);
  static const bgColor = Color(0xFFF5F7F6);

  bool _loading = false;
  String? _qrImageB64; // base64 PNG from server
  String? _manualCode;
  String? _errorMsg;
  DateTime? _expiresAt;

  @override
  void initState() {
    super.initState();
    _generateQR();
  }

  Future<String?> _getToken() async =>
      await FirebaseAuth.instance.currentUser?.getIdToken();

  Future<void> _generateQR() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final res = await http.post(
        Uri.parse(ApiConfig.regenerateQR(widget.elderlyId)),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body)['data'];
        // Server returns: qrCodeImage, manualCode, expiresAt
        setState(() {
          _qrImageB64 = (data['qrCodeImage'] ?? data['qr_image']) as String?;
          _manualCode = (data['manualCode'] ?? data['manual_code'])?.toString();
          final expiresRaw = data['expiresAt'] ?? data['expires_at'];
          _expiresAt = expiresRaw != null
              ? DateTime.parse(expiresRaw.toString())
              : DateTime.now().add(const Duration(minutes: 5));
        });
      } else {
        setState(() => _errorMsg = 'Failed (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  String get _expiryText {
    if (_expiresAt == null) return '';
    final remaining = _expiresAt!.difference(DateTime.now());
    if (remaining.isNegative) return 'Expired — tap Regenerate';
    if (remaining.inMinutes < 1) return 'Expires in <1 min';
    return 'Expires in ${remaining.inMinutes} min';
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          'Reconnect ${widget.elderlyName}',
          style: const TextStyle(
              fontFamily: 'Montserrat',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: textDark),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          // ── Info card ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5F0),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Share this QR code with ${widget.elderlyName} '
                  'so they can reconnect on their device.',
                  style: const TextStyle(
                      fontFamily: 'Montserrat', fontSize: 13, color: textDark),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 28),

          // ── QR image ──────────────────────────────────────
          if (_loading)
            const SizedBox(
              height: 220,
              child: Center(
                child: CircularProgressIndicator(color: primary),
              ),
            )
          else if (_errorMsg != null)
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.red, size: 40),
                      const SizedBox(height: 12),
                      Text(_errorMsg!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontFamily: 'Montserrat',
                              fontSize: 13,
                              color: Colors.red)),
                    ]),
              ),
            )
          else if (_qrImageB64 != null)
            Column(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(
                        _qrImageB64!.replaceAll('data:image/png;base64,', '')),
                    width: 220,
                    height: 220,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _expiryText,
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 12,
                    color: _expiresAt != null &&
                            _expiresAt!.difference(DateTime.now()).inMinutes < 2
                        ? Colors.orange
                        : textGrey),
              ),
            ]),

          const SizedBox(height: 28),

          // ── Manual code ───────────────────────────────────
          if (_manualCode != null) ...[
            const Text(
              'Or share the manual code:',
              style: TextStyle(
                  fontFamily: 'Montserrat', fontSize: 13, color: textGrey),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _manualCode!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code copied!')),
                );
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: primary.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _manualCode!,
                        style: const TextStyle(
                            fontFamily: 'Montserrat',
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: primary,
                            letterSpacing: 6),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.copy_rounded, color: primary, size: 20),
                    ]),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap to copy',
              style: TextStyle(
                  fontFamily: 'Montserrat', fontSize: 11, color: textGrey),
            ),
          ],

          const SizedBox(height: 32),

          // ── Regenerate button ─────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _generateQR,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Regenerate QR Code',
                style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}
