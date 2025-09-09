import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';

class RatingHistory extends StatelessWidget {
  const RatingHistory({super.key});

  CollectionReference<Map<String, dynamic>> _historyRef() {
    final n = Gv.negara;
    final s = Gv.negeri;
    final u = Gv.loggedUser;
    return FirebaseFirestore.instance
        .collection(n) // assume already set in your flow
        .doc(s)
        .collection('passenger_account')
        .doc(u)
        .collection('rating_history');
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rating History')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _historyRef()
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text(
                'Failed to load ratings.\n${snap.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final docs = snap.data?.docs ?? const [];
          // Counters
          int star1 = 0, star2 = 0, star3 = 0, star4 = 0, star5 = 0;
          int good = 0, average = 0, bad = 0;

          for (final d in docs) {
            final m = d.data();
            final r = _toDouble(m['rating']).clamp(0.0, 5.0);

            // Star buckets by integer round-down (1..5)
            final intBucket = r.floor().clamp(0, 5);
            switch (intBucket) {
              case 5:
                star5++;
                break;
              case 4:
                star4++;
                break;
              case 3:
                star3++;
                break;
              case 2:
                star2++;
                break;
              case 1:
                star1++;
                break;
              default:
                // ratings <1 or invalid -> treat as 1★ bucket
                if (r > 0) {
                  star1++;
                }
            }

            // Comment status by rating
            if (r >= 4.5) {
              good++;
            } else if (r >= 3.0) {
              average++;
            } else {
              bad++;
            }
          }

          Widget row(String label, String value) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500)),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ],
                ),
              );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Star Breakdown',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      row('5 Star', '$star5'),
                      row('4 Star', '$star4'),
                      row('3 Star', '$star3'),
                      row('2 Star', '$star2'),
                      row('1 Star', '$star1'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // ——— START: Insert here ———
              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                  childrenPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  title: const Text(
                    'Rating Guidance',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  children: const [
                    SizedBox(height: 8),
                    Text(
                      'Dear Valued User,',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'By default, your profile begins with a full 5-star rating. We kindly '
                      'encourage you to maintain this standard as you start your journey with Lucky Go.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Once you receive 100 or more ratings, your default 5-star will be replaced with '
                      'an average rating calculated from those first 100 ratings onward. This means your '
                      'early ratings will shape your long-term profile.',
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please do your best to provide excellent service and aim to keep your 5-star rating '
                      'as you grow with us.',
                    ),
                    SizedBox(height: 8),
                    Text('Thank you for being part of Lucky Go.'),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              Card(
                elevation: 1.5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'User Feedback',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      row('Positive', '0'),
                      row('Negative', '0'),
                      row('Violation', '0'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 60),
              // ——— END: Insert here ———
              if (docs.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text('No rating history yet.'),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
