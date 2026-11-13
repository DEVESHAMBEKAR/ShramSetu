import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/repositories/i_auth_repository.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/services/firebase_phone_auth_service.dart';
import '../../../../core/utils/phone_number_util.dart';

class SupabaseAuthRepository implements IAuthRepository {
  final SupabaseClient _client;
  User? _cachedBridgeUser;
  String? _cachedBridgePhone;

  SupabaseAuthRepository(this._client);

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<User?> getCurrentUser() async {
    final sbUser = _client.auth.currentUser;
    if (sbUser != null) return sbUser;

    if (AppConfig.isFirebaseOtpEnabled && FirebasePhoneAuthService.instance.isAvailable) {
      try {
        final fbUser = FirebasePhoneAuthService.instance.auth.currentUser;
        if (fbUser != null) {
          final phone = fbUser.phoneNumber ?? FirebasePhoneAuthService.instance.activePhoneNumber ?? '';
          if (_cachedBridgeUser != null && _cachedBridgePhone == phone) {
            return _cachedBridgeUser;
          }

          String effectiveId = fbUser.uid;
          String? resolvedRole;

          // Resolve Supabase user ID and role from public.users using all phone formats
          final clean = PhoneNumberUtil.cleanIndianPhone(phone);
          if (clean.isNotEmpty) {
            try {
              final userRow = await _client
                  .from('users')
                  .select('id, role')
                  .or('phone.eq.$clean,phone.eq.+91$clean,phone.eq.91$clean')
                  .maybeSingle();
              if (userRow != null && userRow['id'] != null) {
                effectiveId = userRow['id'] as String;
                resolvedRole = userRow['role']?.toString().trim().toUpperCase();
              }
            } catch (_) {}
          }

          final bridgeUser = User(
            id: effectiveId,
            appMetadata: {
              'provider': 'phone',
              if (resolvedRole != null && resolvedRole.isNotEmpty) 'role': resolvedRole,
            },
            userMetadata: {
              'phone': phone,
              if (resolvedRole != null && resolvedRole.isNotEmpty) 'role': resolvedRole,
            },
            aud: 'authenticated',
            phone: phone,
            createdAt: DateTime.now().toIso8601String(),
          );
          _cachedBridgeUser = bridgeUser;
          _cachedBridgePhone = phone;
          return bridgeUser;
        }
      } catch (e) {
        debugPrint('[AuthRepo] Firebase getCurrentUser bridge note: $e');
      }
    }

    return null;
  }

  @override
  Future<String?> getUserRole() async {
    final user = await getCurrentUser();
    if (user == null) return null;

    // 1. Authoritative check in public.users table by user.id
    try {
      final data = await _client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      if (data != null && data['role'] != null) {
        final dbRole = data['role'].toString().trim().toUpperCase();
        if (dbRole.isNotEmpty) return dbRole;
      }
    } catch (_) {}

    // 2. Authoritative check in public.users table by phone number (all Indian phone formats)
    if (user.phone != null && user.phone!.isNotEmpty) {
      try {
        final clean = PhoneNumberUtil.cleanIndianPhone(user.phone!);
        if (clean.isNotEmpty) {
          final data = await _client
              .from('users')
              .select('role')
              .or('phone.eq.$clean,phone.eq.+91$clean,phone.eq.91$clean')
              .maybeSingle();
          if (data != null && data['role'] != null) {
            final dbRole = data['role'].toString().trim().toUpperCase();
            if (dbRole.isNotEmpty) return dbRole;
          }
        }
      } catch (_) {}
    }

    // 3. Auth session metadata fallback
    final metaRole = (user.appMetadata['role'] ?? user.userMetadata?['role'])?.toString().toUpperCase();
    if (metaRole != null && metaRole.isNotEmpty) {
      return metaRole;
    }

    // 4. Known admin email fallback
    final email = user.email?.toLowerCase() ?? '';
    if (email == 'admin@shramsetu.in' || email.contains('admin@')) {
      return 'ADMIN';
    }

    return null;
  }

  String _normalizePhone(String phone) {
    final clean = PhoneNumberUtil.cleanIndianPhone(phone);
    if (clean.length == 10) return '+91$clean';
    return phone.startsWith('+') ? phone : '+$phone';
  }

  @override
  Future<void> sendOtp(String phone) async {
    final formattedPhone = _normalizePhone(phone);
    if (AppConfig.isFirebaseOtpEnabled && FirebasePhoneAuthService.instance.isAvailable) {
      debugPrint('[AuthRepo] Sending SMS OTP via Firebase Phone Auth for $formattedPhone...');
      await FirebasePhoneAuthService.instance.sendOtp(formattedPhone);
    } else {
      debugPrint('[AuthRepo] Sending SMS OTP via Supabase Auth for $formattedPhone...');
      await _client.auth.signInWithOtp(phone: formattedPhone);
    }
  }

  @override
  Future<bool> verifyOtp(String phone, String otp) async {
    final formattedPhone = _normalizePhone(phone);

    if (AppConfig.isFirebaseOtpEnabled && FirebasePhoneAuthService.instance.isAvailable) {
      debugPrint('[AuthRepo] Verifying OTP via Firebase Phone Auth...');
      _cachedBridgeUser = null;
      _cachedBridgePhone = null;
      final fbResult = await FirebasePhoneAuthService.instance.verifyOtp(formattedPhone, otp);
      if (!fbResult.isSuccess) {
        throw Exception(fbResult.errorMessage ?? 'Invalid OTP code.');
      }

      // Sync verified phone with Supabase backend in background without failing valid OTP
      try {
        await _syncFirebaseUserWithSupabase(formattedPhone, fbResult.uid);
      } catch (e) {
        debugPrint('[AuthRepo] Supabase bridge sync note: $e');
      }

      return true;
    }

    try {
      final response = await _client.auth.verifyOTP(
        phone: formattedPhone,
        token: otp,
        type: OtpType.sms,
      );
      if (response.session != null || response.user != null || _client.auth.currentUser != null) {
        final uid = response.session?.user.id ?? response.user?.id ?? _client.auth.currentUser?.id;
        if (uid != null) {
          try {
            await DI.notificationService.registerDeviceToken(userId: uid);
          } catch (_) {}
        }
        return true;
      }
    } catch (e) {
      debugPrint('[AuthRepo] Supabase verifyOTP note: $e');
      rethrow;
    }

    return false;
  }

  /// Establishes or syncs an authenticated Supabase user session after Firebase verifies the phone OTP.
  /// Ensures full compatibility with Supabase Row Level Security (RLS) and public.users profile records.
  Future<bool> _syncFirebaseUserWithSupabase(String formattedPhone, String? firebaseUid) async {
    final cleanDigits = formattedPhone.replaceAll(RegExp(r'\D'), '');
    final authEmail = 'phone_$cleanDigits@shramsetu.internal';
    final authPassword = 'ShramSetu_PhoneAuth_${cleanDigits}_SecureSalt';

    try {
      // 1. Try signing in with existing user account
      final res = await _client.auth.signInWithPassword(
        email: authEmail,
        password: authPassword,
      );
      if (res.session != null) {
        try {
          await DI.notificationService.registerDeviceToken(userId: res.session!.user.id);
        } catch (_) {}
        return true;
      }
    } catch (_) {
      // 2. First-time login: create Supabase account for this phone number
      try {
        final signUpRes = await _client.auth.signUp(
          email: authEmail,
          password: authPassword,
          data: {
            'phone': formattedPhone,
            'firebase_uid': firebaseUid ?? '',
            'auth_method': 'FIREBASE_PHONE_OTP',
          },
        );
        final uid = signUpRes.session?.user.id ?? signUpRes.user?.id ?? _client.auth.currentUser?.id;
        if (uid != null) {
          try {
            await DI.notificationService.registerDeviceToken(userId: uid);
          } catch (_) {}
        }
        return true;
      } catch (e) {
        debugPrint('[AuthRepo] Supabase bridge signUp note: $e');
      }
    }

    // 3. Fallback: if Supabase already has an active session, succeed
    if (_client.auth.currentUser != null) {
      return true;
    }

    return false;
  }

  @override
  Future<bool> login(String email, String password) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    DI.federationScopeService?.clearCache();
    if (res.session != null) {
      try {
        await DI.notificationService.registerDeviceToken(userId: res.session!.user.id);
      } catch (_) {}
    }
    return true;
  }

  @override
  Future<bool> signInWithGoogle({required String role}) async {
    try {
      final normalizedRole = role.toUpperCase();
      final redirectUrl = kIsWeb
          ? '${Uri.base.origin}/?auth_role=$normalizedRole'
          : 'io.supabase.shramsetu://login-callback/?auth_role=$normalizedRole';
      final authUrlRes = await _client.auth.getOAuthSignInUrl(
        provider: OAuthProvider.google,
        redirectTo: redirectUrl,
      );

      // Preflight check: prevent browser redirecting to a raw 400 error page if provider is disabled in Supabase
      try {
        final preflight = await http.get(
          Uri.parse(authUrlRes.url),
          headers: _client.headers,
        );
        if (preflight.statusCode == 400 && preflight.body.contains('provider is not enabled')) {
          final callbackUrl = '${authUrlRes.url.split('/auth/v1/').first}/auth/v1/callback';
          throw Exception(
            'Google Sign-In is not enabled in your Supabase backend yet.\n\n'
            'To enable Google Sign-In in Supabase:\n'
            '1. Open Supabase Dashboard > Authentication > Providers > Google\n'
            '2. Turn ON "Enable Sign in with Google"\n'
            '3. Fill in your Google Client ID & Client Secret\n'
            '4. In Google Cloud Console, add callback URL:\n'
            '   $callbackUrl',
          );
        }
      } catch (e) {
        if (e.toString().contains('Google Sign-In is not enabled')) {
          rethrow;
        }
      }

      final success = await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectUrl,
        queryParams: {'prompt': 'select_account'},
      );
      DI.federationScopeService?.clearCache();
      return success;
    } catch (e) {
      debugPrint('[AuthRepo] Supabase signInWithGoogle note: $e');
      rethrow;
    }
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    await _client.auth.updateUser(
      UserAttributes(
        password: newPassword,
        data: {'requires_password_change': false},
      ),
    );
    final user = _client.auth.currentUser;
    if (user != null) {
      try {
        await _client.from('users').update({
          'requires_password_change': false,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', user.id);
      } catch (_) {}
    }
  }

  @override
  Future<void> logout() async {
    _cachedBridgeUser = null;
    _cachedBridgePhone = null;
    DI.federationScopeService?.clearCache();
    try {
      await DI.notificationService.deactivateCurrentToken();
    } catch (_) {}
    await FirebasePhoneAuthService.instance.signOut();
    await _client.auth.signOut();
  }
}
