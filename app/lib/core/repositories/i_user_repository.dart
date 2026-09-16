import '../../features/customer/data/models/customer_profile.dart';

abstract class IUserRepository {
  /// Create or update a user profile when they login for the first time.
  /// NOTE: This method NEVER updates the role field after initial creation.
  Future<void> upsertUserProfile({
    required String userId,
    required String role,
    required String phone,
    String? fullName,
  });

  /// Get the role of the current user.
  Future<String?> getUserRole(String userId);

  // ───────────── Customer Profile Methods ─────────────

  /// Load the customer's full profile (including their default address if any).
  Future<CustomerProfile?> getCustomerProfile(String userId);

  /// Update mutable profile fields (full_name, avatar_url only).
  /// Role is never exposed here — prevents privilege escalation.
  Future<void> updateCustomerProfile({
    required String userId,
    required String fullName,
    String? avatarUrl,
  });

  /// Returns true if profile is considered complete:
  /// - full_name is set & not auto-generated placeholder
  /// - Customer has at least one address
  Future<bool> isProfileComplete(String userId);

  /// Create a new address for the customer.
  /// If this is their first address, is_default is forced to true.
  Future<CustomerAddress> createAddress({
    required String userId,
    required String addressLine,
    required String area,
    required String city,
    required String state,
    required String postalCode,
    String? label,
    double? latitude,
    double? longitude,
  });

  /// Get the customer's default address (returns null if none).
  Future<CustomerAddress?> getDefaultAddress(String userId);
}
