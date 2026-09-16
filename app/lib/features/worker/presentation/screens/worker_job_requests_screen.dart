import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/worker_models.dart';
import '../../../../core/config/dependency_injection.dart';
import 'worker_job_detail_screen.dart';

class WorkerJobRequestsScreen extends StatefulWidget {
  const WorkerJobRequestsScreen({super.key});

  @override
  State<WorkerJobRequestsScreen> createState() => _WorkerJobRequestsScreenState();
}

class _WorkerJobRequestsScreenState extends State<WorkerJobRequestsScreen> {
  late Future<List<JobRequest>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _jobsFuture = DI.workerRepo.getWorkerBookings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        elevation: 0,
        scrolledUnderElevation: 1,
        titleSpacing: AppSpacing.marginMobile,
        title: const Text(
          'Active & Queued Jobs',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111111),
            letterSpacing: -0.4,
          ),
        ),
      ),
      body: FutureBuilder<List<JobRequest>>(
        future: _jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final jobs = snapshot.data ?? [];

          if (jobs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E5EA).withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assignment_outlined, size: 36, color: Color(0xFF6C6C70)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No active job requests',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'New customer bookings will appear here instantly',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6C6C70)),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => _refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: AppSpacing.spacingSm,
              ),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildJobCard(job),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildJobCard(JobRequest job) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => WorkerJobDetailScreen(jobId: job.id)),
        ).then((_) => _refresh());
      },
      child: Container(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3FCEF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    job.status.name.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00875A),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Text(
                  '₹${job.totalAmount.toInt()}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111111),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              job.customerName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
              ),
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
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.near_me, size: 14, color: Color(0xFF6C6C70)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    job.customerLocation,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF6C6C70)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.schedule, size: 13, color: Color(0xFF6C6C70)),
                    const SizedBox(width: 4),
                    Text(
                      '${job.date} • ${job.time}',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF6C6C70)),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Text(
                      'Open Job',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: Color(0xFF111111)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
