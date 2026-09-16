import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/worker_models.dart';
import '../../../../core/config/dependency_injection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WorkerEarningsScreen extends StatefulWidget {
  const WorkerEarningsScreen({super.key});

  @override
  State<WorkerEarningsScreen> createState() => _WorkerEarningsScreenState();
}

class _WorkerEarningsScreenState extends State<WorkerEarningsScreen> {
  int _selectedPeriod = 1; // 0: Today, 1: This Week, 2: This Month
  late Future<WorkerProfile?> _workerFuture;

  @override
  void initState() {
    super.initState();
    _loadWorker();
  }

  void _loadWorker() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      _workerFuture = DI.workerRepo.getWorkerProfile(user.id);
    } else {
      _workerFuture = Future.value(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WorkerProfile?>(
      future: _workerFuture,
      builder: (context, snapshot) {
        final worker = snapshot.data;
        final workerName = worker?.name ?? 'Rahul Patil';
        final guildId = worker?.guildId ?? '128';
        final earnings = worker?.earnings ?? 14280.0;
        final jobsCount = worker?.completedJobs ?? 18;

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FC),
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
                      color: Color(0xFF00875A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'PUNE GUILD #$guildId',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6C6C70),
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
                  color: Color(0xFF111111),
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
            color: const Color(0xFFF8F9FA),
            border: Border.all(color: const Color(0xFFE5E5EA)),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'म',
                  style: TextStyle(
                    color: Color(0xFF00875A),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
                TextSpan(
                  text: '/EN',
                  style: TextStyle(
                    color: Color(0xFF111111),
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
            color: const Color(0xFFF8F9FA),
            border: Border.all(color: const Color(0xFFE5E5EA)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.support_agent, color: Color(0xFF111111), size: 18),
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['Today', 'This Week', 'This Month'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFECEEF0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAEA)),
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
                  border: isSelected ? Border.all(color: const Color(0xFFE5E5EA)) : null,
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
                    color: isSelected ? const Color(0xFF111111) : const Color(0xFF6C6C70),
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
        border: Border.all(color: const Color(0xFFEAEAEA)),
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
                  Icon(Icons.account_balance_wallet, color: Color(0xFF5A38E4), size: 18),
                  SizedBox(width: 6),
                  Text(
                    'TOTAL WEEK PAYOUT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6C6C70),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified, size: 13, color: Color(0xFF027A48)),
                    SizedBox(width: 4),
                    Text(
                      'Instant Settled',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF027A48),
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
                  color: Color(0xFF111111),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '100% Payout',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF027A48),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.check_circle, size: 14, color: Color(0xFF027A48)),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Disbursed to Bank of Maharashtra (A/C **4892) via UPI',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6C6C70)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // 0% Commission Guarantee Ribbon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF0F0F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5A38E4).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.verified_user, color: Color(0xFF5A38E4), size: 18),
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
                              color: Color(0xFF111111),
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            '• Union Member',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF5A38E4),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pune Plumbers Guild returns 100% of fair customer fees directly to you.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF6C6C70)),
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
              _buildMetricCard('Avg. per Job', '₹793', '+6%', const Color(0xFF027A48)),
              _buildMetricCard('Total Active Hours', '26.5', 'hrs', null),
              _buildMetricCard('Platform Fee Deducted', '₹0', 'Free', const Color(0xFF027A48)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, String subtitle, Color? badgeColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEAEAEA)),
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
              color: Color(0xFF6C6C70),
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
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: badgeColor != null ? FontWeight.w800 : FontWeight.w600,
                  color: badgeColor ?? const Color(0xFF6C6C70),
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
        border: Border.all(color: const Color(0xFFEAEAEA)),
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
                      color: Color(0xFF111111),
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'Pune Fair Wage Index Benchmark: ₹1,500/day',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6C6C70)),
                  ),
                ],
              ),
              Row(
                children: [
                  CircleAvatar(radius: 4, backgroundColor: Color(0xFF5A38E4)),
                  SizedBox(width: 4),
                  Text(
                    'Fair Base',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF111111)),
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
                    color: const Color(0xFF5A38E4).withValues(alpha: 0.3),
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFEAEAEA)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Min ₹1,500',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF5A38E4),
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
            color: isPeak ? const Color(0xFF5A38E4) : const Color(0xFF6C6C70),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 24,
          height: 100 * heightPercent,
          decoration: BoxDecoration(
            color: isPeak
                ? const Color(0xFF5A38E4)
                : (isOff ? const Color(0xFFE1E2E5) : const Color(0xFF111111)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          day,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
            color: isPeak ? const Color(0xFF5A38E4) : (isOff ? const Color(0xFFA0A0A5) : const Color(0xFF111111)),
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
        border: Border.all(color: const Color(0xFFEAEAEA)),
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
                      Icon(Icons.verified, color: Color(0xFF027A48), size: 18),
                      SizedBox(width: 5),
                      Text(
                        'Partner Welfare & Protection',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111111),
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '$workerName • ShramSetu Member #$guildId',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6C6C70)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: const Text(
                  '100% Protected',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF027A48),
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
        color: const Color(0xFFF2F4F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEAEAEA)),
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
              border: Border.all(color: const Color(0xFFE5E5EA)),
            ),
            child: Icon(icon, color: const Color(0xFF111111), size: 18),
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
                        color: Color(0xFF111111),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF027A48),
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
                      color: Color(0xFF111111),
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6C6C70)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
