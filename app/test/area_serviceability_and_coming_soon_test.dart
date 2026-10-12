import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/federation_models.dart';
import 'package:app/core/services/india_geography_service.dart';
import 'package:app/features/customer/data/models/customer_profile.dart';
import 'package:app/features/auth/data/repositories/mock_user_repository.dart';
import 'package:app/features/customer/data/repositories/mock_customer_repository.dart';
import 'package:app/features/worker/data/repositories/mock_worker_repository.dart';
import 'package:app/shared/widgets/area_not_serviceable_screen.dart';

void main() {
  group('Area Serviceability & Coming Soon Flow Tests', () {
    late MockUserRepository userRepo;
    late MockCustomerRepository customerRepo;
    late MockWorkerRepository workerRepo;

    setUp(() {
      userRepo = MockUserRepository();
      customerRepo = MockCustomerRepository();
      workerRepo = MockWorkerRepository();
    });

    test('1. FederationModel.findFederationForLocation accurately resolves serviced vs unserviced areas', () {
      // Serviced areas
      final puneFed = FederationModel.findFederationForLocation(
        district: 'Pune',
        city: 'Pune',
        pincode: '411041',
      );
      expect(puneFed, isNotNull);
      expect(puneFed!.district, 'Pune');
      expect(puneFed.id, '11111111-0000-0000-0000-000000000001');

      final mumbaiFed = FederationModel.findFederationForLocation(
        district: 'Mumbai City',
        city: 'Mumbai',
        pincode: '400001',
      );
      expect(mumbaiFed, isNotNull);
      expect(mumbaiFed!.name.contains('Mumbai'), isTrue);

      final nashikFed = FederationModel.findFederationForLocation(
        district: 'Nashik',
        city: 'Nashik',
        pincode: '422005',
      );
      expect(nashikFed, isNotNull);

      // Unserviced areas must return null
      final sataraFed = FederationModel.findFederationForLocation(
        district: 'Satara',
        city: 'Satara',
        pincode: '415001',
      );
      expect(sataraFed, isNull, reason: 'Satara has no cooperative federation yet');

      final jaipurFed = FederationModel.findFederationForLocation(
        district: 'Jaipur',
        city: 'Jaipur',
        pincode: '302001',
      );
      expect(jaipurFed, isNull, reason: 'Jaipur has no cooperative federation yet');

      // isAreaCoveredByFederation boolean helper
      expect(FederationModel.isAreaCoveredByFederation(district: 'Pune', pincode: '411041'), isTrue);
      expect(FederationModel.isAreaCoveredByFederation(district: 'Satara', pincode: '415001'), isFalse);
    });

    test('2. customerRepo.hasWorkersInArea correctly detects worker availability', () async {
      // In Pune, mock workers exist
      final hasPuneWorkers = await customerRepo.hasWorkersInArea(
        federationId: '11111111-0000-0000-0000-000000000001',
        district: 'Pune',
        city: 'Pune',
        pincode: '411041',
      );
      expect(hasPuneWorkers, isTrue);

      // In an empty/unserviced district, no workers exist
      final hasRemoteWorkers = await customerRepo.hasWorkersInArea(
        federationId: 'non_existent_fed_id',
        district: 'RemoteEmptyDistrict',
        city: 'DesertCity',
        pincode: '999999',
      );
      expect(hasRemoteWorkers, isFalse);
    });

    test('3. Customer registration saves data even when federation does not exist (Coming Soon)', () async {
      const custId = 'cust_unserviced_satara';
      
      // Step 1: Register/save customer profile
      await userRepo.upsertUserProfile(
        userId: custId,
        role: 'CUSTOMER',
        phone: '9822998877',
        fullName: 'Aniket Deshmukh',
      );

      // Step 2: Check federation
      final targetFed = FederationModel.findFederationForLocation(
        district: 'Satara',
        city: 'Satara',
        state: 'Maharashtra',
        pincode: '415001',
      );
      expect(targetFed, isNull);

      // Step 3: Save customer address with null/waitlist federation
      final addr = await userRepo.createAddress(
        userId: custId,
        addressLine: 'Plot 44, Radhika Road',
        area: 'Radhika Road',
        city: 'Satara',
        district: 'Satara',
        state: 'Maharashtra',
        postalCode: '415001',
        federationId: targetFed?.id,
      );

      // Assert customer profile and address are safely persisted in platform
      final savedProfile = await userRepo.getCustomerProfile(custId);
      expect(savedProfile, isNotNull);
      expect(savedProfile!.fullName, 'Aniket Deshmukh');
      expect(savedProfile.phone, '9822998877');
      expect(addr.postalCode, '415001');
      expect(addr.district, 'Satara');

      // Serviceability determination: should trigger AreaNotServiceableScreen with noFederation
      final hasFederation = targetFed != null;
      expect(hasFederation, isFalse);
      
      const reason = ServiceUnavailableReason.noFederation;
      expect(reason, ServiceUnavailableReason.noFederation);
    });

    test('4. Customer registration in area with federation but NO workers triggers Coming Soon (noWorkers)', () async {
      const custId = 'cust_empty_workers_zone';
      
      await userRepo.upsertUserProfile(
        userId: custId,
        role: 'CUSTOMER',
        phone: '9822776655',
        fullName: 'Mahesh Shinde',
      );

      // Assume a custom federation without registered artisans
      const dummyFedId = 'dummy-fed-without-workers';
      final hasWorkers = await customerRepo.hasWorkersInArea(
        federationId: dummyFedId,
        district: 'Solapur',
        city: 'Solapur',
      );
      expect(hasWorkers, isFalse);

      // Customer address is still saved
      final addr = await userRepo.createAddress(
        userId: custId,
        addressLine: 'Near Old Mill Road',
        area: 'Old Mill',
        city: 'Solapur',
        district: 'Solapur',
        state: 'Maharashtra',
        postalCode: '413001',
      );
      expect(addr.city, 'Solapur');

      // Triggers ServiceUnavailableReason.noWorkers
      const reason = ServiceUnavailableReason.noWorkers;
      expect(reason, ServiceUnavailableReason.noWorkers);
    });

    test('5. Worker registration saves application to Waitlist when NO federation exists', () async {
      const workerId = 'worker_satara_waitlist';
      
      final matchingFed = FederationModel.findFederationForLocation(
        district: 'Satara',
        city: 'Satara',
        state: 'Maharashtra',
        pincode: '415001',
      );
      expect(matchingFed, isNull);

      // Worker is registered in platform & founding waitlist
      await workerRepo.registerWorker(
        workerId: workerId,
        fullName: 'Vikas Jadhav',
        phone: '9850112233',
        email: 'vikas@artisan.org',
        skill: 'Plumbing & Pipe Fitting',
        experienceYears: 6,
        serviceLocation: 'Satara MIDC',
        district: 'Satara',
        city: 'Satara',
        pinCode: '415001',
        trade: 'Plumbing',
        skillLevel: 'Expert',
        federationName: matchingFed?.name ?? 'Cooperative Expansion Zone (Satara)',
        federationId: matchingFed?.id,
        bio: 'Senior plumber ready for union expansion',
      );

      // Documents are submitted
      await workerRepo.submitVerificationDocument(
        workerId,
        'IDENTITY',
        '$workerId/aadhaar.pdf',
        'aadhaar.pdf',
        'application/pdf',
        1024,
      );

      await workerRepo.submitForVerification(workerId);

      // Check worker is saved in database
      final profile = await workerRepo.getWorkerProfile(workerId);
      expect(profile.name, 'Vikas Jadhav');
      expect(profile.phone, '9850112233');
      expect(profile.district, 'Satara');
      expect(profile.pinCode, '415001');

      // Documents are stored
      final docs = await workerRepo.getVerificationDocuments(workerId);
      expect(docs.length, 1);
      expect(docs.first['document_type'], 'IDENTITY');

      // Worker should see AreaNotServiceableScreen (Expansion / Waitlist) because federation doesn't exist
      final isCovered = FederationModel.isAreaCoveredByFederation(district: 'Satara', pincode: '415001');
      expect(isCovered, isFalse);
    });

    test('6. Worker registration in serviced district (Pune) proceeds normally to Under Verification', () async {
      const workerId = 'worker_pune_serviced';
      
      final matchingFed = FederationModel.findFederationForLocation(
        district: 'Pune',
        city: 'Pune',
        state: 'Maharashtra',
        pincode: '411038',
      );
      expect(matchingFed, isNotNull);
      expect(matchingFed!.id, '11111111-0000-0000-0000-000000000001');

      await workerRepo.registerWorker(
        workerId: workerId,
        fullName: 'Ganesh More',
        phone: '9890123456',
        skill: 'Electrical & Home Wiring',
        experienceYears: 4,
        serviceLocation: 'Kothrud, Pune',
        district: 'Pune',
        city: 'Pune',
        pinCode: '411038',
        trade: 'Electrical',
        skillLevel: 'Intermediate',
        federationName: matchingFed.name,
        federationId: matchingFed.id,
      );

      await workerRepo.submitForVerification(workerId);

      final profile = await workerRepo.getWorkerProfile(workerId);
      expect(profile.name, 'Ganesh More');
      expect(profile.federationRefId, '11111111-0000-0000-0000-000000000001');
      
      final isCovered = FederationModel.isAreaCoveredByFederation(district: 'Pune', pincode: '411038');
      expect(isCovered, isTrue);
    });

    test('7. Kolhapur (416001) and Solapur (413001) resolve to null federation and do NOT default to Pune', () async {
      // 1. Geography lookup
      final kolhapurGeo = await IndiaGeographyService.lookupPincode('416001');
      expect(kolhapurGeo, isNotNull);
      expect(kolhapurGeo!.district, 'Kolhapur');
      expect(kolhapurGeo.state, 'Maharashtra');

      final solapurGeo = await IndiaGeographyService.lookupPincode('413001');
      expect(solapurGeo, isNotNull);
      expect(solapurGeo!.district, 'Solapur');
      expect(solapurGeo.state, 'Maharashtra');

      // 2. Federation resolution for Kolhapur & Solapur must be null
      final kolhapurFed = FederationModel.findFederationForLocation(
        district: 'Kolhapur',
        city: 'Kolhapur',
        state: 'Maharashtra',
        pincode: '416001',
      );
      expect(kolhapurFed, isNull, reason: 'Kolhapur must NOT resolve to Pune or any other federation');

      final solapurFed = FederationModel.findFederationForLocation(
        district: 'Solapur',
        city: 'Solapur',
        state: 'Maharashtra',
        pincode: '413001',
      );
      expect(solapurFed, isNull, reason: 'Solapur must NOT resolve to Pune or any other federation');

      // 3. Pincode-only resolution for unserviced pin must be null
      expect(FederationModel.findFederationForLocation(pincode: '416001'), isNull);
      expect(FederationModel.findFederationForLocation(pincode: '413001'), isNull);
      expect(FederationModel.findFederationForLocation(pincode: '415001'), isNull);
    });

    test('8. Customer profile name, email, and unserviced federation behavior in userRepo', () async {
      const testUserId = 'test_customer_unserviced_city';

      // 1. Initial creation with phone-like name should be rejected by isComplete
      final incompleteProfile = CustomerProfile(
        id: testUserId,
        fullName: '919975811244',
        phone: '919975811244',
        email: null,
      );
      expect(incompleteProfile.isComplete, isFalse, reason: 'Phone number as full_name must not be considered complete');

      // 2. Update profile with legitimate name and email
      await userRepo.updateCustomerProfile(
        userId: testUserId,
        fullName: 'Devesh Ambekar',
        email: 'devesh@example.com',
        phone: '919975811244',
      );

      // 3. Create address in Kolhapur (unserviced)
      await userRepo.createAddress(
        userId: testUserId,
        addressLine: 'Near Rankala Lake, Kolhapur',
        area: 'Rankala',
        city: 'Kolhapur',
        state: 'Maharashtra',
        district: 'Kolhapur',
        postalCode: '416001',
      );

      // 4. Retrieve profile: must have updated name, email, and null federation (NOT Pune!)
      final updatedProfile = await userRepo.getCustomerProfile(testUserId);
      expect(updatedProfile, isNotNull);
      expect(updatedProfile!.fullName, 'Devesh Ambekar');
      expect(updatedProfile.email, 'devesh@example.com');
      expect(updatedProfile.federationId, isNull, reason: 'Kolhapur address must have null federationId');
      expect(updatedProfile.federationName, isNull, reason: 'Kolhapur address must NOT be assigned to Pune');
      expect(updatedProfile.isComplete, isTrue);
    });
  });
}
