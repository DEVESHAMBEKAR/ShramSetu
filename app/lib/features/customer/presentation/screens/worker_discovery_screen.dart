import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/customer_models.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/config/app_config.dart';
import 'worker_profile_screen.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../shared/widgets/shramsetu_brand_mark.dart';

class WorkerDiscoveryScreen extends StatefulWidget {
  final ServiceCategory? initialCategory;
  final String? initialSearchQuery;
  final String? initialServiceArea;
  final bool isEmergency;

  const WorkerDiscoveryScreen({
    super.key,
    this.initialCategory,
    this.initialSearchQuery,
    this.initialServiceArea,
    this.isEmergency = false,
  });

  @override
  State<WorkerDiscoveryScreen> createState() => _WorkerDiscoveryScreenState();
}

class _WorkerDiscoveryScreenState extends State<WorkerDiscoveryScreen> {
  String _activeCategoryFilter = 'all';
  String _searchQuery = '';
  String _customerArea = 'Selected Location';
  String _customerCity = '';
  double? _customerLat;
  double? _customerLng;
  String _selectedWard = 'All Areas';
  late final TextEditingController _searchController;
  late Future<List<Worker>> _workersFuture;
  late ServiceCategory _currentCategory;
  List<ServiceCategory> _availableCategories = [];

  List<String> _discoveryAreas = [
    'All Areas',
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
    'CIDCO, Nashik',
    'Panchavati, Nashik',
    'College Road, Nashik',
    'Andheri, Mumbai',
    'Bandra, Mumbai',
    'Dadar, Mumbai',
    'CIDCO, Chhatrapati Sambhajinagar',
    'Dharampeth, Nagpur',
  ];

  @override
  void initState() {
    super.initState();
    _searchQuery = widget.initialSearchQuery ?? '';
    _searchController = TextEditingController(text: _searchQuery);
    _currentCategory = widget.initialCategory ??
        const ServiceCategory(id: 'c2', name: 'Plumbing', iconData: 'plumbing');
    _loadWorkers();
    _loadCategories();
    _loadCustomerArea();
  }

  Future<void> _loadCustomerArea() async {
    try {
      final user = await DI.authRepo.getCurrentUser();
      final userId = user?.id ?? (AppConfig.useMockData ? 'mock_customer_01' : null);
      if (userId != null) {
        final profile = await DI.userRepo.getCustomerProfile(userId);
        final addr = profile?.defaultAddress;
        if (addr != null && mounted) {
          setState(() {
            _customerLat = addr.latitude;
            _customerLng = addr.longitude;
            _customerArea = addr.area.isNotEmpty ? addr.area : (addr.city.isNotEmpty ? addr.city : 'Selected Location');
            _customerCity = addr.city;
            if (_customerArea.isNotEmpty && !_discoveryAreas.contains(_customerArea)) {
              _discoveryAreas.insert(1, _customerArea);
            }
            if (_customerCity.isNotEmpty && !_discoveryAreas.contains(_customerCity)) {
              _discoveryAreas.insert(2, _customerCity);
            }
            _selectedWard = _customerArea;
          });
          _loadWorkers();
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await DI.customerRepo.getActiveServices();
      if (mounted && cats.isNotEmpty) {
        setState(() {
          _availableCategories = cats;
        });
      }
    } catch (_) {}
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

  void _loadWorkers() {
    setState(() {
      _workersFuture = DI.customerRepo
          .getEligibleWorkers(
            _currentCategory.id,
            customerLat: _customerLat,
            customerLng: _customerLng,
            serviceArea: _selectedWard != 'All Areas' ? _selectedWard : null,
          )
          .then((workers) {
        if (mounted) {
          final set = Set<String>.from(_discoveryAreas);
          for (final w in workers) {
            for (final a in w.serviceAreas) {
              if (a.isNotEmpty && a != 'All Areas') set.add(a);
            }
          }
          setState(() {
            _discoveryAreas = set.toList();
          });
        }
        return workers;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              children: [
                // 1. Urban Company Header Strip
                _buildHeader(),

                // 2. Search & Trade Chips Section
                _buildSearchAndFilters(),

                // 3. Certified Union Guild Banner
                _buildGuildBanner(),

                // 4. Specialist List Header
                _buildListHeader(),

                // 5. Workers List View
                Expanded(
                  child: FutureBuilder<List<Worker>>(
                    future: _workersFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
                      }
                      if (snapshot.hasError) {
                        return Center(child: Text('Error: ${snapshot.error}', style: AppTypography.bodyMd));
                      }

                      final allWorkers = snapshot.data ?? [];
                      List<Worker> filtered = allWorkers.where((w) {
                        if (_searchQuery.isNotEmpty) {
                          final q = _searchQuery.toLowerCase();
                          final matches = w.name.toLowerCase().contains(q) ||
                              w.specializations.any((s) => s.toLowerCase().contains(q)) ||
                              w.locationTag.toLowerCase().contains(q);
                          if (!matches) return false;
                        }
                        if (_activeCategoryFilter == 'top_rated' && w.rating < 4.8) {
                          return false;
                        }
                        return true;
                      }).toList();

                      // If specific ward filter is active
                      if (_selectedWard != 'All Areas') {
                        final target = _selectedWard.toLowerCase();
                        final keywords = target.split(RegExp(r'[\s,&]+')).where((s) => s.length > 2).toList();
                        final wardMatches = filtered.where((w) {
                          final loc = w.locationTag.toLowerCase();
                          final matchesTag = keywords.any((k) => loc.contains(k));
                          final matchesAreas = w.serviceAreas.any((sa) => keywords.any((k) => sa.toLowerCase().contains(k)));
                          return matchesTag || matchesAreas;
                        }).toList();

                        filtered = wardMatches;
                      }

                      if (filtered.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.isEmergency ? Icons.warning_amber_rounded : Icons.search_off,
                                  size: 48,
                                  color: widget.isEmergency ? AppColors.error : AppColors.outline,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  widget.isEmergency
                                      ? 'No emergency artisans available in your area right now'
                                      : 'No registered ${_currentCategory.name} artisans found matching criteria',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.titleMd.copyWith(
                                    color: widget.isEmergency ? AppColors.error : AppColors.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  widget.isEmergency
                                      ? 'All nearby emergency specialists are currently engaged. Try scheduling a standard service or contact our union helpline: 1800-266-9090.'
                                      : 'Try selecting "All Areas" or searching another trade (e.g., Electrician, Carpentry).',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodySm.copyWith(color: AppColors.outline),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 4, AppSpacing.marginMobile, 12),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final worker = filtered[index];
                          return _buildWorkerCard(worker);
                        },
                      );
                    },
                  ),
                ),

                // 6. Escrow Guarantee Footer
                _buildEscrowGuaranteeCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const TricolorStripe(height: 3),
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.6))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (Navigator.canPop(context)) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.primary),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ShramSetuBrandMark(
                    size: 32,
                    showText: true,
                    subtitle: '$_selectedWard क्लस्टर • DPI',
                  ),
                ],
              ),
              Row(
                children: [
                  ListenableBuilder(
                    listenable: LocaleController.instance,
                    builder: (context, _) {
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: AppRadius.radiusFull,
                          onTap: () {
                            LocaleController.instance.toggleNextLanguage();
                          },
                          child: Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: AppRadius.radiusFull,
                              border: Border.all(color: AppColors.outlineVariant),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.translate, size: 14, color: AppColors.secondary),
                                const SizedBox(width: 4),
                                Text(
                                  'अ/A',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  LocaleController.instance.isMarathi
                                      ? 'मराठी'
                                      : (LocaleController.instance.isHindi ? 'हिंदी' : 'EN'),
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 6),
                  Stack(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
                        ),
                        child: const Icon(Icons.notifications_none, size: 18, color: AppColors.onSurfaceVariant),
                      ),
                      Positioned(
                        top: 7,
                        right: 8,
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
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 10, AppSpacing.marginMobile, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        children: [
          // Search Input
          Container(
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Icon(Icons.search, size: 18, color: AppColors.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search verified union artisans...',
                      hintStyle: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: AppColors.outline),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                else
                  const Icon(Icons.mic_none, size: 18, color: AppColors.outline),
                const SizedBox(width: 10),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Trade Category Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTradeChip('all', 'All (${_currentCategory.name})', Icons.tune, onSelected: () {
                  setState(() => _activeCategoryFilter = 'all');
                }),
                const SizedBox(width: 6),
                _buildTradeChip('top_rated', 'Top Rated (4.8+)', Icons.star, onSelected: () {
                  setState(() => _activeCategoryFilter = 'top_rated');
                }),
                const SizedBox(width: 6),
                ..._availableCategories.map((cat) {
                  final isCurrent = _currentCategory.id == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _buildTradeChip(
                      cat.id,
                      cat.name,
                      _mapCategoryIcon(cat.iconData),
                      forceSelected: isCurrent && _activeCategoryFilter != 'top_rated',
                      onSelected: () {
                        setState(() {
                          _activeCategoryFilter = cat.id;
                          _currentCategory = cat;
                        });
                        _loadWorkers();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Pune Ward Area Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _discoveryAreas.map((area) {
                final isSelected = _selectedWard == area;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedWard = area;
                      });
                    },
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        borderRadius: AppRadius.radiusFull,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? Icons.location_on : Icons.location_on_outlined,
                            size: 11,
                            color: isSelected ? Colors.white : AppColors.outline,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            area,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.onSurface,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTradeChip(
    String key,
    String label,
    IconData icon, {
    bool? forceSelected,
    VoidCallback? onSelected,
  }) {
    final isSelected = forceSelected ?? (_activeCategoryFilter == key);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onSelected ?? () => setState(() => _activeCategoryFilter = key),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: AppRadius.radiusFull,
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.outlineVariant),
          boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 2)] : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : AppColors.onSurfaceVariant),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuildBanner() {
    if (widget.isEmergency) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 8, AppSpacing.marginMobile, 4),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.errorContainer.withValues(alpha: 0.2),
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: AppRadius.radiusSm,
                ),
                child: const Icon(Icons.flash_on, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'तातडीची सेवा • Emergency Artisan Dispatch',
                      style: AppTypography.labelSm.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    Text(
                      'Rapid response artisan dispatch • Verified local specialists',
                      style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 8, AppSpacing.marginMobile, 4),
      child: Column(
        children: [
          // Live Directory Context Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: AppRadius.radiusXl,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryContainer.withValues(alpha: 0.2),
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        borderRadius: AppRadius.radiusFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LIVE DIRECTORY',
                            style: AppTypography.labelSm.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'DPI-NIC Registry v4.2',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onPrimaryContainer,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_selectedWard != 'All Areas' ? '$_selectedWard • ' : ''}${_currentCategory.name} कारागीर निर्देशिका',
                  style: AppTypography.headlineSm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Certified Trade Registry • Gazette Standard Pricing',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onPrimaryContainer,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hub, size: 14, color: AppColors.secondaryFixed),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$_selectedWard Cluster • Radius 3.5 km • Verified Artisans Active',
                          style: AppTypography.labelSm.copyWith(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Fair Allocation Active Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.tertiaryContainer,
              borderRadius: AppRadius.radiusLg,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.civicVerifiedGreen.withValues(alpha: 0.2),
                    borderRadius: AppRadius.radiusSm,
                  ),
                  child: const Icon(Icons.balance, size: 16, color: AppColors.tertiaryFixed),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Fair Allocation Active',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.tertiaryFixed,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '• जन-समता नियम',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.civicVerifiedGreen,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Artisans capped at max 4 jobs/day to guarantee equal civic distribution and strict punctual service.',
                        style: AppTypography.bodySm.copyWith(
                          color: AppColors.surfaceContainerHighest,
                          fontSize: 10,
                          height: 1.25,
                        ),
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
  }

  Widget _buildListHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 10, AppSpacing.marginMobile, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isEmergency
                    ? 'Emergency ${_currentCategory.name} Specialists'
                    : '${_currentCategory.name} Specialists in $_customerArea',
                style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              Text(
                widget.isEmergency
                    ? 'Available for immediate dispatch to your location'
                    : 'Govt-verified Union professionals in your service area',
                style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(color: AppColors.secondaryFixed, borderRadius: AppRadius.radiusSm),
            child: Row(
              children: [
                const Icon(Icons.bolt, size: 12, color: AppColors.secondary),
                const SizedBox(width: 2),
                Text('INSTANT', style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(Worker worker) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.radiusXl,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WorkerProfileScreen(worker: worker, category: _currentCategory),
            ),
          );
        },
        child: Container(
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
              // Civic Accent Stripe
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: worker.isCoopMaster
                      ? AppColors.secondaryContainer
                      : (worker.isUnionGold ? AppColors.primaryContainer : AppColors.civicVerifiedGreen),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.spacingMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar with verified badge
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: worker.imageUrl.isNotEmpty
                                  ? Image.network(
                                      worker.imageUrl,
                                      width: 58,
                                      height: 58,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 58,
                                        height: 58,
                                        color: AppColors.surfaceContainerLow,
                                        child: Center(
                                          child: Text(
                                            worker.name.isNotEmpty ? worker.name[0] : 'W',
                                            style: AppTypography.titleMd.copyWith(
                                              color: AppColors.primaryContainer,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 58,
                                      height: 58,
                                      color: AppColors.surfaceContainerLow,
                                      child: Center(
                                        child: Text(
                                          worker.name.isNotEmpty ? worker.name[0] : 'W',
                                          style: AppTypography.titleMd.copyWith(
                                            color: AppColors.primaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: AppColors.civicVerifiedGreen,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.check, size: 11, color: Colors.white),
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
                                  Flexible(
                                    child: Text(
                                      worker.name,
                                      style: AppTypography.titleMd.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => _showWhyRecommendedModal(worker),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.tertiaryContainer.withValues(alpha: 0.08),
                                        borderRadius: AppRadius.radiusSm,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 5,
                                            height: 5,
                                            decoration: const BoxDecoration(
                                              color: AppColors.civicVerifiedGreen,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            worker.availability.isNotEmpty ? worker.availability : 'स्लॉट उपलब्ध',
                                            style: AppTypography.labelSm.copyWith(
                                              color: AppColors.civicVerifiedGreen,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 9.5,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          const Icon(Icons.info_outline, size: 11, color: AppColors.civicVerifiedGreen),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                worker.specializations.isNotEmpty
                                    ? worker.specializations.first
                                    : 'ITI Grade-A Certified Artisan',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
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
                                    '(${worker.jobsCompleted > 0 ? worker.jobsCompleted : worker.reviewCount} audits)',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.near_me, size: 11, color: AppColors.surfaceTint),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${worker.distanceKm.toStringAsFixed(1)} km away',
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
                    const SizedBox(height: 8),

                    // Official Trust Badges Grid
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: AppRadius.radiusSm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.verified_user, size: 11, color: AppColors.civicVerifiedGreen),
                              const SizedBox(width: 3),
                              Text(
                                'DigiLocker Aadhaar eKYC',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: AppRadius.radiusSm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield, size: 11, color: AppColors.surfaceTint),
                              const SizedBox(width: 3),
                              Text(
                                'Police NOC Cleared',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: AppRadius.radiusSm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium, size: 11, color: AppColors.secondary),
                              const SizedBox(width: 3),
                              Text(
                                'ITI NTC #${worker.federationId != null && worker.federationId!.isNotEmpty ? worker.federationId : 'MH-PU-8821'}',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Gazette Tariff Rate Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'शासकीय तपासणी शुल्क (Diagnostic Tariff)',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                  fontSize: 9.5,
                                ),
                              ),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '₹${worker.rate.toStringAsFixed(0)} ',
                                      style: AppTypography.titleMd.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '/ प्रथम भेट + अहवाल',
                                      style: AppTypography.labelSm.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: AppRadius.radiusSm,
                              border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              '₹0 Platform Cut',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.civicVerifiedGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 9.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.outlineVariant),
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WorkerProfileScreen(worker: worker, category: _currentCategory),
                                ),
                              );
                            },
                            icon: const Icon(Icons.badge, size: 14, color: AppColors.primary),
                            label: Text(
                              'तपशील / Dossier',
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WorkerProfileScreen(worker: worker, category: _currentCategory),
                                ),
                              );
                            },
                            icon: const Icon(Icons.touch_app, size: 14, color: Colors.white),
                            label: Text(
                              'तारीफ दर निवडा (Book)',
                              style: AppTypography.labelSm.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEscrowGuaranteeCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.secondaryFixed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield, color: AppColors.secondary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ShramSetu Escrow Guarantee',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Fee released to worker only upon your job sign-off',
                  style: TextStyle(fontSize: 11, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.tertiaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock, size: 12, color: AppColors.onTertiaryContainer),
                const SizedBox(width: 4),
                Text(
                  'Protected',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.onTertiaryContainer),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showWhyRecommendedModal(Worker worker) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryFixed,
                          borderRadius: AppRadius.radiusMd,
                        ),
                        child: const Icon(Icons.auto_awesome, size: 18, color: AppColors.secondary),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Why We Recommended This Artisan', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          Text('ShramSetu FairMatch • Explainable Matching', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppColors.outline),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Rationale Cards / Items
              _buildReasonItem(
                icon: Icons.verified_user,
                iconColor: AppColors.onTertiaryContainer,
                bgColor: AppColors.tertiaryContainer,
                title: 'Verified Trade Certification',
                description: 'Credentials and trade background are certified by the worker\'s assigned Cooperative Federation.',
              ),
              const SizedBox(height: 10),
              _buildReasonItem(
                icon: Icons.location_on_outlined,
                iconColor: AppColors.primary,
                bgColor: AppColors.surfaceContainerLow,
                title: 'Immediate Service Proximity',
                description: 'Located approximately ${worker.distanceKm.toStringAsFixed(1)} km away to ensure punctual diagnostic arrival.',
              ),
              const SizedBox(height: 10),
              _buildReasonItem(
                icon: Icons.star_outline,
                iconColor: AppColors.secondary,
                bgColor: AppColors.secondaryFixed,
                title: 'High Customer Satisfaction',
                description: '${worker.rating > 0 ? worker.rating.toStringAsFixed(1) : "Top"} community rating with proven service quality.',
              ),
              const SizedBox(height: 10),
              _buildReasonItem(
                icon: Icons.balance_outlined,
                iconColor: AppColors.primary,
                bgColor: AppColors.surfaceContainerLow,
                title: 'Fair Opportunity Distribution',
                description: 'Work is balanced equitably across member artisans so you get a dedicated, unburdened specialist.',
              ),
              const SizedBox(height: 20),

              // Model Version & Cooperative Promise Tag
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: AppRadius.radiusLg,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '100% Direct Cooperative • Model fairmatch_v1 • Zero Private Data Leaks',
                        style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Got it button
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
                  child: const Text('Got it', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReasonItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppRadius.radiusMd,
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 2),
              Text(description, style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}
