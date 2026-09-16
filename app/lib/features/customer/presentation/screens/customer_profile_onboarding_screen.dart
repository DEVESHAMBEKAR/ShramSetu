import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/repositories/i_storage_repository.dart';
import '../../../../shared/widgets/map_location_picker_screen.dart';

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
  final _addressLineController = TextEditingController();
  final _areaController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();

  // Location state
  double? _latitude;
  double? _longitude;
  bool _isDetectingLocation = false;

  // State
  Uint8List? _selectedImageBytes;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
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
      final result = await DI.locationService.getCurrentPosition();
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
        );

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

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() {
        _errorMessage = 'Session expired. Please log in again.';
        _isSaving = false;
      });
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
        );
      } catch (_) {
        // Image upload is optional — proceed without it
        avatarUrl = null;
      }
    }

    // Step 2: Save profile name (+ avatar if uploaded)
    try {
      await DI.userRepo.updateCustomerProfile(
        userId: userId,
        fullName: _nameController.text.trim(),
        avatarUrl: avatarUrl,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not save your profile. Please try again.';
        _isSaving = false;
      });
      return;
    }

    // Step 3: Save address with coordinates
    try {
      await DI.userRepo.createAddress(
        userId: userId,
        addressLine: _addressLineController.text.trim(),
        area: _areaController.text.trim(),
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        postalCode: _postalCodeController.text.trim(),
        label: 'Home',
        latitude: _latitude,
        longitude: _longitude,
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not save your address. Please try again.';
        _isSaving = false;
      });
      return;
    }

    // All done — navigate to home
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/customer/home');
    }
  }

  // ─────────────────────── Validation ───────────────────────

  String? _validateName(String? val) {
    if (val == null || val.trim().isEmpty) return 'Full name is required';
    if (val.trim().length < 2) return 'Please enter your full name';
    if (val.trim().length > 80) return 'Name is too long';
    // Reject obviously invalid placeholder names
    final lower = val.trim().toLowerCase();
    if (lower == 'ananya' || lower == 'demo user' || lower == 'test user') {
      return 'Please enter your real name';
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

                // Section: Identity
                _buildSectionLabel('YOUR IDENTITY'),
                const SizedBox(height: AppSpacing.spacingSm),
                _buildCard(
                  children: [
                    _buildTextField(
                      controller: _nameController,
                      label: 'Full Name',
                      hint: 'e.g. Rajesh Patil',
                      icon: Icons.person_outline,
                      validator: _validateName,
                      textCapitalization: TextCapitalization.words,
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
                      label: 'Address Line',
                      hint: 'e.g. 45 MG Road, Shivajinagar',
                      icon: Icons.home_outlined,
                      validator: (v) => _validateRequired(v, 'Address line'),
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: AppSpacing.spacingMd),
                    _buildTextField(
                      controller: _areaController,
                      label: 'Area / Locality',
                      hint: 'e.g. Shivajinagar (optional)',
                      icon: Icons.location_city_outlined,
                      validator: null, // optional
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.spacingMd),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _cityController,
                            label: 'City',
                            hint: 'e.g. Pune',
                            icon: Icons.location_on_outlined,
                            validator: (v) => _validateRequired(v, 'City'),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.spacingSm),
                        Expanded(
                          child: _buildTextField(
                            controller: _stateController,
                            label: 'State',
                            hint: 'e.g. Maharashtra',
                            icon: Icons.map_outlined,
                            validator: (v) => _validateRequired(v, 'State'),
                            textCapitalization: TextCapitalization.words,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.spacingMd),
                    _buildTextField(
                      controller: _postalCodeController,
                      label: 'Postal Code (PIN)',
                      hint: 'e.g. 411001',
                      icon: Icons.markunread_mailbox_outlined,
                      validator: _validatePostalCode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                    ),
                  ],
                ),
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
                            'Save & Continue',
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
}
