import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReceiptFromJobHistory extends StatefulWidget {
  const ReceiptFromJobHistory({
    super.key,
    required this.job,
    required this.completedAt,
    required this.isLatest,
  });

  final Map<String, dynamic> job;
  final DateTime completedAt;
  final bool isLatest;

  @override
  State<ReceiptFromJobHistory> createState() => _ReceiptFromJobHistoryState();
}

class _ReceiptFromJobHistoryState extends State<ReceiptFromJobHistory> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  // ---------- helpers ----------
  double _d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  int _i(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    if (v is bool) return v ? 1 : 0;
    return 0;
  }

  String _s(dynamic v) => (v is String && v.trim().isNotEmpty) ? v : '—';

  String _fmtDateTime(DateTime dt) {
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

  String _fmtStatus(dynamic raw) {
    final s = _s(raw);
    if (s == '—') return s;
    // replace underscores and Title Case each word
    return s
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''))
        .join(' ');
  }

  bool get _isCompleted {
    final status = _s(widget.job['order_status']).trim().toLowerCase();
    return status == 'payment received' || status == 'job completed' ||
           status == 'payment_received' || status == 'job_completed';
  }

  bool get _canShowRatingByTime {
    final windowEnd = widget.completedAt.add(const Duration(minutes: 10));
    final now = DateTime.now();
    return now.isBefore(windowEnd);
  }

  bool get _showRatingButton =>
      widget.isLatest && _isCompleted && _canShowRatingByTime && _timeLeft.inSeconds > 0;

  String _fmtMmSs(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  void initState() {
    super.initState();
    // initialize countdown
    final end = widget.completedAt.add(const Duration(minutes: 10));
    _timeLeft = end.difference(DateTime.now());
    if (_timeLeft.isNegative) _timeLeft = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      final left = end.difference(now);
      if (!mounted) return;
      setState(() {
        _timeLeft = left.isNegative ? Duration.zero : left;
      });
      if (_timeLeft == Duration.zero) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ---------- PDF helpers (NO special glyphs, 16px before MYR) ----------
  pw.Widget _divider() => pw.Divider(height: 14, thickness: 0.6);

  pw.Widget _title(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _pdfLine({
    required String label,
    String middle = '',     // e.g., "1.7 km, 5 min"
    String qty = '',        // e.g., "x3"
    required String price,  // e.g., "MYR 2.00"
    bool bold = false,
    double? fontSize,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(child: pw.Text(label, style: style)),
          if (qty.isNotEmpty) pw.Text(qty, style: style),
          if (qty.isNotEmpty) pw.SizedBox(width: 16),
          if (qty.isEmpty && middle.isNotEmpty) pw.Text(middle, style: style),
          if ((qty.isEmpty && middle.isNotEmpty) || (qty.isNotEmpty && middle.isEmpty))
            pw.SizedBox(width: 16),
          pw.Text(price, style: style),
        ],
      ),
    );
  }

  Future<Uint8List> _buildReceiptPdf() async {
    final doc = pw.Document();

    // Route labels must use dash, not special arrows
    final segs = <({String title, double km, int eta, double price})>[
      (title: 'Source - D1', km: _d(widget.job['km_sod1']), eta: _i(widget.job['eta_sod1']), price: _d(widget.job['price_sod1'])),
      (title: 'D1 - D2',     km: _d(widget.job['km_d1d2']), eta: _i(widget.job['eta_d1d2']), price: _d(widget.job['price_d1d2'])),
      (title: 'D2 - D3',     km: _d(widget.job['km_d2d3']), eta: _i(widget.job['eta_d2d3']), price: _d(widget.job['price_d2d3'])),
      (title: 'D3 - D4',     km: _d(widget.job['km_d3d4']), eta: _i(widget.job['eta_d3d4']), price: _d(widget.job['price_d3d4'])),
      (title: 'D4 - D5',     km: _d(widget.job['km_d4d5']), eta: _i(widget.job['eta_d4d5']), price: _d(widget.job['price_d4d5'])),
      (title: 'D5 - D6',     km: _d(widget.job['km_d5d6']), eta: _i(widget.job['eta_d5d6']), price: _d(widget.job['price_d5d6'])),
    ].where((s) => s.km > 0 || s.eta > 0 || s.price > 0).toList();

    final extras = <({String label, int qty, double price})>[
      (label: 'Shopping Bag',      qty: _i(widget.job['qty_shoppingBag']),   price: _d(widget.job['price_shoppingBag'])),
      (label: 'Luggage',           qty: _i(widget.job['qty_luggage']),       price: _d(widget.job['price_luggage'])),
      (label: 'Wheelchair',        qty: _i(widget.job['qty_wheelchair']),    price: _d(widget.job['price_wheelchair'])),
      (label: 'Support Stick',     qty: _i(widget.job['qty_supportStick']),  price: _d(widget.job['price_supportStick'])),
      (label: 'Baby Stroller',     qty: _i(widget.job['qty_babyStroller']),  price: _d(widget.job['price_babyStroller'])),
      (label: 'Pets in cage',      qty: _i(widget.job['qty_pets']),          price: _d(widget.job['price_pets'])),
      (label: 'Dog',               qty: _i(widget.job['qty_dog']),           price: _d(widget.job['price_dog'])),
      (label: 'Goat',              qty: _i(widget.job['qty_goat']),          price: _d(widget.job['price_goat'])),
      (label: 'Rooster',           qty: _i(widget.job['qty_rooster']),       price: _d(widget.job['price_rooster'])),
      (label: 'Snake',             qty: _i(widget.job['qty_snake']),         price: _d(widget.job['price_snake'])),
      (label: 'Durian',            qty: _i(widget.job['qty_durian']),        price: _d(widget.job['price_durian'])),
      (label: 'Strong odour fruit',qty: _i(widget.job['qty_odourFruits']),   price: _d(widget.job['price_odourFruits'])),
      (label: 'Wet Food',          qty: _i(widget.job['qty_wetFood']),       price: _d(widget.job['price_wetFood'])),
      (label: 'Leaked tupperware', qty: _i(widget.job['qty_tupperware']),    price: _d(widget.job['price_tupperware'])),
    ].where((e) => e.qty > 0 || e.price > 0).toList();

    final total = _d(widget.job['total_price']);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 28, 24, 28),
        build: (ctx) {
          final w = <pw.Widget>[
            pw.Center(
              child: pw.Text('Receipt',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(height: 6),
            pw.Text('Date: ${_fmtDateTime(widget.completedAt)}',
                style: const pw.TextStyle(fontSize: 10)),
            _divider(),
            _pdfLine(
              label: 'Passenger',
              middle: '${_s(widget.job['job_creator_name'])} (${_s(widget.job['job_created_by'])})',
              price: '${Gv.currency} ${total.toStringAsFixed(2)}',
            ),
            _pdfLine(
              label: 'Status',
              price: _fmtStatus(widget.job['order_status']),
            ),
            _divider(),
          ];

          if (segs.isNotEmpty) {
            w.addAll([
              _title('Route Details'),
              ...segs.map((s) => _pdfLine(
                    label: s.title,
                    middle: '${s.km.toStringAsFixed(1)} km, ${s.eta} min',
                    price: '${Gv.currency} ${s.price.toStringAsFixed(2)}',
                  )),
              _divider(),
            ]);
          }

          // Passengers line (qty + price aligned)
          w.add(_title('Passengers & Items'));
          w.add(_pdfLine(
            label: 'Passenger',
            qty: 'x${_i(widget.job['qty_passengerTotal'])}',
            price: '${Gv.currency} ${_d(widget.job['price_passengerTotal']).toStringAsFixed(2)}',
          ));

          if (extras.isNotEmpty) {
            w.addAll(extras.map((e) => _pdfLine(
                  label: e.label,
                  qty: e.qty > 0 ? 'x${e.qty}' : '',
                  price: '${Gv.currency} ${e.price.toStringAsFixed(2)}',
                )));
            w.add(_divider());
          }

          final totalPin = _d(widget.job['total_pin_charges']);
          final tips1 = _d(widget.job['tips_amount1']);
          final tips2 = _d(widget.job['tips_amount2']);

          if (totalPin > 0 || tips1 > 0 || tips2 > 0) {
            w.add(_title('Extras'));
            if (totalPin > 0) {
              w.add(_pdfLine(
                label: 'Extra Pin Charges',
                price: '${Gv.currency} ${totalPin.toStringAsFixed(2)}',
              ));
            }
            if (tips1 > 0) {
              w.add(_pdfLine(
                label: 'Tips 1',
                price: '${Gv.currency} ${tips1.toStringAsFixed(2)}',
              ));
            }
            if (tips2 > 0) {
              w.add(_pdfLine(
                label: 'Tips 2',
                price: '${Gv.currency} ${tips2.toStringAsFixed(2)}',
              ));
            }
            w.add(_divider());
          }

          w.add(_pdfLine(
            label: 'Grand Total',
            price: '${Gv.currency} ${total.toStringAsFixed(2)}',
            bold: true,
            fontSize: 16,
          ));

          return w;
        },
      ),
    );

    return doc.save();
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final bytes = await _buildReceiptPdf();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/LuckyGo_Receipt_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: 'Here is your LuckyGo receipt',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error generating PDF: $e')));
      }
    }
  }

  Future<void> _submitRating(BuildContext context) async {
    final passengerPhone = _s(widget.job['job_created_by']);
    final passengerName  = _s(widget.job['job_creator_name']);
    if (passengerPhone == '—') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing passenger phone for rating.')),
      );
      return;
    }

    int stars = 0;
    String? error;
    String comment = '';

    final res = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return AlertDialog(
            title: Row(
              children: [
                const Expanded(child: Text('Rate Passenger')),
                IconButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  icon: const Icon(Icons.close, color: Colors.red),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('How was $passengerName?'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final idx = i + 1;
                    final on = idx <= stars;
                    return IconButton(
                      icon: Icon(Icons.star,
                          color: on ? Colors.amber : Colors.grey, size: 30),
                      onPressed: () => setState(() { stars = idx; error = null; }),
                    );
                  }),
                ),
                if (error != null) ...[
                  const SizedBox(height: 4),
                  Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                ],
                const SizedBox(height: 8),
                TextField(
                  maxLines: 3,
                  onChanged: (v) => comment = v,
                  decoration: const InputDecoration(
                    labelText: 'Comment (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              ElevatedButton(
                onPressed: () async {
                  if (stars == 0) {
                    setState(() => error = 'Please select a star rating.');
                    return;
                  }
                  try {
                    await FirebaseFirestore.instance
                        .collection(Gv.negara).doc(Gv.negeri)
                        .collection('passenger_account').doc(passengerPhone)
                        .collection('rating_history')
                        .add({
                      'rate_by_driver': '${Gv.userName} ${Gv.loggedUser}',
                      'rating': stars,
                      'comment': comment.trim(),
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    await FirebaseFirestore.instance
                        .collection(Gv.negara).doc(Gv.negeri)
                        .collection('passenger_account').doc(passengerPhone)
                        .collection('notification_page')
                        .add({
                      'notification_date': FieldValue.serverTimestamp(),
                      'notification_description':
                          'You have received $stars⭐ rating from ${Gv.userName}\n\nKeep up the good work!',
                      'notification_seen': false,
                    });
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to submit rating: $e')),
                      );
                    }
                  }
                  if (context.mounted) Navigator.of(dialogCtx).pop({'ok': true});
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Text('Submit'),
                ),
              ),
            ],
          );
        });
      },
    );

    if (res != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thanks! You rated $passengerName')),
      );
    }
  }

  // ---------- UI helpers (NO special glyphs, 16px before MYR) ----------
  Widget _uiLine({
    required String label,
    String middle = '',   // e.g., "1.7 km, 5 min"
    int qty = 0,          // e.g., 3
    required double price,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          if (qty > 0) Text('x$qty', style: const TextStyle(fontSize: 13)),
          if (qty > 0) const SizedBox(width: 16),
          if (qty == 0 && middle.isNotEmpty) Text(middle, style: const TextStyle(fontSize: 13)),
          if ((qty == 0 && middle.isNotEmpty) || (qty > 0 && middle.isEmpty))
            const SizedBox(width: 16),
          Text(
            '${Gv.currency} ${price.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
    child: Text(text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
  );

  Widget _kvRowBig(BuildContext context, String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
    child: Row(
      children: [
        Expanded(child: Text(k,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
        Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final total    = _d(widget.job['total_price']);
    final status   = _fmtStatus(widget.job['order_status']); // Title-cased, underscores removed
    final name     = _s(widget.job['job_creator_name']);
    final phone    = _s(widget.job['job_created_by']);
    final selfie   = _s(widget.job['y_passenger_selfie'] ?? widget.job['passenger_selfie']);

    final segs = <_Seg>[
      _Seg('Source - D1',  _d(widget.job['km_sod1']), _i(widget.job['eta_sod1']), _d(widget.job['price_sod1'])),
      _Seg('D1 - D2',      _d(widget.job['km_d1d2']), _i(widget.job['eta_d1d2']), _d(widget.job['price_d1d2'])),
      _Seg('D2 - D3',      _d(widget.job['km_d2d3']), _i(widget.job['eta_d2d3']), _d(widget.job['price_d2d3'])),
      _Seg('D3 - D4',      _d(widget.job['km_d3d4']), _i(widget.job['eta_d3d4']), _d(widget.job['price_d3d4'])),
      _Seg('D4 - D5',      _d(widget.job['km_d4d5']), _i(widget.job['eta_d4d5']), _d(widget.job['price_d4d5'])),
      _Seg('D5 - D6',      _d(widget.job['km_d5d6']), _i(widget.job['eta_d5d6']), _d(widget.job['price_d5d6'])),
    ].where((e) => e.hasAny).toList();

    final extras = <_Extra>[
      _Extra('Shopping Bag',   _i(widget.job['qty_shoppingBag']), _d(widget.job['price_shoppingBag'])),
      _Extra('Luggage',        _i(widget.job['qty_luggage']),     _d(widget.job['price_luggage'])),
      _Extra('Wheelchair',     _i(widget.job['qty_wheelchair']),  _d(widget.job['price_wheelchair'])),
      _Extra('Support Stick',  _i(widget.job['qty_supportStick']),_d(widget.job['price_supportStick'])),
      _Extra('Baby Stroller',  _i(widget.job['qty_babyStroller']),_d(widget.job['price_babyStroller'])),
      _Extra('Pets in cage',   _i(widget.job['qty_pets']),        _d(widget.job['price_pets'])),
      _Extra('Dog',            _i(widget.job['qty_dog']),         _d(widget.job['price_dog'])),
      _Extra('Goat',           _i(widget.job['qty_goat']),        _d(widget.job['price_goat'])),
      _Extra('Rooster',        _i(widget.job['qty_rooster']),     _d(widget.job['price_rooster'])),
      _Extra('Snake',          _i(widget.job['qty_snake']),       _d(widget.job['price_snake'])),
      _Extra('Durian',         _i(widget.job['qty_durian']),      _d(widget.job['price_durian'])),
      _Extra('Strong odour fruit', _i(widget.job['qty_odourFruits']), _d(widget.job['price_odourFruits'])),
      _Extra('Wet Food',       _i(widget.job['qty_wetFood']),     _d(widget.job['price_wetFood'])),
      _Extra('Leaked tupperware', _i(widget.job['qty_tupperware']), _d(widget.job['price_tupperware'])),
    ].where((e) => e.qty > 0 || e.price > 0).toList();

    final showRating = _showRatingButton;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Share PDF',
            icon: const Icon(Icons.share),
            onPressed: () => _sharePdf(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFFEFF1F6),
                    backgroundImage: (selfie != '—') ? NetworkImage(selfie) : null,
                    child: (selfie == '—')
                        ? const Icon(Icons.person, size: 26, color: Colors.grey)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(phone, style: const TextStyle(color: Colors.black54)),
                        const SizedBox(height: 4),
                        Text(_fmtDateTime(widget.completedAt),
                            style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Gv.currency,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 12,
                        )),
                      Text(total.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.05),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(status,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          if (segs.isNotEmpty) ...[
            _sectionTitle('Route Details'),
            ...segs.map((s) => _uiLine(
                  label: s.title,
                  middle: '${s.km.toStringAsFixed(1)} km, ${s.eta} min',
                  price: s.price,
                )),
            const SizedBox(height: 10),
          ],

          _sectionTitle('Passengers & Items'),
          _uiLine(
            label: 'Passenger',
            qty: _i(widget.job['qty_passengerTotal']),
            price: _d(widget.job['price_passengerTotal']),
          ),

          if (extras.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...extras.map((e) => _uiLine(
                  label: e.label,
                  qty: e.qty,
                  price: e.price,
                )),
          ],

          finalExtrasBlock(context),

          const SizedBox(height: 14),
          const Divider(),
          _kvRowBig(context, 'Grand Total',
              '${Gv.currency} ${total.toStringAsFixed(2)}'),

          const SizedBox(height: 16),

          // ---------- BUTTON AREA ----------
          if (showRating) ...[
            Center(
              child: Text(
                'Star Rating available for ${_fmtMmSs(_timeLeft)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _submitRating(context),
                  icon: const Icon(Icons.star_rate),
                  label: const Text('Star Rating'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => _sharePdf(context),
                  icon: const Icon(Icons.share),
                  label: const Text('Share PDF'),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
              ],
            ),
          ] else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _sharePdf(context),
                  icon: const Icon(Icons.share),
                  label: const Text('Share PDF'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  label: const Text('Close'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // Extras block
  Widget finalExtrasBlock(BuildContext context) {
    final totalPin = _d(widget.job['total_pin_charges']);
    final tips1 = _d(widget.job['tips_amount1']);
    final tips2 = _d(widget.job['tips_amount2']);

    if (totalPin <= 0 && tips1 <= 0 && tips2 <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        _sectionTitle('Extras'),
        if (totalPin > 0)
          _uiLine(label: 'Extra Pin Charges', price: totalPin),
        if (tips1 > 0)
          _uiLine(label: 'Tips 1', price: tips1),
        if (tips2 > 0)
          _uiLine(label: 'Tips 2', price: tips2),
      ],
    );
  }
}

class _Seg {
  final String title; final double km; final int eta; final double price;
  _Seg(this.title, this.km, this.eta, this.price);
  bool get hasAny => km > 0 || eta > 0 || price > 0;
}

class _Extra {
  final String label; final int qty; final double price;
  _Extra(this.label, this.qty, this.price);
}
