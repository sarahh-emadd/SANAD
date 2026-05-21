import 'package:flutter/material.dart';

class AppSettingsProvider extends ChangeNotifier {
  // ── Text Size ──────────────────────────────────────
  String _textSize = 'Large Mode';
  String get textSize => _textSize;

  double get fontScaleFactor {
    switch (_textSize) {
      case 'Small':  return 0.85;
      case 'Medium': return 1.0;
      default:       return 1.15; // Large Mode
    }
  }

  void setTextSize(String size) {
    _textSize = size;
    notifyListeners();
  }

  // ── Volume ─────────────────────────────────────────
  double _volume = 1.0;
  double get volume => _volume;

  String get volumeLabel {
    if (_volume <= 0.25) return 'Low';
    if (_volume <= 0.65) return 'Medium';
    return 'High';
  }

  void setVolume(double value) {
    _volume = value;
    notifyListeners();
  }
}