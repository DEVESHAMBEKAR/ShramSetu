import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// AuditLogService — records immutable administrative actions into the
/// `audit_logs` table. All entries are append-only; no updates or deletes.
///
/// Usage:
///   await AuditLogService.log(
///     action: 'APPROVE_WORKER',
///     entityType: 'WORKER',
///     entityId: workerId,
///     newValue: {'worker_status': 'ACTIVE'},
///     reason: 'Background verified, trade skills confirmed',
///   );
class AuditLogService {
  static SupabaseClient? _client;

  /// Initialize with a Supabase client. Called from DI.setup().
  static void initialize(SupabaseClient client) {
    _client = client;
  }

  /// Log an administrative action. This is fire-and-forget — it will not
  /// throw errors to the caller since audit logging should never block
  /// the primary admin action.
  static Future<void> log({
    required String action,
    required String entityType,
    String? entityId,
    String? federationId,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String? reason,
  }) async {
    if (_client == null) {
      debugPrint('[AuditLog] Client not initialized. Skipping audit log for: $action');
      return;
    }

    try {
      final currentUser = _client!.auth.currentUser;
      final userId = currentUser?.id;

      // Get the actor's role
      String? actorRole;
      if (userId != null) {
        try {
          final userRes = await _client!
              .from('users')
              .select('role')
              .eq('id', userId)
              .maybeSingle();
          actorRole = userRes?['role'] as String?;
        } catch (_) {}
      }

      await _client!.from('audit_logs').insert({
        'actor_id': userId,
        'actor_role': actorRole,
        'action': action,
        'entity_type': entityType,
        if (entityId != null) 'entity_id': entityId,
        if (federationId != null) 'federation_id': federationId,
        if (oldValue != null) 'old_value': oldValue,
        if (newValue != null) 'new_value': newValue,
        if (reason != null) 'reason': reason,
      });

      debugPrint('[AuditLog] Logged: $action on $entityType${entityId != null ? ' ($entityId)' : ''}');
    } catch (e) {
      // Audit logging must never block admin operations
      debugPrint('[AuditLog] Failed to log $action: $e');
    }
  }

  /// Convenience methods for common admin actions
  static Future<void> logWorkerVerification({
    required String workerId,
    required String action,
    required String previousStatus,
    required String newStatus,
    String? remarks,
  }) async {
    await log(
      action: 'WORKER_$action',
      entityType: 'WORKER',
      entityId: workerId,
      oldValue: {'worker_status': previousStatus},
      newValue: {'worker_status': newStatus},
      reason: remarks,
    );
  }

  static Future<void> logFederationAction({
    required String action,
    required String federationId,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
    String? reason,
  }) async {
    await log(
      action: 'FEDERATION_$action',
      entityType: 'FEDERATION',
      entityId: federationId,
      federationId: federationId,
      oldValue: oldValue,
      newValue: newValue,
      reason: reason,
    );
  }

  static Future<void> logServiceToggle({
    required String serviceId,
    required bool newActive,
  }) async {
    await log(
      action: newActive ? 'SERVICE_ACTIVATE' : 'SERVICE_DEACTIVATE',
      entityType: 'SERVICE',
      entityId: serviceId,
      newValue: {'is_active': newActive},
    );
  }

  static Future<void> logComplaintAction({
    required String complaintId,
    required String newStatus,
  }) async {
    await log(
      action: 'COMPLAINT_$newStatus',
      entityType: 'COMPLAINT',
      entityId: complaintId,
      newValue: {'status': newStatus},
    );
  }
}
