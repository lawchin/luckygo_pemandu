import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // For GeoPoint
import 'package:luckygo_pemandu/jobFilter/filter_jobs_helper.dart'; // exports class ShortJob

// in global.dart
class JobCalc {
  final double roadKm;
  final int etaMin;
  const JobCalc({required this.roadKm, required this.etaMin});
}

// Global variables for user session and profile
class Gv {
  // ───────────────────────────────────────────────────────────
  // ROAD results cache (shared across pages; key is anchor-aware)
  static Map<String, JobCalc> roadByJob = {};

  /// 🔔 Notifies listeners whenever new ROAD results are stored.
  static ValueNotifier<int> roadVersion = ValueNotifier<int>(0);

  /// Store a ROAD calc and publish the anchor used for that calc.
  /// Use this from FilterJobsOneStream after each Distance Matrix response.
  static void putRoadCalc({
    required String key,
    required double km,
    required int etaMin,
    required double anchorLat,
    required double anchorLng,
  }) {
    roadByJob[key] = JobCalc(roadKm: km, etaMin: etaMin);
    roadAnchorLat = anchorLat;
    roadAnchorLng = anchorLng;
    roadVersion.value++; // trigger UI (e.g., Bucket123) to rebuild
  }

  static String loggedUser = '';
  static String userName = '';
  static String negara = '';
  static String negeri = '';
  static String kawasan = '';
  static String bahasa = '';

  // Current location
  static GeoPoint? driverGp;
  static double driverLat = 0.0;
  static double driverLng = 0.0;

  // Lite job core details
  static String liteJobId        = '';   // 0
  static dynamic passengerPhone = '';
  static String passengerName    = '';   // 2
  static int    passengerCount   = 0;    // 3
  static double totalKm          = 0.0;  // 4
  static double totalPrice       = 0.0;  // 5
  static int    markerCount      = 0;    // 6

  // Addresses
  static String sAdd1            = '';   // 7
  static String sAdd2            = '';   // 8
  static String dAdd1            = '';   // 9
  static String dAdd2            = '';   // 10

  // Coordinates
  static double sLat             = 0.0;  // 11
  static double sLng             = 0.0;  // 12
  static double dLat             = 0.0;  // 13
  static double dLng             = 0.0;  // 14

  // Passenger disabilities
  static bool   isBlind          = false; // 15
  static bool   isDeaf           = false; // 16
  static bool   isMute           = false; // 17

  // Item counts
  static int wheelchairCount     = 0;    // 18
  static int supportStickCount   = 0;    // 19
  static int babyStrollerCount   = 0;    // 20
  static int shoppingBagCount    = 0;    // 21
  static int luggageCount        = 0;    // 22
  static int petsCount           = 0;    // 23
  static int dogCount            = 0;    // 24
  static int goatCount           = 0;    // 25
  static int roosterCount        = 0;    // 26
  static int snakeCount          = 0;    // 27
  static int durianCount         = 0;    // 28
  static int odourFruitsCount    = 0;    // 29
  static int wetFoodCount        = 0;    // 30
  static int tupperwareCount     = 0;    // 31
  static int gasTankCount        = 0;    // 32
  static int tips1Amount         = 0;    // 33
  static int tips2Amount         = 0;    // 34

  static int groupCapability     = 0;
  static bool form2Completed     = false;
  static bool registrationApproved     = false;

  // Latest numbers for currently selected job / details page
  static double roadKm = 0.0;  // driving distance to pickup for selected job
  static double flyKm  = 0.0;  // straight-line distance (used by 4–14)
  static int roadEta   = 0;    // minutes

  static ValueNotifier<bool> showPresenter = ValueNotifier(false);
  static double distanceDriverToPickup = 0.0;  // convenience distance holder
  static String googleApiKey = 'AIzaSyDa5S3_IbRkjAJsH53VIXca0ZPLm9WcSHw';

  // ───────────────────────────────────────────────────────────
  // Bucket 4 (5.1–7.5 km by AIR) shortlist, globally shareable
  // Fill this from your filter page and read it from B123(). Use the setter to update and notify listeners.
  static List<ShortJob> bucket4Jobs = const [];
  static ValueNotifier<int> bucket4Version = ValueNotifier<int>(0); // increments on set
  static DateTime? bucket4LastBuiltAt;

  static void setBucket4Jobs(List<ShortJob> jobs) {
    bucket4Jobs = List<ShortJob>.unmodifiable(jobs);
    bucket4LastBuiltAt = DateTime.now();
    bucket4Version.value = bucket4Version.value + 1; // notify observers
  }

  // ───────────────────────────────────────────────────────────
  // Anchor used when ROAD results were computed (so lookups are consistent)
  static double roadAnchorLat = 0.0;
  static double roadAnchorLng = 0.0;

  // Canonical key used by FilterJobsOneStream and Bucket123
  static String roadKey(String jobId, double sLat, double sLng, double aLat, double aLng) =>
      '$jobId@$sLat,$sLng@$aLat,$aLng';

  // Convenience getter to fetch ROAD calc for a job using the last published anchor
  static JobCalc? getRoadCalcFor(String jobId, double sLat, double sLng) {
    if (roadAnchorLat == 0.0 && roadAnchorLng == 0.0) return null;
    final k = roadKey(jobId, sLat, sLng, roadAnchorLat, roadAnchorLng);
    return roadByJob[k];
  }

  static String liteJobData = '';
  // static Map<String, dynamic>? liteJobData;
  static String driverSelfie = '';
  static String currency = '';
  // static String orderStatus = '';
}
