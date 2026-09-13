import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/repositories/mock_admin_repository.dart';

class AdminWelfareScreen extends StatefulWidget {
  const AdminWelfareScreen({super.key});

  @override
  State<AdminWelfareScreen> createState() => _AdminWelfareScreenState();
}

class _AdminWelfareScreenState extends State<AdminWelfareScreen> {
  late MockAdminRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = MockAdminRepository();
  }

  @override
  Widget build(BuildContext context) {
    final welfares = _repository.welfareRecords;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Welfare & Benefits', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        itemCount: welfares.length,
        itemBuilder: (context, index) {
          final item = welfares[index];
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: AppRadius.radiusLg),
                  child: Icon(
                    item.type == 'Loan' ? Icons.account_balance : Icons.health_and_safety,
                    color: item.type == 'Loan' ? AppColors.primary : AppColors.tertiaryContainer,
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.title, style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
                      Text(item.details, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 4),
                      Text('Status: ${item.status}', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.outline),
                  onPressed: () {},
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
