import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/main.dart';

class DepositHistory extends StatelessWidget {
  const DepositHistory({Key? key}) : super(key: key);

  // Helper to format timestamp
  String formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final two = (int n) => n.toString().padLeft(2, '0');
    return "${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}";
  }

  void showReceiptDialog(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero, // edge-to-edge
          child: Stack(
            children: [
              // Zoom & pan
              Center(
                child: InteractiveViewer(
                  maxScale: 5,
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    // Show spinner while loading
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const SizedBox(
                        height: 120,
                        width: 120,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    // Fallback if the URL is bad / network error
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
              // Close (×) button
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Close',
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Successfully':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Pending':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Deposit History'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection(Gv.negara!)
            .doc(Gv.negeri)
            .collection('driver_account')
            .doc(Gv.loggedUser)
            .collection('deposit_history')
            .orderBy('deposit_date', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No deposit history found.'));
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final status = (data['deposit_status'] ?? '').toString();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: ListTile(
                  leading: GestureDetector(
                    onTap: () {
                      final url = data['receipt_image_url'];
                      if (url != null && url.toString().isNotEmpty) {
                        showReceiptDialog(context, url);
                      }
                    },
                    child: const Icon(Icons.receipt, size: 40, color: Colors.blue),
                  ),
                  title: Text('Date: ${formatTimestamp(data['deposit_date'])}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(''),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          const Text('Status: '),
                          Text(
                            status,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(status),
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${Gv.currency}',
                                style: const TextStyle(fontSize: 10, height: 0.2),
                              ),
                              Text('${data['deposit_amount']}'),
                            ],
                          ),
                        ],
                      ),
                    ],
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
