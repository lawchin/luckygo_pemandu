import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/jobFilter/mini_route_overlay_map.dart';
import 'package:luckygo_pemandu/jobFilter/straight_road_map.dart';
import 'package:url_launcher/url_launcher.dart';

class JobDetailsPage extends StatelessWidget {
  const JobDetailsPage({super.key});
Future<void> _openExternalGoogleMaps() async {
  final sLat = Gv.sLat, sLng = Gv.sLng, dLat = Gv.dLat, dLng = Gv.dLng;

  if (sLat == null || sLng == null || dLat == null || dLng == null) {
    // graceful fallback
    return;
  }

  // Google Maps directions URL (works without API key and opens the app on Android)
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&origin=${sLat.toStringAsFixed(6)},${sLng.toStringAsFixed(6)}'
    '&destination=${dLat.toStringAsFixed(6)},${dLng.toStringAsFixed(6)}'
    '&travelmode=driving'
  );

  // Prefer external app
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    // Fallback to in-app browser if needed
    await launchUrl(uri, mode: LaunchMode.inAppWebView);
  }
}

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

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
    }..removeWhere((_, v) => (v == null) || v <= 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header: passenger + price
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/images/ind_passenger.png', width: 48, height: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(Gv.passengerName?.isNotEmpty == true ? Gv.passengerName! : (Gv.passengerPhone ?? ''),
                        style: t.titleLarge),
                    const SizedBox(height: 4),
                    Text('Pax: ${Gv.passengerCount} • Markers: ${Gv.markerCount}', style: t.bodyMedium),
                  ],
                ),
              ),
              Text('RM ${Gv.totalPrice.toStringAsFixed(2)}', style: t.titleLarge),
            ],
          ),

          const SizedBox(height: 12),
          Text('Job ID', style: t.labelMedium),
          SelectableText(Gv.liteJobId ?? '-', style: t.bodyMedium),

          const SizedBox(height: 16),
          const Divider(),

          // From
          Text('Pickup', style: t.titleMedium),
          const SizedBox(height: 6),
          _addrRow('assets/images/ind_passenger.png', Gv.sAdd1, Gv.sAdd2, context),
          const SizedBox(height: 6),
          _coordRow('Lat/Lng', Gv.sLat, Gv.sLng, context),

          const SizedBox(height: 12),

          // To
          Text('Destination', style: t.titleMedium),
          const SizedBox(height: 6),
          _addrRow('assets/images/finish.png', Gv.dAdd1, Gv.dAdd2, context),
          const SizedBox(height: 6),
          _coordRow('Lat/Lng', Gv.dLat, Gv.dLng, context),

          const SizedBox(height: 16),
          const Divider(),

          // Distance & fare info
          Row(
            children: [
              const Icon(Icons.straighten, size: 20),
              const SizedBox(width: 6),
              Text('Air distance: ${Gv.distanceDriverToPickup.toStringAsFixed(2)} km (air)', style: t.bodyMedium),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.route, size: 20, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text('Trip km (quoted): ${Gv.totalKm.toStringAsFixed(1)} km', style: t.bodyMedium),
            ],
          ),

          // ⬇️ add this after the "Trip km (quoted)" row
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StraightAndRoadDistanceMap()),
              );
            },
            icon: const Icon(Icons.map_outlined),
            label: const Text('Open Map (straight + road)'),
          ),

          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: _openExternalGoogleMaps,
            icon: const Icon(Icons.navigation_outlined),
            label: const Text('Open in Google Maps (free)'),
          ),

          const SizedBox(height: 16),
          const Divider(),

          // Accessibility flags
          Text('Accessibility', style: t.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (Gv.isBlind == true) _chipIcon('Blind', 'assets/images/blind_symbol.png', context),
              if (Gv.isDeaf == true)  _chipIcon('Deaf', 'assets/images/deaf_symbol.png', context),
              if (Gv.isMute == true)  _chipIcon('Mute', 'assets/images/mute_symbol.png', context),
              if (chips.isEmpty)
                Text('No special items/needs', style: t.bodyMedium),
            ],
          ),

          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Items', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips.entries.map((e) => _qtyChip(e.key, e.value, context)).toList(),
            ),
          ],

          const SizedBox(height: 24),
          // CTA
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              // TODO: wire action (accept, navigate, etc.)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Action tapped (wire this to your flow)')),
              );
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Proceed'),
          ),

          const SizedBox(height: 16),

      // ⬇️ mini overlay in bottom-left (draggable by the user later)
      if (Gv.sLat != null && Gv.sLng != null && Gv.dLat != null && Gv.dLng != null)
        MiniRouteOverlayMap(
          driver: LatLng(Gv.driverLat, Gv.driverLng),
          pickup: LatLng(Gv.sLat!, Gv.sLng!),
          dest:   LatLng(Gv.dLat!, Gv.dLng!),
          googleApiKey: Gv.googleApiKey, // <- make sure you expose your key in Gv
          onTapFullScreen: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StraightAndRoadDistanceMap()),
            );
          },
        ),



        ],
      ),
    );
  }

  // ---------- small UI helpers ----------
  Widget _addrRow(String icon, String? l1, String? l2, BuildContext ctx) {
    final t = Theme.of(ctx).textTheme;
    final line1 = (l1 ?? '').isEmpty ? '-' : l1!;
    final line2 = (l2 ?? '').isEmpty ? '' : l2!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Image.asset(icon, width: 28, height: 28),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line1, style: t.bodyMedium),
              if (line2.isNotEmpty) Text(line2, style: t.bodySmall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _coordRow(String label, double? lat, double? lng, BuildContext ctx) {
    final t = Theme.of(ctx).textTheme;
    final latStr = (lat ?? 0).toStringAsFixed(6);
    final lngStr = (lng ?? 0).toStringAsFixed(6);
    return Row(
      children: [
        const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
        const SizedBox(width: 6),
        Text('$label: $latStr, $lngStr', style: t.bodySmall),
      ],
    );
  }

  Widget _chipIcon(String label, String asset, BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(asset, width: 18, height: 18),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }

  Widget _qtyChip(String label, int qty, BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _iconFor(label) != null
              ? Image.asset(_iconFor(label)!, width: 18, height: 18)
              : const SizedBox(width: 0, height: 0),
          if (_iconFor(label) != null) const SizedBox(width: 6),
          Text('$label x$qty'),
        ],
      ),
    );
  }

  String? _iconFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('wheelchair')) return 'assets/images/ind_wheelchair.png';
    if (l.contains('blind')) return 'assets/images/blind_symbol.png';
    if (l.contains('deaf')) return 'assets/images/deaf_symbol.png';
    if (l.contains('mute')) return 'assets/images/mute_symbol.png';
    if (l.contains('stick')) return 'assets/images/ind_supportstick.png';
    if (l.contains('stroller')) return 'assets/images/ind_stroller.png';
    if (l.contains('bag')) return 'assets/images/ind_shopping1.png';
    if (l.contains('luggage')) return 'assets/images/ind_luggage1.png';
    if (l.contains('tupperware')) return 'assets/images/ind_tupperware.png';
    if (l.contains('gas')) return 'assets/images/ind_gastank.png';
    if (l.contains('wet food')) return 'assets/images/ind_wetfood.png';
    if (l.contains('odour')) return 'assets/images/ind_odourfruits.png';
    if (l.contains('durian')) return 'assets/images/ind_durian.png';
    if (l.contains('pets')) return 'assets/images/ind_pets.png';
    if (l.contains('dog')) return 'assets/images/ind_dog.png';
    if (l.contains('goat')) return 'assets/images/ind_goat.png';
    if (l.contains('rooster')) return 'assets/images/ind_rooster.png';
    if (l.contains('snake')) return 'assets/images/ind_snake.png';
    return null;
  }
}
