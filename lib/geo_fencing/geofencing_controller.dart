import 'package:flutter/foundation.dart';

enum BlockMode { none, full, limited }

class GeofencingController {
  GeofencingController._();
  static final instance = GeofencingController._();

  /// Current geofence enforcement mode seen by the rest of the app.
  final ValueNotifier<BlockMode> mode = ValueNotifier(BlockMode.none);

  /// When true, geofencing is temporarily ignored (used by DAJ page).
  final ValueNotifier<bool> bypass = ValueNotifier(false);

  void enableBypass()  => bypass.value = true;   // call in DAJ.initState
  void disableBypass() => bypass.value = false;  // call in DAJ.dispose / after Payment
}
