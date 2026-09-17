import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:app/features/auth/services/mock_auth_service.dart';

void main() {
  group('Auth OTP Verification Tests', () {
    late MockAuthRepository mockAuthRepo;
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthRepo = MockAuthRepository();
      mockAuthService = MockAuthService();
    });

    test('1. MockAuthRepository accepts Supabase test OTP 111111 for 8421296499', () async {
      final isValid = await mockAuthRepo.verifyOtp('8421296499', '111111');
      expect(isValid, isTrue);
      final user = await mockAuthRepo.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.id, equals('f3af7b05-79f8-43e7-a0ea-7bde1c218b72'));
    });

    test('2. MockAuthRepository accepts test OTP 123456 for standard mock phone', () async {
      final isValid = await mockAuthRepo.verifyOtp('9876543210', '123456');
      expect(isValid, isTrue);
      final user = await mockAuthRepo.getCurrentUser();
      expect(user, isNotNull);
      expect(user!.id, equals('mock_customer_01'));
    });

    test('3. MockAuthRepository accepts repeating digits OTP (e.g., 222222)', () async {
      final isValid = await mockAuthRepo.verifyOtp('9123456780', '222222');
      expect(isValid, isTrue);
    });

    test('4. MockAuthRepository rejects invalid OTP', () async {
      final isValid = await mockAuthRepo.verifyOtp('9123456780', '849201');
      expect(isValid, isFalse);
    });

    test('5. MockAuthService accepts 111111 and 123456', () async {
      expect(await mockAuthService.verifyOtp('8421296499', '111111'), isTrue);
      expect(await mockAuthService.verifyOtp('9876543210', '123456'), isTrue);
      expect(await mockAuthService.verifyOtp('9876543210', '000000'), isTrue);
      expect(await mockAuthService.verifyOtp('9876543210', '483921'), isFalse);
    });
  });
}
