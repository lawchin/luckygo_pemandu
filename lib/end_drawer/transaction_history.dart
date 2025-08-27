import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// Use your DRIVER app global
import 'package:luckygo_pemandu/global.dart';

class TransactionHistory extends StatelessWidget {
  const TransactionHistory({Key? key}) : super(key: key);

  String formatTimestamp(Timestamp timestamp) {
    final d = timestamp.toDate().toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
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
        .orderBy('transaction_date', descending: false) // keep your sort choice
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
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final ts = data['transaction_date'];
              final dateText = ts is Timestamp ? formatTimestamp(ts) : '—';

              final desc = (data['transaction_description'] ?? '-') as String;
              final isIn = (data['transaction_money_in'] ?? false) as bool;

              // amount could be stored as string or number; normalize to string
              final amountRaw = data['transaction_amount'];
              final amountStr = amountRaw is num
                  ? amountRaw.toStringAsFixed(2)
                  : (amountRaw?.toString() ?? '0.00');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  title: Text('Date: $dateText'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Text('📝: $desc'),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                  // If later you store a receipt URL per transaction, you can:
                  // onTap: () => showReceiptDialog(context, data['receipt_image_url']),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
