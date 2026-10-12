import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/utils/phone_number_util.dart';
import 'package:app/features/customer/data/models/customer_profile.dart';
import 'package:app/features/auth/data/repositories/mock_user_repository.dart';

void main() {
  group('PhoneNumberUtil Tests', () {
    test('cleanIndianPhone correctly normalizes various input formats', () {
      // 12-digit format with country code 91
      expect(PhoneNumberUtil.cleanIndianPhone('919975811244'), '9975811244');
      // Format with leading +91
      expect(PhoneNumberUtil.cleanIndianPhone('+919975811244'), '9975811244');
      // Format with spaces
      expect(PhoneNumberUtil.cleanIndianPhone('+91 99758 11244'), '9975811244');
      // Format with dashes
      expect(PhoneNumberUtil.cleanIndianPhone('91-99758-11244'), '9975811244');
      // 11-digit format with leading zero
      expect(PhoneNumberUtil.cleanIndianPhone('09975811244'), '9975811244');
      // Plain 10-digit format
      expect(PhoneNumberUtil.cleanIndianPhone('9975811244'), '9975811244');
      // Null and empty
      expect(PhoneNumberUtil.cleanIndianPhone(null), '');
      expect(PhoneNumberUtil.cleanIndianPhone(''), '');
    });

    test('formatE164 outputs standard +91XXXXXXXXXX', () {
      expect(PhoneNumberUtil.formatE164('9975811244'), '+919975811244');
      expect(PhoneNumberUtil.formatE164('919975811244'), '+919975811244');
      expect(PhoneNumberUtil.formatE164('+919975811244'), '+919975811244');
    });

    test('validateIndianMobile accepts 10-digit and 12-digit (with 91) valid numbers', () {
      // Valid cases
      expect(PhoneNumberUtil.validateIndianMobile('9975811244'), isNull);
      expect(PhoneNumberUtil.validateIndianMobile('919975811244'), isNull);
      expect(PhoneNumberUtil.validateIndianMobile('+919975811244'), isNull);
      expect(PhoneNumberUtil.validateIndianMobile('09975811244'), isNull);
      expect(PhoneNumberUtil.validateIndianMobile('8888888888'), isNull);
      expect(PhoneNumberUtil.validateIndianMobile('7777777777'), isNull);
      expect(PhoneNumberUtil.validateIndianMobile('6666666666'), isNull);

      // Invalid: missing/empty
      expect(PhoneNumberUtil.validateIndianMobile(null), 'Mobile number is required');
      expect(PhoneNumberUtil.validateIndianMobile(''), 'Mobile number is required');

      // Invalid: wrong length
      expect(PhoneNumberUtil.validateIndianMobile('99758'), 'Please enter a valid 10-digit mobile number');

      // Invalid: does not start with 6-9
      expect(PhoneNumberUtil.validateIndianMobile('5555555555'), 'Please enter a valid 10-digit Indian mobile number');
      expect(PhoneNumberUtil.validateIndianMobile('1234567890'), 'Please enter a valid 10-digit Indian mobile number');
    });

    test('IndianPhoneNumberFormatter strips 91/0 prefix and caps at 10 digits', () {
      final formatter = IndianPhoneNumberFormatter();

      // Pasting 919975811244
      final result1 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '919975811244'),
      );
      expect(result1.text, '9975811244');

      // Pasting +919975811244
      final result2 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '+919975811244'),
      );
      expect(result2.text, '9975811244');

      // Pasting 09975811244
      final result3 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '09975811244'),
      );
      expect(result3.text, '9975811244');

      // Typing standard 10 digits
      final result4 = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '9876543210'),
      );
      expect(result4.text, '9876543210');
    });
  });

  group('CustomerProfile.isComplete Tests', () {
    test('isComplete is false when full_name is placeholder User XXXX', () {
      const profile = CustomerProfile(
        id: 'user_1',
        fullName: 'User 1244',
        phone: '9975811244',
        defaultAddress: CustomerAddress(
          id: 'addr_1',
          addressLine: 'Narhe',
          area: 'Narhe',
          city: 'Pune',
          state: 'Maharashtra',
          postalCode: '411041',
          isDefault: true,
        ),
      );
      expect(profile.isComplete, isFalse);
    });

    test('isComplete is false when address is missing', () {
      const profile = CustomerProfile(
        id: 'user_1',
        fullName: 'Rajesh Patil',
        phone: '9975811244',
        defaultAddress: null,
      );
      expect(profile.isComplete, isFalse);
    });

    test('isComplete is true when real name and address are both present', () {
      const profile = CustomerProfile(
        id: 'user_1',
        fullName: 'Rajesh Patil',
        phone: '9975811244',
        defaultAddress: CustomerAddress(
          id: 'addr_1',
          addressLine: 'Narhe',
          area: 'Narhe',
          city: 'Pune',
          state: 'Maharashtra',
          postalCode: '411041',
          isDefault: true,
        ),
      );
      expect(profile.isComplete, isTrue);
    });
  });

  group('MockUserRepository Profile Lifecycle', () {
    test('new user onboarding completes and isProfileComplete becomes true', () async {
      final repo = MockUserRepository();
      const newUserId = 'test_new_customer';

      // 1. Initial OTP creates placeholder
      await repo.upsertUserProfile(
        userId: newUserId,
        role: 'CUSTOMER',
        phone: '9975811244',
      );

      // Before completing onboarding, isProfileComplete is false
      expect(await repo.isProfileComplete(newUserId), isFalse);

      // 2. User completes profile with real name
      await repo.updateCustomerProfile(
        userId: newUserId,
        fullName: 'Devesh Ambekar',
        phone: '9975811244',
      );

      // Still false because no address yet
      expect(await repo.isProfileComplete(newUserId), isFalse);

      // 3. User saves address
      await repo.createAddress(
        userId: newUserId,
        addressLine: 'Narhe Road',
        area: 'Narhe',
        city: 'Pune',
        state: 'Maharashtra',
        postalCode: '411041',
      );

      // Now profile is complete! Refreshing page will not bounce back to onboarding
      expect(await repo.isProfileComplete(newUserId), isTrue);
    });
  });
}
