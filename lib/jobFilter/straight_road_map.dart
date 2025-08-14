import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:luckygo_pemandu/global.dart';

class StraightAndRoadDistanceMap extends StatefulWidget {
  const StraightAndRoadDistanceMap({super.key});

  @override
  State<StraightAndRoadDistanceMap> createState() => _StraightAndRoadDistanceMapState();
}

class _StraightAndRoadDistanceMapState extends State<StraightAndRoadDistanceMap> {
  GoogleMapController? _map;
  final _markers = <Marker>{};
  final _polylines = <Polyline>{};

  String? _roadText;         // e.g., "8.6 km • 17 min"
  String? _error;            // last error
  bool _loading = true;      // network loading
  bool _mapReady = false;    // onMapCreated fired?

  LatLng get _pickup => LatLng(Gv.sLat ?? 0, Gv.sLng ?? 0);
  LatLng get _drop   => LatLng(Gv.dLat ?? 0, Gv.dLng ?? 0);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Debug: dump inputs
    debugPrint('[MAP] init with: '
        'pickup=(${_pickup.latitude}, ${_pickup.longitude}), '
        'drop=(${_drop.latitude}, ${_drop.longitude})');
    debugPrint('[MAP] key present: ${Gv.googleApiKey.isNotEmpty}');

    // Validate coords early
    if (!_validLatLng(_pickup) || !_validLatLng(_drop)) {
      setState(() {
        _error = 'Invalid coordinates. pickup=$_pickup drop=$_drop';
        _loading = false;
      });
      debugPrint('[MAP][ERR] $_error');
      return;
    }

    // Build static overlays (markers + red straight line)
    _buildStaticOverlays();

    // Fetch road route (blue)
    await _loadRoadRoute(); // sets _roadText / _error
  }

  bool _validLatLng(LatLng p) {
    final ok = p.latitude.abs() > 0.000001 && p.longitude.abs() > 0.000001;
    return ok && p.latitude >= -90 && p.latitude <= 90 && p.longitude >= -180 && p.longitude <= 180;
  }

  void _buildStaticOverlays() {
    debugPrint('[MAP] building static overlays (markers + red straight)');
    _markers
      ..add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickup,
        infoWindow: InfoWindow(title: 'Pickup', snippet: '${Gv.sAdd1}, ${Gv.sAdd2}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ))
      ..add(Marker(
        markerId: const MarkerId('dest'),
        position: _drop,
        infoWindow: InfoWindow(title: 'Destination', snippet: '${Gv.dAdd1}, ${Gv.dAdd2}'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));

    _polylines.add(Polyline(
      polylineId: const PolylineId('straight'),
      points: [_pickup, _drop],
      width: 4,
      color: Colors.red,
      patterns: [PatternItem.dash(30), PatternItem.gap(12)], // no const here
    ));

    debugPrint('[MAP] markers=${_markers.length} polylines=${_polylines.length}');
  }

  Future<void> _loadRoadRoute() async {
    setState(() => _loading = true);
    try {
      final apiKey = Gv.googleApiKey;
      if (apiKey.isEmpty) {
        _error = 'Google API key is empty (Gv.googleApiKey).';
        debugPrint('[MAP][ERR] $_error');
        setState(() => _loading = false);
        return;
      }

      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${_pickup.latitude},${_pickup.longitude}'
        '&destination=${_drop.latitude},${_drop.longitude}'
        '&mode=driving&alternatives=false&units=metric&key=$apiKey',
      );
      debugPrint('[MAP] GET $url');
      final resp = await http.get(url);

      debugPrint('[MAP] directions http=${resp.statusCode}');
      if (resp.statusCode != 200) {
        _error = 'Directions failed: HTTP ${resp.statusCode}';
        setState(() => _loading = false);
        return;
      }

      final body = json.decode(resp.body);
      if (body['status'] != null && body['status'] != 'OK') {
        _error = 'Directions status: ${body['status']}';
        debugPrint('[MAP][ERR] $_error • msg=${body['error_message']}');
      }

      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) {
        _error = 'No route found.';
        setState(() => _loading = false);
        return;
      }

      final route = routes.first;
      final overview = route['overview_polyline']?['points'] as String?;
      final legs = (route['legs'] as List);
      int distMeters = 0, durSeconds = 0;
      for (final leg in legs) {
        distMeters += (leg['distance']?['value'] ?? 0) as int;
        durSeconds += (leg['duration']?['value'] ?? 0) as int;
      }

      if (overview != null) {
        final pts = _decodePolyline(overview);
        _polylines.add(Polyline(
          polylineId: const PolylineId('road'),
          points: pts,
          width: 5,
          color: Colors.blue,
        ));
        debugPrint('[MAP] road polyline points=${pts.length}');
      } else {
        debugPrint('[MAP] overview polyline is null');
      }

      _roadText = '${(distMeters / 1000).toStringAsFixed(1)} km • ${(durSeconds / 60).round()} min';
      debugPrint('[MAP] road summary: $_roadText');

      setState(() => _loading = false);

      // Try fit bounds after map ready
      if (_mapReady) {
        await Future.delayed(const Duration(milliseconds: 100));
        _fitBounds();
      }
    } catch (e) {
      _error = 'Directions error: $e';
      debugPrint('[MAP][EXC] $e');
      setState(() => _loading = false);
    }
  }

  void _fitBounds() {
    if (_map == null) return;
    final sw = LatLng(
      _pickup.latitude < _drop.latitude ? _pickup.latitude : _drop.latitude,
      _pickup.longitude < _drop.longitude ? _pickup.longitude : _drop.longitude,
    );
    final ne = LatLng(
      _pickup.latitude > _drop.latitude ? _pickup.latitude : _drop.latitude,
      _pickup.longitude > _drop.longitude ? _pickup.longitude : _drop.longitude,
    );
    debugPrint('[MAP] fit bounds: SW=$sw, NE=$ne');
    _map!.animateCamera(
      CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 70),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = _roadText == null ? 'Map' : 'Map – $_roadText';

    // If coords invalid, show an error-only screen (helps avoid white)
    if (!_validLatLng(_pickup) || !_validLatLng(_drop)) {
      return Scaffold(
        appBar: AppBar(title: Text(appBarTitle)),
        body: _debugPanel(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(appBarTitle)),
      body: Stack(
        children: [
          // Give a visible background so you can see if map layer isn't painting
          Container(color: Colors.amber.shade50),

          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                (_pickup.latitude + _drop.latitude) / 2,
                (_pickup.longitude + _drop.longitude) / 2,
              ),
              zoom: 12,
            ),
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (c) async {
              _map = c;
              _mapReady = true;
              debugPrint('[MAP] onMapCreated');
              await Future.delayed(const Duration(milliseconds: 200));
              _fitBounds();
              setState(() {}); // trigger rebuild to reflect _mapReady
            },
            myLocationButtonEnabled: false,
            myLocationEnabled: false,
            compassEnabled: true,
            zoomControlsEnabled: false,
            onCameraIdle: () => debugPrint('[MAP] camera idle'),
          ),

          if (_loading)
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            ),

          // Debug HUD overlay
          _debugPanel(),
        ],
      ),
    );
  }

  Widget _debugPanel() {
    return Align(
      alignment: Alignment.bottomLeft,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DEBUG'),
              Text('pickup: ${_pickup.latitude.toStringAsFixed(6)}, ${_pickup.longitude.toStringAsFixed(6)}'),
              Text('drop:   ${_drop.latitude.toStringAsFixed(6)}, ${_drop.longitude.toStringAsFixed(6)}'),
              Text('key present: ${Gv.googleApiKey.isNotEmpty}'),
              Text('markers: ${_markers.length}  polylines: ${_polylines.length}'),
              Text('mapReady: $_mapReady  loading: $_loading'),
              if (_roadText != null) Text('road: $_roadText'),
              if (_error != null) Text('error: $_error', style: const TextStyle(color: Colors.orangeAccent)),
            ],
          ),
        ),
      ),
    );
  }

  // Google encoded polyline -> LatLng list
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
