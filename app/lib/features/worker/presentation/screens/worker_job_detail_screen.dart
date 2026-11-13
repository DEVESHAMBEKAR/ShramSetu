import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/worker_models.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../shared/widgets/state_views.dart';

class WorkerJobDetailScreen extends StatefulWidget {
  final String jobId;

  const WorkerJobDetailScreen({super.key, required this.jobId});

  @override
  State<WorkerJobDetailScreen> createState() => _WorkerJobDetailScreenState();
}

class _WorkerJobDetailScreenState extends State<WorkerJobDetailScreen> {
  late Future<List<JobRequest>> _jobFuture;
  StreamSubscription<List<JobRequest>>? _jobsSub;
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());
  bool _otpVerified = false;
  bool _hardwareBillAdded = false;
  bool _cashCollected = false;
  String? _otpErrorMessage;

  @override
  void initState() {
    super.initState();
    _refreshData();
    _jobsSub = DI.workerRepo.watchWorkerBookings().listen(
      (_) {
        if (mounted) _refreshData();
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _jobsSub?.cancel();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _refreshData() {
    setState(() {
      _jobFuture = DI.workerRepo.getWorkerBookings();
    });
  }

  void _onOtpChanged(int index, String value, JobRequest job) {
    if (value.isNotEmpty) {
      if (index < 3) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
        final code = _otpControllers.map((c) => c.text).join();
        if (code.length == 4) {
          final expectedOtp = job.otp ?? '8492';
          if (code == expectedOtp) {
            setState(() {
              _otpVerified = true;
              _otpErrorMessage = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Completion OTP verified successfully!'),
                backgroundColor: Color(0xFF2E7D32),
              ),
            );
          } else {
            setState(() {
              _otpVerified = false;
              _otpErrorMessage = 'Invalid OTP. Ask customer for 4-digit code.';
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Invalid OTP! Ask customer for their 4-digit Completion Code.'),
                backgroundColor: Colors.red,
              ),
            );
            // Clear inputs for re-entry
            for (var c in _otpControllers) {
              c.clear();
            }
            _otpFocusNodes[0].requestFocus();
          }
        }
      }
    } else {
      if (index > 0) {
        _otpFocusNodes[index - 1].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JobRequest>>(
      future: _jobFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: AppLoadingView(message: 'Loading job assignment details...'),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: AppErrorView(
              title: 'Error loading job',
              message: snapshot.error.toString(),
              onRetry: _refreshData,
            ),
          );
        }

        final jobs = snapshot.data ?? [];
        final jobIndex = jobs.indexWhere((j) => j.id == widget.jobId);
        if (jobIndex == -1) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              title: Text('Job Details', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
              backgroundColor: Colors.white,
              elevation: 0,
            ),
            body: AppEmptyView(
              icon: Icons.work_off_outlined,
              title: 'Job Not Found',
              subtitle: 'This service assignment is no longer active or could not be loaded.',
              actionLabel: 'Return to Jobs',
              onActionPressed: () => Navigator.of(context).pop(),
            ),
          );
        }

        final job = jobs[jobIndex];

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: _buildHeader(job),
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: AppSpacing.spacingSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCustomerCard(job),
                const SizedBox(height: 12),
                _buildServiceTimeline(job.status),
                const SizedBox(height: 12),
                _buildActionAndOtpSection(job),
                const SizedBox(height: 12),
                _buildSettlementCard(job),
                const SizedBox(height: 12),
                _buildLiaisonCard(),
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildHeader(JobRequest job) {
    return AppBar(
      backgroundColor: Colors.white.withValues(alpha: 0.95),
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.primary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Job #${job.id.length > 8 ? job.id.substring(0, 7).toUpperCase() : job.id.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: AppColors.onTertiaryContainer),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            job.serviceName,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.support_agent, size: 16, color: AppColors.primary),
            label: const Text(
              'Help',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.outlineVariant),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
            ),
          ),
        ),
        Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: AppSpacing.marginMobile),
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'RP',
            style: TextStyle(
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerCard(JobRequest job) {
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
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.onTertiaryContainer,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getStatusTitle(job.status).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: const Text(
                  'ShramSetu Partner',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          job.customerName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 16, color: AppColors.onTertiaryContainer),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.serviceName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: AppColors.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${job.date}, ${job.time}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
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
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.background,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: const Icon(Icons.person, color: AppColors.onSurfaceVariant, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceContainerLow),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 16, color: AppColors.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    job.customerLocation,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.call, size: 16),
                    label: const Text(
                      'Call Customer',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.navigation, size: 16, color: AppColors.primary),
                    label: const Text(
                      'Open in Maps',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.outlineVariant),
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

  Widget _buildServiceTimeline(BookingStatus status) {
    final stepIndex = _getStepIndex(status);

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
                  const Text(
                    'SERVICE TIMELINE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Step ${stepIndex + 1} of 5 active',
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusBadgeText(status),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTimelineStep(
            title: 'Job Accepted',
            subtitle: 'Assigned to Partner Rahul Patil',
            time: '10:15 AM',
            isCompleted: stepIndex > 0,
            isCurrent: stepIndex == 0,
            icon: Icons.check,
          ),
          _buildTimelineStep(
            title: 'Started Travel',
            subtitle: 'Departed from Kothrud Stand',
            time: '10:40 AM',
            isCompleted: stepIndex > 1,
            isCurrent: stepIndex == 1,
            icon: Icons.directions_car,
          ),
          _buildTimelineStep(
            title: 'Arrived at Location',
            subtitle: 'Checked in at Sai Shraddha Apts',
            time: '11:00 AM',
            isCompleted: stepIndex > 2,
            isCurrent: stepIndex == 2,
            icon: Icons.location_on,
          ),
          _buildTimelineStep(
            title: 'Repair in Progress',
            subtitle: 'Tap spindle dismantle & gasket replace',
            time: '11:10 AM',
            isCompleted: stepIndex > 3,
            isCurrent: stepIndex == 3,
            icon: Icons.build,
          ),
          _buildTimelineStep(
            title: 'Completion & Settlement',
            subtitle: 'Customer OTP verification required',
            time: 'Pending',
            isCompleted: stepIndex == 4,
            isCurrent: stepIndex == 4,
            icon: Icons.lock,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String subtitle,
    required String time,
    required bool isCompleted,
    required bool isCurrent,
    required IconData icon,
    bool isLast = false,
  }) {
    Color iconBg;
    Color iconColor;
    if (isCompleted) {
      iconBg = AppColors.onTertiaryContainer;
      iconColor = AppColors.onTertiary;
    } else if (isCurrent) {
      iconBg = AppColors.primary;
      iconColor = AppColors.onPrimary;
    } else {
      iconBg = AppColors.surfaceContainerLow;
      iconColor = AppColors.outline;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 13, color: iconColor),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: isCompleted ? AppColors.onTertiaryContainer : AppColors.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                              color: isCurrent || isCompleted ? AppColors.primary : AppColors.outline,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'CURRENT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.onPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        time,
                        style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isCurrent || isCompleted ? AppColors.onSurfaceVariant : AppColors.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionAndOtpSection(JobRequest job) {
    final nextStatus = _getNextStatus(job.status);
    final actionLabel = _getActionLabel(job.status);

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
          if (actionLabel.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (job.status == BookingStatus.inProgress) {
                    if (!_otpVerified) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please verify customer OTP first before completing job.')),
                      );
                      return;
                    }
                    if (job.isCash && !_cashCollected) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please confirm that you have collected ₹${job.totalAmount.toInt()} cash from customer.')),
                      );
                      return;
                    }
                  }
                  try {
                    await DI.workerRepo.updateBookingStatus(job.id, nextStatus);
                    if (mounted) _refreshData();
                    if (nextStatus == BookingStatus.completed) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(job.isCash 
                                ? 'Job completed and ₹${job.totalAmount.toInt()} cash payment settled!'
                                : 'Job successfully completed! Payout queued to Bank account.'),
                          ),
                        );
                        Navigator.of(context).pop();
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to update job status: $e')),
                      );
                    }
                  }
                },
                icon: Icon(
                  job.status == BookingStatus.inProgress ? Icons.check_circle : Icons.play_circle_outline,
                  size: 18,
                ),
                label: Text(
                  actionLabel,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.key, size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Text(
                          'Customer Completion OTP',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '4 DIGITS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  job.isCash
                      ? 'Enter the 4-digit code provided by ${job.customerName} after collecting ₹${job.totalAmount.toInt()}.00 cash and completing work.'
                      : 'Enter the 4-digit code provided by ${job.customerName} after job inspection. Upon submission, ₹${job.totalAmount.toInt()}.00 will be instantly transferred via UPI.',
                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.35),
                ),
                const SizedBox(height: 12),
                if (_otpVerified)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryContainer,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.onTertiaryContainer.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, size: 16, color: AppColors.onTertiaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            job.isCash
                                ? 'OTP Verified! Handover receipt & collect ₹${job.totalAmount.toInt()} cash.'
                                : 'OTP Verified! Instant NEFT payout queued to Rahul Patil (**4910)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (i) {
                          return Container(
                            width: 48,
                            height: 48,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            child: TextField(
                              controller: _otpControllers[i],
                              focusNode: _otpFocusNodes[i],
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              maxLength: 1,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                contentPadding: EdgeInsets.zero,
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                                ),
                              ),
                              onChanged: (val) => _onOtpChanged(i, val, job),
                            ),
                          );
                        }),
                      ),
                      if (_otpErrorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _otpErrorMessage!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementCard(JobRequest job) {
    final extraCost = _hardwareBillAdded ? 140 : 0;
    final total = job.totalAmount.toInt() + extraCost;

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
              const Text(
                'TARIFF & ESCROW SETTLEMENT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: job.isCash ? const Color(0xFFFFF3E0) : AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      job.isCash ? Icons.payments : Icons.verified_user,
                      size: 12,
                      color: job.isCash ? const Color(0xFFE65100) : AppColors.onTertiaryContainer,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      job.isCash ? 'Cash on Service' : 'Escrow Secured',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: job.isCash ? const Color(0xFFE65100) : AppColors.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSettlementRow('Base Visit & Inspection Fee', '₹${job.baseAmount.toInt()}.00'),
          const Divider(height: 16, color: AppColors.surfaceContainerLow),
          _buildSettlementRow('Skill & Labor Allowance', '₹${job.laborAllowance.toInt()}.00'),
          if (_hardwareBillAdded) ...[
            const Divider(height: 16, color: AppColors.surfaceContainerLow),
            _buildSettlementRow('Extra Brass Valve & Washer Ring', '+ ₹140.00', isHighlight: true),
          ],
          const SizedBox(height: 12),
          if (!_hardwareBillAdded)
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _hardwareBillAdded = true;
                  });
                },
                icon: const Icon(Icons.receipt_long, size: 16, color: AppColors.primary),
                label: const Text(
                  '+ Add Hardware Parts Bill',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: AppColors.background,
                ),
              ),
            ),
          if (job.isCash) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFB300)),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _cashCollected,
                    onChanged: (v) => setState(() => _cashCollected = v ?? false),
                    activeColor: const Color(0xFFE65100),
                  ),
                  Expanded(
                    child: Text(
                      'I have collected ₹$total.00 in cash from ${job.customerName}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.isCash ? 'CASH COLLECTION AMOUNT' : 'GUARANTEED PAYOUT',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.outline,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      job.isCash 
                          ? (_cashCollected ? '✓ Cash Received' : 'Collect cash before finish')
                          : 'Instant Direct UPI • Rahul Patil',
                      style: TextStyle(
                        fontSize: 11,
                        color: job.isCash && _cashCollected ? Colors.greenAccent : AppColors.outlineVariant,
                      ),
                    ),
                  ],
                ),
                Text(
                  '₹$total.00',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettlementRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isHighlight ? AppColors.onWarningContainer : AppColors.onSurfaceVariant,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: isHighlight ? AppColors.onWarningContainer : AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildLiaisonCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield, size: 16, color: AppColors.primary),
                  SizedBox(width: 6),
                  Text(
                    'ShramSetu Guild On-Duty Liaison',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Available',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Facing technical blockers or dispute on site? Kothrud ward senior union coordinator is available for immediate assistance.',
            style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant, height: 1.3),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.outlineVariant),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone_in_talk, size: 15, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text(
                      'Call Kothrud Ward Liaison',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.chevron_right, size: 16, color: AppColors.onSurfaceVariant),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _getStepIndex(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
      case BookingStatus.accepted:
        return 0;
      case BookingStatus.onTheWay:
        return 1;
      case BookingStatus.arrived:
        return 2;
      case BookingStatus.inProgress:
        return 3;
      case BookingStatus.completed:
        return 4;
      default:
        return 0;
    }
  }

  String _getStatusTitle(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending Acceptance';
      case BookingStatus.accepted:
        return 'Job Accepted';
      case BookingStatus.onTheWay:
        return 'Travelling to Site';
      case BookingStatus.arrived:
        return 'Arrived at Doorstep';
      case BookingStatus.inProgress:
        return 'In Progress • Scheduled Visit';
      case BookingStatus.completed:
        return 'Completed & Settled';
      default:
        return 'Scheduled Visit';
    }
  }

  String _getStatusBadgeText(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
      case BookingStatus.accepted:
        return 'Dispatched';
      case BookingStatus.onTheWay:
        return 'In Transit';
      case BookingStatus.arrived:
      case BookingStatus.inProgress:
        return 'On Site';
      case BookingStatus.completed:
        return 'Completed';
      default:
        return 'Active';
    }
  }

  BookingStatus _getNextStatus(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
      case BookingStatus.accepted:
        return BookingStatus.onTheWay;
      case BookingStatus.onTheWay:
        return BookingStatus.arrived;
      case BookingStatus.arrived:
        return BookingStatus.inProgress;
      case BookingStatus.inProgress:
        return BookingStatus.completed;
      default:
        return BookingStatus.completed;
    }
  }

  String _getActionLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
      case BookingStatus.accepted:
        return 'Start Journey to Customer';
      case BookingStatus.onTheWay:
        return 'Mark as Arrived at Location';
      case BookingStatus.arrived:
        return 'Mark as: Started Work at Customer Site';
      case BookingStatus.inProgress:
        return 'Complete Work (Req. Customer OTP)';
      default:
        return '';
    }
  }
}
