import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../shared/widgets/document_viewer/document_viewer_modal.dart';
import '../../data/models/worker_models.dart';
import 'worker_kyc_screen.dart';
import 'worker_registration_screen.dart';

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
  List<WorkerVerificationHistoryItem> _history = [];
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
      try {
        _history = await DI.workerRepo.getVerificationHistory(_worker?.id ?? userId);
      } catch (_) {}

      // Stop polling if already in a terminal state (rejected / suspended)
      final vs = _worker?.verificationStatus;
      if (vs == VerificationStatus.rejected || vs == VerificationStatus.suspended) {
        _autoCheckTimer?.cancel();
      }
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

      // Also refresh documents so flagged docs become visible
      List<Map<String, dynamic>> freshDocs = _documents;
      try {
        freshDocs = await DI.workerRepo.getVerificationDocuments(updatedWorker.id);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _worker = updatedWorker;
          _documents = freshDocs;
        });

        final vs = updatedWorker.verificationStatus;

        if (vs == VerificationStatus.approved) {
          _autoCheckTimer?.cancel();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.onTertiaryContainer,
                content: Text('🎉 Congratulations! Your documents have been verified by the Federation Administrator. Access granted!'),
                duration: Duration(seconds: 5),
              ),
            );
            if (widget.onVerified != null) {
              widget.onVerified!();
            } else {
              Navigator.of(context).pushReplacementNamed('/worker/dashboard');
            }
          }
        } else if (vs == VerificationStatus.rejected) {
          // Stop polling — rejection is a terminal state
          _autoCheckTimer?.cancel();
          if (!isAuto && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.error,
                content: Text('Application Declined — your registration has been rejected by the Federation Administrator. Check the remarks below.'),
                duration: Duration(seconds: 6),
              ),
            );
          }
        } else if (vs == VerificationStatus.suspended) {
          _autoCheckTimer?.cancel();
          if (!isAuto && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.error,
                content: Text('Account Suspended — your artisan account has been suspended. Please contact your district federation desk.'),
                duration: Duration(seconds: 6),
              ),
            );
          }
        } else if (!isAuto) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(vs == VerificationStatus.changesRequired
                  ? '⚠ Changes Required — check the remarks and resubmit corrected documents.'
                  : vs == VerificationStatus.underReview
                      ? 'Status: Under Review — a Federation Officer is actively examining your documents.'
                      : 'Status: In Queue — Federation Admin is reviewing your documents.'),
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
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Logout', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Row(
                    children: [
                      Icon(Icons.logout_rounded, color: AppColors.error),
                      SizedBox(width: 8),
                      Text('Sign Out'),
                    ],
                  ),
                  content: const Text(
                    'You will be returned to the login screen. Your registration and documents are saved — you can log back in anytime to check your verification status.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Stay'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sign Out & Change Account'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await DI.authRepo.logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
                }
              }
            },
          ),
          const SizedBox(width: 4),
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
                        if (_history.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildVerificationHistoryCard(),
                        ],
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
    final status = _worker?.verificationStatus ?? VerificationStatus.pending;
    final workerName = _worker?.name.isNotEmpty == true ? _worker!.name : 'Artisan Partner';

    Color bgColor;
    Color borderColor;
    Color badgeBg;
    Color iconColor;
    IconData iconData;
    String badgeText;
    String headline;
    String description;

    switch (status) {
      case VerificationStatus.approved:
        bgColor = const Color(0xFFE8F5E9);
        borderColor = const Color(0xFF4CAF50);
        badgeBg = const Color(0xFF2E7D32);
        iconColor = const Color(0xFF2E7D32);
        iconData = Icons.verified_user;
        badgeText = 'VERIFIED & APPROVED';
        headline = 'Registration Approved!';
        description = 'Your credentials and documents have been verified by the Federation Administrator. You now have full access to job assignments and cooperative benefits.';
        break;
      case VerificationStatus.changesRequired:
        bgColor = const Color(0xFFFFF3E0);
        borderColor = const Color(0xFFFF9800);
        badgeBg = const Color(0xFFE65100);
        iconColor = const Color(0xFFE65100);
        iconData = Icons.edit_note;
        badgeText = 'CHANGES REQUIRED';
        headline = 'Action Required: Update Details';
        description = 'The Federation Administrator has reviewed your submission and requested corrections or clearer documents before approval can be granted.';
        break;
      case VerificationStatus.underReview:
        bgColor = const Color(0xFFE3F2FD);
        borderColor = const Color(0xFF2196F3);
        badgeBg = const Color(0xFF1565C0);
        iconColor = const Color(0xFF1565C0);
        iconData = Icons.manage_search;
        badgeText = 'UNDER REVIEW';
        headline = 'Application Under Officer Review';
        description = 'A Federation Verification Officer is currently examining your uploaded documents and trade credentials. No action is needed from you right now.';
        break;
      case VerificationStatus.rejected:
        bgColor = AppColors.errorContainer.withValues(alpha: 0.3);
        borderColor = AppColors.error;
        badgeBg = AppColors.error;
        iconColor = AppColors.error;
        iconData = Icons.cancel_outlined;
        badgeText = 'APPLICATION DECLINED';
        headline = 'Verification Declined';
        description = 'Your application could not be verified by the Federation Administrator based on the provided documents.';
        break;
      case VerificationStatus.suspended:
        bgColor = const Color(0xFFFFEBEE);
        borderColor = const Color(0xFFC62828);
        badgeBg = const Color(0xFFB71C1C);
        iconColor = const Color(0xFFB71C1C);
        iconData = Icons.block;
        badgeText = 'ACCOUNT SUSPENDED';
        headline = 'Artisan Account Suspended';
        description = 'Your artisan account has been temporarily suspended by the Federation Administration. Please contact your district desk for appeals.';
        break;
      case VerificationStatus.pending:
      case VerificationStatus.notSubmitted:
        bgColor = const Color(0xFFFFF8E1);
        borderColor = const Color(0xFFFFB74D);
        badgeBg = const Color(0xFFF57C00);
        iconColor = const Color(0xFFF57C00);
        iconData = Icons.hourglass_top;
        badgeText = 'UNDER VERIFICATION';
        headline = 'Application In Queue';
        description = 'Your registration documents have been submitted to the Pune District Cooperative Federation Administrator.\n\nUnder cooperative bylaws, all tradespeople undergo mandatory document and trade verification before receiving customer assignments. You will get full access immediately after administrator approval.';
        break;
    }

    final hasRemarks = _worker?.verificationRemarks?.trim().isNotEmpty == true;

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
                  iconData,
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
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
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
                      headline,
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
            description,
            style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.onSurfaceVariant),
          ),
          // Generic remarks (changes-required, under-review, etc.)
          if (hasRemarks && status != VerificationStatus.rejected) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor.withValues(alpha: 0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.rate_review_outlined, size: 16, color: iconColor),
                      const SizedBox(width: 6),
                      Text(
                        'Administrator Remarks:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: iconColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _worker!.verificationRemarks!,
                    style: const TextStyle(fontSize: 13, color: AppColors.primary, height: 1.4),
                  ),
                ],
              ),
            ),
          ],
          // ── REJECTED: show why + allow reapply ──────────────────────────
          if (status == VerificationStatus.rejected) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.6), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.error),
                      const SizedBox(width: 6),
                      const Text(
                        'Reason for Rejection:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (_worker?.verificationRemarks?.trim().isNotEmpty == true)
                        ? _worker!.verificationRemarks!
                        : 'The Federation Administrator did not provide a specific reason. Please contact your district federation desk for details.',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFEF9A9A)),
                  const SizedBox(height: 12),
                  const Text(
                    'You may correct the issues mentioned above and reapply. Your registration details will be pre-filled.',
                    style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.refresh_rounded, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Reapply for Verification'),
                        ],
                      ),
                      content: const Text(
                        'Your previous registration details will be pre-filled. Review and correct the issues mentioned in the rejection reason, then resubmit your documents.\n\nYour application will re-enter the queue for Federation Administrator review.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Proceed to Reapply'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true && mounted) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WorkerRegistrationScreen(
                          isResubmission: true,
                          changeRequestReason: _worker?.verificationRemarks ??
                              'Your previous application was rejected. Please review and correct your details.',
                        ),
                      ),
                    );
                    _loadData();
                  }
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text(
                  'Correct & Reapply',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
          // ── CHANGES REQUIRED: quick edit button ─────────────────────────
          if (status == VerificationStatus.changesRequired) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE65100),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WorkerRegistrationScreen(
                        isResubmission: true,
                        changeRequestReason: _worker?.verificationRemarks,
                      ),
                    ),
                  );
                  _loadData();
                },
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text(
                  'Edit Details & Resubmit Documents',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
          if (status == VerificationStatus.approved) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  if (widget.onVerified != null) {
                    widget.onVerified!();
                  } else {
                    Navigator.of(context).pushReplacementNamed('/worker/dashboard');
                  }
                },
                icon: const Icon(Icons.dashboard_outlined, size: 18),
                label: const Text(
                  'Go to Worker Dashboard',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.shield_outlined, size: 16, color: AppColors.outline),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_worker?.federationName.isNotEmpty == true ? _worker!.federationName : "Pune District Cooperative Federation"} • Registered Artisan Desk',
                  style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationTimeline() {
    final status = _worker?.verificationStatus ?? VerificationStatus.pending;
    final isApproved = status == VerificationStatus.approved;
    final isUnderReview = status == VerificationStatus.underReview;
    final isPending = status == VerificationStatus.pending;
    final isChangesRequired = status == VerificationStatus.changesRequired;
    final isRejected = status == VerificationStatus.rejected || status == VerificationStatus.suspended;

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
            subtitle: '${_worker?.trade?.isNotEmpty == true ? _worker!.trade! : (_worker?.skills.isNotEmpty == true ? _worker!.skills.first : "Trade skill")} • ${_worker?.skillLevel?.isNotEmpty == true ? _worker!.skillLevel! : (_worker?.experience ?? "Registered")}',
            isDone: true,
          ),
          _buildTimelineDivider(isDone: isApproved),
          _buildTimelineStep(
            number: '3',
            title: 'Federation Admin Document Verification',
            subtitle: isApproved
                ? 'Approved by Federation Administrator'
                : (isUnderReview
                    ? 'Officer currently reviewing credentials'
                    : (isChangesRequired
                        ? 'Corrections requested by Administrator'
                        : (isRejected
                            ? 'Verification declined'
                            : 'In queue for administrator review'))),
            isDone: isApproved,
            isInProgress: isUnderReview || isPending,
            isRejected: isRejected || isChangesRequired,
          ),
          _buildTimelineDivider(isDone: isApproved),
          _buildTimelineStep(
            number: '4',
            title: 'Marketplace Access & Job Dispatch Active',
            subtitle: isApproved
                ? 'Direct customer bookings, fair wages, zero commission'
                : 'Locked until verification approval',
            isDone: isApproved,
            isLocked: !isApproved,
          ),
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
                'Verification Activity Log',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _history.length,
            separatorBuilder: (_, _) => const Divider(height: 16),
            itemBuilder: (context, index) {
              final item = _history[index];
              Color actionColor = AppColors.primary;
              IconData actionIcon = Icons.info_outline;

              switch (item.action.toUpperCase()) {
                case 'APPROVE':
                  actionColor = const Color(0xFF2E7D32);
                  actionIcon = Icons.check_circle_outline;
                  break;
                case 'REQUEST_CHANGES':
                  actionColor = const Color(0xFFE65100);
                  actionIcon = Icons.edit_note;
                  break;
                case 'REJECT':
                case 'SUSPEND':
                  actionColor = AppColors.error;
                  actionIcon = Icons.cancel_outlined;
                  break;
                case 'START_REVIEW':
                  actionColor = const Color(0xFF1565C0);
                  actionIcon = Icons.visibility_outlined;
                  break;
                case 'SUBMIT':
                case 'RESUBMIT':
                  actionColor = const Color(0xFFF57C00);
                  actionIcon = Icons.upload_file_outlined;
                  break;
              }

              final timeStr = item.createdAt.toLocal().toString().split('.').first;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(actionIcon, size: 18, color: actionColor),
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: actionColor,
                              ),
                            ),
                            Text(
                              timeStr,
                              style: const TextStyle(fontSize: 10, color: AppColors.outline),
                            ),
                          ],
                        ),
                        if (item.remarks?.isNotEmpty == true) ...[
                          const SizedBox(height: 3),
                          Text(
                            item.remarks!,
                            style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                          ),
                        ],
                        if (item.reviewedBy?.isNotEmpty == true) ...[
                          const SizedBox(height: 2),
                          Text(
                            'By: ${item.reviewedBy}',
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
        if (hasDoc)
          TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => DocumentViewerModal.show(context, doc: doc),
            icon: const Icon(Icons.visibility_outlined, size: 14),
            label: const Text('View', style: TextStyle(fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildActionSection() {
    final isChangesRequired = _worker?.verificationStatus == VerificationStatus.changesRequired;

    return Column(
      children: [
        if (isChangesRequired) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 1,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkerRegistrationScreen(
                      isResubmission: true,
                      changeRequestReason: _worker?.verificationRemarks,
                    ),
                  ),
                );
                _loadData();
              },
              icon: const Icon(Icons.edit_note, size: 20),
              label: const Text(
                'Edit Details & Resubmit Application',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: isChangesRequired ? AppColors.surfaceContainerHigh : AppColors.primary,
              foregroundColor: isChangesRequired ? AppColors.primary : Colors.white,
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

