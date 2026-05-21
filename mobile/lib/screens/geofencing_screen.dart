import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class GeofencingScreen extends StatefulWidget {
  final String elderlyId;
  final String elderlyName;

  const GeofencingScreen({
    super.key,
    required this.elderlyId,
    required this.elderlyName,
  });

  @override
  State<GeofencingScreen> createState() => _GeofencingScreenState();
}

class _GeofencingScreenState extends State<GeofencingScreen> {
  // ── Colors ────────────────────────────────────────────────────────────────
  static const primary    = Color(0xFF2FA884);
  static const primaryBg  = Color(0xFFE6F4F0);
  static const dangerRed  = Color(0xFFE53935);
  static const bgColor    = Color(0xFFF5F7F6);
  static const textDark   = Color(0xFF1A1A1A);
  static const textGrey   = Color(0xFFAAAAAA);
  static const purpleC    = Color(0xFF8B5CF6);
  static const purpleBg   = Color(0xFFF3EEFF);

  static TextStyle m(double s, FontWeight w, Color c) =>
      TextStyle(fontFamily: 'Montserrat', fontSize: s, fontWeight: w, color: c);

  // ── State ─────────────────────────────────────────────────────────────────
  bool   _loading     = true;
  bool   _saving      = false;
  bool   _hasZone     = false;

  double _centerLat   = 0;
  double _centerLng   = 0;
  double _radiusM     = 300;   // default 300 m
  bool   _isActive    = false;

  // Elder's last known location — used as default center
  double? _elderLat;
  double? _elderLng;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ── API helpers ───────────────────────────────────────────────────────────
  Future<String?> _token() async =>
      FirebaseAuth.instance.currentUser?.getIdToken();

  Future<void> _loadData() async {
    setState(() => _loading = true);
    await Future.wait([_fetchSafeZone(), _fetchElderLocation()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchSafeZone() async {
    try {
      final token = await _token();
      final res = await http.get(
        Uri.parse(ApiConfig.safeZone(widget.elderlyId)),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.timeout);
      if (res.statusCode == 200) {
        final zone = jsonDecode(res.body)['data']['safe_zone'];
        if (zone != null) {
          _hasZone   = true;
          _centerLat = (zone['center_lat'] as num).toDouble();
          _centerLng = (zone['center_lng'] as num).toDouble();
          _radiusM   = (zone['radius_meters'] as num).toDouble();
          _isActive  = zone['is_active'] as bool;
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchElderLocation() async {
    try {
      final token = await _token();
      final res = await http.get(
        Uri.parse(ApiConfig.elderlyLocation(widget.elderlyId)),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.timeout);
      if (res.statusCode == 200) {
        final loc = jsonDecode(res.body)['data']['location'];
        _elderLat = (loc['latitude']  as num).toDouble();
        _elderLng = (loc['longitude'] as num).toDouble();
        // If no safe zone yet, default center to elder's current location
        if (!_hasZone && _elderLat != null) {
          _centerLat = _elderLat!;
          _centerLng = _elderLng!;
        }
      }
    } catch (_) {}
  }

  Future<void> _saveZone() async {
    setState(() => _saving = true);
    try {
      final token = await _token();
      final res = await http.post(
        Uri.parse(ApiConfig.safeZone(widget.elderlyId)),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'center_lat':    _centerLat,
          'center_lng':    _centerLng,
          'radius_meters': _radiusM.round(),
        }),
      ).timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        if (mounted) {
          setState(() { _hasZone = true; _isActive = true; });
          _showSnack('Safe zone saved! Elder will be monitored.', isError: false);
        }
      } else {
        _showSnack('Failed to save safe zone', isError: true);
      }
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeZone() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Remove Safe Zone?', style: m(17, FontWeight.w700, textDark)),
        content: Text(
          'Geofencing alerts will be disabled for ${widget.elderlyName}.',
          style: m(13, FontWeight.w500, textGrey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: m(13, FontWeight.w600, textGrey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: dangerRed, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text('Remove', style: m(13, FontWeight.w700, Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final token = await _token();
      await http.delete(
        Uri.parse(ApiConfig.safeZone(widget.elderlyId)),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(ApiConfig.timeout);
      if (mounted) {
        setState(() { _hasZone = false; _isActive = false; });
        _showSnack('Safe zone removed', isError: false);
      }
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  void _useElderLocation() {
    if (_elderLat == null) {
      _showSnack("Elder's location not yet reported", isError: true);
      return;
    }
    setState(() {
      _centerLat = _elderLat!;
      _centerLng = _elderLng!;
    });
    _showSnack("Center set to elder's current location", isError: false);
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: m(13, FontWeight.w600, Colors.white)),
      backgroundColor: isError ? dangerRed : primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: textDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Safe Zone', style: m(17, FontWeight.w700, textDark)),
        centerTitle: true,
        actions: [
          if (_hasZone && _isActive)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: dangerRed),
              tooltip: 'Remove safe zone',
              onPressed: _removeZone,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Status banner ─────────────────────────────────────────
                _statusBanner(),
                const SizedBox(height: 20),

                // ── How it works card ─────────────────────────────────────
                _infoCard(),
                const SizedBox(height: 20),

                // ── Zone center ───────────────────────────────────────────
                Text('Zone Center', style: m(14, FontWeight.w700, textDark)),
                const SizedBox(height: 10),
                _whiteCard(child: Column(children: [
                  _coordRow('Latitude',  _centerLat.toStringAsFixed(6)),
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
                  _coordRow('Longitude', _centerLng.toStringAsFixed(6)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _useElderLocation,
                      icon: const Icon(Icons.my_location_rounded, size: 18),
                      label: Text("Use elder's current location",
                          style: m(13, FontWeight.w600, primary)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        side: const BorderSide(color: primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ])),

                const SizedBox(height: 20),

                // ── Radius slider ─────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Safe Radius', style: m(14, FontWeight.w700, textDark)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _radiusM >= 1000
                          ? '${(_radiusM / 1000).toStringAsFixed(1)} km'
                          : '${_radiusM.round()} m',
                      style: m(13, FontWeight.w700, primary),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                _whiteCard(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: primary,
                        inactiveTrackColor: const Color(0xFFE0E0E0),
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
                        overlayColor: primary.withValues(alpha: 0.12),
                        trackHeight: 8,
                      ),
                      child: Slider(
                        value: _radiusM,
                        min: 100,
                        max: 2000,
                        divisions: 38,
                        onChanged: (v) => setState(() => _radiusM = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('100 m', style: m(11, FontWeight.w500, textGrey)),
                          Text('500 m', style: m(11, FontWeight.w500, textGrey)),
                          Text('1 km',  style: m(11, FontWeight.w500, textGrey)),
                          Text('2 km',  style: m(11, FontWeight.w500, textGrey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Visual guide for radius size
                    _radiusGuide(),
                  ],
                )),

                const SizedBox(height: 24),

                // ── Save button ───────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _saveZone,
                    icon: _saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.save_alt_rounded, size: 20),
                    label: Text(
                      _saving ? 'Saving…' : (_hasZone && _isActive ? 'Update Safe Zone' : 'Activate Safe Zone'),
                      style: m(15, FontWeight.w700, Colors.white),
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
                const SizedBox(height: 36),
              ]),
            ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _statusBanner() {
    if (!_hasZone || !_isActive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFCC80), width: 1.2),
        ),
        child: Row(children: [
          const Icon(Icons.location_off_outlined, color: Color(0xFFF57C00), size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('No Safe Zone Set', style: m(13, FontWeight.w700, textDark)),
            Text('Set a zone below to receive alerts when ${widget.elderlyName} leaves it.',
                style: m(12, FontWeight.w500, textGrey)),
          ])),
        ]),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: primaryBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: primary.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(children: [
        Container(
          width: 10, height: 10,
          decoration: const BoxDecoration(color: primary, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Safe Zone Active', style: m(13, FontWeight.w700, primary)),
          Text('Monitoring ${widget.elderlyName} — alert if they leave the zone.',
              style: m(12, FontWeight.w500, textGrey)),
        ])),
      ]),
    );
  }

  Widget _infoCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: purpleBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: purpleC.withValues(alpha: 0.3), width: 1.2),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.info_outline_rounded, color: purpleC, size: 18),
        const SizedBox(width: 8),
        Text('How It Works', style: m(13, FontWeight.w700, purpleC)),
      ]),
      const SizedBox(height: 8),
      ...[
        'Set a center point (e.g. home address) and a radius.',
        "Every time ${widget.elderlyName}'s location is reported, the server checks if they're inside the zone.",
        'If they leave, you get an instant push notification.',
        'A 5-minute cooldown prevents duplicate alerts.',
      ].map((t) => Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('• ', style: m(12, FontWeight.w600, purpleC)),
          Expanded(child: Text(t, style: m(12, FontWeight.w500, textDark))),
        ]),
      )),
    ]),
  );

  Widget _coordRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: m(13, FontWeight.w600, textDark)),
      Text(value,  style: m(13, FontWeight.w500, textGrey)),
    ]),
  );

  Widget _radiusGuide() {
    String desc;
    IconData icon;
    if (_radiusM <= 150) {
      desc = 'Very tight — inside a single building';
      icon = Icons.home_outlined;
    } else if (_radiusM <= 400) {
      desc = 'Home + immediate street';
      icon = Icons.location_city_outlined;
    } else if (_radiusM <= 800) {
      desc = 'Neighbourhood radius';
      icon = Icons.maps_home_work_outlined;
    } else {
      desc = 'Large area — city district';
      icon = Icons.map_outlined;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: primaryBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(children: [
        Icon(icon, color: primary, size: 18),
        const SizedBox(width: 10),
        Text(desc, style: m(12, FontWeight.w500, primary)),
      ]),
    );
  }

  Widget _whiteCard({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: child,
  );
}
