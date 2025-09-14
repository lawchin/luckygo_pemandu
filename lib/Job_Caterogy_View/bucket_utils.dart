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
