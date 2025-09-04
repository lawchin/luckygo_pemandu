import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/driver_accept_job/driver_accept_job.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/jobFilter/filter_job_one_stream2.dart';
import 'package:luckygo_pemandu/view15/countdown_text.dart';
import 'package:luckygo_pemandu/view15/global_variables_for_view15.dart';
import 'package:luckygo_pemandu/view15/item_details.dart';

class View15 extends StatelessWidget {
  const View15({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final countdownKey = GlobalKey<CountdownTextState>();

    // One-time read of the active job doc for this passenger
    final priceDocFuture = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('passenger_account')
        .doc(Gv.passengerPhone)
        .collection('my_active_job')
        .doc(Gv.passengerPhone)
        .get();

    return PopScope(
      canPop: false, // BLOCK device/gesture back on this page
      onPopInvoked: (didPop) {
        // If the system tried to pop but we blocked it, show a brief message
        if (!didPop) {
          final messenger = ScaffoldMessenger.of(context);
          messenger.clearSnackBars();
          messenger.showSnackBar(
            const SnackBar(
              duration: Duration(milliseconds: 900),
              content: Text('Back is disabled on this page'),
            ),
          );
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            future: priceDocFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              }

              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error: ${snap.error}',
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (snap.hasData && snap.data!.exists) {
                final data = snap.data!.data()!;
                passengerName.value   = (data['job_creator_name'] ?? '') as String;
                passengerPhone.value  = (data['job_created_by'] ?? '') as String;
                passengerSelfie.value = (data['passenger_selfie'] ?? '') as String;
                
                Gv.passengerGp = data['z_source'] is GeoPoint
                    ? data['z_source'] as GeoPoint
                    : const GeoPoint(0.0, 0.0);
              }

              // ---------- UI ----------
              return Padding(
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
                        Row(
                          children: [
                            const Text('Price breakdown:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),



                              onPressed: () async {
                                countdownKey.currentState?.cancel();
                                await FirebaseFirestore.instance
                                    .collection(Gv.negara)
                                    .doc(Gv.negeri)
                                    .collection('passenger_account')
                                    .doc('${passengerPhone.value}')
                                    .collection('my_active_job')
                                    .doc('${passengerPhone.value}')
                                    .update({
                                  'found_a_driver': true,
                                  'lite_job_id': Gv.liteJobId,
                                  'job_is_available': false,
                                  'job_is_taken_by': Gv.loggedUser,
                                  'order_status': 'driver_accepted_job',
                                  'x_driver_selfie': Gv.driverSelfie,
                                  'x_driver_geopoint': GeoPoint(Gv.driverGp!.latitude, Gv.driverGp!.longitude),
                                });
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const FilterJobsOneStream2()),
                                );}                      

                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // 👇 Only this area scrolls
                        const Expanded(
                          child: ItemDetails(),
                        ),

                        const Divider(height: 20, thickness: 2),

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
                            Text('${Gv.currency} ${_rm2(Gv.totalPrice)}',
                                style: Theme.of(context).textTheme.titleMedium),
                          ],
                        ),

                        const Divider(height: 14, thickness: 2),

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

                            final badges = <Widget>[];
                            if (Gv.isBlind) badges.add(_badge('Blind', context));
                            if (Gv.isDeaf)  badges.add(_badge('Deaf', context));
                            if (Gv.isMute)  badges.add(_badge('Mute', context));
                            for (final e in chips.entries) {
                              badges.add(_badge('${e.key} x${e.value}', context));
                            }

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (int i = 0; i < badges.length; i++) ...[
                                    Transform.scale(scale: 1.25, child: badges[i]),
                                    if (i != badges.length - 1) const SizedBox(width: 16),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 4),

                        Row(
                          children: [
                            Text('Eta ${Gv.roadEta} minutes',
                                style: const TextStyle(height: 0.5, fontSize: 12)),
                          ],
                        ),

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
                        const Divider(height: 14, thickness: 2),

                        // Top Passenger Card
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundImage: passengerSelfie.value.isNotEmpty
                                      ? NetworkImage(passengerSelfie.value)
                                      : const AssetImage('assets/default_avatar.png') as ImageProvider,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        passengerName.value,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        passengerPhone.value,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        Center(
                          child: SizedBox(
                            width: 300,
                            height: 80,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32),
                                ),
                                textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                              onPressed: () async {
                                countdownKey.currentState?.cancel();
                                await FirebaseFirestore.instance
                                    .collection(Gv.negara)
                                    .doc(Gv.negeri)
                                    .collection('passenger_account')
                                    .doc('${passengerPhone.value}')
                                    .collection('my_active_job')
                                    .doc('${passengerPhone.value}')
                                    .update({
                                  'found_a_driver': true,
                                  'job_is_available': false,
                                  'job_is_taken_by': Gv.loggedUser,
                                  'lite_job_id': Gv.liteJobId,
                                  'order_status': 'driver_accepted_job',
                                  'x_driver_distance_to_source': Gv.roadKm,
                                  'x_driver_eta_to_source': Gv.roadEta,
                                  'x_driver_name': Gv.userName,
                                  'x_driver_geopoint': GeoPoint(Gv.driverLat, Gv.driverLng),
                                  'x_driver_selfie': Gv.driverSelfie,
                                  'x_driver_vehicle_details' : Gv.driverVehicleDetails
                                });
                                if (context.mounted) {
                                  countdownKey.currentState?.cancel();
                                  Navigator.of(context).pop(); // close this page
                                  Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const DAJ()),
                                  );
                                }
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  const Spacer(flex: 2),
                                  const Expanded(
                                    flex: 6,
                                    child: Center(child: Text('Accept')),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Center(
                                      child: Builder(
                                        builder: (ctx) => CountdownText(
                                          key: countdownKey,
                                          onFinished: () async {
                                            // only called if not cancelled
                                            await FirebaseFirestore.instance
                                                .collection(Gv.negara)
                                                .doc(Gv.negeri)
                                                .collection('active_job')
                                                .doc('active_job_lite')
                                                .set({Gv.liteJobId: Gv.liteJobData}, SetOptions(merge: true));
                                            if (context.mounted) Navigator.of(context).pop();
                                          },
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// =============== Helpers ===============
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

