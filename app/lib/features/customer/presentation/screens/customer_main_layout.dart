import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/config/app_config.dart';
import 'customer_home_screen.dart';
import 'customer_bookings_screen.dart';
import 'worker_discovery_screen.dart';
import '../../data/models/customer_profile.dart';

class CustomerMainLayout extends StatefulWidget {
  const CustomerMainLayout({super.key});

  @override
  State<CustomerMainLayout> createState() => _CustomerMainLayoutState();
}

class _CustomerMainLayoutState extends State<CustomerMainLayout> {
  int _currentIndex = 0;
  String _customerName = 'ShramSetu Member';
  String _customerSubtitle = 'Pune District Cooperative Federation';
  String? _customerAvatar;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCustomerProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DI.notificationService.requestPermissions();
    });
  }

  Future<void> _loadCustomerProfile() async {
    try {
      final user = await DI.authRepo.getCurrentUser();
      String? userId = user?.id;
      if (userId == null && !AppConfig.useMockData) {
        try {
          userId = AppConfig.supabaseClient.auth.currentUser?.id;
        } catch (_) {}
      }
      if (userId == null && AppConfig.useMockData) {
        userId = 'mock_customer_01';
      }
      _currentUserId = userId;

      if (userId != null) {
        final profile = await DI.userRepo.getCustomerProfile(userId);
        final userData = await DI.userRepo.getUserProfile(userId);

        if (mounted) {
          setState(() {
            String resolvedName = profile?.fullName.trim() ?? '';
            if (resolvedName.isEmpty || resolvedName.startsWith('User ')) {
              final dbName = (userData?['full_name'] as String?)?.trim() ?? '';
              if (dbName.isNotEmpty && !dbName.startsWith('User ')) {
                resolvedName = dbName;
              }
            }
            if (resolvedName.isEmpty) {
              final metaName = (user?.userMetadata?['full_name'] ?? user?.userMetadata?['name']) as String?;
              if (metaName != null && metaName.trim().isNotEmpty) {
                resolvedName = metaName.trim();
              }
            }
            if (resolvedName.isEmpty) {
              final p = profile?.phone.isNotEmpty == true ? profile!.phone : (user?.phone ?? '');
              resolvedName = p.isNotEmpty ? p : 'Customer';
            }

            _customerName = resolvedName;
            _customerAvatar = profile?.avatarUrl ?? userData?['avatar_url'] as String?;

            final phoneNum = (profile?.phone.isNotEmpty == true) ? profile!.phone : (user?.phone ?? '');
            if (profile?.defaultAddress != null) {
              final addr = profile!.defaultAddress!;
              _customerSubtitle = '${addr.area.isNotEmpty ? addr.area : addr.city}, Pune';
            } else if (phoneNum.isNotEmpty && _customerName != phoneNum) {
              _customerSubtitle = phoneNum;
            } else {
              _customerSubtitle = 'Pune District Cooperative Federation';
            }
          });
        }
      }
    } catch (_) {}
  }

  List<Widget> get _screens => [
    CustomerHomeScreen(onSelectTab: (index) => setState(() => _currentIndex = index)),
    const WorkerDiscoveryScreen(),
    CustomerBookingsScreen(onExploreServices: () => setState(() => _currentIndex = 1)),
    _buildProfileScreen(),
  ];

  void _showSavedAddressesDialog() {
    final userId = _currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading your customer profile, please try again in a moment...')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _SavedAddressesSheet(
        userId: userId,
        customerName: _customerName,
        onAddressChanged: () {
          _loadCustomerProfile();
        },
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
                        backgroundImage: (_customerAvatar != null && _customerAvatar!.isNotEmpty)
                            ? NetworkImage(_customerAvatar!)
                            : null,
                        child: (_customerAvatar == null || _customerAvatar!.isEmpty)
                            ? Text(
                                _customerName.isNotEmpty ? _customerName[0].toUpperCase() : 'C',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_customerName, style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            const SizedBox(height: 2),
                            Text(_customerSubtitle, style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit Profile & Address',
                        icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.outline),
                        onPressed: () async {
                          await Navigator.of(context).pushNamed('/customer/onboarding');
                          _loadCustomerProfile();
                        },
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primaryContainer,
                    backgroundImage: (_customerAvatar != null && _customerAvatar!.isNotEmpty)
                        ? NetworkImage(_customerAvatar!)
                        : null,
                    child: (_customerAvatar == null || _customerAvatar!.isEmpty)
                        ? Text(
                            _customerName.isNotEmpty ? _customerName[0].toUpperCase() : 'C',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMd.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        Text(
                          _customerSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodySm.copyWith(
                            color: AppColors.outline,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
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

class _SavedAddressesSheet extends StatefulWidget {
  final String userId;
  final String customerName;
  final VoidCallback? onAddressChanged;

  const _SavedAddressesSheet({
    required this.userId,
    required this.customerName,
    this.onAddressChanged,
  });

  @override
  State<_SavedAddressesSheet> createState() => _SavedAddressesSheetState();
}

class _SavedAddressesSheetState extends State<_SavedAddressesSheet> {
  List<CustomerAddress> _addresses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAddresses();
  }

  Future<void> _loadAddresses() async {
    setState(() => _isLoading = true);
    try {
      final list = await DI.userRepo.getUserAddresses(widget.userId);
      if (mounted) setState(() => _addresses = list);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _makeDefault(CustomerAddress addr) async {
    try {
      await DI.userRepo.setDefaultAddress(userId: widget.userId, addressId: addr.id);
      widget.onAddressChanged?.call();
      await _loadAddresses();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteAddress(CustomerAddress addr) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Address'),
        content: Text('Are you sure you want to remove "${addr.addressLine}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await DI.userRepo.deleteAddress(userId: widget.userId, addressId: addr.id);
        widget.onAddressChanged?.call();
        await _loadAddresses();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showAddAddressDialog() {
    final lineCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final cityCtrl = TextEditingController(text: 'Pune');
    final pinCtrl = TextEditingController();
    final stateCtrl = TextEditingController(text: 'Maharashtra');

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Add New Address', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: lineCtrl,
                decoration: const InputDecoration(
                  labelText: 'House / Flat / Street *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Flat 301, Silver Oak Society',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: areaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Area / Locality *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Kothrud, Shivajinagar, Baner',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: pinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'PIN Code *',
                        border: OutlineInputBorder(),
                        hintText: '411038',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              if (lineCtrl.text.trim().isEmpty || areaCtrl.text.trim().isEmpty || pinCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(dlgCtx).showSnackBar(
                  const SnackBar(content: Text('Please fill all required fields.')),
                );
                return;
              }
              Navigator.pop(dlgCtx);
              try {
                await DI.userRepo.createAddress(
                  userId: widget.userId,
                  addressLine: lineCtrl.text.trim(),
                  area: areaCtrl.text.trim(),
                  city: cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : 'Pune',
                  state: stateCtrl.text.trim().isNotEmpty ? stateCtrl.text.trim() : 'Maharashtra',
                  postalCode: pinCtrl.text.trim(),
                );
                widget.onAddressChanged?.call();
                await _loadAddresses();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save Address'),
          ),
        ],
      ),
    );
  }

  void _showEditAddressDialog(CustomerAddress addr) {
    final lineCtrl = TextEditingController(text: addr.addressLine);
    final areaCtrl = TextEditingController(text: addr.area);
    final cityCtrl = TextEditingController(text: addr.city.isNotEmpty ? addr.city : 'Pune');
    final pinCtrl = TextEditingController(text: addr.postalCode);
    final stateCtrl = TextEditingController(text: addr.state.isNotEmpty ? addr.state : 'Maharashtra');

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_location_alt_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Edit Address', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: lineCtrl,
                decoration: const InputDecoration(
                  labelText: 'House / Flat / Street *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: areaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Area / Locality *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: pinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'PIN Code *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              if (lineCtrl.text.trim().isEmpty || areaCtrl.text.trim().isEmpty || pinCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(dlgCtx).showSnackBar(
                  const SnackBar(content: Text('Please fill all required fields.')),
                );
                return;
              }
              Navigator.pop(dlgCtx);
              try {
                await DI.userRepo.updateAddress(
                  userId: widget.userId,
                  addressId: addr.id,
                  addressLine: lineCtrl.text.trim(),
                  area: areaCtrl.text.trim(),
                  city: cityCtrl.text.trim().isNotEmpty ? cityCtrl.text.trim() : 'Pune',
                  state: stateCtrl.text.trim().isNotEmpty ? stateCtrl.text.trim() : 'Maharashtra',
                  postalCode: pinCtrl.text.trim(),
                );
                widget.onAddressChanged?.call();
                await _loadAddresses();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: AppColors.primary, size: 24),
                      const SizedBox(width: 8),
                      Text('Saved Addresses', style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Delivery addresses for ${widget.customerName}',
                    style: const TextStyle(fontSize: 12, color: AppColors.outline),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                tooltip: 'Add Address',
                onPressed: _showAddAddressDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_addresses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.location_off_outlined, size: 40, color: AppColors.outline),
                    const SizedBox(height: 8),
                    Text(
                      'No saved addresses for ${widget.customerName}.',
                      style: const TextStyle(color: AppColors.outline, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Add your home or work address below to receive verified artisan services.',
                      style: TextStyle(color: AppColors.outline, fontSize: 11),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Delivery Address'),
                      onPressed: _showAddAddressDialog,
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _addresses.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final addr = _addresses[i];
                  final isHome = addr.area.toLowerCase().contains('home') || i == 0;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: addr.isDefault ? AppColors.primaryContainer : AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isHome ? Icons.home_outlined : Icons.location_on_outlined,
                        color: addr.isDefault ? AppColors.primary : AppColors.outline,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            addr.area.isNotEmpty ? addr.area : addr.city,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: addr.isDefault ? AppColors.primary : AppColors.onSurface,
                            ),
                          ),
                        ),
                        if (addr.isDefault)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.tertiaryContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('DEFAULT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.onTertiaryContainer)),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(addr.addressLine, style: const TextStyle(fontSize: 12)),
                        Text('${addr.city}, ${addr.state} - ${addr.postalCode}', style: const TextStyle(fontSize: 11, color: AppColors.outline)),
                      ],
                    ),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 18, color: AppColors.outline),
                      onSelected: (val) {
                        if (val == 'default') _makeDefault(addr);
                        if (val == 'edit') _showEditAddressDialog(addr);
                        if (val == 'delete') _deleteAddress(addr);
                      },
                      itemBuilder: (_) => [
                        if (!addr.isDefault)
                          const PopupMenuItem(value: 'default', child: Row(children: [Icon(Icons.check, size: 16), SizedBox(width: 8), Text('Set as Default')])),
                        const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 16), SizedBox(width: 8), Text('Edit Address')])),
                        const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: AppColors.error), SizedBox(width: 8), Text('Delete', style: TextStyle(color: AppColors.error))])),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Another Address'),
              onPressed: _showAddAddressDialog,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary),
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }
}

