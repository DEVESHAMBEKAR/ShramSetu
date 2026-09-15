import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/worker_models.dart';

import 'worker_job_detail_screen.dart';

class WorkerJobRequestsScreen extends StatefulWidget {
  const WorkerJobRequestsScreen({super.key});

  @override
  State<WorkerJobRequestsScreen> createState() => _WorkerJobRequestsScreenState();
}

class _WorkerJobRequestsScreenState extends State<WorkerJobRequestsScreen> {
  // late MockWorkerRepository _repository;

  @override
  void initState() {
    super.initState();
    // _repository = MockWorkerRepository();
    
  }

  @override
  void dispose() {
    
    super.dispose();
  }

  void _onRepositoryChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final jobs = [];

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Job Requests', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: jobs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_available, size: 64, color: AppColors.outlineVariant),
                  const SizedBox(height: AppSpacing.spacingMd),
                  Text('No active job requests', style: AppTypography.titleMd.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
                  child: _buildJobCard(job),
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
        );
      },
      child: Container(
        decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(job.customerName, style: AppTypography.titleMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                Text('₹${job.totalAmount.toInt()}', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingXs),
            Text(job.serviceName, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.spacingXs),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: AppColors.outline),
                const SizedBox(width: 4),
                Expanded(child: Text(job.customerLocation, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingSm, vertical: AppSpacing.spacing3xs),
              decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: AppRadius.radiusFull),
              child: Text(job.status.name.toUpperCase(), style: AppTypography.labelSm.copyWith(color: AppColors.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }
}
