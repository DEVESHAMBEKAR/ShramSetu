abstract class IUserRepository {
  /// Create or update a user profile when they login for the first time
  Future<void> upsertUserProfile({
    required String userId,
    required String role,
    required String phone,
    String? fullName,
  });

  /// Get the role of the current user
  Future<String?> getUserRole(String userId);
}
