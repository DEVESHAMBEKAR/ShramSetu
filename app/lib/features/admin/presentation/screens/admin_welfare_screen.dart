import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../data/models/admin_models.dart';

class AdminWelfareScreen extends StatefulWidget {
  const AdminWelfareScreen({super.key});

  @override
  State<AdminWelfareScreen> createState() => _AdminWelfareScreenState();
}

class _AdminWelfareScreenState extends State<AdminWelfareScreen> {
  late Future<List<WelfareRecord>> _recordsFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _recordsFuture = DI.adminRepo.getWelfareRecords();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WelfareRecord>>(
      future: _recordsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ')));
        }
        
        final records = snapshot.data!;

        return Scaffold(
          backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Welfare & Benefits', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        itemCount: records.length,
        itemBuilder: (context, index) {
          final item = records[index];
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
                    color: item.type == 'Loan' ? AppColors.primary : AppColors.onTertiaryContainer,
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
                      Text('Status: ${item.status}', style: AppTypography.labelSm.copyWith(color: AppColors.statusTextColorFromString(item.status), fontWeight: FontWeight.w600)),
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
      );
  }
}
