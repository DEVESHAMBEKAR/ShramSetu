import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

/// Status of location permission & hardware state.
enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  servicesDisabled,
  error,
}

/// Simple immutable coordinates model.
class LocationCoordinates {
  final double latitude;
  final double longitude;
  final double? accuracy;

  const LocationCoordinates({
    required this.latitude,
    required this.longitude,
    this.accuracy,
  });

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    if (accuracy != null) 'accuracy': accuracy,
  };

  factory LocationCoordinates.fromMap(Map<String, dynamic> map) {
    return LocationCoordinates(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() => 'LocationCoordinates($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationCoordinates &&
          runtimeType == other.runtimeType &&
          latitude == other.latitude &&
          longitude == other.longitude;

  @override
  int get hashCode => latitude.hashCode ^ longitude.hashCode;
}

/// Structured reverse-geocoded address.
class GeoAddress {
  final String addressLine;
  final String area;
  final String city;
  final String state;
  final String postalCode;

  const GeoAddress({
    required this.addressLine,
    required this.area,
    required this.city,
    required this.state,
    required this.postalCode,
  });

  String get formattedAddress {
    final parts = [
      if (addressLine.isNotEmpty) addressLine,
      if (area.isNotEmpty) area,
      if (city.isNotEmpty) city,
      if (state.isNotEmpty) state,
      if (postalCode.isNotEmpty) postalCode,
    ];
    return parts.join(', ');
  }

  Map<String, dynamic> toMap() => {
    'address_line': addressLine,
    'area': area,
    'city': city,
    'state': state,
    'postal_code': postalCode,
  };

  factory GeoAddress.fromMap(Map<String, dynamic> map) {
    return GeoAddress(
      addressLine: map['address_line'] as String? ?? '',
      area: map['area'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
      postalCode: map['postal_code'] as String? ?? '',
    );
  }
}

/// Result returned from LocationService.getCurrentPosition
class LocationResult {
  final LocationPermissionStatus status;
  final LocationCoordinates? coordinates;
  final String? errorMessage;

  const LocationResult({
    required this.status,
    this.coordinates,
    this.errorMessage,
  });

  bool get isSuccess => status == LocationPermissionStatus.granted && coordinates != null;
}

/// Abstract contract for device location services to enable unit testing and mocking.
abstract class ILocationService {
  Future<LocationPermissionStatus> checkAndRequestPermission();
  Future<LocationResult> getCurrentPosition({Duration timeout});
  Future<GeoAddress?> reverseGeocode(double latitude, double longitude);
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

/// Production implementation of ILocationService using Geolocator and Geocoding.
class LocationService implements ILocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  @override
  Future<LocationPermissionStatus> checkAndRequestPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionStatus.servicesDisabled;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationPermissionStatus.denied;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationPermissionStatus.deniedForever;
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        return LocationPermissionStatus.granted;
      }

      return LocationPermissionStatus.denied;
    } catch (e) {
      debugPrint('LocationService checkAndRequestPermission error: $e');
      return LocationPermissionStatus.error;
    }
  }

  @override
  Future<LocationResult> getCurrentPosition({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    try {
      final permStatus = await checkAndRequestPermission();
      if (permStatus != LocationPermissionStatus.granted) {
        return LocationResult(
          status: permStatus,
          errorMessage: _getPermissionErrorMessage(permStatus),
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeout,
        ),
      );

      return LocationResult(
        status: LocationPermissionStatus.granted,
        coordinates: LocationCoordinates(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
        ),
      );
    } on TimeoutException {
      // Fallback: try last known position if timeout occurs
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          return LocationResult(
            status: LocationPermissionStatus.granted,
            coordinates: LocationCoordinates(
              latitude: lastKnown.latitude,
              longitude: lastKnown.longitude,
              accuracy: lastKnown.accuracy,
            ),
          );
        }
      } catch (_) {}

      return const LocationResult(
        status: LocationPermissionStatus.error,
        errorMessage: 'GPS request timed out. You can enter your address manually.',
      );
    } catch (e) {
      debugPrint('LocationService getCurrentPosition error: $e');
      return LocationResult(
        status: LocationPermissionStatus.error,
        errorMessage: 'Unable to retrieve current location: $e',
      );
    }
  }

  @override
  Future<GeoAddress?> reverseGeocode(double latitude, double longitude) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isEmpty) return null;

      final p = placemarks.first;
      
      // Compose clean addressLine from street, name, or subThoroughfare + thoroughfare
      final streetParts = [
        if (p.subThoroughfare != null && p.subThoroughfare!.isNotEmpty) p.subThoroughfare,
        if (p.thoroughfare != null && p.thoroughfare!.isNotEmpty) p.thoroughfare,
      ];
      final addressLine = streetParts.isNotEmpty
          ? streetParts.join(' ')
          : (p.street?.isNotEmpty == true ? p.street! : (p.name ?? ''));

      final area = p.subLocality?.isNotEmpty == true
          ? p.subLocality!
          : (p.subAdministrativeArea ?? '');

      final city = p.locality?.isNotEmpty == true
          ? p.locality!
          : (p.subAdministrativeArea ?? 'Pune');

      final state = p.administrativeArea?.isNotEmpty == true
          ? p.administrativeArea!
          : 'Maharashtra';

      final postalCode = p.postalCode?.isNotEmpty == true
          ? p.postalCode!
          : '';

      return GeoAddress(
        addressLine: addressLine,
        area: area,
        city: city,
        state: state,
        postalCode: postalCode,
      );
    } catch (e) {
      debugPrint('LocationService reverseGeocode error: $e');
      // Graceful fallback — reverse geocoding failure must never crash the app
      return null;
    }
  }

  @override
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (_) {
      return false;
    }
  }

  String _getPermissionErrorMessage(LocationPermissionStatus status) {
    switch (status) {
      case LocationPermissionStatus.servicesDisabled:
        return 'Location services are disabled on your device. Please enable GPS in your device settings or enter your address manually.';
      case LocationPermissionStatus.denied:
        return 'Location permission was denied. You can still enter your address manually.';
      case LocationPermissionStatus.deniedForever:
        return 'Location permission is permanently denied. You can enable it in Settings or enter your address manually.';
      case LocationPermissionStatus.error:
        return 'Failed to determine location. Please enter your address manually.';
      case LocationPermissionStatus.granted:
        return '';
    }
  }
}
