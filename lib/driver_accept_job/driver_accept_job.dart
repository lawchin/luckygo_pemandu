import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/jobFilter/filter_job_one_stream2.dart';
import 'package:url_launcher/url_launcher.dart';

class DAJ extends StatelessWidget {
  const DAJ({super.key});

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

    return PopScope(
      canPop: false, // ⛔ Block device back + swipe back on this page
      onPopInvoked: (didPop) {
        // If the system attempted to pop but we blocked it, show a brief message
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
                    return const Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  if (snap.hasError) {
                    return _paddedCard(
                      child: const Center(
                        child: Text('Failed to load job data', style: TextStyle(color: Colors.red)),
                      ),
                    );
                  }

                  if (!snap.hasData || !snap.data!.exists) {
                    // schedule navigation after 1500ms
                    Future.delayed(const Duration(milliseconds: 5000), () {
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(builder: (_) => const FilterJobsOneStream2()),
                        );
                      }
                    });

                    return _paddedCard(
                      child: const Center(
                        child: Text("The job has been cancelled, either by the passenger or by Admin due to a technical issue."),
                      ),
                    );
                  }




                  final data  = snap.data!.data() ?? {};
                  final selfie = (data['y_passenger_selfie'] as String?) ?? '';
                  final pPhone = (data['job_created_by'] as String?) ?? '';
                  final pName  = (data['job_creator_name'] as String?) ?? pPhone;
                  final total  = (data['total_price'] as num?)?.toDouble() ?? 0.0;
                  final tips1  = (data['tips_amount1'] as num?)?.toDouble() ?? 0.0;
                  final tips2  = (data['tips_amount2'] as num?)?.toDouble() ?? 0.0;
                  final orderStatus  = (data['order_status'] as String?) ?? '';

                  return _paddedCard(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top row: avatar + name/phone + amount on right
                          SizedBox(
                            height: 30,
                            child: Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(horizontal: 2), // ⬅ shrink left & right
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              color: const Color(0xFFE9F8EF), // very light green
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical:4),
                                child: Row(
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(999),
                                      onTap: () {
                                        // TODO: show price details
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
                                        // TODO: open action sheet
                                      },
                                      child: const Text(
                                        'Action',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.black87,
                                          height: 1
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
                                      height:0.2
                                    ),
                                  ),
                                  Text(
                                    '${total.toStringAsFixed(2)}',
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
                                  // TODO: open maps for navigation
                                },
                              ),
                              const SizedBox(width: 10),
                              _pillButton(
                                context,
                                icon: Icons.chat_bubble_rounded,
                                label: 'Chat',
                                color: const Color(0xFF22A447),
                                onTap: () {
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
                                  _callNumber(context, pPhone); // <-- CALL: opens dialer
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
                          Center(
                            child: Text(
                              "Press Go button if you're ready",
                              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                            )
                          ),
                          const Spacer(),
_primaryActionForStatus(context, orderStatus),


                          // Bottom row: Price Details • Action • Amount (again)
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

  // ---------- launch helpers ----------
  // Keep digits and '+' (dialer understands +6011..., etc.)
  String _normalizePhone(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9\+]'), '');
  }

  // Chat (WhatsApp) – unchanged
  Future<void> _openWhatsApp(BuildContext context, String rawPhone, {String? prefill}) async {
    final phone = _normalizePhone(rawPhone);
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No passenger phone number')),
      );
      return;
    }

    final text = Uri.encodeComponent(prefill ?? '');
    final uriApp = Uri.parse('whatsapp://send?phone=$phone&text=$text');
    final uriWeb = Uri.parse('https://wa.me/$phone?text=$text');

    try {
      if (await canLaunchUrl(uriApp)) {
        await launchUrl(uriApp, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uriWeb, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open WhatsApp: $e')),
      );
    }
  }

  // CALL button – opens device dialer (no CALL_PHONE permission needed)
  Future<void> _callNumber(BuildContext context, String rawPhone) async {
    final phone = _normalizePhone(rawPhone);
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No passenger phone number')),
      );
      return;
    }
    final telUri = Uri.parse('tel:$phone'); // opens dialer; user confirms call
    try {
      await launchUrl(telUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start call: $e')),
      );
    }
  }
}

// 1) Put these helpers in your widget (e.g., inside DAJ, below build):

Widget _primaryActionButton({
  required BuildContext context,
  required String label,
  required VoidCallback? onPressed, // <-- nullable so we can pass null to disable
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
      onPressed: onPressed, // null = disabled (greyed out, no taps)
      child: Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    ),
  );
}

Widget _primaryActionForStatus(BuildContext context, String? rawStatus) {
  final status = (rawStatus ?? '').trim().toLowerCase();

  switch (status) {
    case 'driver_accepted_job':
      return _primaryActionButton(
        context: context,
        label: 'Go',
        onPressed: () {
          FirebaseFirestore.instance
              .collection(Gv.negara)
              .doc(Gv.negeri)
              .collection('passenger_account')
              .doc(Gv.passengerPhone)
              .collection('my_active_job')
              .doc(Gv.passengerPhone)
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
              .collection(Gv.negara)
              .doc(Gv.negeri)
              .collection('passenger_account')
              .doc(Gv.passengerPhone)
              .collection('my_active_job')
              .doc(Gv.passengerPhone)
              .update({'order_status': 'start_destination'});
        },
      );

    case 'start_destination':
      return const _DelayedJobCompleteButton();

    case 'job_completed':

      return const _DelayedPaymentReceivedButton();

    case 'payment_received':
      return const SizedBox.shrink();

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
    // unlock button after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _enabled = true);
      }
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
                  .collection(Gv.negara)
                  .doc(Gv.negeri)
                  .collection('passenger_account')
                  .doc(Gv.passengerPhone)
                  .collection('my_active_job')
                  .doc(Gv.passengerPhone)
                  .update({'order_status': 'driver_arrived'});
            }
          : null, // disabled until _enabled == true
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
    // unlock button after 3 seconds
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
                  .collection(Gv.negara)
                  .doc(Gv.negeri)
                  .collection('passenger_account')
                  .doc(Gv.passengerPhone)
                  .collection('my_active_job')
                  .doc(Gv.passengerPhone)
                  .update({
                    'job_is_completed': true,
                    'order_status': 'job_completed',
                    });
            }
          : null, // disabled until enabled == true
    );
  }
}

class _DelayedPaymentReceivedButton extends StatefulWidget {
  const _DelayedPaymentReceivedButton();

  @override
  State<_DelayedPaymentReceivedButton> createState() => _DelayedPaymentReceivedButtonState();
}

class _DelayedPaymentReceivedButtonState extends State<_DelayedPaymentReceivedButton> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    // unlock after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _enabled = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return _primaryActionButton(
      context: context,
      label: 'Payment Received',
      onPressed: _enabled
          ? () {
              debugPrint('Payment Received pressed');

              // 1) Navigate FIRST (context is valid here)
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const FilterJobsOneStream2()),
                (route) => false,
              );

              // 2) Fire-and-forget the write (no need for context afterwards)
              // ignore: discarded_futures
              FirebaseFirestore.instance
                  .collection(Gv.negara)
                  .doc(Gv.negeri)
                  .collection('passenger_account')
                  .doc(Gv.passengerPhone)
                  .collection('my_active_job')
                  .doc(Gv.passengerPhone)
                  .set({'order_status': 'payment_received'}, SetOptions(merge: true))
                  .then((_) => debugPrint('payment_received write OK'))
                  .catchError((e, st) {
                    debugPrint('payment_received write failed: $e\n$st');
                  });
            }
          : null,






    );
  }
}







