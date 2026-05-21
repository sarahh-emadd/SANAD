class LocationModel {
  final double latitude;
  final double longitude;
  final String address;
  final DateTime lastUpdated;
  final bool isHome;
  final int? batteryLevel;

  const LocationModel({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.lastUpdated,
    required this.isHome,
    this.batteryLevel,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      latitude:     (json['latitude']  as num).toDouble(),
      longitude:    (json['longitude'] as num).toDouble(),
      address:      json['address']     as String,
      lastUpdated:  DateTime.parse(json['last_updated'] as String),
      isHome:       json['is_home']     as bool,
      batteryLevel: json['battery_level'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'latitude':      latitude,
    'longitude':     longitude,
    'address':       address,
    'last_updated':  lastUpdated.toIso8601String(),
    'is_home':       isHome,
    'battery_level': batteryLevel,
  };

  /// Human-readable "X min ago" label
  String get lastSeenLabel {
    final diff = DateTime.now().difference(lastUpdated);
    if (diff.inSeconds < 60)  return 'just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes} min ago';
    if (diff.inHours < 24)    return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }
}