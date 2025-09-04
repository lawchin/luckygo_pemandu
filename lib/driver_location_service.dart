import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:luckygo_pemandu/global.dart';

class DriverLocationService {
  DriverLocationService._();
  static final DriverLocationService instance = DriverLocationService._();

  StreamSubscription<Position>? _sub;

  // Toggle writing when driver is on an active job
  bool _writeToPassengerJob = false;
  DocumentReference<Map<String, dynamic>>? _passengerJobRef;

  // Optional: last written point to avoid redundant writes
  Position? _lastWritten;

  bool get isRunning => _sub != null;

  /// Call after login (or app resume) to start printing driver GPS every ~100m.
  Future<void> start() async {
    // ensure permission (safe-guard)
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
      if (p != LocationPermission.always && p != LocationPermission.whileInUse) {
        return;
      }
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      // you can prompt: await Geolocator.openLocationSettings();
      return;
    }

    await _sub?.cancel();
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 100, // print every ~100 m
      ),
    ).listen((pos) async {
      // Always print to console
      // (no Firestore cost unless _writeToPassengerJob = true)
      // ignore: avoid_print
      print('driver lat=${pos.latitude}, lng=${pos.longitude}');

      if (_writeToPassengerJob && _passengerJobRef != null) {
        // Optionally skip if same tile as last write
        if (_lastWritten == null ||
            Geolocator.distanceBetween(
                  _lastWritten!.latitude,
                  _lastWritten!.longitude,
                  pos.latitude,
                  pos.longitude,
                ) >= 25 /* extra safety: write only if moved ~25m since last write */) {
          _lastWritten = pos;

          try {
            await _passengerJobRef!.set({
              'x_driver_geopoint': GeoPoint(pos.latitude, pos.longitude),
              'x_driver_last_update': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (e) {
            // ignore: avoid_print
            print('DriverLocationService write error: $e');
          }
        }
      }
    });
  }

  /// Stop listening (e.g., logout / app close)
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  /// Bind to a passenger's active-job doc so we also WRITE location there.
  /// Call this WHEN DRIVER ACCEPTS a job.
  ///
  /// Path: {negara}/{negeri}/passenger_account/{psgPhone}/my_active_job/{psgPhone}
  void bindToPassengerJob(String passengerPhone) {
    if (passengerPhone.isEmpty) return;

    _passengerJobRef = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('passenger_account')
        .doc(passengerPhone)
        .collection('my_active_job')
        .doc(passengerPhone);

    _writeToPassengerJob = true;
    _lastWritten = null; // reset write dedupe
  }

  /// Unbind when job is canceled/completed; stops WRITING but continues printing.
  void unbindPassengerJob() {
    _writeToPassengerJob = false;
    _passengerJobRef = null;
    _lastWritten = null;
  }
}
