import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/worker_models.dart';
import '../../../../core/models/payment_models.dart';
import '../../../../core/models/insurance_models.dart';
import '../../../../core/config/dependency_injection.dart';
import '../widgets/worker_top_app_bar_actions.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/localization/app_strings.dart';

class _EarningsData {
  final WorkerProfile worker;
  final List<PaymentModel> releasedPayments;
  final List<JobRequest> allBookings;
  final WorkerInsuranceModel? insurance;

  _EarningsData({
    required this.worker,
    required this.releasedPayments,
    required this.allBookings,
    this.insurance,
  });
}

class _SettledPayoutItem {
  final String id;
  final String bookingId;
  final String title;
  final String subtitle;
  final double amount;
  final DateTime date;

  const _SettledPayoutItem({
    required this.id,
    required this.bookingId,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.date,
  });
}

class WorkerEarningsScreen extends StatefulWidget {
  const WorkerEarningsScreen({super.key});

  @override
  State<WorkerEarningsScreen> createState() => _WorkerEarningsScreenState();
}

class _WorkerEarningsScreenState extends State<WorkerEarningsScreen> {
  int _selectedPeriod = 1; // 0: Today, 1: This Week, 2: This Month
  late Future<_EarningsData> _earningsDataFuture;
  StreamSubscription<List<JobRequest>>? _jobsSubscription;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _jobsSubscription = DI.workerRepo.watchWorkerBookings().listen(
      (_) {
        if (mounted) _refreshData();
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _jobsSubscription?.cancel();
    super.dispose();
  }

  void _refreshData() {
    setState(() {
      _earningsDataFuture = _loadData();
    });
  }

  Future<_EarningsData> _loadData() async {
    final user = await DI.authRepo.getCurrentUser();
    final workerId = (user != null && user.id.isNotEmpty) ? user.id : 'mock-worker-id';

    WorkerProfile worker;
    try {
      worker = await DI.workerRepo.getWorkerProfile(workerId);
    } catch (e) {
      debugPrint('[WorkerEarnings] getWorkerProfile fallback: $e');
      worker = WorkerProfile(
        id: workerId,
        name: 'Artisan Partner',
        profileImage: '',
        phone: user?.phone ?? '',
        skills: ['General Service'],
        experience: '2 Years',
        rating: 5.0,
        completedJobs: 0,
        earnings: 0.0,
        isVerified: true,
        verificationStatus: VerificationStatus.approved,
        isAvailable: true,
        serviceLocation: 'Pune',
        guildName: 'Pune Labour Collective Guild',
        guildId: '#101',
      );
    }

    List<PaymentModel> releasedPayments;
    try {
      releasedPayments = await DI.paymentRepo.getWorkerReleasedPayments(workerId);
    } catch (e) {
      debugPrint('[WorkerEarnings] getWorkerReleasedPayments fallback: $e');
      releasedPayments = [];
    }

    List<JobRequest> allBookings;
    try {
      allBookings = await DI.workerRepo.getWorkerBookings();
    } catch (e) {
      debugPrint('[WorkerEarnings] getWorkerBookings fallback: $e');
      allBookings = [];
    }

    WorkerInsuranceModel? insurance;
    try {
      insurance = await DI.workerRepo.getWorkerInsurance(workerId);
    } catch (e) {
      debugPrint('[WorkerEarnings] getWorkerInsurance fallback: $e');
    }

    return _EarningsData(
      worker: worker,
      releasedPayments: releasedPayments,
      allBookings: allBookings,
      insurance: insurance,
    );
  }

  String get _periodTitle {
    switch (_selectedPeriod) {
      case 0:
        return 'TODAY\'S PAYOUT'.tr();
      case 1:
        return 'TOTAL WEEK PAYOUT'.tr();
      case 2:
        return 'TOTAL MONTH PAYOUT'.tr();
      default:
        return 'TOTAL PAYOUT'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        return FutureBuilder<_EarningsData>(
      future: _earningsDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildAppBar('#101'),
            body: const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: _buildAppBar('#101'),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.spacingLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load earnings: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshData,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final worker = data.worker;
        final releasedPayments = data.releasedPayments;
        final allBookings = data.allBookings;
        final workerName = worker.name.isNotEmpty ? worker.name : 'Artisan';
        final guildId = worker.guildId.isNotEmpty ? worker.guildId : '101';

        // 1. Unify all completed / released items
        final List<_SettledPayoutItem> allSettledItems = [];
        final Set<String> processedBookingIds = {};

        // Primary: Authoritative released payments from escrow
        for (final p in releasedPayments) {
          final bookingRef = p.bookingId.length >= 6
              ? p.bookingId.substring(0, 6).toUpperCase()
              : p.bookingId.toUpperCase();

          final matchingBk = allBookings.where((b) => b.id == p.bookingId).firstOrNull;
          final serviceName = matchingBk?.serviceName;
          final subtitle = serviceName != null && serviceName.isNotEmpty
              ? 'Escrow Released • ${p.paymentMethod ?? "UPI"} • $serviceName'
              : 'Escrow Released • ${p.paymentMethod ?? "UPI"}';

          allSettledItems.add(_SettledPayoutItem(
            id: p.id,
            bookingId: p.bookingId,
            title: 'Job #$bookingRef',
            subtitle: subtitle,
            amount: p.amount,
            date: p.updatedAt,
          ));
          processedBookingIds.add(p.bookingId);
        }

        // Secondary: Include completed bookings not already in payments table
        for (final b in allBookings) {
          if (b.status == BookingStatus.completed && !processedBookingIds.contains(b.id)) {
            final bookingRef = b.id.length >= 6
                ? b.id.substring(0, 6).toUpperCase()
                : b.id.toUpperCase();
            final amount = b.totalAmount > 0 ? b.totalAmount : b.baseAmount;

            DateTime itemDate = DateTime.now();
            if (b.createdAt.toLowerCase() != 'recently' && b.createdAt.toLowerCase() != 'just now') {
              final parsed = DateTime.tryParse(b.createdAt);
              if (parsed != null) itemDate = parsed;
            }

            allSettledItems.add(_SettledPayoutItem(
              id: 'bk_${b.id}',
              bookingId: b.id,
              title: 'Job #$bookingRef',
              subtitle: 'Completed • Direct Settlement • ${b.serviceName}',
              amount: amount,
              date: itemDate,
            ));
            processedBookingIds.add(b.id);
          }
        }

        // Sort descending by date
        allSettledItems.sort((a, b) => b.date.compareTo(a.date));

        // 2. Filter by period (Today / This Week / This Month)
        final now = DateTime.now();
        final List<_SettledPayoutItem> periodItems = allSettledItems.where((item) {
          switch (_selectedPeriod) {
            case 0: // Today
              return item.date.year == now.year &&
                  item.date.month == now.month &&
                  item.date.day == now.day;
            case 1: // This Week (from Monday 00:00 to now)
              final daysSinceMonday = (now.weekday - DateTime.monday) % 7;
              final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceMonday));
              final endOfWeek = monday.add(const Duration(days: 7));
              return (item.date.isAfter(monday) || item.date.isAtSameMomentAs(monday)) &&
                  item.date.isBefore(endOfWeek);
            case 2: // This Month
              return item.date.year == now.year && item.date.month == now.month;
            default:
              return true;
          }
        }).toList();

        final double periodEarnings = periodItems.fold(0.0, (sum, i) => sum + i.amount);
        final int periodJobsCount = periodItems.length;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildAppBar(guildId, worker: worker),
          body: RefreshIndicator(
            onRefresh: () async => _refreshData(),
            color: AppColors.primary,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: AppSpacing.spacingSm,
              ),
              child: Column(
                children: [
                  _buildPeriodSelector(),
                  const SizedBox(height: 12),
                  _buildFinancialHighlightCard(
                    earnings: periodEarnings,
                    jobsCount: periodJobsCount,
                    worker: worker,
                  ),
                  const SizedBox(height: 12),
                  _buildRecentPayoutsSection(periodItems),
                  const SizedBox(height: 12),
                  _buildDailyIncomeChart(allSettledItems),
                  const SizedBox(height: 12),
                  _buildWelfareFundSection(
                    workerName: workerName,
                    guildId: guildId,
                    periodEarnings: periodEarnings,
                    insurance: data.insurance,
                    workerId: worker.id,
                  ),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PDF generation coming soon')),
                        );
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Column(
                        children: [
                          Text('Download Tax & Earnings Slip (PDF)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                          Text('GST & Union Welfare Compliant', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w400)),
                        ],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(String guildId, {WorkerProfile? worker}) {
    final guildDistrict = (worker?.district?.isNotEmpty == true ? worker!.district : "COOPERATIVE")!.toUpperCase();
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
                    '$guildDistrict GUILD #$guildId',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Text(
                'Worker Earnings'.tr(),
                style: const TextStyle(
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
        WorkerTopAppBarActions(
          worker: worker,
          showAvatar: false,
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    final periods = ['Today'.tr(), 'This Week'.tr(), 'This Month'.tr()];
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

  Widget _buildFinancialHighlightCard({
    required double earnings,
    required int jobsCount,
    required WorkerProfile worker,
  }) {
    final phoneDigits = worker.phone.replaceAll(RegExp(r'\D'), '');
    final lastDigits = phoneDigits.length >= 4
        ? phoneDigits.substring(phoneDigits.length - 4)
        : '4892';

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
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: AppColors.secondary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    _periodTitle,
                    style: const TextStyle(
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
                  color: earnings > 0 ? AppColors.tertiaryContainer : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: earnings > 0 ? AppColors.tertiaryFixed : AppColors.outlineVariant,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      earnings > 0 ? Icons.verified : Icons.schedule,
                      size: 13,
                      color: earnings > 0 ? AppColors.onTertiaryContainer : AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      earnings > 0 ? 'Instant Settled' : 'Ready to Earn',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: earnings > 0 ? AppColors.onTertiaryContainer : AppColors.onSurfaceVariant,
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
                '₹${earnings.toStringAsFixed(0)}',
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
                  color: earnings > 0 ? AppColors.tertiaryContainer : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  earnings > 0 ? '100% Payout' : '0% Payout',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: earnings > 0 ? AppColors.onTertiaryContainer : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                earnings > 0 ? Icons.check_circle : Icons.info_outline,
                size: 14,
                color: earnings > 0 ? AppColors.onTertiaryContainer : AppColors.outline,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  earnings > 0
                      ? 'Disbursed to Bank of Maharashtra (A/C **$lastDigits) via UPI'
                      : 'No payouts settled for this period • Auto-settled via UPI on escrow release',
                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            '0% Commission Guarantee',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• ${worker.trade != null && worker.trade!.isNotEmpty ? worker.trade! : "Union Member"}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.secondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${worker.guildName.isNotEmpty ? worker.guildName : "Pune Plumbers Guild"} returns 100% of fair customer fees directly to you.',
                        style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
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
              _buildMetricCard('Completed Jobs'.tr(), '$jobsCount', 'Jobs'.tr(), null),
              _buildMetricCard(
                'Avg. per Job'.tr(),
                jobsCount > 0 ? '₹${(earnings / jobsCount).toStringAsFixed(0)}' : '₹0',
                jobsCount > 0 ? 'avg' : 'none',
                AppColors.onTertiaryContainer,
              ),
              _buildMetricCard(
                'Total Active Hours'.tr(),
                jobsCount > 0 ? (jobsCount * 1.5).toStringAsFixed(1) : '0.0',
                'hrs',
                null,
              ),
              _buildMetricCard('Platform Fee'.tr(), '₹0', '0%', AppColors.onTertiaryContainer),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPayoutsSection(List<_SettledPayoutItem> items) {
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
              Text(
                'Recent Settled Payouts'.tr(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: items.isNotEmpty ? AppColors.tertiaryContainer : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length} ${'Settled'.tr()}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: items.isNotEmpty ? AppColors.onTertiaryContainer : AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 36, color: AppColors.outline),
                  const SizedBox(height: 8),
                  Text(
                    'No released payouts yet'.tr(),
                    style: const TextStyle(
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
              itemCount: items.length,
              separatorBuilder: (_, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final item = items[index];
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
                            item.title,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            item.subtitle,
                            style: const TextStyle(fontSize: 10, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '₹${item.amount.toStringAsFixed(0)}',
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

  Widget _buildDailyIncomeChart(List<_SettledPayoutItem> allItems) {
    final now = DateTime.now();
    final daysSinceMonday = (now.weekday - DateTime.monday) % 7;
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: daysSinceMonday));

    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final List<double> dayTotals = List.filled(7, 0.0);

    for (int i = 0; i < 7; i++) {
      final targetDate = monday.add(Duration(days: i));
      for (final item in allItems) {
        if (item.date.year == targetDate.year &&
            item.date.month == targetDate.month &&
            item.date.day == targetDate.day) {
          dayTotals[i] += item.amount;
        }
      }
    }

    final double maxDay = dayTotals.reduce((a, b) => a > b ? a : b);
    const double benchmark = 1500.0;
    final double scaleBasis = max(maxDay, benchmark);

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Income Breakdown'.tr(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Text(
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
                  children: List.generate(7, (i) {
                    final val = dayTotals[i];
                    final isOff = val <= 0;
                    final isPeak = val > 0 && val == maxDay;
                    final heightPercent = isOff ? 0.06 : (val / scaleBasis).clamp(0.12, 1.0);
                    final label = isOff
                        ? '-'
                        : (val >= 1000
                            ? '${(val / 1000).toStringAsFixed(1)}k'
                            : '₹${val.toInt()}');
                    return _buildChartBar(
                      label,
                      heightPercent,
                      dayNames[i],
                      isPeak: isPeak,
                      isOff: isOff,
                    );
                  }),
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
          day.tr(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: isPeak ? FontWeight.w800 : FontWeight.w600,
            color: isPeak ? AppColors.secondary : (isOff ? AppColors.outline : AppColors.primary),
          ),
        ),
      ],
    );
  }

  Widget _buildWelfareFundSection({
    required String workerName,
    required String guildId,
    required double periodEarnings,
    required String workerId,
    WorkerInsuranceModel? insurance,
  }) {
    final int cessAccrued = (periodEarnings * 0.02).round();
    final String cessBadge = cessAccrued > 0 ? '+₹$cessAccrued this mo' : '₹0 this mo';

    final bool isApproved = insurance?.isApproved ?? false;
    final bool isPending = insurance?.isPendingApproval ?? false;
    final bool isNotApplied = insurance == null || insurance.isNotApplied;

    const headerBadgeBg = AppColors.tertiaryContainer;
    const headerBadgeBorder = AppColors.tertiaryFixed;
    const headerBadgeText = AppColors.onTertiaryContainer;
    const headerBadgeLabel = '100% Protected';

    final coverageAmountFormatted = '₹${(insurance?.coverageAmount ?? 500000.0).toStringAsFixed(0)}';
    final policyMasked = insurance?.maskedPolicyNumber ?? 'Pending Issuance';
    final provider = insurance?.providerName ?? 'Maharashtra State Cooperative Labour Federation Welfare Pool';

    String bannerText;
    IconData bannerIcon;
    Color bannerIconColor;
    if (isApproved) {
      bannerText = 'External insurance provider integration pending. Group coverage active via Federation Welfare Fund.';
      bannerIcon = Icons.verified_user_outlined;
      bannerIconColor = AppColors.onTertiaryContainer;
    } else if (isPending) {
      bannerText = 'Group insurance application submitted. Awaiting Federation Admin approval and policy issuance.';
      bannerIcon = Icons.hourglass_top_rounded;
      bannerIconColor = AppColors.onWarningContainer;
    } else {
      bannerText = 'Artisan group welfare insurance available. Submit your application below to get covered up to ₹5,00,000.';
      bannerIcon = Icons.info_outline;
      bannerIconColor = AppColors.secondary;
    }

    String insuranceCardBadge;
    String insuranceCardDesc;
    if (isApproved) {
      insuranceCardBadge = 'Active Policy';
      insuranceCardDesc = '$provider\nPolicy: $policyMasked • Helpline: ${insurance?.claimSupportPhone ?? "1800-266-9090"}';
    } else if (isPending) {
      insuranceCardBadge = 'Pending Approval';
      insuranceCardDesc = '$provider\nPolicy: Awaiting Admin Issuance • Application Status: Under Verification';
    } else {
      insuranceCardBadge = 'Not Applied';
      insuranceCardDesc = '$provider\n100% Federation sponsored medical and accident cover for registered artisans.';
    }

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
                  Row(
                    children: [
                      const Icon(Icons.verified, color: AppColors.onTertiaryContainer, size: 18),
                      const SizedBox(width: 5),
                      Text(
                        'Partner Welfare & Protection'.tr(),
                        style: const TextStyle(
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
                  color: headerBadgeBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: headerBadgeBorder),
                ),
                child: Text(
                  headerBadgeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: headerBadgeText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // External Provider Integration / Status Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(bannerIcon, size: 14, color: bannerIconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    bannerText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          _buildWelfareCard(
            icon: Icons.health_and_safety,
            iconColor: isApproved ? const Color(0xFF0284C7) : (isPending ? const Color(0xFFE65100) : const Color(0xFF6B7280)),
            iconBgColor: isApproved ? const Color(0xFFE0F2FE) : (isPending ? const Color(0xFFFFF3E0) : const Color(0xFFF3F4F6)),
            title: insurance?.coverageType ?? 'Accidental & Health Insurance',
            badge: insuranceCardBadge,
            amount: coverageAmountFormatted,
            desc: insuranceCardDesc,
          ),
          if (isNotApplied) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _handleApplyForInsurance(workerId),
                icon: const Icon(Icons.security, size: 16),
                label: const Text(
                  'Apply for ₹5,00,000 Group Insurance',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          _buildWelfareCard(
            icon: Icons.savings,
            iconColor: const Color(0xFFB45309),
            iconBgColor: const Color(0xFFFEF3C7),
            title: 'Welfare Cess Accrued',
            badge: cessBadge,
            desc: 'Held securely in Cooperative Labour Federation Emergency Reserve.'.tr(),
          ),
          const SizedBox(height: 8),
          _buildWelfareCard(
            icon: Icons.elderly,
            iconColor: const Color(0xFF6D28D9),
            iconBgColor: const Color(0xFFEDE9FE),
            title: 'Micro-Pension (PMSYM)',
            badge: 'Auto-Draft',
            desc: '₹100/mo matched 1:1 by Central Union Subsidy.',
          ),
          const SizedBox(height: 8),
          _buildWelfareCard(
            icon: Icons.handyman,
            iconColor: const Color(0xFFAC3400),
            iconBgColor: const Color(0xFFFFEDD5),
            title: 'Tool Upgrade Loan',
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
    required Color iconColor,
    required Color iconBgColor,
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
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
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

  Future<void> _handleApplyForInsurance(String workerId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Apply for Welfare Insurance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enroll in the Maharashtra State Cooperative Labour Federation Group Insurance Plan:',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.check, size: 16, color: Color(0xFF2E7D32)),
                      SizedBox(width: 8),
                      Expanded(child: Text('₹5,00,000 Accidental & Hospitalization Cover', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.check, size: 16, color: Color(0xFF2E7D32)),
                      SizedBox(width: 8),
                      Expanded(child: Text('100% Federation Funded (Zero Premium)', style: TextStyle(fontSize: 12))),
                    ],
                  ),
                  SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.check, size: 16, color: Color(0xFF2E7D32)),
                      SizedBox(width: 8),
                      Expanded(child: Text('24x7 Emergency Claim Helpline 1800-266-9090', style: TextStyle(fontSize: 12))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your application will be sent to the Federation Admin for verification and official policy number assignment.',
              style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Submit Application'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DI.workerRepo.applyForInsurance(workerId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF2E7D32),
              content: Text('✓ Insurance application submitted! Pending Federation Admin approval.'),
            ),
          );
          _refreshData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.error,
              content: Text('Failed to submit application: $e'),
            ),
          );
        }
      }
    }
  }
}

