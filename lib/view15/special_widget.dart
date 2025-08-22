import 'package:flutter/material.dart';// Import where showRemoveBtnInSummaryList is defined

class SpecialWidget extends StatefulWidget {
  final bool isVisible;
  final String indicator;
  final String label;
  final String label2;
  final double total;
  final VoidCallback? onRemove;

  const SpecialWidget({
    Key? key,
    required this.isVisible,
    required this.indicator,
    required this.label,
    required this.label2,
    required this.total,
    this.onRemove,
  }) : super(key: key);

  @override
  State<SpecialWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<SpecialWidget> {
  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: widget.isVisible,
      child: Row(
        children: [
          // Indicator + Label
          Expanded(
            flex: 60,
            child: Container(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/${widget.indicator}.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),

          // Quantity
          Expanded(
            flex: 10,
            child: Container(
              alignment: Alignment.center,
              child: Text(
                '${widget.label2}',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          ),

          // Total
          Expanded(
            flex: 20,
            child: Container(
              alignment: Alignment.centerRight,
              child: Text(
                widget.total.toStringAsFixed(2),
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          ),

          // Remove Button (Reactive)
        ],
      ),
    );
  }
}
