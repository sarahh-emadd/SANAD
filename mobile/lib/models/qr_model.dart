class QrModel {
  final String id;
  final String elderlyId;
  final String token;
  final String manualCode;
  final bool isActive;
  final DateTime expiresAt;
  final String? qrCodeImage; // base64 PNG from backend
  final DateTime? usedAt;
  final DateTime createdAt;

  QrModel({
    required this.id,
    required this.elderlyId,
    required this.token,
    required this.manualCode,
    required this.isActive,
    required this.expiresAt,
    this.qrCodeImage,
    this.usedAt,
    required this.createdAt,
  });

  bool get isValid => isActive && expiresAt.isAfter(DateTime.now());

  int get remainingMinutes =>
      expiresAt.difference(DateTime.now()).inMinutes.clamp(0, 999);

  factory QrModel.fromJson(Map<String, dynamic> json) {
    return QrModel(
      id:           json['id']?.toString() ?? '',
      elderlyId:    json['elderly_id']?.toString() ?? '',
      token:        json['token'] ?? '',
      manualCode:   json['manual_code'] ?? '',
      isActive:     json['is_active'] ?? false,
      expiresAt:    json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : DateTime.now(),
      qrCodeImage:  json['qrCodeImage'], // top-level field from backend
      usedAt:       json['used_at'] != null
          ? DateTime.tryParse(json['used_at'])
          : null,
      createdAt:    json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}
