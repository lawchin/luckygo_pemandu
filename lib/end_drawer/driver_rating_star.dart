import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';

class DriverRatingStars extends StatelessWidget {
  const DriverRatingStars({super.key});

  double _readRating(Map<String, dynamic> m) {
    final v = m['rating'] ?? m['rate'] ?? m['star'] ?? 5;
    if (v is num) return v.toDouble().clamp(0.0, 5.0);
    if (v is String) return double.tryParse(v)?.clamp(0.0, 5.0) ?? 5.0;
    return 5.0;
    // ↑ Change the field name(s) above if your docs use something else.
  }

  List<Widget> _buildStars(double value, {double size = 22}) {
    final List<Widget> stars = [];
    for (int i = 1; i <= 5; i++) {
      IconData icon;
      if (value >= i) {
        icon = Icons.star;
      } else if (value >= i - 0.5) {
        icon = Icons.star_half;
      } else {
        icon = Icons.star_border;
      }
      stars.add(Icon(icon, color: Colors.amber.withOpacity(0.85), size: size));
    }
    return stars;
  }

  @override
  Widget build(BuildContext context) {
    final n = Gv.negara;
    final s = Gv.negeri;
    final u = Gv.loggedUser;

    if (n == null || s == null || n.isEmpty || s.isEmpty || u == null || u.isEmpty) {
      // Fallback UI if IDs are missing
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: List.generate(5, (_) =>
              Icon(Icons.star, color: Colors.amber.withOpacity(0.85), size: 22))),
          const Text(
            '(not enough data)',
            style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500, height: 0.8),
          ),
          const SizedBox(height: 6),
        ],
      );
    }

    final fut = FirebaseFirestore.instance
        .collection(n)
        .doc(s)
        .collection('driver_account')
        .doc(u)
        .collection('rating_history')
        .get();

    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: fut,
      builder: (context, snap) {
        // Defaults
        double avg = 5.0;
        String label = '(5.00)';
        bool useComputed = false;

        if (snap.hasData) {
          final docs = snap.data!.docs;
          final count = docs.length;

          if (count >= 100) {
            double sum = 0;
            for (final d in docs) {
              sum += _readRating(d.data());
            }
            avg = (sum / count).clamp(0.0, 5.0);
            // Round to 2 decimals for display (like 4.99)
            label = '(${avg.toStringAsFixed(2)})';
            useComputed = true;
          } else {
            // < 100 → not enough data (keep default 5 stars)
            label = '(not enough data)';
            avg = 5.0;
          }
        } else if (snap.hasError) {
          // On error, fail soft: show default stars and “not enough data”
          label = '(not enough data)';
          avg = 5.0;
        } else {
          // While loading: show default stars & 5.00
          avg = 5.0;
          label = '(5.00)';
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: useComputed
                  ? _buildStars(avg)
                  : List.generate(5, (_) => Icon(
                        Icons.star,
                        color: Colors.amber.withOpacity(0.85),
                        size: 22,
                      )),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
                height: 0.8,
              ),
            ),
            const SizedBox(height: 6),
          ],
        );
      },
    );
  }
}
