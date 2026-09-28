import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/repositories/i_storage_repository.dart';
import '../../../worker/data/models/worker_models.dart';

class AdminWorkerVerificationDetailScreen extends StatefulWidget {
  final WorkerProfile worker;

  const AdminWorkerVerificationDetailScreen({
    super.key,
    required this.worker,
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
  bool _isLoading = true;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _worker = widget.worker;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final docs = await DI.adminRepo.getWorkerDocuments(_worker.id);
      final history = await DI.adminRepo.getVerificationHistory(_worker.id);
      final workers = await DI.adminRepo.getWorkers();
      final fresh = workers.where((w) => w.id == _worker.id).firstOrNull;

      if (mounted) {
        setState(() {
          _documents = docs;
          _history = history;
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

  /// Opens the document — generates a signed URL for private bucket and copies/shows it.
  Future<void> _viewDocument(Map<String, dynamic> doc) async {
    final storagePath = doc['storage_path']?.toString() ?? '';
    final fileName = doc['file_name']?.toString() ?? 'Document';
    final mimeType = doc['mime_type']?.toString() ?? '';

    if (storagePath.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No storage path available for this document.')),
        );
      }
      return;
    }

    try {
      // Generate a 1-hour signed URL for the private worker-documents bucket
      final signedUrl = await DI.storageRepo.getSignedUrl(
        bucket: StorageBucket.workerDocuments,
        path: storagePath,
        expiresIn: 3600,
      );

      if (mounted) {
        final isPdf = mimeType.contains('pdf') || fileName.toLowerCase().endsWith('.pdf');
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
                  color: isPdf ? AppColors.error : AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Document signed URL generated (valid 1 hour). Copy and open in browser to inspect:',
                  style: TextStyle(fontSize: 12, color: AppColors.outline),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Text(
                    signedUrl,
                    style: const TextStyle(fontSize: 10, color: AppColors.primary, fontFamily: 'monospace'),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Type: ${(doc['document_type'] ?? 'DOCUMENT').toString().replaceAll('_', ' ')} • '
                  'Size: ${_formatBytes((doc['file_size'] as int?) ?? 0)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy URL'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: signedUrl));
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Colors.teal,
                      content: Text('✓ Signed URL copied to clipboard — paste in browser to view document.'),
                      duration: Duration(seconds: 4),
                    ),
                  );
                },
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Fallback: show storage path for manual lookup
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Document Info'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: $fileName', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Storage path (paste in Supabase Storage Explorer):', style: TextStyle(fontSize: 11, color: AppColors.outline)),
                const SizedBox(height: 6),
                SelectableText(
                  storagePath,
                  style: const TextStyle(fontSize: 11, color: AppColors.primary, fontFamily: 'monospace'),
                ),
              ],
            ),
            actions: [
              ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          ),
        );
      }
    }
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
          _buildInfoRow('Federation Name', _worker.federationName.isNotEmpty ? _worker.federationName : 'Pune District Cooperative Federation'),
          _buildInfoRow('Membership / Guild ID', _worker.membershipId?.isNotEmpty == true ? _worker.membershipId! : (_worker.guildId != 'None' ? _worker.guildId : 'Pending Assignment')),
          _buildInfoRow('Artisan Charter Declaration', 'Accepted on Registration'),
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
