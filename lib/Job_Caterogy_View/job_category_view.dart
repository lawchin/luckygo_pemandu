import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/Job_Caterogy_View/auto_button.dart';
import 'package:luckygo_pemandu/Job_Caterogy_View/bucket_labels.dart';
import 'package:luckygo_pemandu/Job_Caterogy_View/distance_utils.dart';
import 'package:luckygo_pemandu/gen_l10n/app_localizations.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/view_job_details/distance_utils.dart';
import 'package:luckygo_pemandu/view_job_details/view_job_details.dart';

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
    List.generate(3, (i) => i + 1),
    key: (e) => e,
    value: (_) => 0,
  );

  @override
  Widget build(BuildContext context) {
    final Map<String, double> roadDistances = {};
    final Map<String, int> etaDurations = {};
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection(Gv.negara)
              .doc(Gv.negeri)
              .collection('active_job')
              .doc('active_job_lite')
              .snapshots(),
          builder: (context, snapshot) {
            final l = AppLocalizations.of(context)!;
            if (!snapshot.hasData || snapshot.data!.data() == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!.data() as Map<String, dynamic>;
            flyBuckets.updateAll((key, value) => 0);
            roadBuckets.updateAll((key, value) => 0);
            final List<Future<void>> roadTasks = [];
            for (var entry in data.entries) {
              if (entry.key == 'claimed_jobs' || entry.value is Map) continue;
              if (ignoredLiteJobIds.contains(entry.key)) continue;
              final jobString = entry.value.toString();
              final parts = jobString.split('·');
              if (parts.length < 35) continue;
              final passengerCount = int.tryParse(parts[3]) ?? 0;
              if (passengerCount > Gv.vehicleCapacity) continue;
              final pickupLat = double.tryParse(parts[11]) ?? 0;
              final pickupLon = double.tryParse(parts[12]) ?? 0;
              final flyKm = flyDistance(Gv.driverGp.latitude, Gv.driverGp.longitude, pickupLat, pickupLon);

              // ✅ FIX: Only assign to fly bucket if flyKm > 5
              if (flyKm > 5) {
                final flyBucketValue = flyBucket(flyKm);
                flyBuckets[flyBucketValue] = (flyBuckets[flyBucketValue] ?? 0) + 1;
              }

              // ✅ Road logic only for flyKm ≤ 5
              if (flyKm <= 5) {
                final task = getRoadDistanceAndEta(
                  lat1: Gv.driverGp.latitude,
                  lon1: Gv.driverGp.longitude,
                  lat2: pickupLat,
                  lon2: pickupLon,
                  fallbackDistanceFn: flyDistance,
                ).then((result) {
                  final roadKm = result.km;
                  final etaMinutes = result.eta;
                  final roadBucketValue = roadBucket(roadKm);
                  roadBuckets[roadBucketValue] = (roadBuckets[roadBucketValue] ?? 0) + 1;
                  roadDistances[entry.key] = roadKm;
                  etaDurations[entry.key] = etaMinutes;
                });
                roadTasks.add(task);
              }
            }
            return Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    'assets/images/jcv_bg.png',
                    fit: BoxFit.cover,
                  ),
                ),
                FutureBuilder(
                  future: Future.wait(roadTasks),
                  builder: (context, _) {
                    final cards = <Widget>[];
                    cards.add(
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Back'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.black54,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                                textStyle: const TextStyle(fontSize: 16),
                              ),
                            ),
                            AutoButton(),
                          ],
                        ),
                      ),
                    );
                    for (int i = 1; i <= Gv.groupCapability; i++) {
final labels = bucketLabels(context);
final label  = labels[i] ?? 'Bucket $i';
                      final count = i <= 3 ? roadBuckets[i] ?? 0 : flyBuckets[i] ?? 0;
                      cards.add(
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => VJD(
                                  bI: i,
                                  rD: roadDistances,
                                  eD: etaDurations,
                                ),
                              ),
                            );
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: ListTile(
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(label),
                                  if (i == 1)
                                    Text('${l.below}', style: TextStyle(height: 0.5, fontSize: 10, color: Colors.grey[700])),
                                  if (i == 2)
                                    Text('${l.oneFive}', style: TextStyle(height: 0.5, fontSize: 10, color: Colors.grey[700])),
                                  if (i == 3)
                                    Text('${l.three}', style: TextStyle(height: 0.5, fontSize: 10, color: Colors.grey[700])),
                                  if (i == 4)
                                    Text('${l.five}', style: TextStyle(height: 0.5, fontSize: 10, color: Colors.grey[700])),
                                  if (i == 5)
                                    Text('${l.seven}', style: TextStyle(height: 0.5, fontSize: 10, color: Colors.grey[700])),
                                ],
                              ),
                              trailing: CircleAvatar(
                                backgroundColor: Colors.blueGrey[700],
                                child: Text(
                                  '$count',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.only(top: 16, bottom: 32),
                      children: cards,
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
