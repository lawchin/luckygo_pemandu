// lib/geofencing_bootstrap_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:math' show sin, cos, sqrt, atan2, pi;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/geo_fencing/zone_preview.dart';
import 'package:luckygo_pemandu/geo_fencing/blocked_overlay.dart'; // external overlay
import 'package:luckygo_pemandu/global.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

import 'package:luckygo_pemandu/geo_fencing/geofencing_controller.dart';

const _TAG = '[GeoFence]';

/// ===== Model =====

class CameraSpec {
  final double? lat;
  final double? lng;
  final double? zoom;
  final double? bearing;
  final double? tilt;
  const CameraSpec({this.lat, this.lng, this.zoom, this.bearing, this.tilt});

  factory CameraSpec.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const CameraSpec();
    double? _d(dynamic v) => (v is num) ? v.toDouble() : double.tryParse('$v');
    return CameraSpec(
      lat: _d(m['lat']),
      lng: _d(m['lng']),
      zoom: _d(m['zoom']),
      bearing: _d(m['bearing']),
      tilt: _d(m['tilt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'lat': lat,
        'lng': lng,
        'zoom': zoom,
        'bearing': bearing,
        'tilt': tilt,
      }..removeWhere((k, v) => v == null);
}

class GeoFence {
  final bool active;
  final Rect bbox; // L=minLng, T=minLat, R=maxLng, B=maxLat
  final List<List<double>> outer; // [[lat,lng], ...]
  final List<List<List<double>>> holes; // [ring: [[lat,lng], ...], ...]
  final int updatedAt; // ms since epoch (from `updated_at`)
  final String hash; // optional (may be empty)
  final String? name; // optional
  final String? mode; // optional (e.g., 'outer_only')
  final CameraSpec camera; // optional

  GeoFence({
    required this.active,
    required this.bbox,
    required this.outer,
    required this.holes,
    required this.updatedAt,
    required this.hash,
    required this.name,
    required this.mode,
    required this.camera,
  });

  /// Robust point parser for new schema
  static List<List<double>> _parseLatLngList(dynamic v) {
    final out = <List<double>>[];
    if (v is! List) return out;
    for (final e in v) {
      if (e is List && e.length >= 2) {
        out.add([(e[0] as num).toDouble(), (e[1] as num).toDouble()]);
      } else if (e is Map) {
        if (e.containsKey('lat') && e.containsKey('lng')) {
          out.add([(e['lat'] as num).toDouble(), (e['lng'] as num).toDouble()]);
        } else if (e.containsKey('latitude') && e.containsKey('longitude')) {
          out.add([(e['latitude'] as num).toDouble(), (e['longitude'] as num).toDouble()]);
        }
      } else if (e is GeoPoint) {
        out.add([e.latitude, e.longitude]);
      }
    }
    return out;
  }

  /// hole_points can be [], [{lat,lng}...], or [ [{lat,lng}...], ... ]
  static List<List<List<double>>> _parseHolesNew(dynamic v) {
    final rings = <List<List<double>>>[];
    if (v is! List || v.isEmpty) return rings;
    final first = v.first;
    if (first is Map && (first.containsKey('lat') || first.containsKey('latitude'))) {
      rings.add(_parseLatLngList(v));
      return rings;
    }
    if (first is Map && first['ring'] != null) {
      for (final h in v) {
        if (h is Map && h['ring'] != null) {
          rings.add(_parseLatLngList(h['ring']));
        }
      }
      return rings;
    }
    for (final h in v) {
      rings.add(_parseLatLngList(h));
    }
    return rings;
  }

  static Rect _computeBboxFromOuter(List<List<double>> outer) {
    if (outer.isEmpty) return const Rect.fromLTRB(0, 0, 0, 0);
    double minLat = outer.first[0], maxLat = outer.first[0];
    double minLng = outer.first[1], maxLng = outer.first[1];
    for (final p in outer) {
      final lat = p[0], lng = p[1];
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }
    return Rect.fromLTRB(minLng, minLat, maxLng, maxLat);
  }

  /// Parse **new** Firestore structure only.
  factory GeoFence.fromMap(Map<String, dynamic> m) {
    final outer = _parseLatLngList(m['outer_points']);
    final holes = _parseHolesNew(m['hole_points']);

    int updatedAt = 0;
    final ua = m['updated_at'];
    if (ua is Timestamp) {
      updatedAt = ua.millisecondsSinceEpoch;
    } else if (ua != null) {
      updatedAt = DateTime.tryParse(ua.toString())?.millisecondsSinceEpoch ?? 0;
    }

    final computedBbox = _computeBboxFromOuter(outer);

    return GeoFence(
      active: m['active'] == true,
      bbox: computedBbox,
      outer: outer,
      holes: holes,
      updatedAt: updatedAt,
      hash: (m['hash']?.toString()) ?? '',
      name: (m['name'] as String?)?.trim(),
      mode: (m['mode'] as String?)?.trim(),
      camera: CameraSpec.fromMap(m['camera'] as Map<String, dynamic>?),
    );
  }

  /// Cache representation (local only).
  Map<String, dynamic> toMap() => {
        'active': active,
        'bbox': {
          'minLat': bbox.top,
          'minLng': bbox.left,
          'maxLat': bbox.bottom,
          'maxLng': bbox.right,
        },
        'outer': outer,
        'holes': holes,
        'updatedAt': updatedAt,
        'hash': hash,
        'name': name,
        'mode': mode,
        'camera': camera.toMap(),
      }..removeWhere((k, v) => v == null);
}

/// ===== Geometry =====
bool _inBbox(GeoFence f, double lat, double lng) {
  return lng >= f.bbox.left && lng <= f.bbox.right && lat >= f.bbox.top && lat <= f.bbox.bottom;
}

bool _pointInPolygon(List<List<double>> poly, double lat, double lng) {
  if (poly.isEmpty) return false;
  bool inside = false;
  for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final yi = poly[i][0], xi = poly[i][1];
    final yj = poly[j][0], xj = poly[j][1];
    final denom = ((yj - yi).abs() < 1e-12) ? 1e-12 : (yj - yi);
    final cond = ((yi > lat) != (yj > lat)) &&
        (lng < (xj - xi) * (lat - yi) / denom + xi);
    if (cond) inside = !inside;
  }
  return inside;
}

bool isBlockedBy(GeoFence f, double lat, double lng) {
  if (!f.active) return false;
  if (!_inBbox(f, lat, lng)) return false;
  final inOuter = _pointInPolygon(f.outer, lat, lng);
  if (!inOuter) return false;
  for (final ring in f.holes) {
    if (_pointInPolygon(ring, lat, lng)) return false; // inside a hole → safe
  }
  return true;
}

/// ===== Local Cache =====
class _FenceCache {
  // Cache version v2 for the new schema.
  static String _kData(String negara, String negeri) => 'geofencing.cache.v2.$negara.$negeri';
  static String _kTime(String negara, String negeri) => 'geofencing.cache.time.v2.$negara.$negeri';

  static Future<void> save(String negara, String negeri, List<GeoFence> fences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kData(negara, negeri), jsonEncode(fences.map((e) => e.toMap()).toList()));
    await prefs.setInt(_kTime(negara, negeri), DateTime.now().millisecondsSinceEpoch);
    debugPrint('$_TAG [LOCAL SAVE] $negara/$negeri  fences=${fences.length}');
  }

  static Future<List<GeoFence>> load(String negara, String negeri) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kData(negara, negeri));
    if (raw == null) {
      debugPrint('$_TAG [LOCAL MISS] $negara/$negeri  (no cached fences)');
      return [];
    }
    final list = jsonDecode(raw) as List;
    final fences = list.map((m) => GeoFence.fromMap(m as Map<String, dynamic>)).toList();
    return fences;
  }
}

/// ===== Main Page =====
class GeofencingBootstrapPage extends StatefulWidget {
  final String negara; // country
  final String negeri; // state
  final Widget Function(BuildContext ctx, bool blocked) builder;

  const GeofencingBootstrapPage({
    super.key,
    required this.negara,
    required this.negeri,
    required this.builder,
  });

  @override
  State<GeofencingBootstrapPage> createState() => _GeofencingBootstrapPageState();
}

class _GeofencingBootstrapPageState extends State<GeofencingBootstrapPage> {
  List<GeoFence> _fences = [];
  bool _blocked = false;

  // Active fence preview data
  List<List<double>>? _activeOuter;
  List<List<List<double>>>? _activeHoles; // donut "open zones"
  String? _activeName;

  // live guidance fields
  double _distanceToExitM = 0.0;
  double? _exitLat, _exitLng;

  // non-blocking boot
  bool _bootDone = false;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _fsSub;
  StreamSubscription<Position>? _posSub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _fsSub?.cancel();
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final negara = widget.negara.trim();
    final negeri = widget.negeri.trim();

    _ensureLocationPermission(); // non-blocking

    // fail-open UI after 3s while fences keep loading
    Timer(const Duration(seconds: 3), () {
      if (!_bootDone && mounted) {
        _bootDone = true;
        setState(() {});
      }
    });

    // 1) load cache
    try {
      final cached = await _FenceCache.load(negara, negeri);
      if (cached.isNotEmpty) {
        _fences = cached;
        _bootDone = true;
        if (mounted) setState(() {});
      }
    } catch (_) {}

    // 2) one-time fetch if still empty
    if (_fences.isEmpty) {
      final fresh = await _fetchOnce();
      if (fresh.isNotEmpty) {
        _fences = fresh;
        _FenceCache.save(negara, negeri, fresh);
        _bootDone = true;
        if (mounted) setState(() {});
      } else {
        _bootDone = true;
        if (mounted) setState(() {});
      }
    }

    // 3) live firestore listener
    _fsSub?.cancel();
    _fsSub = _queryRef().snapshots().listen((snap) async {
      final fresh = <GeoFence>[];
      for (final d in snap.docs) {
        try {
          fresh.add(GeoFence.fromMap(d.data()));
        } catch (_) {}
      }
      _fences = fresh;
      if (mounted) setState(() {});
      _FenceCache.save(negara, negeri, fresh);
    });

    // 4) GPS listener
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 8,
      ),
    ).listen((pos) {
      final lat = pos.latitude, lng = pos.longitude;
      final insideFence = _fences.any((f) => isBlockedBy(f, lat, lng));
      final bypass = GeofencingController.instance.bypass.value;

      if (insideFence && !bypass) {
        _activeOuter = null;
        _activeHoles = null;
        _activeName = null;
        for (final f in _fences) {
          if (!f.active) continue;
          if (isBlockedBy(f, lat, lng)) {
            _activeOuter = f.outer;
            _activeHoles = f.holes;
            _activeName = f.name;
            break;
          }
        }
        final res = _nearestExitMetersAndPoint(lat, lng);
        _distanceToExitM = (res[0] as double);
        _exitLat = (res[1] as double?);
        _exitLng = (res[2] as double?);
      } else {
        _activeOuter = null;
        _activeHoles = null;
        _activeName = null;
        _distanceToExitM = 0.0;
        _exitLat = null;
        _exitLng = null;
      }

      final nextMode = bypass ? BlockMode.none : (insideFence ? BlockMode.full : BlockMode.none);
      GeofencingController.instance.mode.value = nextMode;
      setState(() => _blocked = nextMode != BlockMode.none);
    });
  }

  Future<List<GeoFence>> _fetchOnce() async {
    try {
      final qs = await _queryRef().get();
      return qs.docs.map((d) => GeoFence.fromMap(d.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Query<Map<String, dynamic>> _queryRef() {
    return FirebaseFirestore.instance
        .collection(widget.negara)
        .doc(widget.negeri)
        .collection('information')
        .doc('geo_fencing')
        .collection('all_geo_fencing')
        .where('active', isEqualTo: true);
  }

  List<dynamic> _nearestExitMetersAndPoint(double lat, double lng) {
    double bestMeters = double.infinity;
    double? bestLat, bestLng;

    for (final f in _fences) {
      if (!f.active) continue;
      if (!isBlockedBy(f, lat, lng)) continue;
      final poly = f.outer;
      for (int i = 0, j = poly.length - 1; i < poly.length; j = i++) {
        final aLat = poly[j][0], aLng = poly[j][1];
        final bLat = poly[i][0], bLng = poly[i][1];
        final ax = aLng, ay = aLat;
        final bx = bLng, by = bLat;
        final px = lng, py = lat;
        final abx = bx - ax, aby = by - ay;
        final apx = px - ax, apy = py - ay;
        final ab2 = abx * abx + aby * aby;
        double t = ab2 == 0 ? 0 : ((apx * abx + apy * aby) / ab2);
        t = t.clamp(0.0, 1.0);
        final qx = ax + t * abx;
        final qy = ay + t * aby;
        final dKm = _haversineKm(py, px, qy, qx);
        final dM = dKm * 1000.0;
        if (dM < bestMeters) {
          bestMeters = dM;
          bestLat = qy;
          bestLng = qx;
        }
      }
    }
    if (bestMeters == double.infinity) return [0.0, null, null];
    return [bestMeters, bestLat, bestLng];
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0088;
    final dLat = (lat2 - lat1) * (pi / 180.0);
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) * cos(lat2 * (pi / 180.0)) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  Future<void> _ensureLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      await Geolocator.openLocationSettings();
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_bootDone) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      children: [
        widget.builder(context, _blocked),
        if (_blocked)
          BlockedOverlay(
            regionLabel: '${widget.negara} • ${widget.negeri}',
            distanceMeters: _distanceToExitM,
            exitLat: _exitLat,
            exitLng: _exitLng,
            driverLat: Gv.driverLat,
            driverLng: Gv.driverLng,
            outerForPreview: _activeOuter,
            holesForPreview: _activeHoles,
            zoneName: _activeName,
            onOpenPreview: () {
              if (_activeOuter == null || _activeOuter!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Zone polygon not available yet')),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ZonePreviewPage(
                    regionLabel: '${widget.negara} • ${widget.negeri}',
                    outer: _activeOuter!,
                    holes: _activeHoles ?? const [],
                    driverLat: Gv.driverLat,
                    driverLng: Gv.driverLng,
                    exitLat: _exitLat,
                    exitLng: _exitLng,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
