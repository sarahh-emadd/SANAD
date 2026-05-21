// ════════════════════════════════════════════════════════════
//  PILL BOX ALERT HISTORY SCREEN (ELDER)
//  Shows medication alerts grouped by date
// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../models/medication_model.dart';
import '../../services/medication_service.dart';

class PillBoxAlertHistoryScreen extends StatefulWidget {
  const PillBoxAlertHistoryScreen({super.key});

  @override
  State<PillBoxAlertHistoryScreen> createState() =>
      _PillBoxAlertHistoryScreenState();
}

class _PillBoxAlertHistoryScreenState
    extends State<PillBoxAlertHistoryScreen> {
  // ── Colors ─────────────────────────────────────────
  static const primary    = Color(0xFF2FA884);
  static const dangerRed  = Color(0xFFE53935);
  static const lightRed   = Color(0xFFFFF0EE);
  static const okGreen    = Color(0xFF388E3C);
  static const lightGreen = Color(0xFFEEF7EE);
  static const warnBg     = Color(0xFFFFF8EE);
  static const warnOrange = Color(0xFFF57C00);
  static const bgColor    = Color(0xFFF5F7F6);
  static const textDark   = Color(0xFF1A1A1A);
  static const textGrey   = Color(0xFFAAAAAA);

  static TextStyle m(double size, FontWeight weight, Color color) =>
      TextStyle(
        fontFamily: 'Montserrat',
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  // ── State ───────────────────────────────────────────
  bool _loading = true;
  Map<String, List<MedicationAlert>> _groupedAlerts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final alerts = await MedicationService.getAlertHistory();
    if (!mounted) return;
    setState(() {
      _groupedAlerts = alerts;
      _loading = false;
    });
  }

  // ── Build ───────────────────────────────────────────
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
        title: Text('Pill Box Alert History',
            style: m(18, FontWeight.w700, textDark)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : _groupedAlerts.isEmpty
          ? _buildEmpty()
          : ListView(
        padding: const EdgeInsets.all(16),
        children: _groupedAlerts.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Date Header ──────────────────
              Padding(
                padding:
                const EdgeInsets.only(bottom: 10, top: 4),
                child: Text(entry.key,
                    style: m(14, FontWeight.w700, textDark)),
              ),
              // ── Alert rows ───────────────────
              ...entry.value.map(_buildAlertRow),
              const SizedBox(height: 12),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.notifications_none_outlined,
            color: textGrey, size: 48),
        const SizedBox(height: 12),
        Text('No alerts yet',
            style: m(15, FontWeight.w600, textGrey)),
      ],
    ),
  );

  Widget _buildAlertRow(MedicationAlert alert) {
    Color bc, bgC, ic;
    IconData icon;

    switch (alert.type) {
      case AlertType.danger:
        bc  = dangerRed;
        bgC = lightRed;
        ic  = dangerRed;
        icon = Icons.error_outline;
        break;
      case AlertType.warning:
        bc  = const Color(0xFFFFCC80);
        bgC = warnBg;
        ic  = warnOrange;
        icon = Icons.autorenew;
        break;
      case AlertType.success:
        bc  = const Color(0xFFA5D6A7);
        bgC = lightGreen;
        ic  = okGreen;
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgC,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: bc, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ic, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(alert.title,
                    style: m(13, FontWeight.w700, textDark)),
                const SizedBox(height: 2),
                Text(alert.subtitle,
                    style: m(11, FontWeight.w500, textGrey)),
                if (alert.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(alert.detail,
                      style: m(11, FontWeight.w500,
                          ic.withOpacity(0.85))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}