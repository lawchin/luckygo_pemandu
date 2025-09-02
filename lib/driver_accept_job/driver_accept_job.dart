import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/driver_accept_job/job_status_updater.dart';
import 'package:luckygo_pemandu/driver_accept_job/receipt_page.dart';
import 'package:luckygo_pemandu/driver_accept_job/tell_others.dart';
import 'package:luckygo_pemandu/geo_fencing/geofencing_controller.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/jobFilter/filter_job_one_stream2.dart';
import 'package:luckygo_pemandu/landing%20page/landing_page.dart';
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

                  if (!snap.hasData || !snap.data!.exists) {
                    _d('No active job doc for $phone → schedule redirect to FilterJobsOneStream2');
                    // schedule navigation after 5000ms
                    Future.delayed(const Duration(milliseconds: 5000), () {
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const FilterJobsOneStream2()),
                        );
                      }
                    });

                    return _paddedCard(
                      child: const Center(
                        child: Text(
                          "The job has been cancelled, either by the passenger or by Admin due to a technical issue.",
                        ),
                      ),
                    );
                  }

                  final data = snap.data!.data() ?? {};
                  // ✅ Fill your globals for map usage
                  Gv.passengerGp = data['z_source'] is GeoPoint
                      ? data['z_source'] as GeoPoint
                      : const GeoPoint(0.0, 0.0);

                  Gv.driverGp = data['x_driver_geopoint'] is GeoPoint
                      ? data['x_driver_geopoint'] as GeoPoint
                      : const GeoPoint(0.0, 0.0);

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
                                    InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () {
                                        _d('Price Details tapped');
                                      },
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.help_outline, size: 18, color: Colors.black54),
                                          SizedBox(width: 6),
                                          Text(
                                            'Price Details',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Spacer(),
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
                                                      child: const Text('Tell Others')
                                                    ),

                                                    ElevatedButton(onPressed: () {}, child: const Text('')),
                                                    ElevatedButton(onPressed: () {}, child: const Text('')),
                                                    ElevatedButton(onPressed: () {}, child: const Text('')),
                                                    ElevatedButton(onPressed: () {}, child: const Text('')),
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
                                  _openDriverToPickupInGoogleMaps(context);
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
          ? () {
              FirebaseFirestore.instance
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
  const kStatusPaymentReceived = 'payment_received'; // <- unify this

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

  // If you also keep a single "active_job_lite" collection:
  final activeJobLiteRef = fs
      .collection('active_job').doc('active_job_lite'); // adjust if your path differs

  // Stable, human-readable history doc IDs
  final historyDocId = '${getFormattedDate()}(${Gv.passengerPhone})';

  final passengerRideHistoryRef = passengerRef
      .collection('ride_history').doc(historyDocId);

  final driverJobHistoryRef = driverRef
      .collection('job_history').doc(historyDocId);

  // Compute commission once
  final double commission = (Gv.commissionFixedOrPercentage
      ? Gv.commissionFixed
      : (Gv.totalPrice * Gv.commissionPercentage / 100))
      .toDouble();

  // Optional idempotency
  final paymentId = '${DateTime.now().millisecondsSinceEpoch}-${Gv.passengerPhone}-${Gv.loggedUser}';

  await fs.runTransaction((tx) async {
    // --- 1) Read driver + job data up front ---
    final driverSnap = await tx.get(driverRef);
    if (!driverSnap.exists) {
      throw Exception('Driver account not found.');
    }

    final jobSnap = await tx.get(myActiveJobRef);
    if (!jobSnap.exists) {
      throw Exception('Active job not found for passenger ${Gv.passengerPhone}.');
    }
    final jobData = Map<String, dynamic>.from(jobSnap.data()!);

    // (Optional) idempotency
    final processedIds = (driverSnap.data()?['processed_payment_ids'] as List?)?.cast<String>() ?? const <String>[];
    if (processedIds.contains(paymentId)) {
      return; // already processed
    }

    // --- 2) Deduct commission from driver balance ---
    final currentBalNum = (driverSnap.data()?['account_balance'] as num?) ?? 0;
    final currentBalance = currentBalNum.toDouble();
    final newBalance = currentBalance - commission;

    // Prevent negative if required by your business rules
    if (newBalance < 0) {
      throw Exception('Insufficient balance to deduct commission: ${commission.toStringAsFixed(2)}');
    }

    tx.update(driverRef, {
      'account_balance': FieldValue.increment(-commission),
      'processed_payment_ids': FieldValue.arrayUnion([paymentId]),
      'last_payment_timestamp': FieldValue.serverTimestamp(),
      'last_payment_amount': commission,
    });

    // --- 3) Update my_active_job status (force update, not upsert) ---
    tx.update(myActiveJobRef, {
      'job_complete_date': getNiceDate(),
      'order_status': kStatusPaymentReceived, // <<< unified, expected value
      'process_driver_job_complete': true,
      'commission_deduction': commission,
      'updated_at': FieldValue.serverTimestamp(),
    });

    // --- 4) Copy job to passenger + driver histories ---
    final historyPayload = {
      ...jobData,
      'order_status': kStatusPaymentReceived,
      'commission_deduction': commission,
      'archived_at': FieldValue.serverTimestamp(),
    };
    tx.set(passengerRideHistoryRef, historyPayload, SetOptions(merge: true));
    tx.set(driverJobHistoryRef, historyPayload, SetOptions(merge: true));

    // --- 5) Update passenger_account flags ---
    tx.set(passengerRef, {
      'job_still_active': false,
      'ddpcc': 0,
      'ddpcc_start_time': FieldValue.delete(),
      'last_job_archived_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // --- 6) Create a transaction record for driver ---
    final txRef = driverRef.collection('transaction_history').doc(paymentId);
    tx.set(txRef, {
      'transaction_amount': commission,
      'transaction_date': FieldValue.serverTimestamp(),
      'transaction_description': "Commission Deduction",
      'transaction_money_in': false,
    });

    // --- 7) (Optional per your Step 43) remove job from active buckets ---
    // tx.update(activeJobLiteRef, {
    //   // however you store/identify the job string to remove:
    //   // e.g., FieldValue.arrayRemove([ jobString ])
    // });

    // --- 8) (Optional per Step 43) delete my_active_job doc ---
    // tx.delete(myActiveJobRef);
  });

  // Post-transaction sanity check (helps you debug what UI is reading)
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


onPressed: _enabled ? () {
  // Grab a stable navigator BEFORE any awaits/state changes.
  final nav = Navigator.of(context, rootNavigator: true);

  // Navigate immediately (don’t await, don’t check mounted here).
  nav.push(
    MaterialPageRoute(
      settings: const RouteSettings(name: 'Receipt'),
      builder: (_) => const ReceiptPage(),
    ),
  );

  // Fire-and-forget the writes AFTER the push; don't touch context again.
  () async {
    try {
      await updatePaymentReceivedStatus(); // status-only write
      await handlePaymentReceived();       // heavy write
    } catch (e, st) {
      debugPrint('payment_received write failed: $e\n$st');
    }
  }();
} : null,





    );
  }
}
