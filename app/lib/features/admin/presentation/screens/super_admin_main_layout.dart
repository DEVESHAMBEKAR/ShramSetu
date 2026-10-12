import 'package:flutter/material.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import 'super_admin_dashboard_screen.dart';
import 'super_admin_federations_screen.dart';
import 'super_admin_audit_log_screen.dart';
import 'admin_workers_screen.dart';
import 'admin_customers_screen.dart';
import 'admin_profile_screen.dart';

/// Super Admin Console — dedicated layout separate from the Federation Admin.
/// This is the national-level administration interface for ShramSetu.
/// Accessible only to users with SUPER_ADMIN role.
class SuperAdminMainLayout extends StatefulWidget {
  const SuperAdminMainLayout({super.key});

  @override
  State<SuperAdminMainLayout> createState() => _SuperAdminMainLayoutState();
}

class _SuperAdminMainLayoutState extends State<SuperAdminMainLayout> {
  int _currentIndex = 0;
  String _adminName = 'Super Admin';
  String _adminEmail = '';

  @override
  void initState() {
    super.initState();
    _loadAdminInfo();
  }

  Future<void> _loadAdminInfo() async {
    try {
      final user = await DI.authRepo.getCurrentUser();
      if (user != null) {
        final dbUser = await DI.userRepo.getUserProfile(user.id);
        if (mounted) {
          setState(() {
            _adminName = (dbUser?['full_name'] as String?)?.trim() ??
                (user.userMetadata?['full_name'] as String?)?.trim() ??
                'Super Admin';
            _adminEmail = user.email ?? '';
          });
        }
      }
    } catch (_) {}
  }

  final List<Widget> _screens = [
    const SuperAdminDashboardScreen(),
    const SuperAdminFederationsScreen(),
    const AdminWorkersScreen(isSuperAdmin: true),
    const AdminCustomersScreen(isSuperAdmin: true),
    const SuperAdminAuditLogScreen(),
    const AdminProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    if (isWide) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        body: Row(
          children: [
            _buildDesktopSidebar(),
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF111827),
          border: const Border(top: BorderSide(color: Color(0xFF1F2937))),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard, 'Overview'),
                _buildNavItem(1, Icons.corporate_fare_outlined, Icons.corporate_fare, 'Federations'),
                _buildNavItem(2, Icons.groups_outlined, Icons.groups, 'Workers'),
                _buildNavItem(3, Icons.people_outline, Icons.people, 'Customers'),
                _buildNavItem(4, Icons.history_outlined, Icons.history, 'Audit'),
                _buildNavItem(5, Icons.settings_outlined, Icons.settings, 'Settings'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color: isActive ? AppColors.secondaryContainer : Colors.white38,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.secondaryContainer : Colors.white38,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 260,
      color: const Color(0xFF0F1320),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryContainer.withValues(alpha: 0.15),
                    borderRadius: AppRadius.radiusSm,
                  ),
                  child: const Icon(Icons.shield, color: AppColors.secondaryContainer, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ShramSetu',
                        style: AppTypography.titleMd.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Super Admin',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.secondaryContainer,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0xFF1F2937), height: 1),
          const SizedBox(height: 8),
          // Navigation
          _buildSidebarItem(0, Icons.dashboard, 'Dashboard'),
          _buildSidebarItem(1, Icons.corporate_fare, 'Federations'),
          _buildSidebarItem(2, Icons.groups, 'All Workers'),
          _buildSidebarItem(3, Icons.people, 'Customers'),
          _buildSidebarItem(4, Icons.history, 'Audit Logs'),
          _buildSidebarItem(5, Icons.settings, 'Settings'),
          const Spacer(),
          // Admin info
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: AppRadius.radiusMd,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.secondaryContainer.withValues(alpha: 0.2),
                  child: const Icon(Icons.shield, color: AppColors.secondaryContainer, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _adminName,
                        style: AppTypography.labelMd.copyWith(color: Colors.white, fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _adminEmail,
                        style: AppTypography.labelSm.copyWith(color: Colors.white38, fontSize: 9),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AppColors.secondaryContainer.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: AppRadius.radiusSm,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? AppColors.secondaryContainer : Colors.white38),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTypography.bodyMd.copyWith(
                color: isActive ? Colors.white : Colors.white54,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
