import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/models/review_models.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../data/models/customer_models.dart';
import '../../../booking/data/models/booking_models.dart';
import '../../../booking/presentation/screens/booking_date_time_screen.dart';

class WorkerProfileScreen extends StatefulWidget {
  final Worker worker;
  final ServiceCategory category;

  const WorkerProfileScreen({super.key, required this.worker, required this.category});

  @override
  State<WorkerProfileScreen> createState() => _WorkerProfileScreenState();
}

class _WorkerProfileScreenState extends State<WorkerProfileScreen> {
  int _activeTabIndex = 0;
  late Future<List<ReviewModel>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = DI.reviewRepo.getWorkerReviews(widget.worker.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildFederationBanner(),
                    _buildHeaderCard(),
                    _buildTabs(),
                    _buildTabContent(),
                    const SizedBox(height: 100), // padding for bottom bar
                  ],
                ),
              ),
            ],
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.surface.withValues(alpha: 0.9),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      titleSpacing: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Image.asset('assets/images/logo.jpg', height: 28, width: 28, fit: BoxFit.contain),
          const SizedBox(width: AppSpacing.spacingXs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ShramSetu', style: AppTypography.headlineSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              Text('Cooperative Verified Protection', style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(Icons.help_outline, color: AppColors.onSurfaceVariant), onPressed: () {}),
        const SizedBox(width: AppSpacing.spacingXs),
      ],
    );
  }

  Widget _buildFederationBanner() {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.spacingXs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: AppColors.tertiaryFixed, size: 16),
              const SizedBox(width: AppSpacing.spacing2xs),
              Text(
                'Pune District Labour Cooperative Member #4092'.toUpperCase(),
                style: AppTypography.labelSm.copyWith(color: AppColors.surfaceBright, letterSpacing: 1.2, fontSize: 9),
              ),
            ],
          ),
          Text(
            'Standard Rates',
            style: AppTypography.labelSm.copyWith(color: AppColors.secondaryFixed, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.marginMobile),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusXl,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusXl),
                      child: const Icon(Icons.person, size: 40, color: AppColors.outline),
                    ),
                    Positioned(
                      bottom: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: AppColors.tertiaryContainer, shape: BoxShape.circle),
                        child: const Icon(Icons.check_circle, size: 16, color: AppColors.onTertiaryContainer),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(widget.worker.name, style: AppTypography.headlineSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                          const SizedBox(width: AppSpacing.spacing2xs),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing2xs, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.1), borderRadius: AppRadius.radiusSm),
                            child: Row(
                              children: [
                                const Icon(Icons.verified, size: 12, color: AppColors.secondary),
                                const SizedBox(width: 4),
                                Text('Govt ITI', style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text('Master Plumber & Pipe Specialist', style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                      const SizedBox(height: AppSpacing.spacing2xs),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing2xs, vertical: 2),
                            decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusSm),
                            child: Row(
                              children: [
                                const Icon(Icons.star, size: 14, color: AppColors.starRating),
                                const SizedBox(width: 2),
                                Text(
                                  widget.worker.rating > 0 ? widget.worker.rating.toStringAsFixed(1) : 'New',
                                  style: AppTypography.labelSm.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  widget.worker.reviewCount > 0 ? ' (${widget.worker.reviewCount})' : '',
                                  style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.spacing2xs),
                          Text('• ${widget.worker.jobsCompleted} Jobs', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                          const SizedBox(width: AppSpacing.spacing2xs),
                          Text('• ${widget.worker.experience}', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            Container(
              padding: const EdgeInsets.all(AppSpacing.spacingXs),
              decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.security, size: 16, color: AppColors.onTertiaryContainer),
                      const SizedBox(width: AppSpacing.spacing2xs),
                      Text('Police Verified Background & Identity Cleared', style: AppTypography.labelSm.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.spacing2xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.thumb_up, size: 14, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Text('Top Rated in ${widget.worker.serviceAreas.isNotEmpty ? widget.worker.serviceAreas.first : "area"}', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.tertiaryFixed.withValues(alpha: 0.3), borderRadius: AppRadius.radiusSm),
                        child: Row(
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.onTertiaryContainer, shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text('Today from 10:30 AM', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spacingSm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.spacingXs),
              decoration: BoxDecoration(color: AppColors.surfaceBright, borderRadius: AppRadius.radiusLg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Standard Visit & Diagnosis', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('₹${widget.worker.rate}', style: AppTypography.currencyDisplay.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
                      Text('/ visit', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = ['About', 'Services & Pricing', 'Reviews', 'Tools & Certs'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isActive = index == _activeTabIndex;
          return GestureDetector(
            onTap: () => setState(() => _activeTabIndex = index),
            child: Container(
              margin: const EdgeInsets.only(right: AppSpacing.spacing2xs),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd, vertical: AppSpacing.spacingXs),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : AppColors.surfaceContainerLowest,
                borderRadius: AppRadius.radiusFull,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)],
              ),
              child: Text(
                tabs[index],
                style: AppTypography.labelMd.copyWith(
                  color: isActive ? AppColors.onPrimary : AppColors.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTabContent() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.marginMobile),
      child: Builder(
        builder: (context) {
          switch (_activeTabIndex) {
            case 0: return _buildAboutTab();
            case 1: return _buildServicesTab();
            case 2: return _buildReviewsTab();
            case 3: return _buildToolsTab();
            default: return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _buildAboutTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.spacingMd),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.badge, size: 18, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.spacing2xs),
                  Text('Federation Bio', style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: AppSpacing.spacingXs),
              Text(
                widget.worker.bio ?? 'Professional worker registered with ShramSetu.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.spacingSm),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.spacingXs),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Federation ID', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                          Text(widget.worker.federationId ?? 'N/A', style: AppTypography.labelMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.spacingXs),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.spacingXs),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Insurance Bonded', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                          Text(widget.worker.insuranceAmount ?? 'N/A', style: AppTypography.labelMd.copyWith(color: AppColors.onTertiaryContainer, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        Container(
          padding: const EdgeInsets.all(AppSpacing.spacingMd),
          decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pin_drop, size: 18, color: AppColors.secondary),
                  const SizedBox(width: AppSpacing.spacing2xs),
                  Text('Servicing Pune Localities', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: AppSpacing.spacingSm),
              Wrap(
                spacing: AppSpacing.spacing2xs,
                runSpacing: AppSpacing.spacing2xs,
                children: widget.worker.serviceAreas.map((area) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingSm, vertical: AppSpacing.spacing3xs),
                  decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusFull),
                  child: Text(area, style: AppTypography.labelMd.copyWith(color: AppColors.onSurface)),
                )).toList(),
              ),
              const SizedBox(height: AppSpacing.spacingSm),
              Row(
                children: [
                  Text('Languages Known:', style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                  const SizedBox(width: AppSpacing.spacingXs),
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.spacing2xs,
                      children: widget.worker.languages.map((lang) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing2xs, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: AppRadius.radiusSm),
                        child: Text(lang, style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      )).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServicesTab() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Standard Cooperative Rates', style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            Text('Zero Surge Pricing', style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        _buildServiceItem('Tap & Shower Repair / Leakage', 'Includes diagnosis & 1 hour skilled labor', 399, Icons.water_drop),
        _buildServiceItem('Water Heater / Geyser', 'Inlet/outlet coupling & safety valve check', 650, Icons.heat_pump),
        _buildServiceItem('Blocked Drain Cleaning', 'Mechanized snake rod clearing', 499, Icons.cleaning_services),
      ],
    );
  }

  Widget _buildServiceItem(String title, String subtitle, int price, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusLg),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.spacingXs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                Text(subtitle, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('₹$price', style: AppTypography.currencyDisplay.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 18)),
              Text('Fixed Rate', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    return FutureBuilder<List<ReviewModel>>(
      future: _reviewsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final reviews = snapshot.data ?? [];
        if (reviews.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(AppSpacing.spacingLg),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppRadius.radiusXl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.rate_review_outlined, size: 40, color: AppColors.outline),
                const SizedBox(height: 8),
                Text('No reviews yet', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  'Verified customer reviews will appear here after completed bookings.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          );
        }

        return Column(
          children: reviews.map((r) => _buildReviewItem(
            r.customerName,
            widget.worker.locationTag,
            r.rating.toDouble(),
            r.comment ?? 'Great professional service.',
            r.relativeDateString,
          )).toList(),
        );
      },
    );
  }

  Widget _buildReviewItem(String name, String location, double rating, String text, String date) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(color: AppColors.secondaryFixed, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(name.substring(0, 2).toUpperCase(), style: AppTypography.labelMd.copyWith(color: AppColors.onSecondaryFixed, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: AppSpacing.spacing2xs),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTypography.titleMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                      Text(location, style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              Row(
                children: List.generate(5, (index) => Icon(
                  index < rating ? Icons.star : Icons.star_border,
                  size: 16, color: AppColors.starRating,
                )),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacing2xs),
          Text('"$text"', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant, fontStyle: FontStyle.italic)),
          const SizedBox(height: AppSpacing.spacing2xs),
          Text('Verified Booking • $date', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildToolsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Federation Certified Toolset', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
        const SizedBox(height: AppSpacing.spacingSm),
        Row(
          children: [
            Expanded(child: _buildToolItem('Rigid Pipe Die', 'Accurate threading', Icons.build)),
            const SizedBox(width: AppSpacing.spacingXs),
            Expanded(child: _buildToolItem('Pressure Meter', 'Leak detection', Icons.search)),
          ],
        ),
        const SizedBox(height: AppSpacing.spacingMd),
        Container(
          padding: const EdgeInsets.all(AppSpacing.spacingSm),
          decoration: BoxDecoration(color: AppColors.tertiaryContainer, borderRadius: AppRadius.radiusLg),
          child: Row(
            children: [
              const Icon(Icons.workspace_premium, color: AppColors.onTertiaryContainer, size: 24),
              const SizedBox(width: AppSpacing.spacingXs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Govt ITI Plumbing Trade (2018)', style: AppTypography.labelMd.copyWith(color: AppColors.onTertiaryContainer, fontWeight: FontWeight.bold)),
                    Text('Maharashtra State Board of Vocational Education', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer.withValues(alpha: 0.8))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolItem(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingXs),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.spacing2xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.labelMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                Text(subtitle, style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        color: AppColors.surfaceContainerLowest,
        padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.spacingXs, AppSpacing.marginMobile, 32),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Standard Visit Fee', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('₹${widget.worker.rate}', style: AppTypography.currencyDisplay.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 4),
                    Text('fixed', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.spacingMd),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  bookingFlowState.selectedCategory = widget.category;
                  bookingFlowState.selectedWorker = widget.worker;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BookingDateTimeScreen(),
                    ),
                  );
                },
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.radiusXl,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Book ${widget.worker.name.split(" ")[0]}', style: AppTypography.labelLg.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold)),
                      const SizedBox(width: AppSpacing.spacing2xs),
                      const Icon(Icons.arrow_forward, color: AppColors.onPrimary, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
