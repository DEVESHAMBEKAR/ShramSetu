import '../../../../core/repositories/i_user_repository.dart';

class MockUserRepository implements IUserRepository {
  final Map<String, Map<String, dynamic>> _mockUsers = {};

  @override
  Future<String?> getUserRole(String userId) async {
    return _mockUsers[userId]?['role'] as String?;
  }

  @override
  Future<void> upsertUserProfile({
    required String userId,
    required String role,
    required String phone,
    String? fullName,
  }) async {
    _mockUsers[userId] = {
      'id': userId,
      'role': role,
      'phone': phone,
      'full_name': fullName ?? 'User ${phone.substring(phone.length - 4)}',
    };
  }
}
