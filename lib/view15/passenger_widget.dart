// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';

class PassengerWidget extends StatefulWidget {
  final String indicator;   // e.g. 'ind_adult'
  final String label;       // (reserved for future)
  final int quantity;       // quantity for indicator
  final double total;       // (reserved for future)
  final String indicator2;  // e.g. 'ind_baby'
  final String label2;      // (reserved for future)
  final int quantity2;      // quantity for indicator2
  final double total2;      // (reserved for future)
  final double total3;      // combined total to show at right
  final int totalTotal;     // combined quantity to show in middle
  final String label3;      // e.g. 'Passengers:'
  final VoidCallback? onRemove;

  const PassengerWidget({
    Key? key,
    required this.indicator,
    required this.label,
    required this.quantity,
    required this.total,
    required this.indicator2,
    required this.label2,
    required this.quantity2,
    required this.total2,
    required this.total3,
    required this.totalTotal,
    required this.label3,
    this.onRemove,
  }) : super(key: key);

  @override
  State<PassengerWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<PassengerWidget> {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left: labels + icons + quantities
        Expanded(
          flex: 58,
          child: Container(
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                SizedBox(width: 8),
                Text(
                  widget.label3,
                  style: const TextStyle(color: Colors.black54),
                ),
                SizedBox(width: 6),

                // First indicator with stacked quantity
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Image.asset(
                      'assets/images/${widget.indicator}.png',
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                    Positioned(
                      top: 6,
                      right: -6,
                      child: Text('${widget.quantity}'),
                    ),
                  ],
                ),

                SizedBox(width: 12),

                // Second indicator + quantity
                Image.asset(
                  'assets/images/${widget.indicator2}.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.cover,
                ),
                SizedBox(width: 2),
                Text('${widget.quantity2}'),
              ],
            ),
          ),
        ),

        // Middle: total count (uses provided totalTotal)
        Expanded(
          flex: 8,
          child: Container(
            alignment: Alignment.center,
            child: Text(
              '× ${widget.totalTotal}',
              style: const TextStyle(color: Colors.blue),
            ),
          ),
        ),

        // Right: combined price/total3
        Expanded(
          flex: 16,
          child: Container(
            alignment: Alignment.centerRight,
            child: Text(
              '× ${widget.total3.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.black54),
            ),
          ),
        ),

        // Remove button (conditional)
        Expanded(
          flex: 8,
          child: SizedBox.shrink()          
        ),
      ],
    );
  }
}
