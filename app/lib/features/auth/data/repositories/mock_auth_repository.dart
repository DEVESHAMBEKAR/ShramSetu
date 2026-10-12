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
    final isTestOtp = otp == '123456' || RegExp(r'^(\d)\1{5}$').hasMatch(otp);

    if (isTestOtp) {
      _isLoggedIn = true;
      final userId = (cleanPhone == '9876543210')
          ? 'mock_customer_01'
          : (cleanPhone == '9823145890')
              ? 'mock_customer_02'
              : 'mock_user_$cleanPhone';

      _currentUser = User.fromJson(<String, dynamic>{
        'id': userId,
        'phone': phone,
        'aud': 'authenticated',
        'app_metadata': <String, dynamic>{'role': 'CUSTOMER'},
        'user_metadata': <String, dynamic>{'role': 'CUSTOMER'},
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
    final isValidEmail = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(cleanEmail);
    if (!isValidEmail || password.length < 6) {
      return false;
    }

    final isSuper = cleanEmail.contains('super');
    final role = isSuper ? 'SUPER_ADMIN' : 'ADMIN';
    _isLoggedIn = true;
    _mockRole = role;
    final adminId = 'admin_${cleanEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}';

    _currentUser = User.fromJson(<String, dynamic>{
      'id': adminId,
      'email': cleanEmail,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{'role': role},
      'user_metadata': <String, dynamic>{'role': role},
      'created_at': DateTime.now().toIso8601String(),
    });

    try {
      await DI.userRepo.upsertUserProfile(
        userId: adminId,
        role: role,
        phone: '+91 98765 00000',
        fullName: isSuper ? 'Super Administrator' : 'Admin (${cleanEmail.split('@').first})',
      );
    } catch (_) {}

    try {
      await DI.notificationService.registerDeviceToken(userId: adminId);
    } catch (_) {}
    return true;
  }

  @override
  Future<bool> signInWithGoogle({required String role}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _isLoggedIn = true;
    _mockRole = role.toUpperCase();
    final isWorker = role.toUpperCase() == 'WORKER';
    final mockEmail = isWorker ? 'ramesh.worker@gmail.com' : 'rajesh.customer@gmail.com';
    final mockName = isWorker ? 'Ramesh Kumar' : 'Rajesh Deshmukh';
    final userId = isWorker ? 'mock_worker_01' : 'mock_customer_01';

    _currentUser = User.fromJson(<String, dynamic>{
      'id': userId,
      'email': mockEmail,
      'aud': 'authenticated',
      'app_metadata': <String, dynamic>{'role': _mockRole, 'provider': 'google'},
      'user_metadata': <String, dynamic>{
        'role': _mockRole,
        'full_name': mockName,
        'email': mockEmail,
        'avatar_url': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&q=80&w=256',
      },
      'created_at': DateTime.now().toIso8601String(),
    });

    try {
      await DI.userRepo.upsertUserProfile(
        userId: userId,
        role: _mockRole,
        phone: isWorker ? '+91 98765 43210' : '+91 98220 12345',
        fullName: mockName,
      );
    } catch (_) {}

    try {
      await DI.notificationService.registerDeviceToken(userId: userId);
    } catch (_) {}

    return true;
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    // Mock password update
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
