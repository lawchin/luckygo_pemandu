import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/landing%20page/landing_page.dart';

final _rnd = Random();

/// Always starts with "A-" + 8 random A–Z/0–9 (any mix).
String generateCodeAny8_A() {
  const pool = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  return 'H-' + List.generate(8, (_) => pool[_rnd.nextInt(pool.length)]).join();
}

/// Always starts with "A-" + exactly 4 letters & 4 digits (shuffled).
String generateCode44_A() {
  const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const digits  = '0123456789';
  final parts = <String>[
    for (var i = 0; i < 4; i++) letters[_rnd.nextInt(letters.length)],
    for (var i = 0; i < 4; i++) digits[_rnd.nextInt(digits.length)],
  ]..shuffle(_rnd);
  return 'H-' + parts.join();
}

class HelpCenter extends StatefulWidget {
  @override
  _HelpCenterState createState() => _HelpCenterState();
}

class _HelpCenterState extends State<HelpCenter> {
  final TextEditingController _controller = TextEditingController();

  void _clearText() {
    _controller.clear();
  }

Future<void> _submitText() async {
  final String ref = generateCode44_A(); // one code for both

  await FirebaseFirestore.instance
      .collection(Gv.negara)
      .doc(Gv.negeri)
      .collection('help_center')
      .doc('customer_service')
      .collection('service_data')
      .add({
    'user': Gv.loggedUser,
    'name': Gv.userName,
    'message': _controller.text,
    'timestamp': FieldValue.serverTimestamp(),
    'sender': 'driver',
    'refference': ref,
    'admin_seen': false,
    'admin_seen_timestamp': null,
    'admin_remark': '',
  });

  await _notifyUser(ref);

  if (!mounted) return;

  // show snackBar for 2 seconds
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('you message with the ref: $ref has been sent succesfully'),
      duration: const Duration(seconds: 2),
    ),
  );

  _controller.clear();

  // navigate after 2 seconds
  Future.delayed(const Duration(seconds: 2), () {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => LandingPage()),
    );
  });
}

  Future<void> _notifyUser(String ref) async {
    await FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('driver_account') // ← driver app
        .doc(Gv.loggedUser)
        .collection('notification_page')
        .add({
      'notification_date': FieldValue.serverTimestamp(),
      'notification_description':
          'Hello ${Gv.userName},\nWe have received your message ref:$ref.\nOur customer service will get back to you shortly.\n\nThank you for reaching out to us!\n- LuckyGo Team',
      'notification_seen': false,
    });
  }

  void _closePage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LandingPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _closePage,
        ),
        title: Text('Help Center'),
        actions: [
          TextButton(
            onPressed: _clearText,
            child: Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wellcome to help center how can we help you?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24),
            TextField(
              controller: _controller,
              maxLines: 4,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Type your message here...',
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: _clearText,   // ← changed from _closePage
                  child: Text('Clear'),    // ← label changed from 'Close'
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _submitText,
                  child: Text('Submit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
