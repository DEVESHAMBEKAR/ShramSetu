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
                        final keywords = target.split(RegExp(r'[\s,&]+')).where((s) => s.length > 2 && s != 'pune').toList();
                        final wardMatches = filtered.where((w) {
                          final loc = w.locationTag.toLowerCase();
                          final matchesTag = keywords.any((k) => loc.contains(k));
                          final matchesAreas = w.serviceAreas.any((sa) => keywords.any((k) => sa.toLowerCase().contains(k)));
                          return matchesTag || matchesAreas;
                        }).toList();

                        if (wardMatches.isNotEmpty) {
                          filtered = wardMatches;
                        } else if (AppConfig.useMockData) {
                          // Express dispatch fallback in mock/demo mode
                          filtered = filtered.map((w) => Worker(
                            id: w.id,
                            name: w.name,
                            categoryId: w.categoryId,
                            rate: w.rate,
                            rating: w.rating,
                            reviewCount: w.reviewCount,
                            jobsCompleted: w.jobsCompleted,
                            distanceKm: 3.0,
                            experience: w.experience,
                            availability: 'Available Today',
                            specializations: w.specializations,
                            locationTag: 'Serving $_selectedWard (${w.locationTag})',
                            imageUrl: w.imageUrl,
                            customTag: 'Cooperative Union Dispatch',
                            bio: w.bio,
                            federationId: w.federationId,
                            insuranceAmount: w.insuranceAmount,
                            languages: w.languages,
                            serviceAreas: [...w.serviceAreas, _selectedWard],
                            isUnionGold: w.isUnionGold,
                            isCoopMaster: w.isCoopMaster,
                          )).toList();
                        } else {
                          filtered = [];
                        }
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
                                      : 'No union artisans found matching criteria',
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
                                      : 'Try expanding your service area or searching another trade.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodySm.copyWith(color: AppColors.outline),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 4, AppSpacing.marginMobile, 24),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (Navigator.canPop(context))
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.primary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              if (Navigator.canPop(context)) const SizedBox(width: 10),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text('ShramSetu', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusSm),
                        child: Text('UNION', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: _showAreaPickerModal,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: AppColors.secondary),
                        const SizedBox(width: 2),
                        Text(
                          _customerCity.isNotEmpty && _customerArea != _customerCity
                              ? '$_customerArea, $_customerCity'
                              : _customerArea,
                          style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const Icon(Icons.arrow_drop_down, size: 14, color: AppColors.primary),
                      ],
                    ),
                  ),
                ],
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
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryFixed,
                          borderRadius: AppRadius.radiusFull,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.translate, size: 13, color: AppColors.secondary),
                            const SizedBox(width: 4),
                            Text(
                              LocaleController.instance.isMarathi
                                  ? 'मराठी'
                                  : (LocaleController.instance.isHindi ? 'हिंदी' : 'EN'),
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.secondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
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

  void _showAreaPickerModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select Service Area', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _discoveryAreas.map((area) {
                  final isSelected = _selectedWard == area;
                  return ChoiceChip(
                    label: Text(area),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.onSurface),
                    onSelected: (selected) {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedWard = area;
                        _customerArea = area;
                      });
                      _loadWorkers();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 10, AppSpacing.marginMobile, 4),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: widget.isEmergency ? AppColors.errorContainer.withValues(alpha: 0.15) : Colors.white,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: widget.isEmergency ? AppColors.error.withValues(alpha: 0.4) : AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: widget.isEmergency ? AppColors.errorContainer : AppColors.tertiaryContainer,
                borderRadius: AppRadius.radiusSm,
              ),
              child: Icon(
                widget.isEmergency ? Icons.flash_on : Icons.verified_user,
                size: 18,
                color: widget.isEmergency ? AppColors.error : AppColors.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.isEmergency ? 'Emergency Artisan Dispatch Active' : 'Certified Cooperative Union Guild',
                        style: AppTypography.labelSm.copyWith(
                          fontWeight: FontWeight.bold,
                          color: widget.isEmergency ? AppColors.error : AppColors.onSurface,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: widget.isEmergency ? AppColors.error : AppColors.tertiaryContainer,
                          borderRadius: AppRadius.radiusSm,
                        ),
                        child: Text(
                          widget.isEmergency ? 'PRIORITY' : '100% DIRECT',
                          style: AppTypography.labelSm.copyWith(
                            color: widget.isEmergency ? Colors.white : AppColors.onTertiaryContainer,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    widget.isEmergency
                        ? 'Rapid response artisan dispatch • Verified local union specialists'
                        : 'Fixed union diagnostic rates • 0% platform deductions',
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
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.tertiaryContainer,
                            borderRadius: AppRadius.radiusFull,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, size: 11, color: AppColors.onTertiaryContainer),
                              const SizedBox(width: 2),
                              Text(
                                worker.rating > 0
                                    ? '${worker.rating.toStringAsFixed(1)} (${worker.reviewCount})'
                                    : 'New',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onTertiaryContainer,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (worker.customTag != null) ...[
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _showWhyRecommendedModal(worker),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.secondaryFixed,
                                borderRadius: AppRadius.radiusSm,
                                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.auto_awesome, size: 10, color: AppColors.secondary),
                                  const SizedBox(width: 3),
                                  Text(worker.customTag!, style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.info_outline, size: 10, color: AppColors.secondary),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: AppColors.secondaryFixed, borderRadius: AppRadius.radiusSm),
                            child: Text(
                              worker.isCoopMaster ? 'Coop Master' : (worker.isUnionGold ? 'Union Gold' : 'Union Master'),
                              style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text('${worker.distanceKm.toStringAsFixed(1)} km away', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(width: 5, height: 5, decoration: const BoxDecoration(color: AppColors.onTertiaryContainer, shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(
                          worker.availability.isNotEmpty ? worker.availability : 'Available Today',
                          style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            worker.specializations.isNotEmpty
                                ? '• ${worker.specializations.take(2).join(' • ')}'
                                : '• ITI Certified',
                            style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Fixed Standard Diag.', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
                  Text('₹${worker.rate.toStringAsFixed(0)}', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: AppColors.outlineVariant),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkerProfileScreen(worker: worker, category: _currentCategory),
                        ),
                      );
                    },
                    child: Text('Profile', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => WorkerProfileScreen(worker: worker, category: _currentCategory),
                        ),
                      );
                    },
                    icon: const Icon(Icons.arrow_forward, size: 14),
                    label: Text('Book Service', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
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
                description: 'Credentials and trade background are certified by the Pune District Labour Cooperative Federation.',
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
