import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../data/models/worker_models.dart';
import 'worker_kyc_screen.dart';

class WorkerUnderVerificationScreen extends StatefulWidget {
  final VoidCallback? onVerified;

  const WorkerUnderVerificationScreen({
    super.key,
    this.onVerified,
  });

  @override
  State<WorkerUnderVerificationScreen> createState() =>
      _WorkerUnderVerificationScreenState();
}

class _WorkerUnderVerificationScreenState
    extends State<WorkerUnderVerificationScreen> {
  WorkerProfile? _worker;
  List<Map<String, dynamic>> _documents = [];
  bool _isLoading = true;
  bool _isChecking = false;
  Timer? _autoCheckTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    // Periodically re-check verification status every 15 seconds
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted && !_isChecking) {
        _checkStatus(isAuto: true);
      }
    });
  }

  @override
  void dispose() {
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await DI.authRepo.getCurrentUser();
      final userId = user?.id ?? 'mock-worker-id';
      _worker = await DI.workerRepo.getWorkerProfile(userId);
      _documents = await DI.workerRepo.getVerificationDocuments(_worker?.id ?? userId);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _checkStatus({bool isAuto = false}) async {
    if (!isAuto) {
      setState(() => _isChecking = true);
    }

    try {
      final user = await DI.authRepo.getCurrentUser();
      final userId = user?.id ?? 'mock-worker-id';
      final updatedWorker = await DI.workerRepo.getWorkerProfile(userId);

      if (mounted) {
        setState(() {
          _worker = updatedWorker;
        });

        if (updatedWorker.verificationStatus == VerificationStatus.approved) {
          _autoCheckTimer?.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.onTertiaryContainer,
                content: Text('🎉 Congratulations! Your documents have been verified by the Federation Administrator. Access granted!'),
              ),
            );

            if (widget.onVerified != null) {
              widget.onVerified!();
            } else {
              Navigator.of(context).pushReplacementNamed('/worker/dashboard');
            }
          }
        } else if (!isAuto) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(updatedWorker.verificationStatus == VerificationStatus.rejected
                  ? 'Your application requires attention. Please check rejected documents below.'
                  : 'Status: Under Verification. Federation Admin is currently reviewing your documents.'),
            ),
          );
        }
      }
    } catch (_) {
      if (!isAuto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to refresh verification status. Please check your internet connection.')),
        );
      }
    } finally {
      if (!isAuto && mounted) {
        setState(() => _isChecking = false);
      }
    }
  }

  void _showHelplineModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.support_agent, color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Federation Verification Desk',
                  style: AppTypography.titleLg.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'If you need urgent verification for pending guild assignments or have questions regarding document submission, please contact your district federation officer:',
              style: TextStyle(fontSize: 13, height: 1.5, color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone_in_talk, color: AppColors.primary),
              title: const Text('Cooperative Helpline', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('1800-266-9090 (Toll Free, 9 AM - 6 PM)'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_city, color: AppColors.primary),
              title: const Text('Pune Central Office', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Shramik Bhavan, Shivajinagar, Pune 411005'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: AppSpacing.marginMobile,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset('assets/images/logo.jpg', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ShramSetu Federation',
                  style: AppTypography.titleMd.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const Text(
                  'Artisan Verification Desk',
                  style: TextStyle(fontSize: 11, color: AppColors.outline),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout, color: AppColors.outline, size: 20),
            onPressed: () async {
              await DI.authRepo.logout();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/onboarding');
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: () async {
                    await _loadData();
                    await _checkStatus(isAuto: true);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.marginMobile,
                      vertical: AppSpacing.spacingMd,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeroStatusCard(),
                        const SizedBox(height: 16),
                        _buildVerificationTimeline(),
                        const SizedBox(height: 16),
                        _buildSubmittedDocumentsCard(),
                        const SizedBox(height: 20),
                        _buildActionSection(),
                        const SizedBox(height: 16),
                        _buildHelplineCard(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeroStatusCard() {
    final isRejected = _worker?.verificationStatus == VerificationStatus.rejected;
    final workerName = _worker?.name.isNotEmpty == true ? _worker!.name : 'Artisan Partner';

    final Color bgColor = isRejected ? AppColors.errorContainer.withValues(alpha: 0.3) : const Color(0xFFFFF8E1);
    final Color borderColor = isRejected ? AppColors.error : const Color(0xFFFFB74D);
    final Color iconColor = isRejected ? AppColors.error : const Color(0xFFF57C00);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor),
                ),
                child: Icon(
                  isRejected ? Icons.warning_amber_rounded : Icons.hourglass_top,
                  color: iconColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isRejected ? AppColors.error : const Color(0xFFF57C00),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isRejected ? 'VERIFICATION ACTION REQUIRED' : 'UNDER VERIFICATION',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRejected ? 'Application Needs Correction' : 'Application Under Review',
                      style: AppTypography.titleMd.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Namaste, $workerName!',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
          ),
          const SizedBox(height: 4),
          Text(
            isRejected
                ? 'The Federation Administrator has reviewed your submission and requested updated documents. Please re-upload the required proof below to proceed.'
                : 'Your registration documents have been submitted to the Pune District Cooperative Federation Administrator.\n\nUnder cooperative bylaws, all tradespeople undergo mandatory document and trade verification before receiving customer assignments. You will get full access immediately after administrator approval.',
            style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: AppColors.outline),
              const SizedBox(width: 6),
              Text(
                'Pune District Cooperative Federation • Registered Artisan Desk',
                style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationTimeline() {
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
          Text(
            'Verification Process',
            style: AppTypography.titleMd.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          _buildTimelineStep(
            number: '1',
            title: 'Mobile & Account Verification',
            subtitle: 'Secure Phone Auth & OTP confirmation',
            isDone: true,
          ),
          _buildTimelineDivider(isDone: true),
          _buildTimelineStep(
            number: '2',
            title: 'Artisan Profile & Trade Registered',
            subtitle: '${_worker?.skills.isNotEmpty == true ? _worker!.skills.join(", ") : "Trade skill"} (${_worker?.experience ?? "Registered"})',
            isDone: true,
          ),
          _buildTimelineDivider(isDone: true),
          _buildTimelineStep(
            number: '3',
            title: 'Federation Admin Document Verification',
            subtitle: 'Officer review of Aadhaar, address & trade credentials',
            isInProgress: _worker?.verificationStatus == VerificationStatus.pending,
            isRejected: _worker?.verificationStatus == VerificationStatus.rejected,
          ),
          _buildTimelineDivider(isDone: false),
          _buildTimelineStep(
            number: '4',
            title: 'Marketplace Access & Job Dispatch Active',
            subtitle: 'Direct customer bookings, zero surge, insurance guarantee',
            isLocked: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required String number,
    required String title,
    required String subtitle,
    bool isDone = false,
    bool isInProgress = false,
    bool isRejected = false,
    bool isLocked = false,
  }) {
    Color circleColor;
    Widget leadingWidget;

    if (isDone) {
      circleColor = AppColors.onTertiaryContainer;
      leadingWidget = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (isInProgress) {
      circleColor = const Color(0xFFF57C00);
      leadingWidget = const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    } else if (isRejected) {
      circleColor = AppColors.error;
      leadingWidget = const Icon(Icons.close, size: 14, color: Colors.white);
    } else {
      circleColor = AppColors.surfaceContainerHigh;
      leadingWidget = const Icon(Icons.lock_outline, size: 12, color: AppColors.outline);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: leadingWidget,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isLocked ? AppColors.outline : AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isLocked ? AppColors.outlineVariant : AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineDivider({required bool isDone}) {
    return Container(
      margin: const EdgeInsets.only(left: 11, top: 4, bottom: 4),
      width: 2,
      height: 18,
      color: isDone ? AppColors.onTertiaryContainer : AppColors.outlineVariant,
    );
  }

  Widget _buildSubmittedDocumentsCard() {
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
                'Submitted Documents',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const WorkerKycScreen()),
                  );
                  _loadData();
                },
                icon: const Icon(Icons.upload_file, size: 16),
                label: const Text('Manage Documents', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildDocumentStatusRow('Identity Proof (Aadhaar / PAN)', 'IDENTITY'),
          const Divider(height: 16),
          _buildDocumentStatusRow('Address Proof (Utility Bill / Passport)', 'ADDRESS'),
          const Divider(height: 16),
          _buildDocumentStatusRow('Skill / Trade Certificate', 'SKILL_CERTIFICATE', optional: true),
        ],
      ),
    );
  }

  Widget _buildDocumentStatusRow(String label, String docType, {bool optional = false}) {
    final doc = _documents.where((d) => d['document_type'] == docType).firstOrNull;
    final bool hasDoc = doc != null;
    final String status = doc?['status']?.toString().toUpperCase() ?? (hasDoc ? 'SUBMITTED' : 'NOT SUBMITTED');

    return Row(
      children: [
        Icon(
          hasDoc ? Icons.check_circle : (optional ? Icons.info_outline : Icons.pending_outlined),
          size: 20,
          color: hasDoc ? AppColors.onTertiaryContainer : (optional ? AppColors.outline : const Color(0xFFF57C00)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.primary),
              ),
              Text(
                hasDoc
                    ? 'Uploaded: ${doc['file_name'] ?? "Document"} • $status'
                    : (optional ? 'Optional accreditation document' : 'Pending upload'),
                style: TextStyle(
                  fontSize: 11,
                  color: hasDoc ? AppColors.onTertiaryContainer : AppColors.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionSection() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 1,
            ),
            onPressed: _isChecking ? null : () => _checkStatus(),
            icon: _isChecking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh, size: 20),
            label: Text(
              _isChecking ? 'Checking with Federation Server...' : 'Check Verification Status',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.outlineVariant),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WorkerKycScreen()),
              );
              _loadData();
            },
            icon: const Icon(Icons.document_scanner_outlined, size: 18),
            label: const Text('Upload / Re-submit Documents'),
          ),
        ),
      ],
    );
  }

  Widget _buildHelplineCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const Icon(Icons.headset_mic_outlined, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Need Help or Faster Verification?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                ),
                Text(
                  'Contact the Pune District Labour Cooperative Desk',
                  style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _showHelplineModal,
            child: const Text('Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
