import 'package:flutter/material.dart';

class ISV extends StatelessWidget {
  final String wc;
  final String sk;
  final String sr;
  final String sb;
  final String lge;
  final String pt;
  final String dg;
  final String gt;
  final String rt;
  final String sn;
  final String dr;
  final String of;
  final String wf;
  final String tw;
  final String gs;

  const ISV({
    super.key,
    required this.wc,
    required this.sk,
    required this.sr,
    required this.sb,
    required this.lge,
    required this.pt,
    required this.dg,
    required this.gt,
    required this.rt,
    required this.sn,
    required this.dr,
    required this.of,
    required this.wf,
    required this.tw,
    required this.gs,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      _show('ind_wheelchair.png', wc),
      _show('ind_supportstick.png', sk),
      _show('ind_stroller.png', sr),
      _show('shopping_1.png', sb),
      _show('luggage_1.png', lge),
      _show('ind_pets.png', pt),
      _show('ind_dog.png', dg),
      _show('ind_goat.png', gt),
      _show('ind_rooster.png', rt),
      _show('ind_snake.png', sn),
      _show('ind_durian.png', dr),
      _show('ind_odourfruits.png', of),
      _show('ind_wetfood.png', wf),
      _show('ind_tupperware.png', tw),
      _show('ind_gastank.png', gs),
    ].whereType<Widget>().toList();

    if (items.isEmpty) return const SizedBox.shrink(); // 🔴 Hides everything including divider

    return Column( // 🔴 Wrap with Column to include Divider
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 8, thickness: 1), // 🔴 Only shown if items exist
        SizedBox(
          height: 40,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: items),
          ),
        ),
      ],
    );
  }

  Widget? _show(String assetName, String count) {
    final value = int.tryParse(count) ?? 0;
    if (value < 1) return null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Image.asset(
            'assets/images/$assetName',
            width: 24,
            height: 24,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 2),
          Text(
            '$value',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
