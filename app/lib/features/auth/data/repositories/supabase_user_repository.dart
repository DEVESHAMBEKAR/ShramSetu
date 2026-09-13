import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/i_user_repository.dart';

class SupabaseUserRepository implements IUserRepository {
  final SupabaseClient _client;

  SupabaseUserRepository(this._client);

  @override
  Future<String?> getUserRole(String userId) async {
    try {
      final response = await _client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      
      if (response != null) {
        return response['role'] as String?;
      }
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
    // Upsert into users table
    await _client.from('users').upsert({
      'id': userId,
      'role': role,
      'phone': phone,
      'full_name': fullName ?? 'User ${phone.substring(phone.length - 4)}',
      'updated_at': DateTime.now().toIso8601String(),
    });

    // If role is WORKER, ensure a worker profile exists
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
}
