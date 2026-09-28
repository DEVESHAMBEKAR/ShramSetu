import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/repositories/i_storage_repository.dart';
import 'worker_under_verification_screen.dart';

class WorkerRegistrationScreen extends StatefulWidget {
  const WorkerRegistrationScreen({super.key});

  @override
  State<WorkerRegistrationScreen> createState() =>
      _WorkerRegistrationScreenState();
}

class _WorkerRegistrationScreenState extends State<WorkerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  String _selectedSkill = 'Plumbing & Pipe Fitting';
  int _selectedExperienceYears = 3;
  String _selectedArea = 'Kothrud, Pune';

  bool _agreedToCharter = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Uploaded documents state: docType -> PlatformFile
  final Map<String, PlatformFile> _uploadedFiles = {};
  final Set<String> _uploadingDocTypes = {};

  final List<String> _availableSkills = [
    'Plumbing & Pipe Fitting',
    'Electrical & Home Wiring',
    'Carpentry & Woodwork',
    'Masonry & Civil Repair',
    'Home Deep Cleaning',
    'Appliance Repair (AC / Fridge / Washing Machine)',
    'Painting & Wall Waterproofing',
    'Welding & Metal Fabrication',
    'General Maintenance & Handyman',
  ];

  final List<String> _puneAreas = [
    'Kothrud, Pune',
    'Shivajinagar, Pune',
    'Hinjewadi, Pune',
    'Hadapsar, Pune',
    'Baner & Balewadi, Pune',
    'Wakad & Pimple Saudagar, Pune',
    'Viman Nagar & Kalyani Nagar, Pune',
    'Swargate & Bibwewadi, Pune',
    'Pimpri-Chinchwad, Pune',
    'Katraj & Dhankawadi, Pune',
    'Aundh & Pashan, Pune',
    'Kharadi & Wagholi, Pune',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialUserData() async {
    try {
      final user = await DI.authRepo.getCurrentUser();
      if (user != null) {
        setState(() {
          _phoneController.text = user.phone ?? '';
          final metaName = (user.userMetadata?['full_name'] ?? user.userMetadata?['name']) as String?;
          if (metaName != null && metaName.isNotEmpty && !metaName.startsWith('User ')) {
            _nameController.text = metaName;
          }
        });

        // Also check if user profile exists
        final dbUser = await DI.userRepo.getUserProfile(user.id);
        if (dbUser != null) {
          final dbName = (dbUser['full_name'] as String?)?.trim() ?? '';
          if (dbName.isNotEmpty && !dbName.startsWith('User ') && _nameController.text.isEmpty) {
            setState(() {
              _nameController.text = dbName;
            });
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _pickAndUploadDocument(String docType) async {
    setState(() => _uploadingDocTypes.add(docType));
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );

      if (result.isNotEmpty) {
        final file = result.first;
        setState(() {
          _uploadedFiles[docType] = file;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${_getDocumentLabel(docType)} attached: ${file.name}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File selection note: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploadingDocTypes.remove(docType));
      }
    }
  }

  String _getDocumentLabel(String docType) {
    switch (docType) {
      case 'IDENTITY':
        return 'Identity Proof (Aadhaar / Voter ID / PAN)';
      case 'ADDRESS':
        return 'Address Proof (Electricity Bill / Rent Agreement)';
      case 'SKILL_CERTIFICATE':
        return 'Trade / Skill Certificate (ITI / License)';
      default:
        return 'Document';
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_uploadedFiles.containsKey('IDENTITY')) {
      setState(() => _errorMessage = 'Please attach your Identity Proof (Aadhaar / Voter ID / PAN).');
      return;
    }

    if (!_uploadedFiles.containsKey('ADDRESS')) {
      setState(() => _errorMessage = 'Please attach your Address Proof (Electricity Bill / Rent Agreement).');
      return;
    }

    if (!_agreedToCharter) {
      setState(() => _errorMessage = 'Please agree to the ShramSetu Federation Artisan Charter.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final user = await DI.authRepo.getCurrentUser();
      final userId = user?.id ?? 'worker_${_phoneController.text}';
      final cleanName = _nameController.text.trim();
      final phone = _phoneController.text.trim();

      // 1. Register worker profile in users and workers tables
      await DI.workerRepo.registerWorker(
        workerId: userId,
        fullName: cleanName,
        phone: phone,
        skill: _selectedSkill,
        experienceYears: _selectedExperienceYears,
        serviceLocation: _selectedArea,
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : 'Certified $_selectedSkill artisan serving $_selectedArea with $_selectedExperienceYears years of experience.',
      );

      // 2. Upload attached documents
      for (final entry in _uploadedFiles.entries) {
        final docType = entry.key;
        final file = entry.value;
        final fileBytes = await file.readAsBytes();
        final ext = file.extension?.toLowerCase() ?? 'jpg';
        final mimeType = ext == 'pdf' ? 'application/pdf' : 'image/$ext';
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final storagePath = '$userId/$docType-$timestamp.$ext';

        try {
          await DI.storageRepo.uploadFile(
            bucket: StorageBucket.workerDocuments,
            path: storagePath,
            fileBytes: fileBytes,
            mimeType: mimeType,
          );
        } catch (_) {}

        await DI.workerRepo.submitVerificationDocument(
          userId,
          docType,
          storagePath,
          file.name,
          mimeType,
          fileBytes.length,
        );
      }

      // 3. Mark for verification
      await DI.workerRepo.submitForVerification(userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.onTertiaryContainer,
            content: Text('Registration and documents submitted for Federation Verification!'),
          ),
        );

        // Replace route directly to Under Verification screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const WorkerUnderVerificationScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isSubmitting = false;
      });
    }
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
                  'Artisan Enrollment & Registration',
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.marginMobile,
              vertical: AppSpacing.spacingMd,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderBanner(),
                  const SizedBox(height: 16),
                  if (_errorMessage != null) _buildErrorBanner(),
                  _buildPersonalInfoSection(),
                  const SizedBox(height: 16),
                  _buildTradeDetailsSection(),
                  const SizedBox(height: 16),
                  _buildDocumentUploadSection(),
                  const SizedBox(height: 16),
                  _buildCharterAgreementSection(),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const Icon(Icons.badge, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Artisan Cooperative Registration',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Complete your trade registration and submit verification documents. Access to receiving customer jobs is activated after administrator verification.',
                  style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.onErrorContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.onErrorContainer, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
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
              const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Personal & Contact Details',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Legal Name *',
              hintText: 'e.g. Rahul Ananda Patil',
              prefixIcon: const Icon(Icons.badge_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter your full name as printed on your ID.';
              }
              if (val.trim().length < 3) {
                return 'Name must be at least 3 characters long.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _phoneController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Registered Mobile Number',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              suffixIcon: const Icon(Icons.check_circle, color: AppColors.onTertiaryContainer, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeDetailsSection() {
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
              const Icon(Icons.handyman_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Trade & Service Area',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedSkill,
            decoration: InputDecoration(
              labelText: 'Primary Trade Specialization *',
              prefixIcon: const Icon(Icons.construction, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            items: _availableSkills.map((skill) {
              return DropdownMenuItem(value: skill, child: Text(skill));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedSkill = val);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<int>(
            value: _selectedExperienceYears,
            decoration: InputDecoration(
              labelText: 'Years of Experience *',
              prefixIcon: const Icon(Icons.history_toggle_off, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 Year (Beginner)')),
              DropdownMenuItem(value: 2, child: Text('2 Years')),
              DropdownMenuItem(value: 3, child: Text('3 Years (Experienced)')),
              DropdownMenuItem(value: 5, child: Text('5 Years (Senior Artisan)')),
              DropdownMenuItem(value: 8, child: Text('8 Years')),
              DropdownMenuItem(value: 10, child: Text('10+ Years (Master Artisan)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedExperienceYears = val);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _selectedArea,
            decoration: InputDecoration(
              labelText: 'Primary Service Locality in Pune *',
              prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            items: _puneAreas.map((area) {
              return DropdownMenuItem(value: area, child: Text(area));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedArea = val);
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _bioController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Brief Profile Bio (Optional)',
              hintText: 'e.g. Licensed residential plumbing, pipe leak detection, pump servicing.',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentUploadSection() {
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
              const Icon(Icons.file_copy_outlined, color: AppColors.primary, size: 20),
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
          const SizedBox(height: 6),
          const Text(
            'Documents are reviewed by the Federation Cooperative Administrator. Accepted formats: PDF, JPG, PNG (Max 10MB).',
            style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _buildUploadTile(
            docType: 'IDENTITY',
            title: '1. Identity Proof *',
            subtitle: 'Aadhaar Card, Voter ID, or PAN Card',
            icon: Icons.badge_outlined,
            isRequired: true,
          ),
          const SizedBox(height: 12),
          _buildUploadTile(
            docType: 'ADDRESS',
            title: '2. Address Proof *',
            subtitle: 'Electricity Bill, Ration Card, or Rent Agreement',
            icon: Icons.home_outlined,
            isRequired: true,
          ),
          const SizedBox(height: 12),
          _buildUploadTile(
            docType: 'SKILL_CERTIFICATE',
            title: '3. Trade / Skill Certificate',
            subtitle: 'ITI Certificate, Trade Union ID, or Apprentice Certificate',
            icon: Icons.school_outlined,
            isRequired: false,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTile({
    required String docType,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isRequired,
  }) {
    final file = _uploadedFiles[docType];
    final isAttached = file != null;
    final isUploading = _uploadingDocTypes.contains(docType);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isAttached ? const Color(0xFFF1F8E9) : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAttached ? AppColors.onTertiaryContainer : AppColors.outlineVariant,
          width: isAttached ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAttached ? AppColors.tertiaryContainer : AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAttached ? Icons.check : icon,
              color: isAttached ? AppColors.onTertiaryContainer : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary),
                ),
                Text(
                  isAttached
                      ? '${file.name} • Attached'
                      : subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isAttached ? AppColors.onTertiaryContainer : AppColors.outline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isUploading)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                side: BorderSide(
                  color: isAttached ? AppColors.onTertiaryContainer : AppColors.outlineVariant,
                ),
              ),
              onPressed: () => _pickAndUploadDocument(docType),
              icon: Icon(
                isAttached ? Icons.change_circle_outlined : Icons.upload_file,
                size: 16,
                color: isAttached ? AppColors.onTertiaryContainer : AppColors.primary,
              ),
              label: Text(
                isAttached ? 'Change' : 'Upload',
                style: TextStyle(
                  fontSize: 12,
                  color: isAttached ? AppColors.onTertiaryContainer : AppColors.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCharterAgreementSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _agreedToCharter,
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _agreedToCharter = val ?? false),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'I declare that the trade information and uploaded proof documents are genuine. I agree to operate under the ShramSetu Federation Artisan Charter and understand that access is granted following admin verification.',
                style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
        onPressed: _isSubmitting ? null : _submitRegistration,
        child: _isSubmitting
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                  SizedBox(width: 12),
                  Text('Submitting for Federation Verification...', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              )
            : const Text(
                'Submit Registration for Admin Verification',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
