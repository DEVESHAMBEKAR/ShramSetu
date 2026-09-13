import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/customer_models.dart';
import '../../../../core/config/dependency_injection.dart';
import 'worker_profile_screen.dart';

class WorkerDiscoveryScreen extends StatefulWidget {
  final ServiceCategory category;

  const WorkerDiscoveryScreen({super.key, required this.category});

  @override
  State<WorkerDiscoveryScreen> createState() => _WorkerDiscoveryScreenState();
}

class _WorkerDiscoveryScreenState extends State<WorkerDiscoveryScreen> {
  String _activeFilter = 'All';
  late Future<List<Worker>> _workersFuture;

  @override
  void initState() {
    super.initState();
    _workersFuture = DI.customerRepo.getEligibleWorkers(widget.category.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        titleSpacing: 0,
        title: Row(
          children: [
            Image.asset('assets/images/logo.jpg', height: 28, width: 28, fit: BoxFit.contain),
            const SizedBox(width: AppSpacing.spacingXs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('ShramSetu', style: AppTypography.headlineSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: AppSpacing.spacing4xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing2xs, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: AppRadius.radiusFull),
                      child: Text('UNION', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 12, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text('Pune, Maharashtra', style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.translate, color: AppColors.onSurfaceVariant), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_none, color: AppColors.onSurfaceVariant), onPressed: () {}),
        ],
      ),
      body: FutureBuilder<List<Worker>>(
        future: _workersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load workers', style: AppTypography.bodyMd));
          }

          List<Worker> workers = snapshot.data ?? [];

          // Apply local visual filtering
          if (_activeFilter == 'Available Today') {
            workers = workers.where((w) => w.availability.toLowerCase().contains('today')).toList();
          } else if (_activeFilter == 'Within 3 km') {
            workers = workers.where((w) => w.distanceKm <= 3.0).toList();
          } else if (_activeFilter == '4.5+ Rating') {
            workers = workers.where((w) => w.rating >= 4.5).toList();
          } else if (_activeFilter == 'Under ₹500') {
            workers = workers.where((w) => w.rate < 500).toList();
          } else if (_activeFilter == '5+ Yrs Experience') {
            workers = workers.where((w) => w.experience.toLowerCase().contains('yrs') || w.experience.toLowerCase().contains('exp')).toList();
          }

          return Column(
            children: [
              _buildStickyHeader(),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildAssuranceStrip(),
                    _buildMatchingHeader(workers.length),
                    if (workers.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.spacingXl),
                        child: Center(child: Text('No workers found for this filter.', style: AppTypography.bodyMd.copyWith(color: AppColors.outline))),
                      )
                    else
                      ...workers.map((worker) => _buildWorkerCard(context, worker)),
                    const SizedBox(height: AppSpacing.spacing3xl),
                  ],
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildStickyHeader() {
    return Container(
      color: AppColors.surfaceBright,
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.spacingSm, 0, AppSpacing.spacingXs),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.marginMobile),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadius.radiusXl,
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
              ),
              child: Row(
                children: [
                  const SizedBox(width: AppSpacing.spacingMd),
                  const Icon(Icons.search, size: 22, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.spacingXs),
                  Expanded(
                    child: Text(
                      'Search plumbers, leak repair...',
                      style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
                    ),
                  ),
                  const Icon(Icons.mic_none, size: 20, color: AppColors.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.spacingXs),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.spacingXs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', Icons.filter_list, _activeFilter == 'All'),
                _buildFilterChip('Available Today', Icons.bolt, _activeFilter == 'Available Today'),
                _buildFilterChip('Within 3 km', Icons.near_me, _activeFilter == 'Within 3 km'),
                _buildFilterChip('4.5+ Rating', Icons.star, _activeFilter == '4.5+ Rating'),
                _buildFilterChip('Under ₹500', Icons.currency_rupee, _activeFilter == 'Under ₹500'),
                _buildFilterChip('5+ Yrs Experience', Icons.verified_user, _activeFilter == '5+ Yrs Experience'),
                const SizedBox(width: AppSpacing.marginMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, bool isActive) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeFilter = label;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: AppSpacing.spacingXs),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd, vertical: AppSpacing.spacing2xs),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusFull,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? AppColors.secondaryFixed : AppColors.secondary),
            const SizedBox(width: AppSpacing.spacing3xs),
            Text(
              label,
              style: AppTypography.labelMd.copyWith(color: isActive ? AppColors.onPrimary : AppColors.onSurface),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssuranceStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.spacingSm, AppSpacing.marginMobile, 0),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingSm),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.radiusXl,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(color: AppColors.tertiaryContainer, shape: BoxShape.circle),
              child: const Icon(Icons.verified, size: 18, color: AppColors.tertiaryFixed),
            ),
            const SizedBox(width: AppSpacing.spacingXs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pune District ${widget.category.name} Union', style: AppTypography.labelMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                  Text('Fair daily wages guaranteed • 0% commission cut', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.info_outline, size: 20, color: AppColors.outline),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchingHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.spacingMd, AppSpacing.marginMobile, AppSpacing.spacingXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${widget.category.name} Services in Pune', style: AppTypography.headlineSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    Text('Showing active union technicians in Kothrud • $count available', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: 4),
                decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusFull),
                child: Text('Auto-Matched', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingXs),
          Row(
            children: [
              const Icon(Icons.handshake, size: 16, color: AppColors.onTertiaryContainer),
              const SizedBox(width: AppSpacing.spacing2xs),
              Text('Recommended by Pune Central Cooperative', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerCard(BuildContext context, Worker worker) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => WorkerProfileScreen(worker: worker, category: widget.category),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.spacingXs, AppSpacing.marginMobile, AppSpacing.spacingMd),
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusXl,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (worker.customTag != null || worker.isUnionGold || worker.isCoopMaster)
              Positioned(
                top: -AppSpacing.spacingMd,
                right: -AppSpacing.spacingMd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingSm, vertical: 4),
                  decoration: BoxDecoration(
                    color: worker.customTag != null ? AppColors.primary : worker.isUnionGold ? AppColors.secondaryFixed : AppColors.surfaceContainerHigh,
                    borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        worker.customTag != null ? Icons.thumb_up : worker.isUnionGold ? Icons.workspace_premium : Icons.shield,
                        size: 14,
                        color: worker.customTag != null ? AppColors.tertiaryFixed : worker.isUnionGold ? AppColors.secondary : AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        worker.customTag ?? (worker.isUnionGold ? 'Union Gold' : 'Cooperative Master'),
                        style: AppTypography.labelSm.copyWith(
                          color: worker.customTag != null ? AppColors.onPrimary : worker.isUnionGold ? AppColors.onSecondaryFixed : AppColors.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusXl),
                          child: const Icon(Icons.person, color: AppColors.outline),
                        ),
                        Positioned(
                          bottom: -4,
                          right: -4,
                          child: Container(
                            decoration: const BoxDecoration(color: AppColors.surfaceContainerLowest, shape: BoxShape.circle),
                            child: const Icon(Icons.check_circle, size: 20, color: AppColors.tertiaryFixedDim),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.spacingSm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(worker.name, style: AppTypography.titleLg.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                          Text('${worker.locationTag} • ${worker.distanceKm} km away', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star, size: 15, color: AppColors.secondary),
                              const SizedBox(width: 4),
                              Text(worker.rating.toString(), style: AppTypography.labelMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                              Text(' (${worker.reviewCount} reviews) • ', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                              Text('${worker.jobsCompleted} jobs', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusFull),
                      child: Row(
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.tertiaryContainer, shape: BoxShape.circle)),
                          const SizedBox(width: 4),
                          Text(worker.availability, style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spacingXs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusFull),
                      child: Text(worker.experience, style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.spacingXs),
                  decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Specializations:', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                      Text(worker.specializations.join(', '), style: AppTypography.bodySm.copyWith(color: AppColors.onSurface)),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingMd),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Union Fixed Rate', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('₹${worker.rate}', style: AppTypography.currencyDisplay.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                            Text('/ visit', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingSm, vertical: AppSpacing.spacingXs),
                          decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusXl),
                          child: Text('Profile', style: AppTypography.labelMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: AppSpacing.spacingXs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd, vertical: AppSpacing.spacingXs),
                          decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.radiusXl),
                          child: Row(
                            children: [
                              Text('Book Now', style: AppTypography.labelMd.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward, size: 18, color: AppColors.onPrimary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
