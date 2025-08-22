import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/view15/item_details.dart';

class View15 extends StatelessWidget {
  const View15({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // Single price-details doc for this passenger/active job
    final priceDocFuture = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('passenger_account')
        .doc(Gv.passengerPhone)
        .collection('my_active_job')
        .doc(Gv.passengerPhone)
        .get();

    // Same look/feel as Bucket123 card:
    return 

    Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.shade50,
                    Colors.blue.shade100,
                    Colors.blue.shade200,
                  ],
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ───────────────── Price breakdown (TOP, 200px scroll) ─────────────────
                  const Text('Price breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const ItemDetails(),
                  // FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  //   future: priceDocFuture,
                  //   builder: (context, snap) {
                  //     if (snap.connectionState == ConnectionState.waiting) {
                  //       return const SizedBox(
                  //         height: 200,
                  //         child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  //       );
                  //     }
                  //     if (snap.hasError) {
                  //       return SizedBox(
                  //         height: 200,
                  //         child: Center(
                  //           child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red)),
                  //         ),
                  //       );
                  //     }
                  //     if (!snap.hasData || !snap.data!.exists) {
                  //       return const SizedBox(
                  //         height: 200,
                  //         child: Center(child: Text('No price details found')),
                  //       );
                  //     }

                  //     final data = snap.data!.data() ?? {};
                  //     // Show ALL fields in doc (or you can whitelist certain keys if preferred)
                  //     final entries = data.entries.toList()
                  //       ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));

                  //     return SizedBox(
                  //       height: 200,
                  //       child:
                        
                        
                        
                  //       SingleChildScrollView(
                  //         child: Column(
                  //           children: entries.map((e) {
                  //             final valueStr = e.value == null ? 'null' : e.value.toString();
                  //             return Padding(
                  //               padding: const EdgeInsets.symmetric(vertical: 4),
                  //               child: Row(
                  //                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  //                 children: [
                  //                   // Keep it simple (no Expanded outside of Row/Flex issues)
                  //                   Flexible(child: Text(e.key, style: t.bodyMedium)),
                  //                   const SizedBox(width: 12),
                  //                   Text(valueStr, style: t.bodyMedium),
                  //                 ],
                  //               ),
                  //             );
                  //           }).toList(),
                  //         ),
                  //       ),
                      
                      
                      
                      
                      
                  //     );
                  //   },
                  // ),

                  const Divider(height: 20, thickness: 2),

                  // ───────────────── TITLE ROW (exact as Bucket123) ─────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Image.asset('assets/images/ind_passenger.png',
                              width: 32, height: 32, fit: BoxFit.contain),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(Icons.arrow_forward, size: 20, color: Colors.grey),
                          ),
                          Image.asset('assets/images/finish.png',
                              width: 32, height: 32, fit: BoxFit.contain),
                          const SizedBox(width: 8),
                          Text('${_km1(Gv.totalKm)} km'),
                        ],
                      ),
                      Text('RM ${_rm2(Gv.totalPrice)}',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),

                  const Divider(height: 14, thickness: 2),

                  // ───────────────── From / To with icons + overlay pax (same helper) ─────────────────
                  _addrWithIcon(
                    'assets/images/ind_passenger.png',
                    overlayNumber: Gv.passengerCount,
                    l1: Gv.sAdd1,
                    l2: Gv.sAdd2,
                    ctx: context,
                  ),
                  const SizedBox(height: 4),
                  _addrWithIcon(
                    'assets/images/finish.png',
                    l1: Gv.dAdd1,
                    l2: Gv.dAdd2,
                    ctx: context,
                  ),

                  const Divider(height: 14, thickness: 2),

                  // ───────────────── BADGES (same rendering style) ─────────────────
                  Builder(
                    builder: (_) {
                      final chips = <String, int>{
                        'Wheelchair': Gv.wheelchairCount,
                        'Stick': Gv.supportStickCount,
                        'Stroller': Gv.babyStrollerCount,
                        'Bags': Gv.shoppingBagCount,
                        'Luggage': Gv.luggageCount,
                        'Pets': Gv.petsCount,
                        'Dog': Gv.dogCount,
                        'Goat': Gv.goatCount,
                        'Rooster': Gv.roosterCount,
                        'Snake': Gv.snakeCount,
                        'Durian': Gv.durianCount,
                        'Odour fruit': Gv.odourFruitsCount,
                        'Wet food': Gv.wetFoodCount,
                        'Tupperware': Gv.tupperwareCount,
                        'Gas tank': Gv.gasTankCount,
                      }..removeWhere((_, v) => v <= 0);

                      // first the three boolean disability tags
                      final badges = <Widget>[];
                      if (Gv.isBlind) badges.add(_badge('Blind', context));
                      if (Gv.isDeaf)  badges.add(_badge('Deaf', context));
                      if (Gv.isMute)  badges.add(_badge('Mute', context));
                      // then the item counts as "Label xN"
                      for (final e in chips.entries) {
                        badges.add(_badge('${e.key} x${e.value}', context));
                      }

                      // return SingleChildScrollView(
                      //   scrollDirection: Axis.horizontal,
                      //   child: Row(
                      //     children: badges
                      //         .map((w) => Padding(padding: const EdgeInsets.only(right: 8), child: w))
                      //         .toList(),
                      //   ),
                      // );

return Wrap(
  spacing: 16,
  runSpacing: 12,
  children: badges
      .map((w) => Transform.scale(
            scale: 1.25
            , // increase badge size by 20%
            child: w,
          ))
      .toList(),
);



                    },
                  ),

                  const SizedBox(height: 10),

                  // ───────────────── ETA (from Gv.roadEta) ─────────────────
                  Row(
                    children: [
                      Text('Eta ${Gv.roadEta} minutes',
                          style: const TextStyle(height: 0.5, fontSize: 12)),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // ───────────────── CAR ROW + marker strip — show driver→pickup distance (Gv.roadKm) ─────────────────
                  Row(
                    children: [
                      Image.asset('assets/images/car.png',
                          width: 32, height: 32, fit: BoxFit.contain),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_km1(Gv.roadKm)} km',
                              style: const TextStyle(height: 0.6, fontSize: 12)),
                          const Text('⟶',
                              style: TextStyle(height: 0.1, fontSize: 30, color: Colors.red)),
                        ],
                      ),
                      const SizedBox(width: 6),
                      if (Gv.markerCount >= 2) markerStrip(Gv.markerCount, size: 28, spacing: 1),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  
  }
}

// =============== Helpers copied to match Bucket123’s look & feel ===============

String _km1(double v) => v.isFinite ? v.toStringAsFixed(1) : '-';
String _rm2(double v) => v.isFinite ? v.toStringAsFixed(2) : '-';

Widget _addrWithIcon(
  String iconPath, {
  int? overlayNumber,
  required String l1,
  required String l2,
  required BuildContext ctx,
}) {
  final t = Theme.of(ctx).textTheme;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(iconPath, width: 40, height: 40, fit: BoxFit.contain),
          if (overlayNumber != null && overlayNumber > 0)
            Positioned(
              bottom: 18,
              right: 5,
              child: Text(
                overlayNumber.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.green,
                  shadows: [
                    Shadow(offset: Offset(-1, -1), color: Colors.white),
                    Shadow(offset: Offset( 1, -1), color: Colors.white),
                    Shadow(offset: Offset(-1,  1), color: Colors.white),
                    Shadow(offset: Offset( 1,  1), color: Colors.white),
                    Shadow(offset: Offset( 0, -1), color: Colors.white),
                    Shadow(offset: Offset( 0,  1), color: Colors.white),
                    Shadow(offset: Offset(-1,  0), color: Colors.white),
                    Shadow(offset: Offset( 1,  0), color: Colors.white),
                  ],
                ),
              ),
            ),
        ],
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (l1.isNotEmpty) Text(l1, style: t.bodyMedium),
            if (l2.isNotEmpty) Text(l2, style: t.bodySmall),
          ],
        ),
      ),
    ],
  );
}

Widget _badge(String text, BuildContext ctx) {
  final iconPath = _iconForBadge(text);
  final qty = _extractCount(text);

  return Container(
    decoration: BoxDecoration(
      color: Theme.of(ctx).colorScheme.surfaceVariant,
      borderRadius: BorderRadius.circular(10),
    ),
    padding: const EdgeInsets.all(4),
    child: Stack(
      children: [
        if (iconPath != null)
          Image.asset(iconPath, width: 26, height: 26, fit: BoxFit.contain),
        if (qty != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: Text(
              qty.toString(),
              style: Theme.of(ctx).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.green,
                shadows: const [
                  Shadow(offset: Offset(-1, -1), color: Colors.white),
                  Shadow(offset: Offset( 1, -1), color: Colors.white),
                  Shadow(offset: Offset(-1,  1), color: Colors.white),
                  Shadow(offset: Offset( 1,  1), color: Colors.white),
                  Shadow(offset: Offset( 0, -1), color: Colors.white),
                  Shadow(offset: Offset( 0,  1), color: Colors.white),
                  Shadow(offset: Offset(-1,  0), color: Colors.white),
                  Shadow(offset: Offset( 1,  0), color: Colors.white),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

int? _extractCount(String text) {
  final match = RegExp(r'x\s*(\d+)').firstMatch(text.toLowerCase());
  if (match != null) return int.tryParse(match.group(1) ?? '');
  return null;
}

String? _iconForBadge(String label) {
  final l = label.toLowerCase();
  if (l.contains('wheelchair')) return 'assets/images/ind_wheelchair.png';
  if (l.contains('blind'))      return 'assets/images/blind_symbol.png';
  if (l.contains('deaf'))       return 'assets/images/deaf_symbol.png';
  if (l.contains('mute'))       return 'assets/images/mute_symbol.png';
  if (l.contains('stick'))      return 'assets/images/ind_supportstick.png';
  if (l.contains('stroller'))   return 'assets/images/ind_stroller.png';
  if (l.contains('bag') || l.contains('shopping')) return 'assets/images/ind_shopping1.png';
  if (l.contains('luggage'))    return 'assets/images/ind_luggage1.png';
  if (l.contains('tupperware')) return 'assets/images/ind_tupperware.png';
  if (l.contains('gas'))        return 'assets/images/ind_gastank.png';
  if (l.contains('wet food'))   return 'assets/images/ind_wetfood.png';
  if (l.contains('odour'))      return 'assets/images/ind_odourfruits.png';
  if (l.contains('durian'))     return 'assets/images/ind_durian.png';
  if (l.contains('pets'))       return 'assets/images/ind_pets.png';
  if (l.contains('dog'))        return 'assets/images/ind_dog.png';
  if (l.contains('goat'))       return 'assets/images/ind_goat.png';
  if (l.contains('rooster'))    return 'assets/images/ind_rooster.png';
  if (l.contains('snake'))      return 'assets/images/ind_snake.png';
  return 'assets/images/special2.png';
}

Widget markerStrip(int markerCount, {double size = 28, double spacing = 2}) {
  final count = markerCount.clamp(2, 7);
  final icons = <String>['assets/images/ind_passenger.png'];
  final mid = count - 2; // d1..d5 in the middle
  for (var i = 1; i <= mid; i++) {
    icons.add('assets/images/d$i.png');
  }
  icons.add('assets/images/finish.png');

  return SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var i = 0; i < icons.length; i++) ...[
          Image.asset(icons[i], width: size, height: size, fit: BoxFit.contain),
          if (i != icons.length - 1) SizedBox(width: spacing),
        ],
      ],
    ),
  );
}
