import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/auth/data/repositories/mock_user_repository.dart';
import 'package:app/features/admin/data/repositories/mock_admin_repository.dart';

void main() {
  group('Customer Federation Automatic Assignment Based On Location Tests', () {
    late MockUserRepository userRepo;

    setUp(() {
      userRepo = MockUserRepository();
    });

    test('1. Pre-seeded Pune customers have Pune Federation assigned', () async {
      final profile = await userRepo.getCustomerProfile('mock_customer_01');
      expect(profile, isNotNull);
      expect(profile!.federationId, '11111111-0000-0000-0000-000000000001');
      expect(profile.federationName, 'Pune District Labour Cooperative Federation');
      expect(profile.defaultAddress?.area, 'Deccan');
      expect(profile.defaultAddress?.city, 'Pune');
    });

    test('2. New customer registering with Nashik location gets assigned Nashik Federation', () async {
      const custId = 'cust_nashik_01';
      await userRepo.upsertUserProfile(
        userId: custId,
        role: 'CUSTOMER',
        phone: '9822114455',
        fullName: 'Sameer Joshi',
      );

      // Customer provides location during onboarding/address save
      final addr = await userRepo.createAddress(
        userId: custId,
        addressLine: 'Flat 12, Anand Heights, College Road',
        area: 'College Road',
        city: 'Nashik',
        district: 'Nashik',
        state: 'Maharashtra',
        postalCode: '422005',
      );

      expect(addr.district, 'Nashik');
      expect(addr.federationId, '22222222-0000-0000-0000-000000000002');

      final profile = await userRepo.getCustomerProfile(custId);
      expect(profile, isNotNull);
      expect(profile!.federationId, '22222222-0000-0000-0000-000000000002');
      expect(profile.federationName, 'Nashik District Artisans Cooperative Union');
    });

    test('3. New customer registering with Mumbai location gets assigned Mumbai Federation', () async {
      const custId = 'cust_mumbai_01';
      await userRepo.upsertUserProfile(
        userId: custId,
        role: 'CUSTOMER',
        phone: '9819988776',
        fullName: 'Rohit Kulkarni',
      );

      final addr = await userRepo.createAddress(
        userId: custId,
        addressLine: 'Hill Road, Bandra West',
        area: 'Bandra West',
        city: 'Mumbai',
        district: 'Mumbai City',
        state: 'Maharashtra',
        postalCode: '400050',
      );

      expect(addr.federationId, '33333333-0000-0000-0000-000000000003');

      final profile = await userRepo.getCustomerProfile(custId);
      expect(profile, isNotNull);
      expect(profile!.federationId, '33333333-0000-0000-0000-000000000003');
      expect(profile.federationName, 'Mumbai Metropolitan Labour Federation');
    });

    test('4. New customer registering with Nagpur location gets assigned Nagpur Federation', () async {
      const custId = 'cust_nagpur_01';
      await userRepo.upsertUserProfile(
        userId: custId,
        role: 'CUSTOMER',
        phone: '9871122334',
        fullName: 'Vandana Tiwari',
      );

      final addr = await userRepo.createAddress(
        userId: custId,
        addressLine: 'Civil Lines Road',
        area: 'Dharampeth',
        city: 'Nagpur',
        district: 'Nagpur',
        state: 'Maharashtra',
        postalCode: '440010',
      );

      expect(addr.federationId, '55555555-0000-0000-0000-000000000005');

      final profile = await userRepo.getCustomerProfile(custId);
      expect(profile, isNotNull);
      expect(profile!.federationId, '55555555-0000-0000-0000-000000000005');
      expect(profile.federationName, 'Nagpur District Shramik Cooperative Union');
    });

    test('5. Customer relocation updates their assigned federation automatically', () async {
      const custId = 'cust_moving_01';
      await userRepo.upsertUserProfile(
        userId: custId,
        role: 'CUSTOMER',
        phone: '9855566677',
        fullName: 'Kiran More',
      );

      // 1. Initial address in Pune
      final addrPune = await userRepo.createAddress(
        userId: custId,
        addressLine: 'FC Road',
        area: 'Shivajinagar',
        city: 'Pune',
        district: 'Pune',
        state: 'Maharashtra',
        postalCode: '411005',
      );
      expect(addrPune.federationId, '11111111-0000-0000-0000-000000000001');

      var profile = await userRepo.getCustomerProfile(custId);
      expect(profile!.federationId, '11111111-0000-0000-0000-000000000001');

      // 2. Customer moves to Nashik and sets new address as default
      final addrNashik = await userRepo.createAddress(
        userId: custId,
        addressLine: 'Panchavati Temple Road',
        area: 'Panchavati',
        city: 'Nashik',
        district: 'Nashik',
        state: 'Maharashtra',
        postalCode: '422003',
      );
      await userRepo.setDefaultAddress(userId: custId, addressId: addrNashik.id);

      profile = await userRepo.getCustomerProfile(custId);
      expect(profile!.federationId, '22222222-0000-0000-0000-000000000002');
      expect(profile.federationName, 'Nashik District Artisans Cooperative Union');
    });

    test('6. Explicit assignCustomerFederation assigns and syncs user federation', () async {
      const custId = 'cust_direct_01';
      await userRepo.upsertUserProfile(
        userId: custId,
        role: 'CUSTOMER',
        phone: '9899988811',
        fullName: 'Deepak Shinde',
      );

      final assignedId = await userRepo.assignCustomerFederation(
        userId: custId,
        district: 'Chhatrapati Sambhajinagar',
        city: 'Chhatrapati Sambhajinagar',
        state: 'Maharashtra',
        area: 'CIDCO',
      );

      expect(assignedId, '44444444-0000-0000-0000-000000000004');

      final profile = await userRepo.getCustomerProfile(custId);
      expect(profile, isNotNull);
      expect(profile!.federationId, '44444444-0000-0000-0000-000000000004');
      expect(profile.federationName, 'Chhatrapati Sambhajinagar Labour Federation');
    });

    test('7. Admin customer filtering partitions customers strictly by assigned federation', () async {
      final adminRepo = MockAdminRepository();

      // All customers in national oversight
      final allCusts = await adminRepo.getCustomers();
      expect(allCusts, isNotEmpty);
      expect(allCusts.any((c) => c.federationId == '11111111-0000-0000-0000-000000000001'), isTrue);
      expect(allCusts.any((c) => c.federationId == '22222222-0000-0000-0000-000000000002'), isTrue);
      expect(allCusts.any((c) => c.federationId == '55555555-0000-0000-0000-000000000005'), isTrue);

      // Scoped federation admin test
      final nashikCustomers = allCusts.where((c) => c.federationId == '22222222-0000-0000-0000-000000000002').toList();
      expect(nashikCustomers.length, 1);
      expect(nashikCustomers.first.name, 'Rajesh Jadhav');
      expect(nashikCustomers.first.district, 'Nashik');

      final nagpurCustomers = allCusts.where((c) => c.federationId == '55555555-0000-0000-0000-000000000005').toList();
      expect(nagpurCustomers.length, 1);
      expect(nagpurCustomers.first.name, 'Manoj Verma');
      expect(nagpurCustomers.first.district, 'Nagpur');
    });
  });
}
