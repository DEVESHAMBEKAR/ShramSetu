import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/i_user_repository.dart';
import '../../../../features/customer/data/models/customer_profile.dart';

class SupabaseUserRepository implements IUserRepository {
  final SupabaseClient _client;

  SupabaseUserRepository(this._client);

  // ─────────────────────── Core Auth Methods ───────────────────────

  @override
  Future<String?> getUserRole(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      if (response != null) return response['role'] as String?;
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> upsertUserProfile({
    required String userId,
    required String role,
    required String phone,
    String? fullName,
  }) async {
    // On upsert, if name is not provided we use phone last-4 as placeholder.
    // This placeholder is later replaced during onboarding.
    await _client.from('users').upsert({
      'id': userId,
      'role': role,
      'phone': phone,
      'full_name': fullName ?? 'User ${phone.length >= 4 ? phone.substring(phone.length - 4) : phone}',
      'updated_at': DateTime.now().toIso8601String(),
    });

    // If role is WORKER, ensure a worker profile row exists.
    if (role == 'WORKER') {
      final workerExists = await _client
          .from('workers')
          .select('id')
          .eq('id', userId)
          .maybeSingle();

      if (workerExists == null) {
        await _client.from('workers').insert({
          'id': userId,
          'worker_status': 'PENDING_VERIFICATION',
        });
      }
    }
  }

  // ─────────────────────── Customer Profile Methods ───────────────────────

  @override
  Future<CustomerProfile?> getCustomerProfile(String userId) async {
    try {
      final userRow = await _client
          .from('users')
          .select('id, full_name, phone, avatar_url')
          .eq('id', userId)
          .maybeSingle();

      if (userRow == null) return null;

      final defaultAddr = await getDefaultAddress(userId);

      return CustomerProfile.fromMap(userRow, defaultAddress: defaultAddr);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> updateCustomerProfile({
    required String userId,
    required String fullName,
    String? avatarUrl,
  }) async {
    // IMPORTANT: 'role' is deliberately NOT included here.
    // This prevents a customer from escalating their own privileges.
    final updates = <String, dynamic>{
      'full_name': fullName.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (avatarUrl != null) {
      updates['avatar_url'] = avatarUrl;
    }
    await _client.from('users').update(updates).eq('id', userId);
  }

  @override
  Future<bool> isProfileComplete(String userId) async {
    try {
      final profile = await getCustomerProfile(userId);
      if (profile == null) return false;
      return profile.isComplete;
    } catch (e) {
      return false;
    }
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
  }) async {
    // Determine if this is the first address — if so, make it default.
    final existing = await _client
        .from('addresses')
        .select('id')
        .eq('user_id', userId)
        .limit(1);

    final isFirst = (existing as List).isEmpty;

    // If making this default AND another default already exists,
    // clear the old default first (safe upsert strategy).
    if (!isFirst) {
      // We only set default for first address in onboarding.
      // For now, first address is always default.
    }

    final row = await _client.from('addresses').insert({
      'user_id': userId,
      'label': label ?? 'Home',
      'address_line': addressLine.trim(),
      'area': area.trim(),
      'city': city.trim(),
      'state': state.trim(),
      'postal_code': postalCode.trim(),
      'is_default': isFirst,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).select().single();

    return CustomerAddress.fromMap(row);
  }

  @override
  Future<CustomerAddress?> getDefaultAddress(String userId) async {
    try {
      final row = await _client
          .from('addresses')
          .select()
          .eq('user_id', userId)
          .eq('is_default', true)
          .maybeSingle();

      // Fallback: if no default set, grab the most recent address
      if (row == null) {
        final fallback = await _client
            .from('addresses')
            .select()
            .eq('user_id', userId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (fallback == null) return null;
        return CustomerAddress.fromMap(fallback);
      }

      return CustomerAddress.fromMap(row);
    } catch (e) {
      return null;
    }
  }
}
