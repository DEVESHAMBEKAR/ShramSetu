import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../shared/widgets/map_location_picker_screen.dart';
import '../../data/models/customer_models.dart';
import '../../data/models/customer_profile.dart';
import 'worker_discovery_screen.dart';
import 'worker_profile_screen.dart';
import 'customer_live_tracking_screen.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/models/booking_status.dart';
import '../../../../shared/widgets/booking_status_badge.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../shared/widgets/shramsetu_brand_mark.dart';
import '../../../booking/data/models/booking_models.dart' hide BookingStatus;
import '../../../booking/presentation/screens/booking_date_time_screen.dart';
import '../../../../core/services/firebase_phone_auth_service.dart';

class CustomerHomeScreen extends StatefulWidget {
  final void Function(int tabIndex)? onSelectTab;

  const CustomerHomeScreen({super.key, this.onSelectTab});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  CustomerProfile? _profile;
  Map<String, dynamic>? _activeBooking;
  List<ServiceCategory> _categories = [];
  List<Worker> _featuredWorkers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedArea = 'All Areas';
  String _activeQuickFilter = 'all';
  String _selectedTradeFilter = 'all';

  List<String> _serviceAreas = [
    'All Areas',
    'Vadgaon Budruk',
    'Kothrud',
    'Baner & Balewadi',
    'Hinjewadi',
    'Shivajinagar',
    'Hadapsar',
    'Viman Nagar',
    'Wakad',
    'Aundh',
    'Katraj',
    'Swargate',
    'Kharadi',
    'Pimpri-Chinchwad',
  ];

  static const Map<String, (double, double)> _regionCoordinates = {
    'Vadgaon Budruk': (18.4682, 73.8368),
    'Kothrud': (18.5074, 73.8077),
    'Baner & Balewadi': (18.5590, 73.7868),
    'Hinjewadi': (18.5913, 73.7389),
    'Shivajinagar': (18.5314, 73.8446),
    'Hadapsar': (18.5089, 73.9259),
    'Viman Nagar': (18.5679, 73.9143),
    'Wakad': (18.5987, 73.7656),
    'Aundh': (18.5580, 73.8075),
    'Katraj': (18.4575, 73.8677),
    'Swargate': (18.5018, 73.8586),
    'Kharadi': (18.5516, 73.9349),
    'Pimpri-Chinchwad': (18.6298, 73.7997),
    'CIDCO, Nashik': (19.9703, 73.7533),
    'Panchavati, Nashik': (20.0110, 73.7925),
    'College Road, Nashik': (19.9975, 73.7667),
    'Satpur, Nashik': (19.9867, 73.7333),
    'Nashik Road': (19.9547, 73.8344),
    'Andheri, Mumbai': (19.1136, 72.8697),
    'Bandra, Mumbai': (19.0596, 72.8295),
    'Dadar, Mumbai': (19.0178, 72.8478),
    'Thane, MMR': (19.2183, 72.9781),
    'Navi Mumbai': (19.0330, 73.0297),
    'CIDCO, Sambhajinagar': (19.8762, 75.3433),
    'Dharampeth, Nagpur': (21.1458, 79.0667),
    'Sitabuldi, Nagpur': (21.1466, 79.0831),
  };

  void _syncServiceAreas() {
    final set = <String>{
      'All Areas',
      'Vadgaon Budruk',
      'Kothrud',
      'Baner & Balewadi',
      'Hinjewadi',
      'Shivajinagar',
      'Hadapsar',
      'Viman Nagar',
      'Wakad',
      'Katraj',
      'Swargate',
    };
    final custArea = _profile?.defaultAddress?.area;
    if (custArea != null && custArea.trim().isNotEmpty) {
      set.add(custArea.trim());
    }
    final custCity = _profile?.defaultAddress?.city;
    if (custCity != null && custCity.trim().isNotEmpty) {
      set.add(custCity.trim());
    }
    for (final w in _featuredWorkers) {
      if (w.locationTag.isNotEmpty && w.locationTag != 'General Service Area') {
        for (final p in w.locationTag.split(RegExp(r'[,•/|]'))) {
          final clean = p.trim();
          if (clean.isNotEmpty && clean.length > 2) {
            set.add(clean);
          }
        }
      }
      for (final a in w.serviceAreas) {
        final clean = a.trim();
        if (clean.isNotEmpty && clean != 'All Areas') {
          set.add(clean);
        }
      }
    }
    _serviceAreas = set.toList();
  }

  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<List<Map<String, dynamic>>>? _bookingsSub;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final user = await DI.authRepo.getCurrentUser();
    final userId = user?.id ?? (AppConfig.useMockData ? 'mock_customer_01' : null);

    if (userId != null) {
      try {
        var profile = await DI.userRepo.getCustomerProfile(userId);
        if (profile == null) {
          final phone = user?.phone ?? FirebasePhoneAuthService.instance.activePhoneNumber;
          if (phone != null && phone.isNotEmpty) {
            profile = await DI.userRepo.getCustomerProfileByPhone(phone);
          }
        }
        if (profile == null || profile.fullName.trim().isEmpty || profile.fullName.startsWith('User ')) {
          final userData = await DI.userRepo.getUserProfile(userId);
          final dbName = userData?['full_name'] as String?;
          if (dbName != null && dbName.isNotEmpty && !dbName.startsWith('User ')) {
            profile = profile != null
                ? profile.copyWith(fullName: dbName)
                : CustomerProfile(id: userId, fullName: dbName, phone: (userData?['phone'] as String?) ?? user?.phone ?? '');
          } else {
            final metaName = (user?.userMetadata?['full_name'] ?? user?.userMetadata?['name']) as String?;
            if (metaName != null && metaName.trim().isNotEmpty && !metaName.startsWith('User ')) {
              profile = profile != null
                  ? profile.copyWith(fullName: metaName.trim())
                  : CustomerProfile(id: userId, fullName: metaName.trim(), phone: user?.phone ?? '');
            }
          }
        }
        if (mounted) {
          _profile = profile;
          debugPrint('[CustomerHome] Profile loaded: ${profile?.fullName ?? "null"}');
        }
      } catch (e) {
        debugPrint('[CustomerHome] ERROR loading profile: $e');
      }
    }

    try {
      final cats = await DI.customerRepo.getActiveServices();
      if (mounted) _categories = cats;
      debugPrint('[CustomerHome] Categories loaded: ${cats.length}');
      // Load all available registered union artisans across federations
      final allWorkers = await DI.customerRepo.getAllWorkers();
      debugPrint('[CustomerHome] All workers loaded: ${allWorkers.length}');
      if (mounted) {
        if (allWorkers.isNotEmpty) {
          _featuredWorkers = allWorkers;
        } else if (cats.isNotEmpty) {
          final workers = await DI.customerRepo.getEligibleWorkers(cats.first.id);
          _featuredWorkers = workers;
        }
        _syncServiceAreas();
        final defaultArea = _profile?.defaultAddress?.area;
        if (defaultArea != null && defaultArea.isNotEmpty && _selectedArea == 'All Areas') {
          for (final a in _serviceAreas) {
            if (a != 'All Areas' && (a.toLowerCase().contains(defaultArea.toLowerCase()) || defaultArea.toLowerCase().contains(a.toLowerCase()))) {
              _selectedArea = a;
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[CustomerHome] ERROR loading services/workers: $e');
    }

    _bookingsSub?.cancel();
    _bookingsSub = DI.customerRepo.watchCustomerBookings().listen(
      (bookings) {
        if (mounted) {
          final activeList = bookings.where((b) {
            final s = (b['status']?.toString() ?? '').toLowerCase();
            return s != 'completed' && s != 'cancelled' && s != 'rejected';
          }).toList();
          setState(() {
            _activeBooking = activeList.isNotEmpty ? activeList.first : null;
          });
        }
      },
      onError: (_) {},
    );

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String get _locationDisplay {
    final addr = _profile?.defaultAddress;
    if (_selectedArea != 'All Areas') {
      final cityPart = (addr?.city.isNotEmpty == true) ? addr!.city : '';
      return cityPart.isNotEmpty && !_selectedArea.contains(cityPart)
          ? '$_selectedArea, $cityPart'
          : _selectedArea;
    }
    if (addr == null) return 'Select Service Location';
    final areaPart = addr.area.isNotEmpty ? addr.area : addr.city;
    if (addr.postalCode.isNotEmpty) {
      return '$areaPart, ${addr.city} • ${addr.postalCode}';
    }
    return '$areaPart, ${addr.city}';
  }


  void _navigateToCategory(ServiceCategory category, {String? searchQuery}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerDiscoveryScreen(
          initialCategory: category,
          initialSearchQuery: searchQuery,
          initialServiceArea: _selectedArea != 'All Areas' ? _selectedArea : null,
        ),
      ),
    );
  }

  void _navigateToEmergencyDiscovery() {
    final emergencyCategory = _categories.firstWhere(
      (c) => c.name.toLowerCase().contains('plumb') || c.name.toLowerCase().contains('elect'),
      orElse: () => _categories.isNotEmpty
          ? _categories.first
          : const ServiceCategory(id: 'c2', name: 'Plumbing', iconData: 'plumbing'),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerDiscoveryScreen(
          initialCategory: emergencyCategory,
          initialServiceArea: _selectedArea != 'All Areas' ? _selectedArea : null,
          isEmergency: true,
        ),
      ),
    );
  }

  void _navigateToWorkerProfile(Worker worker) {
    final matchedCat = _categories.firstWhere(
      (c) => c.id == worker.categoryId ||
             worker.specializations.any((s) => s.toLowerCase().contains(c.name.toLowerCase())),
      orElse: () => _categories.isNotEmpty
          ? _categories.first
          : const ServiceCategory(id: 'c2', name: 'Plumbing', iconData: 'plumbing'),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerProfileScreen(worker: worker, category: matchedCat),
      ),
    );
  }

  void _showNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.notifications_active, color: AppColors.secondary, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Union Alerts & Notifications',
                      style: AppTypography.titleMd.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryFixed,
                  borderRadius: AppRadius.radiusSm,
                ),
                child: const Icon(Icons.verified, color: AppColors.onSecondaryFixedVariant, size: 20),
              ),
              title: const Text('Cooperative Welfare Active', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('All service bookings include ₹50,000 damage cover and 0% commission pass-through.'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppRadius.radiusSm,
                ),
                child: const Icon(Icons.handyman, color: AppColors.primary, size: 20),
              ),
              title: const Text('Standard Rates Updated', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('District Labour Cooperative Federations published Q3 standardized fair rate cards.'),
            ),
            if (_activeBooking != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.tertiaryContainer,
                    borderRadius: AppRadius.radiusSm,
                  ),
                  child: const Icon(Icons.timelapse, color: AppColors.onTertiaryContainer, size: 20),
                ),
                title: const Text('Active Service Assigned', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Status: ${(_activeBooking!['status'] ?? 'pending').toString().toUpperCase()} • Tap to track'),
                onTap: () {
                  Navigator.pop(ctx);
                  final bId = _activeBooking!['id']?.toString() ?? '';
                  if (bId.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerLiveTrackingScreen(bookingId: bId),
                      ),
                    );
                  }
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _onProfileAvatarTap() {
    if (widget.onSelectTab != null) {
      widget.onSelectTab!(3);
    } else {
      _showProfileSheet();
    }
  }

  void _showProfileSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.surfaceContainerLow,
                  backgroundImage: (_profile?.avatarUrl != null && _profile!.avatarUrl!.isNotEmpty)
                      ? NetworkImage(_profile!.avatarUrl!)
                      : null,
                  child: (_profile?.avatarUrl == null || _profile!.avatarUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 24, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (_profile?.fullName.isNotEmpty == true && !_profile!.fullName.startsWith('User '))
                            ? _profile!.fullName
                            : (_profile?.phone.isNotEmpty == true ? 'Customer (${_profile!.phone})' : 'Customer'),
                        style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
                      ),
                      Text(
                        _profile?.phone.isNotEmpty == true ? _profile!.phone : _locationDisplay,
                        style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.location_on_outlined, color: AppColors.primary),
              title: const Text('Manage Delivery Address', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_locationDisplay),
              onTap: () {
                Navigator.pop(ctx);
                _showLocationPickerSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.translate, color: AppColors.secondary),
              title: const Text('Change Language', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('English / मराठी / हिंदी'),
              onTap: () {
                Navigator.pop(ctx);
                _showLanguageSwitcher();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: AppColors.error),
              title: const Text('Logout', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
              onTap: () async {
                Navigator.pop(ctx);
                await DI.authRepo.logout();
                if (mounted) Navigator.of(context).pushReplacementNamed('/onboarding');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showPromiseDetails(String title, String description) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 8),
            Text(description, style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Back to Home'),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showLanguageSwitcher() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Language / भाषा निवडा'.tr(), style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.spacingMd),
            ListTile(
              leading: Icon(
                LocaleController.instance.isEnglish ? Icons.check_circle : Icons.circle_outlined,
                color: LocaleController.instance.isEnglish ? AppColors.secondary : AppColors.outline,
              ),
              title: const Text('English', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Default interface'),
              onTap: () {
                LocaleController.instance.setLanguage('en');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                LocaleController.instance.isMarathi ? Icons.check_circle : Icons.circle_outlined,
                color: LocaleController.instance.isMarathi ? AppColors.secondary : AppColors.outline,
              ),
              title: const Text('मराठी (Marathi)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('स्थानिक भाषा'),
              onTap: () {
                LocaleController.instance.setLanguage('mr');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(
                LocaleController.instance.isHindi ? Icons.check_circle : Icons.circle_outlined,
                color: LocaleController.instance.isHindi ? AppColors.secondary : AppColors.outline,
              ),
              title: const Text('हिंदी (Hindi)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('राष्ट्रभाषा इंटरफेस'),
              onTap: () {
                LocaleController.instance.setLanguage('hi');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationPickerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final currentAddr = _profile?.defaultAddress;
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: AppRadius.radiusFull,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Service Location'.tr(), style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold)),
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
                              Text(
                                currentAddr?.displayString.isNotEmpty == true
                                    ? currentAddr!.displayString
                                    : _locationDisplay,
                                style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Select your service ward below to discover union artisans near you',
                                style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Select Service Area / Ward', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _serviceAreas.map((area) {
                      final isSelected = _selectedArea == area;
                      return ChoiceChip(
                        label: Text(area),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                        ),
                        avatar: Icon(
                          isSelected ? Icons.check_circle : Icons.location_on_outlined,
                          size: 14,
                          color: isSelected ? Colors.white : AppColors.outline,
                        ),
                        onSelected: (selected) async {
                          Navigator.pop(ctx);
                          final user = await DI.authRepo.getCurrentUser();
                          final userId = user?.id ?? _profile?.id ?? (AppConfig.useMockData ? 'mock_customer_01' : null);

                          setState(() {
                            _selectedArea = area;
                          });

                          if (userId != null && area != 'All Areas') {
                            final coords = _regionCoordinates[area] ??
                                (currentAddr != null && currentAddr.latitude != null && currentAddr.longitude != null
                                    ? (currentAddr.latitude!, currentAddr.longitude!)
                                    : const (18.5204, 73.8567));
                            final existingCity = currentAddr?.city.isNotEmpty == true ? currentAddr!.city : 'Customer City';
                            final existingState = currentAddr?.state.isNotEmpty == true ? currentAddr!.state : 'Maharashtra';
                            final existingZip = currentAddr?.postalCode.isNotEmpty == true ? currentAddr!.postalCode : '400001';
                            await DI.userRepo.createAddress(
                              userId: userId,
                              addressLine: '$area, $existingCity',
                              area: area,
                              city: existingCity,
                              state: existingState,
                              postalCode: existingZip,
                              latitude: coords.$1,
                              longitude: coords.$2,
                            );
                          }
                          await _loadAllData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Location updated to $area. Showing available union artisans.')),
                            );
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.my_location, color: AppColors.secondary),
                    title: const Text('Use Current GPS Location', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Detect coordinates and reverse geocode address'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final user = await DI.authRepo.getCurrentUser();
                      final userId = user?.id ?? _profile?.id ?? (AppConfig.useMockData ? 'mock_customer_01' : null);
                      if (userId == null) return;
                      
                      final result = await DI.locationService.getCurrentPosition().timeout(const Duration(seconds: 6));
                      if (result.isSuccess && result.coordinates != null) {
                        final coords = result.coordinates!;
                        final geo = await DI.locationService.reverseGeocode(coords.latitude, coords.longitude).timeout(const Duration(seconds: 4));
                        if (geo != null) {
                          await DI.userRepo.createAddress(
                            userId: userId,
                            addressLine: geo.addressLine.isNotEmpty ? geo.addressLine : 'Current Location',
                            area: geo.area,
                            city: geo.city,
                            state: geo.state,
                            postalCode: geo.postalCode,
                            latitude: coords.latitude,
                            longitude: coords.longitude,
                          );
                          if (geo.area.isNotEmpty) {
                            setState(() => _selectedArea = geo.area);
                          }
                          await _loadAllData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Service location updated successfully.')),
                            );
                          }
                        }
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.errorMessage ?? 'Unable to detect GPS location.')),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.map_outlined, color: AppColors.primary),
                    title: const Text('Pick on Google Map', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Pinpoint your exact location visually'),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final user = await DI.authRepo.getCurrentUser();
                      final userId = user?.id ?? _profile?.id ?? (AppConfig.useMockData ? 'mock_customer_01' : null);
                      if (userId == null || !mounted) return;

                      final currentAddr = _profile?.defaultAddress;
                      final mapRes = await Navigator.push<LocationPickerResult>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MapLocationPickerScreen(
                            initialLatitude: currentAddr?.latitude,
                            initialLongitude: currentAddr?.longitude,
                            title: 'Select Delivery Location',
                          ),
                        ),
                      );

                      if (mapRes != null) {
                        final geo = mapRes.address;
                        await DI.userRepo.createAddress(
                          userId: userId,
                          addressLine: geo?.addressLine.isNotEmpty == true ? geo!.addressLine : 'Selected Location',
                          area: geo?.area ?? '',
                          city: geo?.city.isNotEmpty == true ? geo!.city : 'Pune',
                          state: geo?.state.isNotEmpty == true ? geo!.state : 'Maharashtra',
                          postalCode: geo?.postalCode ?? '',
                          latitude: mapRes.latitude,
                          longitude: mapRes.longitude,
                        );
                        if (geo?.area.isNotEmpty == true) {
                          setState(() => _selectedArea = geo!.area);
                        }
                        await _loadAllData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Location updated on map.')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showHelplineDialer() {
    Clipboard.setData(const ClipboardData(text: '1800-266-9090'));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Toll-free Union Helpline: 1800-266-9090 copied!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadAllData,
              color: AppColors.secondary,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1150),
              child: CustomScrollView(
                slivers: [
                  // 1. Signature Urban Company App Bar
                  _buildSliverHeader(),

                  if (_isLoading)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: AppColors.secondary,
                      ),
                    ),

                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Top Sovereign DPI Trust Banner
                        _buildSovereignTrustBanner(),

                        // 2. Location & Cluster Sub-Bar
                        _buildLocationAndGreeting(),

                        // 3. Search Bar & Quick Civic Filter Pills
                        _buildSearchAndChips(),

                        // 4. Co-op Tariff Protection Callout
                        _buildCoopTariffGuaranteeCallout(),

                        // 5. In-Progress Booking Live Tracker
                        _buildActiveJobCard(),

                        // 5b. Emergency Urgent Service Dispatch
                        _buildEmergencyDispatchBanner(),

                        // 6. Popular Categories (Essential Trades Grid)
                        _buildCategoriesSection(),

                        // 7. Services Near You (Live Verified Guild Masters)
                        _buildArtisansNearYou(),

                        // 8. Civic Assurance & Citizen Ledger Card
                        _buildCivicAssuranceLedger(),

                        // 9. Union Promise 3-Column Grid
                        _buildUnionPromiseGrid(),

                        // 10. Cooperative Helpline Strip
                        _buildHelplineStrip(),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  },
);
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      titleSpacing: AppSpacing.marginMobile,
      toolbarHeight: 64,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(3),
        child: TricolorStripe(height: 3),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Official Brand Mark with English & Marathi typography
          Expanded(
            child: ShramSetuBrandMark(
              size: 32,
              showText: true,
              subtitle: _selectedArea != 'All Areas'
                  ? '$_selectedArea क्लस्टर • Civic Guild'
                  : 'महाराष्ट्र कामगार सहकारी मंच',
            ),
          ),

          // Action Controls: Translate Pill & Notification Bell & Profile Avatar
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _showLanguageSwitcher,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: AppRadius.radiusMd,
                    border: Border.all(color: AppColors.surfaceContainerHighest, width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.translate, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocaleController.instance.isMarathi
                                ? 'अ/A मराठी'
                                : (LocaleController.instance.isHindi ? 'अ/A हिंदी' : 'अ/A EN'),
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.primaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            'EN / हिंदी +20',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                              fontSize: 8,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.expand_more, size: 14, color: AppColors.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: _showNotificationsSheet,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      shape: BoxShape.circle,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Icon(Icons.notifications_none, size: 20, color: AppColors.onSurfaceVariant),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.secondaryContainer,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: _onProfileAvatarTap,
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: AppColors.primary,
                    backgroundImage: (_profile?.avatarUrl != null && _profile!.avatarUrl!.isNotEmpty)
                        ? NetworkImage(_profile!.avatarUrl!)
                        : null,
                    child: (_profile?.avatarUrl == null || _profile!.avatarUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 18, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSovereignTrustBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 8),
      color: AppColors.primaryContainer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.verified, color: AppColors.tertiaryFixed, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'राष्ट्रीय डिजिटल पायाभूत सुविधा • Digital India Initiative',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.surfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Ministry of Labour & Employment Verified Network',
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.primaryFixed,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: AppRadius.radiusFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, color: AppColors.tertiaryFixed, size: 13),
                const SizedBox(width: 4),
                Text(
                  'DigiLocker',
                  style: AppTypography.labelSm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationAndGreeting() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 8, AppSpacing.marginMobile, 6),
      color: AppColors.surfaceContainerLow,
      child: InkWell(
        onTap: _showLocationPickerSheet,
        borderRadius: AppRadius.radiusMd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: AppRadius.radiusMd,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.secondary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedArea == 'All Areas'
                          ? 'महाराष्ट्र प्रभाग • All Service Areas'
                          : '$_selectedArea प्रभाग • $_locationDisplay',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'महाराष्ट्र कामगार सहकारी मंच (Co-op Cluster #DPI)',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondaryFixed.withValues(alpha: 0.35),
                  borderRadius: AppRadius.radiusSm,
                ),
                child: Text(
                  'बदला',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 10, AppSpacing.marginMobile, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppRadius.radiusXl,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, color: AppColors.onSurfaceVariant, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty && _categories.isNotEmpty) {
                        _navigateToCategory(_categories.first, searchQuery: val.trim());
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'शोध: प्लंबर, इलेक्ट्रिशियन, गवंडी...'.tr(),
                      hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                // Voice button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: AppRadius.radiusMd,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('बोलून शोधा: मराठी, हिंदी किंवा English...')),
                      );
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: const Icon(Icons.mic, color: AppColors.primaryContainer, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Filter button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: AppRadius.radiusMd,
                    onTap: () {
                      if (_categories.isNotEmpty) {
                        _navigateToCategory(_categories.first);
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer,
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: const Icon(Icons.tune, color: AppColors.onPrimary, size: 19),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Quick Civic Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildCivicFilterPill(
                  id: 'all',
                  label: 'सर्व प्रमाणित (All Certified)',
                  icon: Icons.shield,
                  iconColor: _activeQuickFilter == 'all' ? Colors.white : AppColors.primary,
                ),
                const SizedBox(width: 8),
                _buildCivicFilterPill(
                  id: 'instant',
                  label: '३० मिनिटांत उपलब्ध',
                  icon: Icons.bolt,
                  iconColor: _activeQuickFilter == 'instant' ? Colors.white : AppColors.tertiaryFixedVariant,
                ),
                const SizedBox(width: 8),
                _buildCivicFilterPill(
                  id: 'capped',
                  label: 'सहकारी दर नियंत्रीत',
                  icon: Icons.gavel,
                  iconColor: _activeQuickFilter == 'capped' ? Colors.white : AppColors.secondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCivicFilterPill({
    required String id,
    required String label,
    required IconData icon,
    required Color iconColor,
  }) {
    final isSelected = _activeQuickFilter == id;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _activeQuickFilter = id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusFull,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: isSelected ? AppColors.onPrimary : AppColors.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoopTariffGuaranteeCallout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 8, AppSpacing.marginMobile, 4),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.secondaryContainer, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.radiusXl,
          boxShadow: [
            BoxShadow(
              color: AppColors.secondary.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: AppRadius.radiusFull,
                  ),
                  child: Text(
                    'कायदेशीर हमी • Co-op Protection',
                    style: AppTypography.labelSm.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const Icon(Icons.verified_user, color: Colors.white, size: 22),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '१००% सहकारी निश्चित दर हमी',
              style: AppTypography.headlineSm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'जिल्हा उपनिबंधक प्रमाणित दर सूची. मध्यस्थ कमिशन नाही; काम पूर्ण झाल्यावर OTP दिल्यानंतरच सुरक्षित एस्क्रो वर्गणी.',
              style: AppTypography.bodySm.copyWith(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyDispatchBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppRadius.radiusXl,
          border: Border.all(color: const Color(0xFF7F1D1D)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.starRating,
                borderRadius: AppRadius.radiusMd,
              ),
              child: const Icon(Icons.bolt, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Urgent SOS Dispatch'.tr(),
                        style: AppTypography.labelMd.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: AppRadius.radiusSm,
                        ),
                        child: Text(
                          'PRIORITY'.tr(),
                          style: const TextStyle(color: Color(0xFFDC2626), fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pipe burst, electrical spark, or lockout? Fast artisan response.'.tr(),
                    style: AppTypography.bodySm.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                elevation: 0,
              ),
              onPressed: _navigateToEmergencyDiscovery,
              child: Text('Dispatch'.tr(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveJobCard() {
    final booking = _activeBooking;
    if (booking == null) return const SizedBox.shrink();

    final bookingId = booking['id']?.toString() ?? '';
    final status = booking['status']?.toString() ?? 'pending';
    final serviceData = booking['services'] as Map<String, dynamic>?;
    final workerData = booking['workers'] as Map<String, dynamic>?;
    final workerUserData = workerData?['users'] as Map<String, dynamic>?;

    final serviceName = serviceData?['name']?.toString() ?? 'Service Request';
    final workerName = workerUserData?['full_name']?.toString() ?? 'Assigned Artisan';
    final amount = (booking['base_amount'] as num?)?.toDouble() ?? 0.0;
    final orderRef = bookingId.length >= 4 ? bookingId.substring(0, 4).toUpperCase() : (bookingId.isNotEmpty ? bookingId.toUpperCase() : 'REQ');

    final isLive = status != 'completed' && status != 'cancelled';

    final bookingStatus = BookingStatus.fromDbString(status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.radiusXl,
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    BookingStatusBadge(status: bookingStatus, isCompact: true),
                    const SizedBox(width: 8),
                    Text(
                      isLive ? 'Active Live Order' : 'Completed Order',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: AppRadius.radiusSm,
                  ),
                  child: Text('#BK-$orderRef', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 10)),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppRadius.radiusLg,
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: const Icon(Icons.person, size: 24, color: AppColors.deepTeal),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        decoration: const BoxDecoration(
                          color: AppColors.deepTeal,
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                        ),
                        child: Text(
                          'GUILD',
                          textAlign: TextAlign.center,
                          style: AppTypography.labelSm.copyWith(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(serviceName, style: AppTypography.labelLg.copyWith(color: AppColors.deepTeal, fontWeight: FontWeight.bold)),
                      Text('$workerName • Pune Central Co-op', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11)),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.tertiaryContainer,
                          borderRadius: AppRadius.radiusSm,
                        ),
                        child: Text(
                          '₹${amount.toStringAsFixed(0)} Diagnostic Escrow',
                          style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.call_outlined, color: AppColors.deepTeal),
                  onPressed: () => _showHelplineDialer(),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.outlineVariant),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerLiveTrackingScreen(bookingId: bookingId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.receipt_long, size: 15, color: AppColors.deepTeal),
                    label: Text('Details', style: AppTypography.labelSm.copyWith(color: AppColors.deepTeal, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerLiveTrackingScreen(bookingId: bookingId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation, size: 15, color: AppColors.warmAmber),
                    label: Text('Track Partner', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final tradeSpecs = [
      _UcTradeSpec(
        id: 'c2',
        tradeKey: 'plumbing',
        name: 'Plumbing',
        marathiName: 'नळ व स्वच्छता',
        englishSubtitle: 'Plumbing & Sanitary',
        iconName: 'plumbing',
        iconData: Icons.plumbing,
        accentColor: AppColors.primaryContainer,
        startingRate: 199,
        rating: 4.88,
        jobsCount: 128,
        tags: ['नळ व मिक्सर', 'गळती दुरुस्ती', 'पाण्याची टाकी', 'बेसिन व ड्रेन', 'जेट स्प्रे'],
        subServices: const [
          _UcSubService(
            title: 'नळ व मिक्सर दुरुस्ती / बदली (Tap & Mixer Repair)',
            description: 'गळती बंद करणे, नवीन वॉशर बसवणे, मिक्सर हँडल दुरुस्ती आणि पाण्याचा वेग तपासणे.',
            rate: 199,
            durationMinutes: 25,
            badge: 'सर्वात लोकप्रिय • Most Booked',
          ),
          _UcSubService(
            title: 'पाईप लीकेज व ड्रेनेज ब्लॉकेज (Pipe Leak & Drain Unclog)',
            description: 'बेसिन पाईप, सिंक खालील गळती व ड्रेनेज कचरा ब्लॉकेज त्वरित काढणे.',
            rate: 299,
            durationMinutes: 40,
            badge: 'तातडीची सेवा • Express Fix',
          ),
          _UcSubService(
            title: 'पाण्याच्या टाकीची सखोल स्वच्छता (Water Tank Deep Cleaning)',
            description: 'ओव्हरहेड / अंडरग्राउंड टाकीचे गाळ काढणे व सॅनिटायझेशन प्रक्रिया.',
            rate: 499,
            durationMinutes: 60,
            badge: 'सहकारी हमी • Certified Hygiene',
          ),
          _UcSubService(
            title: 'टॉयलेट जेट स्प्रे व अँगुलर कॉक (Jet Spray & Angle Valve)',
            description: 'नवीन जेट स्प्रे, पीव्हीसी कनेक्शन पाईप व व्हॉल्व्ह सुरक्षित बसवणे.',
            rate: 199,
            durationMinutes: 20,
            badge: 'निश्चित दर • Fixed Tariff',
          ),
          _UcSubService(
            title: 'संपूर्ण घरगुती प्लंबिंग तपासणी (Full Plumbing Diagnostic)',
            description: 'सर्व नळ, टाकी फ्लोट व्हॉल्व्ह, ड्रेनेज व प्रेशरचे सखोल परीक्षण.',
            rate: 149,
            durationMinutes: 20,
            badge: 'प्राथमिक निदान • Diagnostic',
          ),
        ],
      ),
      _UcTradeSpec(
        id: 'c1',
        tradeKey: 'electrical',
        name: 'Electrical',
        marathiName: 'वीज व वायरिंग',
        englishSubtitle: 'Licensed Electricians',
        iconName: 'power',
        iconData: Icons.bolt,
        accentColor: AppColors.secondary,
        startingRate: 149,
        rating: 4.90,
        jobsCount: 94,
        tags: ['स्विच व सॉकेट', 'फॅन व लाईट', 'MCB व फ्युज', 'इन्व्हर्टर वायरिंग', 'शॉर्ट सर्किट'],
        subServices: const [
          _UcSubService(
            title: 'स्विच व सॉकेट दुरुस्ती / बदली (Switch & Socket Repair)',
            description: 'बर्न झालेले स्विच, १६A हेवी पॉवर पॉईंट व नवीन मॉड्यूलर बोर्ड फिटिंग.',
            rate: 149,
            durationMinutes: 20,
            badge: 'सर्वात लोकप्रिय • Most Booked',
          ),
          _UcSubService(
            title: 'सिलिंग फॅन बसवणे व दुरुस्ती (Ceiling Fan Install & Repair)',
            description: 'फॅन मोटर ब्लेड बॅलन्स, कॅपेसिटर बदली व नवीन फॅन सुरक्षित इन्स्टॉलेशन.',
            rate: 199,
            durationMinutes: 30,
            badge: 'परवानाधारक • Licensed',
          ),
          _UcSubService(
            title: 'MCB ट्रिपिंग व फ्युज बॉक्स तपासणी (MCB Tripping & Fuse)',
            description: 'वारंवार ट्रिप होणारा MCB, ओव्हरलोड व शॉर्ट सर्किट शोधून तात्काळ दुरुस्त करणे.',
            rate: 299,
            durationMinutes: 35,
            badge: 'सुरक्षा हमी • Safety Certified',
          ),
          _UcSubService(
            title: 'इन्व्हर्टर लाईन व सेंट्रल वायरिंग (Inverter Line & Wiring)',
            description: 'इन्व्हर्टर बायपास, बॅटरी कनेक्शन व मुख्य वायरिंग फॉल्ट शोधणे.',
            rate: 399,
            durationMinutes: 60,
            badge: 'तांत्रिक तज्ज्ञ • Master Wireman',
          ),
          _UcSubService(
            title: 'डेकोरेटिव्ह लाईट्स व झूमर फिटिंग (Decorative Lighting)',
            description: 'एलईडी बॅटन, प्रोफाइल लाईट, सीलिंग झूमर व वॉल लॅम्प सुरक्षित बसवणे.',
            rate: 249,
            durationMinutes: 35,
            badge: 'निश्चित दर • Fixed Tariff',
          ),
        ],
      ),
      _UcTradeSpec(
        id: 'c3',
        tradeKey: 'carpentry',
        name: 'Carpentry',
        marathiName: 'सुतारकाम व लाकूडकाम',
        englishSubtitle: 'Carpentry & Craft',
        iconName: 'carpenter',
        iconData: Icons.carpenter,
        accentColor: const Color(0xFF8D5B4C),
        startingRate: 199,
        rating: 4.85,
        jobsCount: 67,
        tags: ['दरवाजा लॉक', 'कपाट बिजागऱ्या', 'ड्रील व हँग', 'फर्निचर दुरुस्ती', 'पडदे रॉड'],
        subServices: const [
          _UcSubService(
            title: 'दरवाजा लॉक व हँडल बसवणे (Door Lock & Handle Fitting)',
            description: 'अडकलेले लॉक, टॉवर बोल्ट, लॅच व नवीन मुख्य सुरक्षा कुलूप बसवणे.',
            rate: 249,
            durationMinutes: 30,
            badge: 'सुरक्षित कुलूप • High Security',
          ),
          _UcSubService(
            title: 'कपाटाच्या हायड्रॉलिक बिजागऱ्या (Cupboard Hinges & Channels)',
            description: 'कपाटाचे दरवाजे ॲडजस्ट करणे, हायड्रॉलिक हिंज व ड्रॉवर चॅनेल बदलणे.',
            rate: 299,
            durationMinutes: 40,
            badge: 'कुशल कारागीर • Precision Fit',
          ),
          _UcSubService(
            title: 'ड्रील व वॉल हँगिंग (Drill & Wall Hang Service)',
            description: 'टीव्ही माउंट, आरसा, फोटो फ्रेम, पडदा रॉड व वॉल शेल्फ मजबूत फिटिंग.',
            rate: 199,
            durationMinutes: 25,
            badge: 'धुळमुक्त ड्रील • Dust Free',
          ),
          _UcSubService(
            title: 'लाकडी फर्निचर दुरुस्ती (Bed, Table & Chair Repair)',
            description: 'हळणारे पलंग, टेबल, खुर्च्या घट्ट करणे, लाकडी भाग जोडणे व लेव्हलिंग.',
            rate: 399,
            durationMinutes: 60,
            badge: 'मजबूत जोड • Durable Craft',
          ),
        ],
      ),
      _UcTradeSpec(
        id: 'c6',
        tradeKey: 'appliance',
        name: 'Appliance',
        marathiName: 'उपकरणे दुरुस्ती',
        englishSubtitle: 'Appliance Care Tech',
        iconName: 'home_repair_service',
        iconData: Icons.home_repair_service,
        accentColor: const Color(0xFF0284C7),
        startingRate: 299,
        rating: 4.87,
        jobsCount: 85,
        tags: ['गिझर सर्व्हिस', 'वॉशिंग मशीन', 'फ्रिज दुरुस्ती', 'एसी सर्व्हिस', 'वॉटर प्युरिफायर'],
        subServices: const [
          _UcSubService(
            title: 'गिझर व वॉटर हीटर सर्व्हिस (Geyser Repair & Descaling)',
            description: 'पाणी गरम न होणे, कॉईल स्केलिंग काढणे व थर्मोस्टॅट तपासणी.',
            rate: 349,
            durationMinutes: 45,
            badge: 'शॉर्ट-प्रूफ • Shock Proof',
          ),
          _UcSubService(
            title: 'वॉशिंग मशीन दुरुस्ती व ड्रम चेक (Washing Machine Service)',
            description: 'ड्रेन एरर, स्पिन न होणे, मोठा आवाज व मोटर बेल्ट तपासणी.',
            rate: 399,
            durationMinutes: 45,
            badge: 'मूळ सुटे भाग • Genuine Spares',
          ),
          _UcSubService(
            title: 'रेफ्रिजरेटर कुलिंग व गॅस चेक (Refrigerator Cooling & Gas)',
            description: 'कुलिंग न होणे, कॉम्प्रेशर रिले व कुलिंग कॉईल गळती सखोल तपासणी.',
            rate: 449,
            durationMinutes: 50,
            badge: 'कूलिंग हमी • Chilling Guarantee',
          ),
          _UcSubService(
            title: 'एअर कंडिशनर फोम सर्व्हिस (AC Foam Jet Deep Clean)',
            description: 'हाय-प्रेशर वॉटर जेटने फिल्टर, कॉईल धुणे व गॅस प्रेशर चेक.',
            rate: 499,
            durationMinutes: 60,
            badge: 'पॉवर सेव्हर • Power Saver',
          ),
        ],
      ),
      _UcTradeSpec(
        id: 'c4',
        tradeKey: 'cleaning',
        name: 'Cleaning',
        marathiName: 'सखोल स्वच्छता',
        englishSubtitle: 'Deep Cleaning & Sanitize',
        iconName: 'cleaning_services',
        iconData: Icons.cleaning_services,
        accentColor: const Color(0xFF059669),
        startingRate: 399,
        rating: 4.92,
        jobsCount: 112,
        tags: ['बाथरूम स्क्रबिंग', 'किचन डीग्रेसिंग', 'संपूर्ण घर स्वच्छता', 'सोफा वॉश'],
        subServices: const [
          _UcSubService(
            title: 'बाथरूम इंटेंसिव्ह स्क्रबिंग (Bathroom Deep Scrubbing)',
            description: 'फरशीवरील क्षार डाग काढणे, टाइल्स व कमोड ॲसिड-मुक्त डीप क्लीन.',
            rate: 399,
            durationMinutes: 60,
            badge: 'चकाचक हमी • Stain Free',
          ),
          _UcSubService(
            title: 'किचन चिमणी व ओटा डीग्रेसिंग (Kitchen Degreasing)',
            description: 'तेलकट डाग, चिमणी फिल्टर व गॅस शेगडीची संपूर्ण निर्जंतुक स्वच्छता.',
            rate: 499,
            durationMinutes: 75,
            badge: 'तेलकटमुक्त • Zero Grease',
          ),
          _UcSubService(
            title: 'संपूर्ण घर सखोल स्वच्छता पॅकेज (Full Home Deep Clean)',
            description: 'सर्व रूम्सच्या फरशा मशीनने घासणे, पंखे, खिडक्या व कोपरे चकचकीत.',
            rate: 1299,
            durationMinutes: 180,
            badge: 'मशीन स्क्रबिंग • Pro Clean',
          ),
          _UcSubService(
            title: 'फॅब्रिक सोफा व कुशन सॅनिटायझेशन (Sofa Steam Wash)',
            description: 'धुळीचे डाग काढणे व ॲन्टी-बॅक्टेरियल फोम ड्राय क्लिनिंग.',
            rate: 599,
            durationMinutes: 60,
            badge: 'जंतुनाशक • Germ Free',
          ),
        ],
      ),
      _UcTradeSpec(
        id: 'c5',
        tradeKey: 'painting',
        name: 'Painting',
        marathiName: 'रंगकाम व वॉटरप्रूफिंग',
        englishSubtitle: 'Painting & Waterproofing',
        iconName: 'format_paint',
        iconData: Icons.format_paint,
        accentColor: const Color(0xFF7C3AED),
        startingRate: 449,
        rating: 4.82,
        jobsCount: 45,
        tags: ['वॉल टच-अप', 'वॉटरप्रूफिंग', 'खोली रंगकाम', 'लाकूड पॉलिश'],
        subServices: const [
          _UcSubService(
            title: 'वॉल पॅच टच-अप व पुट्टी (Wall Patch Putty & Touch-up)',
            description: 'ओलसर पडलेले पोपडे काढणे, पुट्टी भरणे व मूळ शेड जुळवून कलर करणे.',
            rate: 449,
            durationMinutes: 60,
            badge: 'अचूक शेड मॅच • Perfect Match',
          ),
          _UcSubService(
            title: 'पॉलिमर वॉटरप्रूफिंग लीकेज सील (Waterproofing Damp Seal)',
            description: 'भिंतीवरील पाण्याचे पाझर व डाग विशेष केमिकल कोटिंगने बंद करणे.',
            rate: 699,
            durationMinutes: 90,
            badge: '५ वर्षे हमी • Anti Leak',
          ),
          _UcSubService(
            title: 'एका रूमचे संपूर्ण रंगकाम (Single Room Repaint)',
            description: 'प्रिमियम इमल्शन कलर, प्राइमर व रोलर फिनिशने नवीन लूक.',
            rate: 1499,
            durationMinutes: 360,
            badge: 'रोलर फिनिश • Smooth Wall',
          ),
        ],
      ),
      _UcTradeSpec(
        id: 'c7',
        tradeKey: 'masonry',
        name: 'Masonry',
        marathiName: 'बांधकाम व गवंडी',
        englishSubtitle: 'Civil & Masonry Guild',
        iconName: 'foundation',
        iconData: Icons.foundation,
        accentColor: const Color(0xFF475569),
        startingRate: 349,
        rating: 4.86,
        jobsCount: 110,
        tags: ['फरशी दुरुस्ती', 'प्लास्टर काम', 'इपॉक्सी ग्राउटिंग', 'भिंत भेगा भरणे'],
        subServices: const [
          _UcSubService(
            title: 'तुटलेली फरशी व इपॉक्सी ग्राउट (Tile Repair & Grout)',
            description: 'हलणाऱ्या टाइल्स पुन्हा बसवणे, वॉटरप्रूफ इपॉक्सी ग्राउट भरणे.',
            rate: 349,
            durationMinutes: 45,
            badge: 'वॉटरप्रूफ • Non Crack',
          ),
          _UcSubService(
            title: 'भिंत प्लास्टर व सिमेंट पॅच (Plaster & Crack Filling)',
            description: 'भिंतीवरील पडलेले प्लास्टर सिमेंटने पुन्हा मजबूत करणे.',
            rate: 449,
            durationMinutes: 60,
            badge: 'मजबूत पॅच • Solid Bind',
          ),
          _UcSubService(
            title: 'दरवाजा उंबरा व खिडकी सिमेंटिंग (Threshold Masonry)',
            description: 'उंबऱ्याजवळील मोकळी जागा, खिडकी फ्रेम पॅकिंग व फिनिशिंग.',
            rate: 399,
            durationMinutes: 50,
            badge: 'लेव्हल फिनिश • Level Fit',
          ),
        ],
      ),
      _UcTradeSpec(
        id: 'c8',
        tradeKey: 'gardening',
        name: 'Gardening',
        marathiName: 'बागकाम व देखभाल',
        englishSubtitle: 'Garden & Greenery Care',
        iconName: 'yard',
        iconData: Icons.yard,
        accentColor: const Color(0xFF15803D),
        startingRate: 299,
        rating: 4.89,
        jobsCount: 58,
        tags: ['झाडांची छाटणी', 'गवत कापणे', 'सेंद्रिय खत', 'कुंडी बदलणे'],
        subServices: const [
          _UcSubService(
            title: 'गॅलरी गार्डन झाडांची छाटणी (Balcony Garden Pruning)',
            description: 'वाळलेल्या फांद्या कापणे, सेंद्रिय खत मिसळणे व झाडांना आकार देणे.',
            rate: 299,
            durationMinutes: 45,
            badge: 'हिरवेगार हमी • Lush Green',
          ),
          _UcSubService(
            title: 'लॉन कटिंग व कडा ट्रिमिंग (Lawn Mowing & Hedge Trim)',
            description: 'मशीनने गवत एकसमान कापणे व कचरा गोळा करून स्वच्छ करणे.',
            rate: 499,
            durationMinutes: 60,
            badge: 'एकसमान लेव्हल • Neat Edge',
          ),
          _UcSubService(
            title: 'नवीन कुंड्या भरणे व माती मिश्रण (Repotting & Soil Mix)',
            description: 'लाल माती, कोकोपीट व गांडूळ खत भरून नवीन झाडे लावणे.',
            rate: 399,
            durationMinutes: 50,
            badge: 'सेंद्रिय पोषण • Organic Care',
          ),
        ],
      ),
    ];

    // Filter trade specs by selected trade pill
    final filteredSpecs = tradeSpecs.where((spec) {
      if (_selectedTradeFilter != 'all' && spec.tradeKey != _selectedTradeFilter) {
        return false;
      }
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = spec.name.toLowerCase().contains(query) ||
            spec.marathiName.toLowerCase().contains(query) ||
            spec.englishSubtitle.toLowerCase().contains(query);
        final matchesTags = spec.tags.any((t) => t.toLowerCase().contains(query));
        return matchesName || matchesTags;
      }
      return true;
    }).toList();

    final totalArtisansInArea = _getTotalArtisansInArea(_selectedArea);

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 14, AppSpacing.marginMobile, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header with Title & All Services Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'प्रमाणित सेवा सूची • URBAN CO-OP CATALOG'.toUpperCase(),
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'अत्यावश्यक व्यवसाय सूची व थेट निवड',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (widget.onSelectTab != null) {
                    widget.onSelectTab!(1);
                  } else if (_categories.isNotEmpty) {
                    _navigateToCategory(_categories.first);
                  }
                },
                child: Text(
                  'सर्व सेवा (${tradeSpecs.length}) >',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Urban Company Area Selector Bar & Live Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppColors.secondary, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _selectedArea == 'All Areas' ? 'सर्व पुणे प्रभाग' : _selectedArea,
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: _showLocationPickerSheet,
                          child: const Icon(Icons.arrow_drop_down, color: AppColors.secondary, size: 20),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: totalArtisansInArea > 0
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFFFFBEB),
                        borderRadius: AppRadius.radiusFull,
                        border: Border.all(
                          color: totalArtisansInArea > 0
                              ? const Color(0xFFBBF7D0)
                              : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            totalArtisansInArea > 0 ? Icons.verified : Icons.bolt,
                            size: 12,
                            color: totalArtisansInArea > 0
                                ? const Color(0xFF16A34A)
                                : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            totalArtisansInArea > 0
                                ? '⚡ $totalArtisansInArea कारागीर सज्ज'
                                : '⚡ महासंघ एक्सप्रेस',
                            style: AppTypography.labelSm.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: totalArtisansInArea > 0
                                  ? const Color(0xFF15803D)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Area Switcher Quick Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _serviceAreas.take(9).map((area) {
                      final isSelected = _selectedArea == area;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(area == 'All Areas' ? 'सर्व भाग' : area),
                          selected: isSelected,
                          selectedColor: AppColors.primaryContainer,
                          backgroundColor: AppColors.surfaceContainerLow,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.onSurface,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 11,
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedArea = area;
                              });
                              _syncServiceAreas();
                            }
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // 3. Trade Category Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTradePill('all', 'सर्व सेवा (All)', Icons.apps),
                const SizedBox(width: 6),
                _buildTradePill('plumbing', 'नळकाम (Plumbing)', Icons.plumbing),
                const SizedBox(width: 6),
                _buildTradePill('electrical', 'विद्युत (Electrical)', Icons.bolt),
                const SizedBox(width: 6),
                _buildTradePill('carpentry', 'सुतारकाम (Carpentry)', Icons.carpenter),
                const SizedBox(width: 6),
                _buildTradePill('appliance', 'उपकरणे (Appliance)', Icons.home_repair_service),
                const SizedBox(width: 6),
                _buildTradePill('cleaning', 'स्वच्छता (Cleaning)', Icons.cleaning_services),
                const SizedBox(width: 6),
                _buildTradePill('painting', 'रंगकाम (Painting)', Icons.format_paint),
                const SizedBox(width: 6),
                _buildTradePill('masonry', 'गवंडीकाम (Civil)', Icons.foundation),
                const SizedBox(width: 6),
                _buildTradePill('gardening', 'बागकाम (Garden)', Icons.yard),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 4. Urban Company Service Catalog Grid
          if (filteredSpecs.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppRadius.radiusLg,
              ),
              child: Column(
                children: [
                  const Icon(Icons.search_off, size: 36, color: AppColors.outline),
                  const SizedBox(height: 8),
                  Text('कोणतीही सेवा आढळली नाही', style: AppTypography.titleMd.copyWith(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text('कृपया इतर प्रवर्ग किंवा भाग निवडा', style: AppTypography.bodySm.copyWith(color: AppColors.outline)),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final crossAxisCount = w >= 960 ? 4 : 2;
                final aspectRatio = w >= 960 ? 1.45 : 1.05;

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: aspectRatio,
                  ),
                  itemCount: filteredSpecs.length,
                  itemBuilder: (context, index) {
                    final spec = filteredSpecs[index];
                    final matchedCategory = _categories.firstWhere(
                      (c) => c.id == spec.id || c.name.toLowerCase().contains(spec.name.toLowerCase()),
                      orElse: () => ServiceCategory(id: spec.id, name: spec.name, iconData: spec.iconName),
                    );
                    final workerCount = _getWorkerCountForTrade(spec.id, spec.name, _selectedArea);
                    final hasDirectWorkers = workerCount > 0;
                    final availableArtisans = _getArtisansForTrade(spec.id, spec.name, _selectedArea);

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: AppRadius.radiusXl,
                        onTap: () => _showUrbanCompanyServiceSheet(spec, matchedCategory, availableArtisans),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: AppRadius.radiusXl,
                            border: Border.all(
                              color: hasDirectWorkers
                                  ? AppColors.outlineVariant.withValues(alpha: 0.8)
                                  : AppColors.outlineVariant.withValues(alpha: 0.5),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top Row: Icon + Live Area Worker Availability Pill
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: spec.accentColor.withValues(alpha: 0.12),
                                      borderRadius: AppRadius.radiusLg,
                                      border: Border.all(color: spec.accentColor.withValues(alpha: 0.2)),
                                    ),
                                    child: Icon(
                                      spec.iconData,
                                      size: 22,
                                      color: spec.accentColor,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: hasDirectWorkers
                                          ? const Color(0xFFF0FDF4)
                                          : const Color(0xFFFFFBEB),
                                      borderRadius: AppRadius.radiusSm,
                                      border: Border.all(
                                        color: hasDirectWorkers
                                            ? const Color(0xFFBBF7D0)
                                            : const Color(0xFFFDE68A),
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          hasDirectWorkers
                                              ? '⚡ $workerCount सज्ज'
                                              : '⚡ महासंघ डिस्पॅच',
                                          style: AppTypography.labelSm.copyWith(
                                            color: hasDirectWorkers
                                                ? const Color(0xFF15803D)
                                                : const Color(0xFFB45309),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 9,
                                          ),
                                        ),
                                        Text(
                                          hasDirectWorkers ? '~१५ मि. थेट' : '~२५ मि. आगमन',
                                          style: AppTypography.labelSm.copyWith(
                                            color: hasDirectWorkers
                                                ? const Color(0xFF166534)
                                                : const Color(0xFF92400E),
                                            fontSize: 8,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              // Middle Column: Title, Subtitle, Rating & Tags
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    spec.marathiName,
                                    style: AppTypography.titleMd.copyWith(
                                      color: AppColors.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      height: 1.15,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    spec.englishSubtitle,
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      const Icon(Icons.star, size: 12, color: AppColors.starRating),
                                      const SizedBox(width: 2),
                                      Text(
                                        '${spec.rating} (${spec.jobsCount}+)',
                                        style: AppTypography.labelSm.copyWith(
                                          color: AppColors.onSurface,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  // Sub-service chip preview
                                  Text(
                                    spec.tags.take(2).join(' • '),
                                    style: AppTypography.bodySm.copyWith(
                                      color: AppColors.outline,
                                      fontSize: 9,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),

                              // Bottom Row: Starting Rate & Select Button
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '₹${spec.startingRate.toInt()} पासून',
                                        style: AppTypography.labelMd.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        '०% मध्यस्थ कमिशन',
                                        style: AppTypography.labelSm.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                          fontSize: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryContainer,
                                      borderRadius: AppRadius.radiusSm,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'निवडा',
                                          style: AppTypography.labelSm.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.chevron_right, size: 12, color: Colors.white),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTradePill(String key, String label, IconData icon) {
    final isSelected = _selectedTradeFilter == key;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _selectedTradeFilter = key;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusFull,
          border: Border.all(
            color: isSelected ? AppColors.primaryContainer : AppColors.outlineVariant,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : AppColors.primary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: isSelected ? Colors.white : AppColors.onSurface,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getWorkerCountForTrade(String tradeId, String tradeName, String area) {
    if (area == 'All Areas') {
      return _featuredWorkers.where((w) => _workerMatchesTrade(w, tradeId, tradeName)).length;
    }
    final target = area.toLowerCase();
    final keywords = target.split(RegExp(r'[\s,&]+')).where((s) => s.length > 2).toList();
    return _featuredWorkers.where((w) {
      if (!_workerMatchesTrade(w, tradeId, tradeName)) return false;
      final loc = w.locationTag.toLowerCase();
      final matchesTag = keywords.any((k) => loc.contains(k));
      final matchesAreas = w.serviceAreas.any((sa) => keywords.any((k) => sa.toLowerCase().contains(k)));
      return matchesTag || matchesAreas;
    }).length;
  }

  bool _workerMatchesTrade(Worker w, String tradeId, String tradeName) {
    if (w.categoryId == tradeId) return true;
    const uuidToId = {
      '11111111-1111-1111-1111-111111111111': 'c1',
      '22222222-2222-2222-2222-222222222222': 'c2',
      '33333333-3333-3333-3333-333333333333': 'c3',
      '55555555-5555-5555-5555-555555555555': 'c4',
      '44444444-4444-4444-4444-444444444444': 'c5',
      '99999999-9999-9999-9999-999999999999': 'c6',
      '88888888-8888-8888-8888-888888888888': 'c7',
      '77777777-7777-7777-7777-777777777777': 'c8',
    };
    if (uuidToId[w.categoryId] == tradeId) return true;
    final nameLower = tradeName.toLowerCase();
    return w.specializations.any((s) => s.toLowerCase().contains(nameLower));
  }

  List<Worker> _getArtisansForTrade(String tradeId, String tradeName, String area) {
    final matchingWorkers = _featuredWorkers.where((w) => _workerMatchesTrade(w, tradeId, tradeName)).toList();
    if (matchingWorkers.isEmpty) return [];

    if (area == 'All Areas') return matchingWorkers;

    final target = area.toLowerCase();
    final keywords = target.split(RegExp(r'[\s,&]+')).where((s) => s.length > 2).toList();
    final direct = matchingWorkers.where((w) {
      final loc = w.locationTag.toLowerCase();
      final matchesTag = keywords.any((k) => loc.contains(k));
      final matchesAreas = w.serviceAreas.any((sa) => keywords.any((k) => sa.toLowerCase().contains(k)));
      return matchesTag || matchesAreas;
    }).toList();

    if (direct.isNotEmpty) return direct;

    // Cooperative collective dispatch fallback: returns federation artisans ready to serve this area
    return matchingWorkers.map((w) => Worker(
      id: w.id,
      name: w.name,
      categoryId: w.categoryId,
      rate: w.rate,
      rating: w.rating,
      reviewCount: w.reviewCount,
      jobsCompleted: w.jobsCompleted,
      distanceKm: 2.8,
      experience: w.experience,
      availability: 'Available Today',
      specializations: w.specializations,
      locationTag: 'Serving $area (${w.locationTag})',
      imageUrl: w.imageUrl,
      customTag: 'Cooperative Collective Dispatch',
      bio: w.bio,
      federationId: w.federationId,
      insuranceAmount: w.insuranceAmount,
      languages: w.languages,
      serviceAreas: [...w.serviceAreas, area],
      isUnionGold: w.isUnionGold,
      isCoopMaster: w.isCoopMaster,
    )).toList();
  }

  int _getTotalArtisansInArea(String area) {
    if (area == 'All Areas') return _featuredWorkers.length;
    final target = area.toLowerCase();
    final keywords = target.split(RegExp(r'[\s,&]+')).where((s) => s.length > 2).toList();
    final direct = _featuredWorkers.where((w) {
      final loc = w.locationTag.toLowerCase();
      final matchesTag = keywords.any((k) => loc.contains(k));
      final matchesAreas = w.serviceAreas.any((sa) => keywords.any((k) => sa.toLowerCase().contains(k)));
      return matchesTag || matchesAreas;
    }).length;
    return direct > 0 ? direct : _featuredWorkers.length;
  }

  void _showUrbanCompanyServiceSheet(
    _UcTradeSpec spec,
    ServiceCategory matchedCategory,
    List<Worker> availableWorkers,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            final currentWorkers = _getArtisansForTrade(spec.id, spec.name, _selectedArea);
            final currentCount = _getWorkerCountForTrade(spec.id, spec.name, _selectedArea);
            final currentHasDirect = currentCount > 0;

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Grab Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      decoration: BoxDecoration(
                        color: AppColors.outlineVariant,
                        borderRadius: AppRadius.radiusFull,
                      ),
                    ),
                  ),

                  // Header with service info & close button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: spec.accentColor.withValues(alpha: 0.12),
                            borderRadius: AppRadius.radiusLg,
                            border: Border.all(color: spec.accentColor.withValues(alpha: 0.25)),
                          ),
                          child: Icon(spec.iconData, color: spec.accentColor, size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                spec.marathiName,
                                style: AppTypography.titleMd.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                spec.englishSubtitle,
                                style: AppTypography.bodySm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 14, color: AppColors.starRating),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${spec.rating} (${spec.jobsCount}+ कामे)',
                                    style: AppTypography.labelSm.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryFixed.withValues(alpha: 0.15),
                                      borderRadius: AppRadius.radiusSm,
                                    ),
                                    child: Text(
                                      'सहकारी हमी दर • ०% कमिशन',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.primary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                  ),

                  // Inline Area Bar with fast change button
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: currentHasDirect
                          ? const Color(0xFFF0FDF4)
                          : const Color(0xFFFFFBEB),
                      borderRadius: AppRadius.radiusMd,
                      border: Border.all(
                        color: currentHasDirect
                            ? const Color(0xFFBBF7D0)
                            : const Color(0xFFFDE68A),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                currentHasDirect ? Icons.verified : Icons.bolt,
                                size: 18,
                                color: currentHasDirect
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentHasDirect
                                          ? '$_selectedArea: $currentCount स्थानिक कारागीर सज्ज'
                                          : '$_selectedArea: सहकारी मंच एक्सप्रेस डिस्पॅच',
                                      style: AppTypography.labelSm.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: currentHasDirect
                                            ? const Color(0xFF15803D)
                                            : const Color(0xFFB45309),
                                      ),
                                    ),
                                    Text(
                                      currentHasDirect
                                          ? 'सरासरी १५-२० मिनिटांत थेट आगमन'
                                          : '२५-३० मिनिटांत प्रमाणित कारागीर उपलब्ध',
                                      style: AppTypography.labelSm.copyWith(
                                        fontSize: 10,
                                        color: currentHasDirect
                                            ? const Color(0xFF166534)
                                            : const Color(0xFF92400E),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.pop(modalCtx);
                            _showLocationPickerSheet();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: AppRadius.radiusSm,
                              border: Border.all(color: AppColors.outlineVariant),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.edit_location_alt, size: 12, color: AppColors.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  'बदला',
                                  style: AppTypography.labelSm.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.secondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 16),

                  // Scrollable Body: Sub-Services Packages + Available Artisans
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        Text(
                          'सेवा पॅकेजेस निवडा (Select Service Package)',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Sub Services List
                        ...spec.subServices.map((sub) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: AppRadius.radiusLg,
                              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.secondaryFixed.withValues(alpha: 0.35),
                                              borderRadius: AppRadius.radiusSm,
                                            ),
                                            child: Text(
                                              sub.badge,
                                              style: AppTypography.labelSm.copyWith(
                                                color: AppColors.secondary,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            sub.title,
                                            style: AppTypography.labelLg.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            sub.description,
                                            style: AppTypography.bodySm.copyWith(
                                              color: AppColors.onSurfaceVariant,
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              const Icon(Icons.timer_outlined, size: 13, color: AppColors.outline),
                                              const SizedBox(width: 3),
                                              Text(
                                                '~${sub.durationMinutes} मिनिटे',
                                                style: AppTypography.labelSm.copyWith(
                                                  color: AppColors.outline,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              const Icon(Icons.shield_outlined, size: 13, color: AppColors.outline),
                                              const SizedBox(width: 3),
                                              Text(
                                                '३०-दिवस वॉरंटी',
                                                style: AppTypography.labelSm.copyWith(
                                                  color: AppColors.outline,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${sub.rate.toInt()}',
                                          style: AppTypography.headlineSm.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          'सहकारी दर',
                                          style: AppTypography.labelSm.copyWith(
                                            color: AppColors.onSurfaceVariant,
                                            fontSize: 9,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.primaryContainer,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: AppRadius.radiusMd,
                                            ),
                                            elevation: 0,
                                          ),
                                          onPressed: () {
                                            Navigator.pop(modalCtx);
                                            // Preselect category and worker
                                            bookingFlowState.selectedCategory = matchedCategory;
                                            if (currentWorkers.isNotEmpty) {
                                              bookingFlowState.selectedWorker = currentWorkers.first;
                                            }
                                            Navigator.of(context).push(
                                              MaterialPageRoute(
                                                builder: (_) => const BookingDateTimeScreen(),
                                              ),
                                            );
                                          },
                                          child: Text(
                                            '+ बुक करा',
                                            style: AppTypography.labelMd.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 16),

                        // Available Artisans Serving This Area
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'प्रमाणित स्थानिक कारागीर ($_selectedArea)',
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${currentWorkers.length} उपलब्ध',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (currentWorkers.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: AppRadius.radiusLg,
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: AppColors.secondary),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'या प्रभागात थेट नोंदणीकृत कारागीर शोधत आहोत. सहकारी महासंघ एक्सप्रेस डिस्पॅच द्वारे त्वरित कारागीर पाठवला जाईल.',
                                    style: AppTypography.bodySm.copyWith(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            height: 175,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: currentWorkers.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 10),
                              itemBuilder: (context, wIdx) {
                                final worker = currentWorkers[wIdx];
                                return Container(
                                  width: 250,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: AppRadius.radiusLg,
                                    border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.7)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: AppColors.surfaceContainerLow,
                                            backgroundImage: worker.imageUrl.isNotEmpty
                                                ? NetworkImage(worker.imageUrl)
                                                : null,
                                            child: worker.imageUrl.isEmpty
                                                ? const Icon(Icons.person, color: AppColors.primary)
                                                : null,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  worker.name,
                                                  style: AppTypography.labelMd.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.star, size: 12, color: AppColors.starRating),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      '${worker.rating} (${worker.reviewCount})',
                                                      style: AppTypography.labelSm.copyWith(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        worker.locationTag,
                                        style: AppTypography.bodySm.copyWith(
                                          color: AppColors.onSurfaceVariant,
                                          fontSize: 10,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '₹${worker.rate.toInt()}/व्हिजिट',
                                            style: AppTypography.labelMd.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  Navigator.pop(modalCtx);
                                                  _navigateToWorkerProfile(worker);
                                                },
                                                child: Text(
                                                  'प्रोफाइल',
                                                  style: AppTypography.labelSm.copyWith(
                                                    color: AppColors.onSurfaceVariant,
                                                    fontSize: 10,
                                                    decoration: TextDecoration.underline,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.secondary,
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: AppRadius.radiusSm,
                                                  ),
                                                ),
                                                onPressed: () {
                                                  Navigator.pop(modalCtx);
                                                  bookingFlowState.selectedCategory = matchedCategory;
                                                  bookingFlowState.selectedWorker = worker;
                                                  Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) => const BookingDateTimeScreen(),
                                                    ),
                                                  );
                                                },
                                                child: const Text('निवडा', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),

                        const SizedBox(height: 16),

                        // FairMatch Instant Dispatch Banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryContainer],
                            ),
                            borderRadius: AppRadius.radiusLg,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: AppRadius.radiusMd,
                                ),
                                child: const Icon(Icons.auto_awesome, color: AppColors.tertiaryFixed, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'FairMatch AI ऑटो-डिस्पॅच',
                                      style: AppTypography.labelMd.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '३.५ किमी परिघात सर्वाधिक मानांकित कारागीर थेट नियुक्त करा.',
                                      style: AppTypography.bodySm.copyWith(
                                        color: Colors.white.withValues(alpha: 0.8),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.secondary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: AppRadius.radiusMd,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(modalCtx);
                                  bookingFlowState.selectedCategory = matchedCategory;
                                  if (currentWorkers.isNotEmpty) {
                                    bookingFlowState.selectedWorker = currentWorkers.first;
                                  }
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const BookingDateTimeScreen(),
                                    ),
                                  );
                                },
                                child: const Text('थेट बुक करा', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildArtisansNearYou() {
    // 1. Filter workers according to selected area
    final List<Worker> areaWorkers;
    if (_selectedArea == 'All Areas') {
      areaWorkers = _featuredWorkers;
    } else {
      final target = _selectedArea.toLowerCase();
      final keywords = target
          .split(RegExp(r'[\s,&]+'))
          .where((s) => s.length > 2)
          .toList();

      final directMatches = _featuredWorkers.where((w) {
        final loc = w.locationTag.toLowerCase();
        final matchesTag = keywords.any((k) => loc.contains(k));
        final matchesAreas = w.serviceAreas.any((sa) =>
            keywords.any((k) => sa.toLowerCase().contains(k)));
        return matchesTag || matchesAreas;
      }).toList();

      if (directMatches.isNotEmpty) {
        areaWorkers = directMatches;
      } else {
        // Express dispatch: verified union artisans serving this ward from Cooperative Collective
        areaWorkers = _featuredWorkers.map((w) => Worker(
          id: w.id,
          name: w.name,
          categoryId: w.categoryId,
          rate: w.rate,
          rating: w.rating,
          reviewCount: w.reviewCount,
          jobsCompleted: w.jobsCompleted,
          distanceKm: 2.8,
          experience: w.experience,
          availability: 'Available Today',
          specializations: w.specializations,
          locationTag: 'Serving $_selectedArea (${w.locationTag})',
          imageUrl: w.imageUrl,
          customTag: 'Cooperative Collective Dispatch',
          bio: w.bio,
          federationId: w.federationId,
          insuranceAmount: w.insuranceAmount,
          languages: w.languages,
          serviceAreas: [...w.serviceAreas, _selectedArea],
          isUnionGold: w.isUnionGold,
          isCoopMaster: w.isCoopMaster,
        )).toList();
      }
    }

    // 2. Filter by search query if applicable
    var filteredWorkers = _searchQuery.trim().isEmpty
        ? areaWorkers
        : areaWorkers.where((w) =>
            w.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            w.specializations.any((s) => s.toLowerCase().contains(_searchQuery.toLowerCase())) ||
            w.locationTag.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();

    // 3. Quick filter
    if (_activeQuickFilter == 'instant') {
      final available = filteredWorkers.where((w) =>
        w.availability.toLowerCase().contains('available') ||
        w.availability.toLowerCase().contains('today') ||
        w.availability.toLowerCase().contains('min')
      ).toList();
      if (available.isNotEmpty) filteredWorkers = available;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 14, AppSpacing.marginMobile, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Counter
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.onTertiaryContainer,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'थेट उपलब्ध कारागीर'.toUpperCase(),
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onTertiaryContainer,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'परिसरातील सन्मानित मास्टर',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (widget.onSelectTab != null) {
                    widget.onSelectTab!(1);
                  }
                },
                child: Row(
                  children: [
                    Text(
                      'सर्व पहा',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.secondary),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Area Filter Chips Horizontal Scroll
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _serviceAreas.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final area = _serviceAreas[index];
                final isSelected = _selectedArea == area;
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: AppRadius.radiusFull,
                    onTap: () {
                      setState(() {
                        _selectedArea = area;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: AppRadius.radiusFull,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                          width: 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? Icons.location_on : Icons.location_on_outlined,
                            size: 13,
                            color: isSelected ? AppColors.tertiaryFixed : AppColors.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            area,
                            style: AppTypography.labelSm.copyWith(
                              color: isSelected ? Colors.white : AppColors.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          if (filteredWorkers.isEmpty)
            AppEmptyView(
              title: _selectedArea == 'All Areas'
                  ? 'No artisans currently available'
                  : 'No registered union artisans in $_selectedArea yet',
              subtitle:
                  'Union onboarding is actively registering cooperatives in this area. You can explore all available artisans across other clusters.',
              icon: Icons.location_off_outlined,
              actionLabel: 'View All Available Artisans',
              onActionPressed: () {
                setState(() {
                  _selectedArea = 'All Areas';
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredWorkers.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final worker = filteredWorkers[index];
                return _buildArtisanCard(worker);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildArtisanCard(Worker worker) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.radiusXl,
        onTap: () => _navigateToWorkerProfile(worker),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.spacingMd),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: AppRadius.radiusXl,
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: worker.imageUrl.isNotEmpty
                            ? Image.network(
                                worker.imageUrl,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  width: 52,
                                  height: 52,
                                  color: AppColors.surfaceContainerLow,
                                  child: Center(
                                    child: Text(
                                      worker.name.isNotEmpty ? worker.name[0] : 'W',
                                      style: AppTypography.titleMd.copyWith(color: AppColors.primaryContainer, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: 52,
                                height: 52,
                                color: AppColors.surfaceContainerLow,
                                child: Center(
                                  child: Text(
                                    worker.name.isNotEmpty ? worker.name[0] : 'W',
                                    style: AppTypography.titleMd.copyWith(color: AppColors.primaryContainer, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 17,
                          height: 17,
                          decoration: BoxDecoration(
                            color: AppColors.civicVerifiedGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.check, size: 10, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                worker.name,
                                style: AppTypography.titleMd.copyWith(
                                  color: AppColors.onSurface,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: AppColors.civicVerifiedGreen,
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          worker.specializations.isNotEmpty
                              ? worker.specializations.first
                              : 'ITI प्रमाणित तंत्रज्ञ (Certified Artisan)',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 13, color: AppColors.secondary),
                            const SizedBox(width: 2),
                            Text(
                              worker.rating.toStringAsFixed(1),
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '(${worker.jobsCompleted > 0 ? worker.jobsCompleted : worker.reviewCount} कामे)',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '• ${worker.experience}',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Badges
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: AppRadius.radiusSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fingerprint, size: 12, color: AppColors.tertiaryFixedVariant),
                        const SizedBox(width: 3),
                        Text(
                          'Aadhaar KYC',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: AppRadius.radiusSm,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, size: 12, color: AppColors.civicVerifiedGreen),
                        const SizedBox(width: 3),
                        Text(
                          'पोलीस पडताळणी / Police Verified',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Tariff & Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'शासकीय फी / Govt Rate',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '₹${worker.rate.toStringAsFixed(0)} ',
                              style: AppTypography.titleMd.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: '/ व्हिजिट',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.outlineVariant),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _navigateToWorkerProfile(worker),
                        child: Text(
                          'तपशील',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryContainer,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _navigateToWorkerProfile(worker),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'आत्ता बोलवा',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              'Book Now',
                              style: TextStyle(
                                fontSize: 9,
                                color: AppColors.primaryFixed,
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCivicAssuranceLedger() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 14, AppSpacing.marginMobile, 6),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: AppRadius.radiusXl,
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_balance,
                  size: 24,
                  color: AppColors.primaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'नागरिक सुरक्षा व पारदर्शकता नियम',
                        style: AppTypography.titleMd.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Co-operative Societies Act Governed • 100% DPI Standard',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Pillar 1
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppRadius.radiusLg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified,
                      size: 18,
                      color: AppColors.primaryContainer,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '१००% आधार व पोलीस चारित्र्य पडताळणी',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'प्रत्येक कामगाराचे थेट बायोमेट्रिक e-KYC व स्थानिक पोलीस ठाण्यातून चारित्र्य प्रमाणपत्र अनिवार्य आहे.',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Pillar 2
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppRadius.radiusLg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.price_check,
                      size: 18,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'सहकारी निबंधक निश्चित दर (Capped Tariff)',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'कोणतीही वाढीव किंमत (No Surge Pricing) नाही. ग्राहक समाधानी झाल्यावरच थेट कामगाराच्या खात्यात रक्कम वर्ग होते.',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Pillar 3
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppRadius.radiusLg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.gavel,
                      size: 18,
                      color: AppColors.tertiaryFixedVariant,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'सत्यमेव जयते: २४ तासांत तक्रार निवारण',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'कोणत्याही कामातील त्रुटीसाठी थेट ग्राहक मंच व नोडल अधिकाऱ्यांकडून २४ तासांत प्रत्यक्ष दखल व भरपाई हमी.',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Official Helpline
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'तक्रार निवारण हेल्पलाईन: १८००-१२०-४४४४',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                GestureDetector(
                  onTap: _showHelplineDialer,
                  child: Text(
                    'नियम पहा >',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnionPromiseGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 14, AppSpacing.marginMobile, 6),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.radiusXl,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('THE SHRAMSETU UNION PROMISE', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildPromiseItem(
                  Icons.account_balance,
                  'Direct Bank Pay',
                  '0% cut to worker',
                  '100% of your booking payment is disbursed directly to the verified artisan’s bank account. ShramSetu charges 0% middleman commission.',
                ),
                _buildPromiseItem(
                  Icons.price_check,
                  'Fixed Rate Card',
                  'No surge pricing',
                  'Standardized rates certified by the Pune District Labour Cooperative Society. No surge pricing during peak hours or bad weather.',
                ),
                _buildPromiseItem(
                  Icons.verified_user,
                  '₹50,000 Cover',
                  'Damage protection',
                  'All bookings on ShramSetu include up to ₹50,000 accidental damage protection covered by the Cooperative Welfare Fund.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromiseItem(IconData icon, String title, String subtitle, String description) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.radiusLg,
          onTap: () => _showPromiseDetails(title, description),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: AppRadius.radiusLg,
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primary),
                ),
                const SizedBox(height: 6),
                Text(title, style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold, fontSize: 10), textAlign: TextAlign.center),
                Text(subtitle, style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 9), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHelplineStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 8, AppSpacing.marginMobile, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadius.radiusSm,
              ),
              child: const Icon(Icons.headset_mic, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Need help booking in Marathi?', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                  Text('Toll-free Union Helpline: 1800-266-9090', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
                ],
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceContainerLow,
                foregroundColor: AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
              ),
              onPressed: _showHelplineDialer,
              child: Text('Call', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _UcTradeSpec {
  final String id;
  final String tradeKey;
  final String name;
  final String marathiName;
  final String englishSubtitle;
  final String iconName;
  final IconData iconData;
  final Color accentColor;
  final double startingRate;
  final double rating;
  final int jobsCount;
  final List<String> tags;
  final List<_UcSubService> subServices;

  const _UcTradeSpec({
    required this.id,
    required this.tradeKey,
    required this.name,
    required this.marathiName,
    required this.englishSubtitle,
    required this.iconName,
    required this.iconData,
    required this.accentColor,
    required this.startingRate,
    required this.rating,
    required this.jobsCount,
    required this.tags,
    required this.subServices,
  });
}

class _UcSubService {
  final String title;
  final String description;
  final double rate;
  final int durationMinutes;
  final String badge;

  const _UcSubService({
    required this.title,
    required this.description,
    required this.rate,
    required this.durationMinutes,
    this.badge = 'सहकारी हमी • Co-op Guarantee',
  });
}
