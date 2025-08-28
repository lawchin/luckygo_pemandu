// lib/geo_fencing/zone_preview.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ZonePreviewPage extends StatefulWidget {
  final String regionLabel;
  final List<List<double>> outer;                  // [[lat, lng], ...]
  final List<List<List<double>>> holes;            // [ [ [lat,lng], ... ], ... ]
  final double driverLat;
  final double driverLng;
  final double? exitLat;
  final double? exitLng;

  const ZonePreviewPage({
    super.key,
    required this.regionLabel,
    required this.outer,
    required this.holes,        // <-- REQUIRED (fixes "No named parameter 'holes'")
    required this.driverLat,
    required this.driverLng,
    this.exitLat,
    this.exitLng,
  });

  @override
  State<ZonePreviewPage> createState() => _ZonePreviewPageState();
}

class _ZonePreviewPageState extends State<ZonePreviewPage> {
  BitmapDescriptor? _carIcon;

  @override
  void initState() {
    super.initState();
    _loadCustomMarker();
  }

  Future<void> _loadCustomMarker() async {
    final icon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(64, 64)),
      'assets/images/car.png', // make sure this path exists in pubspec.yaml
    );
    if (!mounted) return;
    setState(() => _carIcon = icon);
  }

  @override
  Widget build(BuildContext context) {
    final driverPos = LatLng(widget.driverLat, widget.driverLng);

    // Build polygons
    final polygons = <Polygon>{};

    // Red outer (blocked) polygon
    final outerPoints = widget.outer.map((p) => LatLng(p[0], p[1])).toList();
    polygons.add(
      Polygon(
        polygonId: const PolygonId('geofence_outer'),
        points: outerPoints,
        strokeWidth: 3,
        strokeColor: Colors.red,
        fillColor: Colors.red.withOpacity(0.20),
        zIndex: 1,
      ),
    );

    // Blue holes (open zones)
    for (int i = 0; i < widget.holes.length; i++) {
      final ring = widget.holes[i];
      if (ring.isEmpty) continue;
      final ringPoints = ring.map((p) => LatLng(p[0], p[1])).toList();
      polygons.add(
        Polygon(
          polygonId: PolygonId('geofence_hole_$i'),
          points: ringPoints,
          strokeWidth: 2,
          strokeColor: Colors.blue,
          fillColor: Colors.blue.withOpacity(0.25),
          zIndex: 2, // draw above red
        ),
      );
    }

    // Markers
    final markers = <Marker>{
      // Driver marker with custom car icon (fallback if not yet loaded)
      Marker(
        markerId: const MarkerId('driver'),
        position: driverPos,
        infoWindow: const InfoWindow(title: 'You are here'),
        icon: _carIcon ?? BitmapDescriptor.defaultMarker,
        anchor: const Offset(0.5, 0.5),
      ),
    };

    // Exit marker labeled "Nearest exit" (label shows on tap)
    if (widget.exitLat != null && widget.exitLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('exit'),
          position: LatLng(widget.exitLat!, widget.exitLng!),
          infoWindow: const InfoWindow(title: 'Nearest exit'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Geofence • ${widget.regionLabel}')),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: driverPos,
          zoom: 16,
        ),
        polygons: polygons,
        markers: markers,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}


// import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';

// class ZonePreviewPage extends StatefulWidget {
//   final String regionLabel;
//   final List<List<double>> outer; // polygon coordinates [[lat, lng], ...]
//   final double driverLat;
//   final double driverLng;
//   final double? exitLat;
//   final double? exitLng;

//   const ZonePreviewPage({
//     super.key,
//     required this.regionLabel,
//     required this.outer,
//     required this.driverLat,
//     required this.driverLng,
//     this.exitLat,
//     this.exitLng,
//   });

//   @override
//   State<ZonePreviewPage> createState() => _ZonePreviewPageState();
// }

// class _ZonePreviewPageState extends State<ZonePreviewPage> {
//   BitmapDescriptor? _carIcon;

//   @override
//   void initState() {
//     super.initState();
//     _loadCustomMarker();
//   }

//   Future<void> _loadCustomMarker() async {
//     final icon = await BitmapDescriptor.fromAssetImage(
//       const ImageConfiguration(size: Size(48, 48)),
//       'assets/images/car.png',
//     );
//     setState(() {
//       _carIcon = icon;
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final driverPos = LatLng(widget.driverLat, widget.driverLng);
//     final polygonPoints = widget.outer.map((p) => LatLng(p[0], p[1])).toList();

//     final polygon = Polygon(
//       polygonId: const PolygonId('geofence'),
//       points: polygonPoints,
//       strokeWidth: 3,
//       strokeColor: Colors.red,
//       fillColor: Colors.red.withOpacity(0.2),
//     );

//     final markers = <Marker>{};

//     // Driver marker with custom car icon
//     if (_carIcon != null) {
//       markers.add(
//         Marker(
//           markerId: const MarkerId('driver'),
//           position: driverPos,
//           infoWindow: const InfoWindow(title: 'You are here'),
//           icon: _carIcon!,
//         ),
//       );
//     }

//     // Exit marker with "Nearest exit" label
//     if (widget.exitLat != null && widget.exitLng != null) {
//       markers.add(
//         Marker(
//           markerId: const MarkerId('exit'),
//           position: LatLng(widget.exitLat!, widget.exitLng!),
//           infoWindow: const InfoWindow(title: 'Nearest exit'),
//           icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
//           // Custom label via infoWindow (shows when tapping)
//         ),
//       );
//     }

//     return Scaffold(
//       appBar: AppBar(title: Text('Geofence • ${widget.regionLabel}')),
//       body: GoogleMap(
//         initialCameraPosition: CameraPosition(
//           target: driverPos,
//           zoom: 16,
//         ),
//         polygons: {polygon},
//         markers: markers,
//         myLocationEnabled: true,
//         myLocationButtonEnabled: true,
//       ),
//     );
//   }
// }
