import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/location_model.dart';
import '../services/location_service.dart';

class ElderLocationScreen extends StatefulWidget {
  final String elderId;
  final String? elderName;
  const ElderLocationScreen({super.key, required this.elderId, this.elderName});
  @override
  State<ElderLocationScreen> createState() => _ElderLocationScreenState();
}

class _ElderLocationScreenState extends State<ElderLocationScreen> {
  static const bgColor    = Color(0xFFF5F7F6);
  static const textDark   = Color(0xFF1A1A1A);
  static const textGrey   = Color(0xFFAAAAAA);
  static const purpleC    = Color(0xFF8B5CF6);
  static const purpleBg   = Color(0xFFF3EEFF);
  static const lightGreen = Color(0xFFEEF7EE);
  static const okGreen    = Color(0xFF388E3C);
  static const dangerRed  = Color(0xFFE53935);
  static const lightRed   = Color(0xFFFFF0EE);

  static TextStyle m(double size, FontWeight weight, Color color) =>
      TextStyle(fontFamily: 'Montserrat', fontSize: size, fontWeight: weight, color: color);

  LocationModel? _location;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final loc = await LocationService.getElderLocation(widget.elderId);
      setState(() { _location = loc; _isLoading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _openInMaps(double lat, double lng) async {
    final name = Uri.encodeComponent(widget.elderName ?? 'Elder');
    final appleUrl  = Uri.parse('maps://?ll=$lat,$lng&q=$name');
    final googleUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(appleUrl)) {
      await launchUrl(appleUrl);
    } else {
      await launchUrl(googleUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Elder Location', style: m(17, FontWeight.w700, textDark)),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: purpleC), onPressed: _fetchLocation),
        ],
      ),
      body: _isLoading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildLoading() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: purpleC),
          const SizedBox(height: 16),
          Text('Fetching location...', style: m(14, FontWeight.w500, textGrey)),
        ]),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_off, color: dangerRed, size: 48),
            const SizedBox(height: 16),
            Text('Could not fetch location', style: m(15, FontWeight.w700, textDark)),
            const SizedBox(height: 8),
            Text(_error ?? '', style: m(12, FontWeight.w500, textGrey), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: purpleC, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: Text('Try Again', style: m(13, FontWeight.w700, Colors.white)),
            ),
          ]),
        ),
      );

  Widget _buildContent() {
    final loc = _location!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [

        // ── Header card ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: purpleBg, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.location_on, color: purpleC, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("${widget.elderName ?? 'Elder'}'s Location",
                  style: m(14, FontWeight.w700, textDark)),
              Text('Updated ${loc.lastSeenLabel}', style: m(11, FontWeight.w500, textGrey)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: loc.isHome ? lightGreen : lightRed,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(loc.isHome ? 'Home' : 'Away',
                  style: m(11, FontWeight.w700, loc.isHome ? okGreen : dangerRed)),
            ),
          ]),
        ),

        const SizedBox(height: 16),

        // ── OSM map tile with pin ─────────────────────────────────────
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(children: [
            _OsmMapTile(lat: loc.latitude, lng: loc.longitude),
            Positioned.fill(child: IgnorePointer(child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on, color: dangerRed, size: 44,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black38)]),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(widget.elderName ?? 'Elder', style: m(11, FontWeight.w700, textDark)),
                ),
              ]),
            ))),
          ]),
        ),

        const SizedBox(height: 16),

        // ── Coordinates + Open in Maps ────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.my_location, color: purpleC, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'Lat: ${loc.latitude.toStringAsFixed(5)},  Lng: ${loc.longitude.toStringAsFixed(5)}',
                style: m(12, FontWeight.w600, textDark),
              )),
            ]),
            if (loc.address.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.place_outlined, color: purpleC, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(loc.address, style: m(12, FontWeight.w500, textGrey))),
              ]),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openInMaps(loc.latitude, loc.longitude),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purpleC, foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text('Open in Maps', style: m(14, FontWeight.w700, Colors.white)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ── 3×3 OpenStreetMap tile grid centred on the coordinate ────────────────────
class _OsmMapTile extends StatelessWidget {
  final double lat;
  final double lng;
  const _OsmMapTile({required this.lat, required this.lng});

  static const _z = 15;

  int get _xTile => ((lng + 180.0) / 360.0 * (1 << _z)).floor();
  int get _yTile {
    final r = lat * math.pi / 180.0;
    return ((1.0 - math.log(math.tan(r) + 1.0 / math.cos(r)) / math.pi) / 2.0 * (1 << _z)).floor();
  }

  @override
  Widget build(BuildContext context) {
    final x = _xTile;
    final y = _yTile;
    return SizedBox(
      height: 220,
      child: GridView.count(
        crossAxisCount: 3,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (int dy = -1; dy <= 1; dy++)
            for (int dx = -1; dx <= 1; dx++)
              Image.network(
                'https://tile.openstreetmap.org/$_z/${x + dx}/${y + dy}.png',
                fit: BoxFit.cover,
                headers: const {'User-Agent': 'SanadApp/1.0'},
                errorBuilder: (_, __, ___) =>
                    Container(color: const Color(0xFFE8F4F0)),
              ),
        ],
      ),
    );
  }
}
