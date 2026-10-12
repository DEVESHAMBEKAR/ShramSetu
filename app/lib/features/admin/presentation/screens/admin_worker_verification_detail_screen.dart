import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../shared/widgets/document_viewer/document_viewer_modal.dart';
import '../../../../core/models/insurance_models.dart';
import '../../../../core/models/federation_models.dart';
import '../../../worker/data/models/worker_models.dart';

class AdminWorkerVerificationDetailScreen extends StatefulWidget {
  final WorkerProfile worker;
  final bool? isSuperAdmin;

  const AdminWorkerVerificationDetailScreen({
    super.key,
    required this.worker,
    this.isSuperAdmin,
  });

  @override
  State<AdminWorkerVerificationDetailScreen> createState() =>
      _AdminWorkerVerificationDetailScreenState();
}

class _AdminWorkerVerificationDetailScreenState
    extends State<AdminWorkerVerificationDetailScreen> {
  late WorkerProfile _worker;
  List<Map<String, dynamic>> _documents = [];
  List<WorkerVerificationHistoryItem> _history = [];
  WorkerInsuranceModel? _insurance;
  bool _isLoading = true;
  bool _isProcessingAction = false;
  bool _isAccessDenied = false;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _worker = widget.worker;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      await FederationModel.fetchAllFederations();
      // 1. Check federation authority
      final scope = DI.federationScopeService;
      _isSuperAdmin = widget.isSuperAdmin ?? (scope != null ? await scope.hasGlobalScope() : false);
      if (!_isSuperAdmin) {
        final authIds = scope != null
            ? await scope.getAuthorizedFederationIds()
            : <String>[];
        final wFedId = _worker.federationRefId;

        final bool isAuthorized = authIds.isNotEmpty && wFedId != null && authIds.contains(wFedId);

        if (!isAuthorized) {
          if (mounted) {
            setState(() {
              _isAccessDenied = true;
              _isLoading = false;
            });
          }
          return;
        }
      }

      final docs = await DI.adminRepo.getWorkerDocuments(_worker.id);
      final history = await DI.adminRepo.getVerificationHistory(_worker.id);
      final workers = await DI.adminRepo.getWorkers();
      final fresh = workers.where((w) => w.id == _worker.id).firstOrNull;
      WorkerInsuranceModel? insurance;
      try {
        insurance = await DI.adminRepo.getWorkerInsurance(_worker.id);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _documents = docs;
          _history = history;
          _insurance = insurance;
          if (fresh != null) _worker = fresh;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Opens the document directly inside the app viewer modal.
  Future<void> _viewDocument(Map<String, dynamic> doc) async {
    await DocumentViewerModal.show(
      context,
      doc: doc,
      isAdmin: true,
      onApprove: () => _updateDocumentStatus(doc, 'APPROVED'),
      onFlag: () => _updateDocumentStatus(doc, 'FLAGGED'),
    );
  }

  /// Lets admin mark a single document as APPROVED or FLAGGED with optional remarks.
  Future<void> _updateDocumentStatus(Map<String, dynamic> doc, String newStatus) async {
    final docId = doc['id']?.toString() ?? '';
    final docType = (doc['document_type'] ?? 'DOCUMENT').toString().replaceAll('_', ' ');
    final remarksController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              newStatus == 'APPROVED' ? Icons.check_circle_outline : Icons.flag_outlined,
              color: newStatus == 'APPROVED' ? const Color(0xFF2E7D32) : AppColors.error,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(newStatus == 'APPROVED' ? 'Approve Document' : 'Flag Document', style: const TextStyle(fontSize: 15))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Document: $docType', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: InputDecoration(
                labelText: newStatus == 'APPROVED' ? 'Remarks (optional)' : 'Reason for flagging *',
                border: const OutlineInputBorder(),
                hintText: newStatus == 'APPROVED'
                    ? 'e.g. Identity verified against MSDE register'
                    : 'e.g. Photo blurry — re-upload required',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: newStatus == 'APPROVED' ? const Color(0xFF2E7D32) : AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (newStatus == 'FLAGGED' && remarksController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter a reason for flagging.')));
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: Text(newStatus == 'APPROVED' ? 'Approve' : 'Flag'),
          ),
        ],
      ),
    );

    if (confirmed == true && docId.isNotEmpty) {
      try {
        await DI.adminRepo.updateDocumentStatus(docId, newStatus, remarks: remarksController.text.trim());
        setState(() {
          final idx = _documents.indexWhere((d) => d['id'] == docId);
          if (idx != -1) _documents[idx] = Map<String, dynamic>.from(_documents[idx])..['status'] = newStatus;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: newStatus == 'APPROVED' ? AppColors.onTertiaryContainer : AppColors.error,
              content: Text(newStatus == 'APPROVED' ? '✓ Document approved.' : '⚑ Document flagged for re-upload.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _approveInsurance() async {
    setState(() => _isProcessingAction = true);
    try {
      final approved = await DI.adminRepo.approveWorkerInsurance(_worker.id);
      if (mounted) {
        setState(() {
          _insurance = approved;
          _isProcessingAction = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2E7D32),
            content: Text('✓ Insurance approved! Policy ${approved.policyNumber} generated.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingAction = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to approve insurance: $e'),
          ),
        );
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _handleStartReview() async {
    final remarksController = TextEditingController();
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.search, color: Color(0xFF1565C0)),
            SizedBox(width: 8),
            Text('Start Verification Review'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Begin formal verification review for ${_worker.name}? This marks the application as "Under Review".'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(
                labelText: 'Internal Review Notes (Optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g. Assigned to Pune desk for Aadhaar cross-check',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start Review'),
          ),
        ],
      ),
    );

    if (proceed == true) {
      _executeAction(
        actionName: 'Review Started',
        action: () => DI.adminRepo.startReview(_worker.id, remarks: remarksController.text.trim()),
      );
    }
  }

  Future<void> _handleApprove() async {
    final remarksController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF2E7D32)),
            SizedBox(width: 8),
            Text('Approve Artisan'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Confirm full approval for ${_worker.name}? They will gain immediate access to customer assignments and cooperative marketplace benefits.'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(
                labelText: 'Approval Remarks (Optional)',
                border: OutlineInputBorder(),
                hintText: 'e.g. Identity and trade credentials verified against MSDE register',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E7D32), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Approval'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeAction(
        actionName: 'Artisan Approved',
        action: () => DI.adminRepo.approveWorker(_worker.id, remarks: remarksController.text.trim()),
      );
    }
  }

  Future<void> _handleRequestChanges() async {
    final remarksController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_note, color: Color(0xFFE65100)),
            SizedBox(width: 8),
            Text('Request Changes / Corrections'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notify ${_worker.name} that changes or re-uploaded documents are required before approval:'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(
                labelText: 'Required Changes (Visible to Artisan) *',
                border: OutlineInputBorder(),
                hintText: 'e.g. Aadhaar photo is blurry. Please re-upload a clear copy and mention ward number.',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE65100), foregroundColor: Colors.white),
            onPressed: () {
              if (remarksController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please specify the required changes')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Send Change Request'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeAction(
        actionName: 'Changes Requested',
        action: () => DI.adminRepo.requestChanges(_worker.id, remarks: remarksController.text.trim()),
      );
    }
  }

  Future<void> _handleReject() async {
    final remarksController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel, color: AppColors.error),
            SizedBox(width: 8),
            Text('Reject Application'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject the application for ${_worker.name}?'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason *',
                border: OutlineInputBorder(),
                hintText: 'e.g. Fraudulent documents detected or trade unverified',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () {
              if (remarksController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please enter rejection reason')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeAction(
        actionName: 'Application Rejected',
        action: () => DI.adminRepo.rejectWorker(_worker.id, remarks: remarksController.text.trim()),
      );
    }
  }

  Future<void> _handleSuspend() async {
    final remarksController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block, color: Color(0xFFB71C1C)),
            SizedBox(width: 8),
            Text('Suspend Artisan Account'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Suspend ${_worker.name}? This will revoke their access to customer job dispatch and active assignments immediately.'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(
                labelText: 'Suspension Reason *',
                border: OutlineInputBorder(),
                hintText: 'e.g. Repeated customer complaints or disciplinary action',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB71C1C), foregroundColor: Colors.white),
            onPressed: () {
              if (remarksController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Please specify suspension reason')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Suspend Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _executeAction(
        actionName: 'Account Suspended',
        action: () => DI.adminRepo.suspendWorker(_worker.id, remarks: remarksController.text.trim()),
      );
    }
  }

  Future<void> _handleTransferFederation() async {
    final allFederations = await FederationModel.fetchAllFederations(forceRefresh: true);
    final activeFederations = allFederations.where((f) => f.isActive).toList();
    final candidates = activeFederations.isNotEmpty ? activeFederations : allFederations;

    // Pick first candidate that is not the current worker's federation
    final otherFederations = candidates.where((f) =>
      f.id != _worker.federationRefId &&
      f.name.toLowerCase().trim() != _worker.guildName.toLowerCase().trim()
    ).toList();

    final initialFed = otherFederations.isNotEmpty ? otherFederations.first : candidates.first;
    String? selectedFedId = initialFed.id;
    String selectedFedName = initialFed.name;
    final reasonController = TextEditingController();

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.swap_horiz, color: Color(0xFF6A1B9A)),
              SizedBox(width: 8),
              Text('Transfer Federation'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer ${_worker.name} from "${_worker.guildName}" to another cooperative federation.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedFedId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Target Federation *',
                  border: OutlineInputBorder(),
                ),
                items: candidates.map((fed) {
                  final isCurrent = fed.id == _worker.federationRefId ||
                      fed.name.toLowerCase().trim() == _worker.guildName.toLowerCase().trim();
                  final locationStr = fed.city.isNotEmpty ? fed.city : fed.district;
                  return DropdownMenuItem(
                    value: fed.id,
                    enabled: !isCurrent,
                    child: Text(
                      '${fed.name}${locationStr.isNotEmpty ? ' ($locationStr)' : ''}${isCurrent ? ' [Current]' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isCurrent ? Colors.grey : Colors.black87,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    final target = candidates.firstWhere(
                      (f) => f.id == val,
                      orElse: () => candidates.first,
                    );
                    setDialogState(() {
                      selectedFedId = val;
                      selectedFedName = target.name;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Transfer Justification / Reason *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Relocation, regional restructuring',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A), foregroundColor: Colors.white),
              onPressed: () {
                if (selectedFedId == _worker.federationRefId ||
                    selectedFedName.toLowerCase().trim() == _worker.guildName.toLowerCase().trim()) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please select a different target federation')),
                  );
                  return;
                }
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please specify transfer justification')),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Confirm Transfer'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedFedId != null) {
      _executeAction(
        actionName: 'Artisan Transferred to $selectedFedName',
        action: () => DI.adminRepo.transferWorkerFederation(
          _worker.id,
          selectedFedId!,
          selectedFedName,
          reason: reasonController.text.trim(),
        ),
      );
    }
  }

  Future<void> _executeAction({
    required String actionName,
    required Future<void> Function() action,
  }) async {
    setState(() => _isProcessingAction = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.onTertiaryContainer,
            content: Text('✓ $actionName successfully updated.'),
          ),
        );
      }
      await _loadDetails();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.error,
            content: Text('Failed to update status: $e'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingAction = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Artisan Verification File',
          style: AppTypography.titleMd.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh file',
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _loadDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _isAccessDenied
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.gpp_bad, size: 64, color: AppColors.error),
                        const SizedBox(height: 16),
                        const Text(
                          'Cooperative Federation Access Restricted',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Artisan "${_worker.name}" is registered under another cooperative federation (${_worker.federationName}). Under cooperative data isolation policies, only officers of that federation or National Super Admins can access, view, or verify this dossier.',
                          style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, height: 1.4),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Return to Verification Desk'),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.marginMobile),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderCard(),
                          const SizedBox(height: 16),
                          _buildActionButtonsCard(),
                          const SizedBox(height: 16),
                          _buildProfileInfoCard(),
                          const SizedBox(height: 16),
                          _buildWorkSkillsCard(),
                          const SizedBox(height: 16),
                          _buildCooperativeCard(),
                          const SizedBox(height: 16),
                          _buildInsuranceWelfareCard(),
                          const SizedBox(height: 16),
                          _buildDocumentsCard(),
                          const SizedBox(height: 16),
                          _buildVerificationHistoryCard(),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _buildHeaderCard() {
    final status = _worker.verificationStatus;
    Color statusBg = const Color(0xFFFFE0B2);
    Color statusText = const Color(0xFFE65100);
    String statusLabel = 'PENDING';

    switch (status) {
      case VerificationStatus.approved:
        statusBg = const Color(0xFFC8E6C9);
        statusText = const Color(0xFF2E7D32);
        statusLabel = 'APPROVED';
        break;
      case VerificationStatus.underReview:
        statusBg = const Color(0xFFBBDEFB);
        statusText = const Color(0xFF1565C0);
        statusLabel = 'UNDER REVIEW';
        break;
      case VerificationStatus.changesRequired:
        statusBg = const Color(0xFFFFE082);
        statusText = const Color(0xFFE65100);
        statusLabel = 'CHANGES REQUIRED';
        break;
      case VerificationStatus.rejected:
        statusBg = const Color(0xFFFFCDD2);
        statusText = const Color(0xFFC62828);
        statusLabel = 'REJECTED';
        break;
      case VerificationStatus.suspended:
        statusBg = const Color(0xFFFFCDD2);
        statusText = const Color(0xFFB71C1C);
        statusLabel = 'SUSPENDED';
        break;
      case VerificationStatus.pending:
      case VerificationStatus.notSubmitted:
        statusBg = const Color(0xFFFFE0B2);
        statusText = const Color(0xFFE65100);
        statusLabel = 'PENDING';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primaryContainer,
                backgroundImage:
                    _worker.profileImage.isNotEmpty ? NetworkImage(_worker.profileImage) : null,
                child: _worker.profileImage.isEmpty
                    ? Text(
                        _worker.name.isNotEmpty ? _worker.name[0].toUpperCase() : 'W',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            _worker.name,
                            style: AppTypography.titleLg.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_worker.trade?.isNotEmpty == true ? _worker.trade! : (_worker.skills.isNotEmpty ? _worker.skills.first : "General Artisan")} • ${_worker.skillLevel?.isNotEmpty == true ? _worker.skillLevel! : "Skilled"}',
                      style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Worker ID: ${_worker.id.length > 12 ? _worker.id.substring(0, 12) : _worker.id} • Phone: ${_worker.phone}',
                      style: const TextStyle(fontSize: 12, color: AppColors.outline),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_worker.verificationRemarks?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Active Verification Remarks:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.outline),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _worker.verificationRemarks!,
                    style: const TextStyle(fontSize: 13, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtonsCard() {
    final status = _worker.verificationStatus;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Verification Actions',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (_isProcessingAction)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (status == VerificationStatus.pending || status == VerificationStatus.notSubmitted)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isProcessingAction ? null : _handleStartReview,
                  icon: const Icon(Icons.search, size: 16),
                  label: const Text('Start Review'),
                ),
              if (status != VerificationStatus.approved)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: _isProcessingAction ? null : _handleApprove,
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Approve Worker'),
                ),
              if (status != VerificationStatus.changesRequired && status != VerificationStatus.rejected)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE65100),
                    side: const BorderSide(color: Color(0xFFE65100)),
                  ),
                  onPressed: _isProcessingAction ? null : _handleRequestChanges,
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text('Request Changes'),
                ),
              if (status != VerificationStatus.rejected && status != VerificationStatus.suspended)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  onPressed: _isProcessingAction ? null : _handleReject,
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('Reject Application'),
                ),
              if (status == VerificationStatus.approved)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFB71C1C),
                    side: const BorderSide(color: Color(0xFFB71C1C)),
                  ),
                  onPressed: _isProcessingAction ? null : _handleSuspend,
                  icon: const Icon(Icons.block, size: 16),
                  label: const Text('Suspend Account'),
                ),
              if (_isSuperAdmin)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6A1B9A),
                    side: const BorderSide(color: Color(0xFF6A1B9A)),
                  ),
                  onPressed: _isProcessingAction ? null : _handleTransferFederation,
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Transfer Federation'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Personal & Address Information',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow('Full Name', _worker.name),
          _buildInfoRow('Phone Number', _worker.phone),
          _buildInfoRow('Date of Birth', _worker.dob?.isNotEmpty == true ? _worker.dob! : 'Not specified'),
          _buildInfoRow('Gender', _worker.gender?.isNotEmpty == true ? _worker.gender! : 'Not specified'),
          _buildInfoRow('Current Address', _worker.address?.isNotEmpty == true ? _worker.address! : _worker.serviceLocation),
          _buildInfoRow('District', _worker.district?.isNotEmpty == true ? _worker.district! : 'Pune District'),
          _buildInfoRow('PIN Code', _worker.pincode?.isNotEmpty == true ? _worker.pincode! : 'Not specified'),
        ],
      ),
    );
  }

  Widget _buildWorkSkillsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.handyman_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Trade & Skill Qualifications',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoRow('Trade Category', _worker.trade?.isNotEmpty == true ? _worker.trade! : (_worker.skills.isNotEmpty ? _worker.skills.first : 'Artisan')),
          _buildInfoRow('Primary Skill', _worker.primarySkill?.isNotEmpty == true ? _worker.primarySkill! : (_worker.skills.isNotEmpty ? _worker.skills.join(', ') : 'Not specified')),
          _buildInfoRow('Proficiency Level', _worker.skillLevel?.isNotEmpty == true ? _worker.skillLevel! : 'Skilled Artisan'),
          _buildInfoRow('Experience', _worker.experience),
          _buildInfoRow('Service Area / Operational Ward', _worker.serviceLocation),
          _buildInfoRow('Dispatch Availability', _worker.isAvailable ? 'Available for Bookings' : 'Currently Offline'),
        ],
      ),
    );
  }

  Widget _buildCooperativeCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Cooperative & Federation Affiliation',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          () {
            final pool = FederationModel.activePool;
            final fed = (_worker.federationRefId != null && _worker.federationRefId!.isNotEmpty)
                ? pool.firstWhere(
                    (f) => f.id == _worker.federationRefId,
                    orElse: () => FederationModel.resolveFederation(
                      federationId: _worker.federationRefId,
                      federationName: _worker.federationName,
                      district: _worker.district,
                      city: _worker.city,
                      location: _worker.serviceLocation,
                      address: _worker.address,
                    ),
                  )
                : FederationModel.resolveFederation(
                    federationName: _worker.federationName,
                    district: _worker.district,
                    city: _worker.city,
                    location: _worker.serviceLocation,
                    address: _worker.address,
                  );
            final memId = (_worker.membershipId?.isNotEmpty == true && _worker.membershipId != 'Pending Assignment')
                ? _worker.membershipId!
                : ((_worker.guildId.isNotEmpty && _worker.guildId != 'None' && _worker.guildId != '#' && _worker.guildId != 'Pending Assignment')
                    ? _worker.guildId
                    : 'FED-${fed.city.substring(0, fed.city.length >= 3 ? 3 : fed.city.length).toUpperCase()}-2024-${_worker.id.replaceAll(RegExp(r'[^0-9]'), '').padRight(4, '7').substring(0, 4)}');

            final displayFedName = (_worker.guildName.isNotEmpty &&
                    _worker.guildName != 'None' &&
                    _worker.guildName != '#' &&
                    _worker.guildName != 'General Guild')
                ? _worker.guildName
                : fed.name;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Federation Name', displayFedName),
                _buildInfoRow('Membership / Guild ID', memId),
                _buildInfoRow('Artisan Charter Declaration', 'Accepted on Registration'),
              ],
            );
          }(),
        ],
      ),
    );
  }

  Widget _buildInsuranceWelfareCard() {
    final ins = _insurance;
    final isPending = ins?.isPendingApproval ?? false;
    final isApproved = ins?.isApproved ?? false;

    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    if (isApproved) {
      badgeBg = AppColors.tertiaryContainer;
      badgeText = AppColors.onTertiaryContainer;
      badgeLabel = 'Active Policy';
    } else if (isPending) {
      badgeBg = AppColors.warningContainer;
      badgeText = AppColors.onWarningContainer;
      badgeLabel = 'Pending Approval';
    } else {
      badgeBg = const Color(0xFFF3F4F6);
      badgeText = const Color(0xFF4B5563);
      badgeLabel = 'Not Applied';
    }

    final policyNum = isApproved
        ? ins!.maskedPolicyNumber
        : (isPending ? 'Pending Issuance (Requires Admin Approval)' : 'Not Applied');
    final provider = ins?.providerName ?? 'Maharashtra State Cooperative Labour Federation Welfare Pool';
    final amt = '₹${(ins?.coverageAmount ?? 500000.0).toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.health_and_safety_outlined, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Welfare & Group Insurance',
                    style: AppTypography.titleMd.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeText),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  isApproved ? Icons.verified_outlined : Icons.info_outline,
                  size: 14,
                  color: isApproved ? AppColors.onTertiaryContainer : AppColors.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isApproved
                        ? 'External insurance provider integration pending. Group coverage active via Federation Welfare Fund.'
                        : (isPending
                            ? 'Worker submitted group insurance application. Admin approval required to generate policy number and issue certificate.'
                            : 'Worker has not applied for group insurance coverage yet. Coverage is not automatically active until applied and approved.'),
                    style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildInfoRow('Insurance Scheme', ins?.coverageType ?? 'Accidental & Medical Health Cover'),
          _buildInfoRow('Policy Number', policyNum),
          _buildInfoRow('Welfare Provider', provider),
          _buildInfoRow('Coverage Limit', amt),
          _buildInfoRow('Emergency Support', ins?.claimSupportPhone ?? '1800-266-9090'),
          if (isApproved && ins != null) ...[
            _buildInfoRow('Effective From', ins.startDate.toIso8601String().split('T').first),
            _buildInfoRow('Valid Until', ins.expiryDate.toIso8601String().split('T').first),
          ],
          if (!isApproved) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.verified_user_outlined, size: 18),
                label: Text(
                  isPending
                      ? 'Approve Insurance & Generate Policy'
                      : 'Enroll Worker & Issue Group Policy',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: _isProcessingAction ? null : _approveInsurance,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocumentsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_shared_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Verification Documents',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_documents.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'No uploaded document records found. Worker may have registered via fast onboarding.',
                style: TextStyle(fontSize: 12, color: AppColors.outline),
              ),
            )
          else
            ..._documents.map((d) {
              final docType = d['document_type']?.toString() ?? 'DOCUMENT';
              final fileName = d['file_name']?.toString() ?? 'Document';
              final mimeType = d['mime_type']?.toString() ?? '';
              final status = d['status']?.toString().toUpperCase() ?? 'PENDING';
              final fileSize = (d['file_size'] as int?) ?? 0;
              final isPdf = mimeType.contains('pdf') || fileName.toLowerCase().endsWith('.pdf');
              final isImage = mimeType.startsWith('image/');
              final isApproved = status == 'APPROVED';
              final isFlagged = status == 'FLAGGED';

              Color statusColor;
              Color statusTextColor;
              IconData statusIcon;
              if (isApproved) {
                statusColor = AppColors.tertiaryContainer;
                statusTextColor = AppColors.onTertiaryContainer;
                statusIcon = Icons.check_circle;
              } else if (isFlagged) {
                statusColor = AppColors.errorContainer;
                statusTextColor = AppColors.error;
                statusIcon = Icons.flag;
              } else {
                statusColor = AppColors.warningContainer;
                statusTextColor = AppColors.onWarningContainer;
                statusIcon = Icons.hourglass_top_rounded;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isApproved
                        ? const Color(0xFF81C784)
                        : isFlagged
                            ? AppColors.error.withValues(alpha: 0.5)
                            : AppColors.outlineVariant,
                    width: isApproved || isFlagged ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isPdf
                                  ? AppColors.error.withValues(alpha: 0.1)
                                  : isImage
                                      ? AppColors.primaryContainer
                                      : AppColors.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isPdf
                                  ? Icons.picture_as_pdf_outlined
                                  : isImage
                                      ? Icons.image_outlined
                                      : Icons.insert_drive_file_outlined,
                              color: isPdf ? AppColors.error : AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  docType.replaceAll('_', ' '),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppColors.primary,
                                  ),
                                ),
                                Text(
                                  fileName,
                                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (fileSize > 0)
                                  Text(
                                    _formatBytes(fileSize),
                                    style: const TextStyle(fontSize: 10, color: AppColors.outline),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 10, color: statusTextColor),
                                const SizedBox(width: 3),
                                Text(
                                  status,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: statusTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action row
                    Container(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: Row(
                        children: [
                          // VIEW button
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: () => _viewDocument(d),
                              icon: const Icon(Icons.open_in_new, size: 14),
                              label: const Text('View', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // APPROVE button
                          if (!isApproved)
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _updateDocumentStatus(d, 'APPROVED'),
                                icon: const Icon(Icons.check, size: 14),
                                label: const Text('Approve', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          const SizedBox(width: 6),
                          // FLAG button
                          if (!isFlagged)
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  foregroundColor: AppColors.error,
                                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _updateDocumentStatus(d, 'FLAGGED'),
                                icon: const Icon(Icons.flag_outlined, size: 14),
                                label: const Text('Flag', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildVerificationHistoryCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Verification Audit History',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_history.isEmpty)
            const Text(
              'No previous review actions recorded yet.',
              style: TextStyle(fontSize: 12, color: AppColors.outline),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _history.length,
              separatorBuilder: (_, _) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final item = _history[index];
                final timeStr = item.createdAt.toLocal().toString().split('.').first;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 14, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.action.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary),
                              ),
                              Text(
                                timeStr,
                                style: const TextStyle(fontSize: 10, color: AppColors.outline),
                              ),
                            ],
                          ),
                          if (item.remarks?.isNotEmpty == true) ...[
                            const SizedBox(height: 2),
                            Text(
                              item.remarks!,
                              style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                            ),
                          ],
                          if (item.reviewedBy?.isNotEmpty == true) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Reviewed by: ${item.reviewedBy}',
                              style: const TextStyle(fontSize: 10, color: AppColors.outline),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.outline, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
