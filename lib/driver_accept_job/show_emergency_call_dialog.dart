import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/landing%20page/landing_page.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showEmergencyCallDialog(
  BuildContext context, {
  required String eContact1,
  String eContact2 = '',
  String hotline = '999',
  VoidCallback? onSosTriggered, // 👈 Added callback
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: Column(
          children: const [
            Text('Emergency Call'),
            Text(
              'Please note: Our admin team operates during office hours. If an admin is available at night, they will assist both drivers and passengers as best as possible. In case your emergency is not attended to, it may be because all admins are off duty. Kindly allow the police to handle urgent matters during these times.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AlertAdminButton(
              label: 'Alert Admin',
              number: hotline,
              onPressed: () async {
                Navigator.of(ctx, rootNavigator: true).pop();
                await triggerDriverSos('Admin');
                onSosTriggered?.call(); // 👈 Trigger callback after SOS
              },
            ),
            const SizedBox(height: 8),
            _CallButton(
              label: 'Call $hotline',
              number: hotline,
              onPressed: () async {
                await _callAndClose(ctx, hotline);
                await triggerDriverSos('Police');
                onSosTriggered?.call();
              },
            ),
            const SizedBox(height: 8),
            _CallButton(
              label: 'Call Emergency Contact 1 ($eContact1)',
              number: eContact1,
              onPressed: () async {
                await _callAndClose(ctx, eContact1);
                await triggerDriverSos(Gv.emergencyContact1);
                onSosTriggered?.call();
              },
            ),
            const SizedBox(height: 8),
            if (eContact2.trim().isNotEmpty)
              _CallButton(
                label: 'Call Emergency Contact 2 ($eContact2)',
                number: eContact2,
                onPressed: () async {
                  await _callAndClose(ctx, eContact2);
                  await triggerDriverSos(Gv.emergencyContact2);
                  onSosTriggered?.call();
                },
              ),
          ],
        ),
      );
    },
  );
}

class _CallButton extends StatelessWidget {
  final String label;
  final String number;
  final VoidCallback onPressed;

  const _CallButton({
    required this.label,
    required this.number,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.phone),
        label: Text(label),
        onPressed: onPressed,
      ),
    );
  }
}

Future<void> _callAndClose(BuildContext ctx, String raw) async {
  Navigator.of(ctx, rootNavigator: true).pop(); // close the dialog first
  final number = raw.trim();
  final uri = Uri(scheme: 'tel', path: number);

  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text("Couldn't open the phone dialer.")),
    );
  }
}

Future<void> triggerDriverSos(callWho) async {
  final docRef = FirebaseFirestore.instance
      .collection(Gv.negara)
      .doc(Gv.negeri)
      .collection('help_center')
      .doc('SOS')
      .collection('sos_data')
      .doc('${getFormattedDate()}(${Gv.loggedUser})');

  await docRef.set({
    'admin_remark': '',    
    'driver_phone': Gv.loggedUser,
    'driver_is_calling': callWho,
    'driver_name': Gv.userName,
    'passenger_name': Gv.passengerName,
    'passenger_phone': Gv.passengerPhone,
    'sos_solved': false,
    'trigger_by': 'driver',
    'trigger_time': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

class AlertAdminButton extends StatelessWidget {
  final String label;
  final String number;
  final VoidCallback onPressed;

  const AlertAdminButton({
    super.key,
    required this.label,
    required this.number,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.warning_amber_rounded),
        label: Text(label),
        onPressed: onPressed,
      ),
    );
  }
}


// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:luckygo_pemandu/global.dart';
// import 'package:luckygo_pemandu/landing%20page/landing_page.dart';
// import 'package:url_launcher/url_launcher.dart';

// Future<void> showEmergencyCallDialog(
//   BuildContext context, {
//   required String eContact1,
//   String eContact2 = '',
//   String hotline = '999',
// }) {
//   return showDialog<void>(
//     context: context,
//     builder: (ctx) {
//       return AlertDialog(
//         title: Column(
//           children: [
//             const Text('Emergency Call'),
//             const Text(
//               'Please note: Our admin team operates during office hours. If an admin is available at night, they will assist both drivers and passengers as best as possible. In case your emergency is not attended to, it may be because all admins are off duty. Kindly allow the police to handle urgent matters during these times.',
//               style: TextStyle(fontSize: 13, color: Colors.black54),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
// AlertAdminButton(
//   label: 'Alert Admin',
//   number: hotline,
//   onPressed: () {
//     triggerDriverSos('Admin');
//   },
// ),

//             const SizedBox(height: 8),
//             _CallButton(
//               label: 'Call $hotline',
//               number: hotline,
//               onPressed: () {
//                 _callAndClose(ctx, hotline);
//                 triggerDriverSos('Police');
//               },
//             ),
//             const SizedBox(height: 8),
//             _CallButton(
//               label: 'Call Emergency Contact 1 ($eContact1)',
//               number: eContact1,
//               onPressed: () {
//                 _callAndClose(ctx, eContact1);
//                 triggerDriverSos(Gv.emergencyContact1);
//               },
//             ),
//             const SizedBox(height: 8),
//             if (eContact2.trim().isNotEmpty)
//               _CallButton(
//                 label: 'Call Emergency Contact 2 ($eContact2)',
//                 number: eContact2,
//                 onPressed: () {
//                   _callAndClose(ctx, eContact2);
//                   triggerDriverSos(Gv.emergencyContact2);
//                 },
//               ),
//           ],
//         ),
//       );
//     },
//   );
// }

// class _CallButton extends StatelessWidget {
//   final String label;
//   final String number;
//   final VoidCallback onPressed;

//   const _CallButton({
//     required this.label,
//     required this.number,
//     required this.onPressed,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return SizedBox(
//       width: double.infinity,
//       child: ElevatedButton.icon(
//         icon: const Icon(Icons.phone),
//         label: Text(label),
//         onPressed: onPressed,
//       ),
//     );
//   }
// }

// Future<void> _callAndClose(BuildContext ctx, String raw) async {
//   Navigator.of(ctx, rootNavigator: true).pop(); // close the dialog first
//   final number = raw.trim();
//   final uri = Uri(scheme: 'tel', path: number);

//   if (await canLaunchUrl(uri)) {
//     await launchUrl(uri, mode: LaunchMode.externalApplication);
//   } else {
//     // ignore: use_build_context_synchronously
//     ScaffoldMessenger.of(ctx).showSnackBar(
//       const SnackBar(content: Text("Couldn't open the phone dialer.")),
//     );
//   }
// }

// Future<void> triggerDriverSos(callWho) async {
//   final docRef = FirebaseFirestore.instance
//       .collection(Gv.negara)
//       .doc(Gv.negeri)
//       .collection('help_center')
//       .doc('SOS')
//       .collection('sos_data')
//       .doc('${getFormattedDate()}(${Gv.loggedUser})');

//   await docRef.set({
//     'admin_remark': '',
//     'admin_remark_time': null,
//     'name': Gv.userName,
//     'passenger_is_calling': callWho,
//     'phone': Gv.loggedUser,
//     'sos_solved': false,
//     'trigger_by': 'driver',
//     'trigger_time': FieldValue.serverTimestamp(),
//   }, SetOptions(merge: true));
// }



// class AlertAdminButton extends StatelessWidget {
//   final String label;
//   final String number;
//   final VoidCallback onPressed;

//   const AlertAdminButton({
//     super.key,
//     required this.label,
//     required this.number,
//     required this.onPressed,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return ElevatedButton.icon(
//       icon: const Icon(Icons.warning_amber_rounded, color: Colors.white),
//       label: Text(label),
//       style: ElevatedButton.styleFrom(
//         backgroundColor: Colors.redAccent,
//         foregroundColor: Colors.white,
//         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//         textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
//       ),
//       onPressed: onPressed,
//     );
//   }
// }