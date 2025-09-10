import 'dart:async';
import 'package:flutter/material.dart';

class CountdownText extends StatefulWidget {
  final int seconds;
  final VoidCallback onFinished;

  const CountdownText({
    super.key,
    this.seconds = 15,
    required this.onFinished,
  });

  @override
  State<CountdownText> createState() => CountdownTextState();
}

class CountdownTextState extends State<CountdownText> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining == 1) {
        timer.cancel();
        widget.onFinished();
      }
      setState(() => _remaining--);
    });
  }

  /// 👇 Expose a cancel method
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '$_remaining',
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.red,
      ),
    );
  }
}
