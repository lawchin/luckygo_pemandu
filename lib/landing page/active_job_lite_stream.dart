// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:luckygo_pemandu/gen_l10n/app_localizations.dart';
// import 'package:luckygo_pemandu/global.dart';
// import 'package:luckygo_pemandu/landing%20page/bull_shit.dart';
// import 'package:luckygo_pemandu/landing%20page/presenter_page.dart';

// class ActiveJobLiteStream extends StatefulWidget {
//   const ActiveJobLiteStream({super.key});

//   @override
//   State<ActiveJobLiteStream> createState() => _ActiveJobLiteStreamState();
// }

// class _ActiveJobLiteStreamState extends State<ActiveJobLiteStream> {
//   bool checkingDriverGps = true;

//   Future<void> FetchGroupCapability() async {
//     await FirebaseFirestore.instance
//       .collection(Gv.negara)
//       .doc(Gv.negeri)
//       .collection('driver_account')
//       .doc(Gv.loggedUser)
//       .get()
//       .then((doc) {
//         if (doc.exists) {
//           Gv.groupCapability = (doc.data()?['group_capability'] as int?) ?? 0;
//         }
//       });
//   }


//   @override
//   void initState() {
//     super.initState();
//     FetchGroupCapability();
//   }



//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<DocumentSnapshot>(
//       stream: FirebaseFirestore.instance
//           .collection(Gv.negara)
//           .doc(Gv.negeri)
//           .collection('active_job')
//           .doc('active_job_lite')
//           .snapshots(), // <-- live updates

//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }

//         if (!snapshot.hasData || !snapshot.data!.exists) {
//           return const Center(child: Text('No data found'));
//         }

//         final data = snapshot.data!.data() as Map<String, dynamic>;

//     final t = AppLocalizations.of(context)!;
//     final regionLabel = (Gv.negara.isNotEmpty && Gv.negeri.isNotEmpty)
//         ? '${Gv.negara} • ${Gv.negeri}'
//         : 'Region not set';

//     return Scaffold(

//       body: Stack(
//         children: [

//           Container(
//             width: double.infinity,
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [Color(0xFF107572), Color(0xFFCDE989)],
//                 begin: Alignment.topLeft,
//                 end: Alignment.bottomRight,
//               ),
//             ),
//             child: Column(
//               children: [
//                 Expanded(
//                   flex: 6, // 🔼 Top 60%
//                   child: ValueListenableBuilder<bool>(
//                     valueListenable: Gv.showPresenter,
//                     builder: (context, isVisible, _) {
//                       return isVisible
//                           ? SizedBox.shrink()
//                           : const PresenterPage();
//                     },
//                   ),
//                 ),
//                 Expanded(
//                   flex: 4,
//                   child: Column(
//                     children: [
//                       const SizedBox(height: 24),
//                       ElevatedButton.icon(
//                       icon: const Icon(Icons.work_outline),
//                       label: const Text('View Active Jobs'),
//                       style: ElevatedButton.styleFrom(
//                         minimumSize: const Size.fromHeight(48),
//                       ),
//                       onPressed: () {
//                         Navigator.of(context).push(
//                         MaterialPageRoute(
//                           // builder: (_) => DistanceFilterPage(),
//                           builder: (_) => BullShit(),
//                         ),
//                         );
//                       },
//                       ),
//                     ],  
//                   ),
//                 ),
//               ],
//             ),
//           ),
          
//           if (checkingDriverGps)
//             Positioned.fill(
//               child: AbsorbPointer(
//                 absorbing: true,
//                 child: Container(
//                   color: Colors.black.withOpacity(0.3),
//                   child: const Center(
//                     child: Column(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         CircularProgressIndicator(),
//                         SizedBox(height: 16),
//                         Text(
//                           "Fetching driver GPS to match jobs distance",
//                           textAlign: TextAlign.center,
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 16,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ),
//             ),

       
//         ],
//       ),

//     );
//       },
//     );
//   }
// }
