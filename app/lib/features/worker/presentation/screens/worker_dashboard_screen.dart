import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/worker_models.dart';
import '../../../../core/config/dependency_injection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'worker_job_detail_screen.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({super.key});

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  late Future<List<dynamic>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      final currentUser = Supabase.instance.client.auth.currentUser;
      final userId = currentUser?.id ?? 'mock-worker-id';
      _dataFuture = Future.wait([
        DI.workerRepo.getWorkerProfile(userId),
        DI.workerRepo.getWorkerBookings(),
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8F9FA),
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FA),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.spacingLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text('Failed to load dashboard: ${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
                  ],
                ),
              ),
            ),
          );
        }

        final worker = snapshot.data![0] as WorkerProfile;
        final allBookings = snapshot.data![1] as List<JobRequest>;

        final activeRequests = allBookings
            .where((j) => j.status == BookingStatus.pending)
            .toList();
        final completedJobs = allBookings
            .where((j) => j.status == BookingStatus.completed)
            .toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FA),
          appBar: _buildAppBar(worker),
          body: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              _refreshData();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: AppSpacing.spacingSm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIdentityAndDutyCard(worker),
                  const SizedBox(height: AppSpacing.spacingMd),
                  if (activeRequests.isNotEmpty && worker.isAvailable) ...[
                    _buildUrgentJobAlertCard(activeRequests.first),
                    const SizedBox(height: AppSpacing.spacingMd),
                  ],
                  _buildPerformanceGrid(worker),
                  const SizedBox(height: AppSpacing.spacingMd),
                  _buildCompletedSchedule(completedJobs),
                  const SizedBox(height: AppSpacing.spacingMd),
                  _buildWelfareBanner(),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(WorkerProfile worker) {
    return AppBar(
      backgroundColor: Colors.white.withValues(alpha: 0.96),
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      titleSpacing: AppSpacing.marginMobile,
      title: Row(
        children: [
          Image.asset(
            'assets/images/logo.jpg',
            height: 32,
            width: 32,
            fit: BoxFit.contain,
          ),
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
                    '${worker.guildName.toUpperCase()} #${worker.guildId}',
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
                'Partner Hub',
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
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            border: Border.all(color: const Color(0xFFE5E5EA)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.support_agent,
            color: Color(0xFF111111),
            size: 18,
          ),
        ),
        Container(
          width: 34,
          height: 34,
          margin: const EdgeInsets.only(right: AppSpacing.marginMobile),
          decoration: const BoxDecoration(
            color: Color(0xFF111111),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            worker.name.isNotEmpty
                ? worker.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
                : 'PT',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIdentityAndDutyCard(WorkerProfile worker) {
    final isOnline = worker.isAvailable;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
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
            children: [
              Stack(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFF0F0F4),
                      border: Border.all(color: const Color(0xFFF8F9FA), width: 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: worker.profileImage.isNotEmpty
                        ? Image.network(
                            worker.profileImage,
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => const Icon(Icons.person, color: Color(0xFF6C6C70), size: 28),
                          )
                        : const Icon(Icons.person, color: Color(0xFF6C6C70), size: 28),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00875A),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check, size: 11, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            worker.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111111),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3FCEF),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF00875A),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${worker.skills.isNotEmpty ? worker.skills.join(', ') : 'Master Artisan'} • Pipe Specialist',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6C6C70),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            border: Border.all(color: const Color(0xFFE5E5EA)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified, size: 13, color: Color(0xFF00875A)),
                              SizedBox(width: 3),
                              Text(
                                'ITI Certified',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF111111),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            border: Border.all(color: const Color(0xFFE5E5EA)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Guild #${worker.guildId}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6C6C70),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.badge_outlined, color: Color(0xFF111111), size: 20),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              border: Border.all(color: const Color(0xFFE5E5EA)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isOnline ? const Color(0xFF00875A) : const Color(0xFF6C6C70),
                        shape: BoxShape.circle,
                        boxShadow: isOnline
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00875A).withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                )
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isOnline ? 'ONLINE' : 'OFFLINE',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isOnline ? const Color(0xFF00875A) : const Color(0xFF6C6C70),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              isOnline ? ' • Receiving Jobs in ${worker.serviceLocation}' : ' • On Break',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6C6C70),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          isOnline ? '3.5 km priority radius • Instant alerts' : 'Tap switch to resume shifts',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6C6C70),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () async {
                    await DI.workerRepo.updateWorkerAvailability(worker.id, !worker.isAvailable);
                    _refreshData();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 28,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isOnline ? const Color(0xFF111111) : const Color(0xFFE5E5EA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isOnline ? Icons.check : Icons.close,
                        size: 14,
                        color: isOnline ? const Color(0xFF00875A) : const Color(0xFF6C6C70),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentJobAlertCard(JobRequest request) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0B3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, size: 14, color: Color(0xFF7A4100)),
                    const SizedBox(width: 4),
                    Text(
                      'URGENT DISPATCH • ${request.distanceKm}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF7A4100),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.schedule, size: 13, color: Color(0xFF6C6C70)),
                  const SizedBox(width: 4),
                  Text(
                    request.createdAt,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6C6C70),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.customerName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.near_me, size: 14, color: Color(0xFF111111)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            request.customerLocation,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6C6C70),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${request.totalAmount.toInt()}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Text(
                      '100% PAYOUT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF00875A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              border: Border.all(color: const Color(0xFFEFEFF4)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE5E5EA)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.plumbing, size: 15, color: Color(0xFF111111)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        request.serviceName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 13, color: Color(0xFF6C6C70)),
                        const SizedBox(width: 5),
                        Text(
                          '${request.date} • ${request.time}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6C6C70),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Fixed Price',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFE3FCEF).withValues(alpha: 0.7),
              border: Border.all(color: const Color(0xFF00875A).withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.verified, size: 16, color: Color(0xFF00875A)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Zero platform commission. Direct UPI settlement in 10 mins.',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF006644),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                () async {
                  await DI.workerRepo.updateBookingStatus(request.id, BookingStatus.accepted);
                  _refreshData();
                }();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => WorkerJobDetailScreen(jobId: request.id)),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Accept Job',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await DI.workerRepo.updateBookingStatus(request.id, BookingStatus.rejected);
                      _refreshData();
                    },
                    icon: const Icon(Icons.redo, size: 15, color: Color(0xFF6C6C70)),
                    label: const Text(
                      'Pass to Guild',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E5EA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.call, size: 15, color: Color(0xFF6C6C70)),
                    label: const Text(
                      'Call Society',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5E5EA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceGrid(WorkerProfile worker) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TODAY\'S PERFORMANCE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Guild Cycle #${worker.guildId}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6C6C70),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.25,
          children: [
            _buildMetricCard(
              title: "Today's Earnings",
              icon: Icons.payments_outlined,
              iconColor: const Color(0xFF00875A),
              mainValue: '₹${worker.earnings.toInt()}',
              badgeText: '+6% vs y\'day',
              badgeColor: const Color(0xFF00875A),
              badgeBg: const Color(0xFFE3FCEF),
              footer: 'Direct Escrow Payout',
            ),
            _buildMetricCard(
              title: 'Jobs Completed',
              icon: Icons.engineering_outlined,
              iconColor: const Color(0xFF111111),
              mainValue: '${worker.completedJobs} / ${worker.completedJobs + 1}',
              showProgress: true,
              footer: '1 in queue for today',
            ),
            _buildMetricCard(
              title: 'Partner Rating',
              icon: Icons.star,
              iconColor: const Color(0xFFFFAB00),
              mainValue: worker.rating.toStringAsFixed(2),
              subValue: '/ 5.0',
              badgeText: '100% On-Time',
              badgeColor: const Color(0xFF00875A),
              footer: '126 verified reviews',
            ),
            _buildMetricCard(
              title: 'Guild Standing',
              icon: Icons.military_tech_outlined,
              iconColor: const Color(0xFF111111),
              mainValue: 'Top 5%',
              badgeText: 'Gold Badge Tier',
              badgeColor: const Color(0xFF111111),
              footer: 'Kothrud Cluster',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String mainValue,
    String? subValue,
    String? badgeText,
    Color? badgeColor,
    Color? badgeBg,
    bool showProgress = false,
    required String footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
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
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    mainValue,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (subValue != null) ...[
                    const SizedBox(width: 3),
                    Text(
                      subValue,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6C6C70),
                      ),
                    ),
                  ],
                ],
              ),
              if (showProgress)
                Container(
                  margin: const EdgeInsets.only(top: 6, bottom: 2),
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEFF4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: FractionallySizedBox(
                    widthFactor: 0.75,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF111111),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                )
              else if (badgeText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: badgeBg ?? const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badgeColor ?? const Color(0xFF111111),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Text(
            footer,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6C6C70),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedSchedule(List<JobRequest> completedJobs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'COMPLETED TODAY',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5E5EA),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    completedJobs.isNotEmpty ? completedJobs.length.toString() : '2',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                ),
              ],
            ),
            const Text(
              'Full History →',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (completedJobs.isEmpty) ...[
          _buildCompletedRow(
            customerName: 'Rajesh Deshmukh',
            time: '9:15 AM',
            service: 'Kitchen Sink Clog • Pratik Nagar',
            amount: '650',
          ),
          const SizedBox(height: 8),
          _buildCompletedRow(
            customerName: 'Meera Kulkarni',
            time: 'Yesterday',
            service: 'Shower Head Replacement • Mayur Colony',
            amount: '420',
          ),
        ] else
          ...completedJobs.map(
            (job) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildCompletedRow(
                customerName: job.customerName,
                time: job.time,
                service: '${job.serviceName} • ${job.customerLocation.split(',').first}',
                amount: job.totalAmount.toInt().toString(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCompletedRow({
    required String customerName,
    required String time,
    required String service,
    required String amount,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE3FCEF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: Color(0xFF00875A), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      customerName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6C6C70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  service,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6C6C70),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Icon(Icons.bolt, size: 12, color: Color(0xFF00875A)),
                    SizedBox(width: 2),
                    Text(
                      'Instant UPI • ★ 5.0',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00875A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '₹$amount',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3FCEF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Settled',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00875A),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelfareBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
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
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.health_and_safety,
                      color: Color(0xFF99F89E),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cooperative Safety Net',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Pune District Trade Union Trust',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFA0A0A5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00875A),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Insurance cover up to ₹50,000 active for today\'s shifts covering workplace injury, transit, and tool damages.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFE5E5EA),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.call, size: 16, color: Color(0xFFFFD180)),
                    SizedBox(width: 6),
                    Text(
                      'Union Helpline: 1800-209-4092',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Call Now',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
