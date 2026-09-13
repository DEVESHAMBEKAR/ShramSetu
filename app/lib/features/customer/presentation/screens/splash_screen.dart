import 'package:flutter/material.dart';
import '../../../../shared/widgets/app_logo.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';

import 'package:app/core/config/dependency_injection.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Artificial delay for splash screen aesthetics
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;

    final user = await DI.authRepo.getCurrentUser();
    if (user != null) {
      final role = await DI.userRepo.getUserRole(user.id);
      if (mounted) {
        if (role == 'CUSTOMER') {
          Navigator.of(context).pushReplacementNamed('/customer/home');
        } else if (role == 'WORKER') {
          Navigator.of(context).pushReplacementNamed('/worker/dashboard');
        } else if (role == 'ADMIN') {
          Navigator.of(context).pushReplacementNamed('/admin/home');
        } else {
          // If role is missing or unknown, go to onboarding to re-authenticate
          await DI.authRepo.logout();
          if (mounted) Navigator.of(context).pushReplacementNamed('/onboarding');
        }
      }
    } else {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/onboarding');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const AppLogo(size: 140),
            const SizedBox(height: AppSpacing.spacingLg),
            Text(
              'ShramSetu',
              style: AppTypography.displayLgMobile.copyWith(
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.spacing4xs),
            Text(
              'श्रमसेतू सहकार मंच',
              style: AppTypography.titleMd.copyWith(
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
