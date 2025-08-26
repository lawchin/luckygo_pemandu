import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui; // for toImage()
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'; // RenderRepaintBoundary
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:luckygo_pemandu/landing%20page/landing_page.dart';

class ProcessingDeposit extends StatelessWidget {
  final String imageUrl;
  final String amount;
  final String last4;
  final String? localImagePath; // fallback if network fails

  ProcessingDeposit({
    super.key,
    required this.imageUrl,
    required this.amount,
    required this.last4,
    this.localImagePath,
  });

  // ---- capture this widget area (the "paper") to an image ----
  final GlobalKey _receiptKey = GlobalKey();

  Future<void> _shareReceiptPdf(BuildContext context) async {
    try {
      // make sure the receipt is painted
      await Future.delayed(const Duration(milliseconds: 50));

      final boundary = _receiptKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not capture receipt.')),
        );
        return;
      }

      // High-res capture of the receipt UI
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to encode receipt image.')),
        );
        return;
      }
      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Build a PDF that embeds the captured receipt image
      final pdf = pw.Document();
      final receiptMem = pw.MemoryImage(pngBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (ctx) => pw.Center(
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 1),
                color: PdfColor.fromInt(0xFFFEFEFA),
              ),
              padding: const pw.EdgeInsets.all(0),
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                child: pw.Image(receiptMem),
              ),
            ),
          ),
        ),
      );

      final now = DateTime.now();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(now);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/LuckyGo_Deposit_Receipt_$dateStr.pdf';
      final file = File(path);
      await file.writeAsBytes(await pdf.save());

      // Share the PDF
      await Share.shareXFiles(
        [XFile(path)],
        text:
            'LuckyGo Driver Deposit Receipt\nAmount: $amount\nLast 4 digits: $last4\nDate: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}\nyou deposit is now pending approval',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(now);

    // format amount to RM with 2dp (fallback to raw text if parse fails)
    String amountStr;
    final amt = double.tryParse(amount.replaceAll(',', ''));
    if (amt != null) {
      amountStr = NumberFormat.currency(locale: 'en_MY', symbol: 'RM ').format(amt);
    } else {
      amountStr = amount;
    }

    final baseMono = const TextStyle(
      fontFamily: 'monospace', // classic receipt feel
      fontSize: 14,
      height: 1.3,
      letterSpacing: 0.2,
    );

    final titleMono = baseMono.copyWith(fontSize: 16, fontWeight: FontWeight.w700);

    Widget receiptImage;
    if (imageUrl.isNotEmpty) {
      receiptImage = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) {
          if (localImagePath != null && File(localImagePath!).existsSync()) {
            return Image.file(File(localImagePath!), fit: BoxFit.cover);
          }
          return const Center(child: Icon(Icons.image_not_supported, size: 64));
        },
      );
    } else if (localImagePath != null && File(localImagePath!).existsSync()) {
      receiptImage = Image.file(File(localImagePath!), fit: BoxFit.cover);
    } else {
      receiptImage = const Center(child: Icon(Icons.image_not_supported, size: 64));
    }

    return PopScope(
      canPop: false, // block back
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F3F1),
        appBar: AppBar(
          centerTitle: true,
          title: const Text('Receipt'),
          automaticallyImplyLeading: false, // hide back arrow
          actions: [
            IconButton(
              tooltip: 'Share PDF',
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () => _shareReceiptPdf(context),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  children: [
                    // ===== RECEIPT PAPER (wrapped with RepaintBoundary) =====
                    RepaintBoundary(
                      key: _receiptKey,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEFEFA), // thermal paper tint
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 16,
                              spreadRadius: 1,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12, width: 0.6),
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 14),
                            // Header
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  Text('LUCKYGO', style: titleMono.copyWith(letterSpacing: 2)),
                                  const SizedBox(height: 2),
                                  Text('DRIVER DEPOSIT RECEIPT', style: baseMono),
                                  const SizedBox(height: 10),
                                  _DashedDivider(color: Colors.black.withOpacity(0.25)),
                                  const SizedBox(height: 6),
                                  _KVRow(label: 'DATE', value: dateStr, style: baseMono),
                                  const SizedBox(height: 2),
                                  _KVRow(label: 'TYPE', value: 'Deposit', style: baseMono),
                                  const SizedBox(height: 2),
                                  _KVRow(label: 'STATUS', value: 'Pending review', style: baseMono),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),
                            const _Perforation(),
                            const SizedBox(height: 8),

                            // Amount & last 4
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  _KVRow(
                                    label: 'AMOUNT',
                                    value: amountStr,
                                    style: baseMono.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  _KVRow(label: 'LAST 4 DIGITS', value: last4, style: baseMono),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),
                            _DashedDivider(color: Colors.black.withOpacity(0.25)),
                            const SizedBox(height: 10),

                            // Attachment (uploaded image)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text('ATTACHMENT', style: baseMono.copyWith(fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 8),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.black12, width: 0.7),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: AspectRatio(
                                      aspectRatio: 4 / 3,
                                      child: receiptImage,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),
                            _DashedDivider(color: Colors.black.withOpacity(0.25)),
                            const SizedBox(height: 8),

                            // Pending line (exact text requested)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'you deposit is now pending approval',
                                textAlign: TextAlign.center,
                                style: baseMono.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),

                            const SizedBox(height: 16),
                            const _Perforation(),
                            const SizedBox(height: 10),

                            // Footer (mini note)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Please keep this receipt for your records.',
                                textAlign: TextAlign.center,
                                style: baseMono.copyWith(fontSize: 12, color: Colors.black.withOpacity(0.65)),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Action buttons: Share PDF + OK
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Share PDF'),
                            onPressed: () => _shareReceiptPdf(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline),
                            label: const Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(builder: (_) => const LandingPage()),
                                (route) => false,
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Key-Value row for receipt lines
class _KVRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle style;
  const _KVRow({required this.label, required this.value, required this.style});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Flexible(
          child: Text(
            value,
            style: style,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Perforated dotted divider — draws as many dots as fit (no overflow).
class _Perforation extends StatelessWidget {
  final double dotSize;
  final double gap;
  final Color? color;
  const _Perforation({
    this.dotSize = 6,
    this.gap = 6,
    this.color,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: dotSize + 4, // small vertical padding
      child: CustomPaint(
        painter: _PerforationPainter(
          dotSize: dotSize,
          gap: gap,
          color: (color ?? Colors.black.withOpacity(0.35)),
        ),
      ),
    );
  }
}

class _PerforationPainter extends CustomPainter {
  final double dotSize;
  final double gap;
  final Color color;

  _PerforationPainter({
    required this.dotSize,
    required this.gap,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final radius = dotSize / 2;
    final y = size.height / 2;

    double x = 0;
    while (x + dotSize <= size.width) {
      canvas.drawCircle(Offset(x + radius, y), radius, paint);
      x += dotSize + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _PerforationPainter oldDelegate) {
    return oldDelegate.dotSize != dotSize ||
        oldDelegate.gap != gap ||
        oldDelegate.color != color;
  }
}

/// Dotted line divider
class _DashedDivider extends StatelessWidget {
  final Color color;
  const _DashedDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedPainter(color: color),
      size: const Size(double.infinity, 1),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  _DashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
