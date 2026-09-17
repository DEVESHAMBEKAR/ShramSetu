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
    if (!_isLoggedIn) return null;
    if (_currentUser != null) {
      try {
        final role = await DI.userRepo.getUserRole(_currentUser!.id);
        if (role != null) return role;
      } catch (_) {}
    }
    return _mockRole;
  }

  @override
  Future<void> sendOtp(String phone) async {
    // Simulates sending OTP. Does nothing but wait slightly.
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<bool> verifyOtp(String phone, String otp) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final isTestOtp = otp == '123456' ||
        otp == '111111' ||
        cleanPhone == '8421296499' ||
        cleanPhone == '9876543210' ||
        cleanPhone == '9823145890' ||
        RegExp(r'^(\d)\1{5}$').hasMatch(otp);

    if (isTestOtp) {
      _isLoggedIn = true;
      final userId = (cleanPhone == '8421296499')
          ? 'f3af7b05-79f8-43e7-a0ea-7bde1c218b72'
          : (cleanPhone == '9876543210')
              ? 'mock_customer_01'
              : (cleanPhone == '9823145890')
                  ? 'mock_customer_02'
                  : 'mock_user_$cleanPhone';

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
    final cleanEmail = email.trim().toLowerCase();
    // Allow standard admin demo, developer/admin email (ambekardevesh2@gmail.com), or any valid non-empty email
    final isAllowed = cleanEmail.isNotEmpty && password.isNotEmpty;

    if (isAllowed) {
      _isLoggedIn = true;
      _mockRole = 'ADMIN';
      final adminId = 'admin_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

      _currentUser = User.fromJson(<String, dynamic>{
        'id': adminId,
        'email': cleanEmail,
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{'role': 'ADMIN'},
        'created_at': DateTime.now().toIso8601String(),
      });

      try {
        await DI.userRepo.upsertUserProfile(
          userId: adminId,
          role: 'ADMIN',
          phone: '+91 98765 00000',
          fullName: 'Admin (${cleanEmail.split('@').first})',
        );
      } catch (_) {}

      try {
        await DI.notificationService.registerDeviceToken(userId: adminId);
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
