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
import '../../../../core/utils/distance_calculator.dart';
import '../../../../core/services/india_geography_service.dart';
import 'worker_kyc_screen.dart';

class _ProfileAreaSuggestion {
  final String name;
  final double distKm;
  final bool is7to10;
  const _ProfileAreaSuggestion({required this.name, required this.distKm, required this.is7to10});
}

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
                    if (worker.email != null && worker.email!.isNotEmpty)
                      Text(worker.email!, style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 12)),
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
    return Material(
      color: AppColors.surfaceContainerLowest,
      borderRadius: AppRadius.radiusXl,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildAvailabilityToggle(worker),
          const Divider(height: 1, indent: 56),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined, color: AppColors.primary),
            title: Row(
              children: [
                Text('Account Credentials', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: const Text('Required', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                ),
              ],
            ),
            subtitle: Text(
              'Mobile: ${worker.phone}\nEmail: ${worker.email?.isNotEmpty == true ? worker.email! : 'Not set (Required)'}',
              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, height: 1.3),
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 20),
            onTap: () => _showEditCredentialsDialog(worker),
          ),
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
            title: Row(
              children: [
                Text('Service Areas', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
                if (worker.isVerified) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF81C784)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 10, color: Color(0xFF2E7D32)),
                        SizedBox(width: 3),
                        Text('Locked', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            subtitle: Text(
              (worker.serviceAreas.isNotEmpty ? worker.serviceAreas.join(' • ') : worker.serviceLocation) +
                  (worker.isVerified ? '\nTerritorial lock active • Admin ticket required for changes' : ''),
              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
            ),
            trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
            onTap: () => _showUpdateLocationSheet(worker),
          ),
        ],
      ),
    );
  }

  void _showEditCredentialsDialog(WorkerProfile worker) {
    final formKey = GlobalKey<FormState>();
    final phoneCtrl = TextEditingController(text: worker.phone);
    final emailCtrl = TextEditingController(text: worker.email ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.marginMobile,
                right: AppSpacing.marginMobile,
                top: AppSpacing.spacingMd,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.spacingMd,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Update Account Credentials', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Both mobile phone and email are required for official union credentials and payouts.',
                      style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Mobile Number *',
                        prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Mobile number is required.';
                        final clean = val.replaceAll(RegExp(r'\D'), '').trim();
                        if (clean.length != 10) return 'Enter a valid 10-digit mobile number.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: const Icon(Icons.email_outlined, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Email address is required.';
                        if (!RegExp(r'^[\w\.-]+@[\w-]+\.\w{2,}$').hasMatch(val.trim())) {
                          return 'Enter a valid email address.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSaving = true);
                                try {
                                  await DI.workerRepo.updateWorkerCredentials(
                                    worker.id,
                                    phone: phoneCtrl.text.trim(),
                                    email: emailCtrl.text.trim(),
                                  );
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                  }
                                  _refreshData();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Account credentials updated successfully.'),
                                        backgroundColor: AppColors.primary,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSaving = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to update credentials: $e')),
                                    );
                                  }
                                }
                              },
                        child: isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Credentials', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showUpdateLocationSheet(WorkerProfile worker) {
    final activeAreas = worker.serviceAreas.isNotEmpty ? worker.serviceAreas : [worker.serviceLocation];

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
                  Text('Worker Service Areas', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Active Service Areas Badges
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppRadius.radiusLg,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.place, color: AppColors.primary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Active Registered Localities (${activeAreas.length}/3):',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: activeAreas.map((area) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.outlineVariant),
                          ),
                          child: Text(
                            area,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                          ),
                        );
                      }).toList(),
                    ),
                    if (worker.hasLocation) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Base Coordinates: ${worker.latitude!.toStringAsFixed(4)}° N, ${worker.longitude!.toStringAsFixed(4)}° E',
                        style: const TextStyle(fontSize: 11, color: AppColors.outline),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // If Verified: Strict Territorial Lock & Ticket Raising
              if (worker.isVerified) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_clock, color: Color(0xFFE65100), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Territorial Jurisdiction Locked',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFBF360C)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'As a verified artisan, operating areas cannot be changed directly without federation approval. To add or change areas, please raise an Area Change Ticket.',
                              style: TextStyle(fontSize: 11, color: Color(0xFFD84315), height: 1.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Pending Area Change Ticket Status
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: DI.workerRepo.getAreaChangeTickets(worker.id),
                  builder: (context, snapshot) {
                    final tickets = snapshot.data ?? [];
                    final pending = tickets.where((t) => t['status'] == 'PENDING').firstOrNull;

                    if (pending != null) {
                      final requested = (pending['requested_areas'] as List?)?.join(', ') ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE3F2FD),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF90CAF9)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.hourglass_top, color: Color(0xFF1565C0), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pending Ticket: Requested [$requested] • Awaiting Admin Review',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF0D47A1), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.confirmation_number_outlined, size: 20),
                    label: const Text('Raise Area Change Ticket to Admin', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showRaiseAreaChangeTicketDialog(worker);
                    },
                  ),
                ),
              ] else ...[
                // Unverified Worker: Direct Location Updates
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
              ],
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showRaiseAreaChangeTicketDialog(WorkerProfile worker) {
    final activeAreas = worker.serviceAreas.isNotEmpty ? worker.serviceAreas : [worker.serviceLocation];
    final List<String> requestedAreas = List<String>.from(activeAreas);
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    final baseLat = worker.latitude ?? 18.5074;
    final baseLng = worker.longitude ?? 73.8077;

    const knownCoords = {
      'Kothrud': (18.5074, 73.8077),
      'Shivajinagar': (18.5314, 73.8446),
      'Baner': (18.5590, 73.7868),
      'Wakad': (18.5987, 73.7660),
      'Hinjewadi': (18.5913, 73.7389),
      'Hadapsar': (18.5089, 73.9259),
      'Viman Nagar': (18.5679, 73.9143),
      'Swargate': (18.5018, 73.8586),
      'Katraj': (18.4575, 73.8565),
      'Aundh': (18.5580, 73.8075),
      'Bavdhan': (18.5147, 73.7744),
      'Karve Nagar': (18.4913, 73.8193),
      'Warje': (18.4815, 73.8021),
      'Sinhagad Road': (18.4682, 73.8219),
      'Kondhwa': (18.4746, 73.8940),
    };

    final allDistrictAreas = IndiaGeographyService.getAreasForDistrict('Maharashtra', 'Pune');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            // Calculate proximity suggestions
            final suggestions = <_ProfileAreaSuggestion>[];
            for (final entry in knownCoords.entries) {
              if (requestedAreas.contains(entry.key) || requestedAreas.any((r) => r.contains(entry.key))) continue;
              final d = HaversineDistanceUtil.calculateDistance(baseLat, baseLng, entry.value.$1, entry.value.$2);
              if (d != null && d > 0.1 && d <= 20.0) {
                suggestions.add(_ProfileAreaSuggestion(name: entry.key, distKm: d, is7to10: d >= 7.0 && d <= 10.0));
              }
            }
            suggestions.sort((a, b) {
              if (a.is7to10 && !b.is7to10) return -1;
              if (!a.is7to10 && b.is7to10) return 1;
              return a.distKm.compareTo(b.distKm);
            });

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.marginMobile,
                right: AppSpacing.marginMobile,
                top: AppSpacing.spacingMd,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.spacingMd,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.confirmation_number_outlined, color: AppColors.primary, size: 22),
                            SizedBox(width: 8),
                            Text('Area Change Request Ticket', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Request addition or transfer of service areas (Maximum 3). Your federation administrator will review and authorize your request.',
                      style: TextStyle(fontSize: 12, color: AppColors.outline),
                    ),
                    const SizedBox(height: 14),

                    // Current Selected Areas
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Requested Service Areas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('${requestedAreas.length} / 3 Max', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.primary)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: requestedAreas.map((area) {
                        return Chip(
                          label: Text(area, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          deleteIcon: const Icon(Icons.cancel, size: 16),
                          onDeleted: requestedAreas.length <= 1
                              ? null
                              : () {
                                  setDialogState(() {
                                    requestedAreas.remove(area);
                                  });
                                },
                          backgroundColor: AppColors.primaryContainer,
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Proximity Suggestions (7-10 km & nearby)
                    if (requestedAreas.length < 3 && suggestions.isNotEmpty) ...[
                      const Text(
                        '💡 Proximity Suggestions (7–10 km & Nearby):',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1565C0)),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: suggestions.take(6).map((sug) {
                          return ActionChip(
                            avatar: Icon(
                              sug.is7to10 ? Icons.radar : Icons.add,
                              size: 14,
                              color: sug.is7to10 ? const Color(0xFFE65100) : AppColors.primary,
                            ),
                            label: Text(
                              '${sug.name} (~${sug.distKm.toStringAsFixed(1)} km${sug.is7to10 ? ' • 7-10 km' : ''})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: sug.is7to10 ? FontWeight.bold : FontWeight.normal,
                                color: sug.is7to10 ? const Color(0xFFBF360C) : AppColors.primary,
                              ),
                            ),
                            backgroundColor: sug.is7to10 ? const Color(0xFFFFF3E0) : const Color(0xFFF0F4F8),
                            side: BorderSide(
                              color: sug.is7to10 ? const Color(0xFFFFB74D) : AppColors.outlineVariant,
                            ),
                            onPressed: () {
                              if (requestedAreas.length < 3) {
                                setDialogState(() {
                                  requestedAreas.add(sug.name);
                                });
                              }
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Manual Area Dropdown
                    if (requestedAreas.length < 3) ...[
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        hint: const Text('Add area from district list...', style: TextStyle(fontSize: 12)),
                        decoration: InputDecoration(
                          labelText: 'Choose Area to Add (Max 3)',
                          prefixIcon: const Icon(Icons.add_location_outlined, size: 18),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: allDistrictAreas
                            .where((a) => !requestedAreas.contains(a))
                            .map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 12))))
                            .toList(),
                        onChanged: (val) {
                          if (val != null && requestedAreas.length < 3) {
                            setDialogState(() {
                              requestedAreas.add(val);
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Reason Field
                    TextField(
                      controller: reasonController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Reason for Area Change *',
                        hintText: 'e.g. Relocated residence to Bavdhan, extending work radius to meet demand',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (reasonController.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Please state the reason for requesting area change.')),
                                  );
                                  return;
                                }
                                setDialogState(() => isSubmitting = true);
                                try {
                                  await DI.workerRepo.raiseAreaChangeTicket(
                                    workerId: worker.id,
                                    requestedAreas: requestedAreas,
                                    reason: reasonController.text.trim(),
                                  );
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Area Change Ticket submitted to Federation Admin for approval!'),
                                        backgroundColor: Color(0xFF2E7D32),
                                      ),
                                    );
                                    _refreshData();
                                  }
                                } catch (e) {
                                  setDialogState(() => isSubmitting = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Failed to submit ticket: $e')),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Submit Ticket to Federation Admin', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAvailabilityToggle(WorkerProfile worker) {
    final isAvailable = worker.isAvailable;
    return Material(
      color: Colors.transparent,
      child: SwitchListTile(
        value: isAvailable,
        onChanged: (val) async { await DI.workerRepo.updateWorkerAvailability(worker.id, val); _refreshData(); },
        activeThumbColor: AppColors.onTertiaryContainer,
        secondary: Icon(isAvailable ? Icons.notifications_active : Icons.notifications_off, color: isAvailable ? AppColors.onTertiaryContainer : AppColors.outline),
        title: Text('Active Duty Status', style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(isAvailable ? 'Receiving local job requests' : 'Currently offline', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
      ),
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





