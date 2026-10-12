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
import '../../../../shared/widgets/shramsetu_brand_mark.dart';

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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Stack(
            children: [
              CustomScrollView(
                slivers: [
                  _buildSliverAppBar(),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildFederationBanner(),
                        _buildHeaderCard(),
                        _buildGovernmentCredentialVault(),
                        _buildGazetteTariffRateCard(),
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
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      toolbarHeight: 60,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(3),
        child: TricolorStripe(height: 3),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.primaryContainer),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          ShramSetuBrandMark(
            size: 30,
            showText: true,
            subtitle: 'Artisan Detail • DPI Civic',
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Cooperative Verification Details',
          icon: const Icon(Icons.help_outline, color: AppColors.onSurfaceVariant),
          onPressed: _showFederationHelpModal,
        ),
        const SizedBox(width: AppSpacing.spacingXs),
      ],
    );
  }

  void _showFederationHelpModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_user, color: AppColors.primaryContainer, size: 28),
                const SizedBox(width: 12),
                Text('Cooperative Verification', style: AppTypography.titleLg.copyWith(color: AppColors.primaryContainer, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'All artisans on ShramSetu are enrolled members of verified labor cooperatives. They undergo mandatory government skill certification, police background verification, and cooperative insurance coverage.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryContainer,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Understood'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFederationBanner() {
    return Container(
      color: AppColors.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: AppColors.tertiaryFixed, size: 16),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DPI SOVEREIGN REGISTRY: ${widget.worker.federationId != null && widget.worker.federationId!.isNotEmpty ? widget.worker.federationId : "MH-KTR-8842-P"}',
                    style: AppTypography.labelSm.copyWith(
                      color: Colors.white,
                      letterSpacing: 0.8,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'नागरिक सेवा हमी कायदा अंतर्गत प्रमाणीकृत',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 8.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: AppRadius.radiusSm,
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: AppColors.tertiaryFixed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Active & Audited',
                  style: AppTypography.labelSm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 12, AppSpacing.marginMobile, 8),
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
          children: [
            // Top Accent Stripe
            const TricolorStripe(height: 3),

            Padding(
              padding: const EdgeInsets.all(AppSpacing.spacingMd),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: widget.worker.imageUrl.isNotEmpty
                                ? Image.network(
                                    widget.worker.imageUrl,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      width: 72,
                                      height: 72,
                                      color: AppColors.surfaceContainerLow,
                                      child: Center(
                                        child: Text(
                                          widget.worker.name.isNotEmpty ? widget.worker.name[0] : 'W',
                                          style: AppTypography.headlineSm.copyWith(
                                            color: AppColors.primaryContainer,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                : Container(
                                    width: 72,
                                    height: 72,
                                    color: AppColors.surfaceContainerLow,
                                    child: Center(
                                      child: Text(
                                        widget.worker.name.isNotEmpty ? widget.worker.name[0] : 'W',
                                        style: AppTypography.headlineSm.copyWith(
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
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.civicVerifiedGreen,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.check, size: 12, color: Colors.white),
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
                                Flexible(
                                  child: Text(
                                    widget.worker.name,
                                    style: AppTypography.titleLg.copyWith(
                                      color: AppColors.primaryContainer,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryFixed,
                                    borderRadius: AppRadius.radiusSm,
                                    border: Border.all(color: AppColors.primaryFixedDim.withValues(alpha: 0.5)),
                                  ),
                                  child: Text(
                                    'MASTER CLASS',
                                    style: AppTypography.labelSm.copyWith(
                                      color: AppColors.onPrimaryFixed,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 8.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.worker.specializations.isNotEmpty
                                  ? widget.worker.specializations.first
                                  : 'Master Artisan & Technician',
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.onSurface,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'मुख्य तंत्रज्ञ व कुशल कारागीर',
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 10.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.star, size: 14, color: AppColors.secondaryContainer),
                                const SizedBox(width: 2),
                                Text(
                                  widget.worker.rating.toStringAsFixed(2),
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onSurface,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '• (${widget.worker.jobsCompleted > 0 ? widget.worker.jobsCompleted : widget.worker.reviewCount} Audited Jobs / प्रमाणित कामे)',
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
                  const SizedBox(height: 12),

                  // Guild Affiliation Sub-Card
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: AppRadius.radiusLg,
                      border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.assured_workload, size: 18, color: AppColors.primaryContainer),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MAHARASHTRA GUILD AFFILIATION',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                Text(
                                  'Member #${widget.worker.id} • ${widget.worker.locationTag}',
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.primaryContainer,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: AppRadius.radiusSm,
                            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.shield, size: 12, color: AppColors.civicVerifiedGreen),
                              const SizedBox(width: 3),
                              Text(
                                '0 Disputes',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.civicVerifiedGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGovernmentCredentialVault() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 8, AppSpacing.marginMobile, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.policy, size: 18, color: AppColors.primaryContainer),
                  const SizedBox(width: 6),
                  Text(
                    'Government Credential Vault',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: AppRadius.radiusSm,
                ),
                child: Text(
                  '4 / 4 VALID',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                    fontSize: 9.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 1. Aadhaar Biometric
          _buildVaultItem(
            icon: Icons.fingerprint,
            iconColor: AppColors.primaryContainer,
            statusBadge: 'DigiLocker Verified',
            badgeColor: AppColors.civicVerifiedGreen,
            specCode: 'UIDAI e-KYC 2.1',
            title: 'Aadhaar Biometric Authenticated',
            marathiTitle: 'आधार बायोमेट्रिक सत्यप्रत प्रमाणीकरण',
            auditDetail: 'UID: XXXX-XXXX-8912 • Instant Revocation Audited',
          ),
          const SizedBox(height: 6),

          // 2. ITI NTC Grade-A
          _buildVaultItem(
            icon: Icons.workspace_premium,
            iconColor: AppColors.secondaryContainer,
            statusBadge: 'NTC Grade-A',
            badgeColor: AppColors.secondaryContainer,
            specCode: 'NCVT / DVET',
            title: 'ITI Certified Vocational Trade',
            marathiTitle: 'आयटीआय प्रमाणित व्यवसाय प्रमाणपत्र',
            auditDetail: 'Cert #${widget.worker.federationId != null && widget.worker.federationId!.isNotEmpty ? widget.worker.federationId : "MH-PL-90218"} • Directorate of Vocational Education',
          ),
          const SizedBox(height: 6),

          // 3. Police NOC
          _buildVaultItem(
            icon: Icons.local_police,
            iconColor: AppColors.primaryContainer,
            statusBadge: 'NOC Active',
            badgeColor: AppColors.civicVerifiedGreen,
            specCode: 'Valid Dec 2025',
            title: 'Police Character Clearance',
            marathiTitle: 'पोलीस चारित्र्य पडताळणी प्रमाणपत्र',
            auditDetail: 'Special Branch Police • Clean Civic Record',
          ),
          const SizedBox(height: 6),

          // 4. PM Suraksha Bima
          _buildVaultItem(
            icon: Icons.health_and_safety,
            iconColor: AppColors.civicVerifiedGreen,
            statusBadge: 'Insured',
            badgeColor: AppColors.primaryContainer,
            specCode: '₹5,00,000',
            title: 'Pradhan Mantri Suraksha Bima',
            marathiTitle: 'प्रधानमंत्री सुरक्षा विमा योजना कवच',
            auditDetail: 'Comprehensive Co-op Welfare Accidental & Liability Shield',
          ),
        ],
      ),
    );
  }

  Widget _buildVaultItem({
    required IconData icon,
    required Color iconColor,
    required String statusBadge,
    required Color badgeColor,
    required String specCode,
    required String title,
    required String marathiTitle,
    required String auditDetail,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.radiusMd,
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.1),
                        borderRadius: AppRadius.radiusSm,
                        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 10, color: badgeColor),
                          const SizedBox(width: 3),
                          Text(
                            statusBadge,
                            style: AppTypography.labelSm.copyWith(
                              color: badgeColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      specCode,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.primaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  marathiTitle,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  auditDetail,
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.outline,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGazetteTariffRateCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 4, AppSpacing.marginMobile, 8),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusXl,
          border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.gavel, size: 18, color: AppColors.secondaryContainer),
                    const SizedBox(width: 6),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Govt Gazette Tariff Rate Card',
                          style: AppTypography.titleMd.copyWith(
                            color: AppColors.primaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'शासकीय राजपत्रातील प्रमाणित दर • Standardized pricing',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryFixed,
                    borderRadius: AppRadius.radiusSm,
                    border: Border.all(color: AppColors.secondaryFixedDim.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'CAPPED RATE',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSecondaryFixed,
                      fontWeight: FontWeight.bold,
                      fontSize: 8.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Item 1
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadius.radiusMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'तपासणी व प्राथमिक निदान (Diagnostic)',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Includes 45-min on-site inspection & estimate',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${widget.worker.rate.toStringAsFixed(0)}',
                        style: AppTypography.titleMd.copyWith(
                          color: AppColors.primaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Max Govt Cap',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.civicVerifiedGreen,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Item 2
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadius.radiusMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'मानक दुरुस्ती व सुटे भाग जोडणी',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Standard repair per running item / fixture',
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.onSurfaceVariant,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${(widget.worker.rate * 0.75).round()}',
                        style: AppTypography.titleMd.copyWith(
                          color: AppColors.primaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Per Task Cap',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.receipt_long, size: 14, color: AppColors.civicVerifiedGreen),
                const SizedBox(width: 4),
                Text(
                  'Direct digital receipt via ShramSetu • 0% Platform cut',
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
            behavior: HitTestBehavior.opaque,
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
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.98),
          border: const Border(
            top: BorderSide(color: AppColors.surfaceContainerHigh, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, 12, AppSpacing.marginMobile, 28),
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('DigiLocker Verified Credential: MH-KTR-8842-P authenticated.'),
                    backgroundColor: AppColors.primaryContainer,
                  ),
                );
              },
              icon: const Icon(Icons.description_outlined, size: 18, color: AppColors.primaryContainer),
              label: Text(
                'DigiLocker PDF',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.primaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                backgroundColor: AppColors.surfaceContainerHigh,
                side: const BorderSide(color: AppColors.surfaceContainerHigh),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
            ),
            const SizedBox(width: AppSpacing.spacingSm),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  bookingFlowState.selectedCategory = widget.category;
                  bookingFlowState.selectedWorker = widget.worker;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BookingDateTimeScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryContainer,
                  foregroundColor: AppColors.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        'Book at Gazette Tariff (कारीगर निवडा)',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.spacing2xs),
                    const Icon(Icons.arrow_forward, color: AppColors.onPrimary, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
