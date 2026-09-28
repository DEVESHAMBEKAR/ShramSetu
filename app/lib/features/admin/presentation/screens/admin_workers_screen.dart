import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../worker/data/models/worker_models.dart';

class AdminWorkersScreen extends StatefulWidget {
  const AdminWorkersScreen({super.key});

  @override
  State<AdminWorkersScreen> createState() => _AdminWorkersScreenState();
}

class _AdminWorkersScreenState extends State<AdminWorkersScreen> {
  late Future<List<WorkerProfile>> _workersFuture;
  int _selectedFilterIndex = 0; // 0: Pending, 1: All, 2: Active, 3: Rejected

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _workersFuture = DI.adminRepo.getWorkers();
    });
  }

  Future<void> _approveWorker(WorkerProfile worker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified, color: AppColors.onTertiaryContainer),
            SizedBox(width: 8),
            Text('Approve Artisan'),
          ],
        ),
        content: Text(
          'Are you sure you want to approve ${worker.name}? Their trade credentials and documents will be marked as verified, granting them immediate access to receive customer jobs.',
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
            child: const Text('Confirm Approval'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DI.adminRepo.approveWorker(worker.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.onTertiaryContainer,
              content: Text('✓ ${worker.name} approved! Full access granted.'),
            ),
          );
        }
        _refreshData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to approve worker: $e')),
          );
        }
      }
    }
  }

  Future<void> _rejectWorker(WorkerProfile worker) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.error),
            SizedBox(width: 8),
            Text('Reject Application'),
          ],
        ),
        content: Text(
          'Are you sure you want to reject the application for ${worker.name}? They will be notified to review and re-submit required documents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DI.adminRepo.rejectWorker(worker.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Application for ${worker.name} marked as rejected.')),
          );
        }
        _refreshData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reject worker: $e')),
          );
        }
      }
    }
  }

  Future<void> _showDocumentsModal(WorkerProfile worker) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: DI.adminRepo.getWorkerDocuments(worker.id),
          builder: (context, snapshot) {
            final docs = snapshot.data ?? [];
            final isLoading = snapshot.connectionState == ConnectionState.waiting;

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.folder_shared_outlined, color: AppColors.primary, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'Submitted Verification Documents',
                            style: AppTypography.titleMd.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Artisan: ${worker.name} • ${worker.phone}',
                    style: const TextStyle(fontSize: 12, color: AppColors.outline),
                  ),
                  const Divider(height: 20),
                  if (isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  else if (docs.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.description_outlined, size: 36, color: AppColors.outline),
                          SizedBox(height: 8),
                          Text(
                            'No documents found on record',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Worker has registered basic details but has not uploaded attachments yet.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: AppColors.outline),
                          ),
                        ],
                      ),
                    )
                  else
                    ...docs.map((d) {
                      final docType = d['document_type']?.toString() ?? 'DOCUMENT';
                      final fileName = d['file_name']?.toString() ?? 'Document';
                      final fileSize = d['file_size'];
                      final sizeStr = fileSize != null ? ' (${(fileSize / 1024).toStringAsFixed(1)} KB)' : '';
                      final status = d['status']?.toString().toUpperCase() ?? 'PENDING';

                      IconData docIcon = Icons.badge_outlined;
                      String docTitle = 'Identity Proof';
                      if (docType == 'ADDRESS') {
                        docIcon = Icons.home_outlined;
                        docTitle = 'Address Proof';
                      } else if (docType == 'SKILL_CERTIFICATE') {
                        docIcon = Icons.school_outlined;
                        docTitle = 'Trade Certificate';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(docIcon, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    docTitle,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                                  ),
                                  Text(
                                    '$fileName$sizeStr',
                                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: status == 'APPROVED' ? AppColors.tertiaryContainer : AppColors.warningContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: status == 'APPROVED' ? AppColors.onTertiaryContainer : AppColors.onWarningContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 16),
                  if (worker.verificationStatus == VerificationStatus.pending) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: const BorderSide(color: AppColors.outlineVariant),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _rejectWorker(worker);
                            },
                            child: const Text('Reject Application'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _approveWorker(worker);
                            },
                            child: const Text('Approve & Verify'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<WorkerProfile>>(
      future: _workersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('Failed to load workers: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final allWorkers = snapshot.data ?? [];
        final pendingWorkers = allWorkers.where((w) => w.verificationStatus == VerificationStatus.pending).toList();
        final activeWorkers = allWorkers.where((w) => w.verificationStatus == VerificationStatus.approved).toList();
        final rejectedWorkers = allWorkers.where((w) => w.verificationStatus == VerificationStatus.rejected).toList();

        List<WorkerProfile> displayedWorkers;
        switch (_selectedFilterIndex) {
          case 0:
            displayedWorkers = pendingWorkers;
            break;
          case 2:
            displayedWorkers = activeWorkers;
            break;
          case 3:
            displayedWorkers = rejectedWorkers;
            break;
          default:
            displayedWorkers = allWorkers;
            break;
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              'Artisan Verification & Guild Desk',
              style: AppTypography.titleLg.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh, color: AppColors.primary),
                onPressed: _refreshData,
              ),
            ],
          ),
          body: Column(
            children: [
              _buildFilterBar(
                allCount: allWorkers.length,
                pendingCount: pendingWorkers.length,
                activeCount: activeWorkers.length,
                rejectedCount: rejectedWorkers.length,
              ),
              Expanded(
                child: displayedWorkers.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async => _refreshData(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(AppSpacing.marginMobile),
                          itemCount: displayedWorkers.length,
                          itemBuilder: (context, index) {
                            final worker = displayedWorkers[index];
                            return _buildWorkerCard(worker);
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterBar({
    required int allCount,
    required int pendingCount,
    required int activeCount,
    required int rejectedCount,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(0, 'Pending Approval ($pendingCount)', hasBadge: pendingCount > 0),
            const SizedBox(width: 8),
            _buildFilterChip(1, 'All Artisans ($allCount)'),
            const SizedBox(width: 8),
            _buildFilterChip(2, 'Active ($activeCount)'),
            const SizedBox(width: 8),
            _buildFilterChip(3, 'Rejected ($rejectedCount)'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, {bool hasBadge = false}) {
    final isSelected = _selectedFilterIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: hasBadge ? const Color(0xFFFFB74D) : AppColors.primary,
      backgroundColor: AppColors.surfaceContainerLow,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? (hasBadge ? Colors.brown.shade900 : Colors.white)
            : AppColors.onSurfaceVariant,
      ),
      onSelected: (_) => setState(() => _selectedFilterIndex = index),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No artisans found';
    if (_selectedFilterIndex == 0) {
      message = '🎉 All pending applications have been verified!';
    } else if (_selectedFilterIndex == 2) {
      message = 'No active approved artisans found';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.assignment_turned_in_outlined, size: 54, color: AppColors.outline),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          const Text(
            'New registrations will appear here for federation officer review.',
            style: TextStyle(fontSize: 12, color: AppColors.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(WorkerProfile worker) {
    final isPending = worker.verificationStatus == VerificationStatus.pending;
    final isApproved = worker.verificationStatus == VerificationStatus.approved;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? const Color(0xFFFFB74D) : AppColors.outlineVariant,
          width: isPending ? 1.5 : 1,
        ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryContainer,
                backgroundImage: worker.profileImage.isNotEmpty ? NetworkImage(worker.profileImage) : null,
                child: worker.profileImage.isEmpty
                    ? Text(
                        worker.name.isNotEmpty ? worker.name[0].toUpperCase() : 'W',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            worker.name,
                            style: AppTypography.titleMd.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getVerifBgColor(worker.verificationStatus),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isApproved ? 'VERIFIED ACTIVE' : (isPending ? 'UNDER VERIFICATION' : 'REJECTED'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getVerifTextColor(worker.verificationStatus),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${worker.skills.isNotEmpty ? worker.skills.join(", ") : "Artisan"} • ${worker.experience}',
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${worker.phone} • ${worker.serviceLocation}',
                      style: const TextStyle(fontSize: 11, color: AppColors.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Guild: ${worker.guildId != "None" ? worker.guildId : "Pune Federation"}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
                Text(
                  'Jobs Done: ${worker.completedJobs}',
                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
                Row(
                  children: [
                    const Icon(Icons.star, size: 13, color: AppColors.starRating),
                    const SizedBox(width: 2),
                    Text(
                      worker.rating > 0 ? worker.rating.toStringAsFixed(1) : 'New',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: const BorderSide(color: AppColors.outlineVariant),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () => _showDocumentsModal(worker),
                  icon: const Icon(Icons.description_outlined, size: 16),
                  label: const Text('View Documents', style: TextStyle(fontSize: 12)),
                ),
              ),
              if (isPending) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => _approveWorker(worker),
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Approve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Reject',
                  icon: const Icon(Icons.cancel_outlined, color: AppColors.error, size: 20),
                  onPressed: () => _rejectWorker(worker),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _getVerifBgColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.approved:
        return AppColors.tertiaryContainer;
      case VerificationStatus.pending:
        return const Color(0xFFFFE0B2);
      case VerificationStatus.rejected:
        return AppColors.errorContainer;
      default:
        return AppColors.surfaceContainerLow;
    }
  }

  Color _getVerifTextColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.approved:
        return AppColors.onTertiaryContainer;
      case VerificationStatus.pending:
        return const Color(0xFFE65100);
      case VerificationStatus.rejected:
        return AppColors.onErrorContainer;
      default:
        return AppColors.onSurfaceVariant;
    }
  }
}
