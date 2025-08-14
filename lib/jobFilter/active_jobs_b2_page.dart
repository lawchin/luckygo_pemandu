import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/jobFilter/job_details_page.dart';

class ActiveJobsB2Page extends StatefulWidget {
  const ActiveJobsB2Page({super.key});

  @override
  State<ActiveJobsB2Page> createState() => _ActiveJobsB2PageState();
}

class _ActiveJobsB2PageState extends State<ActiveJobsB2Page> {
  late final DocumentReference<Map<String, dynamic>> _docRef;

  @override
  void initState() {
    super.initState();
    _docRef = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('active_job')
        .doc('active_job_lite');
  }

  Future<void> _forceRefresh() async {
    // One-shot GET to warm cache; UI still driven by StreamBuilder.
    try {
      await _docRef.get(const GetOptions(source: Source.server));
    } catch (_) {
      // ignore – stream keeps going
    }
  }

  @override
  Widget build(BuildContext context) {
    if (Gv.negara.isEmpty || Gv.negeri.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('B2 Jobs (1.51–5.0 km)')),
        body: const Center(child: Text('⚠ Set Gv.negara & Gv.negeri first.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('B2 Jobs (1.51–5.0 km)'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _forceRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _forceRefresh,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _docRef.snapshots(includeMetadataChanges: true),
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
            if (raw == null || raw.isEmpty) {
              return const Center(child: Text("⚠ 'active_job_lite' is empty."));
            }

            // Build entries
            final parsed = <({List<String> parts, double dKm})>[];
            int badRows = 0;

            final driverLat = Gv.driverLat;
            final driverLng = Gv.driverLng;

            raw.forEach((_, v) {
              if (v is! String) { badRows++; return; }
              final parts = v.split('·').map((x) => x.trim()).toList(growable: false);
              if (parts.length != 33) { badRows++; return; }

              final sLat = _toDbl(parts, 11);
              final sLng = _toDbl(parts, 12);
              if (!_validCoord(sLat, sLng)) { badRows++; return; }

              final dKm = _haversineKm(driverLat, driverLng, sLat, sLng);
              if (dKm >= 1.51 && dKm <= 5.0) {
                parsed.add((parts: parts, dKm: double.parse(dKm.toStringAsFixed(2))));
              }
            });

            // Sort by distance asc, then price desc
            parsed.sort((a, b) {
              final c = a.dKm.compareTo(b.dKm);
              if (c != 0) return c;
              final ap = _toDbl(a.parts, 5);
              final bp = _toDbl(b.parts, 5);
              return bp.compareTo(ap);
            });

            if (parsed.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No jobs in 1.51–5.0 km right now.'),
                    if (badRows > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('Skipped $badRows malformed rows.',
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _forceRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _statusBar(meta, parsed.length, badRows),
                const Divider(height: 0),
                Expanded(
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    itemCount: parsed.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p   = parsed[i].parts;
                      final dKm = parsed[i].dKm;

                      final name   = p[2].isEmpty ? p[1] : p[2];
                      final price  = _toDbl(p, 5);
                      final pax    = _toInt(p, 3);
                      final sAdd1  = p[7].trim().isEmpty ? 'NOT PROVIDED' : p[7];
                      final sAdd2  = p[8].trim().isEmpty ? '' : p[8];
                      final dAdd1  = p[9].trim().isEmpty ? 'NOT PROVIDED' : p[9];
                      final dAdd2  = p[10].trim().isEmpty ? '' : p[10];
                      final marker = _toInt(p, 6);

return Card(
  margin: const EdgeInsets.only(bottom: 12),
  elevation: 2,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  clipBehavior: Clip.antiAlias,
  child: InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: () {
      Gv.distanceDriverToPickup = dKm; // keep your behavior
      _applyPackedToGlobals(p);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const JobDetailsPage()),
      );
    },
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
          // --- TITLE ROW (icons + quoted km on left, price on right) ---
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
                  // show quoted trip km (field 4) like your other page
                  Text('${_toDbl(p, 4).toStringAsFixed(1)} km'),
                ],
              ),
              Text('RM ${price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),

          const Divider(height: 14, thickness: 2),

          // --- From / To with icons + overlay pax (like the other page) ---
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

          // --- BADGES (blind/deaf/mute + counts) ---
          Builder(
            builder: (_) {
              final isBlind = _toBool(p, 15);
              final isDeaf  = _toBool(p, 16);
              final isMute  = _toBool(p, 17);

              final chips = <String, int>{
                'Wheelchair': _toInt(p, 18),
                'Stick': _toInt(p, 19),
                'Stroller': _toInt(p, 20),
                'Bags': _toInt(p, 21),
                'Luggage': _toInt(p, 22),
                'Pets': _toInt(p, 23),
                'Dog': _toInt(p, 24),
                'Goat': _toInt(p, 25),
                'Rooster': _toInt(p, 26),
                'Snake': _toInt(p, 27),
                'Durian': _toInt(p, 28),
                'Odour fruit': _toInt(p, 29),
                'Wet food': _toInt(p, 30),
                'Tupperware': _toInt(p, 31),
                'Gas tank': _toInt(p, 32),
              }..removeWhere((_, v) => v <= 0);

              return SingleChildScrollView(
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
              );
            },
          ),

          const SizedBox(height: 6),

          // --- STATS ROW: air distance + pax + markers (keep your info) ---
          Row(
            children: [
              _chipStat(icon: Icons.straighten, label: '${dKm.toStringAsFixed(2)} km (air)'),
              const SizedBox(width: 8),
              _chipStat(icon: Icons.people, label: 'pax $pax'),
              const SizedBox(width: 8),
              if (marker >= 2) _chipStat(icon: Icons.route, label: 'markers $marker'),
            ],
          ),

          const SizedBox(height: 6),

          // --- CAR ROW + marker strip (like the other page) ---
          Row(
            children: [
              Image.asset('assets/images/car.png',
                  width: 32, height: 32, fit: BoxFit.contain),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${dKm.toStringAsFixed(2)} km (air)',
                      style: const TextStyle(height: 0.6, fontSize: 12)),
                  const Text('⟶',
                      style: TextStyle(height: 0.1, fontSize: 30, color: Colors.red)),
                ],
              ),
              const SizedBox(width: 6),
              if (marker >= 2) markerStrip(marker, size: 28, spacing: 1),
            ],
          ),

          const SizedBox(height: 6),
        ],
      ),
    ),
  ),
);
                    
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------- UI bits ----------
  Widget _statusBar(SnapshotMetadata meta, int count, int badRows) {
    final isCache = meta.isFromCache;
    final text = isCache ? 'OFFLINE (cache)' : 'LIVE';
    final color = isCache ? Colors.orange : Colors.green;
    final sub = badRows > 0 ? ' • skipped $badRows bad rows' : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: color.withOpacity(0.08),
      child: Row(
        children: [
          Icon(isCache ? Icons.cloud_off : Icons.cloud_done, size: 16, color: color),
          const SizedBox(width: 6),
          Text('$text • ${DateTime.now().toIso8601String().substring(11,19)}'),
          const Spacer(),
          Text('B2: $count$sub'),
        ],
      ),
    );
  }

  Widget _chipStat({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black54),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// ---------- helpers ----------
int _toInt(List<String> p, int i) => (i < p.length) ? int.tryParse(p[i]) ?? 0 : 0;
double _toDbl(List<String> p, int i) => (i < p.length) ? double.tryParse(p[i]) ?? 0.0 : 0.0;

bool _validCoord(double lat, double lng) {
  if (lat == 0.0 && lng == 0.0) return false;
  return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

/// Haversine distance (km) between two lat/lng points.
double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0088;
  double _rad(double d) => d * math.pi / 180.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_rad(lat1)) * math.cos(_rad(lat2)) *
          math.sin(dLon / 2) * math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return R * c;
}

void _applyPackedToGlobals(List<String> p) {
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
  // (15..32) keep as-is if needed later
}
bool _toBool(List<String> p, int i) => (i < p.length) && p[i].toLowerCase() == 'true';

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
  final mid = count - 2;
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
