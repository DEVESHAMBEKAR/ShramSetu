import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/i_auth_repository.dart';

class MockAuthRepository implements IAuthRepository {
  bool _isLoggedIn = false;
  String _mockRole = 'CUSTOMER';

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty(); // Simple mock

  @override
  Future<User?> getCurrentUser() async {
    // Return a dummy user if needed, but for our mock flow, we just return null
    return null; 
  }

  @override
  Future<String?> getUserRole() async {
    return _isLoggedIn ? _mockRole : null;
  }

  @override
  Future<void> sendOtp(String phone) async {
    // Simulates sending OTP. Does nothing but wait slightly.
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<bool> verifyOtp(String phone, String otp) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (otp == '123456') {
      _isLoggedIn = true;
      return true;
    }
    return false;
  }

  @override
  Future<bool> login(String email, String password) async {
    if (email.contains('admin') && password == 'admin123') {
      _isLoggedIn = true;
      _mockRole = 'ADMIN';
      return true;
    }
    return false;
  }

  @override
  Future<void> logout() async {
    _isLoggedIn = false;
  }

  void setMockRole(String role) {
    _mockRole = role;
  }
}
