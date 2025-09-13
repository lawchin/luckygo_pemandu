import 'package:flutter/material.dart';

class EtaVisualRow extends StatelessWidget {
  final double roadKm;
  final int etaMinutes;
  final int index6;

  const EtaVisualRow({
    super.key,
    required this.roadKm,
    required this.etaMinutes,
    required this.index6,
  });

  List<Widget> _buildPassengerIcons() {
    final icons = <String>[
      'assets/images/ind_passenger.png',
      if (index6 >= 3) 'assets/images/d1.png',
      if (index6 >= 4) 'assets/images/d2.png',
      if (index6 >= 5) 'assets/images/d3.png',
      if (index6 >= 6) 'assets/images/d4.png',
      if (index6 >= 7) 'assets/images/d5.png',
      'assets/images/finish.png',
    ];

    return icons.map((path) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Image.asset(path, width: 30, height: 30, fit: BoxFit.contain),
    )).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etaMinutes >= 0 ? 'ETA: $etaMinutes min' : 'ETA unavailable',
              style: const TextStyle(fontSize: 10, color: Colors.black87, height: 0.8),
            ),
            Row(
              children: [
                Image.asset('assets/images/car.png', width: 30, height: 30, fit: BoxFit.contain),
                const SizedBox(width: 6),
                Column(
                  children: [
                    Text(
                      '${roadKm.toStringAsFixed(1)} km',
                      style: const TextStyle(fontSize: 10, color: Colors.black87, height: 1.8),
                    ),
                    const Text('→', style: TextStyle(fontSize: 20, color: Colors.red, height: 0.1)),
                  ],
                ),
                const SizedBox(width: 6),
                ..._buildPassengerIcons(),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
