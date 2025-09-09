// qr_code.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class QR extends StatefulWidget {
  const QR({super.key});

  @override
  State<QR> createState() => _QRState();
}

class _QRState extends State<QR> {
  static const String driverUrl =
      'https://play.google.com/store/search?q=Lucky%20Go%20Driver&c=apps';
  static const String passengerUrl =
      'https://play.google.com/store/search?q=Lucky%20Go&c=apps';

  int _index = 0; // 0 = Driver, 1 = Passenger
  final GlobalKey _qrKey = GlobalKey();

  String get _currentTitle => _index == 0 ? 'Driver' : 'Passenger';
  String get _currentUrl => _index == 0 ? driverUrl : passengerUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lucky Go • QR'),
        actions: [
          IconButton(
            tooltip: 'Share link',
            onPressed: _shareLink,
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            ToggleButtons(
              isSelected: [_index == 0, _index == 1],
              borderRadius: BorderRadius.circular(12),
              onPressed: (i) => setState(() => _index = i),
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Driver'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('Passenger'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Play Store link for $_currentTitle',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SelectableText(
                _currentUrl,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          blurRadius: 12,
                          spreadRadius: 2,
                          offset: Offset(0, 6),
                          color: Color(0x22000000),
                        )
                      ],
                      border: Border.all(color: Colors.black12),
                    ),
                    child: QrImageView(
                      data: _currentUrl,
                      version: QrVersions.auto,
                      size: 260,
                      gapless: true,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Colors.black,
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _openInStore,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open'),
                ),
                OutlinedButton.icon(
                  onPressed: _copyLink,
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy link'),
                ),
                OutlinedButton.icon(
                  onPressed: _shareLink,
                  icon: const Icon(Icons.share),
                  label: const Text('Share link'),
                ),
                OutlinedButton.icon(
                  onPressed: _shareQrImage,
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Share QR image'),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _openInStore() async {
    final uri = Uri.parse(_currentUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      _toast('Could not open link.');
    }
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _currentUrl));
    if (!mounted) return;
    _toast('Link copied.');
  }

  Future<void> _shareLink() async {
    await Share.share('Lucky Go $_currentTitle app link:\n$_currentUrl');
  }

  Future<void> _shareQrImage() async {
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        _toast('QR not ready yet.');
        return;
      }
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _toast('Failed to render QR.');
        return;
      }
      final Uint8List bytes = byteData.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file =
          File('${dir.path}/luckygo_${_currentTitle.toLowerCase()}_qr.png');
      await file.writeAsBytes(bytes, flush: true);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Lucky Go $_currentTitle app QR\n$_currentUrl',
      );
    } catch (e) {
      _toast('Share failed: $e');
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }
}
