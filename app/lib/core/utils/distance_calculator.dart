import 'dart:math' as math;

/// Reusable utility for calculating straight-line geographic distance using the Haversine formula.
/// Does not call external Google Maps APIs.
class HaversineDistanceUtil {
  /// Mean radius of the Earth in kilometers.
  static const double earthRadiusKm = 6371.0;

  /// Calculate distance between two coordinates in kilometers using the Haversine formula.
  /// Returns `null` if any coordinate is null or invalid.
  static double? calculateDistance(
    double? lat1,
    double? lon1,
    double? lat2,
    double? lon2,
  ) {
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      return null;
    }

    // Identical coordinates
    if (lat1 == lat2 && lon1 == lon2) {
      return 0.0;
    }

    // Validate bounds
    if (lat1 < -90 || lat1 > 90 || lat2 < -90 || lat2 > 90) return null;
    if (lon1 < -180 || lon1 > 180 || lon2 < -180 || lon2 > 180) return null;

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final rLat1 = _degreesToRadians(lat1);
    final rLat2 = _degreesToRadians(lat2);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(rLat1) * math.cos(rLat2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    final distance = earthRadiusKm * c;

    // Round to 1 decimal place
    return (distance * 10).roundToDouble() / 10.0;
  }

  /// Format distance into a user-friendly string (e.g., '450 m', '2.4 km').
  static String formatDistance(double? distanceKm, {String fallback = 'Nearby'}) {
    if (distanceKm == null) return fallback;
    if (distanceKm < 0) return fallback;

    if (distanceKm < 1.0) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    }

    return '${distanceKm.toStringAsFixed(1)} km';
  }

  static double _degreesToRadians(double degrees) {
    return degrees * math.pi / 180.0;
  }
}
