import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/i_auth_repository.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/utils/phone_number_util.dart';

class SupabaseAuthRepository implements IAuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  Future<User?> getCurrentUser() async {
    return _client.auth.currentUser;
  }

  @override
  Future<String?> getUserRole() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    // 1. Authoritative check in public.users table
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

    // 2. Auth session metadata fallback
    final metaRole = (user.appMetadata['role'] ?? user.userMetadata?['role'])?.toString().toUpperCase();
    if (metaRole != null && metaRole.isNotEmpty) {
      return metaRole;
    }

    // 3. Known admin email fallback
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
    await _client.auth.signInWithOtp(phone: formattedPhone);
  }

  @override
  Future<bool> verifyOtp(String phone, String otp) async {
    final formattedPhone = _normalizePhone(phone);
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
    DI.federationScopeService?.clearCache();
    try {
      await DI.notificationService.deactivateCurrentToken();
    } catch (_) {}
    await _client.auth.signOut();
  }
}
