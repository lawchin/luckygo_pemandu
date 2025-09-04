import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:luckygo_pemandu/global.dart';

class DriverSosLocationTracker {
  DriverSosLocationTracker._();
  static final DriverSosLocationTracker instance = DriverSosLocationTracker._();

  StreamSubscription<Position>? _sub;
  DocumentReference<Map<String, dynamic>>? _docRef;

  bool get isRunning => _sub != null;

  Future<bool> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.whileInUse || p == LocationPermission.always;
  }

  DocumentReference<Map<String, dynamic>> _sosDoc(String sosId) {
    return FirebaseFirestore.instance
        .collection(Gv.negara!)         // e.g. 'Malaysia'
        .doc(Gv.negeri)                 // e.g. 'Selangor'
        .collection('help_center')
        .doc('SOS')
        .collection('sos_data')
        .doc(sosId);
  }

  /// Start live tracking for DRIVER. Safe to call multiple times (idempotent).
  Future<bool> start({required String sosId}) async {
    if (isRunning) return true;
    if (!await _ensurePermission()) return false;

    _docRef = _sosDoc(sosId);

    // 1) write an initial snapshot
    final first = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await _docRef!.set({
      // metadata
      'status': 'active',
      'trigger_by': 'driver',
      'trigger_time': FieldValue.serverTimestamp(),

      // driver profile
      'driver_name': Gv.userName,
      'driver_phone': Gv.loggedUser,
      'driver_vehicle_details': Gv.driverVehicleDetails,

      // latest driver location (flat fields to avoid nested merge issues)
      'driver_lat': first.latitude,
      'driver_lng': first.longitude,
      'driver_speed': first.speed,         // m/s
      'driver_heading': first.heading,     // degrees, iOS/Android support varies
      'driver_accuracy': first.accuracy,   // meters
      'driver_last_update': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // optional: keep a trace history for the driver
    await _docRef!.collection('trace_driver').add({
      'ts': FieldValue.serverTimestamp(),
      'gp': GeoPoint(first.latitude, first.longitude),
      'speed': first.speed,
      'heading': first.heading,
      'acc': first.accuracy,
    });

    // 2) subscribe to continuous updates
    final settings = const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 50, // meters; tune for your needs
    );

    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(
      (p) async {
        try {
          await _docRef!.set({
            'driver_lat': p.latitude,
            'driver_lng': p.longitude,
            'driver_speed': p.speed,
            'driver_heading': p.heading,
            'driver_accuracy': p.accuracy,
            'driver_last_update': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          // append to trace (optional)
          await _docRef!.collection('trace_driver').add({
            'ts': FieldValue.serverTimestamp(),
            'gp': GeoPoint(p.latitude, p.longitude),
            'speed': p.speed,
            'heading': p.heading,
            'acc': p.accuracy,
          });
        } catch (_) {
          // swallow to keep the stream alive; optionally log
        }
      },
      onError: (_) async {
        await stop(resolved: false, note: 'driver stream error');
      },
      cancelOnError: false,
    );

    return true;
  }

  /// Stop tracking. If [resolved] is true, we mark the SOS as resolved; else canceled.
  Future<void> stop({bool resolved = true, String? note}) async {
    await _sub?.cancel();
    _sub = null;

    if (_docRef != null) {
      await _docRef!.set({
        'status': resolved ? 'resolved' : 'canceled',
        'driver_stop_time': FieldValue.serverTimestamp(),
        if (note != null) 'driver_note': note,
      }, SetOptions(merge: true));
    }

    _docRef = null;
  }
}
