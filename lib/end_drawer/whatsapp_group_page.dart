import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class WhatsappGroupPage extends StatelessWidget {
  const WhatsappGroupPage({Key? key}) : super(key: key);

  Future<List<Map<String, dynamic>>> fetchActiveGroups() async {
    final firestore = FirebaseFirestore.instance;
    final baseRef = firestore
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('information')
        .doc('whatsapp_group')
        .collection('channel');

    final snapshot = await baseRef.where('active', isEqualTo: true).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  void openWhatsappLink(BuildContext context, String link) async {
    if (link.isEmpty || !link.startsWith('https://chat.whatsapp.com/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid WhatsApp link')),
      );
      return;
    }

    final uri = Uri.parse(link);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw Exception('Launch failed');
      }
    } catch (e) {
      debugPrint('Could not launch $link: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open WhatsApp. Link copied to clipboard.'),
          action: SnackBarAction(
            label: 'Paste',
            onPressed: () => Clipboard.setData(ClipboardData(text: link)),
          ),
        ),
      );
      await Clipboard.setData(ClipboardData(text: link));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join WhatsApp Groups')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: fetchActiveGroups(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No active groups found.'));
          }

          final groups = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final name = group['name'] ?? 'Unnamed Group';
              final link = group['link'] ?? '';

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.abc, color: Colors.white),
                    onPressed: () => openWhatsappLink(context, link),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green[600],
                    ),
                    label: Text(
                      name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
