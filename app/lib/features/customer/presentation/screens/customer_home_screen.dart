import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
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

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId != null) {
      try {
        final profile = await DI.userRepo.getCustomerProfile(userId);
        if (mounted) _profile = profile;
      } catch (_) {}
    }

    try {
      final cats = await DI.customerRepo.getActiveServices();
      if (mounted) _categories = cats;
    } catch (_) {}

    try {
      final workers = await DI.customerRepo.getEligibleWorkers('c2');
      if (mounted) _featuredWorkers = workers;
    } catch (_) {}

    try {
      final bookings = await DI.customerRepo.getCustomerBookings();
      if (mounted && bookings.isNotEmpty) {
        _activeBooking = bookings.first;
      }
    } catch (_) {}

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
    if (addr == null) return 'Kothrud, Pune • 411038';
    return '${addr.area.isNotEmpty ? addr.area : addr.city}, ${addr.city} • ${addr.postalCode}';
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
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.radiusLg,
                ),
                child: const Icon(Icons.handyman, size: 18, color: Colors.white),
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
          // Location Pill Box
          Container(
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
          border: Border.all(color: const Color(0xFF262626)),
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
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: const Icon(Icons.verified, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Pune Trades Guild Co-op',
                            style: AppTypography.titleMd.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.secondary,
                              borderRadius: AppRadius.radiusSm,
                            ),
                            child: Text(
                              'PLUS UNION',
                              style: AppTypography.labelSm.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '100% Background-checked • Zero middleman commission',
                        style: AppTypography.bodySm.copyWith(
                          color: const Color(0xFFD1D5DB),
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
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '384 Guild Masters active right now',
                        style: AppTypography.labelSm.copyWith(color: const Color(0xFFE5E7EB), fontSize: 11),
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

    final serviceName = serviceData?['name']?.toString() ?? 'Plumbing & Pipe Repair';
    final workerName = workerUserData?['full_name']?.toString() ?? 'Rahul Patil';
    final amount = (booking['base_amount'] as num?)?.toDouble() ?? 399.0;
    final orderRef = bookingId.length >= 4 ? bookingId.substring(0, 4).toUpperCase() : '9042';

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
                      isLive ? 'PARTNER ARRIVING' : 'RECENT SERVICE',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('• In 12 mins', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
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
                    icon: const Icon(Icons.navigation, size: 15, color: Color(0xFF34D399)),
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

    final onlineCounts = [84, 62, 45, 91, 28, 37, 19, 52];

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
              final count = onlineCounts[index % onlineCounts.length];

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
                        '$count online',
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
    final workers = _featuredWorkers.isNotEmpty
        ? _featuredWorkers
        : [
            const Worker(
              id: 'w1',
              name: 'Rahul Patil',
              categoryId: 'c2',
              rate: 399,
              rating: 4.8,
              reviewCount: 126,
              jobsCompleted: 184,
              distanceKm: 1.4,
              experience: '6 yrs exp',
              availability: 'Available Today',
              specializations: ['Leak Detection', 'Bath Fittings'],
              locationTag: 'Kothrud',
              imageUrl: '',
            ),
            const Worker(
              id: 'w2',
              name: 'Suresh Gaikwad',
              categoryId: 'c1',
              rate: 299,
              rating: 4.9,
              reviewCount: 214,
              jobsCompleted: 350,
              distanceKm: 2.1,
              experience: '9 yrs exp',
              availability: 'Available Today',
              specializations: ['Master Electrician'],
              locationTag: 'Kothrud',
              imageUrl: '',
            ),
          ];

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
                  Text('Govt-verified Union professionals in Kothrud, Pune', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
                ],
              ),
              Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadius.radiusSm,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    Text('See all (42)', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    const Icon(Icons.chevron_right, size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                  icon: const Icon(Icons.lock_outline, size: 14, color: Color(0xFF34D399)),
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
