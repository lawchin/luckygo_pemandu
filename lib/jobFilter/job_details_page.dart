import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/jobFilter/mini_route_overlay_map.dart';
import 'package:luckygo_pemandu/jobFilter/straight_road_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class JobDetailsPage extends StatefulWidget {
  const JobDetailsPage({super.key});

  @override
  State<JobDetailsPage> createState() => _JobDetailsPageState();
}

class _JobDetailsPageState extends State<JobDetailsPage> {
  // ───────── To-Pickup (Driver → Pickup) ─────────
  double? _toPickupAirKm;       // always computed locally
  double? _toPickupRoadKm;      // via Distance Matrix if air ≤ 7.5 km
  bool _toPickupLoading = false;
  String? _toPickupError;

  // ───────── Trip (Pickup → Destination) ─────────
  bool _tripLoading = false;
  double? _tripRoadKm;
  String? _tripEtaText;         // e.g. "44 min"
  String? _tripError;
  bool _tripUsedFallback = false;

  @override
  void initState() {
    super.initState();
    _kickoffCalculations();
  }

  void _kickoffCalculations() {
    // 1) Always compute driver→pickup AIR (free)
    _computeToPickupAir();

    // 2) If short (≤ 7.5 km) try to get driver→pickup ROAD (paid)
    _maybeFetchToPickupRoad();

    // 3) Trip (pickup→destination) ROAD + ETA (paid)
    _fetchTripViaDirections();
  }

  // ───────────────────── Driver → Pickup (AIR first, ROAD if ≤ 7.5) ─────────────────────

  void _computeToPickupAir() {
    final sLat = Gv.sLat, sLng = Gv.sLng;
    final dLat = Gv.driverLat, dLng = Gv.driverLng;
    if (sLat == null || sLng == null) return;
    if (!_validCoord(sLat, sLng) || !_validCoord(dLat, dLng)) return;

    final air = _haversineKm(dLat, dLng, sLat, sLng);
    setState(() {
      _toPickupAirKm = double.parse(air.toStringAsFixed(2));
    });
  }

  Future<void> _maybeFetchToPickupRoad() async {
    // Only attempt paid ROAD lookup if AIR ≤ 7.5 km and we have valid coords + key
    final air = _toPickupAirKm;
    final key = (Gv.googleApiKey).trim();
    final sLat = Gv.sLat, sLng = Gv.sLng;

    if (air == null) return;
    if (air > 7.5) return;
    if (key.isEmpty || sLat == null || sLng == null) return;

    final originLat = Gv.driverLat;
    final originLng = Gv.driverLng;
    if (!_validCoord(originLat, originLng) || !_validCoord(sLat, sLng)) return;

    setState(() {
      _toPickupLoading = true;
      _toPickupError = null;
    });

    try {
      // Distance Matrix: 1 origin (driver) → 1 destination (pickup)
      final origin = '${originLat.toStringAsFixed(6)},${originLng.toStringAsFixed(6)}';
      final dest = '${sLat.toStringAsFixed(6)},${sLng.toStringAsFixed(6)}';

      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/distancematrix/json'
        '?origins=$origin'
        '&destinations=$dest'
        '&mode=driving'
        '&departure_time=now'
        '&key=$key',
      );

      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        throw Exception('DistanceMatrix http=${resp.statusCode}');
      }
      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final top = map['status'] as String?;
      if (top != 'OK') {
        throw Exception('DistanceMatrix status=$top');
      }

      final rows = (map['rows'] as List?) ?? const [];
      if (rows.isEmpty) throw Exception('DistanceMatrix rows empty');
      final elements = (rows.first['elements'] as List?) ?? const [];
      if (elements.isEmpty) throw Exception('DistanceMatrix elements empty');

      final e = elements.first as Map<String, dynamic>?;
      if (e?['status'] != 'OK') {
        throw Exception('DistanceMatrix elem status=${e?['status']}');
      }

      final distMeters = (e?['distance']?['value'] as num?)?.toDouble();
      if (distMeters == null) throw Exception('DistanceMatrix no distance');

      final km = distMeters / 1000.0;
      setState(() {
        _toPickupRoadKm = double.parse(km.toStringAsFixed(2));
        _toPickupLoading = false;
      });
    } catch (e) {
      setState(() {
        _toPickupError = '$e';
        _toPickupLoading = false;
      });
      // We keep showing AIR (free) if ROAD fails.
    }
  }

  // ───────────────────── Pickup → Destination (Directions) ─────────────────────

  Future<void> _fetchTripViaDirections() async {
    final key = (Gv.googleApiKey).trim();
    final sLat = Gv.sLat, sLng = Gv.sLng, dLat = Gv.dLat, dLng = Gv.dLng;

    if (key.isEmpty || sLat == null || sLng == null || dLat == null || dLng == null) {
      _applyTripFallbackFromQuotedDistance();
      return;
    }

    setState(() {
      _tripLoading = true;
      _tripError = null;
      _tripUsedFallback = false;
    });

    try {
      final uri = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${sLat.toStringAsFixed(6)},${sLng.toStringAsFixed(6)}'
        '&destination=${dLat.toStringAsFixed(6)},${dLng.toStringAsFixed(6)}'
        '&mode=driving&departure_time=now'
        '&key=$key',
      );

      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        throw Exception('Directions http=${resp.statusCode}');
      }

      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      if ((map['status'] as String?) != 'OK') {
        throw Exception('Directions status=${map['status']}');
      }

      final routes = (map['routes'] as List?) ?? const [];
      if (routes.isEmpty) throw Exception('Directions routes empty');
      final legs = (routes.first['legs'] as List?) ?? const [];
      if (legs.isEmpty) throw Exception('Directions legs empty');

      final leg = legs.first as Map<String, dynamic>;

      // Distance in meters → km
      final distMeters = (leg['distance']?['value'] as num?)?.toDouble();
      final km = distMeters != null ? (distMeters / 1000.0) : null;

      // Duration_in_traffic preferred, else duration
      final durTraffic = leg['duration_in_traffic']?['text'] as String?;
      final dur = leg['duration']?['text'] as String?;

      setState(() {
        _tripRoadKm = km != null ? double.parse(km.toStringAsFixed(1)) : null;
        _tripEtaText = durTraffic ?? dur; // like "44 min" or "1 hr 10 min"
        _tripLoading = false;
      });

      if (_tripEtaText == null) _applyTripFallbackFromRoadKm();
    } catch (e) {
      setState(() {
        _tripError = '$e';
        _tripLoading = false;
      });
      _applyTripFallbackFromQuotedDistance();
    }
  }

  void _applyTripFallbackFromRoadKm() {
    if (_tripRoadKm == null) {
      _applyTripFallbackFromQuotedDistance();
      return;
    }
    final mins = _estimateEtaMinutes(_tripRoadKm!);
    setState(() {
      _tripEtaText = _formatMins(mins);
      _tripUsedFallback = true;
    });
  }

  void _applyTripFallbackFromQuotedDistance() {
    final qKm = (Gv.totalKm.isFinite && Gv.totalKm > 0) ? Gv.totalKm : null;
    if (qKm == null) return;
    setState(() {
      _tripRoadKm = double.parse(qKm.toStringAsFixed(1));
      _tripEtaText = _formatMins(_estimateEtaMinutes(qKm));
      _tripUsedFallback = true;
    });
  }

  // ───────────────────── Helpers ─────────────────────

  bool _validCoord(double lat, double lng) {
    if (lat == 0.0 && lng == 0.0) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0088;
    double _rad(double d) => d * math.pi / 180.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  int _estimateEtaMinutes(double km) {
    final speed = km <= 5
        ? 22.0
        : km <= 10
            ? 28.0
            : km <= 30
                ? 40.0
                : km <= 100
                    ? 70.0
                    : 85.0;
    final hours = km / speed;
    final mins = (hours * 60).clamp(1, 24 * 60);
    return mins.round();
  }

  String _formatMins(int mins) {
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '$h hr' : '$h hr $m min';
  }

  Future<void> _openExternalGoogleMaps() async {
    final sLat = Gv.sLat, sLng = Gv.sLng, dLat = Gv.dLat, dLng = Gv.dLng;
    if (sLat == null || sLng == null || dLat == null || dLng == null) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${sLat.toStringAsFixed(6)},${sLng.toStringAsFixed(6)}'
      '&destination=${dLat.toStringAsFixed(6)},${dLng.toStringAsFixed(6)}'
      '&travelmode=driving'
    );

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    }
  }

  // ───────────────────── UI ─────────────────────

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final chips = <String, int>{
      'Wheelchair': Gv.wheelchairCount,
      'Stick': Gv.supportStickCount,
      'Stroller': Gv.babyStrollerCount,
      'Bags': Gv.shoppingBagCount,
      'Luggage': Gv.luggageCount,
      'Pets': Gv.petsCount,
      'Dog': Gv.dogCount,
      'Goat': Gv.goatCount,
      'Rooster': Gv.roosterCount,
      'Snake': Gv.snakeCount,
      'Durian': Gv.durianCount,
      'Odour fruit': Gv.odourFruitsCount,
      'Wet food': Gv.wetFoodCount,
      'Tupperware': Gv.tupperwareCount,
      'Gas tank': Gv.gasTankCount,
    }..removeWhere((_, v) => v <= 0);

    // Decide what to show for "Driver → Pickup"
    final showRoadPickup = _toPickupRoadKm != null; // only when we succeeded
    final pickupLine = showRoadPickup
        ? 'Driver → Pickup: ${_toPickupRoadKm!.toStringAsFixed(2)} km (road)'
        : (_toPickupAirKm != null
            ? 'Driver → Pickup: ${_toPickupAirKm!.toStringAsFixed(2)} km (air)'
            : 'Driver → Pickup: —');

    return Scaffold(
      appBar: AppBar(title: const Text('Job Details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/images/ind_passenger.png', width: 48, height: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Gv.passengerName.isNotEmpty ? Gv.passengerName : Gv.passengerPhone,
                      style: t.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text('Pax: ${Gv.passengerCount} • Markers: ${Gv.markerCount}', style: t.bodyMedium),
                  ],
                ),
              ),
              Text('RM ${Gv.totalPrice.toStringAsFixed(2)}', style: t.titleLarge),
            ],
          ),

          const SizedBox(height: 12),
          Text('Job ID', style: t.labelMedium),
          SelectableText(Gv.liteJobId, style: t.bodyMedium),

          const SizedBox(height: 16),
          const Divider(),

          // Pickup
          Text('Pickup', style: t.titleMedium),
          const SizedBox(height: 6),
          _addrRow('assets/images/ind_passenger.png', Gv.sAdd1, Gv.sAdd2, context),
          const SizedBox(height: 6),
          _coordRow('Lat/Lng', Gv.sLat, Gv.sLng, context),

          const SizedBox(height: 12),

          // Destination
          Text('Destination', style: t.titleMedium),
          const SizedBox(height: 6),
          _addrRow('assets/images/finish.png', Gv.dAdd1, Gv.dAdd2, context),
          const SizedBox(height: 6),
          _coordRow('Lat/Lng', Gv.dLat, Gv.dLng, context),

          const SizedBox(height: 16),
          const Divider(),

          // ───── Driver → Pickup ─────
          Row(
            children: [
              const Icon(Icons.social_distance, size: 20),
              const SizedBox(width: 6),
              Text(pickupLine, style: t.bodyMedium),
              if (_toPickupLoading) ...[
                const SizedBox(width: 8),
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
          if (_toPickupError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Pickup road lookup failed – showing air. (${"$_toPickupError"})',
                  style: t.bodySmall?.copyWith(color: Colors.red)),
            ),

          const SizedBox(height: 10),

          // ───── Trip (Pickup → Destination) ─────
          Row(
            children: [
              const Icon(Icons.route, size: 20, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Expanded(
                child: _tripLoading
                    ? Row(children: const [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Fetching trip ETA…'),
                      ])
                    : Text(
                        [
                          if (_tripRoadKm != null) 'Trip: ${_tripRoadKm!.toStringAsFixed(1)} km (road)',
                          if (_tripEtaText != null)
                            _tripUsedFallback ? 'ETA (est): $_tripEtaText' : 'ETA: $_tripEtaText',
                          if (_tripRoadKm == null && _tripEtaText == null) 'ETA unavailable',
                        ].join(' • '),
                        style: t.bodyMedium,
                      ),
              ),
            ],
          ),
          if (_tripError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Hint: enable Directions API & billing. (${"$_tripError"})',
                  style: t.bodySmall?.copyWith(color: Colors.red)),
            ),

          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StraightAndRoadDistanceMap()));
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open Map (straight + road)'),
          ),

          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _openExternalGoogleMaps,
            icon: const Icon(Icons.navigation_outlined),
            label: const Text('Open in Google Maps (free)'),
          ),

          const SizedBox(height: 16),
          const Divider(),

          // Accessibility
          Text('Accessibility', style: t.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (Gv.isBlind == true) _chipIcon('Blind', 'assets/images/blind_symbol.png', context),
              if (Gv.isDeaf == true)  _chipIcon('Deaf', 'assets/images/deaf_symbol.png', context),
              if (Gv.isMute == true)  _chipIcon('Mute', 'assets/images/mute_symbol.png', context),
              if (chips.isEmpty) Text('No special items/needs', style: t.bodyMedium),
            ],
          ),

          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Items', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips.entries.map((e) => _qtyChip(e.key, e.value, context)).toList(),
            ),
          ],

          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Action tapped (wire this to your flow)')),
              );
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Proceed'),
          ),

          const SizedBox(height: 16),

          if (Gv.sLat != null && Gv.sLng != null && Gv.dLat != null && Gv.dLng != null)
            MiniRouteOverlayMap(
              driver: LatLng(Gv.driverLat, Gv.driverLng),
              pickup: LatLng(Gv.sLat!, Gv.sLng!),
              dest:   LatLng(Gv.dLat!, Gv.dLng!),
              googleApiKey: Gv.googleApiKey,
              onTapFullScreen: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const StraightAndRoadDistanceMap()));
              },
            ),
        ],
      ),
    );
  }

  // ---------- small UI helpers ----------
  Widget _addrRow(String icon, String? l1, String? l2, BuildContext ctx) {
    final t = Theme.of(ctx).textTheme;
    final line1 = (l1 ?? '').isEmpty ? '-' : l1!;
    final line2 = (l2 ?? '').isEmpty ? '' : l2!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(icon, width: 28, height: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line1, style: t.bodyMedium),
              if (line2.isNotEmpty) Text(line2, style: t.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coordRow(String label, double? lat, double? lng, BuildContext ctx) {
    final t = Theme.of(ctx).textTheme;
    final latStr = (lat ?? 0).toStringAsFixed(6);
    final lngStr = (lng ?? 0).toStringAsFixed(6);
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
        const SizedBox(width: 6),
        Text('$label: $latStr, $lngStr', style: t.bodySmall),
      ],
    );
  }

  Widget _chipIcon(String label, String asset, BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(asset, width: 18, height: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _qtyChip(String label, int qty, BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconFor(label) != null
              ? Image.asset(_iconFor(label)!, width: 18, height: 18)
              : const SizedBox(width: 0, height: 0),
          if (_iconFor(label) != null) const SizedBox(width: 6),
          Text('$label x$qty'),
        ],
      ),
    );
  }

  String? _iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('wheelchair')) return 'assets/images/ind_wheelchair.png';
    if (l.contains('blind')) return 'assets/images/blind_symbol.png';
    if (l.contains('deaf')) return 'assets/images/deaf_symbol.png';
    if (l.contains('mute')) return 'assets/images/mute_symbol.png';
    if (l.contains('stick')) return 'assets/images/ind_supportstick.png';
    if (l.contains('stroller')) return 'assets/images/ind_stroller.png';
    if (l.contains('bag')) return 'assets/images/ind_shopping1.png';
    if (l.contains('luggage')) return 'assets/images/ind_luggage1.png';
    if (l.contains('tupperware')) return 'assets/images/ind_tupperware.png';
    if (l.contains('gas')) return 'assets/images/ind_gastank.png';
    if (l.contains('wet food')) return 'assets/images/ind_wetfood.png';
    if (l.contains('odour')) return 'assets/images/ind_odourfruits.png';
    if (l.contains('durian')) return 'assets/images/ind_durian.png';
    if (l.contains('pets')) return 'assets/images/ind_pets.png';
    if (l.contains('dog')) return 'assets/images/ind_dog.png';
    if (l.contains('goat')) return 'assets/images/ind_goat.png';
    if (l.contains('rooster')) return 'assets/images/ind_rooster.png';
    if (l.contains('snake')) return 'assets/images/ind_snake.png';
    return null;
  }
}
