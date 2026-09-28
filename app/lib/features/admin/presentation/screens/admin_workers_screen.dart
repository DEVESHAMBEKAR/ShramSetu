import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../worker/data/models/worker_models.dart';
import 'admin_worker_verification_detail_screen.dart';

class AdminWorkersScreen extends StatefulWidget {
  const AdminWorkersScreen({super.key});

  @override
  State<AdminWorkersScreen> createState() => _AdminWorkersScreenState();
}

class _AdminWorkersScreenState extends State<AdminWorkersScreen> {
  late Future<List<WorkerProfile>> _workersFuture;
  int _selectedFilterIndex = 1; // 0: All, 1: Pending, 2: Under Review, 3: Changes Required, 4: Approved, 5: Rejected, 6: Suspended
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshData() {
    setState(() {
      _workersFuture = DI.adminRepo.getWorkers();
    });
  }

  Future<void> _openDetailScreen(WorkerProfile worker) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminWorkerVerificationDetailScreen(worker: worker),
      ),
    );
    _refreshData();
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
    final reasonController = TextEditingController();
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject the application for ${worker.name}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DI.adminRepo.rejectWorker(worker.id, remarks: reasonController.text.trim());
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
        final underReviewWorkers = allWorkers.where((w) => w.verificationStatus == VerificationStatus.underReview).toList();
        final changesRequiredWorkers = allWorkers.where((w) => w.verificationStatus == VerificationStatus.changesRequired).toList();
        final approvedWorkers = allWorkers.where((w) => w.verificationStatus == VerificationStatus.approved).toList();
        final rejectedWorkers = allWorkers.where((w) => w.verificationStatus == VerificationStatus.rejected).toList();
        final suspendedWorkers = allWorkers.where((w) => w.verificationStatus == VerificationStatus.suspended).toList();

        List<WorkerProfile> filteredByStatus;
        switch (_selectedFilterIndex) {
          case 1:
            filteredByStatus = pendingWorkers;
            break;
          case 2:
            filteredByStatus = underReviewWorkers;
            break;
          case 3:
            filteredByStatus = changesRequiredWorkers;
            break;
          case 4:
            filteredByStatus = approvedWorkers;
            break;
          case 5:
            filteredByStatus = rejectedWorkers;
            break;
          case 6:
            filteredByStatus = suspendedWorkers;
            break;
          case 0:
          default:
            filteredByStatus = allWorkers;
            break;
        }

        // Apply search filter
        final displayedWorkers = filteredByStatus.where((w) {
          if (_searchQuery.isEmpty) return true;
          final q = _searchQuery.toLowerCase();
          return w.name.toLowerCase().contains(q) ||
              w.phone.toLowerCase().contains(q) ||
              w.id.toLowerCase().contains(q) ||
              (w.trade?.toLowerCase().contains(q) ?? false) ||
              (w.primarySkill?.toLowerCase().contains(q) ?? false) ||
              w.federationName.toLowerCase().contains(q) ||
              w.serviceLocation.toLowerCase().contains(q);
        }).toList();

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
              _buildSearchBar(),
              _buildFilterBar(
                allCount: allWorkers.length,
                pendingCount: pendingWorkers.length,
                underReviewCount: underReviewWorkers.length,
                changesRequiredCount: changesRequiredWorkers.length,
                approvedCount: approvedWorkers.length,
                rejectedCount: rejectedWorkers.length,
                suspendedCount: suspendedWorkers.length,
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

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by Name, Phone, ID, Trade, Cooperative...',
          hintStyle: const TextStyle(fontSize: 13, color: AppColors.outline),
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.outline),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
      ),
    );
  }

  Widget _buildFilterBar({
    required int allCount,
    required int pendingCount,
    required int underReviewCount,
    required int changesRequiredCount,
    required int approvedCount,
    required int rejectedCount,
    required int suspendedCount,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(0, 'All ($allCount)'),
            const SizedBox(width: 8),
            _buildFilterChip(1, 'Pending ($pendingCount)', hasBadge: pendingCount > 0, badgeColor: const Color(0xFFFFB74D)),
            const SizedBox(width: 8),
            _buildFilterChip(2, 'Under Review ($underReviewCount)', hasBadge: underReviewCount > 0, badgeColor: const Color(0xFF64B5F6)),
            const SizedBox(width: 8),
            _buildFilterChip(3, 'Changes Required ($changesRequiredCount)', hasBadge: changesRequiredCount > 0, badgeColor: const Color(0xFFFFB74D)),
            const SizedBox(width: 8),
            _buildFilterChip(4, 'Approved ($approvedCount)'),
            const SizedBox(width: 8),
            _buildFilterChip(5, 'Rejected ($rejectedCount)'),
            const SizedBox(width: 8),
            _buildFilterChip(6, 'Suspended ($suspendedCount)'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label, {bool hasBadge = false, Color? badgeColor}) {
    final isSelected = _selectedFilterIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: hasBadge && badgeColor != null ? badgeColor : AppColors.primary,
      backgroundColor: AppColors.surfaceContainerLow,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected
            ? (hasBadge && badgeColor != null ? Colors.brown.shade900 : Colors.white)
            : AppColors.onSurfaceVariant,
      ),
      onSelected: (_) => setState(() => _selectedFilterIndex = index),
    );
  }

  Widget _buildEmptyState() {
    String message = 'No artisans found';
    if (_searchQuery.isNotEmpty) {
      message = 'No artisans match "$_searchQuery"';
    } else if (_selectedFilterIndex == 1) {
      message = '🎉 No pending applications awaiting verification!';
    } else if (_selectedFilterIndex == 2) {
      message = 'No applications currently under review';
    } else if (_selectedFilterIndex == 3) {
      message = 'No change requests currently pending';
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
    final status = worker.verificationStatus;
    final isPending = status == VerificationStatus.pending;
    final isUnderReview = status == VerificationStatus.underReview;

    return InkWell(
      onTap: () => _openDetailScreen(worker),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPending || isUnderReview ? const Color(0xFFFFB74D) : AppColors.outlineVariant,
            width: isPending || isUnderReview ? 1.5 : 1,
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
                              _getVerifLabel(worker.verificationStatus),
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
                        '${worker.trade?.isNotEmpty == true ? worker.trade! : (worker.skills.isNotEmpty ? worker.skills.join(", ") : "Artisan")} • ${worker.skillLevel?.isNotEmpty == true ? worker.skillLevel! : worker.experience}',
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
            if (worker.verificationRemarks?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Remarks: ${worker.verificationRemarks}',
                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Fed: ${worker.federationName.isNotEmpty ? worker.federationName : (worker.guildId != "None" ? worker.guildId : "Pune Federation")}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Jobs: ${worker.completedJobs}',
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
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
                    onPressed: () => _openDetailScreen(worker),
                    icon: const Icon(Icons.folder_shared_outlined, size: 16),
                    label: const Text('View File & Review', style: TextStyle(fontSize: 12)),
                  ),
                ),
                if (isPending || isUnderReview) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
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
      ),
    );
  }

  String _getVerifLabel(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.approved:
        return 'VERIFIED ACTIVE';
      case VerificationStatus.underReview:
        return 'UNDER REVIEW';
      case VerificationStatus.changesRequired:
        return 'CHANGES REQ';
      case VerificationStatus.rejected:
        return 'REJECTED';
      case VerificationStatus.suspended:
        return 'SUSPENDED';
      case VerificationStatus.pending:
      case VerificationStatus.notSubmitted:
        return 'PENDING';
    }
  }

  Color _getVerifBgColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.approved:
        return AppColors.tertiaryContainer;
      case VerificationStatus.underReview:
        return const Color(0xFFBBDEFB);
      case VerificationStatus.changesRequired:
        return const Color(0xFFFFE082);
      case VerificationStatus.pending:
      case VerificationStatus.notSubmitted:
        return const Color(0xFFFFE0B2);
      case VerificationStatus.rejected:
      case VerificationStatus.suspended:
        return AppColors.errorContainer;
    }
  }

  Color _getVerifTextColor(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.approved:
        return AppColors.onTertiaryContainer;
      case VerificationStatus.underReview:
        return const Color(0xFF1565C0);
      case VerificationStatus.changesRequired:
        return const Color(0xFFE65100);
      case VerificationStatus.pending:
      case VerificationStatus.notSubmitted:
        return const Color(0xFFE65100);
      case VerificationStatus.rejected:
      case VerificationStatus.suspended:
        return AppColors.onErrorContainer;
    }
  }
}
