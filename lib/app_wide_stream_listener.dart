// lib/app_wide_stream_listener.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'global.dart' as global;   // expects global.Gv.*

class AppWideStreamListener extends StatefulWidget {
  final Widget child;
  const AppWideStreamListener({super.key, required this.child});

  @override
  State<AppWideStreamListener> createState() => _AppWideStreamListenerState();
}

class _AppWideStreamListenerState extends State<AppWideStreamListener> {
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _ratingsSub;
  bool _dialogOpen = false;
  String? _lastSeenRatingId;

  // --- DEBUG helper ---
  void _log(String msg) => debugPrint('[RATING-LISTENER] $msg');

  String get _prefsKey =>
      'last_seen_rating_${global.Gv.loggedUser.isNotEmpty ? global.Gv.loggedUser : "unknown"}';

  @override
  void initState() {
    super.initState();
    _initDebugFireStore();
    _dumpBootstrapValues();
    _initAndListen();
  }

Future<void> _initDebugFireStore() async {
  try {
    // ✅ static call
    await FirebaseFirestore.setLoggingEnabled(true);
    _log('Firestore SDK logging ENABLED');
  } catch (e) {
    _log('Firestore SDK logging call not available (ok to ignore). Error: $e');
  }
}


  void _dumpBootstrapValues() {
    _log('Bootstrap values: negara="${global.Gv.negara}", negeri="${global.Gv.negeri}", loggedUser="${global.Gv.loggedUser}"');
  }

  Future<void> _initAndListen() async {
    // Load last seen id
    final prefs = await SharedPreferences.getInstance();
    _lastSeenRatingId = prefs.getString(_prefsKey);
    _log('Loaded last seen rating id: "${_lastSeenRatingId ?? "(none)"}" from prefs key: $_prefsKey');

    // Basic guards
    if (global.Gv.negara.isEmpty ||
        global.Gv.negeri.isEmpty ||
        global.Gv.loggedUser.isEmpty) {
      _log('ABORT: negara/negeri/loggedUser not ready. No subscription started.');
      return;
    }

    final pathDesc =
        '/${global.Gv.negara}/${global.Gv.negeri}/driver_account/${global.Gv.loggedUser}/rating_history';
    _log('Subscribing to: $pathDesc');

    final colRef = FirebaseFirestore.instance
        .collection(global.Gv.negara)
        .doc(global.Gv.negeri)
        .collection('driver_account')
        .doc(global.Gv.loggedUser)
        .collection('rating_history');

    // Your documents have `timestamp` (screenshot). Use that field to sort.
    final query = colRef.orderBy('timestamp', descending: true).limit(1);

    _ratingsSub = query.snapshots().listen(
      (qs) async {
        _log('Snapshot received. metadata: fromCache=${qs.metadata.isFromCache}, hasPendingWrites=${qs.metadata.hasPendingWrites}, docCount=${qs.docs.length}');

        if (qs.docs.isEmpty) {
          _log('No rating documents found.');
          return;
        }

        final doc = qs.docs.first;
        _log('Top doc id: ${doc.id}');
        _log('Top doc data: ${doc.data()}');

        if (_lastSeenRatingId == doc.id) {
          _log('Same as last seen id "$_lastSeenRatingId". Skipping popup.');
          return;
        }

        final data = doc.data();
        // Fields per screenshot:
        // comment: "goooood"
        // rate_by: "Passenger: Chuck Norris 0000000000"
        // rating: 5
        // timestamp: Timestamp
        final double stars = (data['rating'] is num) ? (data['rating'] as num).toDouble() : 0.0;
        final String comment = (data['comment'] ?? '').toString();
        final String rateBy = (data['rate_by'] ?? '').toString();
        final Timestamp? ts = data['timestamp'] as Timestamp?;
        final String when = ts != null ? ts.toDate().toLocal().toString() : '(no timestamp)';

        _log('Parsed: stars=$stars, comment="$comment", rateBy="$rateBy", when="$when"');

        await _showRatingDialog(
          stars: stars,
          comment: comment,
          rateBy: rateBy,
          when: when,
        );

        // Mark as seen so it won't replay
        _lastSeenRatingId = doc.id;
        await prefs.setString(_prefsKey, doc.id);
        _log('Saved last seen rating id "${doc.id}" to prefs key: $_prefsKey');
      },
      onError: (e, st) {
        _log('STREAM ERROR: $e');
        if (kDebugMode) {
          print(st);
        }
      },
      onDone: () => _log('Stream DONE'),
      cancelOnError: false,
    );
  }

  Future<void> _showRatingDialog({
    required double stars,
    required String comment,
    required String rateBy,
    required String when,
  }) async {
    final ctx = global.rootContext;
    if (ctx == null) {
      _log('Cannot show dialog: rootContext is null.');
      return;
    }
    if (_dialogOpen) {
      _log('Dialog is already open. Skipping.');
      return;
    }

    _dialogOpen = true;
    await Future<void>.delayed(Duration.zero);

    _log('Showing rating dialog…');
    await showDialog(
      context: ctx,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (_) => AlertDialog(
        title: const Text('New rating received'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StarsRow(value: stars),
            const SizedBox(height: 6),
            if (comment.trim().isNotEmpty) Text('“$comment”'),
            if (rateBy.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(rateBy, style: const TextStyle(fontSize: 13)),
            ],
            if (when.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(when, style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _log('Dialog OK pressed');
              Navigator.of(ctx, rootNavigator: true).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );

    _dialogOpen = false;
    _log('Dialog closed.');
  }

  @override
  void dispose() {
    _ratingsSub?.cancel();
    _log('Subscription cancelled.');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Simple 0..5 stars with half support
class _StarsRow extends StatelessWidget {
  final double value;
  const _StarsRow({required this.value});

  @override
  Widget build(BuildContext context) {
    const max = 5;
    final full = value.floor().clamp(0, max);
    final hasHalf = (value - full) >= 0.5 && full < max;
    final empty = max - full - (hasHalf ? 1 : 0);

    Widget icon(IconData i) => Icon(i, size: 22, color: Colors.amber);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < full; i++) icon(Icons.star),
        if (hasHalf) icon(Icons.star_half),
        for (int i = 0; i < empty; i++) icon(Icons.star_border),
      ],
    );
  }
}
