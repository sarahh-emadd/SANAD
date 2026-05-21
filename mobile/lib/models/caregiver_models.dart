import 'package:flutter/material.dart';

// ── Enums ──────────────────────────────────────────────
enum SlotStatus { taken, dueSoon, scheduled }
enum NotifType  { danger, warning, success }

// ── Models ─────────────────────────────────────────────
class SlotData {
  final String label;
  final String time;
  final String statusLabel;
  final SlotStatus status;

  SlotData(this.label, this.time, this.statusLabel, this.status);
}

class NotifData {
  final IconData icon;
  final String title;
  final String subtitle;
  final NotifType type;

  NotifData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.type,
  });
}