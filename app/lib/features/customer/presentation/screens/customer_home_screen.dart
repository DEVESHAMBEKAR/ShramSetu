import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
import 'customer_live_tracking_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

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
        final profile = await DI.userRepo.getCustomerProfile(userId);
        if (mounted) _profile = profile;
      } catch (_) {}
    }

    try {
      final cats = await DI.customerRepo.getActiveServices();
      if (mounted) _categories = cats;
      if (cats.isNotEmpty) {
        final workers = await DI.customerRepo.getEligibleWorkers(cats.first.id);
        if (mounted) _featuredWorkers = workers;
      }
    } catch (_) {}

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

  String get _greetingName {
    if (_profile == null || _profile!.fullName.isEmpty) return 'Guest';
    return _profile!.fullName.trim().split(' ').first;
  }

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _locationDisplay {
    final addr = _profile?.defaultAddress;
    if (addr == null) return 'Pune • Tap to set address';
    final areaPart = addr.area.isNotEmpty ? addr.area : addr.city;
    if (addr.postalCode.isNotEmpty) {
      return '$areaPart, ${addr.city} • ${addr.postalCode}';
    }
    return '$areaPart, ${addr.city}';
  }

  IconData _mapCategoryIcon(String? iconName) {
    switch (iconName?.toLowerCase()) {
      case 'power':
      case 'bolt':
      case 'electrical':
        return Icons.bolt;
      case 'plumbing':
      case 'water_drop':
        return Icons.plumbing;
      case 'carpenter':
      case 'carpentry':
        return Icons.carpenter;
      case 'cleaning':
      case 'cleaning_services':
        return Icons.cleaning_services;
      case 'painting':
      case 'format_paint':
        return Icons.format_paint;
      case 'appliance':
      case 'home_repair_service':
        return Icons.home_repair_service;
      case 'gardening':
      case 'yard':
        return Icons.yard;
      case 'driver':
      case 'directions_car':
        return Icons.directions_car;
      default:
        return Icons.handyman;
    }
  }

  void _navigateToCategory(ServiceCategory category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WorkerDiscoveryScreen(initialCategory: category),
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
            Text('Select Language / भाषा निवडा', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.spacingMd),
            ListTile(
              leading: const Icon(Icons.check_circle, color: AppColors.secondary),
              title: const Text('English', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Default interface'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.circle_outlined, color: AppColors.outline),
              title: const Text('मराठी (Marathi)', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('स्थानिक भाषा'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocationPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final currentAddr = _profile?.defaultAddress;
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Service Location', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold)),
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
                                : 'Pune, Maharashtra',
                            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (currentAddr?.hasCoordinates == true)
                            Text(
                              'GPS Coordinates: ${currentAddr!.latitude!.toStringAsFixed(4)}, ${currentAddr.longitude!.toStringAsFixed(4)}',
                              style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontSize: 10),
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
                title: const Text('Use Current GPS Location', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Detect coordinates and reverse geocode address'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  if (userId == null) return;
                  
                  final result = await DI.locationService.getCurrentPosition();
                  if (result.isSuccess && result.coordinates != null) {
                    final coords = result.coordinates!;
                    final geo = await DI.locationService.reverseGeocode(coords.latitude, coords.longitude);
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
                  final userId = Supabase.instance.client.auth.currentUser?.id;
                  if (userId == null) return;

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
                    await _loadAllData();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Location updated on map.')),
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAllData,
          color: AppColors.secondary,
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
                    // 2. Location Switcher & Greeting
                    _buildLocationAndGreeting(),

                    // 3. Search Bar & Trending Chips
                    _buildSearchAndChips(),

                    // 4. Urban Company Style Trust Banner (Obsidian & Violet)
                    _buildObsidianTrustBanner(),

                    // 5. In-Progress Booking Live Tracker
                    _buildActiveJobCard(),

                    // 6. Popular Categories (4-Column Squircle Grid)
                    _buildCategoriesSection(),

                    // 7. Services Near You (Featured Artisan Cards)
                    _buildArtisansNearYou(),

                    // 8. Union Promise 3-Column Grid
                    _buildUnionPromiseGrid(),

                    // 9. Cooperative Helpline Strip
                    _buildHelplineStrip(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white.withValues(alpha: 0.95),
      surfaceTintColor: Colors.transparent,
      titleSpacing: AppSpacing.marginMobile,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Brand mark
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.radiusLg,
                  border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/images/logo.jpg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'SHRAM',
                      style: AppTypography.titleMd.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    TextSpan(
                      text: 'SETU',
                      style: AppTypography.titleMd.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Action Controls: Translate Pill & Notification Bell
          Row(
            children: [
              GestureDetector(
                onTap: _showLanguageSwitcher,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.radiusFull,
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.translate, size: 14, color: AppColors.secondary),
                      const SizedBox(width: 4),
                      Text(
                        'मराठी / EN',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.notifications_none, size: 18, color: AppColors.primary),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.surfaceContainerLow,
                backgroundImage: (_profile?.avatarUrl != null && _profile!.avatarUrl!.isNotEmpty)
                    ? NetworkImage(_profile!.avatarUrl!)
                    : null,
                child: (_profile?.avatarUrl == null || _profile!.avatarUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 18, color: AppColors.primary)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationAndGreeting() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 12, AppSpacing.marginMobile, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location Pill Box (Interactive)
          InkWell(
            onTap: _showLocationPickerSheet,
            borderRadius: AppRadius.radiusLg,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.radiusLg,
                border: Border.all(color: AppColors.outlineVariant),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppRadius.radiusSm,
                    ),
                    child: const Icon(Icons.location_on, size: 18, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'PUNE GUILD HUB',
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 9,
                                color: AppColors.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.tertiaryContainer,
                                borderRadius: AppRadius.radiusFull,
                              ),
                              child: Text(
                                'VERIFIED AREA',
                                style: AppTypography.labelSm.copyWith(
                                  fontSize: 8,
                                  color: AppColors.onTertiaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          _locationDisplay,
                          style: AppTypography.labelLg.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppRadius.radiusSm,
                    ),
                    child: Row(
                      children: [
                        Text('Change', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                        const Icon(Icons.expand_more, size: 14),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Greeting Headline
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CIVIC HOME SERVICES',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_timeGreeting, $_greetingName',
                    style: AppTypography.headlineMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.radiusLg,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: const Icon(Icons.handshake, size: 20, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndChips() {
    final trendingChips = ['Tap Leakage', 'Fan Repair', 'Deep Kitchen Clean', 'Switchboard Issue'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Input Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: AppColors.outlineVariant),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                const Icon(Icons.search, color: AppColors.outline, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search electrician, plumber, cleaning...',
                      hintStyle: AppTypography.bodySm.copyWith(color: AppColors.outline),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.mic_none, color: AppColors.primary, size: 20),
                  tooltip: 'Voice Search',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Listening in Marathi or English...')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Trending Chips Row
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: trendingChips.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Row(
                    children: [
                      const Icon(Icons.trending_up, size: 14, color: AppColors.outline),
                      const SizedBox(width: 3),
                      Text('Popular:', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                    ],
                  );
                }
                final tag = trendingChips[index - 1];
                return GestureDetector(
                  onTap: () {
                    if (_categories.isNotEmpty) {
                      _navigateToCategory(_categories.first);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.radiusFull,
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: Text(
                      tag,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildObsidianTrustBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: AppRadius.radiusXl,
          border: Border.all(color: AppColors.onPrimaryFixedVariant.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: const Icon(Icons.shield_outlined, color: AppColors.secondaryFixed, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'ShramSetu Cooperative Trust',
                            style: AppTypography.labelLg.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.tertiaryContainer,
                              borderRadius: AppRadius.radiusFull,
                            ),
                            child: Text(
                              'GOVT WAGES',
                              style: AppTypography.labelSm.copyWith(
                                fontSize: 8,
                                color: AppColors.onTertiaryContainer,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '100% Background-checked • Zero middleman commission',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.primaryFixedDim,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.tertiaryFixed,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '384 Guild Masters active right now',
                        style: AppTypography.labelSm.copyWith(color: AppColors.primaryFixed, fontSize: 11),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: AppRadius.radiusFull,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      'Escrow Protected',
                      style: AppTypography.labelSm.copyWith(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
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
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isLive ? 'ACTIVE BOOKING' : 'RECENT SERVICE',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('• ${status.toUpperCase()}', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
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
                      child: const Icon(Icons.person, size: 24, color: AppColors.primary),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
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
                      Text(serviceName, style: AppTypography.labelLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
                  icon: const Icon(Icons.call_outlined, color: AppColors.primary),
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
                    icon: const Icon(Icons.receipt_long, size: 15, color: AppColors.primary),
                    label: Text('Details', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
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
                    icon: const Icon(Icons.navigation, size: 15, color: AppColors.tertiaryFixed),
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
    final displayCategories = _categories.isNotEmpty
        ? _categories
        : const [
            ServiceCategory(id: 'c1', name: 'Electrical', iconData: 'bolt'),
            ServiceCategory(id: 'c2', name: 'Plumbing', iconData: 'plumbing'),
            ServiceCategory(id: 'c3', name: 'Carpentry', iconData: 'carpenter'),
            ServiceCategory(id: 'c4', name: 'Cleaning', iconData: 'cleaning_services'),
            ServiceCategory(id: 'c5', name: 'Painting', iconData: 'format_paint'),
            ServiceCategory(id: 'c6', name: 'Appliance', iconData: 'home_repair_service'),
            ServiceCategory(id: 'c7', name: 'Gardening', iconData: 'yard'),
            ServiceCategory(id: 'c8', name: 'Driver', iconData: 'directions_car'),
          ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 14, AppSpacing.marginMobile, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Popular Services', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFixed,
                      borderRadius: AppRadius.radiusSm,
                    ),
                    child: Text(
                      'STANDARD RATES',
                      style: AppTypography.labelSm.copyWith(
                        fontSize: 8,
                        color: AppColors.onSecondaryFixedVariant,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  if (displayCategories.isNotEmpty) _navigateToCategory(displayCategories.first);
                },
                child: Text('View all', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            itemCount: displayCategories.length > 8 ? 8 : displayCategories.length,
            itemBuilder: (context, index) {
              final cat = displayCategories[index];

              return GestureDetector(
                onTap: () => _navigateToCategory(cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(color: AppColors.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: AppRadius.radiusLg,
                        ),
                        child: Icon(_mapCategoryIcon(cat.iconData), size: 22, color: AppColors.primary),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        cat.name,
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Verified',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.outline,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildArtisansNearYou() {
    final workers = _featuredWorkers;
    final filteredWorkers = _searchQuery.trim().isEmpty
        ? workers
        : workers.where((w) =>
            w.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            w.specializations.any((s) => s.toLowerCase().contains(_searchQuery.toLowerCase()))
          ).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 14, AppSpacing.marginMobile, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Services Near You', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  Text('Govt-verified Union professionals in $_locationDisplay', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
                ],
              ),
              GestureDetector(
                onTap: () {
                  if (_categories.isNotEmpty) {
                    _navigateToCategory(_categories.first);
                  }
                },
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.radiusSm,
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Text(
                        workers.isNotEmpty ? 'See all (${workers.length})' : 'See all',
                        style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.chevron_right, size: 14),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filteredWorkers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppRadius.radiusLg,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Column(
                children: [
                  Icon(Icons.handyman_outlined, size: 36, color: AppColors.outline),
                  const SizedBox(height: 8),
                  Text(
                    'No artisans currently available',
                    style: AppTypography.labelLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a category above to find and book available specialists.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.outline),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.surfaceContainerLow,
                    backgroundImage: worker.imageUrl.isNotEmpty ? NetworkImage(worker.imageUrl) : null,
                    child: worker.imageUrl.isEmpty ? const Icon(Icons.person, size: 28, color: AppColors.primary) : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.onTertiaryContainer,
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(worker.name, style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('₹${worker.rate.toStringAsFixed(0)}', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                            Text('Standard diag.', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 9)),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.secondaryFixed,
                            borderRadius: AppRadius.radiusSm,
                          ),
                          child: Text(
                            'Union Master',
                            style: AppTypography.labelSm.copyWith(color: AppColors.onSecondaryFixedVariant, fontWeight: FontWeight.bold, fontSize: 9),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('• ${worker.specializations.isNotEmpty ? worker.specializations.first : "Certified Artisan"}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('Pune Trades & Guild Certified', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Stats Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.radiusLg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.onTertiaryContainer,
                        borderRadius: AppRadius.radiusSm,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 11, color: Colors.white),
                          const SizedBox(width: 2),
                          Text(worker.rating.toStringAsFixed(1), style: AppTypography.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('${worker.reviewCount} reviews', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
                  ],
                ),
                Text('• ${worker.experience}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10)),
                Text('• ${worker.distanceKm} km away', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onPressed: () {
                    if (_categories.isNotEmpty) {
                      _navigateToCategory(_categories.first);
                    }
                  },
                  icon: const Icon(Icons.lock_outline, size: 14, color: AppColors.tertiaryFixed),
                  label: Text('Book Service', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.outlineVariant),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: () {
                  if (_categories.isNotEmpty) {
                    _navigateToCategory(_categories.first);
                  }
                },
                child: Text('Profile', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
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
                _buildPromiseItem(Icons.account_balance, 'Direct Bank Pay', '0% cut to worker'),
                _buildPromiseItem(Icons.price_check, 'Fixed Rate Card', 'No surge pricing'),
                _buildPromiseItem(Icons.verified_user, '₹50,000 Cover', 'Damage protection'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromiseItem(IconData icon, String title, String subtitle) {
    return Expanded(
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
