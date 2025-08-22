import 'package:flutter/material.dart';// Import where showRemoveBtnInSummaryList is defined

class ItemWidget extends StatefulWidget {
  final String indicator;
  final String label;
  final int quantity;
  final double total;
  // final bool visible;
  final VoidCallback? onRemove;

  const ItemWidget({
    Key? key,
    required this.indicator,
    required this.label,
    required this.quantity,
    required this.total,
    // required this.visible,
    this.onRemove,
  }) : super(key: key);

  @override
  State<ItemWidget> createState() => _ItemWidgetState();
}

class _ItemWidgetState extends State<ItemWidget> {
  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: widget.quantity > 0,
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
                '× ${widget.quantity}',
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
