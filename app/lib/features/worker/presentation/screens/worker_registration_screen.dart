import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/repositories/i_storage_repository.dart';
import 'worker_under_verification_screen.dart';

class WorkerRegistrationScreen extends StatefulWidget {
  final bool isResubmission;
  final String? changeRequestReason;

  const WorkerRegistrationScreen({
    super.key,
    this.isResubmission = false,
    this.changeRequestReason,
  });

  @override
  State<WorkerRegistrationScreen> createState() =>
      _WorkerRegistrationScreenState();
}

class _WorkerRegistrationScreenState extends State<WorkerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Full Name & 2. Mobile Number
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // 4. DOB & 5. Gender
  final TextEditingController _dobController = TextEditingController();
  String _selectedGender = 'Male';

  // 6. Current Address, 7. City, 8. District, 9. PIN Code
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController(text: 'Pune');
  final TextEditingController _districtController = TextEditingController(text: 'Pune');
  final TextEditingController _pinCodeController = TextEditingController();

  // 10. Trade, 11. Primary Skill, 12. Skill Level, 13. Experience, 14. Service Area, 15. Availability
  String _selectedTrade = 'Plumbing';
  String _selectedSkill = 'Plumbing & Pipe Fitting';
  String _selectedSkillLevel = 'Intermediate';
  int _selectedExperienceYears = 3;
  String _selectedArea = 'Kothrud, Pune';
  bool _isAvailable = true;

  // 18. Cooperative/Federation, 19. Membership ID
  final String _federationName = 'Pune District Labour Cooperative Federation';
  final TextEditingController _membershipIdController = TextEditingController();

  // 20. Worker Declaration
  bool _agreedToCharter = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  // Uploaded documents state: docType -> PlatformFile
  final Map<String, PlatformFile> _uploadedFiles = {};
  final Set<String> _uploadingDocTypes = {};

  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  final List<String> _skillLevels = ['Beginner', 'Intermediate', 'Expert'];
  final Map<String, String> _skillLevelLabels = {
    'Beginner': 'Beginner (1-2 yrs)',
    'Intermediate': 'Intermediate (3-5 yrs)',
    'Expert': 'Expert / Master Artisan (6+ yrs)',
  };
  final List<int> _experienceOptions = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 15, 20];

  final List<String> _tradeCategories = [
    'Plumbing',
    'Electrical',
    'Carpentry',
    'Masonry & Construction',
    'Cleaning & Sanitation',
    'Appliance Repair',
    'Painting & Waterproofing',
    'Welding & Fabrication',
    'General Maintenance',
  ];

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
    _dobController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _pinCodeController.dispose();
    _membershipIdController.dispose();
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

        // Check if existing worker record exists to prefill during edit/resubmission
        try {
          final worker = await DI.workerRepo.getWorkerProfile(user.id);
          if (worker.id.isNotEmpty && worker.name.isNotEmpty && !worker.name.startsWith('User ')) {
            setState(() {
              if (_nameController.text.isEmpty) _nameController.text = worker.name;
              if (worker.dob != null && worker.dob!.isNotEmpty) _dobController.text = worker.dob!;
              if (worker.gender != null && _genderOptions.contains(worker.gender)) _selectedGender = worker.gender!;
              if (worker.address != null && worker.address!.isNotEmpty) _addressController.text = worker.address!;
              if (worker.city != null && worker.city!.isNotEmpty) _cityController.text = worker.city!;
              if (worker.district != null && worker.district!.isNotEmpty) _districtController.text = worker.district!;
              if (worker.pinCode != null && worker.pinCode!.isNotEmpty) _pinCodeController.text = worker.pinCode!;
              if (worker.trade != null && _tradeCategories.contains(worker.trade)) _selectedTrade = worker.trade!;
              if (worker.primarySkill != null && _availableSkills.contains(worker.primarySkill)) {
                _selectedSkill = worker.primarySkill!;
              }
              if (worker.skillLevel != null) {
                if (_skillLevels.contains(worker.skillLevel)) {
                  _selectedSkillLevel = worker.skillLevel!;
                } else if (worker.skillLevel!.toLowerCase().contains('begin')) {
                  _selectedSkillLevel = 'Beginner';
                } else if (worker.skillLevel!.toLowerCase().contains('expert')) {
                  _selectedSkillLevel = 'Expert';
                } else {
                  _selectedSkillLevel = 'Intermediate';
                }
              }
              if (worker.experience.isNotEmpty) {
                final match = RegExp(r'\d+').firstMatch(worker.experience);
                if (match != null) {
                  final yrs = int.tryParse(match.group(0)!);
                  if (yrs != null && _experienceOptions.contains(yrs)) {
                    _selectedExperienceYears = yrs;
                  }
                }
              }
              if (worker.serviceLocation.isNotEmpty && _puneAreas.contains(worker.serviceLocation)) {
                _selectedArea = worker.serviceLocation;
              }
              if (worker.membershipId != null && worker.membershipId!.isNotEmpty) {
                _membershipIdController.text = worker.membershipId!;
              }
              _isAvailable = worker.isAvailable;
            });
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> _selectDob() async {
    final now = DateTime.now();
    final initialDate = DateTime(now.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 70),
      lastDate: DateTime(now.year - 18),
      helpText: 'Select Date of Birth (Must be 18+)',
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
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

    if (!widget.isResubmission && !_uploadedFiles.containsKey('IDENTITY')) {
      setState(() => _errorMessage = 'Please attach your Identity Proof (Aadhaar / Voter ID / PAN).');
      return;
    }

    if (!widget.isResubmission && !_uploadedFiles.containsKey('ADDRESS')) {
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

      // 1. Register worker profile in users and workers tables with 20 fields
      await DI.workerRepo.registerWorker(
        workerId: userId,
        fullName: cleanName,
        phone: phone,
        skill: _selectedSkill,
        experienceYears: _selectedExperienceYears,
        serviceLocation: _selectedArea,
        dob: _dobController.text.trim().isNotEmpty ? _dobController.text.trim() : null,
        gender: _selectedGender,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        district: _districtController.text.trim(),
        pinCode: _pinCodeController.text.trim(),
        trade: _selectedTrade,
        skillLevel: _selectedSkillLevel,
        federationName: _federationName,
        membershipId: _membershipIdController.text.trim().isNotEmpty ? _membershipIdController.text.trim() : null,
        bio: _bioController.text.trim().isNotEmpty
            ? _bioController.text.trim()
            : 'Certified $_selectedSkill artisan serving $_selectedArea with $_selectedExperienceYears years of experience.',
        declarationAccepted: _agreedToCharter,
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

      // 3. Mark for verification (submit initial or resubmit)
      if (widget.isResubmission) {
        await DI.workerRepo.resubmitForVerification(userId);
      } else {
        await DI.workerRepo.submitForVerification(userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.onTertiaryContainer,
            content: Text(widget.isResubmission
                ? 'Application updated and resubmitted for Federation Review!'
                : 'Registration and documents submitted for Federation Verification!'),
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
                  if (widget.changeRequestReason != null && widget.changeRequestReason!.isNotEmpty)
                    _buildChangesRequiredBanner(),
                  if (_errorMessage != null) _buildErrorBanner(),
                  _buildPersonalInfoSection(),
                  const SizedBox(height: 16),
                  _buildAddressSection(),
                  const SizedBox(height: 16),
                  _buildTradeDetailsSection(),
                  const SizedBox(height: 16),
                  _buildCooperativeSection(),
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

  Widget _buildChangesRequiredBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF9800), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit_note, color: Color(0xFFE65100), size: 22),
              SizedBox(width: 8),
              Text(
                'Changes Requested by Federation Officer',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFE65100)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            widget.changeRequestReason!,
            style: const TextStyle(fontSize: 12, color: AppColors.primary, height: 1.4),
          ),
          const SizedBox(height: 4),
          const Text(
            'Please update the indicated information or upload corrected documents below and resubmit.',
            style: TextStyle(fontSize: 11, color: AppColors.outline),
          ),
        ],
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
                Text(
                  widget.isResubmission ? 'Update & Resubmit Application' : 'Artisan Cooperative Registration',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Complete your 20-point trade registration and submit verification documents. Access to receiving customer jobs is activated after federation review.',
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
                '1. Basic Information',
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
              labelText: '1. Full Legal Name *',
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
              labelText: '2. Registered Mobile Number',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              suffixIcon: const Icon(Icons.check_circle, color: AppColors.onTertiaryContainer, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dobController,
                  readOnly: true,
                  onTap: _selectDob,
                  decoration: InputDecoration(
                    labelText: '4. Date of Birth *',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: const Icon(Icons.cake_outlined, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_month, size: 20),
                      onPressed: _selectDob,
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Select date of birth.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _genderOptions.contains(_selectedGender) ? _selectedGender : _genderOptions.first,
                  decoration: InputDecoration(
                    labelText: '5. Gender *',
                    prefixIcon: const Icon(Icons.wc, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedGender = val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
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
              const Icon(Icons.home_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '2. Current Address & Location',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: '6. Current Residential Address *',
              hintText: 'e.g. Flat 301, Shanti Niwas, Paud Road',
              prefixIcon: const Icon(Icons.location_city_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Please enter current residential address.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: '7. City *',
                    prefixIcon: const Icon(Icons.map_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter city.' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _districtController,
                  decoration: InputDecoration(
                    labelText: '8. District *',
                    prefixIcon: const Icon(Icons.apartment_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Enter district.' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _pinCodeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: '9. PIN Code *',
                    hintText: '411038',
                    prefixIcon: const Icon(Icons.pin_drop_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter PIN.';
                    if (val.trim().length != 6) return '6 digits.';
                    return null;
                  },
                ),
              ),
            ],
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
                '3. Work & Skill Information',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _tradeCategories.contains(_selectedTrade) ? _selectedTrade : _tradeCategories.first,
            decoration: InputDecoration(
              labelText: '10. Worker Category / Trade *',
              prefixIcon: const Icon(Icons.category_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            items: _tradeCategories.map((trade) {
              return DropdownMenuItem(value: trade, child: Text(trade));
            }).toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedTrade = val);
            },
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _availableSkills.contains(_selectedSkill) ? _selectedSkill : _availableSkills.first,
            decoration: InputDecoration(
              labelText: '11. Primary Skill *',
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
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _skillLevels.contains(_selectedSkillLevel) ? _selectedSkillLevel : 'Intermediate',
                  decoration: InputDecoration(
                    labelText: '12. Skill Level *',
                    prefixIcon: const Icon(Icons.grade_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  items: _skillLevels.map((lvl) {
                    return DropdownMenuItem(
                      value: lvl,
                      child: Text(_skillLevelLabels[lvl] ?? lvl, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSkillLevel = val);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _experienceOptions.contains(_selectedExperienceYears) ? _selectedExperienceYears : 3,
                  decoration: InputDecoration(
                    labelText: '13. Years of Experience *',
                    prefixIcon: const Icon(Icons.history_toggle_off, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  items: _experienceOptions.map((yrs) {
                    return DropdownMenuItem(
                      value: yrs,
                      child: Text(yrs >= 10 ? '$yrs+ Years' : (yrs == 1 ? '1 Year' : '$yrs Years')),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedExperienceYears = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _puneAreas.contains(_selectedArea) ? _selectedArea : _puneAreas.first,
            decoration: InputDecoration(
              labelText: '14. Service Area / Preferred Working Locality *',
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '15. Availability to Receive Jobs',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            subtitle: Text(
              _isAvailable ? 'Currently Available (accepting jobs once verified)' : 'Busy / Not accepting new jobs right now',
              style: const TextStyle(fontSize: 12, color: AppColors.outline),
            ),
            value: _isAvailable,
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _isAvailable = val),
          ),
          const SizedBox(height: 8),
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

  Widget _buildCooperativeSection() {
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
              const Icon(Icons.diversity_3_outlined, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '4. Cooperative / Federation Info',
                style: AppTypography.titleMd.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            readOnly: true,
            initialValue: _federationName,
            decoration: InputDecoration(
              labelText: '18. Registered Federation / Cooperative',
              prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerHigh.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _membershipIdController,
            decoration: InputDecoration(
              labelText: '19. Cooperative Membership ID (Optional)',
              hintText: 'e.g. FED-PUN-2024-9128',
              prefixIcon: const Icon(Icons.card_membership_outlined, size: 20),
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
                  Text(
                    'Submitting for Federation Review...',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : Text(
                widget.isResubmission
                    ? 'Resubmit Application for Federation Review'
                    : 'Submit Registration for Admin Verification',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
