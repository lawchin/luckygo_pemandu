import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Use your driver app's global file:
import 'package:luckygo_pemandu/global.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({Key? key}) : super(key: key);

  String _formatTs(Timestamp ts) {
    final d = ts.toDate().toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final userRef = FirebaseFirestore.instance
        .collection(Gv.negara!)
        .doc(Gv.negeri!)
        .collection('driver_account')
        .doc(Gv.loggedUser!);

    final query = userRef
        .collection('notification_page')
        .orderBy('notification_date', descending: true);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Mark all read',
            icon: const Icon(Icons.done_all),
            onPressed: () async {
              await _markAllNotificationsSeen(userRef);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('All notifications marked as read')),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final docs = snap.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Center(child: Text('No notifications found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (context, i) {
              final doc = docs[i];
              final data = doc.data();

              final desc = (data['notification_description'] ?? '') as String;
              final seen = (data['notification_seen'] ?? false) as bool;
              final ts = data['notification_date'];
              final dateText = ts is Timestamp ? _formatTs(ts) : '';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12),
                child: ListTile(
                  title: Row(
                    children: [
                      Text(
                        dateText,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Delete notification',
                        onPressed: () async {
                          await doc.reference.delete(); // deletes this notification doc
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Notification deleted')),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (desc.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2.0, bottom: 4.0),
                          child: Text(desc),
                        ),
                    ],
                  ),
                  trailing: seen
                      ? null
                      : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(.3)),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                  onTap: () async {
                    if (!seen) {
                      await doc.reference.update({'notification_seen': true});
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Marks all unseen notifications as seen for the given userRef (driver).
Future<void> _markAllNotificationsSeen(
  DocumentReference<Map<String, dynamic>> userRef,
) async {
  final q = await userRef
      .collection('notification_page')
      .where('notification_seen', isEqualTo: false)
      .get();

  if (q.docs.isEmpty) return;

  final batch = FirebaseFirestore.instance.batch();
  for (final d in q.docs) {
    batch.update(d.reference, {'notification_seen': true});
  }
  await batch.commit();
}
