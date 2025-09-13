import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:math';

import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/job_view/view_job_details.dart';

class JCV extends StatefulWidget {
  const JCV({super.key});

  @override
  State<JCV> createState() => _JCVState();
}

class _JCVState extends State<JCV> {
  final Map<int, int> flyBuckets = Map<int, int>.fromIterable(
    List.generate(11, (i) => i + 5),
    key: (e) => e,
    value: (_) => 0,
  );

  final Map<int, int> roadBuckets = Map<int, int>.fromIterable(
    List.generate(4, (i) => i + 1),
    key: (e) => e,
    value: (_) => 0,
  );

  double _deg2rad(double deg) => deg * pi / 180;

  double _flyDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
        sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  // 🔴 UPDATED: Returns both roadKm and ETA as int (minutes)
Future<(double, int)> _getRoadDistanceAndEta(double lat1, double lon1, double lat2, double lon2) async {
  final apiKey = 'AIzaSyDa5S3_IbRkjAJsH53VIXca0ZPLm9WcSHw'; // 🔐 Replace with your actual key
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/directions/json?origin=$lat1,$lon1&destination=$lat2,$lon2&key=$apiKey'
  );

  try {
    final response = await http.get(url);
    if (response.statusCode != 200) throw Exception('Failed to fetch directions');

    final data = jsonDecode(response.body);

    // ✅ Defensive access
    final route = data['routes']?[0];
    final leg = route?['legs']?[0];
    final meters = leg?['distance']?['value'];
    final seconds = leg?['duration']?['value'];

    if (meters == null || seconds == null) throw Exception('Missing distance or duration');

    final roadKm = (meters / 1000.0) as double;

    // ✅ Custom rounding logic (optional)
    final rawMinutes = seconds / 60.0;
    final etaMinutes = rawMinutes < 0.8
        ? rawMinutes.floor()
        : rawMinutes.floor() + 1;

    return ((meters / 1000.0) as double, etaMinutes as int);
  } catch (e) {
    print('[JCV] ❌ Road distance error: $e');
    final fallbackKm = _flyDistance(lat1, lon1, lat2, lon2);
    return (fallbackKm, -1); // ✅ fallback ETA
  }
}


  int _flyBucket(double km) {
    if (km <= 7.5) return 5;
    if (km <= 10) return 6;
    if (km <= 20) return 7;
    if (km <= 30) return 8;
    if (km <= 50) return 9;
    if (km <= 100) return 10;
    if (km <= 200) return 11;
    if (km <= 500) return 12;
    if (km <= 1000) return 13;
    if (km <= 10000) return 14;
    return 15;
  }

  int _roadBucket(double km) {
    if (km <= 1.5) return 1;
    if (km <= 3) return 2;
    if (km <= 5) return 3;
    return 4;
  }

  final bucketLabels = {
    1: 'Next to you',
    2: 'Very Near',
    3: 'Quite Near',
    4: 'Still Reachable',
    5: 'Nearby Zone',
    6: 'Short Drive',
    7: 'Medium Drive',
    8: 'Long Drive',
    9: 'Far Away',
    10: 'Distant Job',
    11: 'Remote Area',
    12: 'Far Region',
    13: 'Cross-State',
    14: 'Cross-Country',
    15: 'Very Far',
  };

  @override
  Widget build(BuildContext context) {
    final Map<String, double> roadDistances = {}; // 🔴
    final Map<String, int> etaDurations = {};     // 🔴 ETA as int

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection(Gv.negara)
          .doc(Gv.negeri)
          .collection('active_job')
          .doc('active_job_lite')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.data() == null) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;

        flyBuckets.updateAll((key, value) => 0);
        roadBuckets.updateAll((key, value) => 0);

        final List<Future<void>> roadTasks = [];

        for (var entry in data.entries) {
          if (entry.key == 'claimed_jobs' || entry.value is Map) continue;

          final jobString = entry.value.toString();
          final parts = jobString.split('·');
          if (parts.length < 35) continue;

          final passengerCount = int.tryParse(parts[3]) ?? 0;
          if (passengerCount > Gv.vehicleCapacity) continue;

          final pickupLat = double.tryParse(parts[11]) ?? 0;
          final pickupLon = double.tryParse(parts[12]) ?? 0;
          final flyKm = _flyDistance(Gv.driverGp.latitude, Gv.driverGp.longitude, pickupLat, pickupLon);
          final flyBucket = _flyBucket(flyKm);
          flyBuckets[flyBucket] = (flyBuckets[flyBucket] ?? 0) + 1;

          if (flyKm <= 7.5) {
            final task = _getRoadDistanceAndEta(
              Gv.driverGp.latitude,
              Gv.driverGp.longitude,
              pickupLat,
              pickupLon,
            ).then((result) {
              final roadKm = result.$1;
              final etaMinutes = result.$2;

              final roadBucket = _roadBucket(roadKm);
              roadBuckets[roadBucket] = (roadBuckets[roadBucket] ?? 0) + 1;

              roadDistances[entry.key] = roadKm;     // 🔴
              etaDurations[entry.key] = etaMinutes; // 🔴
            });
            roadTasks.add(task);
          }
        }

        return FutureBuilder(
          future: Future.wait(roadTasks),
          builder: (context, _) {
            final cards = <Widget>[];
            for (int i = 1; i <= Gv.groupCapability; i++) {
              final label = bucketLabels[i] ?? 'Bucket $i';
              final count = i <= 4 ? roadBuckets[i] ?? 0 : flyBuckets[i] ?? 0;

              cards.add(
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VJD(
                          bucketIndex: i,
                          roadDistances: roadDistances, // 🔴
                          etaDurations: etaDurations,   // 🔴
                        ),
                      ),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(label, style: const TextStyle(fontSize: 16)),
                          Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }

            return ListView(children: cards);
          },
        );
      },
    );
  }
}
