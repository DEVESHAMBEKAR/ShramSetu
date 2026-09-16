import 'package:app/core/config/dependency_injection.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/worker_models.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/repositories/i_storage_repository.dart';
import '../../../../shared/widgets/map_location_picker_screen.dart';
import 'worker_kyc_screen.dart';

class WorkerProfileSettingsScreen extends StatefulWidget {
  const WorkerProfileSettingsScreen({super.key});

  @override
  State<WorkerProfileSettingsScreen> createState() => _WorkerProfileSettingsScreenState();
}

class _WorkerProfileSettingsScreenState extends State<WorkerProfileSettingsScreen> {
  late Future<WorkerProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  
  Future<void> _pickAndUploadImage(WorkerProfile worker) async {
    if (kIsWeb) {
      // On web, image_picker returns no path — use bytes directly
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo upload is available on the mobile app.')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800, maxHeight: 800);
    
    if (pickedFile != null) {
      try {
        final Uint8List fileBytes = await pickedFile.readAsBytes();
        // Path in storage bucket: {worker_id}/avatar.jpg
        final storagePath = '${worker.id}/avatar.jpg';
        
        // Use StorageRepo to upload bytes (web-compatible)
        final publicUrl = await DI.storageRepo.uploadFile(
          bucket: StorageBucket.profileImages,
          path: storagePath,
          fileBytes: fileBytes,
          mimeType: 'image/jpeg',
        );
        
        // Update database with new URL
        await DI.workerRepo.updateProfileImage(worker.id, publicUrl);
        
        // Refresh UI
        _refreshData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
        }
      }
    }
  }

  void _refreshData() {
    setState(() {
      _profileFuture = () async {
        final user = await DI.authRepo.getCurrentUser();
        final userId = user?.id ?? 'mock-worker-id';
        return DI.workerRepo.getWorkerProfile(userId);
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WorkerProfile>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ')));
        }
        
        final worker = snapshot.data!;

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
                GestureDetector(
                  onTap: () => _pickAndUploadImage(worker),
                  child: Stack(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          shape: BoxShape.circle,
                          image: worker.profileImage.isNotEmpty
                              ? DecorationImage(image: NetworkImage(worker.profileImage), fit: BoxFit.cover)
                              : null,
                        ),
                        child: worker.profileImage.isEmpty
                            ? const Icon(Icons.person, color: AppColors.outline, size: 36)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt, color: AppColors.onPrimary, size: 14),
                        ),
                      ),
                    ],
                  ),
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
            leading: const Icon(Icons.verified, color: AppColors.onTertiaryContainer),
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
            subtitle: Text(
              worker.hasLocation 
                  ? '${worker.serviceLocation} • GPS Locked'
                  : worker.serviceLocation, 
              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
            onTap: () => _showUpdateLocationSheet(worker),
          ),
        ],
      ),
    );
  }

  void _showUpdateLocationSheet(WorkerProfile worker) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Worker Service Area', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppRadius.radiusLg,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(worker.serviceLocation, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
                          if (worker.hasLocation)
                            Text(
                              'GPS: ${worker.latitude!.toStringAsFixed(4)}, ${worker.longitude!.toStringAsFixed(4)}',
                              style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontSize: 10),
                            ),
                          if (worker.locationUpdatedAt != null)
                            Text(
                              'Last updated: ${worker.locationUpdatedAt!.toLocal().toString().split('.')[0]}',
                              style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 10),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.my_location, color: AppColors.secondary),
                title: const Text('Update with Current GPS Location', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Detect coordinates and set current duty post'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await DI.locationService.getCurrentPosition();
                  if (result.isSuccess && result.coordinates != null) {
                    final coords = result.coordinates!;
                    final geo = await DI.locationService.reverseGeocode(coords.latitude, coords.longitude);
                    final tagParts = [
                      if (geo?.area.isNotEmpty == true) geo!.area,
                      if (geo?.city.isNotEmpty == true) geo!.city,
                    ];
                    final locationTag = tagParts.isNotEmpty ? tagParts.join(', ') : worker.serviceLocation;

                    await DI.workerRepo.updateWorkerLocation(
                      worker.id,
                      latitude: coords.latitude,
                      longitude: coords.longitude,
                      locationTag: locationTag,
                    );
                    _refreshData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Service area updated to $locationTag')),
                      );
                    }
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(result.errorMessage ?? 'Unable to detect GPS.')),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined, color: AppColors.primary),
                title: const Text('Pick Area on Map', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Pinpoint duty location on Google Map'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final mapRes = await Navigator.push<LocationPickerResult>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapLocationPickerScreen(
                        initialLatitude: worker.latitude,
                        initialLongitude: worker.longitude,
                        title: 'Select Worker Service Base',
                      ),
                    ),
                  );

                  if (mapRes != null) {
                    final geo = mapRes.address;
                    final tagParts = [
                      if (geo?.area.isNotEmpty == true) geo!.area,
                      if (geo?.city.isNotEmpty == true) geo!.city,
                    ];
                    final locationTag = tagParts.isNotEmpty ? tagParts.join(', ') : worker.serviceLocation;

                    await DI.workerRepo.updateWorkerLocation(
                      worker.id,
                      latitude: mapRes.latitude,
                      longitude: mapRes.longitude,
                      locationTag: locationTag,
                    );
                    _refreshData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Service area updated to $locationTag')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvailabilityToggle(WorkerProfile worker) {
    final isAvailable = worker.isAvailable;
    return SwitchListTile(
      value: isAvailable,
      onChanged: (val) async { await DI.workerRepo.updateWorkerAvailability(worker.id, val); _refreshData(); },
      activeThumbColor: AppColors.onTertiaryContainer,
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





