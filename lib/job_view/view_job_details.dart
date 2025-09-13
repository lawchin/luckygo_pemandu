import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/job_view/distance_utils.dart';
import 'package:luckygo_pemandu/job_view/eta_visual_row.dart';
import 'package:luckygo_pemandu/job_view/item_scroller_view.dart';
import 'package:luckygo_pemandu/job_view/tips_column.dart';

class VJD extends StatelessWidget {
  final int bucketIndex;
  final Map<String, double> roadDistances;
  final Map<String, int> etaDurations;

  const VJD({
    super.key,
    required this.bucketIndex,
    required this.roadDistances,
    required this.etaDurations,
  });

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('active_job')
        .doc('active_job_lite');

    return Scaffold(
      appBar: AppBar(title: Text('Bucket $bucketIndex Jobs')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: docRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data()!;
          final entries = data.entries
              .where((e) => e.key != 'claimed_jobs' && e.value is String)
              .toList();

          final isRoadBucket = bucketIndex <= 4;

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
              final roadM = roadDistances[entry.key];
              if (roadM == null) return false;
              return roadBucket(roadM) == bucketIndex;
            } else {
              return flyBucket(flyM) == bucketIndex;
}
          }).toList();

          return ListView.builder(
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final jobKey = filtered[index].key;
              final jobString = filtered[index].value.toString();
              final p = jobString.split('·');

              String nz(String? s) {
                final v = s?.trim();
                return (v == null || v.isEmpty || v == '-') ? 'NOT PROVIDED' : v;
              }

              final passengerCount = p[3];
              final jumlahKm = p[4];
              final totalPrice =
                  double.tryParse(p[5])?.toStringAsFixed(2) ?? p[5];

              final pa1 = nz(p.length > 7 ? p[7] : null);
              final pa2 = nz(p.length > 8 ? p[8] : null);
              final da1 = nz(p.length > 9 ? p[9] : null);
              final da2 = nz(p.length > 10 ? p[10] : null);
              final pickup = '$pa1,\n$pa2';
              final dropoff = '$da1,\n$da2';

              bool flagTrue(int i) =>
                  p.length > i && p[i].trim().toLowerCase() == 'true';
              final blind = flagTrue(15);
              final deaf = flagTrue(16);
              final mute = flagTrue(17);
              final wC = p[18];
              final sK = p[19];
              final sR = p[20];
              final sB = p[21];
              final lGE = p[22];
              final pT = p[23];
              final dG = p[24];
              final gT = p[25];
              final rT = p[26];
              final sN = p[27];
              final dR = p[28];
              final oF = p[29];
              final wF = p[30];
              final tW = p[31];
              final gS = p[32];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/ind_passenger.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              '→',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ),
                          Image.asset(
                            'assets/images/finish.png',
                            width: 32,
                            height: 32,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                          Text('$jumlahKm km', style: const TextStyle(fontSize: 14)),
                          const Spacer(),
                          SizedBox(
                            width: 60,
                            child: TipsColumn(
                              tip1: p.length > 33 ? p[33] : '0',
                              tip2: p.length > 34 ? p[34] : '0',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${Gv.currency}',
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.grey)),
                              Text(
                                '$totalPrice',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const Divider(height: 12, thickness: 1),


                      Row(
                        children: [
                          if (blind)
                            Image.asset('assets/images/blind_symbol.png',
                                width: 14, height: 14, fit: BoxFit.contain),
                          if (deaf) ...[
                            if (blind) const SizedBox(width: 6),
                            Image.asset('assets/images/deaf_symbol.png',
                                width: 14, height: 14, fit: BoxFit.contain),
                          ],
                          if (mute) ...[
                            if (blind || deaf) const SizedBox(width: 6),
                            Image.asset('assets/images/mute_symbol.png',
                                width: 14, height: 14, fit: BoxFit.contain),
                          ],
                        ],
                      ),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              Image.asset(
                                'assets/images/ind_passenger.png',
                                width: 40,
                                height: 42,
                                fit: BoxFit.contain,
                              ),
                              Positioned(
                                top: 0,
                                bottom: 2,
                                right: 6,
                                child: Text(
                                  '$passengerCount',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pickup,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(height: 1),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Image.asset(
                            'assets/images/finish.png',
                            width: 38,
                            height: 40,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dropoff,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(height: 1),
                            ),
                          ),
                        ],
                      ),
                      ISV(
                        wc: wC,
                        sk: sK,
                        sr: sR,
                        sb: sB,
                        lge: lGE,
                        pt: pT,
                        dg: dG,
                        gt: gT,
                        rt: rT,
                        sn: sN,
                        dr: dR,
                        of: oF,
                        wf: wF,
                        tw: tW,
                        gs: gS,
                      ),
                      const Divider(height: 12, thickness: 1),

                      EtaVisualRow(
                        roadKm: roadDistances[jobKey] ?? 0,
                        etaMinutes: etaDurations[jobKey] ?? -1,
                        index6: int.tryParse(p[6]) ?? 0,
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
