// lib/tracking/live_share_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/view15/global_variables_for_view15.dart' as Gv;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

class LiveShareService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> createShareDoc({
    required String negara,
    required String negeri,
    required String ownerPhone,
    required double srcLat,
    required double srcLng,
    required double dstLat,
    required double dstLng,                 // ✅ add this
    String? jobId,
    Duration ttl = const Duration(hours: 2),
  }) async {
    final ref = _db.collection(negara).doc(negeri).collection('live_shares').doc();
    final expiresAt = DateTime.now().toUtc().add(ttl);

await ref.set({
  'active': true,
  'owner': ownerPhone,
  'jobId': jobId,
  'srcLat': srcLat,
  'srcLng': srcLng,
  'dstLat': dstLat,
  'dstLng': dstLng,

  // ✅ convert whatever you get to a String and keep digits only
  'passenger_phone': (() {
    final v = Gv.passengerPhone; // if you kept Gv here
    final s = (v is ValueNotifier<String>) ? v.value : v?.toString();
    return (s ?? '').replaceAll(RegExp(r'\D'), '');
  })(),

  'startedAt': FieldValue.serverTimestamp(),
  'expiresAt': Timestamp.fromDate(expiresAt),
});
    return ref.id; // sid
  }

  Uri buildWebTrackingUrl({
    required String webHost,
    required String sid,
    required String negara,
    required String negeri,
  }) {
    return Uri.parse('$webHost/track?sid=$sid&n=$negara&s=$negeri');
  }

  Future<void> shareLinkViaSystemSheet({
    required Uri url,
    String? subject,
    String? extraText,
  }) async {
    final msg = [
      if (extraText != null && extraText.trim().isNotEmpty) extraText.trim(),
      url.toString(),
    ].join('\n');

    try {
      await Share.share(msg, subject: subject);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: msg));
      rethrow;
    }
  }
}


// // lib/tracking/live_share_service.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:share_plus/share_plus.dart';
// import 'package:flutter/services.dart';

// class LiveShareService {
//   final FirebaseFirestore _db = FirebaseFirestore.instance;

//   Future<String> createShareDoc({
//     required String negara,
//     required String negeri,
//     required String ownerPhone,
//     required double srcLat,
//     required double srcLng,
//     required double dstLat,
//     required double dstLng,
//     String? jobId,
//     Duration ttl = const Duration(hours: 2),
//   }) async {
//     final ref = _db.collection(negara).doc(negeri).collection('live_shares').doc();
//     final expiresAt = DateTime.now().toUtc().add(ttl);
//     await ref.set({
//       'active': true,
//       'owner': ownerPhone,
//       'jobId': jobId,
//       'srcLat': srcLat,
//       'srcLng': srcLng,
//       'dstLat': dstLat,
//       'dstLng': dstLng,
//       'startedAt': FieldValue.serverTimestamp(),
//       'expiresAt': Timestamp.fromDate(expiresAt),
//     });
//     return ref.id; // sid
//   }

//   /// Build the plain web URL that your hosted tracking page will open.
//   Uri buildWebTrackingUrl({
//     required String webHost,  // e.g. https://luckygo.app
//     required String sid,
//     required String negara,
//     required String negeri,
//   }) {
//     return Uri.parse('$webHost/track?sid=$sid&n=$negara&s=$negeri');
//   }

//   /// OPEN THE SYSTEM SHARE SHEET (user can pick any app).
//   Future<void> shareLinkViaSystemSheet({
//     required Uri url,
//     String? subject,     // optional (used by email, etc.)
//     String? extraText,   // optional additional message above the link
//   }) async {
//     final msg = [
//       if (extraText != null && extraText.trim().isNotEmpty) extraText.trim(),
//       url.toString(),
//     ].join('\n');

//     try {
//       await Share.share(msg, subject: subject);
//     } catch (e) {
//       // Fallback: copy to clipboard so user can paste anywhere
//       await Clipboard.setData(ClipboardData(text: msg));
//       rethrow;
//     }
//   }
// }
