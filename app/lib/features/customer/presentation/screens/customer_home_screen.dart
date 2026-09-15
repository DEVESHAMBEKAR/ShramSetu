import '../../../../core/config/dependency_injection.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/customer_models.dart';
import '../../data/models/customer_profile.dart';

import 'worker_discovery_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  CustomerProfile? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final profile = await DI.userRepo.getCustomerProfile(userId);
    if (mounted) {
      setState(() {
        _profile = profile;
      });
    }
  }

  String get _greetingName {
    if (_profile == null || _profile!.fullName.isEmpty) return '';
    // Use first name only for a friendly greeting
    return ', ${_profile!.fullName.trim().split(' ').first}';
  }

  String get _timeGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _locationDisplay {
    final addr = _profile?.defaultAddress;
    if (addr == null) return 'Add your location';
    return addr.displayString;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGreetingCard(),
                _buildSearchInput(),
                _buildCooperativeBanner(),
                _buildPopularServices(context),
                _buildRecentBookingTracker(),
                _buildServicesNearYou(context),
                _buildReassuranceFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: AppColors.surface.withValues(alpha: 0.9),
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      titleSpacing: AppSpacing.marginMobile,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Image.asset('assets/images/logo.jpg', height: 32, width: 32, fit: BoxFit.contain),
              const SizedBox(width: AppSpacing.spacingXs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'ShramSetu',
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.spacing4xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing2xs, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: AppRadius.radiusFull,
                        ),
                        child: Text(
                          'UNION',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 14, color: AppColors.secondary),
                      const SizedBox(width: AppSpacing.spacing4xs),
                      Text(
                        'Pune, Maharashtra',
                        style: AppTypography.labelMd.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      const Icon(Icons.expand_more, size: 16, color: AppColors.onSurfaceVariant),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: AppSpacing.spacing3xs),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: AppRadius.radiusXl,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.translate, size: 16, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: AppSpacing.spacing3xs),
                    Text('मराठी / EN', style: AppTypography.labelMd.copyWith(color: AppColors.onSurface)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.spacingXs),
              Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.notifications_none, size: 24, color: AppColors.onSurfaceVariant),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpacing.spacingXs),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_outline, size: 18, color: AppColors.onPrimary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.spacingSm, AppSpacing.marginMobile, AppSpacing.spacingXs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusXl,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NAMASTE & WELCOME',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      '$_timeGreeting$_greetingName',
                      style: AppTypography.headlineLgMobile.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryFixed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.handshake_outlined, size: 26, color: AppColors.onPrimaryFixed),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingXs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingSm, vertical: AppSpacing.spacingXs),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadius.radiusLg,
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: AppColors.secondary),
                  const SizedBox(width: AppSpacing.spacing3xs),
                  Expanded(
                    child: Text(
                      _locationDisplay,
                      style: AppTypography.labelMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 18, color: AppColors.outline),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.spacingXs),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusXl,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 22, color: AppColors.outline),
            const SizedBox(width: AppSpacing.spacingXs),
            Expanded(
              child: Text(
                'What service do you need today?',
                style: AppTypography.bodyMd.copyWith(color: AppColors.outline),
              ),
            ),
            const Icon(Icons.mic_none, size: 22, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildCooperativeBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.spacingXs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingSm),
        decoration: BoxDecoration(
          color: AppColors.primaryFixed.withValues(alpha: 0.4),
          borderRadius: AppRadius.radiusXl,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 2),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_outlined, size: 20, color: AppColors.onPrimary),
            ),
            const SizedBox(width: AppSpacing.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Cooperative Backed', style: AppTypography.labelMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing3xs),
                        child: Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.4), shape: BoxShape.circle)),
                      ),
                      Text('Govt. ID Verified', style: AppTypography.labelMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text(
                    'Fair fixed trade wages, zero hidden commission',
                    style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'power': return Icons.power;
      case 'plumbing': return Icons.plumbing;
      case 'carpenter': return Icons.carpenter;
      case 'cleaning_services': return Icons.cleaning_services;
      case 'format_paint': return Icons.format_paint;
      case 'home_repair_service': return Icons.home_repair_service;
      case 'yard': return Icons.yard;
      case 'directions_car': return Icons.directions_car;
      default: return Icons.home_repair_service;
    }
  }

  Widget _buildPopularServices(BuildContext context) {
    return FutureBuilder<List<ServiceCategory>>(
      future: DI.customerRepo.getActiveServices(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.marginMobile),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final categories = snapshot.data!;
        
        return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.spacingMd, AppSpacing.marginMobile, AppSpacing.spacingXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Popular Services', style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              Text(
                'UNION CERTIFIED',
                style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingXs),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: categories.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: AppSpacing.spacingXs,
              mainAxisSpacing: AppSpacing.spacingXs,
              childAspectRatio: 0.85,
            ),
            itemBuilder: (context, index) {
              final cat = categories[index];
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkerDiscoveryScreen(category: cat),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: AppRadius.radiusXl,
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: AppRadius.radiusXl,
                        ),
                        child: Icon(_getIconData(cat.iconData), color: AppColors.primary),
                      ),
                      const SizedBox(height: AppSpacing.spacing2xs),
                      Text(
                        cat.name,
                        style: AppTypography.labelSm.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
      },
    );
  }

  Widget _buildRecentBookingTracker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.spacingXs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusXl,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_outline, size: 18, color: AppColors.onTertiaryContainer),
                    const SizedBox(width: AppSpacing.spacing2xs),
                    Text('Recent Booking', style: AppTypography.labelMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('Completed on 14 Oct', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.spacingXs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deep Kitchen Cleaning', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      Text('Worker: Sunita Jadhav • Pune Central Co-op', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                  Text('₹850', style: AppTypography.currencyDisplay.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: AppRadius.radiusXl,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long, size: 18, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.spacing3xs),
                        Text('Receipt', style: AppTypography.labelMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingXs),
                Expanded(
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
                        const Icon(Icons.replay, size: 18, color: AppColors.onPrimary),
                        const SizedBox(width: AppSpacing.spacing3xs),
                        Text('Re-book', style: AppTypography.labelMd.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold)),
                      ],
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

  Widget _buildServicesNearYou(BuildContext context) {
    return FutureBuilder<List<Worker>>(
      // Defaulting to plumbing 'c2' to get some nearby workers for this section
      future: DI.customerRepo.getEligibleWorkers('c2'),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        
        final topWorkers = snapshot.data!.take(2).toList();
        
        return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.spacingSm, AppSpacing.marginMobile, AppSpacing.spacingLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Services Near You', style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  Text('Available union tradespeople in Kothrud', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
              Row(
                children: [
                  Text('View all (42)', style: AppTypography.labelMd.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.secondary),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          ...topWorkers.map((worker) => _buildWorkerCardHome(context, worker)),
        ],
      ),
    );
      },
    );
  }

  Widget _buildWorkerCardHome(BuildContext context, Worker worker) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.radiusXl,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: AppRadius.radiusXl,
                // Fallback icon for network images since tests drop connection
                child: Container(
                  width: 64,
                  height: 64,
                  color: AppColors.surfaceContainer,
                  child: const Icon(Icons.person, color: AppColors.outline),
                ),
              ),
              const SizedBox(width: AppSpacing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(worker.name, style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        Text('₹${worker.rate}', style: AppTypography.currencyDisplay.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing2xs, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryFixed.withValues(alpha: 0.3),
                        borderRadius: AppRadius.radiusFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified, size: 14, color: AppColors.tertiaryContainer),
                          const SizedBox(width: 4),
                          Text('Verified Co-op Member', style: AppTypography.labelSm.copyWith(color: AppColors.tertiaryContainer, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Text(
                      '${worker.specializations.join(' • ')}',
                      style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingSm, vertical: AppSpacing.spacing2xs),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.radiusLg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: AppColors.secondaryContainer),
                    const SizedBox(width: 4),
                    Text(worker.rating.toString(), style: AppTypography.labelSm.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                    Text(' (${worker.reviewCount})', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.outlineVariant, shape: BoxShape.circle)),
                Row(
                  children: [
                    const Icon(Icons.work_history_outlined, size: 16, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Text(worker.experience, style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(width: 4, height: 4, decoration: const BoxDecoration(color: AppColors.outlineVariant, shape: BoxShape.circle)),
                Row(
                  children: [
                    const Icon(Icons.near_me_outlined, size: 16, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Text('${worker.distanceKm} km', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          Container(
            width: double.infinity,
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
                Text('View Profile & Book', style: AppTypography.labelLg.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold)),
                const SizedBox(width: AppSpacing.spacingXs),
                const Icon(Icons.arrow_forward, size: 18, color: AppColors.onPrimary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReassuranceFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 0, AppSpacing.marginMobile, AppSpacing.spacingMd),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.radiusXl,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildFooterItem(Icons.shield_outlined, 'Escrow Payout'),
            Container(width: 1, height: 32, color: AppColors.outlineVariant.withValues(alpha: 0.5)),
            _buildFooterItem(Icons.price_check_outlined, 'Direct to Worker'),
            Container(width: 1, height: 32, color: AppColors.outlineVariant.withValues(alpha: 0.5)),
            _buildFooterItem(Icons.support_agent_outlined, 'Union Helpline'),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(label, style: AppTypography.labelSm.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

