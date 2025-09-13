// distance_utils.dart
import 'dart:math';

double calculateFlyDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0;
  final dLat = _deg2rad(lat2 - lat1);
  final dLon = _deg2rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
      sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return R * c;
}

int flyBucket(double km) {
  if (km <= 7.5) return 5;
  if (km <= 10) return 6;
  if (km <= 20) return 7;
  if (km <= 30) return 8;
  if (km <= 50) return 9;
  if (km <= 100) return 10;
  if (km <= 200) return 11;
  if (km <= 500) return 12;
  if (km <= 1000) return 13;
  if (km <= 10000) return 14;
  return 15;
}

int roadBucket(double km) {
  if (km <= 1.5) return 1;
  if (km <= 3) return 2;
  if (km <= 5) return 3;
  return 4;
}

double _deg2rad(double deg) => deg * pi / 180.0;
