import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/repositories/mock_admin_repository.dart';
import '../../data/models/admin_models.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
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
    final complaints = _repository.complaints;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Complaints & Support', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        itemCount: complaints.length,
        itemBuilder: (context, index) {
          final complaint = complaints[index];
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Case ${complaint.id}', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _getStatusColor(complaint.status), borderRadius: AppRadius.radiusSm),
                      child: Text(complaint.status.name.toUpperCase(), style: AppTypography.labelSm.copyWith(color: AppColors.onPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Text(complaint.subject, style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
                const SizedBox(height: 4),
                Text(complaint.description, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.spacingSm),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Text('Cust: ${complaint.customerName}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.engineering, size: 16, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Text('Wrkr: ${complaint.workerName}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                if (complaint.status != ComplaintStatus.resolved && complaint.status != ComplaintStatus.closed)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        _repository.updateComplaintStatus(complaint.id, ComplaintStatus.resolved);
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                      child: const Text('Mark Resolved'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(ComplaintStatus status) {
    switch (status) {
      case ComplaintStatus.open:
        return AppColors.error;
      case ComplaintStatus.inReview:
        return AppColors.secondary;
      case ComplaintStatus.resolved:
      case ComplaintStatus.closed:
        return AppColors.tertiaryFixed;
    }
  }
}
