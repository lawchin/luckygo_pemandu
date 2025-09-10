import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:http/http.dart' as http;
import 'package:luckygo_pemandu/end_drawer/deposit_page.dart';
import 'package:luckygo_pemandu/gen_l10n/app_localizations.dart';

import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/jobFilter/bucket123b.dart';
import 'package:luckygo_pemandu/jobFilter/bucket414.dart';
import 'package:luckygo_pemandu/jobFilter/filter_jobs_helper.dart';
import 'package:luckygo_pemandu/landing%20page/landing_page.dart'; // ShortJob
import 'package:luckygo_pemandu/view15/view_15.dart'; // View15 has no constructor args

/// Single-stream page (v2):
/// - Accepts 35-token records (indexes 0..34)
/// - Prints token[33] and token[34]
class FilterJobsOneStream2 extends StatefulWidget {
  const FilterJobsOneStream2({super.key});

  @override
  State<FilterJobsOneStream2> createState() => _FilterJobsOneStream2State();
}

// ---------- Lite parser + hydrator (global helpers) ----------
String _tokSafe(List<String> p, int i) => (i >= 0 && i < p.length) ? p[i].trim() : '';
List<String> _splitLite(String s) => s.split('·').map((e) => e.trim()).toList(growable: false);
double _toD(String s) => double.tryParse(s) ?? 0.0;
int _toI(String s) => int.tryParse(s) ?? 0;
bool _toB(String s) {
  final t = s.trim().toLowerCase();
  return t == 'true' || t == '1' || t == 'yes';
}
String _nz(String s) => (s == '-' ? '' : s);

void _hydrateGlobalsFromLite(String jobId, String lite) {
  final p = _splitLite(lite);

  Gv.liteJobId   = jobId;
  Gv.liteJobData = lite;

  Gv.passengerPhone   = _tokSafe(p, 1).replaceAll(RegExp(r'\D'), '');
  Gv.passengerCount   = _toI(_tokSafe(p, 3));
  Gv.totalKm          = _toD(_tokSafe(p, 4));
  Gv.totalPrice       = _toD(_tokSafe(p, 5));
  Gv.markerCount      = _toI(_tokSafe(p, 6)).clamp(2, 7);

  Gv.sAdd1 = _nz(_tokSafe(p, 7));
  Gv.sAdd2 = _nz(_tokSafe(p, 8));
  Gv.dAdd1 = _nz(_tokSafe(p, 9));
  Gv.dAdd2 = _nz(_tokSafe(p,10));

  final sLat = _toD(_tokSafe(p,11));
  final sLng = _toD(_tokSafe(p,12));
  // final dLat = _toD(_tokSafe(p,13));
  // final dLng = _toD(_tokSafe(p,14));
  Gv.passengerGp = GeoPoint(sLat, sLng);

  Gv.isBlind  = _toB(_tokSafe(p,15));
  Gv.isDeaf   = _toB(_tokSafe(p,16));
  Gv.isMute   = _toB(_tokSafe(p,17));

  Gv.wheelchairCount   = _toI(_tokSafe(p,18));
  Gv.supportStickCount = _toI(_tokSafe(p,19));
  Gv.babyStrollerCount = _toI(_tokSafe(p,20));
  Gv.shoppingBagCount  = _toI(_tokSafe(p,21));
  Gv.luggageCount      = _toI(_tokSafe(p,22));
  Gv.petsCount         = _toI(_tokSafe(p,23));
  Gv.dogCount          = _toI(_tokSafe(p,24));
  Gv.goatCount         = _toI(_tokSafe(p,25));
  Gv.roosterCount      = _toI(_tokSafe(p,26));
  Gv.snakeCount        = _toI(_tokSafe(p,27));
  Gv.durianCount       = _toI(_tokSafe(p,28));
  Gv.odourFruitsCount  = _toI(_tokSafe(p,29));
  Gv.wetFoodCount      = _toI(_tokSafe(p,30));
  Gv.tupperwareCount   = _toI(_tokSafe(p,31));
  Gv.gasTankCount      = _toI(_tokSafe(p,32));
}

// Capacity gate: use global `vehicleCapacity` to validate index[3]
bool _fitsCapacityFromLite(String lite) {
  final p  = _splitLite(lite);
  final pc = _toI(_tokSafe(p, 3)); // index[3] = passenger count
  final cap = (Gv.vehicleCapacity <= 0) ? 3 : Gv.vehicleCapacity; // minimal fallback
  return pc >= 1 && pc <= cap;
}

class _FilterJobsOneStream2State extends State<FilterJobsOneStream2> {
  // ---- DEBUG HELPERS ----
  static const String _TAG = '[AUTO]';
  void _log(String msg) => debugPrint('$_TAG $msg');

  // ── Negative balance dialog state (robust against rebuilds)
  bool _negDialogShown = false;
  BuildContext? _negDialogCtx;

  Widget _negativeBalanceWatcher() {
    if (Gv.loggedUser.isEmpty || Gv.negara.isEmpty || Gv.negeri.isEmpty) {
      return const SizedBox.shrink();
    }

    final driverRef = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('driver_account')
        .doc(Gv.loggedUser);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: driverRef.snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();

        final data = snap.data!.data();
        final ab = ((data?['account_balance'] as num?) ?? 0).toDouble();

        if (ab <= 0 && !_negDialogShown) {
          _negDialogShown = true;
          Future.microtask(() {
            if (!mounted) return;
            showDialog(
              context: ctx,
              barrierDismissible: false,
              builder: (dCtx) {
                _negDialogCtx = dCtx;
                return AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Text(AppLocalizations.of(context)!.plsReload),
                  content: Text(
                    '${AppLocalizations.of(context)!.balanceIs} ${Gv.currency} ${ab.toStringAsFixed(2)}.\n'
                    '${AppLocalizations.of(context)!.plsReload}',
                    textAlign: TextAlign.left,
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(dCtx).pop();
                        _negDialogShown = false;
                        if (!mounted) return;
                        Navigator.of(ctx).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LandingPage()),
                          (route) => false,
                        );
                      },
                      child: const Text('Back'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(dCtx).pop();
                        _negDialogShown = false;
                        if (!mounted) return;
                        Navigator.of(ctx).push(
                          MaterialPageRoute(builder: (_) => const DepositPage()),
                        );
                      },
                      child: const Text('Reload'),
                    ),
                  ],
                );
              },
            );
          });
        }

        if (ab > 0 && _negDialogShown && _negDialogCtx != null) {
          Future.microtask(() {
            if (mounted) {
              Navigator.of(_negDialogCtx!).pop();
            }
            _negDialogShown = false;
            _negDialogCtx = null;
          });
        }

        return const SizedBox.shrink();
      },
    );
  }

  // ── Auto On/Off button state
  bool _autoUpdating = false;

  DocumentReference<Map<String, dynamic>>? _driverRefOrNull() {
    if (Gv.negara.isEmpty || Gv.negeri.isEmpty || Gv.loggedUser.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('driver_account')
        .doc(Gv.loggedUser);
  }

  Widget _autoButtonHeader() {
    final ref = _driverRefOrNull();
    if (ref == null) {
      return _autoDisabled('Set negara / negeri / loggedUser first');
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return _autoLoading();
        }
        if (!snap.hasData || !snap.data!.exists) {
          return _autoDisabled('Driver data not found');
        }

        final data = snap.data!.data()!;
        final isOn = (data['job_auto'] == true);

        final bg = isOn ? Colors.green : Colors.red;
        final label = isOn ? 'Auto On' : 'Auto Off';
        final icon = isOn ? Icons.flash_on : Icons.flash_off;

        return SizedBox(
          height: 44,
          child: Stack(
            children: [
              Positioned.fill(
                child: ElevatedButton.icon(
                  onPressed: _autoUpdating ? null : () => _toggleAuto(ref, isOn),
                  icon: Icon(icon, size: 18, color: Colors.white),
                  label: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: bg,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              if (_autoUpdating)
                const Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleAuto(
    DocumentReference<Map<String, dynamic>> ref,
    bool current,
  ) async {
    if (_autoUpdating) return;
    setState(() => _autoUpdating = true);

    try {
      final turningOn = !current;
      _log('toggle pressed → turningOn=$turningOn');

      await ref.update({'job_auto': turningOn});
      _log('driver_account.job_auto updated → $turningOn');

      if (turningOn) {
        // Force-refresh pool from SERVER (not cache)
        try {
          final snap = await _docRef.get(const GetOptions(source: Source.server));
          _raw = snap.data() ?? const {};
          _log('active_job_lite fetched (server). rawKeys=${_raw.length}');
        } catch (e) {
          _log('fetch active_job_lite FAILED: $e');
        }

        // Rebuild shortlist now (so we don't wait for any stream tick)
        _shortlist = _buildShortlistLe7p5(_raw, _anchorLat, _anchorLng);
        _rebuildRoadOverlayFromCache();

        _log('after rebuild: shortlist=${_shortlist.length} '
            'anchor=(${_anchorLat.toStringAsFixed(6)},${_anchorLng.toStringAsFixed(6)})');

        // Kick the auto flow immediately, bypassing cooldown
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _maybeAutoNavigate(force: true);
          });
        }
      }
    } catch (e) {
      _log('toggle error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    } finally {
      if (mounted) setState(() => _autoUpdating = false);
    }
  }

  Widget _autoDisabled(String msg) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(msg, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _autoLoading() {
    return SizedBox(
      height: 44,
      child: ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade600,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  // ─────────────────────────── Job data members ───────────────────────────
  late final DocumentReference<Map<String, dynamic>> _docRef;

  Map<String, dynamic> _raw = const {};
  Map<int, int> _airCountsAll = const {};
  List<ShortJob> _shortlist = const [];
  Map<int, int> _roadCounts123 = const {};

  final Map<String, double> _roadKmCache = {};
  final Set<String> _inFlight = {};

  bool _loadingRoad = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

  late double _anchorLat;
  late double _anchorLng;

  Timer? _locPollTimer;
  Timer? _reanchorDebounce;

  static const _reanchorMeters = 500.0;
  static const _pollInterval = Duration(seconds: 2);
  static const _stopDebounce = Duration(seconds: 3);

  bool _autoNavInProgress = false;
  DateTime? _lastAutoNavAt;
  static const _autoNavCooldown = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();

    _anchorLat = Gv.driverLat;
    _anchorLng = Gv.driverLng;

    _docRef = FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('active_job')
        .doc('active_job_lite');

    _sub = _docRef.snapshots(includeMetadataChanges: true).listen((snap) {
      debugPrint(
          '[FJOS2] snapshot >>> anchor=(${_anchorLat.toStringAsFixed(6)}, ${_anchorLng.toStringAsFixed(6)}) negara=${Gv.negara} negeri=${Gv.negeri}');

      _raw = snap.data() ?? const {};
      _rebuildForAnchorAndScheduleRoad();
    });

    _startLocationPolling();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _locPollTimer?.cancel();
    _reanchorDebounce?.cancel();
    super.dispose();
  }

  // ─────────────────────────── BUILD ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final cap = Gv.groupCapability.clamp(0, 14);

    if (Gv.negara.isEmpty || Gv.negeri.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('⚠ Set Gv.negara & Gv.negeri first.')),
      );
    }

    final rows = <_RowSpec>[];

    for (var i = 1; i <= math.min(3, cap); i++) {
      rows.add(_RowSpec.bucket(
        index: i,
        name: _bucketMeta(i).name,
        range: _bucketMeta(i).range,
        count: _roadCounts123[i] ?? 0,
        pill: 'ROAD',
        pillColor: Colors.teal,
      ));
    }

    if (cap >= 4) {
      for (var i = 4; i <= cap; i++) {
        rows.add(_RowSpec.bucket(
          index: i,
          name: _bucketMeta(i).name,
          range: _bucketMeta(i).range,
          count: _airCountsAll[i] ?? 0,
          pill: 'AIR',
          pillColor: Colors.indigo,
        ));
      }
    }

    return Scaffold(
      appBar: AppBar(
        leading: GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('🔙', style: TextStyle(fontSize: 22)),
          ),
        ),
        title: const Text('Jobs'),
        centerTitle: true,
        elevation: 1,
      ),

      body: Stack(
        children: [
          // List with a header item (index 0) for the Auto button.
          ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: rows.length + 1, // +1 for header
            itemBuilder: (context, idx) {
              if (idx == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                  child: _autoButtonHeader(),
                );
              }

              final r = rows[idx - 1];
              final i = r.index!;
              return InkWell(
                onTap: (r.count ?? 0) <= 0
                    ? null
                    : () {
                        final Widget dest =
                            (i <= 3) ? Bucket123b(bucketIndex: i) : Bucket414(bucketIndex: i);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => dest),
                        );
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.06),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(_bucketMeta(i).icon, size: 20, color: Colors.black87),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Text(
                                r.name!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _pill(r.pill!, r.pillColor!),
                            ]),
                            const SizedBox(height: 2),
                            Text(
                              r.range!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color
                                    ?.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${r.count ?? 0}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Overlay: negative balance watcher
          _negativeBalanceWatcher(),
        ],
      ),
    );
  }

  // ───────────────────── LIVE / IO ─────────────────────

  Future<void> _pokeServer() async {
    try {
      await _docRef.get(const GetOptions(source: Source.server));
    } catch (_) {}
  }

  void _rebuildForAnchorAndScheduleRoad() {
    Gv.roadAnchorLat = _anchorLat;
    Gv.roadAnchorLng = _anchorLng;

    final airCounts = _computeAirCountsAll(_raw, _anchorLat, _anchorLng);
    _logAirCounts(airCounts);

    final shortlist = _buildShortlistLe7p5(_raw, _anchorLat, _anchorLng);
    debugPrint('[FJOS2] shortlist<=7.5km size=${shortlist.length}');

    Gv.setBucket4Jobs(shortlist);
    _dumpBucket4Jobs(reason: 'after shortlist build');

    _safeSetState(() {
      _airCountsAll = airCounts;
      _shortlist = shortlist;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchRoadForCurrentShortlist();
    });

    // Also try auto (non-forced) on normal stream updates
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeAutoNavigate();
    });
  }

  Future<void> _fetchRoadForCurrentShortlist() async {
    if (_shortlist.isEmpty) {
      debugPrint('[FJOS2] _fetchRoadForCurrentShortlist: shortlist empty.');
      if (_loadingRoad) _safeSetState(() => _loadingRoad = false);
      _rebuildRoadOverlayFromCache();
      return;
    }

    final desired = _shortlist
        .map((j) => _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng))
        .toSet();

    if (_roadKmCache.isNotEmpty) {
      _roadKmCache.removeWhere((k, _) => !desired.contains(k));
    }

    final missing = _shortlist.where((j) {
      final k = _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng);
      return !_roadKmCache.containsKey(k) && !_inFlight.contains(k);
    }).toList();

    debugPrint(
        '[FJOS2] ROAD fetch: shortlist=${_shortlist.length}, missing=${missing.length}, cache=${_roadKmCache.length}, inFlight=${_inFlight.length}');

    if (missing.isEmpty) {
      _rebuildRoadOverlayFromCache();
      return;
    }

    _safeSetState(() => _loadingRoad = true);

    const batchSize = 25;
    for (var i = 0; i < missing.length; i += batchSize) {
      final batch = missing.sublist(i, math.min(i + batchSize, missing.length));
      final batchKeys = <String>[];

      for (final j in batch) {
        final k = _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng);
        batchKeys.add(k);
        _inFlight.add(k);
      }

      try {
        final m = await _callDistanceMatrix(
          originLat: _anchorLat,
          originLng: _anchorLng,
          jobs: batch,
        );
        if (m.isNotEmpty) {
          _roadKmCache.addAll(m);
          _rebuildRoadOverlayFromCache();
        }
      } finally {
        _inFlight.removeAll(batchKeys);
      }
    }

    _safeSetState(() => _loadingRoad = false);
  }

  // ───────────────────── Step-1: auto-claim + navigate ─────────────────────
  Future<void> _maybeAutoNavigate({bool force = false}) async {
    _log('_maybeAutoNavigate(force=$force) start; inProg=$_autoNavInProgress');

    // Reentrancy / cooldown (bypass when forced)
    if (!force && _autoNavInProgress) {
      _log('bail: already in progress');
      return;
    }
    if (!force &&
        _lastAutoNavAt != null &&
        DateTime.now().difference(_lastAutoNavAt!) < _autoNavCooldown) {
      _log('bail: cooldown');
      return;
    }

    if (Gv.negara.isEmpty || Gv.negeri.isEmpty || Gv.loggedUser.isEmpty) {
      _log('bail: missing negara="${Gv.negara}" negeri="${Gv.negeri}" user="${Gv.loggedUser}"');
      return;
    }

    final driverRef = _driverRefOrNull();
    if (driverRef == null) {
      _log('bail: driverRef null');
      return;
    }

    bool autoOn = true;
    bool onJob  = false;
    try {
      final dSnap = await driverRef.get();
      final d = dSnap.data() ?? {};
      if (!force) autoOn = d['job_auto'] == true;
      // onJob = d['driver_is_on_a_job'] == true; // (kept as in your code)
      _log('driver state: autoOn=$autoOn onJob=$onJob');
    } catch (e) {
      _log('driver get error: $e');
    }
    if (!autoOn) { _log('bail: autoOn=false'); return; }
    if (onJob)   { _log('bail: already on a job'); return; }

    // ---------- pick best job ≤ 1.5km (prefer ROAD, else AIR) ----------
    ShortJob? best;
    double    bestKm = 1e12;
    String    bestMode = 'none';

    // ensure shortlist (≤7.5 AIR) exists
    if (_shortlist.isEmpty) {
      _shortlist = _buildShortlistLe7p5(_raw, _anchorLat, _anchorLng);
      _log('shortlist was empty → rebuilt: ${_shortlist.length}');
    }

    for (final j in _shortlist) {
      final liteStr = (_raw[j.jobId] as String?) ?? '';
      if (liteStr.isEmpty) continue;
      if (!_fitsCapacityFromLite(liteStr)) {
        _log('skip ${j.jobId}: pc > vehicleCapacity');
        continue;
      }

      // try ROAD first if we have it
      final key = _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng);
      final roadKm = _roadKmCache[key];
      if (roadKm != null) {
        if (roadKm <= 1.5 && roadKm < bestKm) {
          best = j; bestKm = roadKm; bestMode = 'ROAD';
        }
        continue; // had ROAD; skip AIR
      }

      // fallback AIR
      final airKm = _haversineKm(_anchorLat, _anchorLng, j.sLat, j.sLng);
      if (airKm <= 1.5 && airKm < bestKm) {
        best = j; bestKm = airKm; bestMode = 'AIR';
      }
    }

    // extra safety: if still nothing, scan _raw (maybe shortlist missed it)
    if (best == null) {
      _log('no shortlist candidate ≤1.5; scanning raw…');
      _raw.forEach((jobId, v) {
        if (v is! String) return;
        final liteStr = v;
        if (!_fitsCapacityFromLite(liteStr)) {
          _log('skip (raw) $jobId: pc > vehicleCapacity');
          return;
        }

        final p = _splitLite(liteStr);
        if (p.length < 35) return;
        final sLat = double.tryParse(p[11]);
        final sLng = double.tryParse(p[12]);
        if (sLat == null || sLng == null) return;
        if (!_validCoord(sLat, sLng)) return;

        final key = _cacheKey(jobId, sLat, sLng, _anchorLat, _anchorLng);
        final roadKm = _roadKmCache[key];
        double? km;
        String mode;
        if (roadKm != null) {
          km = roadKm; mode = 'ROAD';
        } else {
          km = _haversineKm(_anchorLat, _anchorLng, sLat, sLng); mode = 'AIR';
        }
        if (km <= 1.5 && km < bestKm) {
          best = ShortJob(jobId: '$jobId', sLat: sLat, sLng: sLng);
          bestKm = km; bestMode = mode;
        }
      });
    }

    _log('pick result: job=${best?.jobId} bestKm=${bestKm.toStringAsFixed(3)} via=$bestMode '
        '(shortlist=${_shortlist.length}, roadCache=${_roadKmCache.length})');

    if (best == null) return;

    final jobId  = best!.jobId;
    Gv.liteJobId  = best!.jobId;
    final jobStr = (_raw[jobId] as String?) ?? '';
    if (jobStr.isEmpty) { _log('bail: jobStr empty for $jobId'); return; }

    final activeRef = FirebaseFirestore.instance
        .collection(Gv.negara).doc(Gv.negeri)
        .collection('active_job').doc('active_job_lite');

    _autoNavInProgress = true;
    _lastAutoNavAt = DateTime.now();

    try {
      // ---------- TRANSACTION: flip flags + delete job key ----------
      final ok = await FirebaseFirestore.instance.runTransaction<bool>((tx) async {
        final drv = await tx.get(driverRef);
        final drvData = drv.data() ?? {};
        if (drvData['driver_is_on_a_job'] == true) { _log('txn: already on a job'); return false; }

        final act = await tx.get(activeRef);
        final pool = act.data() as Map<String, dynamic>?;
        if (pool == null || pool[jobId] == null) { _log('txn: job missing'); return false; }

        tx.update(driverRef, {
          'job_auto': false,
          // 'driver_is_on_a_job': true,
          // 'current_job_id': jobId,
          // 'current_job_at': FieldValue.serverTimestamp(),
        });
        tx.update(activeRef, { jobId: FieldValue.delete() });
        return true;
      }).catchError((e) { _log('txn error: $e'); return false; });

      _log('txn result: $ok');
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Another driver took the job.')),
          );
        }
        return;
      }

      // ---------- hydrate + navigate ----------
      _hydrateGlobalsFromLite(jobId, jobStr);
      _log('hydrated: phone=${Gv.passengerPhone} km=${Gv.totalKm} price=${Gv.totalPrice}');

      if (Gv.passengerPhone.isEmpty) {
        _log('bail post-hydrate: passengerPhone empty');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Missing job data. Cannot open details.')),
          );
        }
        return;
      }

      if (!mounted) return;
      _log('NAV → View15()');
      Navigator.push(context, MaterialPageRoute(builder: (_) => const View15()));
    } finally {
      _autoNavInProgress = false;
    }
  }

  // ───────────────────── PURE COMPUTE ─────────────────────

  Map<int, int> _computeAirCountsAll(
    Map<String, dynamic> raw,
    double dLat,
    double dLng,
  ) {
    final counts = {for (var i = 1; i <= 14; i++) i: 0};

    raw.forEach((jobId, v) {
      if (v is! String) return;
      final p = v.split('·').map((s) => s.trim()).toList(growable: false);

      if (p.length < 35) return;

      // capacity filter by index[3]
      final pc = int.tryParse(p[3]) ?? 0;
      final cap = (Gv.vehicleCapacity <= 0) ? 3 : Gv.vehicleCapacity;
      if (pc < 1 || pc > cap) return;

      debugPrint('[FJOS2][$jobId] len=${p.length}  t33="${_tok(p, 33)}"  t34="${_tok(p, 34)}"');

      final sLat = double.tryParse(_tok(p, 11));
      final sLng = double.tryParse(_tok(p, 12));
      if (sLat == null || sLng == null) return;
      if (!_validCoord(sLat, sLng)) return;

      final km = _haversineKm(dLat, dLng, sLat, sLng);
      final b = _bucketIndexForDistance(km);
      if (b != null) counts[b] = (counts[b] ?? 0) + 1;
    });

    return counts;
  }

  List<ShortJob> _buildShortlistLe7p5(
    Map<String, dynamic> raw,
    double dLat,
    double dLng,
  ) {
    final list = <ShortJob>[];
    raw.forEach((jobId, v) {
      if (v is! String) return;
      final p = v.split('·').map((s) => s.trim()).toList(growable: false);

      if (p.length < 35) return;

      // capacity filter by index[3]
      final pc = int.tryParse(p[3]) ?? 0;
      final cap = (Gv.vehicleCapacity <= 0) ? 3 : Gv.vehicleCapacity;
      if (pc < 1 || pc > cap) return;

      debugPrint('[FJOS2][$jobId] shortlist t33="${_tok(p, 33)}"  t34="${_tok(p, 34)}"');

      final sLat = double.tryParse(_tok(p, 11));
      final sLng = double.tryParse(_tok(p, 12));
      if (sLat == null || sLng == null) return;
      if (!_validCoord(sLat, sLng)) return;

      final airKm = _haversineKm(dLat, dLng, sLat, sLng);
      if (airKm <= 7.5) {
        list.add(ShortJob(jobId: '$jobId', sLat: sLat, sLng: sLng));
      }
    });
    return list;
  }

  void _rebuildRoadOverlayFromCache() {
    var b1 = 0, b2 = 0, b3 = 0;
    for (final j in _shortlist) {
      final k = _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng);
      final roadKm = _roadKmCache[k];
      if (roadKm == null) continue;
      final b = _bucketIndexForRoad123(roadKm);
      if (b == 1) {
        b1++;
      } else if (b == 2) {
        b2++;
      } else if (b == 3) {
        b3++;
      }
    }
    final overlay = {1: b1, 2: b2, 3: b3};
    debugPrint('[FJOS2] overlay123 from cache: $overlay  (cache=${_roadKmCache.length})');

    _safeSetState(() {
      _roadCounts123 = overlay;
    });
  }

  // ───────────────────── ROAD lookup ─────────────────────

  Future<Map<String, double>> _callDistanceMatrix({
    required double originLat,
    required double originLng,
    required List<ShortJob> jobs,
  }) async {
    final apiKey = (Gv.googleApiKey).trim();
    if (apiKey.isEmpty || jobs.isEmpty) {
      debugPrint(
          '[FJOS2] DistanceMatrix: apiKey empty? ${apiKey.isEmpty}, jobs=${jobs.length}');
      return {};
    }

    final origin =
        '${originLat.toStringAsFixed(6)},${originLng.toStringAsFixed(6)}';
    final destinations = jobs
        .map((j) => '${j.sLat.toStringAsFixed(6)},${j.sLng.toStringAsFixed(6)}')
        .join('|');

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
      '?origins=$origin'
      '&destinations=$destinations'
      '&mode=driving'
      '&departure_time=now'
      '&key=$apiKey',
    );

    try {
      debugPrint(
          '[FJOS2] DM call → ${uri.toString().substring(0, 120)}...  (dest=${jobs.length})');
      final resp = await http.get(uri);
      if (resp.statusCode != 200) {
        debugPrint('[FJOS2] DM http=${resp.statusCode}');
        return {};
      }

      final map = jsonDecode(resp.body) as Map<String, dynamic>;
      final topStatus = map['status'] as String?;
      debugPrint('[FJOS2] DM top status: $topStatus');
      if (topStatus != 'OK') return {};

      final rows = (map['rows'] as List?) ?? const [];
      if (rows.isEmpty) return {};
      final elements = (rows.first['elements'] as List?) ?? const [];

      final out = <String, double>{};
      final n = math.min(elements.length, jobs.length);

      for (var i = 0; i < n; i++) {
        final e = elements[i] as Map<String, dynamic>?;
        if (e?['status'] != 'OK') continue;

        final distMeters = (e?['distance']?['value'] as num?)?.toDouble();
        if (distMeters == null) continue;
        final km = double.parse((distMeters / 1000.0).toStringAsFixed(1));

        final dur =
            (e?['duration_in_traffic'] ?? e?['duration']) as Map<String, dynamic>?;
        final secs = (dur?['value'] as num?)?.toInt() ?? 0;
        final etaMin = (secs / 60).round();

        final j = jobs[i];
        final key = _cacheKey(j.jobId, j.sLat, j.sLng, originLat, originLng);

        out[key] = km;

        Gv.roadAnchorLat = originLat;
        Gv.roadAnchorLng = originLng;
        Gv.roadByJob[key] = JobCalc(roadKm: km, etaMin: etaMin);
      }

      debugPrint('[FJOS2] DM mapped results: ${out.length}/${jobs.length}');
      return out;
    } catch (e) {
      debugPrint('[FJOS2] DM error: $e');
      return {};
    }
  }

  // ───────────────────── Anchor movement logic ─────────────────────

  void _startLocationPolling() {
    _locPollTimer?.cancel();
    _locPollTimer = Timer.periodic(_pollInterval, (_) {
      final curLat = Gv.driverLat;
      final curLng = Gv.driverLng;
      if (!_validCoord(curLat, curLng) || !_validCoord(_anchorLat, _anchorLng)) {
        if (_validCoord(curLat, curLng) && !_validCoord(_anchorLat, _anchorLng)) {
          _scheduleReanchor(curLat, curLng);
        }
        return;
      }

      final movedM =
          _haversineKm(_anchorLat, _anchorLng, curLat, curLng) * 1000.0;
      if (movedM >= _reanchorMeters) {
        _scheduleReanchor(curLat, curLng);
      } else {
        _reanchorDebounce?.cancel();
        _reanchorDebounce = null;
      }
    });
  }

  void _scheduleReanchor(double lat, double lng) {
    _reanchorDebounce?.cancel();
    _reanchorDebounce = Timer(_stopDebounce, () {
      final newLat = Gv.driverLat;
      final newLng = Gv.driverLng;
      if (!_validCoord(newLat, newLng)) return;

      final distM =
          _haversineKm(_anchorLat, _anchorLng, newLat, newLng) * 1000.0;
      if (distM < _reanchorMeters) return;

      debugPrint(
          '[FJOS2] Re-anchoring: old=(${_anchorLat.toStringAsFixed(6)},${_anchorLng.toStringAsFixed(6)}) '
          'new=(${newLat.toStringAsFixed(6)},${newLng.toStringAsFixed(6)}) dist=${distM.toStringAsFixed(1)}m');

      _anchorLat = newLat;
      _anchorLng = newLng;
      Gv.roadAnchorLat = _anchorLat;
      Gv.roadAnchorLng = _anchorLng;

      _roadKmCache.clear();
      _inFlight.clear();

      _rebuildForAnchorAndScheduleRoad();
    });
  }

  // ───────────────────── helpers ─────────────────────

  String _tok(List<String> p, int i) => (i >= 0 && i < p.length) ? p[i] : '';

  void _dumpBucket4Jobs({required String reason}) {
    final list = Gv.bucket4Jobs;
    debugPrint(
        '[FJOS2] DUMP bucket4Jobs ($reason): count=${list.length} builtAt=${Gv.bucket4LastBuiltAt} ver=${Gv.bucket4Version.value}');
    for (var i = 0; i < list.length && i < 50; i++) {
      final j = list[i];
      final key =
          _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng);
      debugPrint(
          '  [$i] jobId=${j.jobId} s=(${j.sLat.toStringAsFixed(6)},${j.sLng.toStringAsFixed(6)}) key=$key');
    }
    if (list.length > 50) {
      debugPrint('  ... +${list.length - 50} more');
    }
  }

  void _logAirCounts(Map<int, int> c) {
    final sb = StringBuffer('AIR counts: ');
    for (var i = 1; i <= 14; i++) {
      if (i > 1) sb.write(', ');
      sb.write('$i:${c[i] ?? 0}');
    }
    debugPrint('[FJOS2] $sb');
  }

  String _cacheKey(String id, double sLat, double sLng, double aLat, double aLng) =>
      '$id@$sLat,$sLng@$aLat,$aLng';

  int? _bucketIndexForDistance(double km) {
    if (km <= 1.5) return 1;
    if (km <= 2.5) return 2;
    if (km <= 5.0) return 3;
    if (km <= 7.5) return 4;
    if (km <= 10.0) return 5;
    if (km <= 20.0) return 6;
    if (km <= 30.0) return 7;
    if (km <= 50.0) return 8;
    if (km <= 100.0) return 9;
    if (km <= 200.0) return 10;
    if (km <= 500.0) return 11;
    if (km <= 1000.0) return 12;
    if (km <= 2000.0) return 13;
    if (km <= 5000.0) return 14;
    return null;
  }

  int? _bucketIndexForRoad123(double km) {
    if (km <= 1.5) return 1;
    if (km <= 2.5) return 2;
    if (km <= 5.0) return 3;
    return null;
  }

  bool _validCoord(double lat, double lng) {
    if (lat == 0.0 && lng == 0.0) return false;
    return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0088;
    double _rad(double d) => d * math.pi / 180.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1); // fixed
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle || SchedulerPhase.postFrameCallbacks == phase) {
      setState(fn);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
    }
  }
}

// ───────────────────── Small UI bits ─────────────────────

class _RowSpec {
  final int? index;
  final String? name;
  final String? range;
  final int? count;
  final String? pill;
  final Color? pillColor;

  _RowSpec._bucket(
      this.index, this.name, this.range, this.count, this.pill, this.pillColor);

  factory _RowSpec.bucket({
    required int index,
    required String name,
    required String range,
    required int count,
    required String pill,
    required Color pillColor,
  }) =>
      _RowSpec._bucket(index, name, range, count, pill, pillColor);
}

Widget _pill(String text, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withOpacity(0.5)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );
}

class _BucketMeta {
  final String name;
  final String range;
  final IconData icon;
  const _BucketMeta(this.name, this.range, this.icon);
}

_BucketMeta _bucketMeta(int index) {
  const names = <int, String>{
    1: 'Next to you',
    2: 'Very near',
    3: 'Near',
    4: 'Quite near',
    5: 'A little far',
    6: 'Far',
    7: 'Quite far',
    8: 'Very far',
    9: 'Super far',
    10: 'Extreme far',
    11: 'Long haul',
    12: 'Long haul+',
    13: 'Ultra long',
    14: 'Epic',
  };

  const ranges = <int, String>{
    1: '(≤ 1.5 km)',
    2: '(1.51 – 2.5 km)',
    3: '(2.51 – 5 km)',
    4: '(5.1 – 7.5 km)',
    5: '(7.51 – 10 km)',
    6: '(10.1 – 20 km)',
    7: '(20.1 – 30 km)',
    8: '(30.1 – 50 km)',
    9: '(50.1 – 100 km)',
    10: '(100.1 – 200 km)',
    11: '(200.1 – 500 km)',
    12: '(500.1 – 1000 km)',
    13: '(1000.1 – 2000 km)',
    14: '(2000.1 – 5000 km)',
  };

  final icons = <IconData>[
    Icons.place_outlined,
    Icons.directions_walk,
    Icons.directions_bike,
    Icons.directions_car,
    Icons.local_taxi,
    Icons.route,
    Icons.alt_route,
    Icons.signpost_outlined,
    Icons.fork_right,
    Icons.rocket_launch_outlined,
    Icons.public,
    Icons.flight_takeoff,
    Icons.flight,
    Icons.public_off,
  ];
  final icon = icons[(index - 1) % icons.length];

  return _BucketMeta(
    names[index] ?? 'Bucket $index',
    ranges[index] ?? '',
    icon,
  );
}


// import 'dart:async';
// import 'dart:convert';
// import 'dart:math' as math;
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/scheduler.dart';
// import 'package:http/http.dart' as http;
// import 'package:luckygo_pemandu/end_drawer/deposit_page.dart';
// import 'package:luckygo_pemandu/gen_l10n/app_localizations.dart';

// import 'package:luckygo_pemandu/global.dart';
// import 'package:luckygo_pemandu/jobFilter/bucket123b.dart';
// import 'package:luckygo_pemandu/jobFilter/bucket414.dart';
// import 'package:luckygo_pemandu/jobFilter/filter_jobs_helper.dart';
// import 'package:luckygo_pemandu/landing%20page/landing_page.dart'; // ShortJob

// /// Single-stream page (v2):
// /// - Accepts 35-token records (indexes 0..34)
// /// - Prints token[33] and token[34]
// class FilterJobsOneStream2 extends StatefulWidget {
//   const FilterJobsOneStream2({super.key});

//   @override
//   State<FilterJobsOneStream2> createState() => _FilterJobsOneStream2State();
// }

// class _FilterJobsOneStream2State extends State<FilterJobsOneStream2> {
// bool _negDialogShown = false;
// Widget _negativeBalanceWatcher() {
//   if (Gv.loggedUser.isEmpty || Gv.negara.isEmpty || Gv.negeri.isEmpty) {
//     return const SizedBox.shrink();
//   }

//   final driverRef = FirebaseFirestore.instance
//       .collection(Gv.negara).doc(Gv.negeri)
//       .collection('driver_account').doc(Gv.loggedUser);

// BuildContext? dialogContext;
// bool dialogShown = false;

// return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
//   stream: driverRef.snapshots(),
//   builder: (ctx, snap) {

//     if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();

//     final data = snap.data!.data();
//     final ab = ((data?['account_balance'] as num?) ?? 0).toDouble();

//     if (ab <= 0 && !dialogShown) {
//       dialogShown = true;
//       Future.microtask(() {
//         showDialog(
//           context: ctx,
//           barrierDismissible: false,
//           builder: (dCtx) {



//             dialogContext = dCtx;
//             return AlertDialog(
              
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
//                 title: Text(AppLocalizations.of(context)!.plsReload),
//               content: Text(
//                 '${AppLocalizations.of(context)!.balanceIs} ${Gv.currency} ${ab.toStringAsFixed(2)}.\n${AppLocalizations.of(context)!.plsReload}',
//                 textAlign: TextAlign.left,
//               ),
//               actions: [
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(dCtx).pop();
//                     dialogShown = false;
//                     Navigator.of(ctx).pushAndRemoveUntil(
//                       MaterialPageRoute(builder: (_) => const LandingPage()),
//                       (route) => false,
//                     );
//                   },
//                   child: const Text('Back'),
//                 ),
//                 ElevatedButton(
//                   onPressed: () {
//                     Navigator.of(dCtx).pop();
//                     dialogShown = false;
//                     Navigator.of(ctx).push(
//                       MaterialPageRoute(builder: (_) => const DepositPage()),
//                     );
//                   },
//                   child: const Text('Reload'),
//                 ),
//               ],
//             );
//           },
//         );
//       });
//     }

//     if (ab > 0 && dialogShown && dialogContext != null) {
//       Future.microtask(() {
//         Navigator.of(dialogContext!).pop();
//         dialogShown = false;
//         dialogContext = null;
//       });
//     }

//     return const SizedBox.shrink(); // Or your actual content
//   },
// );

// }












  
//   late final DocumentReference<Map<String, dynamic>> _docRef;

//   Map<String, dynamic> _raw = const {};
//   Map<int, int> _airCountsAll = const {};
//   List<ShortJob> _shortlist = const [];
//   Map<int, int> _roadCounts123 = const {};

//   final Map<String, double> _roadKmCache = {};
//   final Set<String> _inFlight = {};

//   bool _loadingRoad = false;
//   StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;

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
//           '[FJOS2] snapshot >>> anchor=(${_anchorLat.toStringAsFixed(6)}, ${_anchorLng.toStringAsFixed(6)}) negara=${Gv.negara} negeri=${Gv.negeri}');

//       _raw = snap.data() ?? const {};
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

//     appBar: AppBar(
//       leading: GestureDetector(
//         onTap: () {
//           // Navigator.pushReplacement(
//           //   context,
//           //   MaterialPageRoute(builder: (_) => LandingPage()),
//           // );
//           Navigator.pop(context);

//         },

//         child: const Padding(
//       padding: EdgeInsets.symmetric(horizontal: 16),
//       child: Text('🔙', style: TextStyle(fontSize: 22)),
//         ),
//       ),
//       title: const Text('Jobs'),
//       centerTitle: true,
//       elevation: 1,
//     ),


//       // appBar: AppBar(
//       //   title: const Text('Nearby Buckets (One Stream) · v2'),
//       //   actions: [
//       //     IconButton(
//       //       tooltip: 'Dump ≤7.5km list',
//       //       icon: const Icon(Icons.bug_report),
//       //       onPressed: () => _dumpBucket4Jobs(reason: 'manual dump via AppBar'),
//       //     ),
//       //     if (_loadingRoad)
//       //       const Padding(
//       //         padding: EdgeInsets.only(right: 12),
//       //         child: Center(
//       //           child: SizedBox(
//       //             width: 16, height: 16,
//       //             child: CircularProgressIndicator(strokeWidth: 2),
//       //           ),
//       //         ),
//       //       ),
//       //     IconButton(
//       //       tooltip: 'Force server refresh',
//       //       icon: const Icon(Icons.refresh),
//       //       onPressed: _pokeServer,
//       //     ),
//       //   ],
//       // ),
      
//       // FIX: no Expanded directly under body
//       body: Stack
//       (
//         children: [
//           ListView.separated(
//             padding: const EdgeInsets.symmetric(vertical: 8),
//             separatorBuilder: (_, __) => const Divider(height: 1),
//             itemCount: rows.length,
//             itemBuilder: (context, idx) {
//               final r = rows[idx];
//               final i = r.index!;
//               return InkWell(
//                 onTap: (r.count ?? 0) <= 0
//                     ? null
//                     : () {
//                         final Widget dest = (i <= 3)
//                             ? Bucket123b(bucketIndex: i)
//                             : Bucket414(bucketIndex: i);
//                         Navigator.push(
//                           context,
//                           MaterialPageRoute(builder: (_) => dest),
//                         );
//                       },
//                 child: Padding(
//                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//                   child: Row(
//                     children: [
//                       Container(
//                         width: 36,
//                         height: 36,
//                         decoration: BoxDecoration(
//                           color: Colors.black.withOpacity(0.06),
//                           shape: BoxShape.circle,
//                         ),
//                         child: Icon(_bucketMeta(i).icon, size: 20, color: Colors.black87),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Row(children: [
//                               Text(
//                                 r.name!,
//                                 maxLines: 1,
//                                 overflow: TextOverflow.ellipsis,
//                                 style: const TextStyle(
//                                   fontSize: 14,
//                                   fontWeight: FontWeight.w600,
//                                 ),
//                               ),
//                               const SizedBox(width: 8),
//                               _pill(r.pill!, r.pillColor!),
//                             ]),
//                             const SizedBox(height: 2),
//                             Text(
//                               r.range!,
//                               maxLines: 1,
//                               overflow: TextOverflow.ellipsis,
//                               style: TextStyle(
//                                 fontSize: 10,
//                                 color: Theme.of(context)
//                                     .textTheme
//                                     .bodySmall
//                                     ?.color
//                                     ?.withOpacity(0.8),
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Container(
//                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//                         decoration: BoxDecoration(
//                           color: Colors.black.withOpacity(0.05),
//                           borderRadius: BorderRadius.circular(999),
//                         ),
//                         child: Text(
//                           '${r.count ?? 0}',
//                           style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               );
//             },
//           ),
// _negativeBalanceWatcher(),

//         ],



//       ),
//     );
//   }

//   // ───────────────────── LIVE / IO ─────────────────────

//   Future<void> _pokeServer() async {
//     try {
//       await _docRef.get(const GetOptions(source: Source.server));
//     } catch (_) {}
//   }

//   void _rebuildForAnchorAndScheduleRoad() {
//     Gv.roadAnchorLat = _anchorLat;
//     Gv.roadAnchorLng = _anchorLng;

//     final airCounts = _computeAirCountsAll(_raw, _anchorLat, _anchorLng);
//     _logAirCounts(airCounts);

//     final shortlist = _buildShortlistLe7p5(_raw, _anchorLat, _anchorLng);
//     debugPrint('[FJOS2] shortlist<=7.5km size=${shortlist.length}');

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

//   Future<void> _fetchRoadForCurrentShortlist() async {
//     if (_shortlist.isEmpty) {
//       debugPrint('[FJOS2] _fetchRoadForCurrentShortlist: shortlist empty.');
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
//         '[FJOS2] ROAD fetch: shortlist=${_shortlist.length}, missing=${missing.length}, cache=${_roadKmCache.length}, inFlight=${_inFlight.length}');

//     if (missing.isEmpty) {
//       _rebuildRoadOverlayFromCache();
//       return;
//     }

//     _safeSetState(() => _loadingRoad = true);

//     const batchSize = 25;
//     for (var i = 0; i < missing.length; i += batchSize) {
//       final batch = missing.sublist(i, math.min(i + batchSize, missing.length));
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
//           _rebuildRoadOverlayFromCache();
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

//       // ACCEPT 35 TOKENS
//       if (p.length < 35) return;

//       // DEBUG: print token[33] and token[34]
//       debugPrint('[FJOS2][$jobId] len=${p.length}  t33="${_tok(p, 33)}"  t34="${_tok(p, 34)}"');

//       final sLat = double.tryParse(_tok(p, 11));
//       final sLng = double.tryParse(_tok(p, 12));
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

//       // ACCEPT 35 TOKENS
//       if (p.length < 35) return;

//       // DEBUG: print token[33] and token[34]
//       debugPrint('[FJOS2][$jobId] shortlist t33="${_tok(p, 33)}"  t34="${_tok(p, 34)}"');

//       final sLat = double.tryParse(_tok(p, 11));
//       final sLng = double.tryParse(_tok(p, 12));
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
//       final k = _cacheKey(j.jobId, j.sLat, j.sLng, _anchorLat, _anchorLng);
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
//     debugPrint('[FJOS2] overlay123 from cache: $overlay  (cache=${_roadKmCache.length})');

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
//           '[FJOS2] DistanceMatrix: apiKey empty? ${apiKey.isEmpty}, jobs=${jobs.length}');
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
//           '[FJOS2] DM call → ${uri.toString().substring(0, 120)}...  (dest=${jobs.length})');
//       final resp = await http.get(uri);
//       if (resp.statusCode != 200) {
//         debugPrint('[FJOS2] DM http=${resp.statusCode}');
//         return {};
//       }

//       final map = jsonDecode(resp.body) as Map<String, dynamic>;
//       final topStatus = map['status'] as String?;
//       debugPrint('[FJOS2] DM top status: $topStatus');
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

//         final dur =
//             (e?['duration_in_traffic'] ?? e?['duration']) as Map<String, dynamic>?;
//         final secs = (dur?['value'] as num?)?.toInt() ?? 0;
//         final etaMin = (secs / 60).round();

//         final j = jobs[i];
//         final key = _cacheKey(j.jobId, j.sLat, j.sLng, originLat, originLng);

//         out[key] = km;

//         Gv.roadAnchorLat = originLat;
//         Gv.roadAnchorLng = originLng;
//         Gv.roadByJob[key] = JobCalc(roadKm: km, etaMin: etaMin);
//       }

//       debugPrint('[FJOS2] DM mapped results: ${out.length}/${jobs.length}');
//       return out;
//     } catch (e) {
//       debugPrint('[FJOS2] DM error: $e');
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
//           '[FJOS2] Re-anchoring: old=(${_anchorLat.toStringAsFixed(6)},${_anchorLng.toStringAsFixed(6)}) '
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

//   String _tok(List<String> p, int i) => (i >= 0 && i < p.length) ? p[i] : '';

//   void _dumpBucket4Jobs({required String reason}) {
//     final list = Gv.bucket4Jobs;
//     debugPrint(
//         '[FJOS2] DUMP bucket4Jobs ($reason): count=${list.length} builtAt=${Gv.bucket4LastBuiltAt} ver=${Gv.bucket4Version.value}');
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
//     debugPrint('[FJOS2] $sb');
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
//       style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
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



