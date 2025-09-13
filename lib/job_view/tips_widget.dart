import 'package:flutter/material.dart';

class TipsWidget extends StatelessWidget {
  final String value;

  const TipsWidget({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final tipValue = int.tryParse(value) ?? 0;
    if (tipValue < 1) return const SizedBox.shrink();

    return SizedBox(
      width: 70,
      height: 20,
      child: Card(
        color: Colors.yellow[50],
        elevation: 0,
        margin: EdgeInsets.zero, // 🔥 removes default margin
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: const Color.fromARGB(255, 243, 118, 0), width: 2),
        ),
        child: Center( // 🔥 replaces Padding for tighter layout
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.card_giftcard, color: Colors.orange[600], size: 14),
              const SizedBox(width: 4),
              Text(
                '$tipValue',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
