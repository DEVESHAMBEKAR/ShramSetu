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

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final success = await DI.authRepo.login(email, password);

      if (success) {
        final user = await DI.authRepo.getCurrentUser();
        if (user != null) {
          final role = await DI.userRepo.getUserRole(user.id);
          final isOwnerAdmin = user.email?.toLowerCase() == 'ambekardevesh2@gmail.com' ||
              user.email?.toLowerCase() == 'admin@shramsetu.demo';

          if (role == 'ADMIN' || isOwnerAdmin || DI.authRepo.runtimeType.toString() == 'MockAuthRepository') {
            // Self-heal: ensure role is recorded in public.users if missing
            if (role != 'ADMIN' && isOwnerAdmin) {
              try {
                await DI.userRepo.upsertUserProfile(
                  userId: user.id,
                  role: 'ADMIN',
                  phone: user.phone ?? '+919876543210',
                  fullName: 'Devesh Ambekar',
                );
              } catch (_) {}
            }

            if (mounted) {
              Navigator.of(context).pushReplacementNamed('/admin/home');
            }
            return;
          } else {
            await DI.authRepo.logout();
            setState(() => _errorMsg = 'Unauthorized: Admin role required for ${user.email ?? 'this account'}.');
          }
        } else {
           setState(() => _errorMsg = 'User profile not found.');
        }
      } else {
        setState(() => _errorMsg = 'Invalid admin credentials. Please verify your email and password.');
      }
    } catch (e) {
      String msg = e.toString().replaceAll('Exception: ', '').replaceAll('AuthException(message: ', '');
      if (msg.endsWith(')')) msg = msg.substring(0, msg.length - 1);
      if (msg.toLowerCase().contains('invalid login credentials') || msg.toLowerCase().contains('invalid_credentials')) {
        msg = 'Invalid credentials or unconfirmed email in Supabase. Please verify your password in Supabase or run the admin setup SQL in Supabase SQL Editor.';
      }
      setState(() => _errorMsg = msg);
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
                    const SizedBox(height: AppSpacing.spacingMd),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Test Credentials: Use your admin email (e.g. ambekardevesh2@gmail.com) or admin@shramsetu.demo with password admin123.',
                              style: AppTypography.bodySm.copyWith(fontSize: 11, color: AppColors.primary),
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
      ),
    );
  }
}
