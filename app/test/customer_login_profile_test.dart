import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/auth/data/repositories/mock_user_repository.dart';
import 'package:app/features/auth/data/repositories/mock_auth_repository.dart';

void main() {
  group('Customer Login & Profile Fetch Verification', () {
    late MockUserRepository userRepo;
    late MockAuthRepository authRepo;

    setUp(() {
      userRepo = MockUserRepository();
      authRepo = MockAuthRepository();
    });

    test('1. Existing customer (9876543210 - Priya Sharma) profile is complete and has details', () async {
      final profile = await userRepo.getCustomerProfileByPhone('9876543210');
      expect(profile, isNotNull);
      expect(profile!.fullName, 'Priya Sharma');
      expect(profile.phone, '9876543210');
      expect(profile.defaultAddress, isNotNull);
      expect(profile.defaultAddress!.area, 'Deccan');
      expect(profile.defaultAddress!.city, 'Pune');
      expect(profile.isComplete, isTrue);
    });

    test('2. Existing customer (9823145890 - Rajesh Patil) profile is complete and has details', () async {
      final profile = await userRepo.getCustomerProfileByPhone('9823145890');
      expect(profile, isNotNull);
      expect(profile!.fullName, 'Rajesh Patil');
      expect(profile.defaultAddress, isNotNull);
      expect(profile.defaultAddress!.area, 'Kothrud');
      expect(profile.isComplete, isTrue);
    });

    test('3. Login with existing number preserves full_name and does not overwrite with User XXXX placeholder', () async {
      // Step 1: Verify OTP
      final verified = await authRepo.verifyOtp('9876543210', '123456');
      expect(verified, isTrue);

      final user = await authRepo.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.id, 'mock_customer_01');

      // Step 2: Login upsert call (with null fullName, as done during login)
      await userRepo.upsertUserProfile(
        userId: user.id,
        role: 'CUSTOMER',
        phone: '9876543210',
      );

      // Step 3: Verify full_name is STILL Priya Sharma, not User 3210
      final profile = await userRepo.getCustomerProfile(user.id);
      expect(profile, isNotNull);
      expect(profile!.fullName, 'Priya Sharma');
      expect(profile.isComplete, isTrue);

      final isComplete = await userRepo.isProfileComplete(user.id);
      expect(isComplete, isTrue, reason: 'Existing customer must bypass onboarding directly to home');
    });

    test('4. Brand new phone number requires onboarding, but subsequent login goes directly to home', () async {
      const newPhone = '9111223344';
      final verified = await authRepo.verifyOtp(newPhone, '123456');
      expect(verified, isTrue);

      final user = await authRepo.getCurrentUser();
      expect(user, isNotNull);

      // Check before onboarding
      var profile = await userRepo.getCustomerProfileByPhone(newPhone);
      expect(profile, isNull);

      await userRepo.upsertUserProfile(
        userId: user!.id,
        role: 'CUSTOMER',
        phone: newPhone,
      );

      var isComplete = await userRepo.isProfileComplete(user.id);
      expect(isComplete, isFalse, reason: 'Brand new customer must go to onboarding');

      // Complete onboarding
      await userRepo.updateCustomerProfile(
        userId: user.id,
        fullName: 'Amit Deshmukh',
      );
      await userRepo.createAddress(
        userId: user.id,
        addressLine: 'Flat 402, Rohan Tarang',
        area: 'Wakad',
        city: 'Pune',
        state: 'Maharashtra',
        postalCode: '411057',
      );

      // Profile is now complete
      isComplete = await userRepo.isProfileComplete(user.id);
      expect(isComplete, isTrue);

      // Simulate re-login with the same number later
      await authRepo.logout();
      expect(await authRepo.getCurrentUser(), isNull);

      await authRepo.verifyOtp(newPhone, '123456');
      final returningUser = await authRepo.getCurrentUser();
      expect(returningUser, isNotNull);

      // Calling upsert on login must NOT wipe out Amit Deshmukh
      await userRepo.upsertUserProfile(
        userId: returningUser!.id,
        role: 'CUSTOMER',
        phone: newPhone,
      );

      final returningProfile = await userRepo.getCustomerProfile(returningUser.id);
      expect(returningProfile, isNotNull);
      expect(returningProfile!.fullName, 'Amit Deshmukh');
      expect(returningProfile.defaultAddress!.area, 'Wakad');
      expect(returningProfile.isComplete, isTrue, reason: 'Returning customer must directly login and fetch details');
    });

    test('5. Customer onboarding save executes swiftly without hanging or timing out', () async {
      final stopwatch = Stopwatch()..start();
      const testPhone = '9777888999';
      await authRepo.verifyOtp(testPhone, '123456');
      final user = await authRepo.getCurrentUser();
      expect(user, isNotNull);

      // Save name
      await userRepo.updateCustomerProfile(
        userId: user!.id,
        fullName: 'Sneha Kulkarni',
      );

      // Save address
      await userRepo.createAddress(
        userId: user.id,
        addressLine: '101 Mayflower Apts',
        area: 'Baner',
        city: 'Pune',
        state: 'Maharashtra',
        postalCode: '411045',
        latitude: 18.5590,
        longitude: 73.7868,
      );

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(1000), reason: 'Save operation must complete in under 1 second');

      final profile = await userRepo.getCustomerProfile(user.id);
      expect(profile, isNotNull);
      expect(profile!.fullName, 'Sneha Kulkarni');
      expect(profile.defaultAddress?.area, 'Baner');
      expect(profile.defaultAddress?.latitude, 18.5590);
    });
  });
}
