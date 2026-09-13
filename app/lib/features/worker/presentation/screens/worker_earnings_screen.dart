import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/worker_models.dart';
import '../../data/repositories/mock_worker_repository.dart';

class WorkerEarningsScreen extends StatefulWidget {
  const WorkerEarningsScreen({super.key});

  @override
  State<WorkerEarningsScreen> createState() => _WorkerEarningsScreenState();
}

class _WorkerEarningsScreenState extends State<WorkerEarningsScreen> {
  late MockWorkerRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = MockWorkerRepository();
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
    final worker = _repository.currentWorker;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Worker Earnings', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          children: [
            _buildPeriodSelector(),
            const SizedBox(height: AppSpacing.spacingMd),
            _buildFinancialHighlightCard(worker),
            const SizedBox(height: AppSpacing.spacingMd),
            _buildDailyIncomeChart(),
            const SizedBox(height: AppSpacing.spacingMd),
            _buildWelfareFundSection(worker),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacing3xs),
      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusXl),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Text('Today', style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
            ),
          ),
          Expanded(
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusLg, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
              child: Text('This Week', style: AppTypography.labelMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: Container(
              height: 48,
              alignment: Alignment.center,
              child: Text('This Month', style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialHighlightCard(WorkerProfile worker) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingLg),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppColors.secondary, size: 20),
                  const SizedBox(width: AppSpacing.spacing2xs),
                  Text('TOTAL WEEK PAYOUT', style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant, letterSpacing: 1.2)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: 2),
                decoration: BoxDecoration(color: AppColors.onTertiaryContainer.withValues(alpha: 0.1), borderRadius: AppRadius.radiusFull),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.onTertiaryContainer, size: 14),
                    const SizedBox(width: 4),
                    Text('Instant Settled', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Text('₹${worker.earnings.toInt() + 12430}', style: AppTypography.displayLg.copyWith(color: AppColors.primary)),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.done_all, size: 16, color: AppColors.onTertiaryContainer),
              const SizedBox(width: 4),
              Expanded(child: Text('Disbursed to Bank of Maharashtra (A/C **4892) via UPI', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant))),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          Container(
            padding: const EdgeInsets.all(AppSpacing.spacingSm),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.verified_user, color: AppColors.secondary, size: 18),
                ),
                const SizedBox(width: AppSpacing.spacingXs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('0% Commission Cooperative Guarantee', style: AppTypography.labelMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      Text('${worker.guildName} returns 100% of fair customer fees.', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.spacingXs,
            crossAxisSpacing: AppSpacing.spacingXs,
            childAspectRatio: 2.2,
            children: [
              _buildMetricSquare('Completed Jobs', '${worker.completedJobs + 15}', 'Jobs', null),
              _buildMetricSquare('Avg. per Job', '₹793', '+6%', AppColors.onTertiaryContainer),
              _buildMetricSquare('Total Active Hours', '26.5', 'hrs', null),
              _buildMetricSquare('Platform Fee Deducted', '₹0', 'Free', AppColors.onTertiaryContainer),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricSquare(String title, String value, String subtitle, Color? subtitleColor) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: AppTypography.headlineSm.copyWith(color: subtitleColor != null && value == '₹0' ? subtitleColor : AppColors.primary, fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              Text(subtitle, style: AppTypography.labelSm.copyWith(color: subtitleColor ?? AppColors.onSurfaceVariant, fontWeight: subtitleColor != null ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyIncomeChart() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingLg),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Income Breakdown', style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
                  Text('Pune Fair Wage Index Benchmark: ₹1,500/day', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
              Row(
                children: [
                  Container(width: 12, height: 2, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Text('Fair Base', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingLg),
          SizedBox(
            height: 160,
            child: Stack(
              children: [
                Positioned(
                  top: 75,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1.5,
                    color: AppColors.secondary.withValues(alpha: 0.6),
                    alignment: Alignment.centerRight,
                    child: Container(
                      color: AppColors.surfaceContainerLowest,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('Min ₹1,500', style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 10)),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildChartBar('1.8k', 0.53, 'Mon'),
                    _buildChartBar('2.4k', 0.68, 'Tue'),
                    _buildChartBar('1.6k', 0.47, 'Wed'),
                    _buildChartBar('2.8k', 0.80, 'Thu'),
                    _buildChartBar('2.1k', 0.60, 'Fri'),
                    _buildChartBar('3.5k', 0.98, 'Sat', isPeak: true),
                    _buildChartBar('-', 0.05, 'Sun', isOff: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartBar(String val, double heightPercent, String day, {bool isPeak = false, bool isOff = false}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(val, style: AppTypography.labelSm.copyWith(color: isPeak ? AppColors.secondary : (isOff ? AppColors.onSurfaceVariant : AppColors.onSurfaceVariant), fontSize: 11, fontWeight: isPeak ? FontWeight.bold : FontWeight.normal)),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: 120 * heightPercent,
          decoration: BoxDecoration(
            color: isPeak ? AppColors.secondaryContainer : (isOff ? AppColors.surfaceVariant : AppColors.primaryContainer),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ),
        const SizedBox(height: 4),
        Text(day, style: AppTypography.labelSm.copyWith(color: isPeak ? AppColors.secondary : AppColors.onSurface, fontWeight: isPeak ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }

  Widget _buildWelfareFundSection(WorkerProfile worker) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingLg),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield, color: AppColors.onTertiaryContainer, size: 20),
                      const SizedBox(width: 4),
                      Text('Cooperative Welfare Fund', style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
                    ],
                  ),
                  Text('${worker.name} • Member ${worker.guildId}', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: 2),
                decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusSm),
                child: Text('100% Protected', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          _buildWelfareItem(Icons.health_and_safety, 'Accidental & Health Insurance', 'Active', '₹5,00,000', 'Full medical & life policy cover • Family included'),
          const SizedBox(height: AppSpacing.spacingXs),
          _buildWelfareItem(Icons.savings, 'Welfare Cess Accrued', '+₹428 this mo', null, 'Held securely in Pune Workers\' Collective Emergency Reserve.', titleColor: AppColors.primary, badgeColor: AppColors.primary),
          const SizedBox(height: AppSpacing.spacingXs),
          _buildWelfareItem(Icons.elderly, 'Micro-Pension (PMSYM)', 'Auto-Draft', null, '₹100/mo matched 1:1 by Central Union Subsidy.', badgeColor: AppColors.onTertiaryContainer),
          const SizedBox(height: AppSpacing.spacingXs),
          _buildWelfareItem(Icons.handyman, 'Tool & Equipment Loan', 'Eligible', 'Up to ₹20k', '0% interest cooperative loan for approved trade tools.', iconColor: AppColors.secondary, iconBgColor: AppColors.secondaryContainer.withValues(alpha: 0.15)),
        ],
      ),
    );
  }

  Widget _buildWelfareItem(IconData icon, String title, String badgeText, String? value, String desc, {Color? titleColor, Color? badgeColor, Color? iconColor, Color? iconBgColor}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBgColor ?? AppColors.surfaceContainerHighest, borderRadius: AppRadius.radiusLg),
            child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
          ),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: AppTypography.titleMd.copyWith(color: titleColor ?? AppColors.primary)),
                    Text(badgeText, style: AppTypography.labelSm.copyWith(color: badgeColor ?? AppColors.onTertiaryContainer, fontWeight: FontWeight.bold)),
                  ],
                ),
                if (value != null) ...[
                  const SizedBox(height: 2),
                  Text(value, style: AppTypography.currencyDisplay.copyWith(color: AppColors.primary, fontSize: 18)),
                ],
                const SizedBox(height: 2),
                Text(desc, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
