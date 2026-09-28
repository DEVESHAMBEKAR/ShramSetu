import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/config/dependency_injection.dart';
import 'customer_home_screen.dart';
import 'customer_bookings_screen.dart';
import 'worker_discovery_screen.dart';

class CustomerMainLayout extends StatefulWidget {
  const CustomerMainLayout({super.key});

  @override
  State<CustomerMainLayout> createState() => _CustomerMainLayoutState();
}

class _CustomerMainLayoutState extends State<CustomerMainLayout> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DI.notificationService.requestPermissions();
    });
  }

  late final List<Widget> _screens = [
    CustomerHomeScreen(onSelectTab: (index) => setState(() => _currentIndex = index)),
    const WorkerDiscoveryScreen(),
    CustomerBookingsScreen(onExploreServices: () => setState(() => _currentIndex = 1)),
    _buildProfileScreen(),
  ];

  void _showSavedAddressesDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Text('Saved Addresses', style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.home, color: AppColors.primary),
              title: const Text('Home - Model Colony', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Flat 402, Shanti Heights, Shivajinagar, Pune 411016'),
              trailing: const Icon(Icons.check_circle, color: AppColors.primary),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.work_outline, color: AppColors.outline),
              title: const Text('Workplace / Office', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Quadron Business Park, Hinjewadi Phase 2, Pune 411057'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.translate, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Text('Language / भाषा / भाषा निवडा', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.radio_button_checked, color: AppColors.primary),
              title: const Text('English (Default)', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.radio_button_unchecked, color: AppColors.outline),
              title: const Text('मराठी (Marathi)'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.radio_button_unchecked, color: AppColors.outline),
              title: const Text('हिंदी (Hindi)'),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showWelfareGuaranteeDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.shield, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Text('Cooperative Welfare Guarantee', style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '1. 100% Zero Surge: Union standard rates with no peak surge.\n'
              '2. Escrow Protection: Payment released to artisan only with your OTP.\n'
              '3. Insurance Bond: ₹10,000 cooperative transit & accidental damage guarantee.\n'
              '4. Verified Workers: Police verified & federation certified trade artisans.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant, height: 1.6),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpSupportDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.headset_mic, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                Text('Union Help & Support', style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.phone, color: AppColors.primary),
              title: const Text('Toll-Free Helpline', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('1800-266-9090 (24x7)'),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.email, color: AppColors.primary),
              title: const Text('Email Support', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('support@shramsetu.in'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileScreen() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Account & Settings', style: AppTypography.titleLg.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.radiusXl,
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.surfaceContainerLow,
                        child: const Icon(Icons.person, size: 30, color: AppColors.primary),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ShramSetu Member', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            const SizedBox(height: 2),
                            Text('Pune District Cooperative Federation', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildProfileTile(Icons.location_on_outlined, 'Saved Addresses', 'Manage home and work addresses', onTap: _showSavedAddressesDialog),
                _buildProfileTile(Icons.translate, 'Language Settings', 'मराठी / English / हिंदी', onTap: _showLanguageDialog),
                _buildProfileTile(Icons.shield_outlined, 'Cooperative Welfare Guarantee', 'Direct deposit & damage protection policy', onTap: _showWelfareGuaranteeDialog),
                _buildProfileTile(Icons.headset_mic_outlined, 'Union Help & Support', '1800-266-9090 (Toll free)', onTap: _showHelpSupportDialog),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.errorContainer),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                    ),
                    onPressed: () async {
                      await DI.authRepo.logout();
                      if (mounted) Navigator.of(context).pushReplacementNamed('/onboarding');
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Logout from ShramSetu'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTile(IconData icon, String title, String subtitle, {VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radiusLg,
        child: InkWell(
          borderRadius: AppRadius.radiusLg,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.labelLg.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                      Text(subtitle, style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.outline, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    if (isWide) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            _buildDesktopSidebar(),
            Expanded(child: _screens[_currentIndex]),
          ],
        ),
      );
    }

    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.outlineVariant, width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
                _buildNavItem(1, Icons.grid_view_outlined, Icons.grid_view, 'Services'),
                _buildNavItem(2, Icons.calendar_month_outlined, Icons.calendar_month, 'Bookings', hasBadge: true),
                _buildNavItem(3, Icons.account_circle_outlined, Icons.account_circle, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.outlineVariant, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.handyman, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ShramSetu',
                        style: AppTypography.titleMd.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        'Service Marketplace',
                        style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.outlineVariant),
          const SizedBox(height: 16),
          _buildDesktopNavItem(0, Icons.home_outlined, Icons.home, 'Home'),
          _buildDesktopNavItem(1, Icons.grid_view_outlined, Icons.grid_view, 'Services'),
          _buildDesktopNavItem(2, Icons.calendar_month_outlined, Icons.calendar_month, 'My Bookings'),
          _buildDesktopNavItem(3, Icons.account_circle_outlined, Icons.account_circle, 'Profile & Settings'),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.outlineVariant),
                ),
                onPressed: () async {
                  await DI.authRepo.logout();
                  if (mounted) Navigator.of(context).pushReplacementNamed('/onboarding');
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign Out'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopNavItem(int index, IconData iconOutlined, IconData iconFilled, String label) {
    final isSelected = _currentIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.transparent,
        leading: Icon(
          isSelected ? iconFilled : iconOutlined,
          color: isSelected ? AppColors.primary : AppColors.outline,
        ),
        title: Text(
          label,
          style: AppTypography.labelLg.copyWith(
            color: isSelected ? AppColors.primary : AppColors.outline,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: () => setState(() => _currentIndex = index),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData iconOutlined, IconData iconFilled, String label, {bool hasBadge = false}) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? iconFilled : iconOutlined,
                  color: isSelected ? AppColors.primary : AppColors.outline,
                  size: 22,
                ),
                if (hasBadge && !isSelected)
                  Positioned(
                    top: -1,
                    right: -2,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.labelSm.copyWith(
                color: isSelected ? AppColors.primary : AppColors.outline,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
