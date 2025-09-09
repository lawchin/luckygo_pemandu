// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:luckygo_pemandu/global.dart'; // uses direct globals: negara, negeri, passengerPhone, etc.
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

class TellOthers extends StatefulWidget {
  const TellOthers({super.key});

  @override
  State<TellOthers> createState() => _TellOthersState();
}

class _TellOthersState extends State<TellOthers> {
  // --- Geo / addresses ---
  double? psgLat, psgLng, dstLat, dstLng;
  String? fromAddress, toAddress;

  // --- Passenger ---
  String? passengerName;
  String? passengerPhone;
  String? passengerImageUrl;

  // --- Driver ---
  String? driverName;
  String? driverPhone;
  String? driverImageUrl;

  // --- Vehicle ---
  String? carModel;
  String? carColor;
  String? carPlate;

  // --- Trip summary ---
  double? distanceKm;
  int? etaMinutes;
  DateTime? tripTime;

  bool _loading = true;
  String? _error;

  static const String _prefixText = "I'm driving now via LuckyGo";

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // ---------------- Helpers ----------------

  T? _get<T>(Map<String, dynamic> data, String key) {
    final v = data[key];
    if (v is T) return v;
    return null;
  }

  double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }

  int? _parseEtaMinutes(dynamic v) {
    if (v == null) return null;
    if (v is num) {
      final n = v.toDouble();
      if (n > 10000) {
        final mins = (n / 60).round();
        return mins > 20000 ? (n / 60000).round() : mins;
      }
      return n.round();
    }
    if (v is String) {
      final s = v.toLowerCase().trim();
      if (s.startsWith('pt') || s.startsWith('p')) {
        int mins = 0;
        final h = RegExp(r'(\d+)h').firstMatch(s)?.group(1);
        final m = RegExp(r'(\d+)m').firstMatch(s)?.group(1);
        if (h != null) mins += int.parse(h) * 60;
        if (m != null) mins += int.parse(m);
        if (mins > 0) return mins;
      }
      int mins = 0;
      final hm = RegExp(r'(\d+)\s*(hours?|hrs?|h)\b').firstMatch(s);
      final mm = RegExp(r'(\d+)\s*(minutes?|mins?|m)\b').firstMatch(s);
      if (hm != null) mins += int.parse(hm.group(1)!) * 60;
      if (mm != null) mins += int.parse(mm.group(1)!);
      if (mins > 0) return mins;
      final numeric = double.tryParse(s.replaceAll(RegExp('[^0-9.]'), ''));
      if (numeric != null) {
        if (numeric > 10000) {
          final mins2 = (numeric / 60).round();
          return mins2 > 20000 ? (numeric / 60000).round() : mins2;
        }
        return numeric.round();
      }
    }
    return null;
  }

  DateTime? _asDateTime(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is num) {
      final val = v.toInt();
      if (val > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(val, isUtc: true).toLocal();
      } else {
        return DateTime.fromMillisecondsSinceEpoch(val * 1000, isUtc: true).toLocal();
      }
    }
    if (v is String) {
      try { return DateTime.parse(v).toLocal(); } catch (_) {}
    }
    return null;
  }

  GeoPoint? _firstGeo(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v is GeoPoint) return v;
      if (v is Map) {
        final lat = _asDouble(v['lat'] ?? v['latitude']);
        final lng = _asDouble(v['lng'] ?? v['longitude']);
        if (lat != null && lng != null) return GeoPoint(lat, lng);
      }
    }
    return null;
  }

  GeoPoint? _latLngFromPairs(Map<String, dynamic> data, List<(String, String)> pairs) {
    for (final (latKey, lngKey) in pairs) {
      final lat = _asDouble(data[latKey]);
      final lng = _asDouble(data[lngKey]);
      if (lat != null && lng != null) return GeoPoint(lat, lng);
    }
    return null;
  }

  String _joinIfAny(List<String?> parts, {String sep = ', '}) {
    return parts.where((e) => e != null && e!.trim().isNotEmpty).map((e) => e!.trim()).join(sep);
  }

  String _fmtOffset(Duration off) {
    final sign = off.isNegative ? '-' : '+';
    final h = off.inHours.abs().toString().padLeft(2, '0');
    final m = off.inMinutes.remainder(60).abs().toString().padLeft(2, '0');
    return '$sign$h:$m';
  }

  String _addressOrNotProvided(String? a1, String? a2) {
    final joined = _joinIfAny([a1, a2]);
    return joined.isEmpty ? 'NOT PROVIDED' : joined;
  }

  bool _isTrivialPhone(String? s) {
    if (s == null) return true;
    final d = s.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return true;
    if (RegExp(r'^0+$').hasMatch(d)) return true; // all zeros
    return false;
  }

  String? _mapsLinkFromLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    return 'https://www.google.com/maps?q=$lat,$lng'; // slightly shorter form
  }

  String? _mapsLinkFromAddress(String? address) {
    if (address == null || address.trim().isEmpty || address == 'NOT PROVIDED') return null;
    final q = Uri.encodeComponent(address);
    return 'https://www.google.com/maps?q=$q';
  }

  String? _directionsLink({
    double? fromLat, double? fromLng,
    double? toLat, double? toLng,
    String? fromAddr, String? toAddr,
  }) {
    if (fromLat != null && fromLng != null && toLat != null && toLng != null) {
      return 'https://www.google.com/maps/dir/?api=1'
          '&origin=$fromLat,$fromLng'
          '&destination=$toLat,$toLng'
          '&travelmode=driving';
    }
    if (fromAddr != null && fromAddr.isNotEmpty && toAddr != null && toAddr.isNotEmpty) {
      final o = Uri.encodeComponent(fromAddr);
      final d = Uri.encodeComponent(toAddr);
      return 'https://www.google.com/maps/dir/?api=1'
          '&origin=$o'
          '&destination=$d'
          '&travelmode=driving';
    }
    return null;
  }

  // ------------- WhatsApp helpers (improved as requested) -------------

  /// Normalize phone to WhatsApp-friendly digits; converts "0123456789" to "60XXXXXXXXX" by default.
  /// Change [defaultCountryCode] if your default isn't Malaysia.
  String _normalizeMsisdn(String raw, {String defaultCountryCode = '60'}) {
    var s = raw.replaceAll(RegExp(r'\D'), '');
    if (s.isEmpty) return s;
    if (s.startsWith('00')) s = s.substring(2);        // 00XX → XX
    if (s.startsWith('0')) s = defaultCountryCode + s.substring(1); // 0XXXXXXXXX → 60XXXXXXXXX
    return s;
  }

  Future<void> _openWhatsAppWithMessage(String message, {String? phone}) async {
    final text = Uri.encodeComponent(message);

    // Prefer targeted chat when phone looks valid
    String? normalized;
    if (phone != null && phone.trim().isNotEmpty && !_isTrivialPhone(phone)) {
      normalized = _normalizeMsisdn(phone);
    }

    // 1) Try native app (with phone)
    if (normalized != null) {
      final uriApp = Uri.parse('whatsapp://send?phone=$normalized&text=$text');
      try {
        if (await canLaunchUrl(uriApp)) {
          if (await launchUrl(uriApp, mode: LaunchMode.externalApplication)) return;
        }
      } catch (_) {}
    }

    // 2) Try native app (no phone → composer)
    final uriAppNoPhone = Uri.parse('whatsapp://send?text=$text');
    try {
      if (await canLaunchUrl(uriAppNoPhone)) {
        if (await launchUrl(uriAppNoPhone, mode: LaunchMode.externalApplication)) return;
      }
    } catch (_) {}

    // 3) Fallback to wa.me (with phone)
    if (normalized != null) {
      final uriWebWithPhone = Uri.parse('https://wa.me/$normalized?text=$text');
      try {
        if (await canLaunchUrl(uriWebWithPhone)) {
          if (await launchUrl(uriWebWithPhone, mode: LaunchMode.externalApplication)) return;
        }
      } catch (_) {}
    }

    // 4) Fallback to wa.me (no phone → composer)
    final uriWebNoPhone = Uri.parse('https://wa.me/?text=$text');
    try {
      if (await canLaunchUrl(uriWebNoPhone)) {
        if (await launchUrl(uriWebNoPhone, mode: LaunchMode.externalApplication)) return;
      }
    } catch (_) {}

    // 5) Final fallback → system share sheet
    try {
      await Share.share(message);
      return;
    } catch (_) {}

    // 6) Last resort → copy to clipboard so user can paste manually
    await Clipboard.setData(ClipboardData(text: message));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('WhatsApp not available. Message copied to clipboard.')),
    );
  }

  // --------------------------- Firestore loader -----------------------

  Future<void> _loadData() async {
    setState(() { _loading = true; _error = null; });

    try {
      final n = Gv.negara;
      final s = Gv.negeri;
      final psgPhone = Gv.passengerPhone; // driver-side: active job lives under passenger

      if ((n == null || n.isEmpty) ||
          (s == null || s.isEmpty) ||
          (psgPhone == null || psgPhone.isEmpty)) {
        throw StateError('Missing negara/negeri/passengerPhone');
      }

      final ref = FirebaseFirestore.instance
          .collection(n)
          .doc(s)
          .collection('passenger_account')
          .doc(psgPhone)
          .collection('my_active_job')
          .doc(psgPhone);

      final snap = await ref.get();
      final data = (snap.data() ?? {}) as Map<String, dynamic>;

      // Source address
      final src1 = _get<String>(data, 'source_address1') ?? _get<String>(data, 'pickup_address1');
      final src2 = _get<String>(data, 'source_address2') ?? _get<String>(data, 'pickup_address2');
      fromAddress = _addressOrNotProvided(src1, src2);

      // Destination by qty_pin (0->d1 ... 5->d6)
      final extraPin = (_asInt(data['qty_pin']) ?? 0).clamp(0, 5);
      final pinIndex = extraPin + 1;
      final a1Key = 'd${pinIndex}_address1';
      final a2Key = 'd${pinIndex}_address2';
      final dA1 = _get<String>(data, a1Key);
      final dA2 = _get<String>(data, a2Key);
      toAddress = _addressOrNotProvided(dA1, dA2);

      // Pickup geo
      final pickupGeo = _firstGeo(data, [
        'source_geopoint','pickup_geopoint','source_location','pickup_location','source','pickup'
      ]) ?? _latLngFromPairs(data, [
        ('source_lat','source_lng'),('pickup_lat','pickup_lng'),('psg_lat','psg_lng'),
      ]);
      if (pickupGeo != null) { psgLat = pickupGeo.latitude; psgLng = pickupGeo.longitude; }

      // Destination geo (per selected pin first)
      final pinGeo = _firstGeo(data, [
        'd${pinIndex}_geopoint','d${pinIndex}_location'
      ]) ?? _latLngFromPairs(data, [
        ('d${pinIndex}_lat','d${pinIndex}_lng'),
      ]);
      final fallbackDestGeo = _firstGeo(data, [
        'd1_geopoint','destination_geopoint','destination_location','d1_location','destination','d1'
      ]) ?? _latLngFromPairs(data, [
        ('d1_lat','d1_lng'),('dest_lat','dest_lng'),
      ]);
      final destGeo = pinGeo ?? fallbackDestGeo;
      if (destGeo != null) { dstLat = destGeo.latitude; dstLng = destGeo.longitude; }

      // -------- Passenger (from job doc) --------
      passengerName     = _get<String>(data, 'job_creator_name') ?? _get<String>(data, 'passenger_name');
      passengerPhone    = _get<String>(data, 'job_created_by')   ?? _get<String>(data, 'passenger_phone') ?? psgPhone;
      passengerImageUrl = _get<String>(data, 'y_passenger_selfie') ?? _get<String>(data, 'passenger_photo');

      // -------- Driver (from job doc) --------
      driverName     = _get<String>(data, 'x_driver_name') ?? _get<String>(data, 'driver_name');
      driverPhone    = _get<String>(data, 'job_is_taken_by') ?? _get<String>(data, 'driver_phone');
      driverImageUrl = _get<String>(data, 'x_driver_selfie') ?? _get<String>(data, 'driver_photo');

      // Vehicle
      carModel = data['x_driver_vehicle_details'] ?? data['driver_vehicle'];
      carColor = _get<String>(data, 'x_driver_vehicle_color') ?? _get<String>(data, 'car_color');
      carPlate = _get<String>(data, 'x_driver_vehicle_plate') ?? _get<String>(data, 'number_plate');

      // Distance / ETA
      final pinDist = _asDouble(data['d${pinIndex}_distance_km']);
      if (pinDist != null) distanceKm = pinDist;
      distanceKm ??= _asDouble(
        data['road_distance_km'] ??
        data['distance_km'] ??
        data['d1_distance_km'] ??
        data['distance'],
      );

      final pinEta = _parseEtaMinutes(data['d${pinIndex}_eta_min'] ?? data['d${pinIndex}_eta']);
      etaMinutes = pinEta ?? _parseEtaMinutes(
        data['eta'] ??
        data['eta_minutes'] ??
        data['duration_minutes'] ??
        data['d1_eta_min'] ??
        data['duration'],
      );

      // Time
      tripTime = _asDateTime(
        data['updated_at'] ??
        data['created_at'] ??
        data['order_time'] ??
        data['order_timestamp'],
      ) ?? DateTime.now().toLocal();

      setState(() { _loading = false; });
    } catch (e, st) {
      debugPrint('[TellOthers-Driver] load error: $e\n$st');
      setState(() { _loading = false; _error = 'Failed to load trip details.'; });
    }
  }

  // ---------------- WhatsApp + message ----------------

  String _buildSafetyMessage() {
    final b = StringBuffer();

    // Time formatting
    final now = DateTime.now().toLocal();
    final fmt = DateFormat('EEE, dd MMM yyyy, h:mm a');
    final nowStr = fmt.format(now);
    final tzName = now.timeZoneName;
    final tzOff  = _fmtOffset(now.timeZoneOffset);
    final orderStr = tripTime != null ? fmt.format(tripTime!) : null;

    b.writeln('🛡️ $_prefixText');
    if (orderStr != null) b.writeln('🗓️ Order time: $orderStr ($tzName GMT$tzOff)');
    b.writeln('🕒 Sent: $nowStr ($tzName GMT$tzOff)');
    b.writeln('');

    // Links – prefer lat/lng; fall back to address links so they’re ALWAYS tappable
    final curLink = _mapsLinkFromLatLng(psgLat, psgLng) ?? _mapsLinkFromAddress(fromAddress);
    final dstLink = _mapsLinkFromLatLng(dstLat, dstLng) ?? _mapsLinkFromAddress(toAddress);
    final dirLink = _directionsLink(
      fromLat: psgLat, fromLng: psgLng, toLat: dstLat, toLng: dstLng,
      fromAddr: fromAddress, toAddr: toAddress,
    );

    if (curLink != null) b.writeln('📍 Current location: $curLink');
    if (dstLink != null) b.writeln('🎯 Destination: $dstLink');
    if (dirLink != null) b.writeln('🗺️ Directions: $dirLink');

    b.writeln('');

    // ---------- People ----------
    // Passenger first
    final showPPhone = !_isTrivialPhone(passengerPhone);
    if ((passengerName != null && passengerName!.isNotEmpty) || showPPhone || (passengerImageUrl?.isNotEmpty ?? false)) {
      b.writeln('🧍 Passenger');
      if (passengerImageUrl != null && passengerImageUrl!.isNotEmpty) b.writeln('🖼️ Photo: ${passengerImageUrl!}');
      if (passengerName != null && passengerName!.isNotEmpty) b.writeln('👤 Name: ${passengerName!}');
      if (showPPhone) b.writeln('☎️ Phone: ${passengerPhone!}');
      b.writeln('');
    }

    // Driver second
    final showDPhone = !_isTrivialPhone(driverPhone);
    if ((driverName != null && driverName!.isNotEmpty) || showDPhone || (driverImageUrl?.isNotEmpty ?? false) ||
        carModel != null || carColor != null || carPlate != null) {
      b.writeln('🧑‍✈️ Driver');
      if (driverImageUrl != null && driverImageUrl!.isNotEmpty) b.writeln('🖼️ Photo: ${driverImageUrl!}');
      if (driverName != null && driverName!.isNotEmpty) b.writeln('👤 Name: ${driverName!}');
      if (showDPhone) b.writeln('☎️ Phone: ${driverPhone!}');
      final carLine = _joinIfAny([
        carColor,
        (carModel != null && carModel!.isNotEmpty) ? carModel : null,
        (carPlate != null && carPlate!.isNotEmpty) ? '($carPlate)' : null,
      ], sep: ' ');
      if (carLine.isNotEmpty) b.writeln('🚗 Car: $carLine');
      b.writeln('');
    }

    // ---------- Route summary ----------
    if (fromAddress != null && fromAddress!.isNotEmpty) b.writeln('📫 From: $fromAddress');
    if (toAddress != null && toAddress!.isNotEmpty) b.writeln('🏁 To: $toAddress');
    if (distanceKm != null) b.writeln('📏 Distance: ${distanceKm!.toStringAsFixed(1)} km');
    if (etaMinutes != null) b.writeln('⏱️ ETA to destination: $etaMinutes min');

    b.writeln('');
    b.writeln('🔴 To enable live tracking in WhatsApp: attach/plus → Location → Share live location (15m / 1h / 8h).');

    return b.toString();
  }

  // ------------------------------ UI ------------------------------

  @override
  Widget build(BuildContext context) {
    final canSend = !_loading && _error == null;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      body: SafeArea(
        child: SizedBox(
          height: h,
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('Would you like to tell others?', style: TextStyle(fontSize: 18)),

                if (_loading)
                  const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),

                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_error!, style: TextStyle(color: Colors.red)),
                  ),

                const SizedBox(height: 12),

                if (canSend)
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(12),
                              child: Text(_buildSafetyMessage()),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const Expanded(child: SizedBox()),

                const SizedBox(height: 12),

                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('No'),
                    ),
                    SizedBox(width: 20),
                    ElevatedButton(
                      onPressed: !canSend ? null : () async {
                        final msg = _buildSafetyMessage();
                        // If passengerPhone looks valid → open that chat; else open composer.
                        await _openWhatsAppWithMessage(
                          msg,
                          phone: (!_isTrivialPhone(passengerPhone)) ? passengerPhone : null,
                        );
                      },
                      child: Text('Yes'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


// // ignore_for_file: prefer_const_constructors, use_build_context_synchronously

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:luckygo_pemandu/global.dart';
// import 'package:url_launcher/url_launcher.dart';

// class TellOthers extends StatefulWidget {
//   const TellOthers({super.key});

//   @override
//   State<TellOthers> createState() => _TellOthersState();
// }

// class _TellOthersState extends State<TellOthers> {
//   // --- Geo / addresses ---
//   double? psgLat, psgLng, dstLat, dstLng;
//   String? fromAddress, toAddress;

//   // --- Passenger ---
//   String? passengerName;
//   String? passengerPhone;
//   String? passengerImageUrl;

//   // --- Driver ---
//   String? driverName;
//   String? driverPhone;
//   String? driverImageUrl;

//   // --- Vehicle ---
//   String? carModel;
//   String? carColor;
//   String? carPlate;

//   // --- Trip summary ---
//   double? distanceKm;
//   int? etaMinutes;
//   DateTime? tripTime;

//   bool _loading = true;
//   String? _error;

//   static const String _prefixText = "I'm driving now via LuckyGo";

//   @override
//   void initState() {
//     super.initState();
//     _loadData();
//   }

//   // ---------------- Helpers ----------------

//   T? _get<T>(Map<String, dynamic> data, String key) {
//     final v = data[key];
//     if (v is T) return v;
//     return null;
//   }

//   double? _asDouble(dynamic v) {
//     if (v == null) return null;
//     if (v is num) return v.toDouble();
//     if (v is String) return double.tryParse(v);
//     return null;
//   }

//   int? _asInt(dynamic v) {
//     if (v == null) return null;
//     if (v is int) return v;
//     if (v is num) return v.toInt();
//     if (v is String) return int.tryParse(v);
//     return null;
//   }

//   int? _parseEtaMinutes(dynamic v) {
//     if (v == null) return null;
//     if (v is num) {
//       final n = v.toDouble();
//       if (n > 10000) {
//         final mins = (n / 60).round();
//         return mins > 20000 ? (n / 60000).round() : mins;
//       }
//       return n.round();
//     }
//     if (v is String) {
//       final s = v.toLowerCase().trim();
//       if (s.startsWith('pt') || s.startsWith('p')) {
//         int mins = 0;
//         final h = RegExp(r'(\d+)h').firstMatch(s)?.group(1);
//         final m = RegExp(r'(\d+)m').firstMatch(s)?.group(1);
//         if (h != null) mins += int.parse(h) * 60;
//         if (m != null) mins += int.parse(m);
//         if (mins > 0) return mins;
//       }
//       int mins = 0;
//       final hm = RegExp(r'(\d+)\s*(hours?|hrs?|h)\b').firstMatch(s);
//       final mm = RegExp(r'(\d+)\s*(minutes?|mins?|m)\b').firstMatch(s);
//       if (hm != null) mins += int.parse(hm.group(1)!) * 60;
//       if (mm != null) mins += int.parse(mm.group(1)!);
//       if (mins > 0) return mins;
//       final numeric = double.tryParse(s.replaceAll(RegExp('[^0-9.]'), ''));
//       if (numeric != null) {
//         if (numeric > 10000) {
//           final mins2 = (numeric / 60).round();
//           return mins2 > 20000 ? (numeric / 60000).round() : mins2;
//         }
//         return numeric.round();
//       }
//     }
//     return null;
//   }

//   DateTime? _asDateTime(dynamic v) {
//     if (v == null) return null;
//     if (v is Timestamp) return v.toDate();
//     if (v is DateTime) return v;
//     if (v is num) {
//       final val = v.toInt();
//       if (val > 1000000000000) {
//         return DateTime.fromMillisecondsSinceEpoch(val, isUtc: true).toLocal();
//       } else {
//         return DateTime.fromMillisecondsSinceEpoch(val * 1000, isUtc: true).toLocal();
//       }
//     }
//     if (v is String) {
//       try { return DateTime.parse(v).toLocal(); } catch (_) {}
//     }
//     return null;
//   }

//   GeoPoint? _firstGeo(Map<String, dynamic> data, List<String> keys) {
//     for (final k in keys) {
//       final v = data[k];
//       if (v is GeoPoint) return v;
//       if (v is Map) {
//         final lat = _asDouble(v['lat'] ?? v['latitude']);
//         final lng = _asDouble(v['lng'] ?? v['longitude']);
//         if (lat != null && lng != null) return GeoPoint(lat, lng);
//       }
//     }
//     return null;
//   }

//   GeoPoint? _latLngFromPairs(Map<String, dynamic> data, List<(String, String)> pairs) {
//     for (final (latKey, lngKey) in pairs) {
//       final lat = _asDouble(data[latKey]);
//       final lng = _asDouble(data[lngKey]);
//       if (lat != null && lng != null) return GeoPoint(lat, lng);
//     }
//     return null;
//   }

//   String _joinIfAny(List<String?> parts, {String sep = ', '}) {
//     return parts.where((e) => e != null && e!.trim().isNotEmpty).map((e) => e!.trim()).join(sep);
//   }

//   String _fmtOffset(Duration off) {
//     final sign = off.isNegative ? '-' : '+';
//     final h = off.inHours.abs().toString().padLeft(2, '0');
//     final m = off.inMinutes.remainder(60).abs().toString().padLeft(2, '0');
//     return '$sign$h:$m';
//   }

//   String _addressOrNotProvided(String? a1, String? a2) {
//     final joined = _joinIfAny([a1, a2]);
//     return joined.isEmpty ? 'NOT PROVIDED' : joined;
//   }

//   bool _isTrivialPhone(String? s) {
//     if (s == null) return true;
//     final d = s.replaceAll(RegExp(r'\D'), '');
//     if (d.isEmpty) return true;
//     if (RegExp(r'^0+$').hasMatch(d)) return true; // all zeros
//     return false;
//   }

//   String? _mapsLinkFromLatLng(double? lat, double? lng) {
//     if (lat == null || lng == null) return null;
//     return 'https://maps.google.com/?q=$lat,$lng';
//   }

//   String? _mapsLinkFromAddress(String? address) {
//     if (address == null || address.trim().isEmpty || address == 'NOT PROVIDED') return null;
//     final q = Uri.encodeComponent(address);
//     return 'https://maps.google.com/?q=$q';
//   }

//   String? _directionsLink({
//     double? fromLat, double? fromLng,
//     double? toLat, double? toLng,
//     String? fromAddr, String? toAddr,
//   }) {
//     if (fromLat != null && fromLng != null && toLat != null && toLng != null) {
//       return 'https://www.google.com/maps/dir/?api=1'
//           '&origin=$fromLat,$fromLng'
//           '&destination=$toLat,$toLng'
//           '&travelmode=driving';
//     }
//     if (fromAddr != null && fromAddr.isNotEmpty && toAddr != null && toAddr.isNotEmpty) {
//       final o = Uri.encodeComponent(fromAddr);
//       final d = Uri.encodeComponent(toAddr);
//       return 'https://www.google.com/maps/dir/?api=1'
//           '&origin=$o'
//           '&destination=$d'
//           '&travelmode=driving';
//     }
//     return null;
//   }

//   // --------------------------- Firestore loader -----------------------

//   Future<void> _loadData() async {
//     setState(() { _loading = true; _error = null; });

//     try {
//       final negara = Gv.negara;
//       final negeri = Gv.negeri;
//       final psgPhone = Gv.passengerPhone; // driver-side: active job lives under passenger

//       if ((negara == null || negara.isEmpty) ||
//           (negeri == null || negeri.isEmpty) ||
//           (psgPhone == null || psgPhone.isEmpty)) {
//         throw StateError('Missing negara/negeri/passengerPhone');
//       }

//       final ref = FirebaseFirestore.instance
//           .collection(negara)
//           .doc(negeri)
//           .collection('passenger_account')
//           .doc(psgPhone)
//           .collection('my_active_job')
//           .doc(psgPhone);

//       final snap = await ref.get();
//       final data = (snap.data() ?? {}) as Map<String, dynamic>;

//       // Source address
//       final src1 = _get<String>(data, 'source_address1') ?? _get<String>(data, 'pickup_address1');
//       final src2 = _get<String>(data, 'source_address2') ?? _get<String>(data, 'pickup_address2');
//       fromAddress = _addressOrNotProvided(src1, src2);

//       // Destination by qty_pin (0->d1 ... 5->d6)
//       final extraPin = (_asInt(data['qty_pin']) ?? 0).clamp(0, 5);
//       final pinIndex = extraPin + 1;
//       final a1Key = 'd${pinIndex}_address1';
//       final a2Key = 'd${pinIndex}_address2';
//       final dA1 = _get<String>(data, a1Key);
//       final dA2 = _get<String>(data, a2Key);
//       toAddress = _addressOrNotProvided(dA1, dA2);

//       // Pickup geo
//       final pickupGeo = _firstGeo(data, [
//         'source_geopoint','pickup_geopoint','source_location','pickup_location','source','pickup'
//       ]) ?? _latLngFromPairs(data, [
//         ('source_lat','source_lng'),('pickup_lat','pickup_lng'),('psg_lat','psg_lng'),
//       ]);
//       if (pickupGeo != null) { psgLat = pickupGeo.latitude; psgLng = pickupGeo.longitude; }

//       // Destination geo (per selected pin first)
//       final pinGeo = _firstGeo(data, [
//         'd${pinIndex}_geopoint','d${pinIndex}_location'
//       ]) ?? _latLngFromPairs(data, [
//         ('d${pinIndex}_lat','d${pinIndex}_lng'),
//       ]);
//       final fallbackDestGeo = _firstGeo(data, [
//         'd1_geopoint','destination_geopoint','destination_location','d1_location','destination','d1'
//       ]) ?? _latLngFromPairs(data, [
//         ('d1_lat','d1_lng'),('dest_lat','dest_lng'),
//       ]);
//       final destGeo = pinGeo ?? fallbackDestGeo;
//       if (destGeo != null) { dstLat = destGeo.latitude; dstLng = destGeo.longitude; }

//       // -------- Passenger (from job doc) --------
//       passengerName     = _get<String>(data, 'job_creator_name') ?? _get<String>(data, 'passenger_name');
//       passengerPhone    = _get<String>(data, 'job_created_by')   ?? _get<String>(data, 'passenger_phone') ?? psgPhone;
//       passengerImageUrl = _get<String>(data, 'y_passenger_selfie') ?? _get<String>(data, 'passenger_photo');

//       // -------- Driver (from job doc) --------
//       driverName     = _get<String>(data, 'x_driver_name') ?? _get<String>(data, 'driver_name');
//       driverPhone    = _get<String>(data, 'job_is_taken_by') ?? _get<String>(data, 'driver_phone');
//       driverImageUrl = _get<String>(data, 'x_driver_selfie') ?? _get<String>(data, 'driver_photo');

//       // Vehicle
//       carModel = data['x_driver_vehicle_details'] ?? data['driver_vehicle'];
//       carColor = _get<String>(data, 'x_driver_vehicle_color') ?? _get<String>(data, 'car_color');
//       carPlate = _get<String>(data, 'x_driver_vehicle_plate') ?? _get<String>(data, 'number_plate');

//       // Distance / ETA
//       final pinDist = _asDouble(data['d${pinIndex}_distance_km']);
//       if (pinDist != null) distanceKm = pinDist;
//       distanceKm ??= _asDouble(
//         data['road_distance_km'] ??
//         data['distance_km'] ??
//         data['d1_distance_km'] ??
//         data['distance'],
//       );

//       final pinEta = _parseEtaMinutes(data['d${pinIndex}_eta_min'] ?? data['d${pinIndex}_eta']);
//       etaMinutes = pinEta ?? _parseEtaMinutes(
//         data['eta'] ??
//         data['eta_minutes'] ??
//         data['duration_minutes'] ??
//         data['d1_eta_min'] ??
//         data['duration'],
//       );

//       // Time
//       tripTime = _asDateTime(
//         data['updated_at'] ??
//         data['created_at'] ??
//         data['order_time'] ??
//         data['order_timestamp'],
//       ) ?? DateTime.now().toLocal();

//       setState(() { _loading = false; });
//     } catch (e, st) {
//       debugPrint('[TellOthers-Driver] load error: $e\n$st');
//       setState(() { _loading = false; _error = 'Failed to load trip details.'; });
//     }
//   }

//   // ---------------- WhatsApp + message ----------------

//   String _buildSafetyMessage() {
//     final b = StringBuffer();

//     // Time formatting
//     final now = DateTime.now().toLocal();
//     final fmt = DateFormat('EEE, dd MMM yyyy, h:mm a');
//     final nowStr = fmt.format(now);
//     final tzName = now.timeZoneName;
//     final tzOff  = _fmtOffset(now.timeZoneOffset);
//     final orderStr = tripTime != null ? fmt.format(tripTime!) : null;

//     b.writeln('🛡️ $_prefixText');
//     if (orderStr != null) b.writeln('🗓️ Order time: $orderStr ($tzName GMT$tzOff)');
//     b.writeln('🕒 Sent: $nowStr ($tzName GMT$tzOff)');
//     b.writeln('');

//     // Links – prefer lat/lng; fall back to address links so they’re ALWAYS tappable
//     final curLink = _mapsLinkFromLatLng(psgLat, psgLng) ?? _mapsLinkFromAddress(fromAddress);
//     final dstLink = _mapsLinkFromLatLng(dstLat, dstLng) ?? _mapsLinkFromAddress(toAddress);
//     final dirLink = _directionsLink(
//       fromLat: psgLat, fromLng: psgLng, toLat: dstLat, toLng: dstLng,
//       fromAddr: fromAddress, toAddr: toAddress,
//     );

//     if (curLink != null) b.writeln('📍 Current location: $curLink');
//     if (dstLink != null) b.writeln('🎯 Destination: $dstLink');
//     if (dirLink != null) b.writeln('🗺️ Directions: $dirLink');

//     b.writeln('');

//     // ---------- People ----------
//     // Passenger first
//     final showPPhone = !_isTrivialPhone(passengerPhone);
//     if ((passengerName != null && passengerName!.isNotEmpty) || showPPhone || (passengerImageUrl?.isNotEmpty ?? false)) {
//       b.writeln('🧍 Passenger');
//       if (passengerImageUrl != null && passengerImageUrl!.isNotEmpty) b.writeln('🖼️ Photo: ${passengerImageUrl!}');
//       if (passengerName != null && passengerName!.isNotEmpty) b.writeln('👤 Name: ${passengerName!}');
//       if (showPPhone) b.writeln('☎️ Phone: ${passengerPhone!}');
//       b.writeln('');
//     }

//     // Driver second
//     final showDPhone = !_isTrivialPhone(driverPhone);
//     if ((driverName != null && driverName!.isNotEmpty) || showDPhone || (driverImageUrl?.isNotEmpty ?? false) ||
//         carModel != null || carColor != null || carPlate != null) {
//       b.writeln('🧑‍✈️ Driver');
//       if (driverImageUrl != null && driverImageUrl!.isNotEmpty) b.writeln('🖼️ Photo: ${driverImageUrl!}');
//       if (driverName != null && driverName!.isNotEmpty) b.writeln('👤 Name: ${driverName!}');
//       if (showDPhone) b.writeln('☎️ Phone: ${driverPhone!}');
//       final carLine = _joinIfAny([
//         carColor,
//         (carModel != null && carModel!.isNotEmpty) ? carModel : null,
//         (carPlate != null && carPlate!.isNotEmpty) ? '($carPlate)' : null,
//       ], sep: ' ');
//       if (carLine.isNotEmpty) b.writeln('🚗 Car: $carLine');
//       b.writeln('');
//     }

//     // ---------- Route summary ----------
//     if (fromAddress != null && fromAddress!.isNotEmpty) b.writeln('📫 From: $fromAddress');
//     if (toAddress != null && toAddress!.isNotEmpty) b.writeln('🏁 To: $toAddress');
//     if (distanceKm != null) b.writeln('📏 Distance: ${distanceKm!.toStringAsFixed(1)} km');
//     if (etaMinutes != null) b.writeln('⏱️ ETA to destination: $etaMinutes min');

//     b.writeln('');
//     b.writeln('🔴 To enable live tracking in WhatsApp: attach/plus → Location → Share live location (15m / 1h / 8h).');

//     return b.toString();
//   }

//   Future<void> _openWhatsAppWithMessage(String message, {String? phone}) async {
//     String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

//     final phoneDigits = (phone != null && phone.trim().isNotEmpty)
//         ? _digitsOnly(phone)
//         : '';

//     final text = Uri.encodeComponent(message);

//     if (phoneDigits.isNotEmpty) {
//       final uriApp = Uri.parse('whatsapp://send?phone=$phoneDigits&text=$text');
//       try {
//         if (await canLaunchUrl(uriApp)) {
//           final ok = await launchUrl(uriApp, mode: LaunchMode.externalApplication);
//           if (ok) return;
//         }
//       } catch (_) {}
//     }

//     final uriAppNoPhone = Uri.parse('whatsapp://send?text=$text');
//     try {
//       if (await canLaunchUrl(uriAppNoPhone)) {
//         final ok = await launchUrl(uriAppNoPhone, mode: LaunchMode.externalApplication);
//         if (ok) return;
//       }
//     } catch (_) {}

//     final uriWebWithPhone = (phoneDigits.isNotEmpty)
//         ? Uri.parse('https://wa.me/$phoneDigits?text=$text')
//         : null;
//     if (uriWebWithPhone != null) {
//       try {
//         final ok = await launchUrl(uriWebWithPhone, mode: LaunchMode.externalApplication);
//         if (ok) return;
//       } catch (_) {}
//     }

//     final uriWebNoPhone = Uri.parse('https://wa.me/?text=$text');
//     try {
//       final ok = await launchUrl(uriWebNoPhone, mode: LaunchMode.externalApplication);
//       if (ok) return;
//     } catch (_) {}

//     if (!mounted) return;
//     ScaffoldMessenger.of(context).showSnackBar(
//       const SnackBar(content: Text('WhatsApp not available. Try sharing manually.')),
//     );
//   }

//   // ------------------------------ UI ------------------------------

//   @override
//   Widget build(BuildContext context) {
//     final canSend = !_loading && _error == null;
//     final h = MediaQuery.of(context).size.height;

//     return Scaffold(
//       body: SafeArea(
//         child: SizedBox(
//           height: h,
//           width: double.infinity,
//           child: Padding(
//             padding: const EdgeInsets.all(16),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.center,
//               children: [
//                 Text('Would you like to tell others?', style: TextStyle(fontSize: 18)),
//                 // const SizedBox(height: 12),

//                 if (_loading)
//                   const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()),

//                 if (_error != null)
//                   Padding(
//                     padding: const EdgeInsets.only(top: 8),
//                     child: Text(_error!, style: TextStyle(color: Colors.red)),
//                   ),



//                 const SizedBox(height: 12),

//                 if (canSend)
//                   Expanded(
//                     child: Center(
//                       child: ConstrainedBox(
//                         constraints: const BoxConstraints(maxWidth: 600),
//                         child: DecoratedBox(
//                           decoration: BoxDecoration(
//                             border: Border.all(color: Colors.black12),
//                             borderRadius: BorderRadius.circular(8),
//                           ),
//                           child: Scrollbar(
//                             thumbVisibility: true,
//                             child: SingleChildScrollView(
//                               padding: const EdgeInsets.all(12),
//                               child: Text(_buildSafetyMessage()),
//                             ),
//                           ),
//                         ),
//                       ),
//                     ),
//                   )
//                 else
//                   const Expanded(child: SizedBox()),


//                 const SizedBox(height: 12),

//                 Wrap(
//                   alignment: WrapAlignment.center,
//                   spacing: 12,
//                   runSpacing: 8,
//                   children: [
//                     ElevatedButton(
//                       onPressed: () => Navigator.pop(context),
//                       child: Text('No'),
//                     ),
//                     SizedBox(width:20),
//                     ElevatedButton(
//                       onPressed: !canSend ? null : () async {
//                         final msg = _buildSafetyMessage();
//                         // You can pass passengerPhone here if you want a targeted chat
//                         await _openWhatsAppWithMessage(msg /*, phone: passengerPhone*/);
//                       },
//                       child: Text('Yes'),
//                     ),
//                   ],
//                 ),


//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }
