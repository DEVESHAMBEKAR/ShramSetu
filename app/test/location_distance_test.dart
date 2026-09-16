import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/location_service.dart';
import 'package:app/core/utils/distance_calculator.dart';
import 'package:app/features/customer/data/models/customer_profile.dart';
import 'package:app/features/worker/data/models/worker_models.dart';
import 'package:app/features/worker/data/repositories/mock_worker_repository.dart';
import 'package:app/features/booking/data/models/booking_models.dart';

/// Test mock implementation of ILocationService for hermetic testing.
class TestMockLocationService implements ILocationService {
  LocationPermissionStatus mockPermissionStatus = LocationPermissionStatus.granted;
  LocationCoordinates? mockCoordinates = const LocationCoordinates(
    latitude: 18.5204,
    longitude: 73.8567,
    accuracy: 5.0,
  );
  GeoAddress? mockGeoAddress = const GeoAddress(
    addressLine: '123 MG Road',
    area: 'Camp',
    city: 'Pune',
    state: 'Maharashtra',
    postalCode: '411001',
  );

  @override
  Future<LocationPermissionStatus> checkAndRequestPermission() async {
    return mockPermissionStatus;
  }

  @override
  Future<LocationResult> getCurrentPosition({Duration timeout = const Duration(seconds: 10)}) async {
    if (mockPermissionStatus != LocationPermissionStatus.granted) {
      return LocationResult(
        status: mockPermissionStatus,
        errorMessage: 'Permission not granted: $mockPermissionStatus',
      );
    }
    return LocationResult(
      status: LocationPermissionStatus.granted,
      coordinates: mockCoordinates,
    );
  }

  @override
  Future<GeoAddress?> reverseGeocode(double latitude, double longitude) async {
    return mockGeoAddress;
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  group('1. Coordinate Model & Serialization', () {
    test('LocationCoordinates equality, toString and toMap', () {
      const coord1 = LocationCoordinates(latitude: 18.5204, longitude: 73.8567, accuracy: 10.0);
      const coord2 = LocationCoordinates(latitude: 18.5204, longitude: 73.8567, accuracy: 10.0);
      const coord3 = LocationCoordinates(latitude: 18.5000, longitude: 73.8000);

      expect(coord1, equals(coord2));
      expect(coord1.hashCode, equals(coord2.hashCode));
      expect(coord1 == coord3, isFalse);
      expect(coord1.toString(), contains('18.5204'));

      final map = coord1.toMap();
      expect(map['latitude'], 18.5204);
      expect(map['longitude'], 73.8567);
      expect(map['accuracy'], 10.0);

      final fromMap = LocationCoordinates.fromMap(map);
      expect(fromMap.latitude, 18.5204);
      expect(fromMap.longitude, 73.8567);
    });
  });

  group('2. Address Coordinate Serialization & Deserialization', () {
    test('CustomerAddress parses null coordinates gracefully', () {
      final jsonWithoutCoords = {
        'id': 'addr_1',
        'address_line': 'Flat 101, Galaxy Apts',
        'area': 'Kothrud',
        'city': 'Pune',
        'state': 'MH',
        'postal_code': '411038',
        'is_default': true,
      };

      final addr = CustomerAddress.fromMap(jsonWithoutCoords);
      expect(addr.id, 'addr_1');
      expect(addr.latitude, isNull);
      expect(addr.longitude, isNull);
      expect(addr.hasCoordinates, isFalse);
      expect(addr.displayString, contains('Kothrud, Pune'));

      final toMap = addr.toMap();
      expect(toMap.containsKey('latitude'), isFalse);
      expect(toMap.containsKey('longitude'), isFalse);
    });

    test('CustomerAddress parses valid coordinates and serializes correctly', () {
      final jsonWithCoords = {
        'id': 'addr_2',
        'address_line': 'Shop 4, Market Yard',
        'area': 'Gultekdi',
        'city': 'Pune',
        'state': 'Maharashtra',
        'postal_code': '411037',
        'is_default': false,
        'latitude': 18.4892,
        'longitude': 73.8643,
      };

      final addr = CustomerAddress.fromMap(jsonWithCoords);
      expect(addr.latitude, 18.4892);
      expect(addr.longitude, 73.8643);
      expect(addr.hasCoordinates, isTrue);

      final map = addr.toMap();
      expect(map['latitude'], 18.4892);
      expect(map['longitude'], 73.8643);

      final updated = addr.copyWith(latitude: 18.5000);
      expect(updated.latitude, 18.5000);
      expect(updated.longitude, 73.8643);
    });
  });

  group('3. Haversine Distance Calculations', () {
    test('Zero distance calculation for identical coordinates', () {
      final d = HaversineDistanceUtil.calculateDistance(18.5204, 73.8567, 18.5204, 73.8567);
      expect(d, equals(0.0));
    });

    test('Known distance between Pune Railway Station and Swargate', () {
      // Pune Station: ~18.5284, 73.8743
      // Swargate: ~18.5018, 73.8586
      // Straight line distance is ~3.4 - 3.5 km
      final dist = HaversineDistanceUtil.calculateDistance(18.5284, 73.8743, 18.5018, 73.8586);
      expect(dist, isNotNull);
      expect(dist!, greaterThan(3.0));
      expect(dist, lessThan(4.0));
    });

    test('Distance calculation is symmetric (A->B == B->A)', () {
      final d1 = HaversineDistanceUtil.calculateDistance(18.5284, 73.8743, 18.5018, 73.8586);
      final d2 = HaversineDistanceUtil.calculateDistance(18.5018, 73.8586, 18.5284, 73.8743);
      expect(d1, equals(d2));
    });

    test('Invalid and null coordinates return null without crashing', () {
      expect(HaversineDistanceUtil.calculateDistance(null, 73.85, 18.52, 73.86), isNull);
      expect(HaversineDistanceUtil.calculateDistance(18.52, null, 18.52, 73.86), isNull);
      expect(HaversineDistanceUtil.calculateDistance(18.52, 73.85, null, 73.86), isNull);
      expect(HaversineDistanceUtil.calculateDistance(18.52, 73.85, 18.52, null), isNull);

      // Out of bounds
      expect(HaversineDistanceUtil.calculateDistance(95.0, 73.85, 18.52, 73.86), isNull);
      expect(HaversineDistanceUtil.calculateDistance(18.52, -200.0, 18.52, 73.86), isNull);
    });

    test('formatDistance formats meters and kilometers cleanly', () {
      expect(HaversineDistanceUtil.formatDistance(0.45), '450 m');
      expect(HaversineDistanceUtil.formatDistance(0.08), '80 m');
      expect(HaversineDistanceUtil.formatDistance(1.24), '1.2 km');
      expect(HaversineDistanceUtil.formatDistance(12.78), '12.8 km');
      expect(HaversineDistanceUtil.formatDistance(null), 'Nearby');
      expect(HaversineDistanceUtil.formatDistance(-1.0), 'Nearby');
    });
  });

  group('4. Location Permission & Result Handling', () {
    test('LocationResult indicates success only when granted with coords', () {
      const successResult = LocationResult(
        status: LocationPermissionStatus.granted,
        coordinates: LocationCoordinates(latitude: 18.5204, longitude: 73.8567),
      );
      expect(successResult.isSuccess, isTrue);

      const deniedResult = LocationResult(
        status: LocationPermissionStatus.denied,
        errorMessage: 'Permission denied',
      );
      expect(deniedResult.isSuccess, isFalse);

      const disabledResult = LocationResult(
        status: LocationPermissionStatus.servicesDisabled,
        errorMessage: 'GPS is disabled',
      );
      expect(disabledResult.isSuccess, isFalse);
    });

    test('TestMockLocationService simulates permission states', () async {
      final mock = TestMockLocationService();

      // Default granted
      var res = await mock.getCurrentPosition();
      expect(res.isSuccess, isTrue);
      expect(res.coordinates?.latitude, 18.5204);

      // Denied
      mock.mockPermissionStatus = LocationPermissionStatus.denied;
      res = await mock.getCurrentPosition();
      expect(res.isSuccess, isFalse);
      expect(res.status, LocationPermissionStatus.denied);

      // Reverse geocode
      final addr = await mock.reverseGeocode(18.5204, 73.8567);
      expect(addr?.city, 'Pune');
      expect(addr?.formattedAddress, contains('Pune'));
    });
  });

  group('5. Worker Location Model & Repository Updates', () {
    test('WorkerProfile location properties and copyWith', () {
      final worker = WorkerProfile(
        id: 'w1',
        name: 'Rahul',
        profileImage: '',
        phone: '9999999999',
        skills: ['Plumbing'],
        experience: '5 Years',
        rating: 4.8,
        completedJobs: 50,
        earnings: 5000,
        isVerified: true,
        verificationStatus: VerificationStatus.approved,
        isAvailable: true,
        serviceLocation: 'Kothrud, Pune',
        guildName: 'Guild',
        guildId: '1',
      );

      expect(worker.hasLocation, isFalse);
      expect(worker.latitude, isNull);

      final withLocation = worker.copyWith(
        latitude: 18.5074,
        longitude: 73.8077,
        locationUpdatedAt: DateTime(2026, 1, 1),
      );

      expect(withLocation.hasLocation, isTrue);
      expect(withLocation.latitude, 18.5074);
      expect(withLocation.longitude, 73.8077);
      expect(withLocation.locationUpdatedAt, isNotNull);
    });

    test('MockWorkerRepository persists location updates', () async {
      final repo = MockWorkerRepository();
      final initial = await repo.getWorkerProfile('w101');
      expect(initial.hasLocation, isFalse);

      await repo.updateWorkerLocation(
        'w101',
        latitude: 18.5204,
        longitude: 73.8567,
        locationTag: 'Shivaji Nagar, Pune',
      );

      final updated = await repo.getWorkerProfile('w101');
      expect(updated.hasLocation, isTrue);
      expect(updated.latitude, 18.5204);
      expect(updated.longitude, 73.8567);
      expect(updated.serviceLocation, 'Shivaji Nagar, Pune');
      expect(updated.locationUpdatedAt, isNotNull);
    });
  });

  group('6. Booking Flow State & Location Compatibility', () {
    test('BookingFlowState stores optional addressId and coordinates', () {
      final state = BookingFlowState(
        address: 'MG Road, Pune',
        addressId: 'addr_123',
        latitude: 18.5204,
        longitude: 73.8567,
      );

      expect(state.addressId, 'addr_123');
      expect(state.latitude, 18.5204);
      expect(state.longitude, 73.8567);
    });

    test('GeoAddress formats full address correctly', () {
      const geo = GeoAddress(
        addressLine: 'Flat 402, Nilgiri Apts',
        area: 'Aundh',
        city: 'Pune',
        state: 'Maharashtra',
        postalCode: '411007',
      );

      expect(geo.formattedAddress, 'Flat 402, Nilgiri Apts, Aundh, Pune, Maharashtra, 411007');
      final map = geo.toMap();
      expect(map['area'], 'Aundh');
      expect(map['city'], 'Pune');

      final fromMap = GeoAddress.fromMap(map);
      expect(fromMap.formattedAddress, geo.formattedAddress);
    });
  });
}
