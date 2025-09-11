import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:luckygo_pemandu/driver_accept_job/rate_passenger_button.dart';
import 'package:luckygo_pemandu/global.dart';
import 'package:luckygo_pemandu/jobFilter/filter_job_one_stream2.dart';
import 'package:luckygo_pemandu/view15/global_variables_for_view15.dart';
import 'package:luckygo_pemandu/view15/item_details.dart';



import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class ReceiptPage extends StatelessWidget {
  const ReceiptPage({Key? key}) : super(key: key);

  // ------------------------ PDF helpers ------------------------
  pw.Widget _divider() => pw.Divider(height: 14, thickness: 0.6);

  pw.Widget _title(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 6, bottom: 4),
        child: pw.Text(
          text,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      );

  // Generic 3-column row: [label.........][ middle ][   price  ]
  pw.Widget _rowLayout({
    required String label,
    String middle = '',
    String price = '',
    bool bold = false,
    double? fontSize,
  }) {
    final style = pw.TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(child: pw.Text(label, style: style)),
        pw.Container(
          width: 70,
          alignment: pw.Alignment.centerRight,
          child: pw.Text(middle, style: style),
        ),
        pw.Container(
          width: 70,
          alignment: pw.Alignment.centerRight,
          child: pw.Text(price, style: style),
        ),
      ],
    );
  }

  // Qty + Price row: shows "xN" in the middle, money at right
  pw.Widget _itemRow(String label, {required int qty, required double price}) {
    if (qty <= 0 && price <= 0) return pw.SizedBox();
    return _rowLayout(
      label: qty > 0 ? label : label, // label unchanged
      middle: qty > 0 ? 'x$qty' : '',
      price: price.toStringAsFixed(2),
    );
  }

  // Value+unit in the middle (no money at right). Minutes → int + "min"
  pw.Widget _metricRow(String label, double value, String unit) {
    final middle = unit.toLowerCase().startsWith('min')
        ? '${value.round()}  min'
        : '${value.toStringAsFixed(2)}  $unit';
    return _rowLayout(label: label, middle: middle, price: '');
  }

  // Money row: price only at right
  pw.Widget _moneyRow(String label, double price) {
    if (price == 0) return pw.SizedBox();
    return _rowLayout(label: label, middle: '', price: price.toStringAsFixed(2));
  }

  bool _hasSegment({required double km, required int eta, required double price}) {
    return km > 0 || eta > 0 || price > 0;
  }

  Future<Uint8List> _buildReceiptPdf() async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(24, 28, 24, 28),
        build: (ctx) {
          final widgets = <pw.Widget>[
            pw.Center(
              child: pw.Text(
                'Receipt',
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text('Date: ${DateTime.now()}', style: const pw.TextStyle(fontSize: 10)),
            _divider(),
          ];

          // ---------------- Items: Passengers ----------------
          if (qty_passengerAdult.value + qty_passengerBaby.value > 0 ||
              ct_passengerBlind.value || ct_passengerDeaf.value || ct_passengerMute.value) {
            widgets.add(_title('Passengers'));
            widgets.add(_itemRow('Adult',
                qty: qty_passengerAdult.value, price: pr_passengerAdult));
            widgets.add(_itemRow('Baby',
                qty: qty_passengerBaby.value, price: pr_passengerBaby));

            // disabilities are flags → treat as qty 1 when true
            if (ct_passengerBlind.value) {
              widgets.add(_itemRow('Blind', qty: 1, price: pr_passengerBlind));
            }
            if (ct_passengerDeaf.value) {
              widgets.add(_itemRow('Deaf', qty: 1, price: pr_passengerDeaf));
            }
            if (ct_passengerMute.value) {
              widgets.add(_itemRow('Mute', qty: 1, price: pr_passengerMute));
            }
            widgets.add(_divider());
          }

          // ---------------- Items: Accessibility ----------------
          if (qty_wheelchair.value > 0 ||
              qty_supportstick.value > 0 ||
              qty_babystroller.value > 0) {
            widgets.add(_itemRow('Wheelchair',
                qty: qty_wheelchair.value, price: pr_wheelchair));
            widgets.add(_itemRow('Support Stick',
                qty: qty_supportstick.value, price: pr_supportstick));
            widgets.add(_itemRow('Baby Stroller',
                qty: qty_babystroller.value, price: pr_babystroller));
            widgets.add(_divider());
          }

          // ---------------- Items: Bags & Luggage ----------------
          if (qty_shoppingBag.value > 0 || qty_luggage.value > 0) {
            widgets.add(_itemRow('Shopping Bag',
                qty: qty_shoppingBag.value, price: pr_shoppingBag));
            widgets.add(_itemRow('Luggage',
                qty: qty_luggage.value, price: pr_luggage));
            widgets.add(_divider());
          }

          // ---------------- Items: Pets & Animals ----------------
          if (qty_pets.value > 0 ||
              qty_dog.value > 0 ||
              qty_goat.value > 0 ||
              qty_rooster.value > 0 ||
              qty_snake.value > 0) {
            widgets.add(_itemRow('Pets in cage', qty: qty_pets.value, price: pr_pets));
            widgets.add(_itemRow('Pet Dog', qty: qty_dog.value, price: pr_dog));
            widgets.add(_itemRow('Goat', qty: qty_goat.value, price: pr_goat));
            widgets.add(_itemRow('Rooster', qty: qty_rooster.value, price: pr_rooster));
            widgets.add(_itemRow('Pet Snake', qty: qty_snake.value, price: pr_snake));
            widgets.add(_divider());
          }

          // ---------------- Items: Food & Others ----------------
          if (qty_durian.value > 0 ||
              qty_odourfruits.value > 0 ||
              qty_wetfood.value > 0 ||
              qty_tupperWare.value > 0 ||
              qty_gastank.value > 0) {
            widgets.add(_itemRow('Durian', qty: qty_durian.value, price: pr_durian));
            widgets.add(_itemRow('Strong odour fruit',
                qty: qty_odourfruits.value, price: pr_odourfruits));
            widgets.add(_itemRow('Wet Food', qty: qty_wetfood.value, price: pr_wetfood));
            widgets.add(_itemRow('Leaked tupperware',
                qty: qty_tupperWare.value, price: pr_tupperWare));
            widgets.add(_itemRow('Gas Tank', qty: qty_gastank.value, price: pr_gastank));
            widgets.add(_divider());
          }

          // ---------------- Route/segment sections ----------------
          void addSegment({
            required String title,
            required double km,
            required int etaMin,
            required double charges,
          }) {
            if (!_hasSegment(km: km, eta: etaMin, price: charges)) return;
            widgets.addAll([
              _title(title),
              _metricRow('Distance (km)', km, 'Km'),
              _metricRow('ETA (min)', etaMin.toDouble(), 'Minutes'),
              _moneyRow('Charges', charges),
              _divider(),
            ]);
          }

          addSegment(
            title: 'Source - D1',
            km: km_sod1.value,
            etaMin: eta_sod1.value,
            charges: pr_sod1,
          );
          addSegment(
            title: 'D1 - D2',
            km: km_d1d2.value,
            etaMin: eta_d1d2.value,
            charges: pr_d1d2,
          );
          addSegment(
            title: 'D2 - D3',
            km: km_d2d3.value,
            etaMin: eta_d2d3.value,
            charges: pr_d2d3,
          );
          addSegment(
            title: 'D3 - D4',
            km: km_d3d4.value,
            etaMin: eta_d3d4.value,
            charges: pr_d3d4,
          );
          addSegment(
            title: 'D4 - D5',
            km: km_d4d5.value,
            etaMin: eta_d4d5.value,
            charges: pr_d4d5,
          );
          addSegment(
            title: 'D5 - D6',
            km: km_d5d6.value,
            etaMin: eta_d5d6.value,
            charges: pr_d5d6,
          );

          // ---------------- Pin charges & Tips ----------------
          // you keep two variants; print both if non-zero
          if (Gv.totalPinCharge > 0) {
            widgets.add(_moneyRow('Extra Pin Charges', Gv.totalPinCharge));
          }
          if (totalPinCharges.value > 0) {
            widgets.add(_moneyRow('Extra Pin Charges', totalPinCharges.value.toDouble()));
          }
          if (Gv.totalPinCharge > 0 || totalPinCharges.value > 0) {
            widgets.add(_divider());
          }

          if (tips1Amount.value > 0 || tips2Amount.value > 0) {
            widgets.add(_title('Tips'));
            if (tips1Amount.value > 0) {
              widgets.add(_moneyRow('Tips 1', tips1Amount.value.toDouble()));
            }
            if (tips2Amount.value > 0) {
              widgets.add(_moneyRow('Tips 2', tips2Amount.value.toDouble()));
            }
            widgets.add(_divider());
          }

          // ---------------- Grand total ----------------
          widgets.add(
            _rowLayout(
              label: 'Grand Total',
              price: Gv.grandTotal.toStringAsFixed(2),
              bold: true,
              fontSize: 16,
            ),
          );

          return widgets;
        },
      ),
    );

    return doc.save();
  }

  Future<void> _sharePdf(BuildContext context) async {
    try {
      final pdfBytes = await _buildReceiptPdf();
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/LuckyGo_Driver_Receipt_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        text: 'Here is your LuckyGo receipt',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating PDF: $e')),
      );
    }
  }
  // ---------------------- end PDF helpers ----------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const Expanded(
            flex: 7,
            child: Column(
              children: [
                SizedBox(
                  height: 60,
                ),
                Center(
                  child: Text(
                    'Receipt',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),

                ItemDetails(),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 12),
              child: Column(
                children: [
                  const Divider(thickness: 2, color: Colors.grey, height: 20),
                  Padding(
                    padding: const EdgeInsets.only(left: 10, right: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Grand Total: ${Gv.grandTotal.toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                  const Divider(thickness: 2, color: Colors.grey, height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
//                       // Rate Passenger
//                       OutlinedButton.icon(
//                         icon: const Icon(Icons.star_rate),
//                         label: const Text('Rate Passenger'),
//                         onPressed: () async {
//                           final messenger = ScaffoldMessenger.of(context);

//                           int selected = 0; // 0..5
//                           String? error;
//                           String commentText = '';
//                           String commentLevel = '';



const RatePassengerButton(),














// // int selected = 0;
// // String? error;
// // String commentText = '';
// // String commentLevel = '';

// final result = await showDialog<Map<String, dynamic>>(
//   context: context,
//   useRootNavigator: true,
//   barrierDismissible: false,
//   builder: (dialogCtx) {
//     return StatefulBuilder(
//       builder: (ctx, setState) {
//         bool commentEnabled;
//         if (selected >= 5) {
//           commentLevel = 'Excellent';
//           commentEnabled = false;
//         } else if (selected == 4) {
//           commentLevel = 'Good';
//           commentEnabled = false;
//         } else if (selected > 0) {
//           commentLevel = 'Bad';
//           commentEnabled = true;
//         } else {
//           commentLevel = '';
//           commentEnabled = true;
//         }

//         return AlertDialog(
//           scrollable: true,
//           insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
//           titlePadding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
//           contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
//           actionsPadding: const EdgeInsets.only(bottom: 12),
//           title: Row(
//             children: [
//               const Expanded(child: Text('Rate Passenger')),
//               IconButton(
//                 tooltip: 'Close',
//                 color: Colors.red,
//                 onPressed: () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
//                 icon: const Icon(Icons.close),
//               ),
//             ],
//           ),
//           content: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const Align(
//                 alignment: Alignment.centerLeft,
//                 child: Text('How was your passenger?'),
//               ),
//               const SizedBox(height: 12),
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: List.generate(5, (i) {
//                   final idx = i + 1;
//                   final isOn = idx <= selected;
//                   return IconButton(
//                     iconSize: 32,
//                     splashRadius: 22,
//                     icon: Icon(Icons.star, color: isOn ? Colors.amber : Colors.grey),
//                     onPressed: () {
//                       setState(() {
//                         selected = idx;
//                         error = null;
//                         // reset typed comment automatically for 4–5 so we don't save stale text
//                         if (selected >= 4) commentText = '';
//                       });
//                     },
//                   );
//                 }),
//               ),
//               if (error != null) ...[
//                 const SizedBox(height: 4),
//                 Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
//               ],
//               if (commentLevel.isNotEmpty) ...[
//                 const SizedBox(height: 8),
//                 Align(
//                   alignment: Alignment.centerLeft,
//                   child: Text(
//                     'Level: $commentLevel',
//                     style: const TextStyle(fontWeight: FontWeight.w600),
//                   ),
//                 ),
//               ],
//               const SizedBox(height: 8),
//               TextField(
//                 enabled: commentEnabled, // ← disabled for 4–5 stars
//                 maxLines: 3,
//                 onChanged: (v) => commentText = v,
//                 decoration: InputDecoration(
//                   labelText: 'Comment',
//                   hintText: commentEnabled
//                       ? 'Add any feedback for the passenger'
//                       : 'Disabled for 4–5★',
//                   border: const OutlineInputBorder(),
//                 ),
//               ),
//               const SizedBox(height: 10),
//             ],
//           ),
//           actionsAlignment: MainAxisAlignment.center,
//           actions: [
//             ElevatedButton(
//               onPressed: () async {
//                 if (selected == 0) {
//                   setState(() => error = 'Please select a star rating.');
//                   return;
//                 }

//                 final level = (selected >= 5)
//                     ? 'Excellent'
//                     : (selected == 4)
//                         ? 'Good'
//                         : 'Bad';
//                 final saveComment = (selected <= 3) ? commentText.trim() : '';

//                 await FirebaseFirestore.instance
//                     .collection(Gv.negara)
//                     .doc(Gv.negeri)
//                     .collection('passenger_account')
//                     .doc(Gv.passengerPhone)
//                     .collection('rating_history')
//                     .add({
//                   'rate_by_driver': '${Gv.userName} ${Gv.loggedUser}',
//                   'rating': selected,
//                   'comment': saveComment,
//                   'comment_level': level,
//                   'timestamp': FieldValue.serverTimestamp(),
//                 });

//                 await FirebaseFirestore.instance
//                     .collection(Gv.negara)
//                     .doc(Gv.negeri)
//                     .collection('passenger_account')
//                     .doc(Gv.passengerPhone)
//                     .collection('notification_page')
//                     .add({
//                   'notification_date': FieldValue.serverTimestamp(),
//                   'notification_description':
//                       'You have received $selected⭐ rating from ${Gv.userName}\n\nKeep up the good work!',
//                   'notification_seen': false,
//                 });

//                 Navigator.of(dialogCtx, rootNavigator: true).pop({
//                   'rating': selected,
//                   'comment': saveComment,
//                   'comment_level': level,
//                 });
//               },
//               child: const Padding(
//                 padding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
//                 child: Text('Submit'),
//               ),
//             ),
//           ],
//         );
//       },
//     );
//   },
// );





























//                           if (result != null) {
//                             messenger.showSnackBar(
//                               SnackBar(
//                                 content: Text(
//                                   'You gave ${result['rating']} star(s). Comment: "${result['comment']}"',
//                                 ),
//                               ),
//                             );
//                           }
//                         },
//                       ),

                      const SizedBox(width: 10),

                      // Share PDF
                      OutlinedButton.icon(
                        onPressed: () => _sharePdf(context),
                        icon: const Icon(Icons.share),
                        label: const Text('Share PDF'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        passengerPhone.value = '';
                        Gv.liteJobId = '';
                        Navigator.of(context).popUntil((route) => route.settings.name == 'FJOS2');
                      },
                      style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      child: const Text('CLOSE'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
