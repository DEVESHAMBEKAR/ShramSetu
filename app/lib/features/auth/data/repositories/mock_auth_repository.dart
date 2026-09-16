import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/i_auth_repository.dart';
import '../../../../core/config/dependency_injection.dart';

class MockAuthRepository implements IAuthRepository {
  bool _isLoggedIn = false;
  String _mockRole = 'CUSTOMER';
  User? _currentUser;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty(); // Simple mock

  @override
  Future<User?> getCurrentUser() async {
    return _isLoggedIn ? _currentUser : null;
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
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final userId = (cleanPhone == '9876543210')
          ? 'mock_customer_01'
          : (cleanPhone == '9823145890')
              ? 'mock_customer_02'
              : 'mock_cust_$cleanPhone';

      _currentUser = User.fromJson(<String, dynamic>{
        'id': userId,
        'phone': phone,
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
        'created_at': DateTime.now().toIso8601String(),
      });

      try {
        await DI.notificationService.registerDeviceToken(userId: userId);
      } catch (_) {}
      return true;
    }
    return false;
  }

  @override
  Future<bool> login(String email, String password) async {
    if (email.contains('admin') && password == 'admin123') {
      _isLoggedIn = true;
      _mockRole = 'ADMIN';
      try {
        await DI.notificationService.registerDeviceToken(userId: 'mock_admin_123');
      } catch (_) {}
      return true;
    }
    return false;
  }

  @override
  Future<void> logout() async {
    _isLoggedIn = false;
    _currentUser = null;
    try {
      await DI.notificationService.deactivateCurrentToken();
    } catch (_) {}
  }

  void setMockRole(String role) {
    _mockRole = role;
  }
}
