// Web stub for package:geocoding/geocoding.dart
// geocoding has no web support. This stub provides the same API signature
// so the code compiles on web. All functions return empty/null results.

// Stub for Placemark
class Placemark {
  final String? name;
  final String? street;
  final String? subThoroughfare;
  final String? thoroughfare;
  final String? subLocality;
  final String? locality;
  final String? subAdministrativeArea;
  final String? administrativeArea;
  final String? postalCode;

  const Placemark({
    this.name,
    this.street,
    this.subThoroughfare,
    this.thoroughfare,
    this.subLocality,
    this.locality,
    this.subAdministrativeArea,
    this.administrativeArea,
    this.postalCode,
  });
}

/// Stub: returns empty list on web. The LocationService.reverseGeocode()
/// already handles an empty list by returning null gracefully.
Future<List<Placemark>> placemarkFromCoordinates(
  double latitude,
  double longitude, {
  String? localeIdentifier,
}) async {
  return [];
}
