import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/models/federation_models.dart';
import '../../../../shared/widgets/area_not_serviceable_screen.dart';
import 'package:app/core/config/dependency_injection.dart';
import '../../../worker/data/models/worker_models.dart';

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

      final incomingAuthRole = Uri.base.queryParameters['auth_role']?.toUpperCase();
      String? role = await DI.userRepo.getUserRole(user.id);
      final isRealAdmin = (user.email?.toLowerCase() == 'admin@shramsetu.in' || (user.email?.toLowerCase().contains('admin@') ?? false));

      // If user has no database role (or is erroneously set to ADMIN for a non-admin email), provision user
      if (role == null || (role == 'ADMIN' && !isRealAdmin)) {
        final effectiveRole = incomingAuthRole ?? 'CUSTOMER';
        final effectiveName = (user.userMetadata?['full_name'] ??
                user.userMetadata?['name'] ??
                (effectiveRole == 'WORKER' ? 'Artisan' : 'Customer'))
            .toString();
        try {
          await DI.userRepo.upsertUserProfile(
            userId: user.id,
            role: effectiveRole,
            phone: user.phone ?? '',
            fullName: effectiveName,
          );
          role = effectiveRole;
        } catch (e) {
          debugPrint('[SplashScreen] OAuth upsert note: $e');
        }
      } else {
        // Verify public.users row exists even if role was cached from session
        try {
          final profile = await DI.userRepo.getUserProfile(user.id);
          if (profile == null) {
            await DI.userRepo.upsertUserProfile(
              userId: user.id,
              role: role,
              phone: user.phone ?? '',
              fullName: user.userMetadata?['full_name'] ?? user.userMetadata?['name'],
            );
          }
        } catch (_) {}
      }

      if (mounted) {
        // Cross-role protection if accessing via role-specific portal
        if (incomingAuthRole != null && role != null) {
          if (incomingAuthRole == 'CUSTOMER' && role == 'WORKER') {
            await DI.authRepo.logout();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Access denied: This Google account is registered as a Worker Partner. Please use the Worker portal.'),
                  backgroundColor: AppColors.error,
                ),
              );
              Navigator.of(context).pushReplacementNamed('/login/worker');
            }
            return;
          } else if (incomingAuthRole == 'WORKER' && role == 'CUSTOMER') {
            await DI.authRepo.logout();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Access denied: This Google account is registered as a Customer. Please use the Customer portal.'),
                  backgroundColor: AppColors.error,
                ),
              );
              Navigator.of(context).pushReplacementNamed('/login/customer');
            }
            return;
          }
        }

        if (role == 'CUSTOMER') {
          // Check if the customer has completed their profile.
          final isComplete = await DI.userRepo.isProfileComplete(user.id);
          if (mounted) {
            if (isComplete) {
              try {
                final profile = await DI.userRepo.getCustomerProfile(user.id);
                final addr = profile?.defaultAddress;
                if (addr != null) {
                  final fed = FederationModel.findFederationForLocation(
                    district: addr.district,
                    city: addr.city,
                    state: addr.state,
                    location: addr.area,
                    address: addr.addressLine,
                    pincode: addr.postalCode,
                  );
                  if (fed == null) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => AreaNotServiceableScreen(
                          userRole: 'CUSTOMER',
                          reason: ServiceUnavailableReason.noFederation,
                          district: addr.district,
                          city: addr.city,
                          area: addr.area,
                          state: addr.state,
                          pincode: addr.postalCode,
                        ),
                      ),
                    );
                    return;
                  }
                  final hasWorkers = await DI.customerRepo.hasWorkersInArea(
                    federationId: fed.id,
                    district: addr.district,
                    city: addr.city,
                    pincode: addr.postalCode,
                  );
                  if (!hasWorkers) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => AreaNotServiceableScreen(
                          userRole: 'CUSTOMER',
                          reason: ServiceUnavailableReason.noWorkers,
                          district: addr.district,
                          city: addr.city,
                          area: addr.area,
                          state: addr.state,
                          pincode: addr.postalCode,
                        ),
                      ),
                    );
                    return;
                  }
                }
              } catch (_) {}
              Navigator.of(context).pushReplacementNamed('/customer/home');
            } else {
              Navigator.of(context).pushReplacementNamed('/customer/onboarding');
            }
          }
        } else if (role == 'WORKER') {
          // Check worker profile registration and document verification
          final WorkerProfile profile = await DI.workerRepo.getWorkerProfile(user.id);
          final docs = await DI.workerRepo.getVerificationDocuments(profile.id);
          final hasCompletedRegistration = profile.name.isNotEmpty &&
              !profile.name.startsWith('Artisan (') &&
              !profile.name.startsWith('User ') &&
              docs.isNotEmpty;

          if (mounted) {
            if (!hasCompletedRegistration) {
              Navigator.of(context).pushReplacementNamed('/worker/registration');
            } else {
              Navigator.of(context).pushReplacementNamed('/worker/dashboard');
            }
          }
        } else if (role == 'SUPER_ADMIN') {
          Navigator.of(context).pushReplacementNamed('/super-admin/home');
        } else if (role == 'ADMIN' || role == 'FEDERATION_ADMIN') {
          Navigator.of(context).pushReplacementNamed('/admin/home');
        } else {
          // If role is missing, provision incoming role (or CUSTOMER)
          final effectiveRole = incomingAuthRole ?? 'CUSTOMER';
          final effectiveName = (user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? 'User').toString();
          try {
            await DI.userRepo.upsertUserProfile(
              userId: user.id,
              role: effectiveRole,
              phone: user.phone ?? '',
              fullName: effectiveName,
            );
          } catch (_) {}

          if (mounted) {
            if (effectiveRole == 'WORKER') {
              Navigator.of(context).pushReplacementNamed('/worker/registration');
            } else {
              Navigator.of(context).pushReplacementNamed('/customer/onboarding');
            }
          }
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
