import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/jobFilter/filter_job_one_stream2.dart';
import 'package:luckygo_pemandu/view15/item_details.dart';

class ReceiptPage extends StatelessWidget {
  const ReceiptPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
Expanded(
  flex: 7,
                          child: ItemDetails(),
                        ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left:12, right: 12),
              child: Column(
                children: [
                        Divider(
                          thickness: 2,
                          color: Colors.grey,
                          height: 20,
                        ),
                  Padding(
                    padding: const EdgeInsets.only(left:10, right:12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Grand Total: ${Gv.grandTotal.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                        Divider(
                          thickness: 2,
                          color: Colors.grey,
                          height: 20,
                        ),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
OutlinedButton.icon(
  icon: const Icon(Icons.star_rate),
  label: const Text('Rate Passenger'),
  onPressed: () async {
    final messenger = ScaffoldMessenger.of(context);

    int selected = 0;           // 0..5
    String? error;
    String commentText = '';    // capture comment without a controller

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              scrollable: true, // <-- prevents overflow when IME shows
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
                          });
                        },
                      );
                    }),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 4),
                    Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    maxLines: 3,
                    onChanged: (v) => commentText = v,
                    decoration: const InputDecoration(
                      labelText: 'Comment (optional)',
                      hintText: 'Add any feedback for the driver',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10), // 10px gap before Submit
                ],
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    print('${Gv.passengerPhone} \n'*10);
                    if (selected == 0) {
                      setState(() => error = 'Please select a star rating.');
                      return;
                    }

                    await FirebaseFirestore.instance
                        .collection(Gv.negara)
                        .doc(Gv.negeri)
                        .collection('passenger_account')
                        .doc(Gv.passengerPhone)
                        .collection('rating_history')
                        .add({
                      'rate_by_driver': '${Gv.userName} ${Gv.loggedUser}',
                      'rating': selected,
                      'comment': commentText.trim(),
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    await FirebaseFirestore.instance
                        .collection(Gv.negara)
                        .doc(Gv.negeri)
                        .collection('passenger_account')
                        .doc(Gv.passengerPhone)
                        .collection('notification_page')
                        .add({
                      'notification_date': FieldValue.serverTimestamp(),
                      'notification_description': 'You have received $selected⭐ rating from ${Gv.passengerName}\n\nKeep up the good work!',
                      'notification_seen': false,
                    });

                    // Print to console
                    print('Stars given: $selected');
                    print('Comment: ${commentText.trim()}');
                    print('Driver phone: ${Gv.passengerPhone}');
                    print('rate_by: Passenger: ${Gv.userName} $Gv.loggedUser');
                    print('timestamp: ${FieldValue.serverTimestamp()}');

                    // Return values
                    Navigator.of(dialogCtx, rootNavigator: true).pop({
                      'rating': selected,
                      'comment': commentText.trim(),
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

    if (result != null) {
      // Optional: show a brief confirmation
      messenger.showSnackBar(
        SnackBar(content: Text('You gave ${result['rating']} star(s). Comment: "${result['comment']}"')),
      );
    }
  },
),
 
                            SizedBox(width: 10),

                            OutlinedButton.icon(
                              onPressed: () {},
                              icon: const Icon(Icons.share),
                              label: const Text('Share PDF'),
                            ),

                          ],
                        ), 

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          // ---- Reset all your globals (kept as you had) ----
                  

                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => const FilterJobsOneStream2()),
                            (Route<dynamic> route) => false,
                          );

                          // await FirebaseFirestore.instance
                          //     .collection(negara!)
                          //     .doc(negeri)
                          //     .collection('passenger_account')
                          //     .doc(loggedUser)
                          //     .collection('my_active_job')
                          //     .doc(loggedUser)
                          //     .delete();
                        },
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        child: const Text('CLOSE'),
                      ),
                    ),
                       
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}