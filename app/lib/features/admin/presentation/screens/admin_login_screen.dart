import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/repositories/mock_admin_repository.dart';

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
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.corporate_fare, color: AppColors.onPrimary, size: 64),
              const SizedBox(height: AppSpacing.spacingMd),
              Text('Cooperative Admin Console', style: AppTypography.headlineSm.copyWith(color: AppColors.onPrimary)),
              Text('ShramSetu Federation', style: AppTypography.bodyMd.copyWith(color: AppColors.onPrimaryContainer)),
              const SizedBox(height: AppSpacing.spacing3xl),
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
