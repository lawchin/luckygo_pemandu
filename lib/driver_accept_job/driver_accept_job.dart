import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:url_launcher/url_launcher.dart';

class DAJ extends StatelessWidget {
  const DAJ({super.key});

  @override
  Widget build(BuildContext context) {
    // Get passenger phone from Gv (supports either String or ValueNotifier<String>)
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

    return Scaffold(
      body: Column(
        children: [
          const Expanded(flex: 6, child: SizedBox.shrink()),

          // Bottom 40% — live job card
          Expanded(
            flex: 4,
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
                  return _paddedCard(
                    child: const Center(child: Text('No active job found')),
                  );
                }

                final data  = snap.data!.data() ?? {};
                final selfie = (data['y_passenger_selfie'] as String?) ?? '';
                final pPhone = (data['job_created_by'] as String?) ?? '';
                final pName  = (data['job_creator_name'] as String?) ?? pPhone;
                final total  = (data['total_price'] as num?)?.toDouble() ?? 0.0;
                final tips1  = (data['tips_amount1'] as num?)?.toDouble() ?? 0.0;
                final tips2  = (data['tips_amount2'] as num?)?.toDouble() ?? 0.0;

                return _paddedCard(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top row: avatar + name/phone + amount on right
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 26,
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
                            Text(
                              'RM ${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1982E3),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

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
                                _callNumber(context, pPhone);
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Tips (conditionally shown)
                        if (tips1 > 0 || tips2 > 0) ...[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (tips1 > 0) _chip('Tips 1: RM ${tips1.toStringAsFixed(2)}'),
                              if (tips2 > 0) _chip('Tips 2: RM ${tips2.toStringAsFixed(2)}'),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],

                        const Spacer(),

                        // Bottom row: Price Details • Action • Amount (again)
                        Row(
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
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              ),
                              onPressed: () {
                                // TODO: open action sheet
                              },
                              child: const Text(
                                'Action',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'RM ${total.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1982E3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------- small UI helpers ----------
  Widget _paddedCard({required Widget child}) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
  String _normalizePhone(String raw) {
    // keep digits only; ensure your stored number already includes country code (e.g., 60xxxxxxxxx)
    return raw.replaceAll(RegExp(r'\D'), '');
  }

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

  Future<void> _callNumber(BuildContext context, String rawPhone) async {
    final phone = _normalizePhone(rawPhone);
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No passenger phone number')),
      );
      return;
    }
    final telUri = Uri.parse('tel:$phone');
    try {
      await launchUrl(telUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start call: $e')),
      );
    }
  }
}
