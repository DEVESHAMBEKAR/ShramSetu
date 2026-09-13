import 'package:app/core/config/dependency_injection.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import 'admin_workers_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_complaints_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_welfare_screen.dart';
import '../../data/repositories/mock_admin_repository.dart';

class AdminProfileScreen extends StatelessWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Admin Profile & Settings', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: SingleChildScrollView(
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
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.shield, color: AppColors.onPrimary, size: 36),
          ),
          const SizedBox(width: AppSpacing.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Admin Superuser', style: AppTypography.headlineSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                Text('admin@shramsetu.demo', style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: AppRadius.radiusFull),
                  child: Text('Level 3 Federation Admin', style: AppTypography.labelSm.copyWith(color: AppColors.onPrimaryContainer)),
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
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
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

