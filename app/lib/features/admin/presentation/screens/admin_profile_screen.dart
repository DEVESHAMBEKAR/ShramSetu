import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/config/dependency_injection.dart';
import 'admin_workers_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_complaints_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_welfare_screen.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  String _adminName = 'Federation Administrator';
  String _adminEmail = 'admin@shramsetu.in';
  String _adminRole = 'Level 3 Federation Admin';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    try {
      final user = await DI.authRepo.getCurrentUser();
      if (user != null) {
        final dbUser = await DI.userRepo.getUserProfile(user.id);
        if (mounted) {
          setState(() {
            final name = (dbUser?['full_name'] as String?)?.trim() ??
                (user.userMetadata?['full_name'] as String?)?.trim() ??
                (user.email != null ? user.email!.split('@').first : '');
            if (name.isNotEmpty && !name.startsWith('User ')) {
              _adminName = name;
            } else if (user.email != null && user.email!.isNotEmpty) {
              _adminName = 'Admin (${user.email!.split('@').first})';
            } else {
              _adminName = 'Federation Administrator';
            }

            _adminEmail = (dbUser?['email'] as String?) ??
                user.email ??
                (dbUser?['phone'] as String?) ??
                user.phone ??
                'admin@shramsetu.in';

            final roleStr = (dbUser?['role'] as String?) ?? 'ADMIN';
            _adminRole = 'Verified $roleStr Administrator';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Admin Profile & Settings', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.marginMobile),
            child: Column(
              children: [
                _buildProfileCard(),
                const SizedBox(height: AppSpacing.spacingLg),
                _buildMenuCard(context),
                const SizedBox(height: AppSpacing.spacingLg),
                _buildLogoutButton(context),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    final initials = _adminName.isNotEmpty
        ? _adminName.trim().split(' ').map((s) => s.isNotEmpty ? s[0] : '').take(2).join().toUpperCase()
        : 'AD';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.radiusXl,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.onPrimary),
            ),
          ),
          const SizedBox(width: AppSpacing.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_adminName, style: AppTypography.headlineSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                Text(_adminEmail, style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: AppRadius.radiusFull),
                  child: Text(_adminRole, style: AppTypography.labelSm.copyWith(color: AppColors.onPrimaryContainer)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.radiusXl,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: Column(
        children: [
          _buildMenuItem(context, Icons.engineering, 'Worker Management', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminWorkersScreen()))),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(context, Icons.group, 'Customer Management', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCustomersScreen()))),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(context, Icons.support_agent, 'Complaints & Support', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminComplaintsScreen()))),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(context, Icons.volunteer_activism, 'Welfare & Benefits', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminWelfareScreen()))),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(context, Icons.analytics, 'Platform Analytics', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen()))),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title, style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.outline),
      onTap: onTap,
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          await DI.authRepo.logout();
          if (context.mounted) {
            Navigator.of(context).pushReplacementNamed('/onboarding');
          }
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.spacingMd),
          side: const BorderSide(color: AppColors.error),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
        ),
        child: Text('Sign Out', style: AppTypography.labelLg.copyWith(color: AppColors.error, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
