// ignore_for_file: non_constant_identifier_names

import 'package:flutter/foundation.dart';

/// =====================
/// PRICES (double)
/// =====================
double pr_babystroller = 0.0;
double pr_d1d2 = 0.0;
double pr_d2d3 = 0.0;
double pr_d3d4 = 0.0;
double pr_d4d5 = 0.0;
double pr_d5d6 = 0.0;
double pr_details = 0.0;          // price_details (null safe fallback)
double pr_dog = 0.0;
double pr_durian = 0.0;
double pr_gastank = 0.0;
double pr_goat = 0.0;
double pr_luggage = 0.0;
double pr_odourfruits = 0.0;
double pr_passengerAdult = 0.0;
double pr_passengerBaby = 0.0;
double pr_passengerBlind = 0.0;
double pr_passengerDeaf = 0.0;
double pr_passengerMute = 0.0;
double pr_pets = 0.0;
double pr_rooster = 0.0;
double pr_shoppingBag = 0.0;
double pr_snake = 0.0;
double pr_sod1 = 0.0;             // price_sod1
double pr_stop_point1 = 0.0;
double pr_stop_point2 = 0.0;
double pr_stop_point3 = 0.0;
double pr_stop_point4 = 0.0;
double pr_stop_point5 = 0.0;
double pr_stop_point6 = 0.0;
double pr_supportstick = 0.0;
double pr_tupperWare = 0.0;
double pr_wetfood = 0.0;
double pr_wheelchair = 0.0;

/// =====================
/// COUNTS (int, reactive for UI)
/// =====================
ValueNotifier<int> qty_babystroller = ValueNotifier<int>(0);
ValueNotifier<int> qty_d1d2 = ValueNotifier<int>(0);
ValueNotifier<int> qty_d2d3 = ValueNotifier<int>(0);
ValueNotifier<int> qty_d3d4 = ValueNotifier<int>(0);
ValueNotifier<int> qty_d4d5 = ValueNotifier<int>(0);
ValueNotifier<int> qty_d5d6 = ValueNotifier<int>(0);
ValueNotifier<int> qty_dog = ValueNotifier<int>(0);
ValueNotifier<int> qty_durian = ValueNotifier<int>(0);
ValueNotifier<int> qty_gastank = ValueNotifier<int>(0);
ValueNotifier<int> qty_goat = ValueNotifier<int>(0);
ValueNotifier<int> qty_luggage = ValueNotifier<int>(0);
ValueNotifier<int> qty_odourfruits = ValueNotifier<int>(0);
ValueNotifier<int> qty_passengerAdult = ValueNotifier<int>(0);
ValueNotifier<int> qty_passengerBaby = ValueNotifier<int>(0);
ValueNotifier<int> qty_pets = ValueNotifier<int>(0);
ValueNotifier<int> qty_pin = ValueNotifier<int>(0);
ValueNotifier<int> qty_rooster = ValueNotifier<int>(0);
ValueNotifier<int> qty_shoppingBag = ValueNotifier<int>(0);
ValueNotifier<int> qty_snake = ValueNotifier<int>(0);
ValueNotifier<int> qty_supportstick = ValueNotifier<int>(0);
ValueNotifier<int> qty_tupperWare = ValueNotifier<int>(0);
ValueNotifier<int> qty_wetfood = ValueNotifier<int>(0);
ValueNotifier<int> qty_wheelchair = ValueNotifier<int>(0);

ValueNotifier<int> totalPinCharges = ValueNotifier<int>(0);
ValueNotifier<int> tips1Amount = ValueNotifier<int>(0);
ValueNotifier<int> tips2Amount = ValueNotifier<int>(0);



/// =====================
/// Passenger disability flags (bool)
/// =====================
ValueNotifier<bool> ct_passengerBlind = ValueNotifier<bool>(false);
ValueNotifier<bool> ct_passengerMute  = ValueNotifier<bool>(false);
ValueNotifier<bool> ct_passengerDeaf  = ValueNotifier<bool>(false);

ValueNotifier<double> km_sod1 = ValueNotifier<double>(0);
ValueNotifier<double> km_d1d2 = ValueNotifier<double>(0);
ValueNotifier<double> km_d2d3 = ValueNotifier<double>(0);
ValueNotifier<double> km_d3d4 = ValueNotifier<double>(0);
ValueNotifier<double> km_d4d5 = ValueNotifier<double>(0);
ValueNotifier<double> km_d5d6 = ValueNotifier<double>(0);

ValueNotifier<String> passengerName = ValueNotifier<String>('');
ValueNotifier<String> passengerPhone = ValueNotifier<String>('');
ValueNotifier<String> passengerSelfie = ValueNotifier<String>('');
