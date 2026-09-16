import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/worker_models.dart';
import '../../../../core/config/dependency_injection.dart';

class WorkerJobDetailScreen extends StatefulWidget {
  final String jobId;

  const WorkerJobDetailScreen({super.key, required this.jobId});

  @override
  State<WorkerJobDetailScreen> createState() => _WorkerJobDetailScreenState();
}

class _WorkerJobDetailScreenState extends State<WorkerJobDetailScreen> {
  late Future<List<JobRequest>> _jobFuture;
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());
  bool _otpVerified = false;
  bool _hardwareBillAdded = false;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
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

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 3) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        _otpFocusNodes[index].unfocus();
        final code = _otpControllers.map((c) => c.text).join();
        if (code.length == 4) {
          setState(() {
            _otpVerified = true;
          });
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
            backgroundColor: Color(0xFFF8F9FC),
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF8F9FC),
            body: Center(child: Text('Error loading job: ${snapshot.error}')),
          );
        }

        final jobs = snapshot.data ?? [];
        final job = jobs.firstWhere(
          (j) => j.id == widget.jobId,
          orElse: () => JobRequest(
            id: widget.jobId,
            customerId: '',
            customerName: 'Ananya Sharma',
            customerLocation: 'Flat 402, Sai Shraddha Apts, Ideal Colony, Paud Road, Kothrud, Pune - 411038',
            customerPhone: '+919876543210',
            serviceName: 'Plumbing Inspection & Tap Leakage Repair',
            date: 'Today',
            time: '11:00 AM – 12:00 PM',
            baseAmount: 399,
            laborAllowance: 86,
            status: BookingStatus.inProgress,
            distanceKm: '1.8 KM',
            createdAt: '10 mins ago',
          ),
        );

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FC),
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
        icon: const Icon(Icons.arrow_back, color: Color(0xFF111111)),
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
                  color: Color(0xFF111111),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3FCEF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(radius: 3, backgroundColor: Color(0xFF00875A)),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF00875A),
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
              color: Color(0xFF6C6C70),
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
            icon: const Icon(Icons.support_agent, size: 16, color: Color(0xFF111111)),
            label: const Text(
              'Help',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111111),
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFE5E5EA)),
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
            color: Color(0xFF111111),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            'RP',
            style: TextStyle(
              color: Colors.white,
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
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF00875A),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getStatusTitle(job.status).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: const Text(
                  'ShramSetu Partner',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6C6C70),
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
                            color: Color(0xFF111111),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 16, color: Color(0xFF00875A)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      job.serviceName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6C6C70),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 14, color: Color(0xFF111111)),
                        const SizedBox(width: 4),
                        Text(
                          '${job.date}, ${job.time}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
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
                  color: const Color(0xFFF8F9FA),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                child: const Icon(Icons.person, color: Color(0xFF6C6C70), size: 28),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEFEFF4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on, size: 16, color: Color(0xFF6C6C70)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    job.customerLocation,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF333333),
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
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
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
                    icon: const Icon(Icons.navigation, size: 16, color: Color(0xFF111111)),
                    label: const Text(
                      'Open in Maps',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111111)),
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

  Widget _buildServiceTimeline(BookingStatus status) {
    final stepIndex = _getStepIndex(status);

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SERVICE TIMELINE',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Step ${stepIndex + 1} of 5 active',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6C6C70)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3FCEF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusBadgeText(status),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00875A),
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
      iconBg = const Color(0xFF00875A);
      iconColor = Colors.white;
    } else if (isCurrent) {
      iconBg = const Color(0xFF111111);
      iconColor = Colors.white;
    } else {
      iconBg = const Color(0xFFF0F0F4);
      iconColor = const Color(0xFFA0A0A5);
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
                    color: isCompleted ? const Color(0xFF00875A) : const Color(0xFFE5E5EA),
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
                              color: isCurrent || isCompleted ? const Color(0xFF111111) : const Color(0xFFA0A0A5),
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111111),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'CURRENT',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        time,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF6C6C70)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isCurrent || isCompleted ? const Color(0xFF6C6C70) : const Color(0xFFA0A0A5),
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
          if (actionLabel.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (job.status == BookingStatus.inProgress && !_otpVerified) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please verify customer OTP first before completing job.')),
                    );
                    return;
                  }
                  await DI.workerRepo.updateBookingStatus(job.id, nextStatus);
                  _refreshData();
                  if (nextStatus == BookingStatus.completed) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Job successfully completed! Payout queued to Bank account.')),
                      );
                      Navigator.of(context).pop();
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
                  backgroundColor: const Color(0xFF111111),
                  foregroundColor: Colors.white,
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
              color: const Color(0xFFFBFBFD),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEAEAEA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.key, size: 16, color: Color(0xFF111111)),
                        SizedBox(width: 6),
                        Text(
                          'Customer Completion OTP',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111111),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E5EA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '4 DIGITS',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6C6C70),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the 4-digit code provided by ${job.customerName} after job inspection. Upon submission, ₹${job.totalAmount.toInt()}.00 will be instantly transferred via UPI.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6C6C70), height: 1.35),
                ),
                const SizedBox(height: 12),
                if (_otpVerified)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3FCEF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF00875A).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle, size: 16, color: Color(0xFF00875A)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'OTP Verified! Instant NEFT payout queued to Rahul Patil (**4910)',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF006644),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
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
                            color: Color(0xFF111111),
                          ),
                          decoration: InputDecoration(
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFFE5E5EA)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF111111), width: 1.5),
                            ),
                          ),
                          onChanged: (val) => _onOtpChanged(i, val),
                        ),
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

  Widget _buildSettlementCard(JobRequest job) {
    final extraCost = _hardwareBillAdded ? 140 : 0;
    final total = job.totalAmount.toInt() + extraCost;

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
              const Text(
                'TARIFF & ESCROW SETTLEMENT',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3FCEF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user, size: 12, color: Color(0xFF00875A)),
                    SizedBox(width: 3),
                    Text(
                      'Escrow Secured',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF00875A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSettlementRow('Base Visit & Inspection Fee', '₹${job.baseAmount.toInt()}.00'),
          const Divider(height: 16, color: Color(0xFFF0F0F4)),
          _buildSettlementRow('Skill & Labor Allowance', '₹${job.laborAllowance.toInt()}.00'),
          if (_hardwareBillAdded) ...[
            const Divider(height: 16, color: Color(0xFFF0F0F4)),
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
                icon: const Icon(Icons.receipt_long, size: 16, color: Color(0xFF111111)),
                label: const Text(
                  '+ Add Hardware Parts Bill',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE5E5EA)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: const Color(0xFFF8F9FA),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GUARANTEED PAYOUT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFA0A0A5),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      'Instant Direct UPI • Rahul Patil',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFFE5E5EA),
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
            color: isHighlight ? const Color(0xFF7A4100) : const Color(0xFF6C6C70),
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            color: isHighlight ? const Color(0xFF7A4100) : const Color(0xFF111111),
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
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.shield, size: 16, color: Color(0xFF111111)),
                  SizedBox(width: 6),
                  Text(
                    'ShramSetu Guild On-Duty Liaison',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3FCEF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Available',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF00875A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Facing technical blockers or dispute on site? Kothrud ward senior union coordinator is available for immediate assistance.',
            style: TextStyle(fontSize: 11, color: Color(0xFF6C6C70), height: 1.3),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E5EA)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.phone_in_talk, size: 15, color: Color(0xFF111111)),
                    SizedBox(width: 6),
                    Text(
                      'Call Kothrud Ward Liaison',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ],
                ),
                Icon(Icons.chevron_right, size: 16, color: Color(0xFF6C6C70)),
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
