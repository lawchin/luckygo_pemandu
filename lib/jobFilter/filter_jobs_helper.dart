/// Lightweight job used for the ≤7.5 km shortlist (for ROAD lookups)
class ShortJob {
  final String jobId;
  final double sLat;
  final double sLng;

  const ShortJob({
    required this.jobId,
    required this.sLat,
    required this.sLng,
  });

  /// Optional helper if you want to build the cache key from the instance
  String cacheKey(double anchorLat, double anchorLng) =>
      '$jobId@$sLat,$sLng@$anchorLat,$anchorLng';
}
