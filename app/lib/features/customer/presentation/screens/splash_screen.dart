import 'package:flutter/material.dart';
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
      DI.notificationService.registerDeviceToken(userId: user.id);
      final role = await DI.userRepo.getUserRole(user.id);
      if (mounted) {
        if (role == 'CUSTOMER') {
          // Check if the customer has completed their profile.
          // Returning customers who never finished onboarding are sent back.
          final isComplete = await DI.userRepo.isProfileComplete(user.id);
          if (mounted) {
            if (isComplete) {
              Navigator.of(context).pushReplacementNamed('/customer/home');
            } else {
              Navigator.of(context).pushReplacementNamed('/customer/onboarding');
            }
          }
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
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: ClipOval(
                child: Image.asset('assets/images/logo.jpg', fit: BoxFit.contain),
              ),
            ),
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
