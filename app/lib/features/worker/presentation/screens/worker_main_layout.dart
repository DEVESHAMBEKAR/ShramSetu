import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import 'worker_dashboard_screen.dart';
import 'worker_job_requests_screen.dart';
import 'worker_earnings_screen.dart';
import 'worker_profile_settings_screen.dart';

class WorkerMainLayout extends StatefulWidget {
  const WorkerMainLayout({super.key});

  @override
  State<WorkerMainLayout> createState() => _WorkerMainLayoutState();
}

class _WorkerMainLayoutState extends State<WorkerMainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const WorkerDashboardScreen(),
    const WorkerJobRequestsScreen(),
    const WorkerEarningsScreen(),
    const WorkerProfileSettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withValues(alpha: 0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -1),
            )
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.work, 'Home'),
                _buildNavItem(1, Icons.event_available, 'Jobs'),
                _buildNavItem(2, Icons.account_balance_wallet, 'Earnings'),
                _buildNavItem(3, Icons.account_circle, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.secondary : AppColors.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        width: 64,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: AppSpacing.spacing4xs),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
