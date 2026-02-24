import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ElderConnectQRScreen extends StatefulWidget {
  final Map<String, dynamic> elderData;

  const ElderConnectQRScreen({super.key, required this.elderData});

  @override
  State<ElderConnectQRScreen> createState() => _ElderConnectQRScreenState();
}

class _ElderConnectQRScreenState extends State<ElderConnectQRScreen> {
  late final String _pairingCode;

  @override
  void initState() {
    super.initState();
    _pairingCode = _generateCode();
  }

  String _generateCode() {
    final rand = Random();
    return (10000 + rand.nextInt(90000)).toString();
  }

  String get _elderFirstName =>
      widget.elderData['firstName']?.toString() ?? 'Elder';

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: _pairingCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pairing code copied!',
            style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _finishSetUp() {
    // TODO: Navigate to main dashboard
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Profile for $_elderFirstName created successfully! 🎉',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Pop back to root / login for now
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

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
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  size: 18, color: AppTheme.textDark),
            ),
          ),
        ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Hero Image ──
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 200,
                height: 160,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/qr_elder.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.people_alt_outlined,
                      size: 80,
                      color: AppTheme.primaryGreen.withAlpha(120),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Title ──
            Text(
              'Connect Elder',
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share this code with $_elderFirstName',
              style: GoogleFonts.inter(
                fontSize: 14.5,
                color: AppTheme.textLight,
              ),
            ),
            const SizedBox(height: 28),

            // ── QR Code ──
            Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(18),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: _QRPatternPainter(code: _pairingCode),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Divider(color: AppTheme.borderColor.withAlpha(180)),
            ),

            const SizedBox(height: 12),

            Text(
              'Scan QR Code',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 12),

            // ── Pairing Code ──
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
                    Text(
                      'Pairing Code : ',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      _pairingCode,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryGreen,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.copy_rounded,
                        size: 18, color: AppTheme.primaryGreen),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Show this QR to Elder or Enter this\nCode Manually',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13.5,
                color: AppTheme.textLight,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 36),

            // ── Finish Button ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OutlinedButton(
                onPressed: _finishSetUp,
                style: OutlinedButton.styleFrom(
                  side:
                  const BorderSide(color: AppTheme.primaryGreen, width: 1.8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50)),
                  minimumSize: const Size(double.infinity, 54),
                ),
                child: Text(
                  'Finish Set Up',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

/// A custom painter that draws a QR-like pattern to visually represent the code.
class _QRPatternPainter extends CustomPainter {
  final String code;

  const _QRPatternPainter({required this.code});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final bgPaint = Paint()..color = Colors.white;

    canvas.drawRect(Offset.zero & size, bgPaint);

    const modules = 21;
    final cellSize = size.width / modules;

    final rand = Random(code.hashCode);

    // Reserved corner positions (finder patterns)
    final reserved = <String>{};
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        reserved.add('$r,$c');
      }
    }
    for (int r = 0; r < 9; r++) {
      for (int c = modules - 8; c < modules; c++) {
        reserved.add('$r,$c');
      }
    }
    for (int r = modules - 8; r < modules; r++) {
      for (int c = 0; c < 9; c++) {
        reserved.add('$r,$c');
      }
    }

    // Data modules
    for (int row = 0; row < modules; row++) {
      for (int col = 0; col < modules; col++) {
        if (reserved.contains('$row,$col')) continue;
        if (rand.nextBool()) {
          final rect = Rect.fromLTWH(
            col * cellSize + 1,
            row * cellSize + 1,
            cellSize - 2,
            cellSize - 2,
          );
          canvas.drawRect(rect, paint);
        }
      }
    }

    // Draw finder patterns (top-left, top-right, bottom-left)
    _drawFinder(canvas, paint, bgPaint, 0, 0, cellSize);
    _drawFinder(canvas, paint, bgPaint, modules - 7, 0, cellSize);
    _drawFinder(canvas, paint, bgPaint, 0, modules - 7, cellSize);
  }

  void _drawFinder(Canvas canvas, Paint dark, Paint light, int col, int row,
      double cell) {
    // Outer 7x7 dark
    canvas.drawRect(
      Rect.fromLTWH(col * cell, row * cell, 7 * cell, 7 * cell),
      dark,
    );
    // Inner 5x5 light
    canvas.drawRect(
      Rect.fromLTWH(
          (col + 1) * cell, (row + 1) * cell, 5 * cell, 5 * cell),
      light,
    );
    // Center 3x3 dark
    canvas.drawRect(
      Rect.fromLTWH(
          (col + 2) * cell, (row + 2) * cell, 3 * cell, 3 * cell),
      dark,
    );
  }

  @override
  bool shouldRepaint(covariant _QRPatternPainter oldDelegate) =>
      oldDelegate.code != code;
}