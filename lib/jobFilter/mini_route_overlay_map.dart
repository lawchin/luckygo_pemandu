import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MiniRouteOverlayMap extends StatefulWidget {
  const MiniRouteOverlayMap({
    super.key,
    required this.driver,
    required this.pickup,
    required this.dest, // kept for compatibility – not used here
    required this.googleApiKey,
    this.onTapFullScreen,
  });

  final LatLng driver;
  final LatLng pickup;
  final LatLng dest; // not used in this mini map
  final String googleApiKey;
  final VoidCallback? onTapFullScreen;

  @override
  State<MiniRouteOverlayMap> createState() => _MiniRouteOverlayMapState();
}

class _MiniRouteOverlayMapState extends State<MiniRouteOverlayMap> {
  GoogleMapController? _map;
  final _polylines = <Polyline>{};
  final _markers = <Marker>{};

  // custom marker icons
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _pickupIcon;

  // draggable offset (from top-left)
  Offset _offset = const Offset(12, 12);

  // initial camera: midpoint driver↔pickup
  CameraPosition get _initialCamera {
    final midLat = (widget.driver.latitude + widget.pickup.latitude) / 2;
    final midLng = (widget.driver.longitude + widget.pickup.longitude) / 2;
    return CameraPosition(target: LatLng(midLat, midLng), zoom: 12);
  }

  @override
  void initState() {
    super.initState();
    _loadCustomMarkers().then((_) {
      _buildStaticOverlays();
      setState(() {});
    });
    _fetchRoadPolyline(); // async; paints blue route when ready
  }

  Future<void> _loadCustomMarkers() async {
    try {
      _driverIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/car.png',
      );
      _pickupIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(30, 30)),
        'assets/images/ind_passenger.png',
      );
    } catch (e) {
      // fallback to default pins if asset missing
      _driverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
      _pickupIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  void _buildStaticOverlays() {
    final driver = widget.driver;
    final pickup = widget.pickup;

    _markers
      ..clear()
      ..addAll({
        Marker(
          markerId: const MarkerId('driver'),
          position: driver,
          icon: _driverIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Driver'),
        ),
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      });

    _polylines
      ..clear()
      // red straight line: driver -> pickup
      ..add(Polyline(
        polylineId: const PolylineId('straight_driver_pickup'),
        points: [driver, pickup],
        width: 4,
        color: Colors.red,
        geodesic: true,
        zIndex: 1,
      ));
  }

  Future<void> _fetchRoadPolyline() async {
    // road route: driver -> pickup
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${widget.driver.latitude},${widget.driver.longitude}'
        '&destination=${widget.pickup.latitude},${widget.pickup.longitude}'
        '&mode=driving&key=${widget.googleApiKey}',
      );
      final resp = await http.get(url);
      if (resp.statusCode != 200) return;

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = (json['routes'] as List?) ?? const [];
      if (routes.isEmpty) return;

      final poly = routes.first['overview_polyline']?['points'] as String?;
      if (poly == null || poly.isEmpty) return;

      final pts = _decodePolyline(poly);
      setState(() {
        _polylines.add(Polyline(
          polylineId: const PolylineId('road_driver_pickup'),
          points: pts,
          width: 6,
          color: Colors.blue, // road = blue
          geodesic: true,
          zIndex: 2,
        ));
      });

      await _fitAll(padding: 60);
    } catch (_) {
      // keep mini-map resilient
    }
  }

  List<LatLng> get _allPoints {
    final pts = <LatLng>[
      widget.driver,
      widget.pickup,
    ];
    // include all polyline points (straight + road)
    for (final pl in _polylines) {
      pts.addAll(pl.points);
    }
    // de-dupe
    final seen = <String>{};
    return pts.where((p) {
      final key = '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}';
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList(growable: false);
  }

  Future<void> _fitAll({double padding = 60}) async {
    if (_map == null) return;

    final pts = _allPoints;
    if (pts.isEmpty) return;

    double minLat = pts.first.latitude, maxLat = pts.first.latitude;
    double minLng = pts.first.longitude, maxLng = pts.first.longitude;

    for (final p in pts.skip(1)) {
      if (p.latitude  < minLat) minLat = p.latitude;
      if (p.latitude  > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    if ((maxLat - minLat).abs() < 1e-6) {
      minLat -= 0.0005; maxLat += 0.0005;
    }
    if ((maxLng - minLng).abs() < 1e-6) {
      minLng -= 0.0005; maxLng += 0.0005;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    await _map!.animateCamera(CameraUpdate.newLatLngBounds(bounds, padding));
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() => _offset += d.delta),
        onDoubleTap: () => _fitAll(),
        onTap: widget.onTapFullScreen,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 220,
            height: 160,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  blurRadius: 12,
                  color: Colors.black.withOpacity(0.2),
                )
              ],
            ),
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: _initialCamera,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  tiltGesturesEnabled: false,
                  rotateGesturesEnabled: false,
                  scrollGesturesEnabled: false,
                  zoomGesturesEnabled: false,
                  markers: _markers,
                  polylines: _polylines,
                  onMapCreated: (c) async {
                    _map = c;
                    await Future.delayed(const Duration(milliseconds: 200));
                    await _fitAll(padding: 40);
                  },
                ),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Row(
                    children: [
                      _roundBtn(
                        icon: Icons.center_focus_strong,
                        onTap: () => _fitAll(),
                      ),
                      const SizedBox(width: 6),
                      _roundBtn(
                        icon: Icons.open_in_full,
                        onTap: widget.onTapFullScreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _roundBtn({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              color: Colors.black.withOpacity(0.15),
            )
          ],
        ),
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 18),
      ),
    );
  }

  // Polyline decode (no extra package)
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, lat = 0, lng = 0;

    while (index < encoded.length) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
