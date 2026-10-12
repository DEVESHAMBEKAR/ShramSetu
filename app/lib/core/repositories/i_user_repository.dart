import '../../features/customer/data/models/customer_profile.dart';

abstract class IUserRepository {
  /// Create or update a user profile when they login for the first time.
  /// NOTE: This method NEVER updates the role field after initial creation.
  Future<void> upsertUserProfile({
    required String userId,
    required String role,
    required String phone,
    String? fullName,
    String? federationId,
  });

  /// Get the role of the current user.
  Future<String?> getUserRole(String userId);

  /// Get the user profile record from the users table.
  Future<Map<String, dynamic>?> getUserProfile(String userId);

  // ───────────── Customer Profile Methods ─────────────

  /// Load the customer's full profile (including their default address and assigned federation).
  Future<CustomerProfile?> getCustomerProfile(String userId);

  /// Load the customer's full profile by phone number (useful during login lookup).
  Future<CustomerProfile?> getCustomerProfileByPhone(String phone);

  /// Update mutable profile fields (full_name, phone, email, avatar_url, federation_id).
  /// Role is never exposed here — prevents privilege escalation.
  Future<void> updateCustomerProfile({
    required String userId,
    required String fullName,
    String? phone,
    String? email,
    String? avatarUrl,
    String? federationId,
  });

  /// Assign or update customer federation based on their provided location.
  /// Resolves the corresponding cooperative federation and saves it to users table.
  Future<String?> assignCustomerFederation({
    required String userId,
    String? district,
    String? city,
    String? state,
    String? area,
    String? addressLine,
    String? federationId,
  });

  /// Returns true if profile is considered complete:
  /// - full_name is set & not auto-generated placeholder
  /// - Customer has at least one address
  Future<bool> isProfileComplete(String userId);

  /// Create a new address for the customer.
  /// Automatically resolves and assigns the cooperative federation from the address location.
  Future<CustomerAddress> createAddress({
    required String userId,
    required String addressLine,
    required String area,
    required String city,
    required String state,
    required String postalCode,
    String? district,
    String? federationId,
    String? label,
    double? latitude,
    double? longitude,
  });

  /// Get the customer's default address (returns null if none).
  Future<CustomerAddress?> getDefaultAddress(String userId);

  /// Get all saved addresses for a user.
  Future<List<CustomerAddress>> getUserAddresses(String userId);

  /// Set an address as the default address for the user.
  Future<void> setDefaultAddress({required String userId, required String addressId});

  /// Delete a saved address.
  Future<void> deleteAddress({required String userId, required String addressId});

  /// Update an existing address.
  Future<void> updateAddress({
    required String userId,
    required String addressId,
    required String addressLine,
    required String area,
    required String city,
    required String state,
    required String postalCode,
    String? district,
    String? federationId,
  });
}
