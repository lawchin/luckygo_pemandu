// lib/geo_fencing/blocked_overlay.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class BlockedOverlay extends StatelessWidget {
  const BlockedOverlay({
    super.key,
    required this.regionLabel,
    required this.distanceMeters,
    required this.exitLat,
    required this.exitLng,
    required this.driverLat,
    required this.driverLng,
    required this.outerForPreview,
    this.holesForPreview,
    this.zoneName,
    required this.onOpenPreview,
  });

  final String regionLabel;
  final double distanceMeters;
  final double? exitLat;
  final double? exitLng;

  final double driverLat;
  final double driverLng;

  /// Active fence outer ring for preview (passed to ZonePreviewPage by onOpenPreview).
  final List<List<double>>? outerForPreview;

  /// Active fence holes (open zones) for preview.
  final List<List<List<double>>>? holesForPreview;

  /// Optional zone display name.
  final String? zoneName;

  /// Callback to open the in-app preview map (wired up by the bootstrap page).
  final VoidCallback onOpenPreview;

  String _prettyDistance(double m) {
    if (m <= 0) return '—';
    if (m < 1000) return '${m.toStringAsFixed(0)} m';
    return '${(m / 1000).toStringAsFixed(2)} km';
  }

  Future<void> _navigateToExit(BuildContext context) async {
    if (exitLat == null || exitLng == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exit point not available yet')),
        );
      }
      return;
    }

    String? origin() => (driverLat.isFinite && driverLng.isFinite)
        ? '${driverLat.toStringAsFixed(6)},${driverLng.toStringAsFixed(6)}'
        : null;

    final exitLatStr = exitLat!.toStringAsFixed(6);
    final exitLngStr = exitLng!.toStringAsFixed(6);
    final originStr = origin();

    Future<bool> _try(Uri uri) async {
      try {
        if (!await canLaunchUrl(uri)) return false;
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        return false;
      }
    }

    // Preferred intents/urls by platform
    final navUri = Uri.parse('google.navigation:q=$exitLatStr,$exitLngStr&mode=d');
    final deepUri = Uri(
      scheme: 'comgooglemaps',
      host: '',
      queryParameters: {
        'daddr': '$exitLatStr,$exitLngStr',
        'directionsmode': 'driving',
        if (originStr != null) 'saddr': originStr,
      },
    );
    final geoUri = Uri.parse('geo:0,0?q=$exitLatStr,$exitLngStr(Nearest%20exit)');
    final webUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$exitLatStr,$exitLngStr',
      'travelmode': 'driving',
      if (originStr != null) 'origin': originStr,
    });

    bool launched = false;
    if (Platform.isAndroid) {
      launched = await _try(navUri) || await _try(deepUri) || await _try(geoUri) || await _try(webUri);
      if (!launched) {
        final playUri = Uri.parse('market://details?id=com.google.android.apps.maps');
        final webPlayUri = Uri.https('play.google.com', '/store/apps/details', {
          'id': 'com.google.android.apps.maps',
        });
        launched = await _try(playUri) || await _try(webPlayUri);
      }
    } else {
      launched = await _try(deepUri) || await _try(geoUri) || await _try(webUri);
    }

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = (zoneName != null && zoneName!.isNotEmpty)
        ? 'Restricted Zone ($zoneName)'
        : 'Restricted Zone';

    return Container(
      color: Colors.black.withOpacity(0.75),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Material(
          color: Colors.white,
          elevation: 6,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Banner image (optional – keep your asset path)
                Image.asset(
                  'assets/images/geofencing.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),

                Text(
                  header,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),

                Text(
                  'Region: $regionLabel',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "You are",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, height: 1.35),
                    ),
                    Text(
                      " NOT ",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, height: 1.35, fontWeight: FontWeight.w800, color: Colors.red),
                    ),                
                    Text(
                      "able to receive new",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, height: 1.35),
                    ),
                  ],
                ),
                Text(
                  "job until you leave this zone.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.35),
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.near_me, size: 18, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      'Nearest exit: ${_prettyDistance(distanceMeters)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Actions
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onOpenPreview,
                      icon: const Icon(Icons.map),
                      label: const Text('View Zone on Map'),
                    ),
                    ElevatedButton.icon(
                      onPressed: (exitLat != null && exitLng != null)
                          ? () => _navigateToExit(context)
                          : null,
                      icon: const Icon(Icons.directions),
                      label: const Text('Navigate to Exit'),
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
