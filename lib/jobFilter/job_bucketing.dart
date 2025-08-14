import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/global.dart';

class JobLite {
  final String id;
  final String raw;
  final double srcLat;
  final double srcLng;
  final double airKm;
  JobLite({
    required this.id,
    required this.raw,
    required this.srcLat,
    required this.srcLng,
    required this.airKm,
  });
}

class NearbyBuckets {
  final List<JobLite> bucket01;
  final List<JobLite> bucket02;
  final List<JobLite> bucket03;
  final List<JobLite> bucket04;
  final List<JobLite> bucket05;
  final List<JobLite> bucket06;
  final List<JobLite> bucket07;
  final List<JobLite> bucket08;
  final List<JobLite> bucket09;
  final List<JobLite> bucket10;
  final List<JobLite> bucket11;
  final List<JobLite> bucket12;
  final List<JobLite> bucket13;
  final List<JobLite> bucket14;
  NearbyBuckets({
    required this.bucket01,
    required this.bucket02,
    required this.bucket03,
    required this.bucket04,
    required this.bucket05,
    required this.bucket06,
    required this.bucket07,
    required this.bucket08,
    required this.bucket09,
    required this.bucket10,
    required this.bucket11,
    required this.bucket12,
    required this.bucket13,
    required this.bucket14,
  });
}

Future<NearbyBuckets> loadAndBucketJobs({
  required String negara,
  required String negeri,
}) async {
  final snap = await FirebaseFirestore.instance
      .collection(negara)
      .doc(negeri)
      .collection('active_job')
      .doc('active_job_lite')
      .get();

  final data = snap.data() ?? {};

  final b01 = <JobLite>[]; // ≤ 1.5
  final b02 = <JobLite>[]; // 1.51–2.5
  final b03 = <JobLite>[]; // 2.51–5
  final b04 = <JobLite>[]; // 5.1–7.5
  final b05 = <JobLite>[]; // 7.51–10
  final b06 = <JobLite>[]; // 10.1–20
  final b07 = <JobLite>[]; // 20.1–30
  final b08 = <JobLite>[]; // 30.1–50
  final b09 = <JobLite>[]; // 50.1–100
  final b10 = <JobLite>[]; // 100.1–200
  final b11 = <JobLite>[]; // 200.1–500
  final b12 = <JobLite>[]; // 500.1–1000
  final b13 = <JobLite>[]; // 1000.1–2000
  final b14 = <JobLite>[]; // 2000.1–5000

  data.forEach((liteJobId, rawValue) {
    if (rawValue is! String) return;
    final parts = rawValue.split('·').map((s) => s.trim()).toList();
    if (parts.length != 33) return;

    final sLat = double.tryParse(parts[11]);
    final sLng = double.tryParse(parts[12]);
    if (sLat == null || sLng == null) return;

    final dKm = _haversineKm(Gv.driverLat, Gv.driverLng, sLat, sLng);
    final job = JobLite(
      id: liteJobId,
      raw: rawValue,
      srcLat: sLat,
      srcLng: sLng,
      airKm: double.parse(dKm.toStringAsFixed(2)),
    );

    if (dKm <= 1.5) b01.add(job);
    else if (dKm <= 2.5) b02.add(job);
    else if (dKm <= 5.0) b03.add(job);
    else if (dKm <= 7.5) b04.add(job);
    else if (dKm <= 10.0) b05.add(job);
    else if (dKm <= 20.0) b06.add(job);
    else if (dKm <= 30.0) b07.add(job);
    else if (dKm <= 50.0) b08.add(job);
    else if (dKm <= 100.0) b09.add(job);
    else if (dKm <= 200.0) b10.add(job);
    else if (dKm <= 500.0) b11.add(job);
    else if (dKm <= 1000.0) b12.add(job);
    else if (dKm <= 2000.0) b13.add(job);
    else if (dKm <= 5000.0) b14.add(job);
  });

  int _cmp(JobLite a, JobLite b) => a.airKm.compareTo(b.airKm);
  for (final list in [b01,b02,b03,b04,b05,b06,b07,b08,b09,b10,b11,b12,b13,b14]) {
    list.sort(_cmp);
  }

  return NearbyBuckets(
    bucket01: b01, bucket02: b02, bucket03: b03, bucket04: b04,
    bucket05: b05, bucket06: b06, bucket07: b07, bucket08: b08,
    bucket09: b09, bucket10: b10, bucket11: b11, bucket12: b12,
    bucket13: b13, bucket14: b14,
  );
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0088;
  double _rad(double d) => d * math.pi / 180.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat/2) * math.sin(dLat/2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) *
      math.sin(dLon/2) * math.sin(dLon/2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}
