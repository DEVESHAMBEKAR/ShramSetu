import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_radius.dart';
import '../../core/config/dependency_injection.dart';
import '../../core/models/federation_models.dart';

enum ServiceUnavailableReason {
  noFederation,
  noWorkers,
}

class AreaNotServiceableScreen extends StatefulWidget {
  final String userRole; // 'CUSTOMER' or 'WORKER'
  final String? district;
  final String? state;
  final String? pincode;
  final String? area;
  final String? city;
  final ServiceUnavailableReason reason;

  const AreaNotServiceableScreen({
    super.key,
    required this.userRole,
    this.district,
    this.state,
    this.pincode,
    this.area,
    this.city,
    this.reason = ServiceUnavailableReason.noFederation,
  });

  @override
  State<AreaNotServiceableScreen> createState() => _AreaNotServiceableScreenState();
}

class _AreaNotServiceableScreenState extends State<AreaNotServiceableScreen> {
  bool _notificationEnabled = true;

  String get _effectiveDistrict =>
      widget.district?.isNotEmpty == true ? widget.district! : (widget.city ?? 'your area');

  @override
  Widget build(BuildContext context) {
    final isCustomer = widget.userRole.toUpperCase() == 'CUSTOMER';
    final isNoFederation = widget.reason == ServiceUnavailableReason.noFederation;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset('assets/images/logo.jpg', height: 26, width: 26, fit: BoxFit.contain),
            const SizedBox(width: AppSpacing.spacingXs),
            Text(
              'ShramSetu',
              style: AppTypography.titleMd.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout, size: 20, color: AppColors.outline),
            onPressed: () async {
              await DI.authRepo.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/onboarding', (_) => false);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.marginMobile,
                vertical: AppSpacing.spacingLg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Animated radar/compass visual card
                  _buildHeroVisual(isCustomer, isNoFederation),
                  const SizedBox(height: 24),

                  // Status Badge
                  _buildStatusBadge(isCustomer, isNoFederation),
                  const SizedBox(height: 12),

                  // Main Headline
                  Text(
                    isCustomer
                        ? 'We Are Coming Soon to $_effectiveDistrict!'
                        : 'Founding Artisan Waitlist Confirmed!',
                    textAlign: TextAlign.center,
                    style: AppTypography.headlineMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle explanation
                  Text(
                    isCustomer
                        ? (isNoFederation
                            ? 'Your customer account and home address have been registered. However, our cooperative artisan federation has not launched jurisdiction in your sector yet.'
                            : 'Your customer account is registered! While a cooperative union is assigned to $_effectiveDistrict, verified local artisans are currently undergoing onboarding.')
                        : 'Your 20-point trade registration has been safely saved! Cooperative union coverage is currently expanding and not yet open in $_effectiveDistrict.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Location Details Card
                  _buildLocationCard(),
                  const SizedBox(height: 16),

                  // Notification Alert Card
                  _buildNotificationCard(isCustomer),
                  const SizedBox(height: 24),

                  // Action Buttons
                  _buildActionButtons(isCustomer),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroVisual(bool isCustomer, bool isNoFederation) {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 2),
      ),
      child: Center(
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            isCustomer ? Icons.explore_outlined : Icons.handyman_outlined,
            size: 40,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool isCustomer, bool isNoFederation) {
    final String label;
    final Color bgColor;
    final Color textColor;
    final Color borderColor;

    if (isCustomer) {
      if (isNoFederation) {
        label = 'EXPANSION ZONE • CURRENTLY NOT SERVICEABLE';
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        borderColor = const Color(0xFFFFB74D);
      } else {
        label = 'UNION ESTABLISHED • ONBOARDING ARTISANS';
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        borderColor = const Color(0xFF81C784);
      }
    } else {
      label = 'FOUNDING ARTISAN WAITLIST • DISTRICT EXPANSION';
      bgColor = const Color(0xFFEDE7F6);
      textColor = const Color(0xFF512DA8);
      borderColor = const Color(0xFFB39DDB);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final areaPart = [
      if (widget.area?.isNotEmpty == true) widget.area,
      if (widget.city?.isNotEmpty == true) widget.city,
      if (widget.district?.isNotEmpty == true && widget.district != widget.city) widget.district,
      if (widget.state?.isNotEmpty == true) widget.state,
    ].join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.location_on, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'YOUR REGISTERED LOCATION',
                style: AppTypography.labelSm.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Account Saved',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            areaPart.isNotEmpty ? areaPart : 'Registered Delivery Address',
            style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
          ),
          if (widget.pincode?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              'Postal PIN: ${widget.pincode}',
              style: AppTypography.bodySm.copyWith(color: AppColors.outline),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotificationCard(bool isCustomer) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: const Color(0xFFB8DAFF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.notifications_active_outlined, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Launch Notification Priority',
                  style: AppTypography.bodyMd.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isCustomer
                      ? 'You are on the priority list. You will receive an SMS/WhatsApp notice the moment verified artisans go live in your pincode.'
                      : 'You are on the Founding Artisan list. Our union coordinators will notify you as soon as district onboarding begins.',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _notificationEnabled,
            onChanged: (val) {
              setState(() => _notificationEnabled = val);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(val ? 'Launch notifications enabled.' : 'Launch notifications silenced.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isCustomer) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              if (isCustomer) {
                Navigator.of(context).pushReplacementNamed('/customer/onboarding');
              } else {
                Navigator.of(context).pushReplacementNamed('/worker/registration');
              }
            },
            icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
            label: Text(
              isCustomer ? 'Change Location / Enter Another Address' : 'Update Registration Locality',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.outlineVariant),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _showActiveDistrictsModal(context),
            icon: const Icon(Icons.map_outlined, size: 18),
            label: const Text('View Currently Active Federations & Districts'),
          ),
        ),
      ],
    );
  }

  void _showActiveDistrictsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Cooperative Federations',
                    style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'ShramSetu is fully operational in the following municipal districts:',
                style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              ...FederationModel.defaultFederations.map((fed) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(fed.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Text('Jurisdiction: ${fed.district}, ${fed.state}', style: const TextStyle(fontSize: 11, color: AppColors.outline)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32))),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
