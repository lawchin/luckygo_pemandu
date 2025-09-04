import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/end_drawer/receipt_from_job_history.dart';
import 'package:luckygo_pemandu/global.dart';
// If you still need to hydrate old ReceiptPage flows, keep these:
import 'package:luckygo_pemandu/driver_accept_job/receipt_page.dart';
import 'package:luckygo_pemandu/view15/global_variables_for_view15.dart';

class JobHistory extends StatelessWidget {
  const JobHistory({super.key});

  CollectionReference<Map<String, dynamic>> _historyRef() {
    return FirebaseFirestore.instance
        .collection(Gv.negara)
        .doc(Gv.negeri)
        .collection('driver_account')
        .doc(Gv.loggedUser)
        .collection('job_history');
  }

  // -------- date parsing (handles "31 August 2025 - 2:06 pm", timestamp, fallbacks) --------
  DateTime? _parseJobDate(String id, Map<String, dynamic> data) {
    final raw = data['job_complete_date'];

    if (raw is Timestamp) return raw.toDate();

    if (raw is String && raw.trim().isNotEmpty) {
      final s = raw.trim();
      final parts = s.split('-');
      if (parts.length >= 2) {
        final left = parts[0].trim();   // "31 August 2025"
        final right = parts[1].trim();  // "2:06 pm"
        try {
          final leftParts = left.split(RegExp(r'\s+'));
          if (leftParts.length >= 3) {
            final dd = int.parse(leftParts[0]);
            final monthName = leftParts[1].toLowerCase();
            const months = {
              'january':1,'february':2,'march':3,'april':4,'may':5,'june':6,
              'july':7,'august':8,'september':9,'october':10,'november':11,'december':12
            };
            final mm = months[monthName];
            final yyyy = int.parse(leftParts[2]);
            if (mm != null) {
              final m = RegExp(r'^(\d{1,2}):(\d{2})\s*(am|pm)$', caseSensitive: false).firstMatch(right);
              if (m != null) {
                var hh = int.parse(m.group(1)!);
                final min = int.parse(m.group(2)!);
                final ampm = (m.group(3) ?? '').toUpperCase();
                if (ampm == 'PM' && hh != 12) hh += 12;
                if (ampm == 'AM' && hh == 12) hh = 0;
                return DateTime(yyyy, mm, dd, hh, min);
              }
            }
          }
        } catch (_) {}
      }
      // ISO fallback
      try { return DateTime.parse(s); } catch (_) {}
    }

    final createdTs = data['job_created_date_and_time'];
    if (createdTs is Timestamp) return createdTs.toDate();

    final createdDt = data['job_created_dt'];
    if (createdDt is String && createdDt.length >= 15) {
      try {
        final datePart = createdDt.substring(0, 6);   // ddMMyy
        final timePart = createdDt.substring(7, 13);  // hhmmss
        final ampm = createdDt.substring(13, 15).toUpperCase();
        final dd = int.parse(datePart.substring(0, 2));
        final mm = int.parse(datePart.substring(2, 4));
        final yy = int.parse(datePart.substring(4, 6));
        var hh = int.parse(timePart.substring(0, 2));
        final min = int.parse(timePart.substring(2, 4));
        final sec = int.parse(timePart.substring(4, 6));
        if (ampm == 'PM' && hh != 12) hh += 12;
        if (ampm == 'AM' && hh == 12) hh = 0;
        return DateTime(2000 + yy, mm, dd, hh, min, sec);
      } catch (_) {}
    }

    // last resort: try from doc id if it uses your ddMMyy hhmmssAM(...) format
    try {
      if (id.length >= 17) {
        final datePart = id.substring(0, 6);
        final timePart = id.substring(7, 13);
        final ampm = id.substring(13, 15).toUpperCase();
        final dd = int.parse(datePart.substring(0, 2));
        final mm = int.parse(datePart.substring(2, 4));
        final yy = int.parse(datePart.substring(4, 6));
        var hh = int.parse(timePart.substring(0, 2));
        final min = int.parse(timePart.substring(2, 4));
        final sec = int.parse(timePart.substring(4, 6));
        if (ampm == 'PM' && hh != 12) hh += 12;
        if (ampm == 'AM' && hh == 12) hh = 0;
        return DateTime(2000 + yy, mm, dd, hh, min, sec);
      }
    } catch (_) {}

    return null;
  }

  String _fmtDate(DateTime? dt) {
    if (dt == null) return '—';
    const months = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final monthName = months[dt.month - 1];
    final year = dt.year;
    int hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12; if (hour == 0) hour = 12;
    final hourStr = hour.toString().padLeft(2, '0');
    return '$day $monthName $year  $hourStr:$minute $ampm';
  }

  String _fmtStatus(String raw) {
    final s = (raw).trim().toLowerCase().replaceAll('_', ' ');
    if (s.isEmpty) return '—';
    return s.split(' ').map((w) => w.isEmpty ? '' : (w[0].toUpperCase() + w.substring(1))).join(' ');
  }

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) { final d = double.tryParse(v); return d ?? 0.0; }
    return 0.0;
  }

  // -------- hydrate view15 / Gv globals so ReceiptPage renders this history doc --------
  void _hydrateReceiptGlobalsFromHistory(Map<String, dynamic> data) {
    // money & totals
    Gv.grandTotal = _toDouble(data['total_price']);
    totalPinCharges.value = _toDouble(data['total_pin_charges']);
    Gv.totalPinCharge = _toDouble(data['total_pin_charges']);

    // segment kms + etas + prices (only those present in history)
    km_sod1.value = _toDouble(data['km_sod1']);
    eta_sod1.value = (data['eta_sod1'] as num?)?.toInt() ?? 0;
    pr_sod1 = _toDouble(data['price_sod1']);

    km_d1d2.value = _toDouble(data['km_d1d2']);
    eta_d1d2.value = (data['eta_d1d2'] as num?)?.toInt() ?? 0;
    pr_d1d2 = _toDouble(data['price_d1d2']);

    km_d2d3.value = _toDouble(data['km_d2d3']);
    eta_d2d3.value = (data['eta_d2d3'] as num?)?.toInt() ?? 0;
    pr_d2d3 = _toDouble(data['price_d2d3']);

    km_d3d4.value = _toDouble(data['km_d3d4']);
    eta_d3d4.value = (data['eta_d3d4'] as num?)?.toInt() ?? 0;
    pr_d3d4 = _toDouble(data['price_d3d4']);

    km_d4d5.value = _toDouble(data['km_d4d5']);
    eta_d4d5.value = (data['eta_d4d5'] as num?)?.toInt() ?? 0;
    pr_d4d5 = _toDouble(data['price_d4d5']);

    km_d5d6.value = _toDouble(data['km_d5d6']);
    eta_d5d6.value = (data['eta_d5d6'] as num?)?.toInt() ?? 0;
    pr_d5d6 = _toDouble(data['price_d5d6']);

    // quantities
    qty_passengerAdult.value = (data['qty_passengerAdult'] as num?)?.toInt() ?? 0;
    qty_passengerBaby.value  = (data['qty_passengerBaby']  as num?)?.toInt() ?? 0;
    ct_passengerBlind.value  = (data['qty_blind'] as bool?) ?? false;
    ct_passengerDeaf.value   = (data['qty_deaf']  as bool?) ?? false;
    ct_passengerMute.value   = (data['qty_mute']  as bool?) ?? false;

    qty_wheelchair.value     = (data['qty_wheelchair']     as num?)?.toInt() ?? 0;
    qty_supportstick.value   = (data['qty_supportStick']   as num?)?.toInt() ?? 0;
    qty_babystroller.value   = (data['qty_babyStroller']   as num?)?.toInt() ?? 0;

    qty_shoppingBag.value    = (data['qty_shoppingBag']    as num?)?.toInt() ?? 0;
    qty_luggage.value        = (data['qty_luggage']        as num?)?.toInt() ?? 0;

    qty_pets.value           = (data['qty_pets']           as num?)?.toInt() ?? 0;
    qty_dog.value            = (data['qty_dog']            as num?)?.toInt() ?? 0;
    qty_goat.value           = (data['qty_goat']           as num?)?.toInt() ?? 0;
    qty_rooster.value        = (data['qty_rooster']        as num?)?.toInt() ?? 0;
    qty_snake.value          = (data['qty_snake']          as num?)?.toInt() ?? 0;

    qty_durian.value         = (data['qty_durian']         as num?)?.toInt() ?? 0;
    qty_odourfruits.value    = (data['qty_odourFruits']    as num?)?.toInt() ?? 0;
    qty_wetfood.value        = (data['qty_wetFood']        as num?)?.toInt() ?? 0;
    qty_tupperWare.value     = (data['qty_tupperware']     as num?)?.toInt() ?? 0;
    qty_gastank.value        = (data['qty_gasTank']        as num?)?.toInt() ?? 0;

    // prices
    pr_passengerAdult  = _toDouble(data['price_passengerAdult']);
    pr_passengerBaby   = _toDouble(data['price_passengerBaby']);
    pr_passengerBlind  = _toDouble(data['price_passengerBlind']);
    pr_passengerDeaf   = _toDouble(data['price_passengerDeaf']);
    pr_passengerMute   = _toDouble(data['price_passengerMute']);
    pr_wheelchair      = _toDouble(data['price_wheelchair']);
    pr_supportstick    = _toDouble(data['price_supportStick']);
    pr_babystroller    = _toDouble(data['price_babyStroller']);
    pr_shoppingBag     = _toDouble(data['price_shoppingBag']);
    pr_luggage         = _toDouble(data['price_luggage']);
    pr_pets            = _toDouble(data['price_pets']);
    pr_dog             = _toDouble(data['price_dog']);
    pr_goat            = _toDouble(data['price_goat']);
    pr_rooster         = _toDouble(data['price_rooster']);
    pr_snake           = _toDouble(data['price_snake']);
    pr_durian          = _toDouble(data['price_durian']);
    pr_odourfruits     = _toDouble(data['price_odourFruits']);
    pr_wetfood         = _toDouble(data['price_wetFood']);
    pr_tupperWare      = _toDouble(data['price_tupperware']);
    pr_gastank         = _toDouble(data['price_gasTank']);

    // tips (double)
    tips1Amount.value = _toDouble(data['tips_amount1']).toDouble();
    tips2Amount.value = _toDouble(data['tips_amount2']).toDouble();
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }
String _statusEmoji(String raw) {
  final s = raw.toLowerCase();
  if (s.contains('payment')) return '🟢';
  if (s.contains('completed')) return '✅';
  if (s.contains('coming')) return '🚗';
  if (s.contains('arrived')) return '📍';
  if (s.contains('otw')) return '➡️';
  if (s.contains('cancel')) return '❌';
  return 'ℹ️'; // default/info
}
  @override
  Widget build(BuildContext context) {
    final missingRegion =
        Gv.negara.isEmpty || Gv.negeri.isEmpty || Gv.loggedUser.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Job History'), centerTitle: true),
      body: missingRegion
          ? const Center(child: Text('⚠ Set region & logged user first'))
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _historyRef().snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text('Error: ${snap.error}'));
                }
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return const Center(child: Text('No job history yet.'));
                }

                // Build items + sort newest-first
                final items = docs.map((d) {
                  final data = d.data();
                  final when = _parseJobDate(d.id, data);
                  final totalKm = _toDouble(data['total_distance']);
                  final totalPrice = _toDouble(data['total_price']);
                  final status = (data['order_status'] as String?)?.trim().isNotEmpty == true
                      ? (data['order_status'] as String)
                      : '—';
                  return _JobItem(
                    id: d.id,
                    when: when,
                    totalKm: totalKm,
                    totalPrice: totalPrice,
                    status: status,
                    raw: data,
                  );
                }).toList()
                  ..sort((a, b) {
                    final ad = a.when ?? DateTime.fromMillisecondsSinceEpoch(0);
                    final bd = b.when ?? DateTime.fromMillisecondsSinceEpoch(0);
                    return bd.compareTo(ad); // newest first
                  });

                // Group into Today / Yesterday / Other Days
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                final yesterday = today.subtract(const Duration(days: 1));

                bool _isSameDay(DateTime a, DateTime b) =>
                    a.year == b.year && a.month == b.month && a.day == b.day;

                final todayItems = <_JobItem>[];
                final yesterdayItems = <_JobItem>[];
                final otherItems = <_JobItem>[];

                for (final it in items) {
                  final d = it.when;
                  if (d == null) {
                    otherItems.add(it);
                    continue;
                  }
                  final day = DateTime(d.year, d.month, d.day);
                  if (_isSameDay(day, today)) {
                    todayItems.add(it);
                  } else if (_isSameDay(day, yesterday)) {
                    yesterdayItems.add(it);
                  } else {
                    otherItems.add(it);
                  }
                }

                // The overall latest is items.first (since sorted)
                final latestId = items.isNotEmpty ? items.first.id : null;

                Widget jobCard(_JobItem it) {
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    elevation: 2,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      title: Text(_fmtDate(it.when)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Distance: ${it.totalKm.toStringAsFixed(1)} km'),
                          Row(
                            children: [
                              Text(_statusEmoji(it.status), style: const TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              // Text(_fmtStatus(it.status)),
                          if (![
                            'passenger create job',
                            'driver_accepted_job',
                            'driver_coming',
                            'driver_arrived',
                            'passenger_otw',
                            'start_destination',
                            'job_completed',
                            'payment_received',
                          ].contains(it.raw['order_status'] as String? ?? '')) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                it.raw['order_status'] as String? ?? '',
                                style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, height:1),
                              ),
                            ),
                          ]


                            ],
                          ),
                        ],
                      ),

trailing: Column(
  mainAxisAlignment: MainAxisAlignment.center,
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    Text(
      Gv.currency,
      style: TextStyle(
        fontSize: 11,
        color: Theme.of(context).colorScheme.primary,
        height: 0.9,
      ),
    ),
    Text(
      it.totalPrice.toStringAsFixed(2),
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
    if ((it.raw['commission_deduction'] ?? 0) != 0)
      Text(
        '🎟 -${_toDouble(it.raw['commission_deduction']).toStringAsFixed(2)}',
        style: const TextStyle(fontSize: 10, color: Colors.redAccent),
      ),
  ],
),

                      onTap: () {
                        final isLatest = (latestId != null && it.id == latestId);
                        final completedAt = it.when ?? DateTime.now();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReceiptFromJobHistory(
                              job: it.raw,
                              completedAt: completedAt,
                              isLatest: isLatest,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                }

                // Build the grouped list
                final children = <Widget>[];
                if (todayItems.isNotEmpty) {
                  children.add(_sectionHeader('Today'));
                  children.addAll(todayItems.map(jobCard));
                }
                if (yesterdayItems.isNotEmpty) {
                  children.add(_sectionHeader('Yesterday'));
                  children.addAll(yesterdayItems.map(jobCard));
                }
                if (otherItems.isNotEmpty) {
                  children.add(_sectionHeader('Other Days'));
                  children.addAll(otherItems.map(jobCard));
                }

                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: children,
                );
              },
            ),
    );
  }
}

class _JobItem {
  final String id;
  final DateTime? when;
  final double totalKm;
  final double totalPrice;
  final String status;
  final Map<String, dynamic> raw;
  _JobItem({
    required this.id,
    required this.when,
    required this.totalKm,
    required this.totalPrice,
    required this.status,
    required this.raw,
  });
}
