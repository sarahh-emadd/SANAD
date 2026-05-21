// ════════════════════════════════════════════════════════════
//  MEDICATION HISTORY SCREEN (ELDER)
//  Shows slot-by-slot medication history grouped by date
// ════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../models/medication_model.dart';
import '../../services/medication_service.dart';

class MedicationHistoryScreen extends StatefulWidget {
  const MedicationHistoryScreen({super.key});

  @override
  State<MedicationHistoryScreen> createState() =>
      _MedicationHistoryScreenState();
}

class _MedicationHistoryScreenState extends State<MedicationHistoryScreen> {
  // ── Colors ─────────────────────────────────────────
  static const primary    = Color(0xFF2FA884);
  static const primaryBg  = Color(0xFFE6F4F0);
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

  static TextStyle m(double size, FontWeight weight, Color color) =>
      TextStyle(
        fontFamily: 'Montserrat',
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  // ── State ───────────────────────────────────────────
  bool _loading = true;
  Map<String, List<MedicationSlot>> _groupedHistory = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final history = await MedicationService.getSlotHistory();
    if (!mounted) return;
    setState(() {
      _groupedHistory = history;
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
        title: Text('Medication History',
            style: m(18, FontWeight.w700, textDark)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : _groupedHistory.isEmpty
          ? _buildEmpty()
          : ListView(
        padding: const EdgeInsets.all(16),
        children: _groupedHistory.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Date Header ──────────────────
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 4),
                child: Text(entry.key,
                    style: m(14, FontWeight.w700, textDark)),
              ),
              // ── Slots ────────────────────────
              ...entry.value.map(_buildSlotCard),
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
        Icon(Icons.medication_outlined, color: textGrey, size: 48),
        const SizedBox(height: 12),
        Text('No history yet',
            style: m(15, FontWeight.w600, textGrey)),
      ],
    ),
  );

  Widget _buildSlotCard(MedicationSlot slot) {
    Color bg, tc, icC;
    IconData ic;

    switch (slot.status) {
      case SlotStatus.taken:
        bg = lightGreen;
        tc = okGreen;
        ic = Icons.check_circle;
        icC = okGreen;
        break;
      case SlotStatus.missed:
        bg = lightRed;
        tc = dangerRed;
        ic = Icons.cancel_outlined;
        icC = dangerRed;
        break;
      case SlotStatus.dueSoon:
        bg = infoBlueBg;
        tc = infoBlue;
        ic = Icons.radio_button_checked;
        icC = infoBlue;
        break;
      case SlotStatus.scheduled:
        bg = const Color(0xFFF5F5F5);
        tc = textGrey;
        ic = Icons.radio_button_unchecked;
        icC = textGrey;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: icC.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(ic, color: icC, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(slot.label, style: m(13, FontWeight.w700, textDark)),
                const SizedBox(height: 3),
                Text(
                  '${slot.time}  ·  ${slot.statusLabel}',
                  style: m(12, FontWeight.w500, tc),
                ),
                if (slot.medications.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    slot.medications.join(', '),
                    style: m(11, FontWeight.w500, textGrey),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}