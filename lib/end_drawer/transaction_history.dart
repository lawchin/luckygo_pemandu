import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:luckygo_pemandu/global.dart';

class TransactionHistory extends StatelessWidget {
  const TransactionHistory({Key? key}) : super(key: key);

  String formatTimestamp(Timestamp timestamp) {
    final d = timestamp.toDate().toLocal();
    return DateFormat('dd/MM/yyyy HH:mm').format(d);
  }

  String getGroupLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final dateOnly = DateTime(d.year, d.month, d.day);

    if (dateOnly == today) {
      return "Today";
    } else if (dateOnly == yesterday) {
      return "Yesterday";
    } else {
      return "Other days";
    }
  }

  void showReceiptDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        height: 120,
                        width: 120,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stack) {
                      return const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'Failed to load receipt image.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final txStream = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('driver_account')
        .doc(Gv.loggedUser)
        .collection('transaction_history')
        .orderBy('transaction_date', descending: true) // latest at top
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: txStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No transaction history found.'));
          }

          final docs = snapshot.data!.docs;
          String? currentGroup;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final ts = data['transaction_date'];
              if (ts is! Timestamp) return const SizedBox.shrink();

              final date = ts.toDate().toLocal();
              final groupLabel = getGroupLabel(date);

              final desc = (data['transaction_description'] ?? '-') as String;
              final isIn = (data['transaction_money_in'] ?? false) as bool;

              final amountRaw = data['transaction_amount'];
              final amountStr = amountRaw is num
                  ? amountRaw.toStringAsFixed(2)
                  : (amountRaw?.toString() ?? '0.00');

              final card = Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text('Date: ${formatTimestamp(ts)}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('📝: $desc')),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                Gv.currency,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 0.2,
                                  fontWeight: FontWeight.bold,
                                  color: isIn ? Colors.green : Colors.red,
                                ),
                              ),
                              Text(
                                amountStr,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isIn ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );

              // Add header if group changes
              if (groupLabel != currentGroup) {
                currentGroup = groupLabel;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      color: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Text(
                        groupLabel,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    card,
                  ],
                );
              } else {
                return card;
              }
            },
          );
        },
      ),
    );
  }
}
