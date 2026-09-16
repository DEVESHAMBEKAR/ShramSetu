import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/worker_models.dart';
import '../../../../core/models/payment_models.dart';
import '../../../../core/config/dependency_injection.dart';

class WorkerEarningsScreen extends StatefulWidget {
  const WorkerEarningsScreen({super.key});

  @override
  State<WorkerEarningsScreen> createState() => _WorkerEarningsScreenState();
}

class _WorkerEarningsScreenState extends State<WorkerEarningsScreen> {
  int _selectedPeriod = 1; // 0: Today, 1: This Week, 2: This Month
  late Future<WorkerProfile?> _workerFuture;
  late Future<List<PaymentModel>> _paymentsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _workerFuture = () async {
      final user = await DI.authRepo.getCurrentUser();
      final workerId = user?.id ?? 'worker-1';
      return DI.workerRepo.getWorkerProfile(workerId);
    }();
    _paymentsFuture = () async {
      final user = await DI.authRepo.getCurrentUser();
      final workerId = user?.id ?? 'worker-1';
      return DI.paymentRepo.getWorkerReleasedPayments(workerId);
    }();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WorkerProfile?>(
      future: _workerFuture,
      builder: (context, workerSnapshot) {
        return FutureBuilder<List<PaymentModel>>(
          future: _paymentsFuture,
          builder: (context, paymentsSnapshot) {
            final worker = workerSnapshot.data;
            final releasedPayments = paymentsSnapshot.data ?? [];
            final workerName = worker?.name ?? 'Artisan';
            final guildId = worker?.guildId ?? '101';

            // Calculate actual released earnings from payments
            final double releasedTotal = releasedPayments.fold(
              0.0,
              (sum, p) => sum + p.amount,
            );
            final earnings = releasedTotal > 0 ? releasedTotal : (worker?.earnings ?? 0.0);
            final jobsCount = releasedPayments.isNotEmpty ? releasedPayments.length : (worker?.completedJobs ?? 0);

            return Scaffold(
              backgroundColor: AppColors.background,
              appBar: _buildAppBar(guildId),
              body: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                  vertical: AppSpacing.spacingSm,
                ),
                child: Column(
                  children: [
                    _buildPeriodSelector(),
                    const SizedBox(height: 12),
                    _buildFinancialHighlightCard(earnings, jobsCount),
                    const SizedBox(height: 12),
                    _buildRecentPayoutsSection(releasedPayments),
                    const SizedBox(height: 12),
                    _buildDailyIncomeChart(),
                    const SizedBox(height: 12),
                    _buildWelfareFundSection(workerName, guildId),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(String guildId) {
    return AppBar(
      backgroundColor: Colors.white.withValues(alpha: 0.95),
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      titleSpacing: AppSpacing.marginMobile,
      title: Row(
        children: [
          Image.asset('assets/images/logo.jpg', height: 32, width: 32, fit: BoxFit.contain),
          const SizedBox(width: AppSpacing.spacingXs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.onTertiaryContainer,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'PUNE GUILD #$guildId',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const Text(
                'Worker Earnings',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'म',
                  style: TextStyle(
                    color: AppColors.onTertiaryContainer,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                TextSpan(
                  text: '/EN',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(right: AppSpacing.marginMobile),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.support_agent, color: AppColors.primary, size: 18),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['Today', 'This Week', 'This Month'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: List.generate(periods.length, (index) {
          final isSelected = _selectedPeriod == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  border: isSelected ? Border.all(color: AppColors.outlineVariant) : null,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          )
                        ]
                      : null,
                ),
                child: Text(
                  periods[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFinancialHighlightCard(double earnings, int jobsCount) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              const Row(
                children: [
                  Icon(Icons.account_balance_wallet, color: AppColors.secondary, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'TOTAL WEEK PAYOUT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.tertiaryFixed),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 13, color: AppColors.onTertiaryContainer),
                    SizedBox(width: 4),
                    Text(
                      'Instant Settled',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₹${earnings.toInt() > 0 ? earnings.toInt() : 14280}',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '100% Payout',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.check_circle, size: 14, color: AppColors.onTertiaryContainer),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Disbursed to Bank of Maharashtra (A/C **4892) via UPI',
                  style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 0% Commission Guarantee Ribbon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user, color: AppColors.secondary, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '0% Commission Guarantee',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            '• Union Member',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pune Plumbers Guild returns 100% of fair customer fees directly to you.',
                        style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 2x2 Grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.1,
            children: [
              _buildMetricCard('Completed Jobs', '$jobsCount', 'Jobs', null),
              _buildMetricCard(
                'Avg. per Job',
                jobsCount > 0 ? '₹${(earnings / jobsCount).toStringAsFixed(0)}' : '₹0',
                jobsCount > 0 ? 'avg' : 'none',
                AppColors.onTertiaryContainer,
              ),
              _buildMetricCard(
                'Total Active Hours',
                jobsCount > 0 ? (jobsCount * 1.5).toStringAsFixed(1) : '0.0',
                'hrs',
                null,
              ),
              _buildMetricCard('Platform Fee Deducted', '₹0', '0%', AppColors.onTertiaryContainer),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPayoutsSection(List<PaymentModel> payments) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
              const Text(
                'Recent Released Payouts',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${payments.length} Settled',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (payments.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: const Column(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 36, color: AppColors.outline),
                  SizedBox(height: 8),
                  Text(
                    'No released payouts yet',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Earnings from completed jobs are deposited directly here once customer releases escrow.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: payments.length,
              separatorBuilder: (_, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final payment = payments[index];
                final bookingRef = payment.bookingId.length >= 6
                    ? payment.bookingId.substring(0, 6).toUpperCase()
                    : payment.bookingId.toUpperCase();
                return Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.check_circle_outline, size: 18, color: AppColors.onTertiaryContainer),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Job #$bookingRef',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            'Escrow Released • ${payment.paymentMethod}',
                            style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${payment.amount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onTertiaryContainer,
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, Color? badgeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: badgeColor != null ? FontWeight.w800 : FontWeight.w600,
                  color: badgeColor ?? AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDailyIncomeChart() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Income Breakdown',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'Pune Fair Wage Index Benchmark: ₹1,500/day',
                    style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: AppColors.secondary),
                  SizedBox(width: 4),
                  Text(
                    'Fair Base',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 150,
            child: Stack(
              children: [
                // Benchmark Reference Line (1500)
                Positioned(
                  top: 75,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1.5,
                    color: AppColors.secondary.withValues(alpha: 0.3),
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppColors.outlineVariant),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Min ₹1,500',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.secondary,
                        ),
                      ),
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
                    _buildChartBar('-', 0.06, 'Sun', isOff: true),
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
        Text(
          val,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
            color: isPeak ? AppColors.secondary : AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: 100 * heightPercent,
          decoration: BoxDecoration(
            color: isPeak
                ? AppColors.secondary
                : (isOff ? AppColors.outlineVariant : AppColors.primary),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
            color: isPeak ? AppColors.secondary : (isOff ? AppColors.outline : AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildWelfareFundSection(String workerName, String guildId) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.verified, color: AppColors.onTertiaryContainer, size: 18),
                      SizedBox(width: 5),
                      Text(
                        'Partner Welfare & Protection',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$workerName • ShramSetu Member #$guildId',
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.tertiaryFixed),
                ),
                child: const Text(
                  '100% Protected',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWelfareCard(
            icon: Icons.health_and_safety,
            title: 'Accidental & Health Insurance',
            badge: 'Active',
            amount: '₹5,00,000',
            desc: 'Full medical & life policy cover • Family included',
          ),
          const SizedBox(height: 8),
          _buildWelfareCard(
            icon: Icons.savings,
            title: 'Welfare Cess Accrued',
            badge: '+₹428 this mo',
            desc: 'Held securely in Pune Workers\' Collective Emergency Reserve.',
          ),
          const SizedBox(height: 8),
          _buildWelfareCard(
            icon: Icons.elderly,
            title: 'Micro-Pension (PMSYM)',
            badge: 'Auto-Draft',
            desc: '₹100/mo matched 1:1 by Central Union Subsidy.',
          ),
          const SizedBox(height: 8),
          _buildWelfareCard(
            icon: Icons.handyman,
            title: 'Tool & Equipment Loan',
            badge: 'Eligible',
            amount: 'Up to ₹20k',
            desc: '0% interest cooperative loan for approved trade tools.',
          ),
        ],
      ),
    );
  }

  Widget _buildWelfareCard({
    required IconData icon,
    required String title,
    required String badge,
    String? amount,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onTertiaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
                if (amount != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    amount,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
