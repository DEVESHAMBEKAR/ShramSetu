import 'package:supabase_flutter/supabase_flutter.dart';

abstract class IAuthRepository {
  Future<void> sendOtp(String phone);
  Future<bool> verifyOtp(String phone, String otp);
  Future<bool> login(String email, String password);
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<String?> getUserRole();
  Stream<AuthState> get authStateChanges;
}
