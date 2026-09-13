import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/worker_models.dart';
import '../../data/repositories/mock_worker_repository.dart';

class WorkerKycScreen extends StatefulWidget {
  const WorkerKycScreen({super.key});

  @override
  State<WorkerKycScreen> createState() => _WorkerKycScreenState();
}

class _WorkerKycScreenState extends State<WorkerKycScreen> {
  late MockWorkerRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = MockWorkerRepository();
  }

  @override
  Widget build(BuildContext context) {
    final worker = _repository.currentWorker;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Worker Verification', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderContext(),
            const SizedBox(height: AppSpacing.spacingMd),
            _buildProgressBar(),
            const SizedBox(height: AppSpacing.spacingMd),
            _buildWorkerSummary(worker),
            const SizedBox(height: AppSpacing.spacingMd),
            _buildBiometricCard(),
            const SizedBox(height: AppSpacing.spacingMd),
            _buildDocumentChecklist(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderContext() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: 4),
              decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: AppRadius.radiusFull),
              child: Row(
                children: [
                  const Icon(Icons.shield, size: 15, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('Official Guild Onboarding', style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            Text('Step 3 of 4', style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: AppSpacing.spacingXs),
        Text('Karigar Registration & Guild KYC', style: AppTypography.headlineSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Step 3 of 4: Identity & Skill Verification', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Application Milestone', style: AppTypography.labelLg.copyWith(color: AppColors.primary)),
                  const SizedBox(width: AppSpacing.spacingXs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.tertiaryFixed, borderRadius: AppRadius.radiusFull),
                    child: Text('75% Complete', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryFixed, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              Text('Next: Bank Escrow', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Container(
            height: 8,
            decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: AppRadius.radiusFull),
            child: Row(
              children: [
                Expanded(flex: 3, child: Container(decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: AppRadius.radiusFull))),
                Expanded(flex: 1, child: Container()),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMicroStep('Personal', true, false),
              _buildMicroStep('Trade Skills', true, false),
              _buildMicroStep('KYC Docs', false, true, index: 3),
              _buildMicroStep('Bank Escrow', false, false, index: 4, disabled: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMicroStep(String label, bool isDone, bool isCurrent, {int? index, bool disabled = false}) {
    Color iconBg = isDone ? AppColors.tertiaryFixed : (isCurrent ? AppColors.primary : AppColors.surfaceContainerHigh);
    Color iconColor = isDone ? AppColors.onTertiaryFixed : (isCurrent ? AppColors.onPrimary : AppColors.onSurfaceVariant);

    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: Column(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: isDone
                ? Icon(Icons.done, size: 14, color: iconColor)
                : Text(index.toString(), style: AppTypography.labelSm.copyWith(color: iconColor, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.labelSm.copyWith(color: isCurrent ? AppColors.primary : AppColors.onSurface, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildWorkerSummary(WorkerProfile worker) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: AppColors.outline),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(color: AppColors.tertiaryFixed, shape: BoxShape.circle),
                  child: const Icon(Icons.verified, size: 16, color: AppColors.onTertiaryFixed),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(worker.name, style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: AppSpacing.spacingXs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: BorderRadius.circular(4)),
                      child: Text('UID: **** 4912', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Licensed Master ${worker.skills.first}', style: AppTypography.titleMd.copyWith(color: AppColors.secondary)),
                const SizedBox(height: AppSpacing.spacingXs),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Expanded(child: Text(worker.serviceLocation, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.face, color: AppColors.surfaceTint, size: 20),
                  const SizedBox(width: 8),
                  Text('Live Biometric Match', style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppColors.tertiaryFixed, borderRadius: AppRadius.radiusFull),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.onTertiaryFixed, size: 14),
                    const SizedBox(width: 4),
                    Text('98% Matched', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryFixed, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.spacingSm),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusLg),
                  child: const Icon(Icons.person, color: AppColors.outline, size: 32),
                ),
                const SizedBox(width: AppSpacing.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Live Scan Authenticated', style: AppTypography.labelLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('Biometric verification authenticated against the Aadhaar Central UIDAI Registry.', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentChecklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Document Verification', style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            Text('4 of 4 Verified', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        _buildDocItem(Icons.badge, 'Aadhaar Card (Govt ID)', 'OCR Verified', 'UID Number: •••• •••• 4912', AppColors.primary),
        _buildDocItem(Icons.local_police, 'Police Character Certificate', 'Cleared', 'Issued & Certified: Kothrud Police Stn, Pune', AppColors.primary),
        _buildDocItem(Icons.school, 'Trade Certificate / ITI Diploma', 'PDF Document', 'ITI_Wireman_Diploma_2018.pdf', AppColors.secondary, isSecondaryBadge: true),
        _buildDocItem(Icons.electric_bolt, 'Trade License (#MH-8219)', 'Govt Validated', 'Maharashtra State Electricity Board', AppColors.primary),
      ],
    );
  }

  Widget _buildDocItem(IconData icon, String title, String badgeText, String desc, Color iconColor, {bool isSecondaryBadge = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusLg),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: AppTypography.titleMd.copyWith(color: AppColors.primary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: isSecondaryBadge ? AppColors.surfaceContainer : AppColors.tertiaryFixed, borderRadius: BorderRadius.circular(4)),
                      child: Row(
                        children: [
                          if (!isSecondaryBadge) const Icon(Icons.check, size: 12, color: AppColors.onTertiaryFixed),
                          if (!isSecondaryBadge) const SizedBox(width: 2),
                          Text(badgeText, style: AppTypography.labelSm.copyWith(color: isSecondaryBadge ? AppColors.onSurfaceVariant : AppColors.onTertiaryFixed, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(desc, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.spacingXs),
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            child: Icon(isSecondaryBadge ? Icons.preview : Icons.visibility, color: isSecondaryBadge ? AppColors.secondary : AppColors.onSurfaceVariant, size: 20),
          ),
        ],
      ),
    );
  }
}
