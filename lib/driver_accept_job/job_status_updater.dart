// // lib/services/job_status_updater.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/foundation.dart';
// import '../global.dart'; // adjust path so Gv is available

// const kStatusPaymentReceived = 'payment_received';

// Future<void> updatePaymentReceivedStatus() async {
//   await _updateMyActiveJobStatus(kStatusPaymentReceived);
// }

// Future<void> _updateMyActiveJobStatus(String status) async {
//   final fs = FirebaseFirestore.instance;

//   final myActiveJobRef = fs
//       .collection(Gv.negara).doc(Gv.negeri)
//       .collection('passenger_account').doc(Gv.passengerPhone)
//       .collection('my_active_job').doc(Gv.passengerPhone);

//   debugPrint('[order_status] Path => /${Gv.negara}/${Gv.negeri}/passenger_account/${Gv.passengerPhone}/my_active_job/${Gv.passengerPhone}');

//   try {
//     await myActiveJobRef.update({
//       'order_status': status,
//       'updated_at': FieldValue.serverTimestamp(),
//     });
//   } catch (e) {
//     // fallback if doc missing
//     await myActiveJobRef.set({
//       'order_status': status,
//       'updated_at': FieldValue.serverTimestamp(),
//     }, SetOptions(merge: true));
//   }

//   final afterSnap = await myActiveJobRef.get(const GetOptions(source: Source.server));
//   debugPrint('[order_status] AFTER (server) -> status=${afterSnap.data()?['order_status']}');
// }


