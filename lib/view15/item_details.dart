import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/view15/destination_widget.dart';
import 'package:luckygo_pemandu/view15/global_variables_for_view15.dart';
import 'package:luckygo_pemandu/view15/item_widget.dart';
import 'package:luckygo_pemandu/view15/special_widget.dart';

class ItemDetails extends StatelessWidget {
  const ItemDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final future = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('passenger_account')
        .doc(Gv.passengerPhone)
        .collection('my_active_job')
        .doc(Gv.passengerPhone)
        .get();

    return SizedBox(
      height: 220, // safe to embed inside View15
      child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (snap.hasError) {
            return Center(
              child: Text('Error: ${snap.error}', style: const TextStyle(color: Colors.red)),
            );
          }
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: Text('No document found'));
          }

          final data = snap.data!.data() ?? {};

          // ============== PRICES ==============
          pr_babystroller   = _toD(data['price_babystroller']);
          pr_d1d2           = _toD(data['price_d1d2']);
          pr_d2d3           = _toD(data['price_d2d3']);
          pr_d3d4           = _toD(data['price_d3d4']);
          pr_d4d5           = _toD(data['price_d4d5']);
          pr_d5d6           = _toD(data['price_d5d6']);
          pr_details        = _toD(data['price_details']); // null-safe fallback
          pr_dog            = _toD(data['price_dog']);
          pr_durian         = _toD(data['price_durian']);
          pr_gastank        = _toD(data['price_gasTank']);
          pr_goat           = _toD(data['price_goat']);
          pr_luggage        = _toD(data['price_luggage']);
          pr_odourfruits    = _toD(data['price_odourFruits']);
          pr_passengerAdult = _toD(data['price_passengerAdult']);
          pr_passengerBaby  = _toD(data['price_passengerBaby']);
          pr_passengerBlind = _toD(data['price_passengerBlind']);
          pr_passengerDeaf  = _toD(data['price_passengerDeaf']);
          pr_passengerMute  = _toD(data['price_passengerMute']);
          pr_pets           = _toD(data['price_pets']);
          pr_rooster        = _toD(data['price_rooster']);
          pr_shoppingBag    = _toD(data['price_shoppingBag']);
          pr_snake          = _toD(data['price_snake']);


          pr_sod1           = _toD(data['price_sod1']);
          pr_d1d2           = _toD(data['price_d1d2']);
          pr_d2d3           = _toD(data['price_d2d3']);
          pr_d3d4           = _toD(data['price_d3d4']);
          pr_d4d5           = _toD(data['price_d4d5']);
          pr_d5d6           = _toD(data['price_d5d6']);

          km_sod1.value      = _toD(data['km_sod1']);
          km_d1d2.value      = _toD(data['km_d1d2']);
          km_d2d3.value      = _toD(data['km_d2d3']);
          km_d3d4.value      = _toD(data['km_d3d4']);
          km_d4d5.value      = _toD(data['km_d4d5']);
          km_d5d6.value      = _toD(data['km_d5d6']);


          pr_supportstick   = _toD(data['price_supportStick']);
          pr_tupperWare     = _toD(data['price_tupperware']);
          pr_wetfood        = _toD(data['price_wetFood']);
          pr_wheelchair     = _toD(data['price_wheelchair']);



          // ============== COUNTS (ValueNotifier<int>) ==============
          qty_babystroller.value   = _toI(data['qty_babyStroller']   ?? data['babystroller_qty']);
          qty_dog.value            = _toI(data['qty_dog']            ?? data['dog_qty']);
          qty_durian.value         = _toI(data['qty_durian']         ?? data['durian_qty']);
          qty_gastank.value        = _toI(data['qty_gasTank']        ?? data['gas_tank_qty']);
          qty_goat.value           = _toI(data['qty_goat']           ?? data['goat_qty']);
          qty_luggage.value        = _toI(data['qty_luggage']        ?? data['luggage_qty']);
          qty_odourfruits.value    = _toI(data['qty_odourFruits']    ?? data['odour_fruits_qty']);
          qty_passengerAdult.value = _toI(data['qty_passengerAdult'] ?? data['passenger_adult_qty']);
          qty_passengerBaby.value  = _toI(data['qty_passengerBaby']  ?? data['passenger_baby_qty']);
          qty_pets.value           = _toI(data['qty_pets']           ?? data['pets_qty']);
          qty_pin.value            = _toI(data['qty_pin']            ?? data['pin_qty']);
          qty_rooster.value        = _toI(data['qty_rooster']        ?? data['rooster_qty']);
          qty_shoppingBag.value    = _toI(data['qty_shoppingBag']    ?? data['shopping_bag_qty']);
          qty_snake.value          = _toI(data['qty_snake']          ?? data['snake_qty']);
          qty_supportstick.value   = _toI(data['qty_supportStick']   ?? data['support_stick_qty']);
          qty_tupperWare.value     = _toI(data['qty_tupperware']     ?? data['tupperware_qty']);
          qty_wetfood.value        = _toI(data['qty_wetFood']        ?? data['wet_food_qty']);
          qty_wheelchair.value     = _toI(data['qty_wheelchair']     ?? data['wheelchair_qty']);

          tips1Amount.value     = _toI(data['tips_amount1']);
          tips2Amount.value     = _toI(data['tips_amount2']);

          // Optional total pin charges if you store it
          totalPinCharges.value    = _toI(data['price_totalPin']);

          // ============== FLAGS (ValueNotifier<bool>) ==============
          ct_passengerBlind.value  = _toB(data['qty_blind']) || pr_passengerBlind > 0;
          ct_passengerMute.value   = _toB(data['qty_mute'])  || pr_passengerMute  > 0;
          ct_passengerDeaf.value   = _toB(data['qty_deaf'])  || pr_passengerDeaf  > 0;

 

          // Debug print example (as you used earlier)
          if (data.containsKey('tips_amount1') && data['tips_amount1'] != null) {
          }

return Column(
  children: [
    // Top card (fixed, always visible)
    // Card(
    //   elevation: 4,
    //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    //   child: Padding(
    //     padding: const EdgeInsets.all(16),
    //     child: Row(
    //       children: [
    //         CircleAvatar(
    //           radius: 32,
    //           backgroundImage: passengerSelfie.value.isNotEmpty
    //               ? NetworkImage(passengerSelfie.value)
    //               : const AssetImage('assets/default_avatar.png') as ImageProvider,
    //         ),
    //         const SizedBox(width: 16),
    //         Expanded(
    //           child: Column(
    //             crossAxisAlignment: CrossAxisAlignment.start,
    //             children: [
    //               Text(
    //                 passengerName.value,
    //                 style: const TextStyle(
    //                   fontSize: 18,
    //                   fontWeight: FontWeight.bold,
    //                 ),
    //               ),
    //               const SizedBox(height: 6),
    //               Text(
    //                 passengerPhone.value,
    //                 style: const TextStyle(
    //                   fontSize: 16,
    //                   color: Colors.grey,
    //                 ),
    //               ),
    //             ],
    //           ),
    //         ),
    //       ],
    //     ),
    //   ),
    // ),

    const SizedBox(height: 8),

    // Scrollable content
Expanded(
  child: SingleChildScrollView(
    padding: const EdgeInsets.all(12),
    child: Column(
      children: [
        if (qty_passengerBaby.value > 0)
          ItemWidget(
            indicator: 'ind_baby', label: 'Passenger Baby',
            quantity: qty_passengerBaby.value, total: pr_passengerBaby,
          ),

        if (qty_passengerAdult.value > 0)
          ItemWidget(
            indicator: 'ind_adult', label: 'Passenger Adult',
            quantity: qty_passengerAdult.value, total: pr_passengerAdult,
          ),

        if (ct_passengerBlind.value)
          SpecialWidget(
            indicator: 'blind_symbol', label: 'Passenger Blind',
            label2: 'Yes', total: 0.00, isVisible: ct_passengerBlind.value,
          ),

        if (ct_passengerDeaf.value)
          SpecialWidget(
            indicator: 'deaf_symbol', label: 'Passenger Deaf',
            label2: 'Yes', total: 0.00, isVisible: ct_passengerDeaf.value,
          ),

        if (ct_passengerMute.value)
          SpecialWidget(
            indicator: 'mute_symbol', label: 'Passenger Mute',
            label2: 'Yes', total: 0.00, isVisible: ct_passengerMute.value,
          ),

        if (tips1Amount.value > 0)
          ItemWidget(
            indicator: 'tips', label: 'Tips 1',
            quantity: 1, total: tips1Amount.value.toDouble(),
          ),

        if (tips2Amount.value > 0)
          ItemWidget(
            indicator: 'tips', label: 'Tips 2',
            quantity: 1, total: tips2Amount.value.toDouble(),
          ),

        if (qty_rooster.value > 0 || pr_rooster > 0)
          ItemWidget(
            indicator: 'ind_rooster', label: 'Rooster',
            quantity: qty_rooster.value, total: pr_rooster,
          ),

        if (qty_babystroller.value > 0 || pr_babystroller > 0)
          ItemWidget(
            indicator: 'ind_stroller', label: 'Baby Stroller',
            quantity: qty_babystroller.value, total: pr_babystroller,
          ),

        if (qty_dog.value > 0 || pr_dog > 0)
          ItemWidget(
            indicator: 'ind_dog', label: 'Dog',
            quantity: qty_dog.value, total: pr_dog,
          ),

        if (qty_durian.value > 0 || pr_durian > 0)
          ItemWidget(
            indicator: 'ind_durian', label: 'Durian',
            quantity: qty_durian.value, total: pr_durian,
          ),

        if (qty_gastank.value > 0 || pr_gastank > 0)
          ItemWidget(
            indicator: 'ind_gastank', label: 'Gas Tank',
            quantity: qty_gastank.value, total: pr_gastank,
          ),

        if (qty_goat.value > 0 || pr_goat > 0)
          ItemWidget(
            indicator: 'ind_goat', label: 'Goat',
            quantity: qty_goat.value, total: pr_goat,
          ),

        if (qty_luggage.value > 0 || pr_luggage > 0)
          ItemWidget(
            indicator: 'ind_luggage1', label: 'Luggage',
            quantity: qty_luggage.value, total: pr_luggage,
          ),

        if (qty_odourfruits.value > 0 || pr_odourfruits > 0)
          ItemWidget(
            indicator: 'ind_odourfruits', label: 'Odour Fruits',
            quantity: qty_odourfruits.value, total: pr_odourfruits,
          ),

        if (qty_pets.value > 0 || pr_pets > 0)
          ItemWidget(
            indicator: 'ind_pets', label: 'Pets',
            quantity: qty_pets.value, total: pr_pets,
          ),

        if (qty_shoppingBag.value > 0 || pr_shoppingBag > 0)
          ItemWidget(
            indicator: 'ind_shopping1', label: 'Shopping Bag',
            quantity: qty_shoppingBag.value, total: pr_shoppingBag,
          ),

        if (qty_snake.value > 0 || pr_snake > 0)
          ItemWidget(
            indicator: 'ind_snake', label: 'Snake',
            quantity: qty_snake.value, total: pr_snake,
          ),

        if (qty_supportstick.value > 0 || pr_supportstick > 0)
          ItemWidget(
            indicator: 'ind_supportstick', label: 'Support Stick',
            quantity: qty_supportstick.value, total: pr_supportstick,
          ),

        if (qty_tupperWare.value > 0 || pr_tupperWare > 0)
          ItemWidget(
            indicator: 'ind_tupperware', label: 'Tupperware',
            quantity: qty_tupperWare.value, total: pr_tupperWare,
          ),

        if (qty_wetfood.value > 0 || pr_wetfood > 0)
          ItemWidget(
            indicator: 'ind_wetfood', label: 'Wet Food',
            quantity: qty_wetfood.value, total: pr_wetfood,
          ),

        if (qty_wheelchair.value > 0 || pr_wheelchair > 0)
          ItemWidget(
            indicator: 'ind_wheelchair', label: 'Wheelchair',
            quantity: qty_wheelchair.value, total: pr_wheelchair,
          ),

        if (km_sod1.value > 0)
          DesWidget(
            img1: 'ind_passenger', img2: 'd1',
            desKm: km_sod1.value, desCharges: pr_sod1,
            visible: true,
          ),

        if (km_d1d2.value > 0)
          DesWidget(
            img1: 'd1', img2: 'd2',
            desKm: km_d1d2.value, desCharges: pr_d1d2,
            visible: true,
          ),

        if (km_d2d3.value > 0)
          DesWidget(
            img1: 'd2', img2: 'd3',
            desKm: km_d2d3.value, desCharges: pr_d2d3,
            visible: true,
          ),

        if (km_d3d4.value > 0)
          DesWidget(
            img1: 'd3', img2: 'd4',
            desKm: km_d3d4.value, desCharges: pr_d3d4,
            visible: true,
          ),

        if (km_d4d5.value > 0)
          DesWidget(
            img1: 'd4', img2: 'd5',
            desKm: km_d4d5.value, desCharges: pr_d4d5,
            visible: true,
          ),

        if (km_d5d6.value > 0)
          DesWidget(
            img1: 'd5', img2: 'finish',
            desKm: km_d5d6.value, desCharges: pr_d5d6,
            visible: true,
          ),

        if (qty_pin.value > 0)
          ItemWidget(
            indicator: 'pin', label: 'Extra stop point',
            quantity: qty_pin.value, total: totalPinCharges.value.toDouble(),
          ),
      ],
    ),
  ),
),

  ],
);
        
        
        
        
        },
      ),
    );
  }
}

// ── helpers ──────────────────────────────────────────────────────────────────
double _toD(Object? v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0.0;
}

int _toI(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

bool _toB(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v.toLowerCase() == 'true' || v == '1';
  return false;
}

String _toS(Object? v) {
  if (v == null) return '';
  return v.toString();
}