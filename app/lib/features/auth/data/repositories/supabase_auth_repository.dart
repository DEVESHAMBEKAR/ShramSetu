import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/i_auth_repository.dart';
import '../../../../core/config/dependency_injection.dart';

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

    final metaRole = (user.appMetadata['role'] ?? user.userMetadata?['role'])?.toString().toUpperCase();
    if (metaRole != null && metaRole.isNotEmpty) {
      return metaRole;
    }

    if (user.email != null && user.email!.isNotEmpty) {
      return 'ADMIN';
    }

    try {
      final data = await _client
          .from('users')
          .select('role')
          .eq('id', user.id)
          .single();
      return data['role'] as String?;
    } catch (e) {
      return null;
    }
  }

  String _normalizePhone(String phone) {
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 10) return '+91$clean';
    if (clean.startsWith('91') && clean.length == 12) return '+$clean';
    return phone.startsWith('+') ? phone : '+$clean';
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
    if (res.session != null) {
      try {
        await DI.notificationService.registerDeviceToken(userId: res.session!.user.id);
      } catch (_) {}
    }
    return true;
  }

  @override
  Future<void> logout() async {
    try {
      await DI.notificationService.deactivateCurrentToken();
    } catch (_) {}
    await _client.auth.signOut();
  }
}
