import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/repositories/i_storage_repository.dart';
import '../../../../core/models/federation_models.dart';
import '../../../../core/services/india_geography_service.dart';
import 'worker_under_verification_screen.dart';
import '../../../../shared/widgets/area_not_serviceable_screen.dart';
import '../../../../core/utils/phone_number_util.dart';

class WorkerRegistrationScreen extends StatefulWidget {
  final bool isResubmission;
  final String? changeRequestReason;

  const WorkerRegistrationScreen({
    super.key,
    this.isResubmission = false,
    this.changeRequestReason,
  });

  static const Map<String, List<String>> tradeSubSkills = {
    'Plumbing': [
      'Plumbing & Pipe Fitting',
      'Drainage & Sewage Line Cleaning',
      'Water Tank Cleaning & Installation',
      'Bathroom Fittings & Sanitary Fixtures',
      'Water Pump & Motor Repair',
      'Leak Detection & Commercial Plumbing',
    ],
    'Electrical': [
      'Electrical & Home Wiring',
      'Switchboard & MCB Fuse Installation',
      'Inverter & Battery Wiring',
      'Ceiling Fan & Light Fixture Installation',
      'Three-Phase Industrial Wiring',
      'Earthing & Power Surge Protection',
    ],
    'Carpentry': [
      'Carpentry & Woodwork',
      'Furniture Assembly & Repair',
      'Modular Kitchen & Wardrobe Fabrication',
      'Door, Window & Lock Fitting',
      'Wood Polishing & Varnishing',
      'Custom Cabinet & Shelf Making',
    ],
    'Masonry & Construction': [
      'Masonry & Civil Repair',
      'Tile, Marble & Granite Laying',
      'Wall Plastering & Bricklaying',
      'Concrete Flooring & Structural Repair',
      'Roof Sealing & Waterproofing Works',
    ],
    'Cleaning & Sanitation': [
      'Home Deep Cleaning',
      'Kitchen & Chimney Degreasing',
      'Bathroom Disinfection & Tile Scrubbing',
      'Sofa, Carpet & Mattress Shampooing',
      'Water Tank Deep Sanitation',
      'Post-Construction Cleanup',
    ],
    'Appliance Repair': [
      'Appliance Repair (AC / Fridge / Washing Machine)',
      'AC Servicing, Gas Refill & Installation',
      'Refrigerator & Deep Freezer Repair',
      'Washing Machine & Dryer Repair',
      'Microwave & Induction Hob Repair',
      'Water Purifier (RO) Servicing & Filter Replacement',
      'Geyser & Water Heater Repair',
    ],
    'Painting & Waterproofing': [
      'Painting & Wall Waterproofing',
      'Interior Emulsion & Texture Painting',
      'Exterior Weatherproof Coating',
      'Wall Putty, Primer & Crack Sealing',
      'Wood & Metal Enamel Painting',
      'Terrace & Balcony Waterproofing',
    ],
    'Welding & Fabrication': [
      'Welding & Metal Fabrication',
      'Safety Grill & Gate Fabrication',
      'Shed, Truss & Roof Structure Welding',
      'Aluminum Sliding Window Fabrication',
      'Stainless Steel Railing Work',
    ],
    'General Maintenance': [
      'General Maintenance & Handyman',
      'Minor Civil, Wall Drill & Hanging Services',
      'Locksmith & Key Duplication Service',
      'Curtain Rod & Blinds Installation',
      'Preventive Home Maintenance Inspection',
    ],
  };

  @override
  State<WorkerRegistrationScreen> createState() =>
      _WorkerRegistrationScreenState();
}

class _WorkerRegistrationScreenState extends State<WorkerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // 1. Full Name, 2. Mobile Number & 3. Email Address
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // 4. DOB & 5. Gender
  final TextEditingController _dobController = TextEditingController();
  String _selectedGender = 'Male';

  // 6. Current Address, 7. City, 8. District, 9. PIN Code & Geographic Dropdowns
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();
  final TextEditingController _pinCodeController = TextEditingController();

  String _selectedState = 'Maharashtra';
  String _selectedDistrict = 'Pune';
  String _selectedCityOrArea = 'Kothrud';
  List<String> _availableDistricts = [];
  List<String> _availableAreas = [];
  bool _isResolvingPincode = false;
  String? _pincodeFeedback;

  // 10. Trade, 11. Primary Skill, 12. Skill Level, 13. Experience, 14. Service Area, 15. Availability
  String? _selectedTrade;
  String? _selectedSkill;
  String _selectedSkillLevel = 'Intermediate';
  int _selectedExperienceYears = 3;
  String _selectedArea = 'Kothrud, Pune';
  bool _isAvailable = true;

  // 18. Cooperative/Federation, 19. Membership ID
  String? _selectedFederationId;
  String _federationName = '';
  bool _userSelectedFederationManually = false;
  final TextEditingController _membershipIdController = TextEditingController();
  List<FederationModel> _availableFederations = List.from(FederationModel.defaultFederations);

  Future<void> _loadFederations() async {
    try {
      final feds = await FederationModel.fetchAllFederations();
      if (mounted && feds.isNotEmpty) {
        setState(() {
          _availableFederations = feds;
        });
        if (!_userSelectedFederationManually) {
          _autoRouteFederation(_selectedArea);
        }
      }
    } catch (e) {
      debugPrint('[WorkerRegistration] loadFederations error: $e');
    }
  }

  void _autoRouteFederation(String text) {
    if (text.trim().isEmpty) return;
    if (_userSelectedFederationManually && _selectedFederationId != null && _selectedFederationId!.isNotEmpty) {
      return;
    }
    final matched = FederationModel.findFederationForLocation(
      district: _districtController.text.trim().isNotEmpty ? _districtController.text.trim() : _selectedDistrict,
      city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : _selectedCityOrArea,
      state: _selectedState,
      pincode: _pinCodeController.text.trim(),
      location: text,
      federationsList: _availableFederations,
    );
    if (matched != null) {
      setState(() {
        _selectedFederationId = matched.id;
        _federationName = matched.name;
        _selectedDistrict = matched.district;
        _districtController.text = matched.district;
        if (matched.city.isNotEmpty) {
          _selectedCityOrArea = matched.city;
          _cityController.text = matched.city;
        }
      });
    } else {
      setState(() {
        _selectedFederationId = null;
        _federationName = 'Cooperative Expansion Zone (${_selectedDistrict.isNotEmpty ? _selectedDistrict : "Waitlist"})';
      });
    }
  }

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

  static Map<String, List<String>> get tradeSubSkills => WorkerRegistrationScreen.tradeSubSkills;

  final List<String> _serviceAreasList = [
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
    'CIDCO, Nashik',
    'Panchavati, Nashik',
    'College Road, Nashik',
    'Satpur & Ambad MIDC, Nashik',
    'Nashik Road, Nashik',
    'Andheri & Juhu, Mumbai',
    'Bandra & Khar, Mumbai',
    'Dadar & Parel, Mumbai',
    'Thane & Mulund, MMR',
    'Navi Mumbai & Vashi',
    'CIDCO, Chhatrapati Sambhajinagar',
    'Waluj MIDC, Chhatrapati Sambhajinagar',
    'Dharampeth & Sitabuldi, Nagpur',
    'Sadar & Civil Lines, Nagpur',
  ];

  @override
  void initState() {
    super.initState();
    _availableDistricts = IndiaGeographyService.getDistricts(_selectedState);
    _availableAreas = IndiaGeographyService.getAreasForDistrict(_selectedState, _selectedDistrict);
    _districtController.text = _selectedDistrict;
    _cityController.text = _selectedCityOrArea;
    final initialFed = FederationModel.findFederationForLocation(
      district: _selectedDistrict,
      city: _selectedCityOrArea,
      location: _selectedArea,
      federationsList: _availableFederations,
    );
    _selectedFederationId = initialFed?.id;
    _federationName = initialFed?.name ?? 'Cooperative Expansion Zone ($_selectedDistrict)';
    _loadInitialUserData();
    _loadFederations();
  }

  Future<void> _handlePincodeAutoDetect(String val) async {
    final clean = val.replaceAll(RegExp(r'\D'), '').trim();
    if (clean.length == 6) {
      setState(() {
        _isResolvingPincode = true;
        _pincodeFeedback = 'Resolving location...';
      });
      final res = await IndiaGeographyService.lookupPincode(clean);
      if (res != null && mounted) {
        setState(() {
          _selectedState = res.state;
          _availableDistricts = IndiaGeographyService.getDistricts(res.state);
          _selectedDistrict = _availableDistricts.contains(res.district)
              ? res.district
              : (_availableDistricts.isNotEmpty ? _availableDistricts.first : res.district);
          _districtController.text = _selectedDistrict;

          final areas = res.areas.isNotEmpty
              ? res.areas
              : IndiaGeographyService.getAreasForDistrict(_selectedState, _selectedDistrict);
          _availableAreas = areas;
          _selectedCityOrArea = areas.isNotEmpty ? areas.first : res.city;
          _cityController.text = _selectedCityOrArea;
          _isResolvingPincode = false;
          _pincodeFeedback = 'Detected: $_selectedDistrict, $_selectedState (${res.isFromNetwork ? "Live Post Office" : "Postal Directory"})';
        });
        _autoRouteFederation(_selectedDistrict);
      } else if (mounted) {
        setState(() {
          _isResolvingPincode = false;
          _pincodeFeedback = null;
        });
      }
    } else {
      if (_pincodeFeedback != null) {
        setState(() => _pincodeFeedback = null);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
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
          final rawPhone = user.phone ?? '';
          final cleanedPhone = PhoneNumberUtil.cleanIndianPhone(rawPhone);
          _phoneController.text = cleanedPhone.isNotEmpty ? cleanedPhone : rawPhone;
          if (user.email != null && user.email!.isNotEmpty) {
            _emailController.text = user.email!;
          }
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
          final dbEmail = (dbUser['email'] as String?)?.trim() ?? '';
          if (dbEmail.isNotEmpty && _emailController.text.isEmpty) {
            setState(() {
              _emailController.text = dbEmail;
            });
          }
        }

        // Check if existing worker record exists to prefill during edit/resubmission
        try {
          final worker = await DI.workerRepo.getWorkerProfile(user.id);
          if (worker.id.isNotEmpty && worker.name.isNotEmpty && !worker.name.startsWith('User ')) {
            setState(() {
              if (_nameController.text.isEmpty) _nameController.text = worker.name;
              if (worker.email != null && worker.email!.isNotEmpty && _emailController.text.isEmpty) {
                _emailController.text = worker.email!;
              }
              if (worker.dob != null && worker.dob!.isNotEmpty) _dobController.text = worker.dob!;
              if (worker.gender != null && _genderOptions.contains(worker.gender)) _selectedGender = worker.gender!;
              if (worker.address != null && worker.address!.isNotEmpty) _addressController.text = worker.address!;
              if (worker.city != null && worker.city!.isNotEmpty) _cityController.text = worker.city!;
              if (worker.district != null && worker.district!.isNotEmpty) _districtController.text = worker.district!;
              if (worker.pinCode != null && worker.pinCode!.isNotEmpty) _pinCodeController.text = worker.pinCode!;
              if (worker.trade != null && _tradeCategories.contains(worker.trade)) {
                _selectedTrade = worker.trade!;
              }
              if (worker.primarySkill != null && worker.primarySkill!.isNotEmpty) {
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
              if (worker.serviceLocation.isNotEmpty && _serviceAreasList.contains(worker.serviceLocation)) {
                _selectedArea = worker.serviceLocation;
              }
              if (worker.membershipId != null && worker.membershipId!.isNotEmpty) {
                _membershipIdController.text = worker.membershipId!;
              }
              _isAvailable = worker.isAvailable;
              final fed = FederationModel.resolveFederation(
                federationId: worker.federationRefId,
                federationName: worker.guildName,
                district: worker.district ?? _selectedDistrict,
                city: worker.city ?? _selectedCityOrArea,
                location: worker.serviceLocation,
                address: worker.address,
              );
              _selectedFederationId = fed.id;
              _federationName = fed.name;
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

    if (_selectedTrade == null || _selectedTrade!.trim().isEmpty) {
      setState(() => _errorMessage = 'Please select your Worker Category / Trade.');
      return;
    }

    if (_selectedSkill == null || _selectedSkill!.trim().isEmpty) {
      setState(() => _errorMessage = 'Please select your specific Primary Sub-Skill.');
      return;
    }

    final hasAreaFederation = FederationModel.isAreaCoveredByFederation(
      district: _districtController.text.trim(),
      city: _cityController.text.trim(),
      state: _selectedState,
      pincode: _pinCodeController.text.trim(),
      location: _selectedArea,
      address: _addressController.text.trim(),
      federationsList: _availableFederations,
    );

    if (hasAreaFederation && (_selectedFederationId == null || _selectedFederationId!.isEmpty)) {
      final matching = FederationModel.findFederationForLocation(
        district: _districtController.text.trim(),
        city: _cityController.text.trim(),
        state: _selectedState,
        pincode: _pinCodeController.text.trim(),
        location: _selectedArea,
        address: _addressController.text.trim(),
        federationsList: _availableFederations,
      );
      if (matching != null) {
        _selectedFederationId = matching.id;
        _federationName = matching.name;
      }
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
      final cleanName = _nameController.text.trim();
      final phone = PhoneNumberUtil.cleanIndianPhone(_phoneController.text.trim());
      final effectivePhone = phone.isNotEmpty ? phone : _phoneController.text.trim();
      final userId = user?.id ?? 'worker_$effectivePhone';

      // Resolve authoritative federation using identical ID from Super Admin & dynamic list
      final targetFed = (_selectedFederationId != null && _selectedFederationId!.isNotEmpty)
          ? _availableFederations.firstWhere(
              (f) => f.id == _selectedFederationId,
              orElse: () => FederationModel.resolveFederation(
                federationId: _selectedFederationId,
                federationName: _federationName,
                district: _districtController.text.trim(),
                city: _cityController.text.trim(),
                location: _selectedArea,
                address: _addressController.text.trim(),
                federationsList: _availableFederations,
              ),
            )
          : (hasAreaFederation
              ? FederationModel.resolveFederation(
                  district: _districtController.text.trim(),
                  city: _cityController.text.trim(),
                  location: _selectedArea,
                  address: _addressController.text.trim(),
                  federationsList: _availableFederations,
                )
              : null);

      // 1. Register worker profile in users and workers tables with 20 fields
      await DI.workerRepo.registerWorker(
        workerId: userId,
        fullName: cleanName,
        phone: effectivePhone,
        email: _emailController.text.trim(),
        skill: _selectedSkill!,
        experienceYears: _selectedExperienceYears,
        serviceLocation: _selectedArea,
        dob: _dobController.text.trim().isNotEmpty ? _dobController.text.trim() : null,
        gender: _selectedGender,
        address: _addressController.text.trim(),
        city: _cityController.text.trim(),
        district: _districtController.text.trim(),
        pinCode: _pinCodeController.text.trim(),
        trade: _selectedTrade!,
        skillLevel: _selectedSkillLevel,
        federationName: targetFed?.name ?? 'Cooperative Expansion Zone (${_districtController.text.trim()})',
        federationId: targetFed?.id,
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
                : (hasAreaFederation
                    ? 'Registration and documents submitted for Federation Verification!'
                    : 'Registration saved in Founding Artisan Expansion Waitlist!')),
          ),
        );

        if (hasAreaFederation) {
          // Replace route directly to Under Verification screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WorkerUnderVerificationScreen()),
          );
        } else {
          // Replace route to AreaNotServiceableScreen (Expansion Waitlist)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => AreaNotServiceableScreen(
                userRole: 'WORKER',
                reason: ServiceUnavailableReason.noFederation,
                district: _districtController.text.trim(),
                area: _selectedCityOrArea,
                city: _cityController.text.trim(),
                state: _selectedState,
                pincode: _pinCodeController.text.trim().isNotEmpty ? _pinCodeController.text.trim() : null,
              ),
            ),
          );
        }
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
            keyboardType: TextInputType.phone,
            inputFormatters: [IndianPhoneNumberFormatter()],
            decoration: InputDecoration(
              labelText: '2. Registered Mobile Number *',
              hintText: 'e.g. 9876543210',
              prefixIcon: const Icon(Icons.phone_outlined, size: 20),
              suffixIcon: const Icon(Icons.check_circle, color: AppColors.onTertiaryContainer, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            validator: (val) => PhoneNumberUtil.validateIndianMobile(val),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: '3. Official Email Address *',
              hintText: 'e.g. artisan@gmail.com',
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              suffixIcon: const Icon(Icons.mark_email_read_outlined, color: AppColors.onTertiaryContainer, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Official email address is required.';
              }
              if (!RegExp(r'^[\w\.-]+@[\w-]+\.\w{2,}$').hasMatch(val.trim())) {
                return 'Please enter a valid email address.';
              }
              return null;
            },
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
                  initialValue: _genderOptions.contains(_selectedGender) ? _selectedGender : _genderOptions.first,
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

          // PIN Code with Live Auto-Detection & State Dropdown
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _pinCodeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: '7. PIN Code *',
                    hintText: '411038',
                    counterText: '',
                    prefixIcon: const Icon(Icons.pin_drop_outlined, size: 20),
                    suffixIcon: _isResolvingPincode
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                          )
                        : (_pincodeFeedback != null
                            ? const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 20)
                            : null),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  onChanged: _handlePincodeAutoDetect,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Enter PIN.';
                    if (val.trim().length != 6) return '6 digits.';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              // State Dropdown (All 36 States & UTs of India)
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  initialValue: IndiaGeographyService.states.contains(_selectedState)
                      ? _selectedState
                      : IndiaGeographyService.states.first,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: '8. State *',
                    prefixIcon: const Icon(Icons.public, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  items: IndiaGeographyService.states.map((st) {
                    return DropdownMenuItem(
                      value: st,
                      child: Text(st, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedState = val;
                        _availableDistricts = IndiaGeographyService.getDistricts(val);
                        _selectedDistrict = _availableDistricts.isNotEmpty ? _availableDistricts.first : 'Pune';
                        _districtController.text = _selectedDistrict;
                        _availableAreas = IndiaGeographyService.getAreasForDistrict(val, _selectedDistrict);
                        _selectedCityOrArea = _availableAreas.isNotEmpty ? _availableAreas.first : _selectedDistrict;
                        _cityController.text = _selectedCityOrArea;
                      });
                      _autoRouteFederation(_selectedDistrict);
                    }
                  },
                ),
              ),
            ],
          ),

          if (_pincodeFeedback != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF81C784)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF2E7D32), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _pincodeFeedback!,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF1B5E20), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // District & City/Area Dropdowns
          Row(
            children: [
              // District Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('dist_${_selectedState}_$_selectedDistrict'),
                  initialValue: _availableDistricts.contains(_selectedDistrict)
                      ? _selectedDistrict
                      : (_availableDistricts.isNotEmpty ? _availableDistricts.first : null),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: '9. District *',
                    prefixIcon: const Icon(Icons.apartment_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  items: _availableDistricts.map((d) {
                    return DropdownMenuItem(
                      value: d,
                      child: Text(d, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedDistrict = val;
                        _districtController.text = val;
                        _availableAreas = IndiaGeographyService.getAreasForDistrict(_selectedState, val);
                        _selectedCityOrArea = _availableAreas.isNotEmpty ? _availableAreas.first : val;
                        _cityController.text = _selectedCityOrArea;
                      });
                      _autoRouteFederation(val);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              // City / Area Dropdown
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey('area_${_selectedDistrict}_$_selectedCityOrArea'),
                  initialValue: _availableAreas.contains(_selectedCityOrArea)
                      ? _selectedCityOrArea
                      : (_availableAreas.isNotEmpty ? _availableAreas.first : null),
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: '10. City / Area *',
                    prefixIcon: const Icon(Icons.map_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: AppColors.surfaceContainerLowest,
                  ),
                  items: _availableAreas.map((a) {
                    return DropdownMenuItem(
                      value: a,
                      child: Text(a, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedCityOrArea = val;
                        _cityController.text = val;
                      });
                    }
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
            key: ValueKey('trade_$_selectedTrade'),
            initialValue: _selectedTrade,
            isExpanded: true,
            hint: const Text('Select Worker Category / Trade *', style: TextStyle(fontSize: 13, color: AppColors.outline)),
            decoration: InputDecoration(
              labelText: '10. Worker Category / Trade *',
              prefixIcon: const Icon(Icons.category_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            validator: (val) => val == null || val.isEmpty ? 'Please select a worker category.' : null,
            items: _tradeCategories.map((trade) {
              return DropdownMenuItem(value: trade, child: Text(trade));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedTrade = val;
                  _selectedSkill = null; // Do NOT autofill skill! Worker must select specific sub-skill!
                });
              }
            },
          ),
          const SizedBox(height: 14),
          () {
            final List<String> currentSubSkills = _selectedTrade != null ? (tradeSubSkills[_selectedTrade] ?? []) : [];
            final bool hasCategory = _selectedTrade != null && _selectedTrade!.isNotEmpty;

            return DropdownButtonFormField<String>(
              key: ValueKey('skill_${_selectedTrade}_$_selectedSkill'),
              initialValue: (currentSubSkills.contains(_selectedSkill)) ? _selectedSkill : null,
              isExpanded: true,
              hint: Text(
                !hasCategory
                    ? 'Select Worker Category first'
                    : 'Select Specific Sub-Skill *',
                style: const TextStyle(fontSize: 13, color: AppColors.outline),
              ),
              decoration: InputDecoration(
                labelText: '11. Primary Sub-Skill *',
                prefixIcon: const Icon(Icons.construction, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: !hasCategory ? const Color(0xFFF3F4F6) : AppColors.surfaceContainerLowest,
              ),
              validator: (val) {
                if (!hasCategory) return 'Please select a worker category first.';
                if (val == null || val.isEmpty) return 'Please select your specific sub-skill.';
                return null;
              },
              items: currentSubSkills.map((skill) {
                return DropdownMenuItem(
                  value: skill,
                  child: Text(skill, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: !hasCategory
                  ? null
                  : (val) {
                      if (val != null) setState(() => _selectedSkill = val);
                    },
            );
          }(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _skillLevels.contains(_selectedSkillLevel) ? _selectedSkillLevel : 'Intermediate',
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
                  initialValue: _experienceOptions.contains(_selectedExperienceYears) ? _selectedExperienceYears : 3,
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
            initialValue: _serviceAreasList.contains(_selectedArea) ? _selectedArea : _serviceAreasList.first,
            decoration: InputDecoration(
              labelText: '14. Service Area / Preferred Working Locality *',
              prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            items: _serviceAreasList.map((area) {
              return DropdownMenuItem(value: area, child: Text(area));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _selectedArea = val;
                });
                _autoRouteFederation(val);
              }
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
            activeThumbColor: AppColors.primary,
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
          DropdownButtonFormField<String>(
            key: ValueKey('fed_select_$_selectedFederationId'),
            initialValue: _selectedFederationId,
            isExpanded: true,
            hint: const Text('Select your Cooperative Federation', style: TextStyle(fontSize: 13, color: AppColors.outline)),
            decoration: InputDecoration(
              labelText: '18. Registered Federation / Cooperative *',
              prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: AppColors.surfaceContainerLowest,
            ),
            validator: (val) {
              final isCovered = FederationModel.isAreaCoveredByFederation(
                district: _districtController.text.trim(),
                city: _cityController.text.trim(),
                state: _selectedState,
                pincode: _pinCodeController.text.trim(),
                location: _selectedArea,
                federationsList: _availableFederations,
              );
              if (isCovered && (val == null || val.isEmpty)) {
                return 'Select a cooperative federation.';
              }
              return null;
            },
            items: [
              ..._availableFederations.map((fed) {
                return DropdownMenuItem<String>(
                  value: fed.id,
                  child: Text(
                    '${fed.name} (${fed.city.isNotEmpty ? fed.city : fed.district})',
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }),
            ],
            onChanged: (val) {
              if (val != null) {
                final fed = _availableFederations.firstWhere(
                  (f) => f.id == val,
                  orElse: () => FederationModel.defaultFederations.first,
                );
                setState(() {
                  _userSelectedFederationManually = true;
                  _selectedFederationId = val;
                  _federationName = fed.name;
                  _selectedDistrict = fed.district;
                  _districtController.text = fed.district;
                  _selectedCityOrArea = fed.city;
                  _cityController.text = fed.city;
                });
              }
            },
          ),
          if (_selectedFederationId == null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFFB300)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFFE65100), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'No Federation in $_selectedDistrict yet. Your application will be registered in the State Founding Artisan Waitlist and verified upon district expansion.',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF795548), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
