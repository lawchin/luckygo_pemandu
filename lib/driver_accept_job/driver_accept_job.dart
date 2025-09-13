import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:luckygo_pemandu/driver_accept_job/receipt_page.dart';
import 'package:luckygo_pemandu/driver_accept_job/show_emergency_call_dialog.dart';
import 'package:luckygo_pemandu/driver_accept_job/tell_others.dart';
import 'package:luckygo_pemandu/driver_accept_job/view_receipt.dart';
import 'package:luckygo_pemandu/driver_location_service.dart';
import 'package:luckygo_pemandu/gen_l10n/app_localizations.dart';
import 'package:luckygo_pemandu/geo_fencing/geofencing_controller.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/jobFilter/filter_job_one_stream.dart';
import 'package:luckygo_pemandu/landing%20page/landing_page.dart';
import 'package:luckygo_pemandu/live_share_service/share_ride_button.dart';
import 'package:url_launcher/url_launcher.dart';


String getNiceDate() {
  final now = DateTime.now();
  final day = now.day;
  final month = _monthName(now.month);
  final year = now.year;
  final hour = now.hour > 12 ? now.hour - 12 : now.hour == 0 ? 12 : now.hour;
  final minute = now.minute.toString().padLeft(2, '0');
  final period = now.hour >= 12 ? 'pm' : 'am';
  return '$day $month $year - $hour:$minute $period';
}

String _monthName(int month) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return months[month - 1];
}

class DAJ extends StatefulWidget {
  const DAJ({super.key});

  @override
  State<DAJ> createState() => _DAJState();
}

class _DAJState extends State<DAJ> {
  static const String _TAG = '[DAJ]';

  bool _paymentDone = false; // marks that "Payment Received" was pressed













































void _showRouteOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (BuildContext ctx) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.directions_car),
              label: const Text('Driver - Pickup'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F69FE),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _d('Driver - Pickup tapped');
                _openDriverToPickupInGoogleMaps(context);
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.location_on),
              label: const Text('Pickup - Destination'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2F69FE),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                _d('Pickup - Destination tapped');
                _openPickupToDestinationInGoogleMaps(context);
              },
            ),
          ],
        ),
      );
    },
  );
}



void _openPickupToDestinationInGoogleMaps(BuildContext context) {
  // Replace these with your actual coordinates or logic
  final pickupLatLng = LatLng(Gv.passengerGp.latitude, Gv.passengerGp.longitude);
  final destinationLatLng = LatLng(Gv.destinationGp.latitude, Gv.destinationGp.longitude);

  final url = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&origin=${pickupLatLng.latitude},${pickupLatLng.longitude}'
    '&destination=${destinationLatLng.latitude},${destinationLatLng.longitude}'
    '&travelmode=driving',
  );

  launchUrl(url, mode: LaunchMode.externalApplication);
}


























































  @override
  void initState() {
    super.initState();
    // While DAJ is visible, IGNORE geofencing everywhere else.
    GeofencingController.instance.enableBypass();
  }

  @override
  void dispose() {
    // If user leaves DAJ without pressing Payment, restore geofencing.
    if (!_paymentDone) {
      GeofencingController.instance.disableBypass();
    }
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    // Supports either String or ValueNotifier<String> in your Gv
    final String phone = Gv.passengerPhone is String
        ? (Gv.passengerPhone as String)
        : (Gv.passengerPhone as dynamic).value as String;

    final docRef = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('passenger_account')
        .doc(phone)
        .collection('my_active_job')
        .doc(phone);

        //  IF DATA EXIST grandTotal = data['total_price']

    return PopScope(
      canPop: false, // ⛔ Block device back + swipe back on this page
      onPopInvoked: (didPop) {
        if (!didPop) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.clearSnackBars();
          messenger.showSnackBar(
            const SnackBar(
              duration: Duration(milliseconds: 900),
              content: Text('Back is disabled on this page'),
            ),
          );
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            const Expanded(flex: 54, child: SizedBox.shrink()),

            // Bottom 40% — live job card
            Expanded(
              flex: 46,
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: docRef.snapshots(),
                builder: (context, snap) {
                  final loc = AppLocalizations.of(context)!;
                  if (snap.connectionState == ConnectionState.waiting) {
                    _d('Stream waiting… phone=$phone');
                    return const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    _d('Stream error: ${snap.error}');
                    return _paddedCard(
                      child: const Center(
                        child: Text('Failed to load job data', style: TextStyle(color: Colors.red)),
                      ),
                    );
                  }

                  // if (!snap.hasData || !snap.data!.exists) {
                  //   _d('No active job doc for $phone → schedule redirect to FilterJobsOneStream');
                  //   Future.delayed(const Duration(milliseconds: 3000), () {
                  //     if (context.mounted) {
                  //       Navigator.of(context).pushReplacement(
                  //         MaterialPageRoute(builder: (_) => const FilterJobsOneStream()),
                  //       );
                  //     }
                  //   });

                  //   return _paddedCard(
                  //     child: Center(
                  //       child: Text(
                  //         loc.noJob,
                  //       ),
                  //     ),
                  //   );
                  // }


if (!snap.hasData || !snap.data!.exists) {
  _d('No active job doc for $phone → redirect in 3s');

  WidgetsBinding.instance.addPostFrameCallback((_) {
    Future.delayed(const Duration(seconds: 3), () async{
      if (!mounted) return;

      await FirebaseFirestore.instance
          .collection(Gv.negara)
          .doc(Gv.negeri)
          .collection('driver_account')
          .doc(Gv.loggedUser)
          .update({
        'job_auto': false,
        'driver_is_on_a_job': false,
        'current_job_id': '',
        'current_job_at': '',
      });


      Navigator.of(context, rootNavigator: true).pushReplacement(
        MaterialPageRoute(builder: (_) => const FilterJobsOneStream()),
      );
    });
  });

  return _paddedCard(
    child: Center(
      child: Column(
        children: [
          Text(loc.noJob),
            const SizedBox(height: 16),
            ElevatedButton(
            onPressed: () async{

              await FirebaseFirestore.instance
                  .collection(Gv.negara)
                  .doc(Gv.negeri)
                  .collection('driver_account')
                  .doc(Gv.loggedUser)
                  .update({
                'job_auto': false,
                'driver_is_on_a_job': false,
                'current_job_id': '',
                'current_job_at': '',
              });

              Navigator.of(context, rootNavigator: true).pushReplacement(
              MaterialPageRoute(builder: (_) => const FilterJobsOneStream()),
              );
            },
            child: const Text('Close'),
            ),
        ],
      ),
    ),
  );
}



                  final data = snap.data!.data() ?? {};
                  // ✅ Fill your globals for map usage
                  Gv.passengerGp = data['z_source'] is GeoPoint
                      ? data['z_source'] as GeoPoint
                      : const GeoPoint(0.0, 0.0);

                  Gv.destinationCount = (data['total_destination'] as int?) ?? 0;

                  Gv.driverGp = data['x_driver_geopoint'] is GeoPoint
                      ? data['x_driver_geopoint'] as GeoPoint
                      : const GeoPoint(0.0, 0.0);

                  Gv.passengerGp = data['z_source'] is GeoPoint
                      ? data['z_source'] as GeoPoint
                      : const GeoPoint(0.0, 0.0);

                  if (Gv.destinationCount == 1){
                    Gv.destinationGp = data['z_d01'] is GeoPoint
                        ? data['z_d01'] as GeoPoint
                        : const GeoPoint(0.0, 0.0);
                  } else if (Gv.destinationCount == 2){
                    Gv.destinationGp = data['z_d02'] is GeoPoint
                        ? data['z_d02'] as GeoPoint
                        : const GeoPoint(0.0, 0.0);
                  } else if (Gv.destinationCount == 3){
                    Gv.destinationGp = data['z_d03'] is GeoPoint
                        ? data['z_d03'] as GeoPoint
                        : const GeoPoint(0.0, 0.0);
                  } else if (Gv.destinationCount == 4){
                    Gv.destinationGp = data['z_d04'] is GeoPoint
                        ? data['z_d04'] as GeoPoint
                        : const GeoPoint(0.0, 0.0);
                  } else if (Gv.destinationCount == 5){
                    Gv.destinationGp = data['z_d05'] is GeoPoint
                        ? data['z_d05'] as GeoPoint
                        : const GeoPoint(0.0, 0.0);
                  } else if (Gv.destinationCount == 6){
                    Gv.destinationGp = data['z_d06'] is GeoPoint
                        ? data['z_d06'] as GeoPoint
                        : const GeoPoint(0.0, 0.0);
                  } else {
                    Gv.destinationGp = const GeoPoint(0.0, 0.0);
                  }

                  _d('Updated globals from Firestore: '
                      'driver=(${Gv.driverGp.latitude}, ${Gv.driverGp.longitude}), '
                      'pickup=(${Gv.passengerGp.latitude}, ${Gv.passengerGp.longitude})');

                  final selfie = (data['y_passenger_selfie'] as String?) ?? '';
                  final pPhone = (data['job_created_by'] as String?) ?? '';
                  final pName = (data['job_creator_name'] as String?) ?? pPhone;
                  final total = (data['total_price'] as num?)?.toDouble() ?? 0.0;
                  final tips1 = (data['tips_amount1'] as num?)?.toDouble() ?? 0.0;
                  final tips2 = (data['tips_amount2'] as num?)?.toDouble() ?? 0.0;
                  final orderStatus = (data['order_status'] as String?) ?? '';

                  Gv.passengerName = (data['job_creator_name'] as String?) ?? pPhone;
                  Gv.passengerPhone = (data['job_created_by'] as String?) ?? '';
                  Gv.grandTotal = (data['total_price'] as num?)?.toDouble() ?? 0.0;
                  Gv.driverSelfie = (data['y_driver_selfie'] as String?) ?? '';
                  Gv.passengerSelfie = (data['y_passenger_selfie'] as String?) ?? '';



                  return _paddedCard(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row
                          SizedBox(
                            height: 50,
                            child: Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              color: const Color(0xFFE9F8EF),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                child: Row(
                                  children: [

                                    GestureDetector(// PRICE DETAILS
                                      onTap: () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) => const ViewReceipt(),
                                          ),
                                        );
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.summarize, color: Colors.blue, size: 32),
                                        ],
                                      ),
                                    ),
                                  
                                    const Spacer(),




                                    IconButton(// SOS
                                      icon: const Icon(Icons.sos, color: Colors.red, size: 32),
                                      onPressed: () {


                                      showEmergencyCallDialog(
                                        context,
                                        eContact1: Gv.emergencyContact1,
                                        eContact2: Gv.emergencyContact2,
                                        hotline: '999',
                                        onSosTriggered: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Admin has been alerted. If this is during office hours, our team will respond promptly. For after-hours or late-night emergencies, response times may vary, but your safety is our priority.'
                                              ),
                                              backgroundColor: Colors.red,
                                              duration: Duration(seconds: 10),
                                            ),
                                          );
                                        },
                                      );
                                   
                                      
                                      
                                      },



),


                                    
                                    SizedBox(width:20),

                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.black87, width: 1),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                                      ),
                                      onPressed: () {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: const Text('Action'),
                                              content: SizedBox(
                                                width: double.maxFinite,
                                                child: Column(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    ShareRideButton(),                                                    
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        Navigator.of(context).push(
                                                          PageRouteBuilder(
                                                            opaque: false,
                                                            barrierDismissible: true,
                                                            pageBuilder: (_, __, ___) => TellOthers(),
                                                            transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
                                                          ),
                                                        );
                                                      }, 
                                                      child: SizedBox(
                                                        width:140,
                                                        child: const Row(
                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: const [
                                                            Icon(
                                                              Icons.share,
                                                              color: Colors.blue,
                                                            ),
                                                            SizedBox(width: 8), // spacing between icon and text
                                                            Text(
                                                              'Destination',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                fontWeight: FontWeight.w600,
                                                                color: Colors.blue,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),

                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        showDialog(
                                                          context: context,
                                                          builder: (context) {
                                                            String? selectedReason;
                                                            TextEditingController optionalController = TextEditingController();

                                                            return StatefulBuilder(
                                                              builder: (context, setState) {
                                                                return Dialog(
                                                                  insetPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 24),
                                                                  child: Container(
                                                                    width: double.infinity,
                                                                    padding: const EdgeInsets.all(20),
                                                                    child: SingleChildScrollView(
                                                                      child: Column(
                                                                        mainAxisSize: MainAxisSize.min,
                                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                                        children: [
                                                                          const Text(
                                                                            'End Trip',
                                                                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                                                          ),
                                                                          const SizedBox(height: 16),
                                                                          DropdownButtonFormField<String>(
                                                                            decoration: const InputDecoration(
                                                                              labelText: 'End Trip Reason',
                                                                              border: OutlineInputBorder(),
                                                                            ),
                                                                            value: selectedReason,
                                                                            isExpanded: true,
                                                                            hint: const Text('Select reason'),
                                                                            items: [
                                                                              'Passenger not paying',
                                                                              'Passenger request to end trip',
                                                                              'Quarrel',
                                                                              'Passenger family emergency',
                                                                              'Driver family emergency',
                                                                            ].map((reason) {
                                                                              return DropdownMenuItem(
                                                                                value: reason,
                                                                                child: Text(reason),
                                                                              );
                                                                            }).toList(),
                                                                            onChanged: (value) {
                                                                              setState(() {
                                                                                selectedReason = value;
                                                                              });
                                                                            },
                                                                          ),
                                                                          const SizedBox(height: 12),
                                                                          TextField(
                                                                            controller: optionalController,
                                                                            decoration: const InputDecoration(
                                                                              labelText: 'Additional Notes (Optional)',
                                                                              border: OutlineInputBorder(),
                                                                            ),
                                                                            maxLines: 2,
                                                                          ),
                                                                          const SizedBox(height: 20),
                                                                          Row(
                                                                            mainAxisAlignment: MainAxisAlignment.end,
                                                                            children: [
                                                                              TextButton(
                                                                                onPressed: () => Navigator.pop(context),
                                                                                child: const Text('Close'),
                                                                              ),
                                                                              const SizedBox(width: 8),
                                                    ElevatedButton(
                                                      onPressed: () async {
                                                        final finalReason = selectedReason ?? '';
                                                        final extraNotes = optionalController.text;

                                                        final FirebaseFirestore firestore = FirebaseFirestore.instance;

                                                        final passengerActiveJobRef = firestore
                                                          .collection(Gv.negara)
                                                          .doc(Gv.negeri)
                                                          .collection('passenger_account')
                                                          .doc(Gv.passengerPhone)
                                                          .collection('my_active_job')
                                                          .doc(Gv.passengerPhone);

                                                        final formattedDate = getFormattedDate(); // e.g. '2025-09-04'

                                                        final passengerHistoryRef = firestore
                                                          .collection(Gv.negara)
                                                          .doc(Gv.negeri)
                                                          .collection('passenger_account')
                                                          .doc(Gv.passengerPhone)
                                                          .collection('ride_history')
                                                          .doc('$formattedDate(${Gv.passengerPhone})');

                                                        final driverHistoryRef = firestore
                                                          .collection(Gv.negara)
                                                          .doc(Gv.negeri)
                                                          .collection('driver_account')
                                                          .doc(Gv.loggedUser)
                                                          .collection('job_history')
                                                          .doc('$formattedDate(${Gv.loggedUser})');

                                                        final driverAccRef = firestore
                                                          .collection(Gv.negara)
                                                          .doc(Gv.negeri)
                                                          .collection('driver_account')
                                                          .doc(Gv.loggedUser);

                                                        try {
                                                          // Step 1: Update order status
                                                          await passengerActiveJobRef.update({
                                                            'order_status': '$finalReason\n$extraNotes',
                                                          });

                                                          //HELP ME UPDATE WHERE ON PASSENGER ride_history WE ONLY UPDATE THE ORDER STATUS USING $finalReason only
                                                          // in driver job_history then we show $finalReason\n$extraNotes

                                                          // Step 2: Read full active job data
                                                          final activeJobSnapshot = await passengerActiveJobRef.get();
                                                          final jobData = activeJobSnapshot.data();

                                                          if (jobData != null) {
                                                            // Step 3: Write to passenger ride history
                                                            await passengerHistoryRef.set(jobData);

                                                            // Step 4: Write to driver job history
                                                            await driverHistoryRef.set(jobData);

                                                            await driverAccRef.update({
                                                              'driver_is_on_a_job': false,
                                                              'current_job_id': ''  ,
                                                              'current_job_at': '',
                                                            });
                                                          }

                                                          // Step 5: Delete active job
                                                          await passengerActiveJobRef.delete();

                                                          Navigator.pop(context);
                                                          Navigator.of(context).pushAndRemoveUntil(
                                                            MaterialPageRoute(builder: (_) => const LandingPage()),
                                                            (route) => false,
                                                          );
                                                        } catch (e) {
                                                          // Handle error (e.g. show a snackbar or log)
                                                          print('Error ending trip: $e');
                                                        }
                                                      },
                                                      child: const Text('Submit'),
                                                    ),
                                                                            ],
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                            );
                                                          },
                                                        );
                                                      },
                                                      child: SizedBox(
                                                        width: 140,
                                                        child: Center(
                                                          child: const Text('End Trip'),
                                                        ),
                                                      ),
                                                    ),
                                                    ElevatedButton(// blank
                                                      onPressed: () {}, 
                                                      child: SizedBox(
                                                        width: 140,
                                                        child: Center(
                                                          child: const 
                                                          Text(
                                                            '',
                                                          ),
                                                        ),
                                                      )
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.of(context).pop(),
                                                      child: const Text('Close'),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                      child: const Text(
                                        'Action',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                          height: 1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              CircleAvatar(
                                radius: 34,
                                backgroundColor: const Color(0xFFEFF1F6),
                                backgroundImage: (selfie.isNotEmpty) ? NetworkImage(selfie) : null,
                                child: (selfie.isEmpty)
                                    ? const Icon(Icons.person, color: Colors.grey, size: 28)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      pName.isEmpty ? '—' : pName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      pPhone.isEmpty ? '—' : pPhone,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    Gv.currency,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1982E3),
                                      height: 0.2,
                                    ),
                                  ),
                                  Text(
                                    total.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1982E3),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // Middle row: map icon + Chat + Call
                          Row(
                            children: [
                              _squareIconButton(
                                context,
                                icon: Icons.map_rounded,
                                color: const Color(0xFF2F69FE),
                                onTap: () {
                                  _d('Map button tapped');
                                  // _openDriverToPickupInGoogleMaps(context);
                                  _showRouteOptions(context);
                                },
                              ),
                              const SizedBox(width: 10),
                              _pillButton(
                                context,
                                icon: Icons.chat_bubble_rounded,
                                label: 'Chat',
                                color: const Color(0xFF22A447),
                                onTap: () {
                                  _d('Chat button tapped → $pPhone');
                                  _openWhatsApp(
                                    context,
                                    pPhone,
                                    prefill: 'Hello ${pName.isEmpty ? 'there' : pName}',
                                  );
                                },
                              ),
                              const SizedBox(width: 10),
                              _pillButton(
                                context,
                                icon: Icons.phone,
                                label: 'Call',
                                color: const Color(0xFF22A447),
                                onTap: () {
                                  _d('Call button tapped → $pPhone');
                                  _callNumber(context, pPhone);
                                },
                              ),
                            ],
                          ),

                          const SizedBox(height: 4),

                          // Tips (conditionally shown)
                          if (tips1 > 0 || tips2 > 0) ...[
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (tips1 > 0) _chip('Tips 1: ${Gv.currency} ${tips1.toStringAsFixed(2)}'),
                                if (tips2 > 0) _chip('Tips 2: ${Gv.currency} ${tips2.toStringAsFixed(2)}'),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          const Spacer(),
                          const Center(
                            child: Text(
                              "Press Go button if you're ready",
                              style: TextStyle(fontSize: 16, color: Colors.grey),
                            ),
                          ),
                          const Spacer(),
                          _primaryActionForStatus(context, orderStatus,
                              onPaymentFinished: () {
                            // child tells parent payment is done → don't re-enable bypass in dispose
                            _paymentDone = true;
                          }),
                        ],
                      ),
                    ),
                  );



                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- small UI helpers ----------
  static void _d(String msg) => debugPrint('$_TAG $msg');

  Widget _paddedCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: child,
      ),
    );
  }

  Widget _squareIconButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Ink(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color.withOpacity(.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }

  Widget _pillButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      decoration: BoxDecoration(
        color: const Color(0xFF22A447).withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF22A447).withOpacity(.35)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF0A7A33),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  bool _validGeo(GeoPoint gp) {
    final ok = !(gp.latitude == 0.0 && gp.longitude == 0.0) &&
        gp.latitude >= -90 && gp.latitude <= 90 &&
        gp.longitude >= -180 && gp.longitude <= 180;
    _d('Validate GeoPoint (${gp.latitude}, ${gp.longitude}) -> $ok');
    return ok;
  }

  // Keep digits and '+' (dialer understands +6011..., etc.)
  String _normalizePhone(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9\+]'), '');
  }

  // Chat (WhatsApp)
  Future<void> _openWhatsApp(BuildContext context, String rawPhone, {String? prefill}) async {
    final phone = _normalizePhone(rawPhone);
    _d('Open WhatsApp: raw="$rawPhone" normalized="$phone" prefill="$prefill"');
    if (phone.isEmpty) {
      _snack(context, 'No passenger phone number');
      return;
    }

    final text = Uri.encodeComponent(prefill ?? '');
    final uriApp = Uri.parse('whatsapp://send?phone=$phone&text=$text');
    final uriWeb = Uri.parse('https://wa.me/$phone?text=$text');

    try {
      final canApp = await canLaunchUrl(uriApp);
      _d('canLaunchUrl(app)=$canApp');
      if (canApp) {
        final ok = await launchUrl(uriApp, mode: LaunchMode.externalApplication);
        _d('launchUrl(app)=$ok');
      } else {
        final ok = await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
        _d('launchUrl(web)=$ok');
      }
    } catch (e) {
      _d('WhatsApp open failed: $e');
      _snack(context, 'Unable to open WhatsApp: $e');
    }
  }

  // CALL button – opens device dialer
  Future<void> _callNumber(BuildContext context, String rawPhone) async {
    final phone = _normalizePhone(rawPhone);
    _d('Open dialer: raw="$rawPhone" normalized="$phone"');
    if (phone.isEmpty) {
      _snack(context, 'No passenger phone number');
      return;
    }
    final telUri = Uri.parse('tel:$phone');
    try {
      final ok = await launchUrl(telUri, mode: LaunchMode.externalApplication);
      _d('launchUrl(tel)=$ok');
      if (!ok) _snack(context, 'Unable to start call');
    } catch (e) {
      _d('Dialer failed: $e');
      _snack(context, 'Unable to start call: $e');
    }
  }

  /// Opens Google Maps with turn-by-turn route (polylines) DRIVER → PICKUP.
  Future<void> _openDriverToPickupInGoogleMaps(BuildContext context) async {
    final driver = Gv.driverGp;
    final pickup = Gv.passengerGp;

    _d('Launch Maps DRIVER→PICKUP with globals: '
        'driver=(${driver.latitude}, ${driver.longitude}), '
        'pickup=(${pickup.latitude}, ${pickup.longitude})');

    if (!_validGeo(driver) || !_validGeo(pickup)) {
      _snack(context, 'Missing driver/pickup location for map directions');
      return;
    }

    // Prefer Google Maps app scheme if available; fallback to universal https
    final uriApp = Uri.parse(
      'comgooglemaps://?saddr=${driver.latitude},${driver.longitude}'
      '&daddr=${pickup.latitude},${pickup.longitude}'
      '&directionsmode=driving',
    );
    final uriWeb = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${driver.latitude},${driver.longitude}'
      '&destination=${pickup.latitude},${pickup.longitude}'
      '&travelmode=driving',
    );

    try {
      final canApp = await canLaunchUrl(uriApp);
      _d('canLaunchUrl(app)=$canApp uri="$uriApp"');
      if (canApp) {
        final ok = await launchUrl(uriApp, mode: LaunchMode.externalApplication);
        _d('launchUrl(app)=$ok');
        if (!ok) _snack(context, 'Could not open Google Maps app');
      } else {
        final ok = await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
        _d('launchUrl(web)=$ok uri="$uriWeb"');
        if (!ok) _snack(context, 'Could not open Google Maps');
      }
    } catch (e) {
      _d('Maps open failed: $e');
      _snack(context, 'Unable to open Google Maps: $e');
    }
  }

  void _snack(BuildContext context, String msg) {
    _d('SNACKBAR: $msg');
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(msg)));
  }
}



Widget _primaryActionButton({
  required BuildContext context,
  required String label,
  required VoidCallback? onPressed, // null = disabled
}) {
  return SizedBox(
    width: MediaQuery.of(context).size.width - 20,
    height: 80,
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        backgroundColor: const Color(0xFF1982E3),
        foregroundColor: Colors.white,
        elevation: 3,
      ),
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
  );
}

// Added onPaymentFinished to notify parent so DAJ won't re-enable bypass in dispose
Widget _primaryActionForStatus(
  BuildContext context,
  String? rawStatus, {
  VoidCallback? onPaymentFinished,
}) {
  final status = (rawStatus ?? '').trim().toLowerCase();

  switch (status) {
    case 'driver_accepted_job':
      return _primaryActionButton(
        context: context,
        label: 'Go',
        onPressed: () {
          FirebaseFirestore.instance
              .collection(Gv.negara).doc(Gv.negeri)
              .collection('passenger_account').doc(Gv.passengerPhone)
              .collection('my_active_job').doc(Gv.passengerPhone)
              .update({'order_status': 'driver_coming'});
        },
      );

    case 'driver_coming':
      return const _DelayedArrivedButton();

    case 'arrived':
      return const SizedBox.shrink();

    case 'passenger_otw':
      return _primaryActionButton(
        context: context,
        label: 'Start Destination',
        onPressed: () {
          FirebaseFirestore.instance
              .collection(Gv.negara).doc(Gv.negeri)
              .collection('passenger_account').doc(Gv.passengerPhone)
              .collection('my_active_job').doc(Gv.passengerPhone)
              .update({'order_status': 'start_destination'});
        },
      );

    case 'start_destination':
      return const _DelayedJobCompleteButton();

    case 'job_completed':
      return _DelayedPaymentReceivedButton(onPaymentFinished: onPaymentFinished);

    case 'payment_received':
      return const SizedBox.shrink();
      // After payment received, navigate to ReceiptPage
      // return _primaryActionButton(
      //   context: context,
      //   label: 'View Receipt',
      //   onPressed: () {
      //     Navigator.of(context).push(
      //   MaterialPageRoute(builder: (_) => const ReceiptPage()),
      //     );
      //   },
      // );

    default:
      return const SizedBox.shrink();
  }
}

class _DelayedArrivedButton extends StatefulWidget {
  const _DelayedArrivedButton();

  @override
  State<_DelayedArrivedButton> createState() => _DelayedArrivedButtonState();
}

class _DelayedArrivedButtonState extends State<_DelayedArrivedButton> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _enabled = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _primaryActionButton(
      context: context,
      label: 'Arrived',
      onPressed: _enabled
          ? () {
              FirebaseFirestore.instance
                  .collection(Gv.negara).doc(Gv.negeri)
                  .collection('passenger_account').doc(Gv.passengerPhone)
                  .collection('my_active_job').doc(Gv.passengerPhone)
                  .update({'order_status': 'driver_arrived'});
            }
          : null,
    );
  }
}

class _DelayedJobCompleteButton extends StatefulWidget {
  const _DelayedJobCompleteButton();

  @override
  State<_DelayedJobCompleteButton> createState() => _DelayedJobCompleteButtonState();
}

class _DelayedJobCompleteButtonState extends State<_DelayedJobCompleteButton> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _enabled = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _primaryActionButton(
      context: context,
      label: 'Job Complete',
      onPressed: _enabled
          ? () async {
            DriverLocationService.instance.unbindPassengerJob();
            await FirebaseFirestore.instance
                .collection(Gv.negara).doc(Gv.negeri)
                .collection('passenger_account').doc(Gv.passengerPhone)
                .collection('my_active_job').doc(Gv.passengerPhone)
                .update({
              'job_is_completed': true,
              'order_status': 'job_completed',
            });
            }
          : null,
    );
  }
}

class _DelayedPaymentReceivedButton extends StatefulWidget {
  const _DelayedPaymentReceivedButton({this.onPaymentFinished});

  final VoidCallback? onPaymentFinished;

  @override
  State<_DelayedPaymentReceivedButton> createState() => _DelayedPaymentReceivedButtonState();
}

class _DelayedPaymentReceivedButtonState extends State<_DelayedPaymentReceivedButton> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _enabled = true);
    });
  }







Future<void> handlePaymentReceived() async {
  const kStatusPaymentReceived = 'payment_received';

  final fs = FirebaseFirestore.instance;

  // ---- Refs ----
  final myActiveJobRef = fs
      .collection(Gv.negara).doc(Gv.negeri)
      .collection('passenger_account').doc(Gv.passengerPhone)
      .collection('my_active_job').doc(Gv.passengerPhone);

  final passengerRef = fs
      .collection(Gv.negara).doc(Gv.negeri)
      .collection('passenger_account').doc(Gv.passengerPhone);

  final driverRef = fs
      .collection(Gv.negara).doc(Gv.negeri)
      .collection('driver_account').doc(Gv.loggedUser);

  // (optional) central bucket
  final activeJobLiteRef = fs.collection('active_job').doc('active_job_lite');

  // History IDs
  final historyDocId = '${getFormattedDate()}(${Gv.passengerPhone})';
  final passengerRideHistoryRef = passengerRef.collection('ride_history').doc(historyDocId);
  final driverJobHistoryRef    = driverRef.collection('job_history').doc(historyDocId);

  // Commission
  final double commission = (Gv.commissionFixedOrPercentage
          ? Gv.commissionFixed
          : (Gv.totalPrice * Gv.commissionPercentage / 100))
      .toDouble();

  // Idempotency
  final paymentId = '${DateTime.now().millisecondsSinceEpoch}-${Gv.passengerPhone}-${Gv.loggedUser}';

  await fs.runTransaction((tx) async {
    // 1) Read driver + job
    final driverSnap = await tx.get(driverRef);
    if (!driverSnap.exists) {
      throw Exception('Driver account not found.');
    }

    final jobSnap = await tx.get(myActiveJobRef);
    if (!jobSnap.exists) {
      throw Exception('Active job not found for passenger ${Gv.passengerPhone}.');
    }
    final jobData = Map<String, dynamic>.from(jobSnap.data()!);

    // Idempotency
    final processedIds =
        (driverSnap.data()?['processed_payment_ids'] as List?)?.cast<String>() ?? const <String>[];
    if (processedIds.contains(paymentId)) return;

    // 2) Deduct commission — ALLOW NEGATIVE
    final currentBalNum = (driverSnap.data()?['account_balance'] as num?) ?? 0;
    final double currentBalance = currentBalNum.toDouble();
    final double resultingBalance = currentBalance - commission;
    final crossedToNegative = currentBalance >= 0 && resultingBalance < 0;

    tx.update(driverRef, {
      'account_balance'       : FieldValue.increment(-commission), // always deduct
      'processed_payment_ids' : FieldValue.arrayUnion([paymentId]),
      'last_payment_timestamp': FieldValue.serverTimestamp(),
      'last_payment_amount'   : commission,
      // helpful metadata:
      'has_negative_balance'  : resultingBalance < 0,
      'last_balance_before'   : currentBalance,
      'last_balance_after'    : resultingBalance,
      if (crossedToNegative) 'negative_since': FieldValue.serverTimestamp(),
      if (!crossedToNegative && resultingBalance >= 0) 'negative_since': FieldValue.delete(),
    });

    // 3) Update my_active_job
    tx.update(myActiveJobRef, {
      'job_complete_date'          : getNiceDate(),
      'order_status'               : kStatusPaymentReceived,
      'process_driver_job_complete': true,
      'commission_deduction'       : commission,
      'updated_at'                 : FieldValue.serverTimestamp(),
    });

    // 4) Archive to histories
    final historyPayload = {
      ...jobData,
      'order_status'         : kStatusPaymentReceived,
      'commission_deduction' : commission,
      'archived_at'          : FieldValue.serverTimestamp(),
    };
    tx.set(passengerRideHistoryRef, historyPayload, SetOptions(merge: true));
    tx.set(driverJobHistoryRef, historyPayload, SetOptions(merge: true));

    // 5) Passenger flags
    tx.set(passengerRef, {
      'job_still_active'     : false,
      'ddpcc'                : 0,
      'ddpcc_start_time'     : FieldValue.delete(),
      'last_job_archived_at' : FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 6) Driver ledger
    final ledgerRef = driverRef.collection('transaction_history').doc(paymentId);
    tx.set(ledgerRef, {
      'transaction_amount'     : commission,
      'transaction_date'       : FieldValue.serverTimestamp(),
      'transaction_description': 'Commission Deduction',
      'transaction_money_in'   : false,
      // nice to have:
      'balance_before'         : currentBalance,
      'balance_after'          : resultingBalance,
      'job_ref'                : myActiveJobRef.path,
    });

    // 7) Optional: active bucket updates
    // tx.update(activeJobLiteRef, {...});

    // 8) Optional: delete active job
    // tx.delete(myActiveJobRef);
  });

  // Post-verify (optional)
  try {
    final verify = await myActiveJobRef.get();
    if (verify.exists) {
      debugPrint('my_active_job.order_status = ${verify.data()?['order_status']}');
    } else {
      debugPrint('my_active_job has been deleted.');
    }
  } catch (e) {
    debugPrint('Verification read failed: $e');
  }
}





  @override
  Widget build(BuildContext context) {
    return _primaryActionButton(
      context: context,
      label: 'Payment Received',


onPressed: _enabled ? () async {
  // (optional) avoid double taps
  setState(() => _enabled = false);

  // capture a stable navigator before awaits
  final nav = Navigator.of(context, rootNavigator: true);

  try {
    await handlePaymentReceived(); // do all Firestore work first
  } catch (e, st) {
    debugPrint('handlePaymentReceived failed: $e\n$st');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment update failed: $e')),
      );
    }
  } finally {
    // navigate after the call (even if it failed)
    nav.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Receipt'),
        builder: (_) => const ReceiptPage(),
      ),
    );
    if (mounted) setState(() => _enabled = true);
  }
} : null,

    );
  }
}
