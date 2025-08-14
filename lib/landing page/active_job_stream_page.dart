import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';

class ActiveJobsStreamPage extends StatelessWidget {
  const ActiveJobsStreamPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (Gv.negara.isEmpty || Gv.negeri.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Jobs')),
        body: const Center(child: Text('⚠ Set Gv.negara & Gv.negeri first.')),
      );
    }

    final docRef = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('active_job')
        .doc('active_job_lite');

    // IMPORTANT: includeMetadataChanges so UI repaints on cache/pending writes too
    final stream = docRef.snapshots(includeMetadataChanges: true);

    return Scaffold(
      appBar: AppBar(title: const Text('Active Jobs')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('❌ ${snap.error}'));
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text("⚠ No 'active_job_lite' document found."));
          }

          final meta = snap.data!.metadata;
          final raw = snap.data!.data();
          debugPrint(
            '🔁 active_job_lite changed | fromCache=${meta.isFromCache} '
            'pendingWrites=${meta.hasPendingWrites} '
            'len=${(raw ?? {}).length} ts=${DateTime.now()}',
          );

          if (raw == null || raw.isEmpty) {
            return const Center(child: Text("⚠ 'active_job_lite' is empty."));
          }

          // Build entries without silently dropping non-strings.
          final entries = <MapEntry<String, List<String>>>[];
          raw.forEach((k, v) {
            if (v is String) {
              entries.add(MapEntry(k, v.split('·').map((x) => x.trim()).toList()));
            } else {
              debugPrint("⚠ Key '$k' is ${v.runtimeType}, expected String. Skipping.");
            }
          });

          final valid = entries.where((e) => e.value.length >= 33).toList();
          if (valid.isEmpty) {
            return const Center(child: Text('No active jobs right now.'));
          }

          // Example sort: highest price first
          valid.sort((a, b) {
            final ap = _toDbl(a.value, 5);
            final bp = _toDbl(b.value, 5);
            return bp.compareTo(ap);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: valid.length,
            itemBuilder: (context, i) {
              final parts = valid[i].value;

              final name   = parts[2].isEmpty ? parts[1] : parts[2]; // passengerName fallback to phone
              final price  = _toDbl(parts, 5);
              final km     = _toDbl(parts, 4);
              final pax    = _toInt(parts, 3);
              final sAdd1  = (parts[7].trim().isEmpty) ? 'NOT PROVIDED' : parts[7];
              final sAdd2  = (parts[8].trim().isEmpty) ? 'NOT PROVIDED' : parts[8];
              final dAdd1  = (parts[9].trim().isEmpty) ? 'NOT PROVIDED' : parts[9];
              final dAdd2  = (parts[10].trim().isEmpty) ? 'NOT PROVIDED' : parts[10];
              final marker = _toInt(parts, 6);

              final isBlind = _toBool(parts, 15);
              final isDeaf  = _toBool(parts, 16);
              final isMute  = _toBool(parts, 17);

              // counts shown only if > 0
              final chips = <String, int>{
                'Wheelchair': _toInt(parts, 18),
                'Stick': _toInt(parts, 19),
                'Stroller': _toInt(parts, 20),
                'Bags': _toInt(parts, 21),
                'Luggage': _toInt(parts, 22),
                'Pets': _toInt(parts, 23),
                'Dog': _toInt(parts, 24),
                'Goat': _toInt(parts, 25),
                'Rooster': _toInt(parts, 26),
                'Snake': _toInt(parts, 27),
                'Durian': _toInt(parts, 28),
                'Odour fruit': _toInt(parts, 29),
                'Wet food': _toInt(parts, 30),
                'Tupperware': _toInt(parts, 31),
                'Gas tank': _toInt(parts, 32),
              }..removeWhere((_, v) => v <= 0);


return Card(
  margin: const EdgeInsets.only(bottom: 12),
  elevation: 2,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  clipBehavior: Clip.antiAlias, // ensure gradient & ink ripple respect radius
  child: InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () {
      _applyPackedToGlobals(parts);
      // Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverMap()));
    },
    child: Container(
      decoration: BoxDecoration(
        // card already clips; still mirror radius for gradient
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade50,   // lighter top
            Colors.blue.shade100,  // mid
            Colors.blue.shade200,  // darker bottom
          ],
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // title row (icons + km on left, price on right)
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
                  Text('${km.toStringAsFixed(1)} km'),
                ],
              ),
              Text(
                'RM ${price.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),

          const Divider(height: 14, thickness: 2),

          // From / To with icons + overlay pax
          _addrWithIcon(
            'assets/images/ind_passenger.png',
            overlayNumber: pax,
            l1: sAdd1,
            l2: sAdd2,
            ctx: context,
          ),
          const SizedBox(height: 4),
          _addrWithIcon(
            'assets/images/finish.png',
            l1: dAdd1,
            l2: dAdd2,
            ctx: context,
          ),

          const Divider(height: 14, thickness: 2),

          // BADGES — one line, scrollable (icons-only, number bottom-right)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (isBlind) _badge('Blind', context),
                if (isDeaf)  _badge('Deaf', context),
                if (isMute)  _badge('Mute', context),
                for (final e in chips.entries) _badge('${e.key} x${e.value}', context),
              ].map((w) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: w,
              )).toList(),
            ),
          ),

          const SizedBox(height: 4),
          Row(
            children: [
              Image.asset('assets/images/car.png',
                  width: 32, height: 32, fit: BoxFit.contain),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${Gv.distanceDriverToPickup} 9 km', style: const TextStyle(height: 0.6, fontSize: 12)),
                  const Text('⟶', style: TextStyle(height: 0.1, fontSize: 30, color: Colors.red)),
                ],
              ),
              const SizedBox(width: 6),
              if (marker >= 2) markerStrip(marker, size: 28, spacing: 1),
              const SizedBox(width: 8),
            ],
          ),

          const SizedBox(height: 8),
        ],
      ),
    ),
  ),
);
         
            
            
            },
          );
        },
      ),
    );
  }
}

// ---------- helpers (no models, all globals) ----------

int _toInt(List<String> p, int i) => (i < p.length) ? int.tryParse(p[i]) ?? 0 : 0;
double _toDbl(List<String> p, int i) => (i < p.length) ? double.tryParse(p[i]) ?? 0.0 : 0.0;
bool _toBool(List<String> p, int i) => (i < p.length) && p[i].toLowerCase() == 'true';

void _applyPackedToGlobals(List<String> p) {
  // Safely guard indexes; assumes p.length >= 33
  Gv.liteJobId         = p[0];
  Gv.passengerPhone    = p[1];
  Gv.passengerName     = p[2];
  Gv.passengerCount    = _toInt(p, 3);
  Gv.totalKm           = _toDbl(p, 4);
  Gv.totalPrice        = _toDbl(p, 5);
  Gv.markerCount       = _toInt(p, 6);

  Gv.sAdd1             = p[7];
  Gv.sAdd2             = p[8];
  Gv.dAdd1             = p[9];
  Gv.dAdd2             = p[10];

  Gv.sLat              = _toDbl(p, 11);
  Gv.sLng              = _toDbl(p, 12);
  Gv.dLat              = _toDbl(p, 13);
  Gv.dLng              = _toDbl(p, 14);

  Gv.isBlind           = _toBool(p, 15);
  Gv.isDeaf            = _toBool(p, 16);
  Gv.isMute            = _toBool(p, 17);

  Gv.wheelchairCount   = _toInt(p, 18);
  Gv.supportStickCount = _toInt(p, 19);
  Gv.babyStrollerCount = _toInt(p, 20);
  Gv.shoppingBagCount  = _toInt(p, 21);
  Gv.luggageCount      = _toInt(p, 22);
  Gv.petsCount         = _toInt(p, 23);
  Gv.dogCount          = _toInt(p, 24);
  Gv.goatCount         = _toInt(p, 25);
  Gv.roosterCount      = _toInt(p, 26);
  Gv.snakeCount        = _toInt(p, 27);
  Gv.durianCount       = _toInt(p, 28);
  Gv.odourFruitsCount  = _toInt(p, 29);
  Gv.wetFoodCount      = _toInt(p, 30);
  Gv.tupperwareCount   = _toInt(p, 31);
  Gv.gasTankCount      = _toInt(p, 32);
}

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
      // Icon with optional overlay number
      Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(iconPath, width: 40, height: 40, fit: BoxFit.contain),
          if (overlayNumber != null)
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

// simple chip (kept in case you still use elsewhere)
Widget _chip(String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: const Color(0x1F000000)),
  ),
  child: Text(text),
);

// =============== ICON-ONLY BADGE (image + bottom-right green number) ===============
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
          Image.asset(
            iconPath,
            width: 26, // ~30% bigger than 20
            height: 26,
            fit: BoxFit.contain,
          ),
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
                // sharp 1px white outline for readability
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
  if (match != null) {
    return int.tryParse(match.group(1) ?? '');
  }
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

  return 'assets/images/special2.png'; // fallback
}

// =============== ICON STAT (icon with overlaid number) =================
Widget _iconStat(String assetPath, Object value, {bool isDouble = false, int decimals = 0}) {
  String display;
  if (isDouble) {
    final v = (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? 0.0;
    display = v.toStringAsFixed(decimals);
  } else {
    final v = (value is num) ? value.toInt() : int.tryParse(value.toString()) ?? 0;
    display = v.toString();
  }

  return Stack(
    alignment: Alignment.center,
    children: [
      Image.asset(assetPath, width: 26, height: 26, fit: BoxFit.contain),
      Positioned(
        bottom: 0,
        right: 0,
        child: Text(
          display,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
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
  );
}

// =============== MARKER STRIP (sequence icons for markerCount 2..7) ===============
Widget markerStrip(int markerCount, {double size = 28, double spacing = 2}) {
  final count = markerCount.clamp(2, 7);
  final icons = <String>['assets/images/ind_passenger.png'];
  final mid = count - 2; // how many of d1..d5
  for (var i = 1; i <= mid; i++) {
    icons.add('assets/images/d$i.png'); // d1..d5
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
