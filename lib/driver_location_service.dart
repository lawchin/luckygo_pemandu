import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:luckygo_pemandu/global.dart';

class DriverLocationService {
  DriverLocationService._();
  static final DriverLocationService instance = DriverLocationService._();

  StreamSubscription<Position>? _sub;

  // ---------- Existing: write into passenger's active job ----------
  bool _writeToPassengerJob = false;
  DocumentReference<Map<String, dynamic>>? _passengerJobRef;
  Position? _lastWrittenJob; // (renamed from _lastWritten for clarity)

  // ---------- NEW: live share -> {negara}/{negeri}/live_shares/{sid}/positions ----------
  bool _shareActive = false;
  CollectionReference<Map<String, dynamic>>? _sharePositionsRef;
  Position? _lastWrittenShare;

  // Current stream config (so we can tighten/relax the granularity on the fly)
  int _distanceFilterMeters = 100;
  LocationAccuracy _accuracy = LocationAccuracy.bestForNavigation;

  bool get isRunning => _sub != null;
  bool get isShareActive => _shareActive;

  /// Start (or restart) the single Geolocator stream.
  /// You can change [distanceFilterMeters] / [accuracy] when calling enable/disable share.
  Future<void> start({
    int distanceFilterMeters = 100,
    LocationAccuracy accuracy = LocationAccuracy.bestForNavigation,
  }) async {
    _distanceFilterMeters = distanceFilterMeters;
    _accuracy = accuracy;

    // Permissions / services
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
      if (p != LocationPermission.always && p != LocationPermission.whileInUse) {
        return;
      }
    }
    if (!await Geolocator.isLocationServiceEnabled()) {
      // Consider: await Geolocator.openLocationSettings();
      return;
    }

    await _sub?.cancel();

    _sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: _accuracy,
        distanceFilter: _distanceFilterMeters,
      ),
    ).listen((pos) async {
      // Debug print (no Firestore cost unless flags are on)
      // ignore: avoid_print
      print('driver lat=${pos.latitude}, lng=${pos.longitude} (df=$_distanceFilterMeters)');

      // ---- Existing: write to passenger's active job ----
      if (_writeToPassengerJob && _passengerJobRef != null) {
        final shouldWriteJob = _lastWrittenJob == null ||
            Geolocator.distanceBetween(
                  _lastWrittenJob!.latitude,
                  _lastWrittenJob!.longitude,
                  pos.latitude,
                  pos.longitude,
                ) >= 25; // ~25m threshold for job doc

        if (shouldWriteJob) {
          _lastWrittenJob = pos;
          try {
            await _passengerJobRef!.set({
              'x_driver_geopoint': GeoPoint(pos.latitude, pos.longitude),
              'x_driver_last_update': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (e) {
            // ignore: avoid_print
            print('DriverLocationService job write error: $e');
          }
        }
      }

      // ---- NEW: write to live_shares/{sid}/positions when sharing ----
      if (_shareActive && _sharePositionsRef != null) {
        final shouldWriteShare = _lastWrittenShare == null ||
            Geolocator.distanceBetween(
                  _lastWrittenShare!.latitude,
                  _lastWrittenShare!.longitude,
                  pos.latitude,
                  pos.longitude,
                ) >= 20; // ~20m for smoother public tracking

        if (shouldWriteShare) {
          _lastWrittenShare = pos;
          try {
            await _sharePositionsRef!.add({
              'lat': pos.latitude,
              'lng': pos.longitude,
              'speed': pos.speed,
              'heading': pos.heading,
              'ts': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            // ignore: avoid_print
            print('DriverLocationService share write error: $e');
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

  // ---------------- Bind/unbind passenger job (your original behavior) ----------------

  /// Call WHEN DRIVER ACCEPTS a job.
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
    _lastWrittenJob = null; // reset dedupe for job
  }

  /// Unbind when job is canceled/completed; stops WRITING but continues printing.
  void unbindPassengerJob() {
    _writeToPassengerJob = false;
    _passengerJobRef = null;
    _lastWrittenJob = null;
  }

  // ===================== Live Share controls (NEW) =====================

  /// Enable live share writing and (optionally) restart stream with finer granularity.
  /// Path: {negara}/{negeri}/live_shares/{sid}/positions
  Future<void> enableLiveShare({
    required String negara,
    required String negeri,
    required String sid,
    int distanceFilterForShare = 20, // smoother public updates while sharing
  }) async {
    _sharePositionsRef = FirebaseFirestore.instance
        .collection(negara)
        .doc(negeri)
        .collection('live_shares')
        .doc(sid)
        .collection('positions');

    _shareActive = true;
    _lastWrittenShare = null;

    // If our current stream is coarser than requested, restart it finer.
    if (!isRunning || _distanceFilterMeters > distanceFilterForShare) {
      await start(distanceFilterMeters: distanceFilterForShare, accuracy: _accuracy);
    }
  }

  /// Disable live share writing and (optionally) restore coarser granularity.
  Future<void> disableLiveShare({int restoreDistanceFilter = 100}) async {
    _shareActive = false;
    _sharePositionsRef = null;
    _lastWrittenShare = null;

    // If we tightened the stream for sharing, relax it back.
    if (isRunning && _distanceFilterMeters < restoreDistanceFilter) {
      await start(distanceFilterMeters: restoreDistanceFilter, accuracy: _accuracy);
    }
  }
}


// import 'dart:async';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:luckygo_pemandu/global.dart';

// class DriverLocationService {
//   DriverLocationService._();
//   static final DriverLocationService instance = DriverLocationService._();

//   StreamSubscription<Position>? _sub;

//   // Toggle writing when driver is on an active job
//   bool _writeToPassengerJob = false;
//   DocumentReference<Map<String, dynamic>>? _passengerJobRef;

//   // Optional: last written point to avoid redundant writes
//   Position? _lastWritten;

//   bool get isRunning => _sub != null;

//   /// Call after login (or app resume) to start printing driver GPS every ~100m.
//   Future<void> start() async {
//     // ensure permission (safe-guard)
//     var p = await Geolocator.checkPermission();
//     if (p == LocationPermission.denied) {
//       p = await Geolocator.requestPermission();
//       if (p != LocationPermission.always && p != LocationPermission.whileInUse) {
//         return;
//       }
//     }
//     if (!await Geolocator.isLocationServiceEnabled()) {
//       // you can prompt: await Geolocator.openLocationSettings();
//       return;
//     }

//     await _sub?.cancel();
//     _sub = Geolocator.getPositionStream(
//       locationSettings: const LocationSettings(
//         accuracy: LocationAccuracy.bestForNavigation,
//         distanceFilter: 100, // print every ~100 m
//       ),
//     ).listen((pos) async {
//       // Always print to console
//       // (no Firestore cost unless _writeToPassengerJob = true)
//       // ignore: avoid_print
//       print('driver lat=${pos.latitude}, lng=${pos.longitude}');

//       if (_writeToPassengerJob && _passengerJobRef != null) {
//         // Optionally skip if same tile as last write
//         if (_lastWritten == null ||
//             Geolocator.distanceBetween(
//                   _lastWritten!.latitude,
//                   _lastWritten!.longitude,
//                   pos.latitude,
//                   pos.longitude,
//                 ) >= 25 /* extra safety: write only if moved ~25m since last write */) {
//           _lastWritten = pos;

//           try {
//             await _passengerJobRef!.set({
//               'x_driver_geopoint': GeoPoint(pos.latitude, pos.longitude),
//               'x_driver_last_update': FieldValue.serverTimestamp(),
//             }, SetOptions(merge: true));
//           } catch (e) {
//             // ignore: avoid_print
//             print('DriverLocationService write error: $e');
//           }
//         }
//       }
//     });
//   }

//   /// Stop listening (e.g., logout / app close)
//   Future<void> stop() async {
//     await _sub?.cancel();
//     _sub = null;
//   }

//   /// Bind to a passenger's active-job doc so we also WRITE location there.
//   /// Call this WHEN DRIVER ACCEPTS a job.
//   ///
//   /// Path: {negara}/{negeri}/passenger_account/{psgPhone}/my_active_job/{psgPhone}
//   void bindToPassengerJob(String passengerPhone) {
//     if (passengerPhone.isEmpty) return;

//     _passengerJobRef = FirebaseFirestore.instance
//         .collection(Gv.negara)
//         .doc(Gv.negeri)
//         .collection('passenger_account')
//         .doc(passengerPhone)
//         .collection('my_active_job')
//         .doc(passengerPhone);

//     _writeToPassengerJob = true;
//     _lastWritten = null; // reset write dedupe
//   }

//   /// Unbind when job is canceled/completed; stops WRITING but continues printing.
//   void unbindPassengerJob() {
//     _writeToPassengerJob = false;
//     _passengerJobRef = null;
//     _lastWritten = null;
//   }
// }
