import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/global.dart';

/// Lightweight model for bucketing + later road distance calls.
class JobLite {
  final String id;      // liteJobId (map key)
  final String raw;     // original string (for later use)
  final double srcLat;  // pickup latitude
  final double srcLng;  // pickup longitude
  final double airKm;   // Haversine distance from driver → pickup (km)

  JobLite({
    required this.id,
    required this.raw,
    required this.srcLat,
    required this.srcLng,
    required this.airKm,
  });
}

/// Buckets container with your exact ranges.
class NearbyBuckets {
  final List<JobLite> bucket1; // ≤ 1.5 km
  final List<JobLite> bucket2; // 1.51–5.0 km
  final List<JobLite> bucket3; // 5.1–7.49 km
  final List<JobLite> bucket4; // 7.5–9.99 km
  final List<JobLite> bucket5; // 10–19.99 km
  final List<JobLite> bucket6; // 20–30 km

  NearbyBuckets({
    required this.bucket1,
    required this.bucket2,
    required this.bucket3,
    required this.bucket4,
    required this.bucket5,
    required this.bucket6,
  });
}

Future<NearbyBuckets> loadAndBucketJobs({
  required String negara, // Gv.negara
  required String negeri, // Gv.negeri
  // Driver location (use your fixed values or pass live GPS here)
  // double driverLat = 5.992976057618301,
  // double driverLng = 116.13490015392537,
  // WE DONT USE THIS.... WE CAN GET A PROPER DRVIER LATITUDE AND LONGITUDE FROM GPS. BECAUSE WE TEST THE APPS IN REAL DEVICE WHERE IT GRANT PERMISSION
}) async {
  final doc = await FirebaseFirestore.instance
      .collection(negara)
      .doc(negeri)
      .collection('active_job')
      .doc('active_job_lite')
      .get();

  final data = doc.data() ?? {};
  // Buckets
  final b1 = <JobLite>[];
  final b2 = <JobLite>[];
  final b3 = <JobLite>[];
  final b4 = <JobLite>[];
  final b5 = <JobLite>[];
  final b6 = <JobLite>[];

  // Iterate each entry (key = liteJobId, value = '·'-string)
  data.forEach((liteJobId, rawValue) {
    if (rawValue is! String) return;
    // Split by '·' and trim
    final parts = rawValue.split('·').map((s) => s.trim()).toList();
    if (parts.length != 33) {
      // malformed row → skip
      return;
    }

    // Parse pickup lat/lng at indices 11 and 12
    final sLat = double.tryParse(parts[11]);
    final sLng = double.tryParse(parts[12]);
    if (sLat == null || sLng == null) return;

    // Haversine from driver → pickup
    final dKm = _haversineKm(Gv.driverLat, Gv.driverLng, sLat, sLng);
    // IM USING MY GLOBAL VARIABLES

    // Only keep jobs within 30 km for nearby view
    if (dKm <= 30.0) {
      final job = JobLite(
        id: liteJobId,
        raw: rawValue,
        srcLat: sLat,
        srcLng: sLng,
        airKm: double.parse(dKm.toStringAsFixed(2)), // nice for display
      );

      // Assign to your exact buckets
      if (dKm <= 1.5) {
        b1.add(job); // ≤ 1.5
      } else if (dKm <= 5.0) {
        b2.add(job); // 1.51–5.0
      } else if (dKm <= 7.49) {
        b3.add(job); // 5.1–7.49
      } else if (dKm <= 9.99) {
        b4.add(job); // 7.5–9.99
      } else if (dKm <= 19.99) {
        b5.add(job); // 10–19.99
      } else {
        b6.add(job); // 20–30
      }
    }
  });

  // Sort each bucket by air distance ascending
  int _cmp(JobLite a, JobLite b) => a.airKm.compareTo(b.airKm);
  b1.sort(_cmp); b2.sort(_cmp); b3.sort(_cmp);
  b4.sort(_cmp); b5.sort(_cmp); b6.sort(_cmp);

  return NearbyBuckets(
    bucket1: b1,
    bucket2: b2,
    bucket3: b3,
    bucket4: b4,
    bucket5: b5,
    bucket6: b6,
  );
}

/// Haversine distance (km) between two lat/lng points.
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
