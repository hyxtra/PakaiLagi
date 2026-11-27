import 'dart:math' as math;

/// Jarak garis lurus antara dua koordinat menggunakan rumus Haversine.
abstract final class DistanceHelper {
  static double kilometers({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(endLatitude - startLatitude);
    final dLon = _radians(endLongitude - startLongitude);
    final lat1 = _radians(startLatitude);
    final lat2 = _radians(endLatitude);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLon / 2), 2);
    final boundedA = a.clamp(0.0, 1.0).toDouble();
    return earthRadiusKm *
        2 *
        math.atan2(math.sqrt(boundedA), math.sqrt(1 - boundedA));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  static String formatKilometers(double kilometers) =>
      '${kilometers.toStringAsFixed(kilometers < 10 ? 1 : 0)} km';
}
