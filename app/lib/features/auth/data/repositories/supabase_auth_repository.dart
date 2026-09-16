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

  @override
  Future<void> sendOtp(String phone) async {
    final formattedPhone = '+91$phone'; // Assuming India (+91)
    await _client.auth.signInWithOtp(phone: formattedPhone);
  }

  @override
  Future<bool> verifyOtp(String phone, String otp) async {
    final formattedPhone = '+91$phone';
    final response = await _client.auth.verifyOTP(
      phone: formattedPhone,
      token: otp,
      type: OtpType.sms,
    );
    if (response.session != null) {
      try {
        await DI.notificationService.registerDeviceToken(userId: response.session!.user.id);
      } catch (_) {}
    }
    return response.session != null;
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
