import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
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
      final userId = Supabase.instance.client.auth.currentUser!.id;
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        }

        final worker = snapshot.data![0] as WorkerProfile;
        final allBookings = snapshot.data![1] as List<JobRequest>;
        
        final activeRequests = allBookings.where((j) => j.status == BookingStatus.pending).toList();
        final completedJobs = allBookings.where((j) => j.status == BookingStatus.completed).toList();

        return Scaffold(
          backgroundColor: AppColors.surface,
          appBar: _buildAppBar(worker),
          body: RefreshIndicator(
            onRefresh: () async { _refreshData(); },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              child: Column(
                children: [
                  _buildIdentityCard(worker),
                  const SizedBox(height: AppSpacing.spacingMd),
                  if (activeRequests.isNotEmpty && worker.isAvailable)
                    _buildInboundJobCard(activeRequests.first),
                  const SizedBox(height: AppSpacing.spacingMd),
                  _buildDailyMetrics(worker),
                  const SizedBox(height: AppSpacing.spacingMd),
                  _buildCompletedSchedule(completedJobs),
                  const SizedBox(height: AppSpacing.spacingMd),
                  _buildWelfareBanner(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
  PreferredSizeWidget _buildAppBar(WorkerProfile worker) {
    return AppBar(
      backgroundColor: AppColors.surface.withValues(alpha: 0.9),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.04),
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
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(color: AppColors.onTertiaryContainer, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: AppSpacing.spacing2xs),
                  Text('${worker.guildName} ${worker.guildId}', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
              Text('Home Dashboard', style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
            ],
          ),
        ],
      ),
      actions: [
        Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.only(right: AppSpacing.spacing3xs),
          decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusLg),
          alignment: Alignment.center,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(text: 'म', style: AppTypography.labelMd.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                TextSpan(text: '/EN', style: AppTypography.labelMd.copyWith(color: AppColors.onSurface)),
              ],
            ),
          ),
        ),
        Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.only(right: AppSpacing.spacing3xs),
          decoration: BoxDecoration(color: AppColors.secondaryContainer.withValues(alpha: 0.15), borderRadius: AppRadius.radiusLg),
          child: const Icon(Icons.support_agent, color: AppColors.secondary),
        ),
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: AppSpacing.marginMobile),
          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          child: const Icon(Icons.person, color: AppColors.onPrimary, size: 18),
        ),
      ],
    );
  }

  Widget _buildIdentityCard(WorkerProfile worker) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
                    child: const Icon(Icons.person, color: AppColors.outline),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: const BoxDecoration(color: AppColors.tertiaryFixedDim, shape: BoxShape.circle),
                      child: const Icon(Icons.verified, size: 12, color: AppColors.onTertiaryFixed),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Namaste, ${worker.name}', style: AppTypography.headlineSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    Text('Master Plumber & Pipe Specialist', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.spacing4xs),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing2xs, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusFull),
                          child: Row(
                            children: [
                              const Icon(Icons.workspace_premium, size: 13, color: AppColors.secondary),
                              const SizedBox(width: 4),
                              Text('ITI Certified', style: AppTypography.labelSm.copyWith(color: AppColors.primary)),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.spacing2xs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing2xs, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: AppRadius.radiusFull),
                          child: Row(
                            children: [
                              const Icon(Icons.groups, size: 13, color: AppColors.onPrimaryFixedVariant),
                              const SizedBox(width: 4),
                              Text('Guild ${worker.guildId}', style: AppTypography.labelSm.copyWith(color: AppColors.onPrimaryFixedVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusLg),
                child: const Icon(Icons.badge, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          _buildDutyToggle(worker),
        ],
      ),
    );
  }

  Widget _buildDutyToggle(WorkerProfile worker) {
    final isOnline = worker.isAvailable;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      decoration: BoxDecoration(
        color: isOnline ? AppColors.tertiaryFixed.withValues(alpha: 0.3) : AppColors.surfaceContainerHigh,
        borderRadius: AppRadius.radiusXl,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: isOnline ? AppColors.onTertiaryContainer : AppColors.outline, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.spacingXs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? 'ONLINE & RECEIVING JOBS' : 'OFFLINE • ON BREAK',
                    style: AppTypography.labelLg.copyWith(color: isOnline ? AppColors.tertiaryContainer : AppColors.onSurfaceVariant, fontWeight: FontWeight.bold),
                  ),
                  if (isOnline)
                    Text('Priority radius: ${worker.serviceLocation} (3.5 km)', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ],
          ),
          GestureDetector(
            onTap: () => () async { await DI.workerRepo.updateWorkerAvailability(worker.id, !worker.isAvailable); _refreshData(); }(),
            child: Container(
              width: 56,
              height: 36,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: isOnline ? AppColors.primary : AppColors.surfaceVariant, borderRadius: AppRadius.radiusFull),
              alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(color: AppColors.surfaceContainerLowest, shape: BoxShape.circle),
                child: Icon(isOnline ? Icons.check : Icons.close, size: 16, color: isOnline ? AppColors.onTertiaryContainer : AppColors.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInboundJobCard(JobRequest request) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6)]),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: AppRadius.radiusFull),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, size: 16, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Text('New Urgent Request • ${request.distanceKm}', style: AppTypography.labelMd.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.timer, size: 14, color: AppColors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(request.createdAt, style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(request.customerName, style: AppTypography.titleLg.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: AppColors.secondary),
                              const SizedBox(width: 4),
                              Expanded(child: Text(request.customerLocation, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('₹${request.totalAmount.toInt()}', style: AppTypography.currencyDisplay.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        Text('100% Payout', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.spacingXs),
                  decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.plumbing, size: 18, color: AppColors.primary),
                          const SizedBox(width: AppSpacing.spacingXs),
                          Text(request.serviceName, style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.spacing3xs),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 18, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: AppSpacing.spacingXs),
                          Text('${request.date} • ${request.time}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.spacing3xs),
                      Text('Base: ₹${request.baseAmount.toInt()} + Standard labor: ₹${request.laborAllowance.toInt()}', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.spacingXs),
                  decoration: BoxDecoration(color: AppColors.tertiaryFixed.withValues(alpha: 0.2), borderRadius: AppRadius.radiusLg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified_user, size: 20, color: AppColors.onTertiaryContainer),
                      const SizedBox(width: AppSpacing.spacingXs),
                      Expanded(
                        child: Text(
                          'Zero platform commission. Direct UPI credit to your union-linked bank within 10 mins of OTP signoff.',
                          style: AppTypography.bodySm.copyWith(color: AppColors.onTertiaryFixedVariant),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                GestureDetector(
                  onTap: () {
                    () async { await DI.workerRepo.updateBookingStatus(request.id, BookingStatus.accepted); _refreshData(); }();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => WorkerJobDetailScreen(jobId: request.id)),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.radiusXl),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.onPrimary),
                        const SizedBox(width: AppSpacing.spacingXs),
                        Text('Accept Job (Tap to Confirm)', style: AppTypography.labelLg.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingXs),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => () async { await DI.workerRepo.updateBookingStatus(request.id, BookingStatus.rejected); _refreshData(); }(),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusXl),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.redo, size: 18, color: AppColors.onSurface),
                              const SizedBox(width: 4),
                              Text('Pass to Guild', style: AppTypography.labelMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spacingXs),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusXl),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.call, size: 18, color: AppColors.onSurface),
                            const SizedBox(width: 4),
                            Text('Call Desk', style: AppTypography.labelMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyMetrics(WorkerProfile worker) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Today\'s Performance', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            Text('Guild Cycle #44', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.spacingXs,
          crossAxisSpacing: AppSpacing.spacingXs,
          childAspectRatio: 1.2,
          children: [
            _buildMetricCard('Today\'s Earnings', Icons.payments, '₹${worker.earnings.toInt()}', '${worker.completedJobs} jobs settled', AppColors.onTertiaryContainer, 'Direct Union Escrow Payout', AppColors.primary),
            _buildMetricCard('Jobs Dispatched', Icons.engineering, '4 Assigned', '3 Done • 1 In Queue', AppColors.primary, '', AppColors.primary, showProgress: true),
            _buildMetricCard('Worker Rating', Icons.star, worker.rating.toString(), '126 verified reviews', AppColors.secondaryContainer, '100% On-Time', AppColors.primary, isRating: true),
            _buildMetricCard('Guild Rank', Icons.military_tech, 'Top 5%', 'Kothrud Cluster', AppColors.secondary, 'Gold Badge Tier', AppColors.secondary),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String title, IconData icon, String value, String subtitle, Color iconColor, String footer, Color valueColor, {bool showProgress = false, bool isRating = false}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(value, style: AppTypography.headlineMd.copyWith(color: valueColor, fontWeight: FontWeight.bold)),
                  if (isRating) Text('/ 5.0', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
              if (showProgress)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  height: 6,
                  decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: AppRadius.radiusFull),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Container(decoration: BoxDecoration(color: AppColors.onTertiaryContainer, borderRadius: AppRadius.radiusFull))),
                      Expanded(flex: 1, child: Container(decoration: BoxDecoration(color: AppColors.secondary, borderRadius: AppRadius.radiusFull))),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Text(subtitle, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11)),
            ],
          ),
          if (footer.isNotEmpty)
            Text(footer, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11)),
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
                Text('Completed Today', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                const SizedBox(width: AppSpacing.spacingXs),
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(completedJobs.length.toString(), style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                ),
              ],
            ),
            Row(
              children: [
                Text('Full History', style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                const Icon(Icons.chevron_right, size: 14, color: AppColors.secondary),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        ...completedJobs.map((job) => _buildCompletedJobCard(job)),
      ],
    );
  }

  Widget _buildCompletedJobCard(JobRequest job) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spacingXs),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.tertiaryFixed.withValues(alpha: 0.3), shape: BoxShape.circle),
            child: const Icon(Icons.check, color: AppColors.onTertiaryContainer, size: 20),
          ),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(job.customerName, style: AppTypography.titleMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                    const SizedBox(width: AppSpacing.spacingXs),
                    Text(job.time.split(' ')[0] + ' ' + job.time.split(' ')[1], style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                Text('${job.serviceName} • ${job.customerLocation.split(',').first}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.spacing3xs),
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, size: 13, color: AppColors.onTertiaryContainer),
                    const SizedBox(width: 4),
                    Text('Paid via UPI', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontWeight: FontWeight.bold)),
                    Text(' • Rating ★ 5.0', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹${job.totalAmount.toInt()}', style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              Text('Settled', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWelfareBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.radiusXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: AppColors.surfaceContainerLowest.withValues(alpha: 0.15), borderRadius: AppRadius.radiusLg),
                    child: const Icon(Icons.health_and_safety, color: AppColors.tertiaryFixed, size: 20),
                  ),
                  const SizedBox(width: AppSpacing.spacingXs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cooperative Safety Net Active', style: AppTypography.titleMd.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold)),
                      Text('Pune District Trade Union Trust', style: AppTypography.labelSm.copyWith(color: AppColors.onPrimaryContainer)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing2xs, vertical: 2),
                decoration: BoxDecoration(color: AppColors.tertiaryContainer, borderRadius: BorderRadius.circular(4)),
                child: Text('ACTIVE', style: AppTypography.labelSm.copyWith(color: AppColors.tertiaryFixed, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          RichText(
            text: TextSpan(
              style: AppTypography.bodySm.copyWith(color: AppColors.primaryFixed),
              children: [
                const TextSpan(text: 'Insurance cover up to '),
                TextSpan(text: '₹50,000', style: const TextStyle(fontWeight: FontWeight.bold)),
                const TextSpan(text: ' active for today\'s shifts covering workplace injury, transit, and tool damages.'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.spacingXs),
            decoration: BoxDecoration(color: AppColors.primaryContainer.withValues(alpha: 0.4), borderRadius: AppRadius.radiusLg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.call, size: 18, color: AppColors.secondaryContainer),
                    const SizedBox(width: AppSpacing.spacingXs),
                    Text('Union Helpline: 1800-209-4092', style: AppTypography.bodySm.copyWith(color: AppColors.onPrimary)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: 4),
                  decoration: BorderRadius.circular(4) != null ? BoxDecoration(color: AppColors.secondaryContainer, borderRadius: BorderRadius.circular(4)) : null,
                  child: Text('Call Now', style: AppTypography.labelSm.copyWith(color: AppColors.onSecondaryContainer, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

