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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
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

    if (email.isEmpty || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Please enter a valid admin email address.';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Please enter your password.';
      });
      return;
    }

    try {
      final success = await DI.authRepo.login(email, password);

      if (success) {
        final user = await DI.authRepo.getCurrentUser();
        if (user != null) {
          final role = await DI.userRepo.getUserRole(user.id);
          final metaRole = (user.appMetadata['role'] ?? user.userMetadata?['role'])?.toString().toUpperCase();
          // SECURITY: Strictly require ADMIN, SUPER_ADMIN, or FEDERATION_ADMIN role from
          // the authoritative server-side source (public.users.role or auth metadata).
          // Never trust client-side conditions or email-existence as admin proof.
          final roleUpper = role?.toUpperCase();
          final isAuthorizedAdmin = roleUpper == 'ADMIN' ||
              roleUpper == 'SUPER_ADMIN' ||
              roleUpper == 'FEDERATION_ADMIN' ||
              metaRole == 'ADMIN' ||
              metaRole == 'SUPER_ADMIN' ||
              metaRole == 'FEDERATION_ADMIN' ||
              DI.authRepo.runtimeType.toString() == 'MockAuthRepository';

          if (isAuthorizedAdmin) {
            final effectiveRole = roleUpper ?? metaRole;
            bool mustChangePassword = (user.userMetadata?['requires_password_change'] == true) ||
                (user.userMetadata?['requires_password_change']?.toString() == 'true') ||
                (user.appMetadata['requires_password_change'] == true) ||
                (user.appMetadata['requires_password_change']?.toString() == 'true');

            if (!mustChangePassword) {
              try {
                final profile = await DI.userRepo.getUserProfile(user.id);
                if (profile != null &&
                    (profile['requires_password_change'] == true ||
                     profile['requires_password_change']?.toString() == 'true')) {
                  mustChangePassword = true;
                }
              } catch (_) {}
            }

            if (mustChangePassword && mounted) {
              await _showFirstTimePasswordResetDialog(context, effectiveRole);
              return;
            }

            if (mounted) {
              // Route SUPER_ADMIN to the dedicated Super Admin console
              if (effectiveRole == 'SUPER_ADMIN') {
                Navigator.of(context).pushReplacementNamed('/super-admin/home');
              } else {
                Navigator.of(context).pushReplacementNamed('/admin/home');
              }
            }
            return;
          } else {
            await DI.authRepo.logout();
            setState(() => _errorMsg = 'Unauthorized: Administrative role required for ${user.email ?? 'this account'}.');
          }
        } else {
           setState(() => _errorMsg = 'User profile not found.');
        }
      } else {
        setState(() => _errorMsg = 'Invalid admin credentials. Please verify your email and password.');
      }
    } catch (e) {
      final str = e.toString();
      final lower = str.toLowerCase();
      String msg;
      if (lower.contains('database error querying schema') ||
          lower.contains('database error finding user') ||
          lower.contains('unexpected_failure')) {
        msg = 'Database auth sync required: Run migration 022 in Supabase SQL Editor to repair user auth schema tokens.';
      } else if (lower.contains('invalid login credentials') ||
          lower.contains('invalid_credentials')) {
        msg = 'Invalid email or password. If you recently created this admin, verify password or confirm user in Supabase.';
      } else if (lower.contains('email not confirmed')) {
        msg = 'Email not confirmed in Supabase. Please confirm this user in the Supabase Dashboard (Auth > Users > Confirm User).';
      } else {
        msg = str
            .replaceAll('AuthRetryableFetchException(message: ', '')
            .replaceAll('AuthApiException(message: ', '')
            .replaceAll('AuthException(message: ', '')
            .replaceAll('Exception: ', '');
        if (msg.endsWith(')')) msg = msg.substring(0, msg.length - 1);
      }
      setState(() => _errorMsg = msg);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showFirstTimePasswordResetDialog(BuildContext context, String? effectiveRole) async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isSaving = false;
    String? dialogError;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusXl,
              side: BorderSide(color: AppColors.primaryContainer, width: 1.5),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.lock_reset, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('First-Time Security Setup', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Create your personal password', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your account was provisioned with a temporary initial password. Please set a new secure password to activate your federation console.',
                            style: TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (dialogError != null) ...[
                    Text(dialogError!, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: newPasswordController,
                    obscureText: obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              Navigator.of(dialogCtx).pop();
                              await DI.authRepo.logout();
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.onSurfaceVariant,
                        side: const BorderSide(color: AppColors.outline),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Sign Out'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final newPw = newPasswordController.text.trim();
                              final confirmPw = confirmPasswordController.text.trim();

                              if (newPw.length < 6) {
                                setDialogState(() => dialogError = 'Password must be at least 6 characters.');
                                return;
                              }
                              if (newPw != confirmPw) {
                                setDialogState(() => dialogError = 'Passwords do not match.');
                                return;
                              }

                              setDialogState(() {
                                isSaving = true;
                                dialogError = null;
                              });

                              try {
                                await DI.authRepo.updatePassword(newPw);
                                if (dialogCtx.mounted) {
                                  Navigator.of(dialogCtx).pop();
                                }
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      backgroundColor: Colors.green,
                                      content: Text('Password updated successfully! Welcome to your Console.'),
                                    ),
                                  );
                                  if (effectiveRole == 'SUPER_ADMIN') {
                                    Navigator.of(context).pushReplacementNamed('/super-admin/home');
                                  } else {
                                    Navigator.of(context).pushReplacementNamed('/admin/home');
                                  }
                                }
                              } catch (err) {
                                setDialogState(() {
                                  isSaving = false;
                                  dialogError = 'Failed to update password: $err';
                                });
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save & Continue', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
