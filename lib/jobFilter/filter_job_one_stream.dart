// import 'dart:async';
// import 'dart:convert';
// import 'dart:math' as math;
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/scheduler.dart';
// import 'package:http/http.dart' as http;

// import 'package:luckygo_pemandu/global.dart';
// import 'package:luckygo_pemandu/jobFilter/bucket123.dart';
// import 'package:luckygo_pemandu/jobFilter/bucket414.dart';
// import 'package:luckygo_pemandu/jobFilter/filter_jobs_helper.dart'; // ShortJob

// /// Single-stream page:
// /// - Section A (Buckets 1–3): ROAD distance for jobs whose AIR ≤ 7.5 km
// /// - Section B (Buckets 4–14): AIR distance
// /// - Re-anchors when driver moves ≥ 500 m and *stops* (debounced), then recomputes & refetches ROAD.
// class FilterJobsOneStream extends StatefulWidget {
//   const FilterJobsOneStream({super.key});

//   @override
//   State<FilterJobsOneStream> createState() => _FilterJobsOneStreamState();
// }

// class _FilterJobsOneStreamState extends State<FilterJobsOneStream> {
//   late final DocumentReference<Map<String, dynamic>> _docRef;

//   // Latest Firestore doc
//   Map<String, dynamic> _raw = const {};

//   // AIR counts for 1..14 (we display 4..14 from this)
//   Map<int, int> _airCountsAll = const {};

//   // Shortlist (AIR ≤ 7.5 km) for ROAD fetching
//   List<ShortJob> _shortlist = const [];

//   // ROAD overlay counts for 1..3
//   Map<int, int> _roadCounts123 = const {};

//   // ROAD km cache (key: "jobId@sLat,sLng@anchorLat,anchorLng" -> km)
//   final Map<String, double> _roadKmCache = {};
//   final Set<String> _inFlight = {}; // prevent duplicate requests

//   bool _loadingRoad = false;
//   StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

//   // ───────── Anchor state (500 m re-anchor with stop-detect) ─────────
//   late double _anchorLat;
//   late double _anchorLng;

//   Timer? _locPollTimer;
//   Timer? _reanchorDebounce;

//   static const _reanchorMeters = 500.0;
//   static const _pollInterval = Duration(seconds: 2);
//   static const _stopDebounce = Duration(seconds: 3);

//   @override
//   void initState() {
//     super.initState();

//     _anchorLat = Gv.driverLat;
//     _anchorLng = Gv.driverLng;

//     _docRef = FirebaseFirestore.instance
//         .collection(Gv.negara)
//         .doc(Gv.negeri)
//         .collection('active_job')
//         .doc('active_job_lite');

//     _sub = _docRef.snapshots(includeMetadataChanges: true).listen((snap) {
//       debugPrint(
//           '[FJOS] snapshot >>> anchor=(${_anchorLat.toStringAsFixed(6)}, ${_anchorLng.toStringAsFixed(6)}) negara=${Gv.negara} negeri=${Gv.negeri}');

//       final data = snap.data() ?? const {};
//       _raw = data;

//       _rebuildForAnchorAndScheduleRoad();
//     });

//     _startLocationPolling();
//   }

//   @override
//   void dispose() {
//     _sub?.cancel();
//     _locPollTimer?.cancel();
//     _reanchorDebounce?.cancel();
//     super.dispose();
//   }

//   // ─────────────────────────── BUILD ───────────────────────────

//   @override
//   Widget build(BuildContext context) {
//     final cap = Gv.groupCapability.clamp(0, 14);

//     if (Gv.negara.isEmpty || Gv.negeri.isEmpty) {
//       return const Scaffold(
//         body: Center(child: Text('⚠ Set Gv.negara & Gv.negeri first.')),
//       );
//     }

//     // Prepare rows: Section A (b1..b3 ROAD), Section B (b4..cap AIR)
//     final rows = <_RowSpec>[];

//     for (var i = 1; i <= math.min(3, cap); i++) {
//       rows.add(_RowSpec.bucket(
//         index: i,
//         name: _bucketMeta(i).name,
//         range: _bucketMeta(i).range,
//         count: _roadCounts123[i] ?? 0,
//         pill: 'ROAD',
//         pillColor: Colors.teal,
//       ));
//     }

//     if (cap >= 4) {
//       for (var i = 4; i <= cap; i++) {
//         rows.add(_RowSpec.bucket(
//           index: i,
//           name: _bucketMeta(i).name,
//           range: _bucketMeta(i).range,
//           count: _airCountsAll[i] ?? 0,
//           pill: 'AIR',
//           pillColor: Colors.indigo,
//         ));
//       }
//     }

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Nearby Buckets (One Stream)'),
//         actions: [
//           IconButton(
//             tooltip: 'Dump ≤7.5km list',
//             icon: const Icon(Icons.bug_report),
//             onPressed: () => _dumpBucket4Jobs(reason: 'manual dump via AppBar'),
//           ),
//           if (_loadingRoad)
//             const Padding(
//               padding: EdgeInsets.only(right: 12),
//               child: Center(
//                 child: SizedBox(
//                   width: 16, height: 16,
//                   child: CircularProgressIndicator(strokeWidth: 2),
//                 ),
//               ),
//             ),
//           IconButton(
//             tooltip: 'Force server refresh',
//             icon: const Icon(Icons.refresh),
//             onPressed: _pokeServer,
//           ),
//         ],
//       ),
//       body: Expanded(
//         child: ListView.separated(
//           padding: const EdgeInsets.symmetric(vertical: 8),
//           separatorBuilder: (_, __) => const Divider(height: 1),
//           itemCount: rows.length,
//           itemBuilder: (context, idx) {
//             final r = rows[idx];
//             final i = r.index!;
//             return InkWell(
//               onTap: (r.count ?? 0) <= 0
//                   ? null
//                   : () {
//                       final Widget dest = (i <= 3)
//                           ? Bucket123(bucketIndex: i) // b1–b3
//                           : Bucket414(bucketIndex: i); // b4–b14
//                       Navigator.push(
//                         context,
//                         MaterialPageRoute(builder: (_) => dest),
//                       );
//                     },
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//                 child: Row(
//                   children: [
//                     // icon
//                     Container(
//                       width: 36,
//                       height: 36,
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.06),
//                         shape: BoxShape.circle,
//                       ),
//                       child: Icon(_bucketMeta(i).icon, size: 20, color: Colors.black87),
//                     ),
//                     const SizedBox(width: 12),
//                     // labels
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Row(children: [
//                             Text(
//                               r.name!,
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                               style: const TextStyle(
//                                 fontSize: 14,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                             ),
//                             const SizedBox(width: 8),
//                             _pill(r.pill!, r.pillColor!),
//                           ]),
//                           const SizedBox(height: 2),
//                           Text(
//                             r.range!,
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                             style: TextStyle(
//                               fontSize: 10,
//                               color: Theme.of(context)
//                                   .textTheme
//                                   .bodySmall
//                                   ?.color
//                                   ?.withOpacity(0.8),
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                     const SizedBox(width: 12),
//                     // count
//                     Container(
//                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                       decoration: BoxDecoration(
//                         color: Colors.black.withOpacity(0.05),
//                         borderRadius: BorderRadius.circular(999),
//                       ),
//                       child: Text(
//                         '${r.count ?? 0}',
//                         style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }

//   // ───────────────────── LIVE / IO ─────────────────────

//   Future<void> _pokeServer() async {
//     try {
//       await _docRef.get(const GetOptions(source: Source.server));
//     } catch (_) {}
//   }

//   // Rebuild AIR & shortlist for the *current* anchor, then schedule ROAD
//   void _rebuildForAnchorAndScheduleRoad() {
//     Gv.roadAnchorLat = _anchorLat;
//     Gv.roadAnchorLng = _anchorLng;

//     final airCounts = _computeAirCountsAll(_raw, _anchorLat, _anchorLng);
//     _logAirCounts(airCounts);

//     final shortlist = _buildShortlistLe7p5(_raw, _anchorLat, _anchorLng);
//     debugPrint('[FJOS] shortlist<=7.5km size=${shortlist.length}');

//     Gv.setBucket4Jobs(shortlist);
//     _dumpBucket4Jobs(reason: 'after shortlist build');

//     _safeSetState(() {
//       _airCountsAll = airCounts;
//       _shortlist = shortlist;
//     });

//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _fetchRoadForCurrentShortlist();
//     });
//   }

//   // Called after snapshot processing — never inside build
//   Future<void> _fetchRoadForCurrentShortlist() async {
//     if (_shortlist.isEmpty) {
//       debugPrint('[FJOS] _fetchRoadForCurrentShortlist: shortlist empty.');
//       if (_loadingRoad) _safeSetState(() => _loadingRoad = false);
//       _rebuildRoadOverlayFromCache();
//       return;
//     }

//     final desired = _shortlist
//         .map((j) => _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng))
//         .toSet();

//     if (_roadKmCache.isNotEmpty) {
//       _roadKmCache.removeWhere((k, _) => !desired.contains(k));
//     }

//     final missing = _shortlist.where((j) {
//       final k = _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng);
//       return !_roadKmCache.containsKey(k) && !_inFlight.contains(k);
//     }).toList();

//     debugPrint(
//         '[FJOS] ROAD fetch: shortlist=${_shortlist.length}, missing=${missing.length}, cache=${_roadKmCache.length}, inFlight=${_inFlight.length}');

//     if (missing.isEmpty) {
//       _rebuildRoadOverlayFromCache();
//       return;
//     }

//     _safeSetState(() => _loadingRoad = true);

//     // Fetch in batches
//     const batchSize = 25;
//     for (var i = 0; i < missing.length; i += batchSize) {
//       final batch = missing.sublist(i, math.min(i + batchSize, missing.length));

//       // mark in-flight
//       final batchKeys = <String>[];
//       for (final j in batch) {
//         final k = _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng);
//         batchKeys.add(k);
//         _inFlight.add(k);
//       }

//       try {
//         final m = await _callDistanceMatrix(
//           originLat: _anchorLat,
//           originLng: _anchorLng,
//           jobs: batch,
//         );
//         if (m.isNotEmpty) {
//           _roadKmCache.addAll(m);
//           _rebuildRoadOverlayFromCache(); // update counts incrementally
//         }
//       } finally {
//         _inFlight.removeAll(batchKeys);
//       }
//     }

//     _safeSetState(() => _loadingRoad = false);
//   }

//   // ───────────────────── PURE COMPUTE ─────────────────────

//   Map<int, int> _computeAirCountsAll(
//     Map<String, dynamic> raw,
//     double dLat,
//     double dLng,
//   ) {
//     final counts = {for (var i = 1; i <= 14; i++) i: 0};

//     raw.forEach((jobId, v) {
//       if (v is! String) return;
//       final p = v.split('·').map((s) => s.trim()).toList(growable: false);
//       if (p.length != 33) return;

//       final sLat = double.tryParse(p[11]);
//       final sLng = double.tryParse(p[12]);
//       if (sLat == null || sLng == null) return;
//       if (!_validCoord(sLat, sLng)) return;

//       final km = _haversineKm(dLat, dLng, sLat, sLng);
//       final b = _bucketIndexForDistance(km);
//       if (b != null) counts[b] = (counts[b] ?? 0) + 1;
//     });

//     return counts;
//   }

//   List<ShortJob> _buildShortlistLe7p5(
//     Map<String, dynamic> raw,
//     double dLat,
//     double dLng,
//   ) {
//     final list = <ShortJob>[];
//     raw.forEach((jobId, v) {
//       if (v is! String) return;
//       final p = v.split('·').map((s) => s.trim()).toList(growable: false);
//       if (p.length != 33) return;

//       final sLat = double.tryParse(p[11]);
//       final sLng = double.tryParse(p[12]);
//       if (sLat == null || sLng == null) return;
//       if (!_validCoord(sLat, sLng)) return;

//       final airKm = _haversineKm(dLat, dLng, sLat, sLng);
//       if (airKm <= 7.5) {
//         list.add(ShortJob(jobId: '$jobId', sLat: sLat, sLng: sLng));
//       }
//     });
//     return list;
//   }

//   void _rebuildRoadOverlayFromCache() {
//     var b1 = 0, b2 = 0, b3 = 0;
//     for (final j in _shortlist) {
//       final k =
//           _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng);
//       final roadKm = _roadKmCache[k];
//       if (roadKm == null) continue;
//       final b = _bucketIndexForRoad123(roadKm);
//       if (b == 1) {
//         b1++;
//       } else if (b == 2) {
//         b2++;
//       } else if (b == 3) {
//         b3++;
//       }
//     }
//     final overlay = {1: b1, 2: b2, 3: b3};
//     debugPrint(
//         '[FJOS] overlay123 from cache: $overlay  (cache=${_roadKmCache.length})');

//     _safeSetState(() {
//       _roadCounts123 = overlay;
//     });
//   }

//   // ───────────────────── ROAD lookup ─────────────────────

//   Future<Map<String, double>> _callDistanceMatrix({
//     required double originLat,
//     required double originLng,
//     required List<ShortJob> jobs,
//   }) async {
//     final apiKey = (Gv.googleApiKey).trim();
//     if (apiKey.isEmpty || jobs.isEmpty) {
//       debugPrint(
//           '[FJOS] DistanceMatrix: apiKey empty? ${apiKey.isEmpty}, jobs=${jobs.length}');
//       return {};
//     }

//     final origin =
//         '${originLat.toStringAsFixed(6)},${originLng.toStringAsFixed(6)}';
//     final destinations = jobs
//         .map((j) =>
//             '${j.sLat.toStringAsFixed(6)},${j.sLng.toStringAsFixed(6)}')
//         .join('|');

//     final uri = Uri.parse(
//       'https://maps.googleapis.com/maps/api/distancematrix/json'
//       '?origins=$origin'
//       '&destinations=$destinations'
//       '&mode=driving'
//       '&departure_time=now'
//       '&key=$apiKey',
//     );

//     try {
//       debugPrint(
//           '[FJOS] DM call → ${uri.toString().substring(0, 120)}...  (dest=${jobs.length})');
//       final resp = await http.get(uri);
//       if (resp.statusCode != 200) {
//         debugPrint('[FJOS] DM http=${resp.statusCode}');
//         return {};
//       }

//       final map = jsonDecode(resp.body) as Map<String, dynamic>;
//       final topStatus = map['status'] as String?;
//       debugPrint('[FJOS] DM top status: $topStatus');
//       if (topStatus != 'OK') return {};

//       final rows = (map['rows'] as List?) ?? const [];
//       if (rows.isEmpty) return {};
//       final elements = (rows.first['elements'] as List?) ?? const [];

//       final out = <String, double>{};
//       final n = math.min(elements.length, jobs.length);

//       for (var i = 0; i < n; i++) {
//         final e = elements[i] as Map<String, dynamic>?;
//         if (e?['status'] != 'OK') continue;

//         final distMeters = (e?['distance']?['value'] as num?)?.toDouble();
//         if (distMeters == null) continue;
//         final km = double.parse((distMeters / 1000.0).toStringAsFixed(1));

//         // prefer duration_in_traffic if present, else duration
//         final dur = (e?['duration_in_traffic'] ?? e?['duration'])
//             as Map<String, dynamic>?;
//         final secs = (dur?['value'] as num?)?.toInt() ?? 0;
//         final etaMin = (secs / 60).round();

//         final j = jobs[i];
//         final key = _cacheKey(
//             j.jobId, j.sLat, j.sLng, originLat, originLng);

//         // local cache used for overlay counts
//         out[key] = km;

//         // persist to global so Bucket123 can read immediately
//         Gv.roadAnchorLat = originLat;
//         Gv.roadAnchorLng = originLng;
//         Gv.roadByJob[key] = JobCalc(roadKm: km, etaMin: etaMin);
//       }

//       debugPrint('[FJOS] DM mapped results: ${out.length}/${jobs.length}');
//       return out;
//     } catch (e) {
//       debugPrint('[FJOS] DM error: $e');
//       return {};
//     }
//   }

//   // ───────────────────── Anchor movement logic ─────────────────────

//   void _startLocationPolling() {
//     _locPollTimer?.cancel();
//     _locPollTimer = Timer.periodic(_pollInterval, (_) {
//       final curLat = Gv.driverLat;
//       final curLng = Gv.driverLng;
//       if (!_validCoord(curLat, curLng) || !_validCoord(_anchorLat, _anchorLng)) {
//         if (_validCoord(curLat, curLng) && !_validCoord(_anchorLat, _anchorLng)) {
//           _scheduleReanchor(curLat, curLng);
//         }
//         return;
//       }

//       final movedM =
//           _haversineKm(_anchorLat, _anchorLng, curLat, curLng) * 1000.0;
//       if (movedM >= _reanchorMeters) {
//         _scheduleReanchor(curLat, curLng);
//       } else {
//         _reanchorDebounce?.cancel();
//         _reanchorDebounce = null;
//       }
//     });
//   }

//   void _scheduleReanchor(double lat, double lng) {
//     _reanchorDebounce?.cancel();
//     _reanchorDebounce = Timer(_stopDebounce, () {
//       final newLat = Gv.driverLat;
//       final newLng = Gv.driverLng;
//       if (!_validCoord(newLat, newLng)) return;

//       final distM =
//           _haversineKm(_anchorLat, _anchorLng, newLat, newLng) * 1000.0;
//       if (distM < _reanchorMeters) return;

//       debugPrint(
//           '[FJOS] Re-anchoring: old=(${_anchorLat.toStringAsFixed(6)},${_anchorLng.toStringAsFixed(6)}) '
//           'new=(${newLat.toStringAsFixed(6)},${newLng.toStringAsFixed(6)}) dist=${distM.toStringAsFixed(1)}m');

//       _anchorLat = newLat;
//       _anchorLng = newLng;
//       Gv.roadAnchorLat = _anchorLat;
//       Gv.roadAnchorLng = _anchorLng;

//       _roadKmCache.clear();
//       _inFlight.clear();

//       _rebuildForAnchorAndScheduleRoad();
//     });
//   }

//   // ───────────────────── helpers ─────────────────────

//   void _dumpBucket4Jobs({required String reason}) {
//     final list = Gv.bucket4Jobs;
//     debugPrint(
//         '[FJOS] DUMP bucket4Jobs ($reason): count=${list.length} builtAt=${Gv.bucket4LastBuiltAt} ver=${Gv.bucket4Version.value}');
//     for (var i = 0; i < list.length && i < 50; i++) {
//       final j = list[i];
//       final key =
//           _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng);
//       debugPrint(
//           '  [$i] jobId=${j.jobId} s=(${j.sLat.toStringAsFixed(6)},${j.sLng.toStringAsFixed(6)}) key=$key');
//     }
//     if (list.length > 50) {
//       debugPrint('  ... +${list.length - 50} more');
//     }
//   }

//   void _logAirCounts(Map<int, int> c) {
//     final sb = StringBuffer('AIR counts: ');
//     for (var i = 1; i <= 14; i++) {
//       if (i > 1) sb.write(', ');
//       sb.write('$i:${c[i] ?? 0}');
//     }
//     debugPrint('[FJOS] $sb');
//   }

//   String _cacheKey(
//           String id, double sLat, double sLng, double aLat, double aLng) =>
//       '$id@$sLat,$sLng@$aLat,$aLng';

//   int? _bucketIndexForDistance(double km) {
//     if (km <= 1.5) return 1;
//     if (km <= 2.5) return 2;
//     if (km <= 5.0) return 3;
//     if (km <= 7.5) return 4;
//     if (km <= 10.0) return 5;
//     if (km <= 20.0) return 6;
//     if (km <= 30.0) return 7;
//     if (km <= 50.0) return 8;
//     if (km <= 100.0) return 9;
//     if (km <= 200.0) return 10;
//     if (km <= 500.0) return 11;
//     if (km <= 1000.0) return 12;
//     if (km <= 2000.0) return 13;
//     if (km <= 5000.0) return 14;
//     return null;
//   }

//   int? _bucketIndexForRoad123(double km) {
//     if (km <= 1.5) return 1;
//     if (km <= 2.5) return 2;
//     if (km <= 5.0) return 3;
//     return null;
//   }

//   bool _validCoord(double lat, double lng) {
//     if (lat == 0.0 && lng == 0.0) return false;
//     return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
//   }

//   double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
//     const R = 6371.0088;
//     double _rad(double d) => d * math.pi / 180.0;
//     final dLat = _rad(lat2 - lat1);
//     final dLon = _rad(lon2 - lon1);
//     final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
//         math.cos(_rad(lat1)) *
//             math.cos(_rad(lat2)) *
//             math.sin(dLon / 2) *
//             math.sin(dLon / 2);
//     final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
//     return R * c;
//   }

//   void _safeSetState(VoidCallback fn) {
//     if (!mounted) return;
//     final phase = SchedulerBinding.instance.schedulerPhase;
//     if (phase == SchedulerPhase.idle ||
//         phase == SchedulerPhase.postFrameCallbacks) {
//       setState(fn);
//     } else {
//       WidgetsBinding.instance.addPostFrameCallback((_) {
//         if (mounted) setState(fn);
//       });
//     }
//   }
// }

// // ───────────────────── Small UI bits ─────────────────────

// class _RowSpec {
//   final int? index;
//   final String? name;
//   final String? range;
//   final int? count;
//   final String? pill;
//   final Color? pillColor;

//   _RowSpec._bucket(
//       this.index, this.name, this.range, this.count, this.pill, this.pillColor);

//   factory _RowSpec.bucket({
//     required int index,
//     required String name,
//     required String range,
//     required int count,
//     required String pill,
//     required Color pillColor,
//   }) =>
//       _RowSpec._bucket(index, name, range, count, pill, pillColor);
// }

// Widget _pill(String text, Color color) {
//   return Container(
//     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//     decoration: BoxDecoration(
//       color: color.withOpacity(0.1),
//       borderRadius: BorderRadius.circular(999),
//       border: Border.all(color: color.withOpacity(0.5)),
//     ),
//     child: Text(
//       text,
//       style:
//           TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
//     ),
//   );
// }

// class _BucketMeta {
//   final String name;
//   final String range;
//   final IconData icon;
//   const _BucketMeta(this.name, this.range, this.icon);
// }

// _BucketMeta _bucketMeta(int index) {
//   const names = <int, String>{
//     1: 'Next to you',
//     2: 'Very near',
//     3: 'Near',
//     4: 'Quite near',
//     5: 'A little far',
//     6: 'Far',
//     7: 'Quite far',
//     8: 'Very far',
//     9: 'Super far',
//     10: 'Extreme far',
//     11: 'Long haul',
//     12: 'Long haul+',
//     13: 'Ultra long',
//     14: 'Epic',
//   };

//   const ranges = <int, String>{
//     1: '(≤ 1.5 km)',
//     2: '(1.51 – 2.5 km)',
//     3: '(2.51 – 5 km)',
//     4: '(5.1 – 7.5 km)',
//     5: '(7.51 – 10 km)',
//     6: '(10.1 – 20 km)',
//     7: '(20.1 – 30 km)',
//     8: '(30.1 – 50 km)',
//     9: '(50.1 – 100 km)',
//     10: '(100.1 – 200 km)',
//     11: '(200.1 – 500 km)',
//     12: '(500.1 – 1000 km)',
//     13: '(1000.1 – 2000 km)',
//     14: '(2000.1 – 5000 km)',
//   };

//   final icons = <IconData>[
//     Icons.place_outlined,
//     Icons.directions_walk,
//     Icons.directions_bike,
//     Icons.directions_car,
//     Icons.local_taxi,
//     Icons.route,
//     Icons.alt_route,
//     Icons.signpost_outlined,
//     Icons.fork_right,
//     Icons.rocket_launch_outlined,
//     Icons.public,
//     Icons.flight_takeoff,
//     Icons.flight,
//     Icons.public_off,
//   ];
//   final icon = icons[(index - 1) % icons.length];

//   return _BucketMeta(
//     names[index] ?? 'Bucket $index',
//     ranges[index] ?? '',
//     icon,
//   );
// }


// // import 'dart:async';
// // import 'dart:convert';
// // import 'dart:math' as math;
// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:flutter/material.dart';
// // import 'package:flutter/scheduler.dart';
// // import 'package:http/http.dart' as http;

// // import 'package:luckygo_pemandu/global.dart';
// // import 'package:luckygo_pemandu/jobFilter/b1_air_list_page.dart';
// // import 'package:luckygo_pemandu/jobFilter/bucket123.dart';
// // import 'package:luckygo_pemandu/jobFilter/bucket414.dart';
// // import 'package:luckygo_pemandu/jobFilter/filter_jobs_helper.dart'; // ShortJob

// // /// Single-stream page:
// // /// - Section A (Buckets 1–3): ROAD distance for jobs whose AIR ≤ 7.5 km
// // /// - Section B (Buckets 4–14): AIR distance
// // /// - Re-anchors when driver moves ≥ 500 m and *stops* (debounced), then recomputes & refetches ROAD.
// // class FilterJobsOneStream extends StatefulWidget {
// //   const FilterJobsOneStream({super.key});

// //   @override
// //   State<FilterJobsOneStream> createState() => _FilterJobsOneStreamState();
// // }

// // class _FilterJobsOneStreamState extends State<FilterJobsOneStream> {
// //   late final DocumentReference<Map<String, dynamic>> _docRef;

// //   // Latest Firestore doc
// //   Map<String, dynamic> _raw = const {};

// //   // AIR counts for 1..14 (we display 4..14 from this)
// //   Map<int, int> _airCountsAll = const {};

// //   // Shortlist (AIR ≤ 7.5 km) for ROAD fetching
// //   List<ShortJob> _shortlist = const [];

// //   // ROAD overlay counts for 1..3
// //   Map<int, int> _roadCounts123 = const {};

// //   // ROAD km cache (key: "jobId@sLat,sLng@anchorLat,anchorLng" -> km)
// //   final Map<String, double> _roadKmCache = {};
// //   final Set<String> _inFlight = {}; // prevent duplicate requests

// //   bool _loadingRoad = false;
// //   StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

// //   // ───────── Anchor state (500 m re-anchor with stop-detect) ─────────
// //   // We keep our own anchor instead of calling Gv.driverLat/Lng dynamically.
// //   late double _anchorLat;
// //   late double _anchorLng;

// //   // Poller to watch driver movement (uses Gv.* that your app updates elsewhere)
// //   Timer? _locPollTimer;

// //   // Debounce timer to detect "stopped" after moving >= 500 m
// //   Timer? _reanchorDebounce;

// //   static const _reanchorMeters = 500.0;
// //   static const _pollInterval = Duration(seconds: 2);
// //   static const _stopDebounce = Duration(seconds: 3);

// //   @override
// //   void initState() {
// //     super.initState();

// //     // Initialize anchor from current driver location (if valid); else leave at 0/0 (won't compute until valid)
// //     _anchorLat = Gv.driverLat;
// //     _anchorLng = Gv.driverLng;

// //     _docRef = FirebaseFirestore.instance
// //         .collection(Gv.negara)
// //         .doc(Gv.negeri)
// //         .collection('active_job')
// //         .doc('active_job_lite');

// //     // Single Firestore stream
// //     _sub = _docRef.snapshots(includeMetadataChanges: true).listen((snap) {
// //       debugPrint(
// //           '[FJOS] snapshot >>> anchor=(${_anchorLat.toStringAsFixed(6)}, ${_anchorLng.toStringAsFixed(6)}) negara=${Gv.negara} negeri=${Gv.negeri}');

// //       final data = snap.data() ?? const {};
// //       _raw = data;

// //       // Rebuild for CURRENT anchor (free) — then schedule ROAD
// //       _rebuildForAnchorAndScheduleRoad();
// //     });

// //     // Start polling driver location to decide when to re-anchor
// //     _startLocationPolling();
// //   }

// //   @override
// //   void dispose() {
// //     _sub?.cancel();
// //     _locPollTimer?.cancel();
// //     _reanchorDebounce?.cancel();
// //     super.dispose();
// //   }

// //   // ─────────────────────────── BUILD ───────────────────────────

// //   @override
// //   Widget build(BuildContext context) {
// //     final cap = Gv.groupCapability.clamp(0, 14);

// //     if (Gv.negara.isEmpty || Gv.negeri.isEmpty) {
// //       return const Scaffold(
// //         body: Center(child: Text('⚠ Set Gv.negara & Gv.negeri first.')),
// //       );
// //     }

// //     // Prepare rows: Section A (b1..b3 ROAD), Section B (b4..cap AIR)
// //     final rows = <_RowSpec>[];

// //     for (var i = 1; i <= math.min(3, cap); i++) {
// //       rows.add(_RowSpec.bucket(
// //         index: i,
// //         name: _bucketMeta(i).name,
// //         range: _bucketMeta(i).range,
// //         count: _roadCounts123[i] ?? 0,
// //         pill: 'ROAD',
// //         pillColor: Colors.teal,
// //       ));
// //     }

// //     if (cap >= 4) {
// //       for (var i = 4; i <= cap; i++) {
// //         rows.add(_RowSpec.bucket(
// //           index: i,
// //           name: _bucketMeta(i).name,
// //           range: _bucketMeta(i).range,
// //           count: _airCountsAll[i] ?? 0,
// //           pill: 'AIR',
// //           pillColor: Colors.indigo,
// //         ));
// //       }
// //     }

// //     return Scaffold(
// //       appBar: AppBar(
// //         title: const Text('Nearby Buckets (One Stream)'),
// //         actions: [
// //           IconButton(
// //             tooltip: 'Dump ≤7.5km list',
// //             icon: const Icon(Icons.bug_report),
// //             onPressed: () => _dumpBucket4Jobs(reason: 'manual dump via AppBar'),
// //           ),
// //           if (_loadingRoad)
// //             const Padding(
// //               padding: EdgeInsets.only(right: 12),
// //               child: Center(
// //                 child: SizedBox(
// //                   width: 16, height: 16,
// //                   child: CircularProgressIndicator(strokeWidth: 2),
// //                 ),
// //               ),
// //             ),
// //           IconButton(
// //             tooltip: 'Force server refresh',
// //             icon: const Icon(Icons.refresh),
// //             onPressed: _pokeServer,
// //           ),
// //         ],
// //       ),
// //       body: Column(
// //         children: [
// //           Padding(
// //             padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
// //             child: SizedBox(
// //               width: double.infinity,
// //               child: ElevatedButton.icon(
// //                 icon: const Icon(Icons.list_alt),
// //                 label: const Text('Show ≤1.5km AIR jobs'),
// //                 style: ElevatedButton.styleFrom(
// //                   backgroundColor: Colors.indigo,
// //                   foregroundColor: Colors.white,
// //                   padding: const EdgeInsets.symmetric(vertical: 12),
// //                   textStyle: const TextStyle(fontWeight: FontWeight.w600),
// //                 ),
// //                 onPressed: () {
// //                   Navigator.push(
// //                     context,
// //                     MaterialPageRoute(builder: (_) => const B1AirListPage()),
// //                   );
// //                 },
// //               ),
// //             ),
// //           ),
// //           ListView.separated(
// //             padding: const EdgeInsets.symmetric(vertical: 8),
// //             separatorBuilder: (_, __) => const Divider(height: 1),
// //             itemCount: rows.length,
// //             itemBuilder: (context, idx) {
// //               final r = rows[idx];
// //               final i = r.index!;
// //               return InkWell(
// //                 onTap: (r.count ?? 0) <= 0
// //                     ? null
// //                     : () {
// //                         final i = r.index!;
// //                         final Widget dest = (i <= 3)
// //                             ? Bucket123(bucketIndex: i) // b1–b3
// //                             : Bucket414(bucketIndex: i); // b4–b14
// //                         Navigator.push(
// //                           context,
// //                           MaterialPageRoute(builder: (_) => dest),
// //                         );
// //                       },
// //                 child: Padding(
// //                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
// //                   child: Row(
// //                     children: [
// //                       // icon
// //                       Container(
// //                         width: 36,
// //                         height: 36,
// //                         decoration: BoxDecoration(
// //                           color: Colors.black.withOpacity(0.06),
// //                           shape: BoxShape.circle,
// //                         ),
// //                         child:
// //                             Icon(_bucketMeta(i).icon, size: 20, color: Colors.black87),
// //                       ),
// //                       const SizedBox(width: 12),
// //                       // labels
// //                       Expanded(
// //                         child: Column(
// //                           crossAxisAlignment: CrossAxisAlignment.start,
// //                           children: [
// //                             Row(children: [
// //                               Text(r.name!,
// //                                   maxLines: 1,
// //                                   overflow: TextOverflow.ellipsis,
// //                                   style: const TextStyle(
// //                                       fontSize: 14, fontWeight: FontWeight.w600)),
// //                               const SizedBox(width: 8),
// //                               _pill(r.pill!, r.pillColor!),
// //                             ]),
// //                             const SizedBox(height: 2),
// //                             Text(
// //                               r.range!,
// //                               maxLines: 1,
// //                               overflow: TextOverflow.ellipsis,
// //                               style: TextStyle(
// //                                 fontSize: 10,
// //                                 color: Theme.of(context)
// //                                     .textTheme
// //                                     .bodySmall
// //                                     ?.color
// //                                     ?.withOpacity(0.8),
// //                               ),
// //                             ),
// //                           ],
// //                         ),
// //                       ),
// //                       const SizedBox(width: 12),
// //                       // count
// //                       Container(
// //                         padding:
// //                             const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
// //                         decoration: BoxDecoration(
// //                           color: Colors.black.withOpacity(0.05),
// //                           borderRadius: BorderRadius.circular(999),
// //                         ),
// //                         child: Text('${r.count ?? 0}',
// //                             style: const TextStyle(
// //                                 fontSize: 12, fontWeight: FontWeight.w600)),
// //                       ),
// //                     ],
// //                   ),
// //                 ),
// //               );
// //             },
// //           ),
// //         ],
// //       ),
// //     );
// //   }

// //   // ───────────────────── LIVE / IO ─────────────────────

// //   Future<void> _pokeServer() async {
// //     try {
// //       await _docRef.get(const GetOptions(source: Source.server));
// //     } catch (_) {}
// //   }

// //   // Rebuild AIR & shortlist for the *current* anchor, then schedule ROAD
// //   void _rebuildForAnchorAndScheduleRoad() {
// //     // publish the anchor so other pages can use consistent keys
// //     Gv.roadAnchorLat = _anchorLat;
// //     Gv.roadAnchorLng = _anchorLng;

// //     // 1) AIR for all buckets (free)
// //     final airCounts = _computeAirCountsAll(_raw, _anchorLat, _anchorLng);
// //     _logAirCounts(airCounts);

// //     // 2) Shortlist (AIR ≤ 7.5 km)
// //     final shortlist = _buildShortlistLe7p5(_raw, _anchorLat, _anchorLng);
// //     debugPrint('[FJOS] shortlist<=7.5km size=${shortlist.length}');

// //     // 2a) Publish shortlist globally (Bucket 4 list) + dump it
// //     Gv.setBucket4Jobs(shortlist);
// //     _dumpBucket4Jobs(reason: 'after shortlist build');

// //     // 3) Update UI now
// //     _safeSetState(() {
// //       _airCountsAll = airCounts;
// //       _shortlist = shortlist;
// //     });

// //     // 4) Schedule ROAD fetch for missing (NOT in build)
// //     WidgetsBinding.instance.addPostFrameCallback((_) {
// //       _fetchRoadForCurrentShortlist();
// //     });
// //   }

// //   // Called after snapshot processing — never inside build
// //   Future<void> _fetchRoadForCurrentShortlist() async {
// //     if (_shortlist.isEmpty) {
// //       debugPrint('[FJOS] _fetchRoadForCurrentShortlist: shortlist empty.');
// //       if (_loadingRoad) _safeSetState(() => _loadingRoad = false);
// //       _rebuildRoadOverlayFromCache(); // will set zeros
// //       return;
// //     }

// //     // Determine current desired keys for this anchor
// //     final desired = _shortlist
// //         .map((j) => _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng))
// //         .toSet();

// //     // Evict cache entries that are no longer relevant
// //     if (_roadKmCache.isNotEmpty) {
// //       _roadKmCache.removeWhere((k, _) => !desired.contains(k));
// //     }

// //     // Missing items (not cached, not currently being fetched)
// //     final missing = _shortlist.where((j) {
// //       final k = _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng);
// //       return !_roadKmCache.containsKey(k) && !_inFlight.contains(k);
// //     }).toList();

// //     debugPrint(
// //         '[FJOS] ROAD fetch: shortlist=${_shortlist.length}, missing=${missing.length}, cache=${_roadKmCache.length}, inFlight=${_inFlight.length}');

// //     if (missing.isEmpty) {
// //       _rebuildRoadOverlayFromCache();
// //       return;
// //     }

// //     _safeSetState(() => _loadingRoad = true);

// //     // Fetch in batches
// //     const batchSize = 25;
// //     for (var i = 0; i < missing.length; i += batchSize) {
// //       final batch = missing.sublist(i, math.min(i + batchSize, missing.length));

// //       // mark in-flight
// //       final batchKeys = <String>[];
// //       for (final j in batch) {
// //         final k = _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng);
// //         batchKeys.add(k);
// //         _inFlight.add(k);
// //       }

// //       try {
// //         final m = await _callDistanceMatrix(
// //           originLat: _anchorLat,
// //           originLng: _anchorLng,
// //           jobs: batch,
// //         );
// //         if (m.isNotEmpty) {
// //           _roadKmCache.addAll(m);
// //           _rebuildRoadOverlayFromCache(); // update counts incrementally
// //         }
// //       } finally {
// //         _inFlight.removeAll(batchKeys);
// //       }
// //     }

// //     _safeSetState(() => _loadingRoad = false);
// //   }

// //   // ───────────────────── PURE COMPUTE ─────────────────────

// //   Map<int, int> _computeAirCountsAll(
// //     Map<String, dynamic> raw,
// //     double dLat,
// //     double dLng,
// //   ) {
// //     final counts = {for (var i = 1; i <= 14; i++) i: 0};

// //     raw.forEach((jobId, v) {
// //       if (v is! String) return;
// //       final p = v.split('·').map((s) => s.trim()).toList(growable: false);
// //       if (p.length != 33) return;

// //       final sLat = double.tryParse(p[11]);
// //       final sLng = double.tryParse(p[12]);
// //       if (sLat == null || sLng == null) return;
// //       if (!_validCoord(sLat, sLng)) return;

// //       final km = _haversineKm(dLat, dLng, sLat, sLng);
// //       final b = _bucketIndexForDistance(km);
// //       if (b != null) counts[b] = (counts[b] ?? 0) + 1;
// //     });

// //     return counts;
// //   }

// //   List<ShortJob> _buildShortlistLe7p5(
// //     Map<String, dynamic> raw,
// //     double dLat,
// //     double dLng,
// //   ) {
// //     final list = <ShortJob>[];
// //     raw.forEach((jobId, v) {
// //       if (v is! String) return;
// //       final p = v.split('·').map((s) => s.trim()).toList(growable: false);
// //       if (p.length != 33) return;

// //       final sLat = double.tryParse(p[11]);
// //       final sLng = double.tryParse(p[12]);
// //       if (sLat == null || sLng == null) return;
// //       if (!_validCoord(sLat, sLng)) return;

// //       final airKm = _haversineKm(dLat, dLng, sLat, sLng);
// //       if (airKm <= 7.5) {
// //         list.add(ShortJob(jobId: '$jobId', sLat: sLat, sLng: sLng));
// //       }
// //     });
// //     return list;
// //   }

// //   void _rebuildRoadOverlayFromCache() {
// //     var b1 = 0, b2 = 0, b3 = 0;
// //     for (final j in _shortlist) {
// //       final k =
// //           _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng);
// //       final roadKm = _roadKmCache[k];
// //       if (roadKm == null) continue;
// //       final b = _bucketIndexForRoad123(roadKm);
// //       if (b == 1) {
// //         b1++;
// //       } else if (b == 2) {
// //         b2++;
// //       } else if (b == 3) {
// //         b3++;
// //       }
// //     }
// //     final overlay = {1: b1, 2: b2, 3: b3};
// //     debugPrint(
// //         '[FJOS] overlay123 from cache: $overlay  (cache=${_roadKmCache.length})');

// //     _safeSetState(() {
// //       _roadCounts123 = overlay;
// //     });
// //   }

// //   // ───────────────────── ROAD lookup ─────────────────────

// //   Future<Map<String, double>> _callDistanceMatrix({
// //     required double originLat,
// //     required double originLng,
// //     required List<ShortJob> jobs,
// //   }) async {
// //     final apiKey = (Gv.googleApiKey).trim();
// //     if (apiKey.isEmpty || jobs.isEmpty) {
// //       debugPrint(
// //           '[FJOS] DistanceMatrix: apiKey empty? ${apiKey.isEmpty}, jobs=${jobs.length}');
// //       return {};
// //     }

// //     final origin =
// //         '${originLat.toStringAsFixed(6)},${originLng.toStringAsFixed(6)}';
// //     final destinations = jobs
// //         .map((j) =>
// //             '${j.sLat.toStringAsFixed(6)},${j.sLng.toStringAsFixed(6)}')
// //         .join('|');

// //     final uri = Uri.parse(
// //       'https://maps.googleapis.com/maps/api/distancematrix/json'
// //       '?origins=$origin'
// //       '&destinations=$destinations'
// //       '&mode=driving'
// //       '&departure_time=now'
// //       '&key=$apiKey',
// //     );

// //     try {
// //       debugPrint(
// //           '[FJOS] DM call → ${uri.toString().substring(0, 120)}...  (dest=${jobs.length})');
// //       final resp = await http.get(uri);
// //       if (resp.statusCode != 200) {
// //         debugPrint('[FJOS] DM http=${resp.statusCode}');
// //         return {};
// //       }

// //       final map = jsonDecode(resp.body) as Map<String, dynamic>;
// //       final topStatus = map['status'] as String?;
// //       debugPrint('[FJOS] DM top status: $topStatus');
// //       if (topStatus != 'OK') return {};

// //       final rows = (map['rows'] as List?) ?? const [];
// //       if (rows.isEmpty) return {};
// //       final elements = (rows.first['elements'] as List?) ?? const [];

// //       final out = <String, double>{};
// //       final n = math.min(elements.length, jobs.length);

// //       for (var i = 0; i < n; i++) {
// //         final e = elements[i] as Map<String, dynamic>?;
// //         if (e?['status'] != 'OK') continue;

// //         final distMeters = (e?['distance']?['value'] as num?)?.toDouble();
// //         if (distMeters == null) continue;
// //         final km = double.parse((distMeters / 1000.0).toStringAsFixed(1));

// //         // prefer duration_in_traffic if present, else duration
// //         final dur = (e?['duration_in_traffic'] ?? e?['duration'])
// //             as Map<String, dynamic>?;
// //         final secs = (dur?['value'] as num?)?.toInt() ?? 0;
// //         final etaMin = (secs / 60).round();

// //         final j = jobs[i];
// //         final key = _cacheKey(
// //             j.jobId, j.sLat, j.sLng, originLat, originLng);

// //         // local cache used for overlay counts
// //         out[key] = km;

// //         // persist to global so Bucket123 can read immediately
// //         Gv.roadAnchorLat = originLat;
// //         Gv.roadAnchorLng = originLng;
// //         Gv.roadByJob[key] = JobCalc(roadKm: km, etaMin: etaMin);
// //       }

// //       debugPrint('[FJOS] DM mapped results: ${out.length}/${jobs.length}');
// //       return out;
// //     } catch (e) {
// //       debugPrint('[FJOS] DM error: $e');
// //       return {};
// //     }
// //   }

// //   // ───────────────────── Anchor movement logic ─────────────────────

// //   void _startLocationPolling() {
// //     _locPollTimer?.cancel();
// //     _locPollTimer = Timer.periodic(_pollInterval, (_) {
// //       final curLat = Gv.driverLat;
// //       final curLng = Gv.driverLng;
// //       if (!_validCoord(curLat, curLng) || !_validCoord(_anchorLat, _anchorLng)) {
// //         // If anchor invalid but current valid, allow first anchor promotion fast.
// //         if (_validCoord(curLat, curLng) && !_validCoord(_anchorLat, _anchorLng)) {
// //           _scheduleReanchor(curLat, curLng);
// //         }
// //         return;
// //       }

// //       final movedM =
// //           _haversineKm(_anchorLat, _anchorLng, curLat, curLng) * 1000.0;
// //       if (movedM >= _reanchorMeters) {
// //         // Driver is far enough from anchor; wait until they "stop" (debounce).
// //         _scheduleReanchor(curLat, curLng);
// //       } else {
// //         // Not far enough → cancel any pending reanchor
// //         _reanchorDebounce?.cancel();
// //         _reanchorDebounce = null;
// //       }
// //     });
// //   }

// //   void _scheduleReanchor(double lat, double lng) {
// //     // If driver keeps moving, we'll keep resetting this timer.
// //     _reanchorDebounce?.cancel();
// //     _reanchorDebounce = Timer(_stopDebounce, () {
// //       // Promote this location as new anchor
// //       final newLat = Gv.driverLat;
// //       final newLng = Gv.driverLng;
// //       if (!_validCoord(newLat, newLng)) return;

// //       final distM =
// //           _haversineKm(_anchorLat, _anchorLng, newLat, newLng) * 1000.0;
// //       if (distM < _reanchorMeters) return; // in case we drifted back

// //       debugPrint(
// //           '[FJOS] Re-anchoring: old=(${_anchorLat.toStringAsFixed(6)},${_anchorLng.toStringAsFixed(6)}) '
// //           'new=(${newLat.toStringAsFixed(6)},${newLng.toStringAsFixed(6)}) dist=${distM.toStringAsFixed(1)}m');

// //       // Update anchor (must be inside this callback where newLat/newLng exist)
// //       _anchorLat = newLat;
// //       _anchorLng = newLng;

// //       // Publish anchor so other pages can look up ROAD results with the same key
// //       Gv.roadAnchorLat = _anchorLat;
// //       Gv.roadAnchorLng = _anchorLng;

// //       // ROAD cache keys depend on anchor → clear cache & in-flight
// //       _roadKmCache.clear();
// //       _inFlight.clear();

// //       // Rebuild everything for new anchor and refetch ROAD
// //       _rebuildForAnchorAndScheduleRoad();
// //     });
// //   }

// //   // ───────────────────── helpers ─────────────────────

// //   void _dumpBucket4Jobs({required String reason}) {
// //     final list = Gv.bucket4Jobs;
// //     debugPrint(
// //         '[FJOS] DUMP bucket4Jobs ($reason): count=${list.length} builtAt=${Gv.bucket4LastBuiltAt} ver=${Gv.bucket4Version.value}');
// //     for (var i = 0; i < list.length && i < 50; i++) {
// //       final j = list[i];
// //       final key =
// //           _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng);
// //       debugPrint(
// //           '  [$i] jobId=${j.jobId} s=(${j.sLat.toStringAsFixed(6)},${j.sLng.toStringAsFixed(6)}) key=$key');
// //     }
// //     if (list.length > 50) {
// //       debugPrint('  ... +${list.length - 50} more');
// //     }
// //   }

// //   void _logAirCounts(Map<int, int> c) {
// //     final sb = StringBuffer('AIR counts: ');
// //     for (var i = 1; i <= 14; i++) {
// //       if (i > 1) sb.write(', ');
// //       sb.write('$i:${c[i] ?? 0}');
// //     }
// //     debugPrint('[FJOS] $sb');
// //   }

// //   String _cacheKey(
// //           String id, double sLat, double sLng, double aLat, double aLng) =>
// //       '$id@$sLat,$sLng@$aLat,$aLng';

// //   int? _bucketIndexForDistance(double km) {
// //     if (km <= 1.5) return 1;
// //     if (km <= 2.5) return 2;
// //     if (km <= 5.0) return 3;
// //     if (km <= 7.5) return 4;
// //     if (km <= 10.0) return 5;
// //     if (km <= 20.0) return 6;
// //     if (km <= 30.0) return 7;
// //     if (km <= 50.0) return 8;
// //     if (km <= 100.0) return 9;
// //     if (km <= 200.0) return 10;
// //     if (km <= 500.0) return 11;
// //     if (km <= 1000.0) return 12;
// //     if (km <= 2000.0) return 13;
// //     if (km <= 5000.0) return 14;
// //     return null;
// //   }

// //   int? _bucketIndexForRoad123(double km) {
// //     if (km <= 1.5) return 1;
// //     if (km <= 2.5) return 2;
// //     if (km <= 5.0) return 3;
// //     return null;
// //   }

// //   bool _validCoord(double lat, double lng) {
// //     if (lat == 0.0 && lng == 0.0) return false;
// //     return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
// //   }

// //   double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
// //     const R = 6371.0088;
// //     double _rad(double d) => d * math.pi / 180.0;
// //     final dLat = _rad(lat2 - lat1);
// //     final dLon = _rad(lon2 - lon1);
// //     final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
// //         math.cos(_rad(lat1)) *
// //             math.cos(_rad(lat2)) *
// //             math.sin(dLon / 2) *
// //             math.sin(dLon / 2);
// //     final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
// //     return R * c;
// //   }

// //   void _safeSetState(VoidCallback fn) {
// //     if (!mounted) return;
// //     final phase = SchedulerBinding.instance.schedulerPhase;
// //     if (phase == SchedulerPhase.idle ||
// //         phase == SchedulerPhase.postFrameCallbacks) {
// //       setState(fn);
// //     } else {
// //       WidgetsBinding.instance.addPostFrameCallback((_) {
// //         if (mounted) setState(fn);
// //       });
// //     }
// //   }
// // }

// // // ───────────────────── Small UI bits ─────────────────────

// // class _RowSpec {
// //   final int? index;
// //   final String? name;
// //   final String? range;
// //   final int? count;
// //   final String? pill;
// //   final Color? pillColor;

// //   _RowSpec._bucket(
// //       this.index, this.name, this.range, this.count, this.pill, this.pillColor);

// //   factory _RowSpec.bucket({
// //     required int index,
// //     required String name,
// //     required String range,
// //     required int count,
// //     required String pill,
// //     required Color pillColor,
// //   }) =>
// //       _RowSpec._bucket(index, name, range, count, pill, pillColor);
// // }

// // Widget _pill(String text, Color color) {
// //   return Container(
// //     padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
// //     decoration: BoxDecoration(
// //       color: color.withOpacity(0.1),
// //       borderRadius: BorderRadius.circular(999),
// //       border: Border.all(color: color.withOpacity(0.5)),
// //     ),
// //     child: Text(
// //       text,
// //       style:
// //           TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
// //     ),
// //   );
// // }

// // class _BucketMeta {
// //   final String name;
// //   final String range;
// //   final IconData icon;
// //   const _BucketMeta(this.name, this.range, this.icon);
// // }

// // _BucketMeta _bucketMeta(int index) {
// //   const names = <int, String>{
// //     1: 'Next to you',
// //     2: 'Very near',
// //     3: 'Near',
// //     4: 'Quite near',
// //     5: 'A little far',
// //     6: 'Far',
// //     7: 'Quite far',
// //     8: 'Very far',
// //     9: 'Super far',
// //     10: 'Extreme far',
// //     11: 'Long haul',
// //     12: 'Long haul+',
// //     13: 'Ultra long',
// //     14: 'Epic',
// //   };

// //   const ranges = <int, String>{
// //     1: '(≤ 1.5 km)',
// //     2: '(1.51 – 2.5 km)',
// //     3: '(2.51 – 5 km)',
// //     4: '(5.1 – 7.5 km)',
// //     5: '(7.51 – 10 km)',
// //     6: '(10.1 – 20 km)',
// //     7: '(20.1 – 30 km)',
// //     8: '(30.1 – 50 km)',
// //     9: '(50.1 – 100 km)',
// //     10: '(100.1 – 200 km)',
// //     11: '(200.1 – 500 km)',
// //     12: '(500.1 – 1000 km)',
// //     13: '(1000.1 – 2000 km)',
// //     14: '(2000.1 – 5000 km)',
// //   };

// //   final icons = <IconData>[
// //     Icons.place_outlined,
// //     Icons.directions_walk,
// //     Icons.directions_bike,
// //     Icons.directions_car,
// //     Icons.local_taxi,
// //     Icons.route,
// //     Icons.alt_route,
// //     Icons.signpost_outlined,
// //     Icons.fork_right,
// //     Icons.rocket_launch_outlined,
// //     Icons.public,
// //     Icons.flight_takeoff,
// //     Icons.flight,
// //     Icons.public_off,
// //   ];
// //   final icon = icons[(index - 1) % icons.length];

// //   return _BucketMeta(
// //     names[index] ?? 'Bucket $index',
// //     ranges[index] ?? '',
// //     icon,
// //   );
// // }
