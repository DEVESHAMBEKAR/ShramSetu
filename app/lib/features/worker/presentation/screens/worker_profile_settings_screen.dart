import 'package:app/core/config/dependency_injection.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/worker_models.dart';
import '../../data/repositories/mock_worker_repository.dart';
import 'worker_kyc_screen.dart';

class WorkerProfileSettingsScreen extends StatefulWidget {
  const WorkerProfileSettingsScreen({super.key});

  @override
  State<WorkerProfileSettingsScreen> createState() => _WorkerProfileSettingsScreenState();
}

class _WorkerProfileSettingsScreenState extends State<WorkerProfileSettingsScreen> {
  late MockWorkerRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = MockWorkerRepository();
    _repository.addListener(_onRepositoryChanged);
  }

  @override
  void dispose() {
    _repository.removeListener(_onRepositoryChanged);
    super.dispose();
  }

  void _onRepositoryChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final worker = _repository.currentWorker;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Profile & Settings', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileCard(worker),
            const SizedBox(height: AppSpacing.spacingLg),
            Text('Account Settings', style: AppTypography.titleMd.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.spacingSm),
            _buildSettingsList(worker),
            const SizedBox(height: AppSpacing.spacingLg),
            _buildLogoutButton(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(WorkerProfile worker) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(color: AppColors.surfaceContainerHigh, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: AppColors.outline, size: 36),
              ),
              const SizedBox(width: AppSpacing.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(worker.name, style: AppTypography.headlineSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    Text(worker.phone, style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.05), borderRadius: AppRadius.radiusFull),
                      child: Text('Guild ${worker.guildId}', style: AppTypography.labelSm.copyWith(color: AppColors.onPrimaryFixedVariant)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildProfileStat('Rating', '${worker.rating} ★'),
              Container(width: 1, height: 32, color: AppColors.surfaceVariant),
              _buildProfileStat('Jobs', worker.completedJobs.toString()),
              Container(width: 1, height: 32, color: AppColors.surfaceVariant),
              _buildProfileStat('Exp', worker.experience),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStat(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
        Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildSettingsList(WorkerProfile worker) {
    return Container(
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        children: [
          _buildAvailabilityToggle(worker),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.verified, color: AppColors.tertiaryFixed),
            title: Text('KYC Verification', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text('Identity & Documents Verified', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkerKycScreen()));
            },
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.handyman, color: AppColors.secondary),
            title: Text('Trade Skills', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(worker.skills.join(', '), style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
          ),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.location_on, color: AppColors.primary),
            title: Text('Service Area', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
            subtitle: Text(worker.serviceLocation, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
            trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityToggle(WorkerProfile worker) {
    final isAvailable = worker.isAvailable;
    return SwitchListTile(
      value: isAvailable,
      onChanged: (val) => _repository.toggleAvailability(),
      activeColor: AppColors.onTertiaryContainer,
      secondary: Icon(isAvailable ? Icons.notifications_active : Icons.notifications_off, color: isAvailable ? AppColors.onTertiaryContainer : AppColors.outline),
      title: Text('Active Duty Status', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
      subtitle: Text(isAvailable ? 'Receiving local job requests' : 'Currently offline', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () async {
        await DI.authRepo.logout();
        if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (route) => false);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.spacingMd),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusLg, border: Border.all(color: AppColors.error)),
        alignment: Alignment.center,
        child: Text('Sign Out', style: AppTypography.labelLg.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

