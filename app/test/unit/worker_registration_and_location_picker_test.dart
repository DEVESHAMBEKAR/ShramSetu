import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/services/india_geography_service.dart';
import 'package:app/features/worker/data/models/worker_models.dart';

void main() {
  group('Worker Registration & Proximity Tests', () {
    test('IndiaGeographyService aliases and areas for Ahmednagar/Ahilyanagar', () {
      expect(IndiaGeographyService.matchDistrict('Maharashtra', 'ahilyanagar'), 'Ahmednagar');
      expect(IndiaGeographyService.matchDistrict('Maharashtra', 'Ahmednagar'), 'Ahmednagar');
      
      final areas = IndiaGeographyService.getAreasForDistrict('Maharashtra', 'Ahmednagar');
      expect(areas, contains('Savedi'));
      expect(areas, contains('Bhavani Nagar'));
      expect(areas, contains('Pipeline Road'));
    });

    test('Strict District Isolation - Ahmednagar never suggests Pune localities', () {
      final ahmednagarAreas = IndiaGeographyService.getAreasForDistrict('Maharashtra', 'Ahmednagar');
      final puneAreas = IndiaGeographyService.getAreasForDistrict('Maharashtra', 'Pune');

      for (final a in ahmednagarAreas) {
        expect(puneAreas.contains(a), isFalse, reason: '$a should not be in Pune');
      }
    });

    test('VerificationStatus and WorkerProfile model integrity', () {
      final worker = WorkerProfile(
        id: 'w-1',
        name: 'Ganesh Shinde',
        phone: '9876543210',
        district: 'Ahmednagar',
        city: 'Savedi',
        serviceLocation: 'Savedi, Ahmednagar',
        serviceAreas: const ['Savedi, Ahmednagar', 'Bhavani Nagar, Ahmednagar'],
        skillLevel: 'Intermediate',
        experience: '3 Years',
        verificationStatus: VerificationStatus.pending,
        federationRefId: 'fed_nagar_01',
        federationName: 'Ahmednagar Artisan Federation',
      );

      expect(worker.verificationStatus, VerificationStatus.pending);
      expect(worker.serviceAreas.length, 2);
      expect(worker.serviceAreas.every((a) => a.contains('Ahmednagar')), isTrue);
    });
  });
}

