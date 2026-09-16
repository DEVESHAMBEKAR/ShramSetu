import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/customer_models.dart';
import '../../../../core/config/dependency_injection.dart';
import 'worker_profile_screen.dart';

class WorkerDiscoveryScreen extends StatefulWidget {
  final ServiceCategory? initialCategory;

  const WorkerDiscoveryScreen({super.key, this.initialCategory});

  @override
  State<WorkerDiscoveryScreen> createState() => _WorkerDiscoveryScreenState();
}

class _WorkerDiscoveryScreenState extends State<WorkerDiscoveryScreen> {
  String _activeCategoryFilter = 'all';
  String _searchQuery = '';
  late Future<List<Worker>> _workersFuture;
  late ServiceCategory _currentCategory;
  List<ServiceCategory> _availableCategories = [];

  @override
  void initState() {
    super.initState();
    _currentCategory = widget.initialCategory ??
        const ServiceCategory(id: 'c2', name: 'Plumbing', iconData: 'plumbing');
    _loadWorkers();
    _loadCategories();
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
      _workersFuture = DI.customerRepo.getEligibleWorkers(_currentCategory.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
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
                  final filtered = allWorkers.where((w) {
                    if (_searchQuery.isNotEmpty && !w.name.toLowerCase().contains(_searchQuery.toLowerCase())) {
                      return false;
                    }
                    if (_activeCategoryFilter == 'top_rated' && w.rating < 4.8) {
                      return false;
                    }
                    return true;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.search_off, size: 48, color: AppColors.outline),
                          const SizedBox(height: 8),
                          Text('No union artisans found matching criteria', style: AppTypography.bodyMd.copyWith(color: AppColors.outline)),
                        ],
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
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: AppColors.secondary),
                      const SizedBox(width: 2),
                      Text('Kothrud, Pune', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
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
                    Text('मराठी / EN', style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
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
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'Search verified union artisans...',
                      hintStyle: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
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
          color: Colors.white,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.tertiaryContainer,
                borderRadius: AppRadius.radiusSm,
              ),
              child: const Icon(Icons.verified_user, size: 18, color: AppColors.onTertiaryContainer),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Pune Certified Union Guild', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: AppColors.tertiaryContainer, borderRadius: AppRadius.radiusSm),
                        child: Text('100% DIRECT', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  Text('Fixed union diagnostic rates • 0% platform deductions', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
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
              Text('${_currentCategory.name} Specialists in Pune', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text('Govt-verified Union professionals near Kothrud', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
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
    return Container(
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
