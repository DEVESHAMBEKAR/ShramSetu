import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/repositories/i_storage_repository.dart';
import '../../../../core/services/india_geography_service.dart';
import '../../../../core/models/federation_models.dart';
import '../../../../shared/widgets/map_location_picker_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/phone_number_util.dart';
import '../../data/models/customer_profile.dart';
import '../../../../core/services/firebase_phone_auth_service.dart';

class CustomerProfileOnboardingScreen extends StatefulWidget {
  const CustomerProfileOnboardingScreen({super.key});

  @override
  State<CustomerProfileOnboardingScreen> createState() =>
      _CustomerProfileOnboardingScreenState();
}

class _CustomerProfileOnboardingScreenState
    extends State<CustomerProfileOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  // Text controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressLineController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();

  // Geographic dropdown state
  String _selectedState = 'Maharashtra';
  String _selectedDistrict = 'Pune';
  String _selectedArea = 'Kothrud';
  List<String> _availableDistricts = [];
  List<String> _availableAreas = [];
  bool _isResolvingPincode = false;
  String? _pincodeFeedback;

  // Location state
  double? _latitude;
  double? _longitude;
  bool _isDetectingLocation = false;

  // Assigned Federation state
  List<FederationModel> _availableFederations = List.from(FederationModel.defaultFederations);
  FederationModel? _assignedFederation;

  // State
  Uint8List? _selectedImageBytes;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _availableDistricts = IndiaGeographyService.getDistricts(_selectedState);
    _availableAreas = IndiaGeographyService.getAreasForDistrict(_selectedState, _selectedDistrict);
    _stateController.text = _selectedState;
    _cityController.text = _selectedDistrict;
    _areaController.text = _selectedArea;
    _assignedFederation = FederationModel.findFederationForLocation(
      district: _selectedDistrict,
      city: _selectedDistrict,
      state: _selectedState,
      location: _selectedArea,
      federationsList: _availableFederations,
    );
    _loadFederations();
    _loadExistingProfile();
  }

  Future<void> _loadFederations() async {
    try {
      final feds = await FederationModel.fetchAllFederations();
      if (mounted && feds.isNotEmpty) {
        setState(() {
          _availableFederations = feds;
          _updateAssignedFederation();
        });
      }
    } catch (_) {}
  }

  void _updateAssignedFederation() {
    final target = FederationModel.findFederationForLocation(
      district: _selectedDistrict,
      city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : _selectedDistrict,
      state: _selectedState,
      location: _selectedArea,
      pincode: _postalCodeController.text.trim(),
      federationsList: _availableFederations,
    );
    setState(() {
      _assignedFederation = target;
    });
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
          _stateController.text = res.state;
          _availableDistricts = IndiaGeographyService.getDistricts(res.state);
          _selectedDistrict = _availableDistricts.contains(res.district)
              ? res.district
              : (_availableDistricts.isNotEmpty ? _availableDistricts.first : res.district);
          _cityController.text = _selectedDistrict;

          final areas = res.areas.isNotEmpty
              ? res.areas
              : IndiaGeographyService.getAreasForDistrict(_selectedState, _selectedDistrict);
          _availableAreas = areas;
          _selectedArea = areas.isNotEmpty ? areas.first : res.city;
          _areaController.text = _selectedArea;
          _isResolvingPincode = false;
          _pincodeFeedback = 'Detected: $_selectedDistrict, $_selectedState (${res.isFromNetwork ? "Live Post Office" : "Postal Directory"})';
          _updateAssignedFederation();
        });
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

  Future<void> _loadExistingProfile() async {
    try {
      final user = await DI.authRepo.getCurrentUser().timeout(const Duration(seconds: 3));

      // 1. Immediately pre-fill phone number from active user
      final rawPhone = user?.phone ?? FirebasePhoneAuthService.instance.activePhoneNumber ?? '';
      final cleanedPhone = PhoneNumberUtil.cleanIndianPhone(rawPhone);
      if (mounted && cleanedPhone.isNotEmpty && _phoneController.text.isEmpty) {
        setState(() {
          _phoneController.text = cleanedPhone;
        });
      }

      // 2. Pre-fill name or email from active auth user metadata if available
      final metaName = (user?.userMetadata?['full_name'] ?? user?.userMetadata?['name'] ?? user?.userMetadata?['displayName'])?.toString().trim();
      if (mounted && metaName != null && metaName.isNotEmpty && _nameController.text.isEmpty && !metaName.toLowerCase().startsWith('user ')) {
        setState(() {
          _nameController.text = metaName;
        });
      }

      // 3. Resolve profile from user repository (first by ID, then by phone)
      final userId = user?.id ?? (AppConfig.useMockData ? 'mock_customer_01' : null);
      CustomerProfile? profile;
      if (userId != null) {
        profile = await DI.userRepo.getCustomerProfile(userId).timeout(const Duration(seconds: 3));
      }
      if (profile == null && cleanedPhone.isNotEmpty) {
        profile = await DI.userRepo.getCustomerProfileByPhone(cleanedPhone).timeout(const Duration(seconds: 3));
      }

      final resolvedProfile = profile;
      if (resolvedProfile != null && resolvedProfile.isComplete && mounted) {
        Navigator.of(context).pushReplacementNamed('/customer/home');
        return;
      }
      if (resolvedProfile != null && mounted) {
        setState(() {
          if (resolvedProfile.fullName.isNotEmpty && _nameController.text.isEmpty) {
            final cleanName = resolvedProfile.fullName.trim();
            final isPhone = RegExp(r'^\+?\d{10,13}$').hasMatch(cleanName);
            if (!cleanName.toLowerCase().startsWith('user ') &&
                !isPhone &&
                cleanName.toLowerCase() != 'ananya' &&
                cleanName.toLowerCase() != 'demo user' &&
                cleanName.toLowerCase() != 'test user') {
              _nameController.text = cleanName;
            }
          }
          final pPhone = PhoneNumberUtil.cleanIndianPhone(resolvedProfile.phone);
          if (pPhone.isNotEmpty) {
            _phoneController.text = pPhone;
          }
          if (_emailController.text.isEmpty && resolvedProfile.email != null && resolvedProfile.email!.isNotEmpty) {
            _emailController.text = resolvedProfile.email!;
          }
          final addr = resolvedProfile.defaultAddress;
          if (addr != null) {
            if (_addressLineController.text.isEmpty && addr.addressLine.isNotEmpty) {
              _addressLineController.text = addr.addressLine;
            }
            if (addr.state.isNotEmpty) {
              final matched = IndiaGeographyService.matchState(addr.state) ?? addr.state;
              _selectedState = matched;
              _stateController.text = matched;
              _availableDistricts = IndiaGeographyService.getDistricts(matched);
            }
            if (addr.city.isNotEmpty) {
              final matchedDist = IndiaGeographyService.matchDistrict(_selectedState, addr.city);
              _selectedDistrict = matchedDist;
              _cityController.text = matchedDist;
              _availableAreas = IndiaGeographyService.getAreasForDistrict(_selectedState, _selectedDistrict);
            }
            if (addr.area.isNotEmpty) {
              _selectedArea = addr.area;
              _areaController.text = addr.area;
            }
            if (_postalCodeController.text.isEmpty && addr.postalCode.isNotEmpty) {
              _postalCodeController.text = addr.postalCode;
            }
            if (_latitude == null && addr.latitude != null) {
              _latitude = addr.latitude;
            }
            if (_longitude == null && addr.longitude != null) {
              _longitude = addr.longitude;
            }
          }
          _updateAssignedFederation();
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressLineController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    super.dispose();
  }

  // ─────────────────────── Image Picker ───────────────────────

  Future<void> _pickImage() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked != null && mounted) {
        final bytes = await picked.readAsBytes();
        setState(() => _selectedImageBytes = bytes);
      }
    } catch (_) {
      // Image pick is optional — silently ignore errors
    }
  }

  // ─────────────────────── Location Detection & Picker ───────────────────────

  Future<void> _fetchCurrentLocation() async {
    setState(() => _isDetectingLocation = true);
    try {
      final result = await DI.locationService.getCurrentPosition().timeout(const Duration(seconds: 6));
      if (!mounted) return;

      if (result.isSuccess && result.coordinates != null) {
        final coords = result.coordinates!;
        setState(() {
          _latitude = coords.latitude;
          _longitude = coords.longitude;
        });

        final address = await DI.locationService.reverseGeocode(
          coords.latitude,
          coords.longitude,
        ).timeout(const Duration(seconds: 4));

        if (mounted && address != null) {
          setState(() {
            if (address.addressLine.isNotEmpty) {
              _addressLineController.text = address.addressLine;
            }
            if (address.area.isNotEmpty) {
              _areaController.text = address.area;
            }
            if (address.city.isNotEmpty) {
              _cityController.text = address.city;
            }
            if (address.state.isNotEmpty) {
              _stateController.text = address.state;
            }
            if (address.postalCode.isNotEmpty) {
              _postalCodeController.text = address.postalCode;
            }
            _updateAssignedFederation();
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('GPS location detected. Please review and confirm your address.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } else {
        final msg = result.errorMessage ?? 'Could not detect location. You can enter it manually.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error detecting location: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.of(context).push<LocationPickerResult>(
      MaterialPageRoute(
        builder: (_) => MapLocationPickerScreen(
          initialLatitude: _latitude,
          initialLongitude: _longitude,
          title: 'Pick Home Address',
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });

      final addr = result.address;
      if (addr != null) {
        setState(() {
          if (addr.addressLine.isNotEmpty) _addressLineController.text = addr.addressLine;
          if (addr.area.isNotEmpty) _areaController.text = addr.area;
          if (addr.city.isNotEmpty) _cityController.text = addr.city;
          if (addr.state.isNotEmpty) _stateController.text = addr.state;
          if (addr.postalCode.isNotEmpty) _postalCodeController.text = addr.postalCode;
          _updateAssignedFederation();
        });
      }
    }
  }

  // ─────────────────────── Save ───────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      String? userId;
      try {
        final user = await DI.authRepo.getCurrentUser().timeout(const Duration(seconds: 3));
        userId = user?.id;
      } catch (_) {
        userId = null;
      }
      if (userId == null || userId.isEmpty) {
        try {
          userId = Supabase.instance.client.auth.currentUser?.id;
        } catch (_) {}
      }

      if (userId == null && AppConfig.useMockData) {
        userId = 'mock_customer_01';
      }

      if (userId == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Session expired. Please log in again.';
            _isSaving = false;
          });
        }
        return;
      }

      String? avatarUrl;

      // Step 1 (optional): Upload profile image if selected
      if (_selectedImageBytes != null) {
        try {
          avatarUrl = await DI.storageRepo.uploadFile(
            bucket: StorageBucket.profileImages,
            path: '$userId/avatar.jpg',
            fileBytes: _selectedImageBytes!,
            mimeType: 'image/jpeg',
          ).timeout(const Duration(seconds: 4));
        } catch (_) {
          // Image upload is optional — proceed without it
          avatarUrl = null;
        }
      }

      // Step 2: Save profile name (+ avatar if uploaded + assigned federation)
      try {
        final cleanPhone = PhoneNumberUtil.cleanIndianPhone(_phoneController.text.trim());
        await DI.userRepo.updateCustomerProfile(
          userId: userId,
          fullName: _nameController.text.trim(),
          phone: cleanPhone.isNotEmpty ? cleanPhone : _phoneController.text.trim(),
          email: _emailController.text.trim(),
          avatarUrl: avatarUrl,
          federationId: _assignedFederation?.id,
        ).timeout(const Duration(seconds: 12));
      } catch (e) {
        debugPrint('[CustomerOnboarding] updateCustomerProfile warning: $e');
        if (!AppConfig.useMockData) {
          if (mounted) {
            setState(() {
              _errorMessage = 'Could not save your profile. Please check your connection and try again.';
              _isSaving = false;
            });
          }
          return;
        }
      }

      // Step 3: Save address with coordinates & assigned federation
      try {
        await DI.userRepo.createAddress(
          userId: userId,
          addressLine: _addressLineController.text.trim(),
          area: _selectedArea,
          city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : _selectedDistrict,
          state: _selectedState,
          postalCode: _postalCodeController.text.trim(),
          district: _selectedDistrict,
          federationId: _assignedFederation?.id,
          label: 'Home',
          latitude: _latitude,
          longitude: _longitude,
        ).timeout(const Duration(seconds: 12));
      } catch (e) {
        debugPrint('[CustomerOnboarding] createAddress warning: $e');
        // Non-blocking: Profile name and location selections are already captured in state and Step 2.
        // Proceed cleanly to Step 4 so the citizen is never trapped on onboarding.
      }

      if (!mounted) return;

      // Profile and address successfully saved — navigate customer directly to their dashboard
      Navigator.of(context).pushReplacementNamed('/customer/home');
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _isSaving = false;
        });
      }
    } finally {
      if (mounted && _isSaving) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ─────────────────────── Validation ───────────────────────

  String? _validateName(String? val) {
    if (val == null || val.trim().isEmpty) return 'Full name is required';
    final clean = val.trim();
    if (clean.length < 2) return 'Please enter your full name';
    if (clean.length > 80) return 'Name is too long';
    if (RegExp(r'^\+?\d{10,13}$').hasMatch(clean)) {
      return 'Please enter your actual name, not your phone number';
    }
    // Reject obviously invalid placeholder names
    final lower = clean.toLowerCase();
    if (lower == 'ananya' || lower == 'demo user' || lower == 'test user') {
      return 'Please enter your real name';
    }
    return null;
  }

  String? _validatePhone(String? val) {
    return PhoneNumberUtil.validateIndianMobile(val);
  }

  String? _validateEmail(String? val) {
    if (val == null || val.trim().isEmpty) return 'Email address is required';
    if (!RegExp(r'^[\w\.-]+@[\w-]+\.\w{2,}$').hasMatch(val.trim())) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validateRequired(String? val, String fieldName) {
    if (val == null || val.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  String? _validatePostalCode(String? val) {
    if (val == null || val.trim().isEmpty) return 'Postal code is required';
    if (!RegExp(r'^\d{6}$').hasMatch(val.trim())) {
      return 'Please enter a valid 6-digit postal code';
    }
    return null;
  }

  // ─────────────────────── Build ───────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset('assets/images/logo.jpg',
                height: 28, width: 28, fit: BoxFit.contain),
            const SizedBox(width: AppSpacing.spacingXs),
            Text(
              'ShramSetu',
              style: AppTypography.titleLg.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.spacingMd),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.spacingXs, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: AppRadius.radiusFull,
              ),
              child: Text(
                'NEW MEMBER',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.marginMobile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const SizedBox(height: AppSpacing.spacingSm),
                Text(
                  'Complete Your Profile',
                  style: AppTypography.headlineMd.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacing3xs),
                Text(
                  'Just a few details so we can connect you with verified workers in your area.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingLg),

                // Profile Image (optional)
                _buildAvatarPicker(),
                const SizedBox(height: AppSpacing.spacingLg),

                // Section: Identity & Credentials
                _buildSectionLabel('YOUR IDENTITY & CREDENTIALS'),
                const SizedBox(height: AppSpacing.spacingSm),
                _buildCard(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name *',
                      hint: 'e.g. Rajesh Patil',
                      icon: Icons.person_outline,
                      validator: _validateName,
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.spacingMd),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'Mobile Number *',
                      hint: 'e.g. 9876543210',
                      icon: Icons.phone_android_outlined,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [IndianPhoneNumberFormatter()],
                      validator: _validatePhone,
                    ),
                    const SizedBox(height: AppSpacing.spacingMd),
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address *',
                      hint: 'e.g. rajesh.patil@example.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingLg),

                // Section: Address
                _buildSectionLabel('YOUR PRIMARY ADDRESS'),
                const SizedBox(height: AppSpacing.spacing3xs),
                Text(
                  'Your address helps us show you workers nearby.',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.spacingSm),

                // Location Action Row: GPS & Map Picker
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.outlineVariant),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        ),
                        onPressed: _isDetectingLocation ? null : _fetchCurrentLocation,
                        icon: _isDetectingLocation
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                              )
                            : const Icon(Icons.my_location, size: 16, color: AppColors.secondary),
                        label: Text(
                          _isDetectingLocation ? 'Detecting...' : 'Use Current GPS',
                          style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.outlineVariant),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        ),
                        onPressed: _pickOnMap,
                        icon: const Icon(Icons.map_outlined, size: 16, color: AppColors.primary),
                        label: Text(
                          'Pick on Map',
                          style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_latitude != null && _longitude != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: AppColors.onTertiaryContainer),
                      const SizedBox(width: 4),
                      Text(
                        'Coordinates locked (${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)})',
                        style: AppTypography.labelSm.copyWith(
                          fontSize: 10,
                          color: AppColors.onTertiaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.spacingSm),

                _buildCard(
                  children: [
                    _buildTextField(
                      controller: _addressLineController,
                      label: 'House / Flat / Street Address *',
                      hint: 'e.g. 45 MG Road, Shivajinagar',
                      icon: Icons.home_outlined,
                      validator: (v) => _validateRequired(v, 'Address line'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: AppSpacing.spacingMd),

                    // PIN Code with auto-detect and State Dropdown
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PIN Code
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _postalCodeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            enabled: !_isSaving,
                            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Postal PIN *',
                              hintText: '411001',
                              counterText: '',
                              prefixIcon: const Icon(Icons.markunread_mailbox_outlined, size: 20, color: AppColors.onSurfaceVariant),
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
                              filled: true,
                              fillColor: AppColors.surfaceContainerLow,
                              border: OutlineInputBorder(borderRadius: AppRadius.radiusLg, borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: AppRadius.radiusLg,
                                borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: AppRadius.radiusLg,
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
                            ),
                            onChanged: _handlePincodeAutoDetect,
                            validator: _validatePostalCode,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.spacingSm),

                        // State Dropdown (All 36 Indian States & UTs)
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: IndiaGeographyService.states.contains(_selectedState)
                                ? _selectedState
                                : IndiaGeographyService.states.first,
                            isExpanded: true,
                            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
                            decoration: InputDecoration(
                              labelText: 'State *',
                              prefixIcon: const Icon(Icons.public, size: 20, color: AppColors.onSurfaceVariant),
                              filled: true,
                              fillColor: AppColors.surfaceContainerLow,
                              border: OutlineInputBorder(borderRadius: AppRadius.radiusLg, borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: AppRadius.radiusLg,
                                borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: AppRadius.radiusLg,
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
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
                                  _stateController.text = val;
                                  _availableDistricts = IndiaGeographyService.getDistricts(val);
                                  _selectedDistrict = _availableDistricts.isNotEmpty ? _availableDistricts.first : 'Pune';
                                  _cityController.text = _selectedDistrict;
                                  _availableAreas = IndiaGeographyService.getAreasForDistrict(val, _selectedDistrict);
                                  _selectedArea = _availableAreas.isNotEmpty ? _availableAreas.first : _selectedDistrict;
                                  _areaController.text = _selectedArea;
                                  _updateAssignedFederation();
                                });
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

                    const SizedBox(height: AppSpacing.spacingMd),

                    // District & Area Dropdowns
                    Row(
                      children: [
                        // District Dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('cust_dist_${_selectedState}_$_selectedDistrict'),
                            initialValue: _availableDistricts.contains(_selectedDistrict)
                                ? _selectedDistrict
                                : (_availableDistricts.isNotEmpty ? _availableDistricts.first : null),
                            isExpanded: true,
                            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
                            decoration: InputDecoration(
                              labelText: 'District *',
                              prefixIcon: const Icon(Icons.apartment_outlined, size: 20, color: AppColors.onSurfaceVariant),
                              filled: true,
                              fillColor: AppColors.surfaceContainerLow,
                              border: OutlineInputBorder(borderRadius: AppRadius.radiusLg, borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: AppRadius.radiusLg,
                                borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: AppRadius.radiusLg,
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
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
                                  _cityController.text = val;
                                  _availableAreas = IndiaGeographyService.getAreasForDistrict(_selectedState, val);
                                  _selectedArea = _availableAreas.isNotEmpty ? _availableAreas.first : val;
                                  _areaController.text = _selectedArea;
                                  _updateAssignedFederation();
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.spacingSm),

                        // Area / Locality Dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('cust_area_${_selectedDistrict}_$_selectedArea'),
                            initialValue: _availableAreas.contains(_selectedArea)
                                ? _selectedArea
                                : (_availableAreas.isNotEmpty ? _availableAreas.first : null),
                            isExpanded: true,
                            style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
                            decoration: InputDecoration(
                              labelText: 'Area / Locality *',
                              prefixIcon: const Icon(Icons.location_city_outlined, size: 20, color: AppColors.onSurfaceVariant),
                              filled: true,
                              fillColor: AppColors.surfaceContainerLow,
                              border: OutlineInputBorder(borderRadius: AppRadius.radiusLg, borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: AppRadius.radiusLg,
                                borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: AppRadius.radiusLg,
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                              ),
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
                                  _selectedArea = val;
                                  _areaController.text = val;
                                  _updateAssignedFederation();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingLg),

                // Section: Federation Jurisdiction
                _buildSectionLabel('ASSIGNED COOPERATIVE FEDERATION'),
                const SizedBox(height: AppSpacing.spacing3xs),
                Text(
                  'Auto-assigned based on your delivery address jurisdiction.',
                  style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                _buildAssignedFederationCard(),
                const SizedBox(height: AppSpacing.spacingXl),

                // Error message
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.spacingMd),
                    margin:
                        const EdgeInsets.only(bottom: AppSpacing.spacingMd),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: AppRadius.radiusLg,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.onErrorContainer, size: 18),
                        const SizedBox(width: AppSpacing.spacingXs),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppTypography.bodyMd
                                .copyWith(color: AppColors.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.5),
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppRadius.radiusLg),
                      elevation: 2,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: AppColors.onPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            _assignedFederation != null
                                ? 'Save & Continue'
                                : 'Complete Registration & Join Waitlist',
                            style: AppTypography.titleMd.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingSm),

                // Info note
                Center(
                  child: Text(
                    'You can update these details anytime from your profile.',
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingXl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────── Widgets ───────────────────────

  Widget _buildAvatarPicker() {
    return Center(
      child: GestureDetector(
        onTap: _isSaving ? null : _pickImage,
        child: Stack(
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer,
                image: _selectedImageBytes != null
                    ? DecorationImage(
                        image: MemoryImage(_selectedImageBytes!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _selectedImageBytes == null
                  ? const Icon(Icons.person,
                      size: 48, color: AppColors.onPrimaryContainer)
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt,
                    size: 16, color: AppColors.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: AppTypography.labelSm.copyWith(
        color: AppColors.onSurfaceVariant,
        letterSpacing: 1.2,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.radiusXl,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      enabled: !_isSaving,
      style: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon:
            Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
        labelStyle: AppTypography.bodyMd
            .copyWith(color: AppColors.onSurfaceVariant),
        hintStyle: AppTypography.bodyMd
            .copyWith(color: AppColors.outline),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide: const BorderSide(
              color: AppColors.outlineVariant, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide:
              const BorderSide(color: AppColors.error, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.radiusLg,
          borderSide:
              const BorderSide(color: AppColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.spacingMd,
            vertical: AppSpacing.spacingMd),
      ),
    );
  }

  Widget _buildAssignedFederationCard() {
    if (_assignedFederation == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: const Color(0xFFFFB300), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFE65100), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Not Serviceable Yet',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFFB74D)),
                        ),
                        child: const Text(
                          'Expansion Waitlist',
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFE65100)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'No active cooperative union in $_selectedDistrict. Complete registration to join the priority expansion waitlist.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.onSurface, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final fed = _assignedFederation!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: AppRadius.radiusMd,
                ),
                child: const Icon(
                  Icons.account_balance,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'ASSIGNED COOPERATIVE FEDERATION',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F5E9),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF81C784)),
                          ),
                          child: const Text(
                            'Auto-Assigned',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      fed.name,
                      style: AppTypography.titleMd.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          const Divider(height: 1, color: AppColors.outlineVariant),
          const SizedBox(height: AppSpacing.spacingSm),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 14, color: AppColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'Jurisdiction: ${fed.district}, ${fed.state}',
                style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
              ),
              if (fed.registrationNo != null) ...[
                const Spacer(),
                Text(
                  fed.registrationNo!,
                  style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 10),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'All artisan bookings from your address are guaranteed and regulated by this union.',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

