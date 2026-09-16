import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import 'admin_demand_forecast_screen.dart';

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
            // AI Demand Forecasting Entry Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.spacingMd),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.radiusXl,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryFixed,
                          borderRadius: AppRadius.radiusSm,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, size: 12, color: AppColors.secondary),
                            const SizedBox(width: 4),
                            Text('COOP RESEARCH AI', style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const Icon(Icons.show_chart, color: Colors.white, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('AI Demand Forecasting', style: AppTypography.titleLg.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Evaluate historical trade demand, inspect 7-day Holt-Winters projections, and identify potential cooperative supply deficits.',
                    style: AppTypography.bodySm.copyWith(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminDemandForecastScreen()),
                        );
                      },
                      icon: const Icon(Icons.analytics_outlined, size: 16),
                      label: const Text('Launch Demand Forecasting Hub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spacingLg),

            // Cooperative AI & Research Intelligence Section
            Text('Cooperative AI & Research Intelligence', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
            const SizedBox(height: 4),
            Text('Traceable algorithms and active marketplace inference engines.', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
            const SizedBox(height: AppSpacing.spacingSm),

            // 1. FairMatch Model Card
            _buildFairMatchModelCard(),
            const SizedBox(height: 12),

            // 2. Demand Forecasting Model Card
            _buildDemandForecastModelCard(),
            const SizedBox(height: AppSpacing.spacingLg),

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

  Widget _buildFairMatchModelCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFixed,
                      borderRadius: AppRadius.radiusMd,
                    ),
                    child: const Icon(Icons.hub_outlined, size: 16, color: AppColors.secondary),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('FairMatch Engine', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      Text('Operational Matching • Model fairmatch_v1', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: AppRadius.radiusSm,
                ),
                child: Text('SERVING ACTIVE', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Linear multi-factor objective function balancing verified skill, client proximity, punctuality, and equitable workload distribution.',
            style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildFactorChip('Skill', '35%'),
              _buildFactorChip('Distance', '20%'),
              _buildFactorChip('Availability', '15%'),
              _buildFactorChip('Rating', '10%'),
              _buildFactorChip('Experience', '10%'),
              _buildFactorChip('Fairness', '10%'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.check_circle_outline, size: 12, color: AppColors.secondary),
              const SizedBox(width: 4),
              Text('Sum strictly 1.0 • Deterministic lexicographical tie-break • Logged in fairmatch_logs', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemandForecastModelCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius: AppRadius.radiusMd,
                    ),
                    child: const Icon(Icons.timeline_outlined, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Demand Forecasting', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      Text('Administrative Planning • Model demand_forecast_v1', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: AppRadius.radiusSm,
                ),
                child: Text('ADVISORY ONLY', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Holt-Winters Additive Exponential Smoothing (Level α, Trend β, 7-day Seasonality γ) evaluated against Naive, 7D Moving Average, and Seasonal Naive baselines.',
            style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildFactorChip('Horizon', '7 Days'),
              _buildFactorChip('Seasonality', 'L = 7 (Weekly)'),
              _buildFactorChip('Baselines', '3 Comparative'),
              _buildFactorChip('Supply Gap', 'Active Analyzer'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 12, color: AppColors.outline),
              const SizedBox(width: 4),
              Text('Strict boundary: Zero automatic worker assignment or price/wage modification', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFactorChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.radiusSm,
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
          Text(value, style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }
}
