import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/global.dart';

class AutoButton extends StatelessWidget {
  const AutoButton({super.key});

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('driver_account')
        .doc(Gv.loggedUser);

    return StreamBuilder<DocumentSnapshot>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('Loading AutoButton…');
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;

        if (data == null || !data.containsKey('job_auto')) {
          return const Text('Missing job_auto');
        }

        final isAutoOn = data['job_auto'] == true;

        return ElevatedButton(
          onPressed: () async {
            try {
              await docRef.update({'job_auto': !isAutoOn});
            } catch (e) {
              debugPrint('Failed to toggle job_auto: $e');
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isAutoOn ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          child: Text(
            isAutoOn ? 'Auto On' : 'Auto Off',
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }
}
