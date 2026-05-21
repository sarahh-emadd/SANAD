import 'package:flutter/material.dart';

// ── Enums ──────────────────────────────────────────────
enum HistoryType { info, warning, danger }

// ── Models ─────────────────────────────────────────────
class ActivityItem {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String time;

  const ActivityItem({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.time,
  });
}

class HistoryItem {
  final String title;
  final String location;
  final String time;
  final HistoryType type;
  final bool resolved;
  final String? note;

  const HistoryItem({
    required this.title,
    required this.location,
    required this.time,
    required this.type,
    required this.resolved,
    this.note,
  });
}