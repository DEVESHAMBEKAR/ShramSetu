import '../../../../core/models/booking_status.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/worker_models.dart';
import '../../data/repositories/mock_worker_repository.dart';

class WorkerJobDetailScreen extends StatefulWidget {
  final String jobId;

  const WorkerJobDetailScreen({super.key, required this.jobId});

  @override
  State<WorkerJobDetailScreen> createState() => _WorkerJobDetailScreenState();
}

class _WorkerJobDetailScreenState extends State<WorkerJobDetailScreen> {
  late MockWorkerRepository _repository;
  bool _otpVerified = false;

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

  JobRequest get _job => _repository.currentJobs.firstWhere(
    (j) => j.id == widget.jobId,
    orElse: () => _repository.activeRequests.firstWhere(
      (j) => j.id == widget.jobId,
      orElse: () => _repository.completedJobs.firstWhere((j) => j.id == widget.jobId)
    )
  );

  @override
  Widget build(BuildContext context) {
    final job = _job;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Job Detail View', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          children: [
            _buildStatusStrip(job.status),
            const SizedBox(height: AppSpacing.spacingMd),
            _buildCustomerCard(job),
            const SizedBox(height: AppSpacing.spacingMd),
            _buildProgressTimeline(job.status),
            const SizedBox(height: AppSpacing.spacingMd),
            if (job.status != BookingStatus.completed) _buildActionArea(job),
            const SizedBox(height: AppSpacing.spacingMd),
            _buildBillingBreakdown(job),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStrip(BookingStatus status) {
    String label = '';
    Color color = AppColors.primaryContainer;
    Color textColor = AppColors.onPrimary;

    switch (status) {
      case BookingStatus.pending: label = 'Pending Accept'; break;
      case BookingStatus.accepted: label = 'Accepted'; break;
      case BookingStatus.onTheWay: label = 'Travelling'; break;
      case BookingStatus.arrived: label = 'Arrived'; break;
      case BookingStatus.inProgress: label = 'In Progress'; break;
      case BookingStatus.completed: 
        label = 'Completed'; 
        color = AppColors.tertiaryContainer;
        break;
      default: label = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd, vertical: AppSpacing.spacingXs),
      decoration: BoxDecoration(color: color, borderRadius: AppRadius.radiusXl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (status != BookingStatus.completed)
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: AppSpacing.spacingXs),
                  decoration: const BoxDecoration(color: AppColors.secondaryContainer, shape: BoxShape.circle),
                ),
              Text('Active Job #${widget.jobId.toUpperCase()}', style: AppTypography.labelMd.copyWith(color: textColor, letterSpacing: 1.2)),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: 2),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest.withValues(alpha: 0.15), borderRadius: AppRadius.radiusFull),
            child: Text(label, style: AppTypography.labelSm.copyWith(color: textColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(JobRequest job) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(job.customerName, style: AppTypography.titleLg.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                        const SizedBox(width: AppSpacing.spacing2xs),
                        const Icon(Icons.verified, size: 18, color: AppColors.onTertiaryContainer),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(job.serviceName, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: AppColors.outline),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.spacingSm),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 20, color: AppColors.secondary),
                    const SizedBox(width: AppSpacing.spacingXs),
                    Text('${job.date}, ${job.time}', style: AppTypography.labelLg.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 20, color: AppColors.outline),
                    const SizedBox(width: AppSpacing.spacingXs),
                    Expanded(
                      child: Text(job.customerLocation, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.radiusLg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.call, size: 20, color: AppColors.onPrimary),
                      const SizedBox(width: 8),
                      Text('Call Customer', style: AppTypography.labelLg.copyWith(color: AppColors.onPrimary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.spacingSm),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusLg),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.navigation, size: 20, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text('Open in Maps', style: AppTypography.labelLg.copyWith(color: AppColors.onSurface)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressTimeline(BookingStatus currentStatus) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Job Progress Timeline', style: AppTypography.titleMd.copyWith(color: AppColors.onSurface)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: 2),
                decoration: BoxDecoration(color: AppColors.secondaryFixed.withValues(alpha: 0.5), borderRadius: AppRadius.radiusFull),
                child: Text('Tracking', style: AppTypography.labelSm.copyWith(color: AppColors.secondary)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          _buildTimelineItem('Job Accepted', Icons.check, true, currentStatus == BookingStatus.accepted),
          _buildTimelineItem('Travelling', Icons.check, currentStatus.index >= BookingStatus.onTheWay.index, currentStatus == BookingStatus.onTheWay),
          _buildTimelineItem('Arrived at Location', Icons.location_on, currentStatus.index >= BookingStatus.arrived.index, currentStatus == BookingStatus.arrived),
          _buildTimelineItem('Work in Progress', Icons.build, currentStatus.index >= BookingStatus.inProgress.index, currentStatus == BookingStatus.inProgress),
          _buildTimelineItem('Completed & Settled', Icons.verified, currentStatus.index >= BookingStatus.completed.index, currentStatus == BookingStatus.completed, isLast: true),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(String title, IconData icon, bool isCompleted, bool isCurrent, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCompleted ? (isCurrent ? AppColors.secondaryContainer : AppColors.tertiaryContainer) : AppColors.surfaceContainerHigh,
                  shape: BoxShape.circle,
                  border: isCurrent ? Border.all(color: AppColors.secondaryFixed.withValues(alpha: 0.5), width: 4) : null,
                ),
                child: Icon(icon, size: 16, color: isCompleted ? AppColors.onPrimary : AppColors.outline),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: isCompleted && !isCurrent ? AppColors.tertiaryContainer : AppColors.surfaceVariant)),
            ],
          ),
          const SizedBox(width: AppSpacing.spacingMd),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.spacingLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: AppTypography.labelLg.copyWith(color: isCompleted ? (isCurrent ? AppColors.secondary : AppColors.onSurface) : AppColors.outline, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                      if (isCurrent) ...[
                        const SizedBox(width: AppSpacing.spacingXs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.secondary, borderRadius: AppRadius.radiusSm),
                          child: Text('CURRENT', style: AppTypography.labelSm.copyWith(color: AppColors.onSecondary)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionArea(JobRequest job) {
    String actionText = '';
    IconData actionIcon = Icons.play_circle;
    BookingStatus nextStatus = job.status;

    switch (job.status) {
      case BookingStatus.accepted:
        actionText = 'Start Journey';
        actionIcon = Icons.directions_car;
        nextStatus = BookingStatus.onTheWay;
        break;
      case BookingStatus.onTheWay:
        actionText = 'Mark as Arrived';
        actionIcon = Icons.location_on;
        nextStatus = BookingStatus.arrived;
        break;
      case BookingStatus.arrived:
        actionText = 'Start Work at Customer Site';
        actionIcon = Icons.play_circle;
        nextStatus = BookingStatus.inProgress;
        break;
      case BookingStatus.inProgress:
        actionText = 'Complete Work (Req. OTP)';
        actionIcon = Icons.verified;
        nextStatus = BookingStatus.completed;
        break;
      default:
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        children: [
          if (job.status == BookingStatus.inProgress) ...[
            _buildOtpSection(),
            const SizedBox(height: AppSpacing.spacingMd),
          ],
          GestureDetector(
            onTap: () {
              if (job.status == BookingStatus.inProgress && !_otpVerified) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please verify OTP first')));
                return;
              }
              _repository.updateBookingStatus(job.id, nextStatus);
              if (nextStatus == BookingStatus.completed) {
                Navigator.of(context).pop();
              }
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(color: (job.status == BookingStatus.inProgress && !_otpVerified) ? AppColors.surfaceContainerHigh : AppColors.secondary, borderRadius: AppRadius.radiusXl),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(actionIcon, color: AppColors.onSecondary, size: 22),
                  const SizedBox(width: AppSpacing.spacingXs),
                  Text(actionText, style: AppTypography.labelLg.copyWith(color: AppColors.onSecondary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpSection() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusXl),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.pin, color: AppColors.secondary, size: 20),
                  const SizedBox(width: 4),
                  Text('Customer Escrow Release OTP', style: AppTypography.titleMd.copyWith(color: AppColors.onSurface)),
                ],
              ),
              Text('4 Digits', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingXs),
          Text('Ask customer for completion OTP after they inspect your plumbing repair.', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.spacingSm),
          if (_otpVerified)
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.spacingXs),
              decoration: BoxDecoration(color: AppColors.tertiaryFixed, borderRadius: AppRadius.radiusSm),
              alignment: Alignment.center,
              child: Text('✓ OTP Verified! Funds releasing to Bank Account', style: AppTypography.labelMd.copyWith(color: AppColors.onTertiaryFixedVariant)),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) => Container(
                width: 56,
                height: 56,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusLg, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
                alignment: Alignment.center,
                child: TextField(
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                  style: AppTypography.currencyDisplay,
                  onChanged: (val) {
                    if (val.isNotEmpty && index == 3) {
                      setState(() => _otpVerified = true);
                    }
                  },
                ),
              )),
            ),
        ],
      ),
    );
  }

  Widget _buildBillingBreakdown(JobRequest job) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Cooperative Escrow Breakdown', style: AppTypography.titleMd.copyWith(color: AppColors.onSurface)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: 2),
                decoration: BoxDecoration(color: AppColors.tertiaryFixed.withValues(alpha: 0.3), borderRadius: AppRadius.radiusFull),
                child: Row(
                  children: [
                    const Icon(Icons.lock, size: 14, color: AppColors.onTertiaryContainer),
                    const SizedBox(width: 4),
                    Text('Escrow Locked', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Base Visit & Inspection Fee', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
              Text('₹${job.baseAmount.toInt()}.00', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Skill & Labor Allowance', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
              Text('₹${job.laborAllowance.toInt()}.00', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          Container(
            padding: const EdgeInsets.all(AppSpacing.spacingSm),
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.radiusXl),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Cooperative Payout', style: AppTypography.titleMd.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold)),
                    Text('0% Commission Deducted', style: AppTypography.labelSm.copyWith(color: AppColors.onPrimaryContainer)),
                  ],
                ),
                Text('₹${job.totalAmount.toInt()}.00', style: AppTypography.currencyDisplay.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

