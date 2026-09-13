import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String _selectedRole = 'customer'; // 'customer' or 'worker'
  String _selectedLanguage = 'en'; // 'en', 'mr', 'hi'

  void _handleContinue() {
    if (_selectedRole == 'customer') {
      Navigator.of(context).pushReplacementNamed('/login/customer');
    } else if (_selectedRole == 'worker') {
      Navigator.of(context).pushReplacementNamed('/login/worker');
    } else {
      Navigator.of(context).pushReplacementNamed('/login/admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.marginMobile,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.spacingMd),
                    _buildHeroHeader(),
                    const SizedBox(height: AppSpacing.spacingLg),
                    _buildIllustrationCard(),
                    const SizedBox(height: AppSpacing.spacingMd),
                    Text(
                      'Choose Your Language',
                      style: AppTypography.headlineLgMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spacing4xs),
                    Text(
                      'आपली भाषा निवडा • अपनी भाषा चुनें',
                      style: AppTypography.titleMd.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spacing3xs),
                    Text(
                      'Select your preferred language for service booking and direct cooperative customer support.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spacingMd),
                    _buildRoleSelector(),
                    const SizedBox(height: AppSpacing.spacingLg),
                    _buildLanguageOptions(),
                    const SizedBox(height: AppSpacing.spacingXl),
                    _buildTrustBanner(),
                    const SizedBox(height: AppSpacing.spacingLg),
                    _buildAudioPill(),
                    const SizedBox(height: AppSpacing.spacing3xl),
                  ],
                ),
              ),
            ),
            _buildBottomCta(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: AppRadius.radiusXl,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.handshake_outlined, color: AppColors.onPrimary, size: 24),
        ),
        const SizedBox(width: AppSpacing.spacingXs),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ShramSetu',
              style: AppTypography.headlineSm.copyWith(
                color: AppColors.primary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'श्रमसेतू सहकार मंच',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIllustrationCard() {
    return Container(
      width: double.infinity,
      height: 144, // 36 * 4
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: AppRadius.radiusXl,
        image: const DecorationImage(
          image: NetworkImage(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuDj_q9BXU6qHaTPda1q03V9Tf3_1exNxkPuWc6hnMf22zLFEF7s_kxSJjAtTI8p_lIwHALrj09KNrGAyl4V7p1KZ0QQOFuOElfYfWfvE7QsKi_grlzO2YGPKinOT7hjLb0puxZ5Oed7B6-NtatqH46OqeVl3vpFUMmTVOn13T1ecQh3zRXh0X-jzDHS8h4XT4f2X2gRMHmWp77Lz_RS7XmmF2FBa-IwM6_qJHjrJVzLz5cyfoV-4MW4zQ'
          ),
          fit: BoxFit.cover,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 64,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: AppSpacing.spacingSm,
            left: AppSpacing.spacingSm,
            child: Row(
              children: [
                const Icon(Icons.verified_outlined, color: AppColors.tertiaryFixed, size: 18),
                const SizedBox(width: AppSpacing.spacing2xs),
                Text(
                  'Fair Wages • Trade Union Backed',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacing3xs),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: AppRadius.radiusXl,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildRoleTab('customer', Icons.home_repair_service_outlined, 'Customer', AppColors.secondary),
          ),
          Expanded(
            child: _buildRoleTab('worker', Icons.engineering_outlined, 'Worker', AppColors.primary),
          ),
          Expanded(
            child: _buildRoleTab('admin', Icons.corporate_fare, 'Admin', AppColors.tertiaryFixed),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleTab(String roleId, IconData icon, String label, Color iconColor) {
    final isSelected = _selectedRole == roleId;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = roleId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.spacingSm,
          horizontal: 4,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceContainerLowest : Colors.transparent,
          borderRadius: AppRadius.radiusLg,
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? iconColor : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTypography.labelLg.copyWith(
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOptions() {
    return Column(
      children: [
        _buildLanguageCard(
          code: 'en',
          iconText: 'En',
          title: 'English',
          subtitle: 'Standard platform interface & live updates',
          badgeText: 'Default',
          badgeBg: AppColors.primaryContainer.withOpacity(0.1),
          badgeColor: AppColors.primary,
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        _buildLanguageCard(
          code: 'mr',
          iconText: 'म',
          title: 'मराठी',
          subtitle: 'पुणे व महाराष्ट्र कामगार सहकारी मंच',
          badgeText: 'स्थानिक',
          badgeBg: AppColors.secondaryFixed,
          badgeColor: AppColors.onSecondaryFixedVariant,
        ),
        const SizedBox(height: AppSpacing.spacingSm),
        _buildLanguageCard(
          code: 'hi',
          iconText: 'हिं',
          title: 'हिन्दी',
          subtitle: 'कुशल कामगार और पारदर्शी सेवा गारंटी',
        ),
      ],
    );
  }

  Widget _buildLanguageCard({
    required String code,
    required String iconText,
    required String title,
    required String subtitle,
    String? badgeText,
    Color? badgeBg,
    Color? badgeColor,
  }) {
    final bool isSelected = _selectedLanguage == code;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedLanguage = code),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusXl,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryFixed : AppColors.surfaceContainerHigh,
                borderRadius: AppRadius.radiusXl,
              ),
              child: Center(
                child: Text(
                  iconText,
                  style: AppTypography.titleLg.copyWith(
                    color: isSelected ? AppColors.primary : AppColors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: AppTypography.titleLg.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: AppSpacing.spacingXs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.spacing2xs,
                            vertical: AppSpacing.spacing4xs,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: AppTypography.labelSm.copyWith(
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    subtitle,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                size: 20,
                color: isSelected ? AppColors.onPrimary : AppColors.outline.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.radiusXl,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.spacing2xs),
            margin: const EdgeInsets.only(top: AppSpacing.spacing4xs),
            decoration: BoxDecoration(
              color: AppColors.tertiaryFixedDim.withOpacity(0.4),
              borderRadius: AppRadius.radiusLg,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppColors.tertiaryContainer,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cooperative Guarantee',
                  style: AppTypography.titleMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.spacing4xs),
                Text(
                  '100% Verified Tradespeople • Zero Middlemen Cuts • Fair Hourly Wages Guaranteed by Pune District Trade Union.',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPill() {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.spacingXs,
        horizontal: AppSpacing.spacingMd,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppRadius.radiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.volume_up_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.spacingXs),
          Text(
            'Tap to listen in audio (ऐका / सुनें)',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCta() {
    String btnText = 'Continue / Next';
    if (_selectedLanguage == 'mr') {
      btnText = 'पुढे चला (Continue)';
    } else if (_selectedLanguage == 'hi') {
      btnText = 'आगे बढ़ें (Continue)';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.marginMobile),
      color: AppColors.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: _handleContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.radiusXl,
              ),
              elevation: 2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  btnText,
                  style: AppTypography.headlineSm.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingSm),
                const Icon(Icons.arrow_forward, size: 22),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.spacing2xs),
          Text(
            'By proceeding, you support authentic worker-owned cooperatives.',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
