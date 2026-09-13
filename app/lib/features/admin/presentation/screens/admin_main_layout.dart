import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'admin_dashboard_screen.dart';
import 'admin_services_screen.dart';
import 'admin_bookings_screen.dart';
import 'admin_payments_screen.dart';
import 'admin_profile_screen.dart';

class AdminMainLayout extends StatefulWidget {
  const AdminMainLayout({super.key});

  @override
  State<AdminMainLayout> createState() => _AdminMainLayoutState();
}

class _AdminMainLayoutState extends State<AdminMainLayout> {
  int _currentIndex = 2; // Default to Coop Hub (Dashboard)

  final List<Widget> _screens = [
    const AdminServicesScreen(),
    const AdminBookingsScreen(),
    const AdminDashboardScreen(),
    const AdminPaymentsScreen(),
    const AdminProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.9),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, -2),
              blurRadius: 12,
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.handyman_outlined, Icons.handyman, 'Services'),
                _buildNavItem(1, Icons.assignment_outlined, Icons.assignment, 'Bookings'),
                _buildNavItem(2, Icons.corporate_fare_outlined, Icons.corporate_fare, 'Coop Hub'),
                _buildNavItem(3, Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Wallet'),
                _buildNavItem(4, Icons.badge_outlined, Icons.badge, 'Member'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData iconOutlined, IconData iconFilled, String label) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? iconFilled : iconOutlined,
              color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
