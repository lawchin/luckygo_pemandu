import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/view15/view_15.dart';
import 'package:luckygo_pemandu/view_job_details/item_scroller_view.dart';
import 'package:luckygo_pemandu/view_job_details/tips_column.dart';
import 'package:luckygo_pemandu/view_job_details/eta_visual_row.dart';

class VjdCard extends StatelessWidget {
  final String jobKey;
  final String jobString;
  final Map<String, double> rD; // road distances (km) by jobId
  final Map<String, int> eD;    // eta minutes by jobId

  const VjdCard({
    super.key,
    required this.jobKey,
    required this.jobString,
    required this.rD,
    required this.eD,
  });

  @override
  Widget build(BuildContext context) {
    final p = jobString.split('·');

    String nz(String? s) {
      final v = s?.trim();
      return (v == null || v.isEmpty || v == '-') ? 'NOT PROVIDED' : v;
    }

    final passengerCount = p[3];
    final jumlahKm = p[4];
    final totalPrice = double.tryParse(p[5])?.toStringAsFixed(2) ?? p[5];

    final pa1 = nz(p.length > 7 ? p[7] : null);
    final pa2 = nz(p.length > 8 ? p[8] : null);
    final da1 = nz(p.length > 9 ? p[9] : null);
    final da2 = nz(p.length > 10 ? p[10] : null);
    final pickup = '$pa1,\n$pa2';
    final dropoff = '$da1,\n$da2';

    bool flagTrue(int i) => p.length > i && p[i].trim().toLowerCase() == 'true';
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

    return InkWell(
onTap: () async {
  final p = jobString.split('·');
  final jobId = p[0].trim();
  Gv.liteJobId = jobId; // ✅ Store jobId for future reference

  // Update passenger phone
  if (p.length > 1) {
    final phone = p[1].trim();
    if (phone.isNotEmpty && phone != '-') {
      Gv.passengerPhone = phone;
    }
  }

  // Update total price
  if (p.length > 5) {
    final price = double.tryParse(p[5].trim());
    if (price != null) {
      Gv.totalPrice = price;
    }
  }

  // Update total km
  if (p.length > 4) {
    final km = double.tryParse(p[4].trim());
    if (km != null) {
      Gv.totalKm = km;
    }
  }

  // Update pickup and dropoff addresses
  Gv.sAdd1 = (p.length > 7) ? p[7].trim() : '';
  Gv.sAdd2 = (p.length > 8) ? p[8].trim() : '';
  Gv.dAdd1 = (p.length > 9) ? p[9].trim() : '';
  Gv.dAdd2 = (p.length > 10) ? p[10].trim() : '';

  // Update road ETA and KM
  Gv.roadEta = eD[jobKey] ?? -1;
  Gv.roadKm = rD[jobKey] ?? 0;

  print('Negara: ${Gv.negara}');
  print('Negeri: ${Gv.negeri}');
  print('Passenger Phone: ${Gv.passengerPhone}');
  print('Total Price: ${Gv.totalPrice}');
  print('Total KM: ${Gv.totalKm}');
  print('Pickup Address 1: ${Gv.sAdd1}');
  print('Pickup Address 2: ${Gv.sAdd2}');
  print('Dropoff Address 1: ${Gv.dAdd1}');
  print('Dropoff Address 2: ${Gv.dAdd2}');
  print('Road ETA: ${Gv.roadEta}');
  print('Road KM: ${Gv.roadKm}');
  print('Lite Job ID: ${Gv.liteJobId}');

  final docRef = FirebaseFirestore.instance
      .collection(Gv.negara)
      .doc(Gv.negeri)
      .collection('active_job')
      .doc('active_job_lite');

  try {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final data = snapshot.data();

      if (data == null || !data.containsKey(jobId)) return;

      final jobValue = data[jobId];
      Gv.liteJobData = jobValue; // ✅ Store job data for potential restoration

      // Remove from active
      transaction.update(docRef, {jobId: FieldValue.delete()});

      // Move to claimed_jobs
      final claimed = Map<String, dynamic>.from(data['claimed_jobs'] ?? {});
      claimed[jobId] = jobValue;
      transaction.update(docRef, {'claimed_jobs': claimed});
    });

    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => View15(),
    //   ),
    // );

if (context.mounted) {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (_) => const View15()),
  );
}

    
  } catch (e) {
    print('Firestore transaction failed: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to claim job. Please try again.')),
    );
  }
},


      child: Card(
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
              // Top row (icons, km, tips, price)
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
                    child: Text('→', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  ),
                  Image.asset(
                    'assets/images/finish.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      Column(
                        children: [
                          Text('', style: const TextStyle(fontSize: 14,height:0.8)),
                          Text('$jumlahKm', style: const TextStyle(fontSize: 14,height:0.8)),
                        ],
                      ),
                      Text(' km', style: const TextStyle(fontSize: 14)),
                    ],
                  ),
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
                      Text(
                        '${Gv.currency}',
                        style: const TextStyle(fontSize: 10, color: Colors.grey, height: 2),
                      ),
                      Text(
                        '$totalPrice',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, height: 0.2),
                      ),
                    ],
                  ),
                ],
              ),
      
              const Divider(height: 12, thickness: 1),
      
              // Special needs icons
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
      
              // Pickup row
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
                      style: const TextStyle(height: 1),
                    ),
                  ),
                ],
              ),
      
              const SizedBox(height: 6),
      
              // Dropoff row
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
                      style: const TextStyle(height: 1),
                    ),
                  ),
                ],
              ),
      
              // Item scroller (flags)
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
      
              // ETA row
              EtaVisualRow(
                roadKm: rD[jobKey] ?? 0,
                etaMinutes: eD[jobKey] ?? -1,
                index6: int.tryParse(p[6]) ?? 0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
