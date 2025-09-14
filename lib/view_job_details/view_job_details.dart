import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/view_job_details/distance_utils.dart';
import 'package:luckygo_pemandu/view_job_details/vjd_card.dart'; // uses VjdCard

class VJD extends StatelessWidget {
  final int bI;
  final Map<String, double> rD;
  final Map<String, int> eD;
  const VJD({
    super.key,
    int? bI,
    Map<String, double>? rD,
    Map<String, int>? eD,
    // old names (compat)
    int? bucketIndex,
    Map<String, double>? roadDistances,
    Map<String, int>? etaDurations,
  })  : bI = bI ?? bucketIndex ?? 0,
        rD = rD ?? roadDistances ?? const {},
        eD = eD ?? etaDurations ?? const {};

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('active_job')
        .doc('active_job_lite');

    return Scaffold(
      appBar: AppBar(title: Text('Bucket $bI Jobs')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(child: Text('No jobs yet.'));
          }

          final data = snapshot.data!.data()!;
          final entries = data.entries
              .where((e) => e.key != 'claimed_jobs' && e.value is String)
              .toList();

          final isRoadBucket = bI <= 4;

          final filtered = entries.where((entry) {
            final p = entry.value.toString().split('·');
            if (p.length < 35) return false;

            final passengerCount = int.tryParse(p[3]) ?? 0;
            if (passengerCount > Gv.vehicleCapacity) return false;

            final pickupLat = double.tryParse(p[11]) ?? 0;
            final pickupLon = double.tryParse(p[12]) ?? 0;

            final flyM = calculateFlyDistance(
              Gv.driverGp.latitude,
              Gv.driverGp.longitude,
              pickupLat,
              pickupLon,
            );

            if (isRoadBucket) {
              final roadM = rD[entry.key];
              if (roadM == null) return false;
              return roadBucket(roadM) == bI;
            } else {
              return flyBucket(flyM) == bI;
            }
          }).toList();

          if (filtered.isEmpty) {
            return const Center(child: Text('No jobs in this bucket.'));
          }

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final jobKey = filtered[index].key;
              final jobString = filtered[index].value.toString();
              return VjdCard(
                jobKey: jobKey,
                jobString: jobString,
                rD: rD,
                eD: eD,
              );
            },
          );
        },
      ),
    );
  }
}
