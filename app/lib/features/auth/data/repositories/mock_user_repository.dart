import '../../../../core/repositories/i_user_repository.dart';
import '../../../../features/customer/data/models/customer_profile.dart';

class MockUserRepository implements IUserRepository {
  final Map<String, Map<String, dynamic>> _mockUsers = {};
  final Map<String, List<Map<String, dynamic>>> _mockAddresses = {};

  // Pre-seeded complete mock profile for mock mode
  static const _mockCompleteProfile = CustomerProfile(
    id: 'mock_customer_01',
    fullName: 'Priya Sharma',
    phone: '9876543210',
    avatarUrl: null,
    defaultAddress: CustomerAddress(
      id: 'mock_addr_01',
      addressLine: '45 Deccan Gymkhana Road',
      area: 'Deccan',
      city: 'Pune',
      state: 'Maharashtra',
      postalCode: '411004',
      isDefault: true,
    ),
  );

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
      'full_name': fullName ?? 'User ${phone.length >= 4 ? phone.substring(phone.length - 4) : phone}',
      'avatar_url': null,
    };
  }

  @override
  Future<CustomerProfile?> getCustomerProfile(String userId) async {
    final user = _mockUsers[userId];
    if (user == null) {
      // Return mock profile so the home screen works in dev mode
      return _mockCompleteProfile;
    }
    final addrs = _mockAddresses[userId] ?? [];
    CustomerAddress? defaultAddr;
    if (addrs.isNotEmpty) {
      final defRow = addrs.firstWhere(
        (a) => a['is_default'] == true,
        orElse: () => addrs.first,
      );
      defaultAddr = CustomerAddress.fromMap(defRow);
    }
    return CustomerProfile(
      id: userId,
      fullName: user['full_name'] as String? ?? '',
      phone: user['phone'] as String? ?? '',
      avatarUrl: user['avatar_url'] as String?,
      defaultAddress: defaultAddr,
    );
  }

  @override
  Future<void> updateCustomerProfile({
    required String userId,
    required String fullName,
    String? avatarUrl,
  }) async {
    _mockUsers[userId] = {
      ..._mockUsers[userId] ?? {},
      'full_name': fullName.trim(),
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }

  @override
  Future<bool> isProfileComplete(String userId) async {
    final profile = await getCustomerProfile(userId);
    return profile?.isComplete ?? false;
  }

  @override
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
  }) async {
    final isFirst = (_mockAddresses[userId] ?? []).isEmpty;
    final addr = {
      'id': 'mock_addr_${DateTime.now().millisecondsSinceEpoch}',
      'user_id': userId,
      'label': label ?? 'Home',
      'address_line': addressLine,
      'area': area,
      'city': city,
      'state': state,
      'postal_code': postalCode,
      'is_default': isFirst,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
    _mockAddresses[userId] = [...(_mockAddresses[userId] ?? []), addr];
    return CustomerAddress.fromMap(addr);
  }

  @override
  Future<CustomerAddress?> getDefaultAddress(String userId) async {
    final addrs = _mockAddresses[userId] ?? [];
    if (addrs.isEmpty) return null;
    final def = addrs.firstWhere(
      (a) => a['is_default'] == true,
      orElse: () => addrs.first,
    );
    return CustomerAddress.fromMap(def);
  }
}
