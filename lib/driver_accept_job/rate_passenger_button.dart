import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';

class RatePassengerButton extends StatefulWidget {
  /// Optional receipt/order id. If you don't have it, omit and it locks per passenger.
  final String? receiptId;
  const RatePassengerButton({super.key, this.receiptId});

  @override
  State<RatePassengerButton> createState() => _RatePassengerButtonState();
}

class _RatePassengerButtonState extends State<RatePassengerButton> {
  bool _rateLocked = false;
  String? _lockKey; // remembers which passenger/receipt we submitted for

  String get _currentKey {
    final phone = Gv.passengerPhone ?? '';
    final receipt = widget.receiptId ?? '';
    return '$phone::$receipt';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = _rateLocked && _lockKey == _currentKey;

    return ElevatedButton(
      onPressed: isDisabled
          ? null
          : () async {
              final result = await _showRatingDialog(context);
              if (result != null) {
                // lock button for this passenger/receipt only
                setState(() {
                  _rateLocked = true;
                  _lockKey = _currentKey;
                });
                // success snackbar
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your ratings has been submited succesfully!'),
                    ),
                  );
                }
              }
            },
      child: const Text('Rate Passenger'),
    );
  }

  Future<Map<String, dynamic>?> _showRatingDialog(BuildContext context) async {
    int selected = 0;
    String? error;
    String commentText = '';
    String commentLevel = '';

    return showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            // compute comment enable/disable + level based on selected stars
            final bool commentEnabled;
            if (selected >= 5) {
              commentLevel = 'Excellent';
              commentEnabled = false;
            } else if (selected == 4) {
              commentLevel = 'Good';
              commentEnabled = false;
            } else if (selected > 0) {
              commentLevel = 'Bad';
              commentEnabled = true;
            } else {
              commentLevel = '';
              commentEnabled = true;
            }

            return AlertDialog(
              scrollable: true,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              titlePadding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              actionsPadding: const EdgeInsets.only(bottom: 12),
              title: Row(
                children: [
                  const Expanded(child: Text('Rate Passenger')),
                  IconButton(
                    tooltip: 'Close',
                    color: Colors.red,
                    onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('How was your passenger?'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final idx = i + 1;
                      final isOn = idx <= selected;
                      return IconButton(
                        iconSize: 32,
                        splashRadius: 22,
                        icon: Icon(Icons.star, color: isOn ? Colors.amber : Colors.grey),
                        onPressed: () {
                          setState(() {
                            selected = idx;
                            error = null;
                            if (selected >= 4) commentText = ''; // avoid saving stale text
                          });
                        },
                      );
                    }),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 4),
                    Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  if (commentLevel.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Level: $commentLevel',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  TextField(
                    enabled: commentEnabled, // disabled for 4–5 stars
                    maxLines: 3,
                    onChanged: (v) => commentText = v,
                    decoration: InputDecoration(
                      labelText: 'Comment',
                      hintText: commentEnabled
                          ? 'Add any feedback for the passenger'
                          : 'Disabled for 4–5★',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    if (selected == 0) {
                      setState(() => error = 'Please select a star rating.');
                      return;
                    }

                    final String level = (selected >= 5)
                        ? 'Excellent'
                        : (selected == 4)
                            ? 'Good'
                            : 'Bad';
                    final String saveComment = (selected <= 3) ? commentText.trim() : '';

                    // write to Firestore
                    await FirebaseFirestore.instance
                        .collection(Gv.negara)
                        .doc(Gv.negeri)
                        .collection('passenger_account')
                        .doc(Gv.passengerPhone)
                        .collection('rating_history')
                        .add({
                      'rate_by_driver': '${Gv.userName} ${Gv.loggedUser}',
                      'rating': selected,
                      'comment': saveComment,
                      'comment_level': level,
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    // notification
                    await FirebaseFirestore.instance
                        .collection(Gv.negara)
                        .doc(Gv.negeri)
                        .collection('passenger_account')
                        .doc(Gv.passengerPhone)
                        .collection('notification_page')
                        .add({
                      'notification_date': FieldValue.serverTimestamp(),
                      'notification_description':
                          'You have received $selected⭐ rating from ${Gv.userName}\n\nKeep up the good work!',
                      'notification_seen': false,
                    });

                    Navigator.of(dialogCtx, rootNavigator: true).pop({
                      'rating': selected,
                      'comment': saveComment,
                      'comment_level': level,
                    });
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    child: Text('Submit'),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
