import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/worker_models.dart';
import '../../../../core/config/dependency_injection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/repositories/i_storage_repository.dart';

class WorkerKycScreen extends StatefulWidget {
  const WorkerKycScreen({super.key});

  @override
  State<WorkerKycScreen> createState() => _WorkerKycScreenState();
}

class _WorkerKycScreenState extends State<WorkerKycScreen> {
  WorkerProfile? _worker;
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id ?? 'mock-worker-id';
    _worker = await DI.workerRepo.getWorkerProfile(userId);
    _documents = await DI.workerRepo.getVerificationDocuments(_worker?.id ?? userId);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _uploadDocument(String docType) async {
    // file_picker v13 API: FilePicker.pickFiles() returns List<PlatformFile>
    // Use readAsBytes() to get bytes — works on all platforms including web
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (files.isNotEmpty) {
      final picked = files.first;

      setState(() => _isUploading = true);
      try {
        final fileBytes = await picked.readAsBytes();
        final fileName = picked.name;
        final ext = picked.extension?.toLowerCase() ?? 'jpg';
        final mimeType = ext == 'pdf' ? 'application/pdf' : 'image/$ext';
        final workerId = _worker?.id ?? Supabase.instance.client.auth.currentUser?.id ?? 'worker';
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = '$workerId/$docType-$timestamp.$ext';

        await DI.storageRepo.uploadFile(
          bucket: StorageBucket.workerDocuments,
          path: storagePath,
          fileBytes: fileBytes,
          mimeType: mimeType,
        );

        await DI.workerRepo.submitVerificationDocument(
          workerId,
          docType,
          storagePath,
          fileName,
          mimeType,
          fileBytes.length,
        );

        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document uploaded successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _submitVerification() async {
    setState(() => _isUploading = true);
    try {
      final workerId = _worker?.id ?? Supabase.instance.client.auth.currentUser?.id ?? 'worker';
      await DI.workerRepo.submitForVerification(workerId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted for verification successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  bool _hasDocument(String docType) {
    return _documents.any((doc) => doc['document_type'] == docType);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Worker Verification', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.marginMobile),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusBanner(),
                      const SizedBox(height: AppSpacing.spacingLg),
                      Text('Required Documents',
                          style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
                      const SizedBox(height: AppSpacing.spacingSm),
                      _buildDocumentTile('IDENTITY', 'Identity Proof (Aadhaar/PAN)', Icons.badge),
                      _buildDocumentTile('ADDRESS', 'Address Proof (Utility Bill/Passport)', Icons.home),
                      _buildDocumentTile('SKILLS', 'Skill Certificate / Trade License', Icons.school),
                      const SizedBox(height: AppSpacing.spacingXl),
                      if (_worker?.verificationStatus == VerificationStatus.pending)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _hasDocument('IDENTITY') && _hasDocument('ADDRESS') && !_isUploading
                                ? _submitVerification
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                            ),
                            child: Text(
                              'Submit For Verification',
                              style: AppTypography.labelLg.copyWith(color: AppColors.onPrimary),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isUploading)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
    );
  }

  Widget _buildStatusBanner() {
    Color bgColor = AppColors.surfaceContainerHigh;
    Color textColor = AppColors.onSurfaceVariant;
    String status = 'PENDING DOCUMENTS';

    if (_worker?.verificationStatus == VerificationStatus.approved) {
      bgColor = AppColors.tertiaryFixed;
      textColor = AppColors.onTertiaryFixed;
      status = 'VERIFIED';
    } else if (_worker?.verificationStatus == VerificationStatus.rejected) {
      bgColor = AppColors.errorContainer;
      textColor = AppColors.onErrorContainer;
      status = 'REJECTED';
    } else if (_documents.isNotEmpty) {
      status = 'IN REVIEW';
      bgColor = AppColors.secondaryContainer;
      textColor = AppColors.onSecondaryContainer;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: bgColor, borderRadius: AppRadius.radiusLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Status: $status',
            style: AppTypography.titleMd.copyWith(color: textColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            status == 'VERIFIED'
                ? 'Your profile is fully verified. You are eligible for priority guild assignments.'
                : (status == 'IN REVIEW'
                    ? 'Documents submitted. Verification typically completes within 24 hours.'
                    : 'Upload required documents below to get verified and start receiving jobs.'),
            style: AppTypography.bodyMd.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTile(String docType, String title, IconData icon) {
    final bool hasDoc = _hasDocument(docType);
    final doc = _documents.where((d) => d['document_type'] == docType).firstOrNull;
    final fileName = doc?['file_name']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.radiusXl,
        side: BorderSide(color: hasDoc ? AppColors.tertiaryFixed : AppColors.outlineVariant),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpacing.spacingMd),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: hasDoc ? AppColors.tertiaryFixed : AppColors.surfaceContainerHigh,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: hasDoc ? AppColors.onTertiaryFixed : AppColors.onSurfaceVariant),
        ),
        title: Text(title, style: AppTypography.titleMd),
        subtitle: Text(
          hasDoc
              ? (fileName != null ? 'Uploaded: $fileName' : 'Uploaded • Verified')
              : (kIsWeb ? 'Tap to upload document' : 'Pending Upload'),
          style: AppTypography.bodySm.copyWith(
            color: hasDoc ? AppColors.tertiary : AppColors.error,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: hasDoc
            ? const Icon(Icons.check_circle, color: AppColors.tertiary)
            : TextButton.icon(
                onPressed: () => _uploadDocument(docType),
                icon: const Icon(Icons.upload_file, size: 18),
                label: const Text('Upload'),
              ),
      ),
    );
  }
}
