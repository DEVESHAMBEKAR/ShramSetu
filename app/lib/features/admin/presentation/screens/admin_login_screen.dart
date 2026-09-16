import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';


import 'package:app/core/config/dependency_injection.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController(text: 'admin@shramsetu.demo');
  final _passwordController = TextEditingController(text: 'admin123');
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final success = await DI.authRepo.login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (success) {
        final user = await DI.authRepo.getCurrentUser();
        if (user != null) {
          final role = await DI.userRepo.getUserRole(user.id);
          if (role == 'ADMIN' || DI.authRepo.runtimeType.toString() == 'MockAuthRepository') {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/admin/home');
            }
            return;
          } else {
            await DI.authRepo.logout();
            setState(() => _errorMsg = 'Unauthorized: Admin role required.');
          }
        } else {
           setState(() => _errorMsg = 'User profile not found.');
        }
      } else {
        setState(() => _errorMsg = 'Invalid admin credentials');
      }
    } catch (e) {
      setState(() => _errorMsg = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacementNamed('/onboarding');
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/logo.jpg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.spacingMd),
              Text('Cooperative Admin Console', style: AppTypography.headlineSm.copyWith(color: AppColors.onPrimary)),
              Text('ShramSetu Federation', style: AppTypography.bodyMd.copyWith(color: AppColors.onPrimaryContainer)),
              const SizedBox(height: AppSpacing.spacing2xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.spacingLg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.radiusXl,
                ),
                child: Column(
                  children: [
                    if (_errorMsg != null) ...[
                      Text(_errorMsg!, style: AppTypography.labelSm.copyWith(color: AppColors.error)),
                      const SizedBox(height: AppSpacing.spacingMd),
                    ],
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Admin Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: AppRadius.radiusLg),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spacingMd),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: OutlineInputBorder(borderRadius: AppRadius.radiusLg),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.spacingLg),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                        ),
                        child: _isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2))
                            : const Text('Access Console', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),

                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
