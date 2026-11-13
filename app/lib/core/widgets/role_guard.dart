import 'package:flutter/material.dart';
import '../config/dependency_injection.dart';
import '../config/app_config.dart';
import '../theme/app_colors.dart';

/// Protects application routes by validating current user authentication and role permissions.
/// If unauthenticated or role does not match, redirects to fallbackRoute.
class RoleGuard extends StatefulWidget {
  final String requiredRole;
  final Widget child;
  final String fallbackRoute;

  const RoleGuard({
    super.key,
    required this.requiredRole,
    required this.child,
    required this.fallbackRoute,
  });

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  bool _isLoading = true;
  bool _isAuthorized = false;

  @override
  void initState() {
    super.initState();
    _checkAuthorization();
  }

  Future<void> _checkAuthorization() async {
    try {
      var user = await DI.authRepo.getCurrentUser();
      if (user == null && !AppConfig.useMockData) {
        // Allow brief moment for web localStorage session recovery
        for (int i = 0; i < 3; i++) {
          await Future.delayed(const Duration(milliseconds: 100));
          user = await DI.authRepo.getCurrentUser();
          if (user != null) break;
        }
      }

      if (user == null) {
        _handleUnauthorized();
        return;
      }

      final role = await DI.authRepo.getUserRole() ?? await DI.userRepo.getUserRole(user.id);
      final metaRole = (user.appMetadata['role'] ?? user.userMetadata?['role'])?.toString().toUpperCase();

      // Normalize required role for comparison
      final required = widget.requiredRole.toUpperCase();
      final roleUpper = role?.toUpperCase();

      // Check direct role match
      bool authorized = (roleUpper != null && roleUpper == required) ||
          (metaRole != null && metaRole == required);

      // ADMIN route accepts ADMIN, SUPER_ADMIN, and FEDERATION_ADMIN
      if (!authorized && required == 'ADMIN') {
        authorized = roleUpper == 'SUPER_ADMIN' ||
            roleUpper == 'FEDERATION_ADMIN' ||
            metaRole == 'SUPER_ADMIN' ||
            metaRole == 'FEDERATION_ADMIN';
      }

      // CUSTOMER route: An authenticated user who is not explicitly an Admin is authorized for Customer
      // (especially for onboarding and initial registration).
      if (!authorized && required == 'CUSTOMER') {
        final isAdmin = roleUpper == 'ADMIN' ||
            roleUpper == 'SUPER_ADMIN' ||
            roleUpper == 'FEDERATION_ADMIN' ||
            metaRole == 'ADMIN' ||
            metaRole == 'SUPER_ADMIN' ||
            metaRole == 'FEDERATION_ADMIN';
        if (!isAdmin && (roleUpper == null || roleUpper == 'CUSTOMER')) {
          authorized = true;
        }
      }

      // WORKER route: An authenticated user registering as a worker is authorized
      // unless they are already an Admin.
      if (!authorized && required == 'WORKER') {
        final isAdmin = roleUpper == 'ADMIN' ||
            roleUpper == 'SUPER_ADMIN' ||
            roleUpper == 'FEDERATION_ADMIN' ||
            metaRole == 'ADMIN' ||
            metaRole == 'SUPER_ADMIN' ||
            metaRole == 'FEDERATION_ADMIN';
        if (!isAdmin && (roleUpper == null || roleUpper == 'CUSTOMER' || roleUpper == 'WORKER')) {
          authorized = true;
        }
      }

      if (authorized) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isAuthorized = true;
          });
        }
      } else {
        _handleUnauthorized();
      }
    } catch (_) {
      _handleUnauthorized();
    }
  }

  void _handleUnauthorized() {
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isAuthorized = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed(widget.fallbackRoute);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.surface,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_isAuthorized) {
      return widget.child;
    }

    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: SizedBox.shrink(),
    );
  }
}
