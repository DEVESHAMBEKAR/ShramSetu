import '../../../../core/repositories/i_user_repository.dart';
import '../../../../features/customer/data/models/customer_profile.dart';

class MockUserRepository implements IUserRepository {
  final Map<String, Map<String, dynamic>> _mockUsers = {};
  final Map<String, List<Map<String, dynamic>>> _mockAddresses = {};

  MockUserRepository() {
    _seedDefaultMockData();
  }

  void _seedDefaultMockData() {
    // 1. Priya Sharma (9876543210)
    _mockUsers['mock_customer_01'] = {
      'id': 'mock_customer_01',
      'role': 'CUSTOMER',
      'phone': '9876543210',
      'full_name': 'Priya Sharma',
      'avatar_url': null,
    };
    _mockAddresses['mock_customer_01'] = [
      {
        'id': 'mock_addr_01',
        'user_id': 'mock_customer_01',
        'label': 'Home',
        'address_line': '45 Deccan Gymkhana Road',
        'area': 'Deccan',
        'city': 'Pune',
        'state': 'Maharashtra',
        'postal_code': '411004',
        'is_default': true,
        'latitude': 18.5173,
        'longitude': 73.8415,
      }
    ];

    // 2. Rajesh Patil (9823145890) - hint number in login screen
    _mockUsers['mock_customer_02'] = {
      'id': 'mock_customer_02',
      'role': 'CUSTOMER',
      'phone': '9823145890',
      'full_name': 'Rajesh Patil',
      'avatar_url': null,
    };
    _mockAddresses['mock_customer_02'] = [
      {
        'id': 'mock_addr_02',
        'user_id': 'mock_customer_02',
        'label': 'Home',
        'address_line': '12 Mayur Colony, Kothrud',
        'area': 'Kothrud',
        'city': 'Pune',
        'state': 'Maharashtra',
        'postal_code': '411038',
        'is_default': true,
        'latitude': 18.5074,
        'longitude': 73.8077,
      }
    ];

    // 3. Worker: Rahul Patil
    _mockUsers['mock_worker_01'] = {
      'id': 'mock_worker_01',
      'role': 'WORKER',
      'phone': '9800012345',
      'full_name': 'Rahul Patil',
      'avatar_url': null,
    };
    _mockUsers['mock-worker-id'] = _mockUsers['mock_worker_01']!;

    // 4. Admin: Federation Administrator
    _mockUsers['mock_admin_01'] = {
      'id': 'mock_admin_01',
      'role': 'ADMIN',
      'phone': '9811122233',
      'email': 'admin@shramsetu.in',
      'full_name': 'Devendra Ambdekar (Federation Admin)',
      'avatar_url': null,
    };
    _mockUsers['mock-admin-id'] = _mockUsers['mock_admin_01']!;
  }

  @override
  Future<String?> getUserRole(String userId) async {
    return _mockUsers[userId]?['role'] as String?;
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    if (_mockUsers.containsKey(userId)) {
      return _mockUsers[userId];
    }
    for (final entry in _mockUsers.entries) {
      if (entry.key == userId || entry.value['id'] == userId) {
        return entry.value;
      }
    }
    return null;
  }

  @override
  Future<void> upsertUserProfile({
    required String userId,
    required String role,
    required String phone,
    String? fullName,
  }) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    // Check if user exists by userId or phone
    String targetId = userId;
    Map<String, dynamic>? existing = _mockUsers[userId];
    if (existing == null) {
      for (final entry in _mockUsers.entries) {
        final p = (entry.value['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
        if (p == cleanPhone) {
          targetId = entry.key;
          existing = entry.value;
          break;
        }
      }
    }

    if (existing != null) {
      // User exists! Preserve their existing full_name if not explicitly provided
      final existingName = existing['full_name'] as String?;
      _mockUsers[targetId] = {
        ...existing,
        'phone': phone,
        if (fullName != null && fullName.isNotEmpty)
          'full_name': fullName
        else if (existingName == null || existingName.isEmpty)
          'full_name': 'User ${phone.length >= 4 ? phone.substring(phone.length - 4) : phone}',
      };
    } else {
      _mockUsers[userId] = {
        'id': userId,
        'role': role,
        'phone': phone,
        'full_name': fullName ?? 'User ${phone.length >= 4 ? phone.substring(phone.length - 4) : phone}',
        'avatar_url': null,
      };
    }
  }

  @override
  Future<CustomerProfile?> getCustomerProfile(String userId) async {
    Map<String, dynamic>? user = _mockUsers[userId];
    String targetId = userId;

    if (user == null) {
      // Check pre-seeded fallback
      if (userId == 'mock_customer_01' || userId == 'mock_user_id') {
        user = _mockUsers['mock_customer_01'];
        targetId = 'mock_customer_01';
      } else if (userId == 'mock_customer_02') {
        user = _mockUsers['mock_customer_02'];
        targetId = 'mock_customer_02';
      }
    }

    if (user == null) {
      return null;
    }

    final addrs = _mockAddresses[targetId] ?? [];
    CustomerAddress? defaultAddr;
    if (addrs.isNotEmpty) {
      final defRow = addrs.firstWhere(
        (a) => a['is_default'] == true,
        orElse: () => addrs.first,
      );
      defaultAddr = CustomerAddress.fromMap(defRow);
    }
    return CustomerProfile(
      id: targetId,
      fullName: user['full_name'] as String? ?? '',
      phone: user['phone'] as String? ?? '',
      avatarUrl: user['avatar_url'] as String?,
      defaultAddress: defaultAddr,
    );
  }

  @override
  Future<CustomerProfile?> getCustomerProfileByPhone(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    for (final entry in _mockUsers.entries) {
      final p = (entry.value['phone'] as String? ?? '').replaceAll(RegExp(r'\D'), '');
      if (p.endsWith(cleanPhone) || cleanPhone.endsWith(p)) {
        return getCustomerProfile(entry.key);
      }
    }
    return null;
  }

  @override
  Future<void> updateCustomerProfile({
    required String userId,
    required String fullName,
    String? avatarUrl,
  }) async {
    final user = _mockUsers[userId] ?? {};
    _mockUsers[userId] = {
      ...user,
      'id': userId,
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

  @override
  Future<List<CustomerAddress>> getUserAddresses(String userId) async {
    final addrs = _mockAddresses[userId] ?? [];
    return addrs.map((a) => CustomerAddress.fromMap(a)).toList();
  }

  @override
  Future<void> setDefaultAddress({required String userId, required String addressId}) async {
    final addrs = _mockAddresses[userId] ?? [];
    _mockAddresses[userId] = addrs.map((a) {
      final copy = Map<String, dynamic>.from(a);
      copy['is_default'] = (copy['id'] == addressId);
      return copy;
    }).toList();
  }

  @override
  Future<void> deleteAddress({required String userId, required String addressId}) async {
    final addrs = _mockAddresses[userId] ?? [];
    _mockAddresses[userId] = addrs.where((a) => a['id'] != addressId).toList();
  }

  @override
  Future<void> updateAddress({
    required String userId,
    required String addressId,
    required String addressLine,
    required String area,
    required String city,
    required String state,
    required String postalCode,
  }) async {
    final addrs = _mockAddresses[userId] ?? [];
    _mockAddresses[userId] = addrs.map((a) {
      if (a['id'] == addressId) {
        final copy = Map<String, dynamic>.from(a);
        copy['address_line'] = addressLine;
        copy['area'] = area;
        copy['city'] = city;
        copy['state'] = state;
        copy['postal_code'] = postalCode;
        return copy;
      }
      return a;
    }).toList();
  }
}
