import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/repositories/mock_admin_repository.dart';
import '../../../worker/data/models/worker_models.dart';

class AdminWorkersScreen extends StatefulWidget {
  const AdminWorkersScreen({super.key});

  @override
  State<AdminWorkersScreen> createState() => _AdminWorkersScreenState();
}

class _AdminWorkersScreenState extends State<AdminWorkersScreen> {
  late MockAdminRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = MockAdminRepository();
    _repository.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final workers = _repository.workers;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Worker Management', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        itemCount: workers.length,
        itemBuilder: (context, index) {
          final worker = workers[index];
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: AppRadius.radiusXl),
                      child: const Icon(Icons.person, color: AppColors.outline),
                    ),
                    const SizedBox(width: AppSpacing.spacingSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(worker.name, style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: _getVerifBgColor(worker.verificationStatus), borderRadius: AppRadius.radiusSm),
                                child: Text(worker.verificationStatus.name.toUpperCase(), style: AppTypography.labelSm.copyWith(color: _getVerifTextColor(worker.verificationStatus))),
                              ),
                            ],
                          ),
                          Text(worker.skills.first, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                          Text('Guild: ${worker.guildId}', style: AppTypography.labelSm.copyWith(color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Completed Jobs: ${worker.completedJobs}', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.orange),
                        const SizedBox(width: 2),
                        Text(worker.rating.toString(), style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                if (worker.verificationStatus == VerificationStatus.pending)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _repository.rejectWorker(worker.id);
                          },
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                          child: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _repository.approveWorker(worker.id);
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getVerifBgColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.approved:
        return AppColors.tertiaryFixed;
      case VerificationStatus.pending:
        return AppColors.surfaceContainer;
      case VerificationStatus.rejected:
        return AppColors.errorContainer;
      default:
        return AppColors.surfaceContainer;
    }
  }

  Color _getVerifTextColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.approved:
        return AppColors.onTertiaryFixed;
      case VerificationStatus.pending:
        return AppColors.onSurfaceVariant;
      case VerificationStatus.rejected:
        return AppColors.onErrorContainer;
      default:
        return AppColors.onSurfaceVariant;
    }
  }
}
