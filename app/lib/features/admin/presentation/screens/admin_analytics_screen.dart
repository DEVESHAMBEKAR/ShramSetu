import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Platform Analytics', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Growth Overview', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
            const SizedBox(height: AppSpacing.spacingSm),
            _buildChartMock('Monthly Bookings', AppColors.primaryContainer),
            const SizedBox(height: AppSpacing.spacingLg),
            Text('Revenue & Escrow', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
            const SizedBox(height: AppSpacing.spacingSm),
            _buildChartMock('Escrow Volume (Lakhs)', AppColors.secondaryFixedDim),
          ],
        ),
      ),
    );
  }

  Widget _buildChartMock(String title, Color bgColor) {
    return Container(
      width: double.infinity,
      height: 200,
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
          const Spacer(),
          Container(
            width: double.infinity,
            height: 120,
            decoration: BoxDecoration(color: bgColor, borderRadius: AppRadius.radiusLg),
            alignment: Alignment.center,
            child: const Icon(Icons.bar_chart, size: 64, color: Colors.black26),
          ),
        ],
      ),
    );
  }
}
