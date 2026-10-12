import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';

/// Super Admin — Immutable Audit Log viewer.
/// Displays all administrative actions in chronological order.
/// Audit logs are read-only; they cannot be modified or deleted.
class SuperAdminAuditLogScreen extends StatefulWidget {
  const SuperAdminAuditLogScreen({super.key});

  @override
  State<SuperAdminAuditLogScreen> createState() => _SuperAdminAuditLogScreenState();
}

class _SuperAdminAuditLogScreenState extends State<SuperAdminAuditLogScreen> {
  bool _isLoading = false;
  final List<_AuditEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _isLoading = true);

    try {
      if (AppConfig.useMockData) {
        _entries.clear();
        _entries.addAll([
          const _AuditEntry(
            action: 'WORKER_APPROVE',
            actor: 'SUPER_ADMIN',
            entityType: 'WORKER',
            timestamp: 'Just now',
            icon: Icons.check_circle_outline,
            color: Colors.green,
            reason: 'Background verification approved, documents verified',
          ),
          const _AuditEntry(
            action: 'FEDERATION_CREATE',
            actor: 'SUPER_ADMIN',
            entityType: 'FEDERATION',
            timestamp: '2 hours ago',
            icon: Icons.corporate_fare,
            color: Colors.purpleAccent,
            reason: 'New district artisan cooperative enrolled',
          ),
          const _AuditEntry(
            action: 'SERVICE_ACTIVATE',
            actor: 'SUPER_ADMIN',
            entityType: 'SERVICE',
            timestamp: '1 day ago',
            icon: Icons.toggle_on_outlined,
            color: Colors.blue,
            reason: 'Electrical category made live in district',
          ),
        ]);
      } else {
        final client = Supabase.instance.client;
        final res = await client
            .from('audit_logs')
            .select()
            .order('created_at', ascending: false)
            .limit(100);

        _entries.clear();
        for (final row in res as List) {
          final action = (row['action'] as String?) ?? 'UNKNOWN_ACTION';
          final entityType = (row['entity_type'] as String?) ?? 'GENERAL';
          final actorRole = (row['actor_role'] as String?) ?? 'ADMIN';
          final reason = row['reason'] as String?;
          final createdAt = row['created_at'] != null
              ? DateTime.tryParse(row['created_at'].toString())
              : null;
          final timeStr = createdAt != null
              ? '${createdAt.day}/${createdAt.month} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}'
              : 'Recent';

          Color color = const Color(0xFF3B82F6);
          IconData icon = Icons.info_outline;

          if (action.contains('APPROVE') || action.contains('ACTIVATE')) {
            color = Colors.green;
            icon = Icons.check_circle_outline;
          } else if (action.contains('REJECT') || action.contains('DEACTIVATE') || action.contains('SUSPEND')) {
            color = Colors.redAccent;
            icon = Icons.cancel_outlined;
          } else if (action.contains('CHANGES') || action.contains('REVIEW')) {
            color = Colors.amber;
            icon = Icons.rate_review_outlined;
          } else if (action.contains('FEDERATION')) {
            color = Colors.purpleAccent;
            icon = Icons.corporate_fare;
          } else if (action.contains('TRANSFER')) {
            color = Colors.tealAccent;
            icon = Icons.swap_horiz;
          }

          _entries.add(_AuditEntry(
            action: action,
            actor: actorRole,
            entityType: entityType,
            timestamp: timeStr,
            icon: icon,
            color: color,
            reason: reason,
          ));
        }
      }
    } catch (e) {
      debugPrint('[SuperAdminAuditLog] Error loading logs: $e');
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.secondaryContainer))
          : _entries.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAuditLogs,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.marginMobile),
                    itemCount: _entries.length,
                    itemBuilder: (context, index) => _buildLogEntry(_entries[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: AppRadius.radiusMd,
            ),
            child: const Icon(Icons.history, color: Colors.white38, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            'Audit Log Ready',
            style: AppTypography.titleMd.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No audit entries recorded yet.\nAdministrative actions will be logged\nhere automatically.',
            style: AppTypography.bodyMd.copyWith(color: Colors.white38),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF111827),
              borderRadius: AppRadius.radiusSm,
              border: Border.all(color: const Color(0xFF1F2937)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, color: Colors.green.withValues(alpha: 0.7), size: 14),
                const SizedBox(width: 8),
                Text(
                  'Immutable • Append-only • RLS-protected',
                  style: AppTypography.labelSm.copyWith(
                    color: Colors.white38,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(_AuditEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: const Color(0xFF1F2937)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.15),
              borderRadius: AppRadius.radiusSm,
            ),
            child: Icon(entry.icon, color: entry.color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.action,
                  style: AppTypography.bodyMd.copyWith(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '${entry.actor} • ${entry.entityType}',
                  style: AppTypography.labelSm.copyWith(color: Colors.white38, fontSize: 10),
                ),
                if (entry.reason != null && entry.reason!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.reason!,
                    style: AppTypography.bodySm.copyWith(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          Text(
            entry.timestamp,
            style: AppTypography.labelSm.copyWith(color: Colors.white24, fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _AuditEntry {
  final String action;
  final String actor;
  final String entityType;
  final String timestamp;
  final IconData icon;
  final Color color;
  final String? reason;

  const _AuditEntry({
    required this.action,
    required this.actor,
    required this.entityType,
    required this.timestamp,
    required this.icon,
    required this.color,
    this.reason,
  });
}
