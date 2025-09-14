import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;

class RoadResult {
  final double km;
  final int eta;
  RoadResult(this.km, this.eta);
}

double deg2rad(double deg) => deg * pi / 180;

double flyDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0;
  final dLat = deg2rad(lat2 - lat1);
  final dLon = deg2rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(deg2rad(lat1)) * cos(deg2rad(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

Future<RoadResult> getRoadDistanceAndEta({
  required double lat1,
  required double lon1,
  required double lat2,
  required double lon2,
  required double Function(double, double, double, double) fallbackDistanceFn,
}) async {
  final apiKey = 'YOUR_API_KEY';
  final url = Uri.parse(
    'https://maps.googleapis.com/maps/api/directions/json?origin=$lat1,$lon1&destination=$lat2,$lon2&key=$apiKey'
  );

  try {
    final response = await http.get(url);
    if (response.statusCode != 200) throw Exception('Failed to fetch directions');

    final data = jsonDecode(response.body);
    final route = data['routes']?[0];
    final leg = route?['legs']?[0];
    final meters = leg?['distance']?['value'];
    final seconds = leg?['duration']?['value'];

    if (meters == null || seconds == null) throw Exception('Missing distance or duration');

    final roadKm = meters / 1000.0;
    final rawMinutes = seconds / 60.0;
    final etaMinutes = rawMinutes < 0.8 ? rawMinutes.floor() : rawMinutes.floor() + 1;

    return RoadResult(roadKm, etaMinutes);
  } catch (e) {
    print('[DistanceUtils] ❌ Road distance error: $e');
    final fallbackKm = fallbackDistanceFn(lat1, lon1, lat2, lon2);
    return RoadResult(fallbackKm, -1);
  }
}
