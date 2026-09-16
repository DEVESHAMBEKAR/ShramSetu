import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../data/models/admin_models.dart';

class AdminComplaintsScreen extends StatefulWidget {
  const AdminComplaintsScreen({super.key});

  @override
  State<AdminComplaintsScreen> createState() => _AdminComplaintsScreenState();
}

class _AdminComplaintsScreenState extends State<AdminComplaintsScreen> {
  late Future<List<Complaint>> _complaintsFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _complaintsFuture = DI.adminRepo.getComplaints();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Complaint>>(
      future: _complaintsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ')));
        }
        
        final complaints = snapshot.data!;

        return Scaffold(
          backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Complaints & Support', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        itemCount: complaints.length,
        itemBuilder: (context, index) {
          final complaint = complaints[index];
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Case ${complaint.id}', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.statusContainerFromString(complaint.status.name), borderRadius: AppRadius.radiusSm),
                      child: Text(complaint.status.name.toUpperCase(), style: AppTypography.labelSm.copyWith(color: AppColors.statusTextColorFromString(complaint.status.name), fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Text(complaint.subject, style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
                const SizedBox(height: 4),
                Text(complaint.description, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.spacingSm),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Text('Cust: ${complaint.customerName}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.engineering, size: 16, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Text('Wrkr: ${complaint.workerName}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                if (complaint.status != ComplaintStatus.resolved && complaint.status != ComplaintStatus.closed)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        () async { await DI.adminRepo.updateComplaintStatus(complaint.id, ComplaintStatus.resolved); _refreshData(); }();
                      },
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                      child: const Text('Mark Resolved'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
        }
      );
  }
}
