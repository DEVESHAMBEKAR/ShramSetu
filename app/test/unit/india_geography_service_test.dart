import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/india_geography_service.dart';

void main() {
  group('IndiaGeographyService Tests', () {
    test('states contains all 28 states and 8 union territories', () {
      final states = IndiaGeographyService.states;
      expect(states.length, equals(36));
      expect(states.contains('Maharashtra'), isTrue);
      expect(states.contains('Delhi'), isTrue);
      expect(states.contains('Karnataka'), isTrue);
      expect(states.contains('Tamil Nadu'), isTrue);
      expect(states.contains('Gujarat'), isTrue);
      expect(states.contains('Uttar Pradesh'), isTrue);
      expect(states.contains('West Bengal'), isTrue);
    });

    test('getDistricts returns official districts for Maharashtra', () {
      final dists = IndiaGeographyService.getDistricts('Maharashtra');
      expect(dists.contains('Pune'), isTrue);
      expect(dists.contains('Mumbai City'), isTrue);
      expect(dists.contains('Mumbai Suburban'), isTrue);
      expect(dists.contains('Nagpur'), isTrue);
      expect(dists.contains('Nashik'), isTrue);
      expect(dists.contains('Chhatrapati Sambhajinagar'), isTrue);
    });

    test('lookupPincode resolves Pune 411038 with areas', () async {
      final result = await IndiaGeographyService.lookupPincode('411038');
      expect(result, isNotNull);
      expect(result!.state, equals('Maharashtra'));
      expect(result.district, equals('Pune'));
      expect(result.areas.isNotEmpty, isTrue);
    });

    test('lookupPincode resolves Delhi 110001', () async {
      final result = await IndiaGeographyService.lookupPincode('110001');
      expect(result, isNotNull);
      expect(result!.state, equals('Delhi'));
    });

    test('matchState and matchDistrict handle case insensitivity', () {
      expect(IndiaGeographyService.matchState('maharashtra'), equals('Maharashtra'));
      expect(IndiaGeographyService.matchDistrict('Maharashtra', 'pune'), equals('Pune'));
    });
  });
}
