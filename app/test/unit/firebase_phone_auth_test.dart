import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/app_config.dart';
import 'package:app/core/services/firebase_phone_auth_service.dart';

void main() {
  group('Firebase Phone Auth OTP Configuration Tests', () {
    test('AppConfig detects firebase as default OTP provider', () {
      expect(AppConfig.otpProvider, 'firebase');
      expect(AppConfig.isFirebaseOtpEnabled, isTrue);
      expect(AppConfig.disableFirebaseRecaptcha, isTrue);
    });

    test('FirebasePhoneAuthResult model creation and attributes', () {
      final success = FirebasePhoneAuthResult.success(
        uid: 'fb_user_123',
        phoneNumber: '+919876543210',
      );
      expect(success.isSuccess, isTrue);
      expect(success.uid, 'fb_user_123');
      expect(success.phoneNumber, '+919876543210');
      expect(success.errorMessage, isNull);

      final failure = FirebasePhoneAuthResult.failure('Incorrect 6-digit OTP code.');
      expect(failure.isSuccess, isFalse);
      expect(failure.uid, isNull);
      expect(failure.errorMessage, 'Incorrect 6-digit OTP code.');
    });

    test('FirebasePhoneAuthService singleton instance verification', () {
      final instance1 = FirebasePhoneAuthService.instance;
      final instance2 = FirebasePhoneAuthService();
      expect(identical(instance1, instance2), isTrue);
    });
  });
}

