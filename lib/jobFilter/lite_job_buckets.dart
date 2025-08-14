// lib/job_filter/lite_job_buckets.dart
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/global.dart';

/// Lightweight model for bucketing + later road distance calls.
class JobLite {
  final String id;      // liteJobId (map key)
  final String raw;     // original packed string
  final double srcLat;  // pickup latitude
  final double srcLng;  // pickup longitude
  final double airKm;   // Haversine distance driver → pickup (km)

  JobLite({
    required this.id,
    required this.raw,
    required this.srcLat,
    required this.srcLng,
    required this.airKm,
  });
}

/// 14 buckets (we'll only fill up to Gv.groupCapability).
class NearbyBuckets {
  final List<JobLite> bucket1;  // ≤ 1.5 km
  final List<JobLite> bucket2;  // 1.51–2.5 km
  final List<JobLite> bucket3;  // 2.51–5 km
  final List<JobLite> bucket4;  // 5.1–7.5 km
  final List<JobLite> bucket5;  // 7.51–10 km
  final List<JobLite> bucket6;  // 10.1–20 km
  final List<JobLite> bucket7;  // 20.1–30 km
  final List<JobLite> bucket8;  // 30.1–50 km
  final List<JobLite> bucket9;  // 50.1–100 km
  final List<JobLite> bucket10; // 100.1–200 km
  final List<JobLite> bucket11; // 200.1–500 km
  final List<JobLite> bucket12; // 500.1–1000 km
  final List<JobLite> bucket13; // 1000.1–2000 km
  final List<JobLite> bucket14; // 2000.1–5000 km

  /// The highest bucket index we actually filled (== Gv.groupCapability clamped to 1..14).
  final int filledUpTo;

  NearbyBuckets({
    required this.bucket1,
    required this.bucket2,
    required this.bucket3,
    required this.bucket4,
    required this.bucket5,
    required this.bucket6,
    required this.bucket7,
    required this.bucket8,
    required this.bucket9,
    required this.bucket10,
    required this.bucket11,
    required this.bucket12,
    required this.bucket13,
    required this.bucket14,
    required this.filledUpTo,
  });
}

/// Loads the packed jobs and buckets by straight-line distance (free).
/// Only fills buckets up to `Gv.groupCapability` (1..14).
Future<NearbyBuckets> loadAndBucketJobs({
  required String negara, // Gv.negara
  required String negeri, // Gv.negeri
}) async {
  final doc = await FirebaseFirestore.instance
      .collection(negara)
      .doc(negeri)
      .collection('active_job')
      .doc('active_job_lite')
      .get();

  final data = doc.data() ?? {};

  // Prepare 14 buckets
  final b1  = <JobLite>[];
  final b2  = <JobLite>[];
  final b3  = <JobLite>[];
  final b4  = <JobLite>[];
  final b5  = <JobLite>[];
  final b6  = <JobLite>[];
  final b7  = <JobLite>[];
  final b8  = <JobLite>[];
  final b9  = <JobLite>[];
  final b10 = <JobLite>[];
  final b11 = <JobLite>[];
  final b12 = <JobLite>[];
  final b13 = <JobLite>[];
  final b14 = <JobLite>[];

  // Range upper-bounds for the 14 buckets (lower bound is previous+ε).
  // 1: ≤1.5, 2: ≤2.5, 3: ≤5, ... 14: ≤5000
  const upper = <double>[
    1.5, 2.5, 5.0, 7.5, 10.0, 20.0, 30.0, 50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0
  ];

  // Respect capability (clamp 1..14). If 4, we only fill buckets 1..4.
  final cap = Gv.groupCapability.clamp(1, 14);

  final driverLat = Gv.driverLat;
  final driverLng = Gv.driverLng;

  data.forEach((liteJobId, rawValue) {
    if (rawValue is! String) return;

    final parts = rawValue.split('·').map((s) => s.trim()).toList(growable: false);
    if (parts.length != 33) return;

    final sLat = double.tryParse(parts[11]);
    final sLng = double.tryParse(parts[12]);
    if (sLat == null || sLng == null) return;
    if (!_validCoord(sLat, sLng)) return;

    final dKm = _haversineKm(driverLat, driverLng, sLat, sLng);
    final idx = _bucketIndexFor(dKm, cap, upper); // 0-based index into buckets (0..cap-1), or -1

    if (idx == -1) return;

    final job = JobLite(
      id: liteJobId,
      raw: rawValue,
      srcLat: sLat,
      srcLng: sLng,
      airKm: double.parse(dKm.toStringAsFixed(2)),
    );

    switch (idx) {
      case 0:  b1.add(job);  break;
      case 1:  b2.add(job);  break;
      case 2:  b3.add(job);  break;
      case 3:  b4.add(job);  break;
      case 4:  b5.add(job);  break;
      case 5:  b6.add(job);  break;
      case 6:  b7.add(job);  break;
      case 7:  b8.add(job);  break;
      case 8:  b9.add(job);  break;
      case 9:  b10.add(job); break;
      case 10: b11.add(job); break;
      case 11: b12.add(job); break;
      case 12: b13.add(job); break;
      case 13: b14.add(job); break;
    }
  });

  // Sort filled buckets by distance asc
  int _cmp(JobLite a, JobLite b) => a.airKm.compareTo(b.airKm);
  final all = [b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13,b14];
  for (var i = 0; i < cap; i++) {
    all[i].sort(_cmp);
  }

  return NearbyBuckets(
    bucket1: b1,
    bucket2: b2,
    bucket3: b3,
    bucket4: b4,
    bucket5: b5,
    bucket6: b6,
    bucket7: b7,
    bucket8: b8,
    bucket9: b9,
    bucket10: b10,
    bucket11: b11,
    bucket12: b12,
    bucket13: b13,
    bucket14: b14,
    filledUpTo: cap,
  );
}

/// Returns 0-based bucket index for distance `dKm`, limited to `cap` buckets.
/// If `dKm` is greater than the cap’s upper bound, returns -1.
int _bucketIndexFor(double dKm, int cap, List<double> upperBounds) {
  // bucket 1: (0 .. ≤ upper[0]), bucket 2: (upper[0]+ε .. ≤ upper[1]), ...
  for (var i = 0; i < cap; i++) {
    if (dKm <= upperBounds[i]) return i;
  }
  return -1; // outside the highest enabled bucket
}

/// Haversine distance (km) — free, no API calls.
double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0088; // mean Earth radius in km
  double _deg2rad(double d) => d * math.pi / 180.0;

  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg2rad(lat1)) *
          math.cos(_deg2rad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

bool _validCoord(double lat, double lng) {
  if (lat == 0.0 && lng == 0.0) return false;
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}
