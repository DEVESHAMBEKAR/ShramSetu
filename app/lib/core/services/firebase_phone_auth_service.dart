import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../utils/phone_number_util.dart';

/// Result returned after verifying OTP with Firebase Phone Auth
class FirebasePhoneAuthResult {
  final bool isSuccess;
  final String? uid;
  final String? phoneNumber;
  final String? errorMessage;

  const FirebasePhoneAuthResult({
    required this.isSuccess,
    this.uid,
    this.phoneNumber,
    this.errorMessage,
  });

  factory FirebasePhoneAuthResult.success({
    required String uid,
    required String phoneNumber,
  }) {
    return FirebasePhoneAuthResult(
      isSuccess: true,
      uid: uid,
      phoneNumber: phoneNumber,
    );
  }

  factory FirebasePhoneAuthResult.failure(String message) {
    return FirebasePhoneAuthResult(
      isSuccess: false,
      errorMessage: message,
    );
  }
}

/// Service dedicated strictly to SMS OTP delivery and verification using Firebase Phone Auth.
/// Provides 10,000 free SMS OTPs per month across India and globally.
class FirebasePhoneAuthService {
  static final FirebasePhoneAuthService instance = FirebasePhoneAuthService._internal();
  factory FirebasePhoneAuthService() => instance;
  FirebasePhoneAuthService._internal();

  FirebaseAuth? _auth;
  ConfirmationResult? _webConfirmationResult;
  String? _verificationId;
  int? _resendToken;
  String? _activePhoneNumber;
  PhoneAuthCredential? _autoVerifiedCredential;

  String? get activePhoneNumber => _activePhoneNumber;

  bool get isAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseAuth get auth {
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  String _formatPhone(String phone) {
    final clean = PhoneNumberUtil.cleanIndianPhone(phone);
    if (clean.length == 10) return '+91$clean';
    return phone.startsWith('+') ? phone : '+$phone';
  }

  /// Sends a 6-digit SMS OTP to the given phone number via Firebase
  Future<void> sendOtp(String phone) async {
    final formattedPhone = _formatPhone(phone);
    _activePhoneNumber = formattedPhone;
    _autoVerifiedCredential = null;
    _verificationId = null;
    _webConfirmationResult = null;

    // 1. Web Flow (Chrome / Edge / Safari on Web)
    if (kIsWeb) {
      debugPrint('[FirebasePhoneAuth] Initiating Web Phone Auth for $formattedPhone...');
      if (AppConfig.disableFirebaseRecaptcha) {
        debugPrint('[FirebasePhoneAuth] Disabling reCAPTCHA app verification for testing mode...');
        try {
          await auth.setSettings(appVerificationDisabledForTesting: true);
        } catch (e) {
          debugPrint('[FirebasePhoneAuth] Could not set appVerificationDisabledForTesting: $e');
        }
      }

      try {
        _webConfirmationResult = await auth.signInWithPhoneNumber(formattedPhone);
        debugPrint('[FirebasePhoneAuth] Web ConfirmationResult acquired. SMS OTP sent successfully.');
        return;
      } on FirebaseAuthException catch (e) {
        debugPrint('[FirebasePhoneAuth] Web sendOtp error: [${e.code}] ${e.message}');
        throw Exception(_mapFirebaseError(e));
      } catch (e) {
        debugPrint('[FirebasePhoneAuth] Web sendOtp unexpected error: $e');
        throw Exception('Failed to send SMS OTP on Web: $e');
      }
    }

    // 2. Native Flow (Android / iOS)
    final completer = Completer<void>();

    try {
      await auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          debugPrint('[FirebasePhoneAuth] Automatic SMS verification completed on device.');
          _autoVerifiedCredential = credential;
          try {
            await auth.signInWithCredential(credential);
          } catch (e) {
            debugPrint('[FirebasePhoneAuth] Auto-sign in error: $e');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('[FirebasePhoneAuth] Verification failed: [${e.code}] ${e.message}');
          final message = _mapFirebaseError(e);
          if (!completer.isCompleted) {
            completer.completeError(Exception(message));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          debugPrint('[FirebasePhoneAuth] SMS OTP sent. Verification ID acquired: $verificationId');
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          debugPrint('[FirebasePhoneAuth] Auto-retrieval timed out. Manual OTP entry active.');
        },
      );

      return await completer.future;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseError(e));
    } catch (e) {
      if (!completer.isCompleted) {
        throw Exception('Failed to send SMS OTP: $e');
      }
    }
  }

  /// Verifies the 6-digit SMS OTP code entered by the user
  Future<FirebasePhoneAuthResult> verifyOtp(String phone, String otp) async {
    final formattedPhone = _formatPhone(phone);
    final cleanOtp = otp.trim();

    // 1. Web Flow via ConfirmationResult
    if (kIsWeb) {
      if (_webConfirmationResult == null) {
        return FirebasePhoneAuthResult.failure(
          'No active OTP verification session found on Web. Please tap "Resend OTP" to request a new code.',
        );
      }

      try {
        final userCredential = await _webConfirmationResult!.confirm(cleanOtp);
        final user = userCredential.user;

        if (user != null) {
          debugPrint('[FirebasePhoneAuth] Web OTP successfully verified for UID: ${user.uid}');
          return FirebasePhoneAuthResult.success(
            uid: user.uid,
            phoneNumber: user.phoneNumber ?? formattedPhone,
          );
        } else {
          return FirebasePhoneAuthResult.failure('Authentication failed. Please try again.');
        }
      } on FirebaseAuthException catch (e) {
        debugPrint('[FirebasePhoneAuth] Web OTP verification error: [${e.code}] ${e.message}');
        return FirebasePhoneAuthResult.failure(_mapFirebaseError(e));
      } catch (e) {
        debugPrint('[FirebasePhoneAuth] Web unexpected verification error: $e');
        return FirebasePhoneAuthResult.failure('Failed to verify OTP: $e');
      }
    }

    // 2. Native Flow (Android / iOS)
    // Check if device auto-retrieved and verified SMS instantly
    if (_autoVerifiedCredential != null) {
      try {
        final current = auth.currentUser;
        if (current != null) {
          return FirebasePhoneAuthResult.success(
            uid: current.uid,
            phoneNumber: current.phoneNumber ?? formattedPhone,
          );
        }
      } catch (_) {}
    }

    if (_verificationId == null || _verificationId!.isEmpty) {
      return FirebasePhoneAuthResult.failure(
        'No active OTP verification session found. Please tap "Resend OTP" to request a new code.',
      );
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: cleanOtp,
      );

      final userCredential = await auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        debugPrint('[FirebasePhoneAuth] Native OTP successfully verified for UID: ${user.uid}');
        return FirebasePhoneAuthResult.success(
          uid: user.uid,
          phoneNumber: user.phoneNumber ?? formattedPhone,
        );
      } else {
        return FirebasePhoneAuthResult.failure('Authentication failed. Please try again.');
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[FirebasePhoneAuth] Native OTP verification error: [${e.code}] ${e.message}');
      return FirebasePhoneAuthResult.failure(_mapFirebaseError(e));
    } catch (e) {
      debugPrint('[FirebasePhoneAuth] Unexpected verification error: $e');
      return FirebasePhoneAuthResult.failure('Failed to verify OTP: $e');
    }
  }

  /// Logs out of Firebase Auth
  Future<void> signOut() async {
    try {
      await auth.signOut();
      _verificationId = null;
      _webConfirmationResult = null;
      _resendToken = null;
      _activePhoneNumber = null;
      _autoVerifiedCredential = null;
    } catch (e) {
      debugPrint('[FirebasePhoneAuth] Sign out error: $e');
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'The mobile number format is invalid. Please check and try again.';
      case 'quota-exceeded':
        return 'Daily SMS quota reached. Please try again later or contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a few moments before trying again.';
      case 'invalid-verification-code':
        return 'Incorrect 6-digit OTP code. Please check the SMS and re-enter.';
      case 'session-expired':
        return 'The OTP code has expired. Please tap "Resend OTP" to get a new code.';
      case 'missing-verification-code':
        return 'Please enter the 6-digit verification code sent to your phone.';
      case 'network-request-failed':
        return 'Network connection issue. Please check your internet connection.';
      case 'app-not-authorized':
        return 'Firebase App not authorized. Ensure SHA-1 fingerprint / SafetyNet is configured in Firebase Console.';
      case 'captcha-check-failed':
        return 'To test on localhost with reCAPTCHA disabled, please register this number in Firebase Console: Authentication > Sign-in method > Phone > "Phone numbers for testing" with code 123456.';
      case 'invalid-app-credential':
        return 'reCAPTCHA verification could not be completed on this browser. For development on localhost, please add this number under Firebase Console > Authentication > Sign-in method > Phone > "Phone numbers for testing" with code 123456.';
      case 'operation-not-allowed':
        return 'Phone authentication is not enabled. Please enable Phone provider in Firebase Console under Authentication > Sign-in method.';
      default:
        return e.message ?? 'An error occurred during phone verification (${e.code}).';
    }
  }
}
