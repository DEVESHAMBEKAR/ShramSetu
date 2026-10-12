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
import '../../../../core/localization/locale_controller.dart';
import '../../../../core/localization/app_strings.dart';
import '../../../../core/services/india_geography_service.dart';

class CustomerMainLayout extends StatefulWidget {
  const CustomerMainLayout({super.key});

  @override
  State<CustomerMainLayout> createState() => _CustomerMainLayoutState();
}

class _CustomerMainLayoutState extends State<CustomerMainLayout> {
  int _currentIndex = 0;
  String _customerName = 'ShramSetu Member';
  String _customerSubtitle = 'Labour Cooperative Federation';
  String? _customerFederationName;
  String? _customerAvatar;
  String? _customerPhone;
  String? _customerEmail;
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

          setState(() {
            String resolvedName = profile?.fullName.trim() ?? '';
            final isPlaceholder = resolvedName.isEmpty ||
                resolvedName.startsWith('User ') ||
                RegExp(r'^\+?\d{10,13}$').hasMatch(resolvedName) ||
                resolvedName.toLowerCase() == 'demo user' ||
                resolvedName.toLowerCase() == 'test user' ||
                resolvedName.toLowerCase() == 'ananya';

            if (isPlaceholder) {
              final dbName = (userData?['full_name'] as String?)?.trim() ?? '';
              if (dbName.isNotEmpty &&
                  !dbName.startsWith('User ') &&
                  !RegExp(r'^\+?\d{10,13}$').hasMatch(dbName) &&
                  dbName.toLowerCase() != 'demo user' &&
                  dbName.toLowerCase() != 'test user') {
                resolvedName = dbName;
              } else {
                final metaName = (user?.userMetadata?['full_name'] ?? user?.userMetadata?['name']) as String?;
                if (metaName != null &&
                    metaName.trim().isNotEmpty &&
                    !RegExp(r'^\+?\d{10,13}$').hasMatch(metaName.trim())) {
                  resolvedName = metaName.trim();
                }
              }
            }

            if (resolvedName.isEmpty || RegExp(r'^\+?\d{10,13}$').hasMatch(resolvedName)) {
              final metaName = (user?.userMetadata?['full_name'] ?? user?.userMetadata?['name']) as String?;
              if (metaName != null &&
                  metaName.trim().isNotEmpty &&
                  !RegExp(r'^\+?\d{10,13}$').hasMatch(metaName.trim())) {
                resolvedName = metaName.trim();
              } else {
                resolvedName = 'Add Your Name';
              }
            }

            _customerName = resolvedName;
            _customerAvatar = profile?.avatarUrl ?? userData?['avatar_url'] as String?;
            _customerFederationName = (profile?.federationName?.isNotEmpty == true)
                ? profile?.federationName
                : null;

            final phoneNum = (profile?.phone.isNotEmpty == true)
                ? profile!.phone
                : (user?.phone ?? ((userData?['phone'] as String?) ?? ''));
            final emailAddr = (profile?.email != null && profile!.email!.isNotEmpty)
                ? profile.email!
                : ((user?.email != null && user!.email!.isNotEmpty)
                    ? user.email!
                    : (((userData?['email'] as String?)?.isNotEmpty == true)
                        ? (userData!['email'] as String)
                        : (user?.userMetadata?['email'] as String? ?? '')));
            _customerPhone = phoneNum;
            _customerEmail = emailAddr;

            if (profile?.defaultAddress != null) {
              final addr = profile!.defaultAddress!;
              final areaPart = addr.area.isNotEmpty ? addr.area : addr.city;
              _customerSubtitle = addr.city.isNotEmpty && addr.city != areaPart
                  ? '$areaPart, ${addr.city}'
                  : areaPart;
            } else if (phoneNum.isNotEmpty && _customerName != phoneNum) {
              _customerSubtitle = phoneNum;
            } else {
              _customerSubtitle = _customerFederationName ?? 'Cooperative Network';
            }
          });
        }
      } catch (_) {}
  }

  List<Widget> get _screens => [
    CustomerHomeScreen(onSelectTab: (index) => setState(() => _currentIndex = index)),
    const WorkerDiscoveryScreen(),
    CustomerBookingsScreen(onExploreServices: () => setState(() => _currentIndex = 1)),
    _buildProfileScreen(),
  ];

  void _showEditCredentialsDialog() {
    final userId = _currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading customer profile, please try again in a moment...')),
      );
      return;
    }

    final initialName = RegExp(r'^\+?\d{10,13}$').hasMatch(_customerName) ? '' : _customerName;
    final nameCtrl = TextEditingController(text: initialName);
    final emailCtrl = TextEditingController(text: _customerEmail ?? '');
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Update Credentials',
                              style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Ensure your full name and email are up to date for verified cooperative bookings.',
                      style: AppTypography.bodySm.copyWith(color: AppColors.outline),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Full Name *',
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        if (val.trim().length < 2) {
                          return 'Please enter a valid full name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Address *',
                        hintText: 'e.g. name@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Email address is required';
                        }
                        final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                        if (!emailRegex.hasMatch(val.trim())) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      initialValue: _customerPhone,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Registered Mobile',
                        prefixIcon: Icon(Icons.phone_android),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setSheetState(() => isSaving = true);
                                try {
                                  await DI.userRepo.updateCustomerProfile(
                                    userId: userId,
                                    fullName: nameCtrl.text.trim(),
                                    email: emailCtrl.text.trim(),
                                    phone: _customerPhone,
                                  );
                                  if (context.mounted) {
                                    Navigator.of(dialogCtx).pop();
                                    setState(() {
                                      _customerName = nameCtrl.text.trim();
                                      _customerEmail = emailCtrl.text.trim();
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Account credentials updated successfully!'),
                                        backgroundColor: Color(0xFF2E7D32),
                                      ),
                                    );
                                    await _loadCustomerProfile();
                                  }
                                } catch (e) {
                                  setSheetState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to update: $e')),
                                  );
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Save Credentials', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton.icon(
                        icon: const Icon(Icons.edit_location_alt_outlined, size: 16),
                        label: const Text('Need to change address or location?'),
                        onPressed: () async {
                          Navigator.of(dialogCtx).pop();
                          await Navigator.of(context).pushNamed('/customer/onboarding');
                          _loadCustomerProfile();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

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
      builder: (ctx) {
        final currentCode = LocaleController.instance.languageCode;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.translate, color: AppColors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text('Select Language / भाषा निवडा'.tr(), style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(
                  currentCode == 'en' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: currentCode == 'en' ? AppColors.primary : AppColors.outline,
                ),
                title: const Text('English (Default)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Standard interface'),
                onTap: () {
                  LocaleController.instance.setLanguage('en');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(
                  currentCode == 'mr' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: currentCode == 'mr' ? AppColors.primary : AppColors.outline,
                ),
                title: const Text('मराठी (Marathi)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('स्थानिक युनियन भाषा'),
                onTap: () {
                  LocaleController.instance.setLanguage('mr');
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: Icon(
                  currentCode == 'hi' ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: currentCode == 'hi' ? AppColors.primary : AppColors.outline,
                ),
                title: const Text('हिंदी (Hindi)', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('राष्ट्रभाषा'),
                onTap: () {
                  LocaleController.instance.setLanguage('hi');
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
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
                            ? (_customerName == 'Add Your Name' || RegExp(r'^\+?\d+$').hasMatch(_customerName)
                                ? const Icon(Icons.person_outline, size: 26, color: AppColors.primary)
                                : Text(
                                    _customerName.isNotEmpty ? _customerName[0].toUpperCase() : 'C',
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ))
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _customerName,
                              style: AppTypography.titleMd.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _customerName == 'Add Your Name' ? AppColors.outline : AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _customerName == 'Add Your Name' ? 'Tap edit icon to add your name & email' : _customerSubtitle,
                              style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit Profile & Credentials',
                        icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.outline),
                        onPressed: _showEditCredentialsDialog,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.radiusXl,
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _customerFederationName != null
                                  ? AppColors.primaryContainer
                                  : const Color(0xFFFFF8E1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _customerFederationName != null ? Icons.account_balance : Icons.access_time_filled,
                              color: _customerFederationName != null ? AppColors.primary : const Color(0xFFE65100),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      _customerFederationName != null
                                          ? 'ASSIGNED COOPERATIVE FEDERATION'
                                          : 'COOPERATIVE EXPANSION ZONE',
                                      style: AppTypography.labelSm.copyWith(
                                        color: _customerFederationName != null ? AppColors.primary : const Color(0xFFE65100),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _customerFederationName != null
                                            ? const Color(0xFFE8F5E9)
                                            : const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: _customerFederationName != null
                                              ? const Color(0xFF81C784)
                                              : const Color(0xFFFFB74D),
                                        ),
                                      ),
                                      child: Text(
                                        _customerFederationName != null ? 'Jurisdiction Assigned' : 'Coming Soon',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: _customerFederationName != null
                                              ? const Color(0xFF2E7D32)
                                              : const Color(0xFFE65100),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _customerFederationName ?? 'No Active Cooperative Union Yet',
                                  style: AppTypography.titleMd.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: AppColors.outlineVariant),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            _customerFederationName != null ? Icons.shield_outlined : Icons.info_outline,
                            size: 14,
                            color: _customerFederationName != null ? AppColors.primary : const Color(0xFFE65100),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _customerFederationName != null
                                  ? 'All artisan bookings from your location are guaranteed by this federation with 0% middleman cut and direct dispute resolution.'
                                  : 'Artisans and cooperative coverage are expanding to your district. You will be notified when bookings go live.',
                              style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Account Credentials Card (Required Mobile & Email)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: AppRadius.radiusXl,
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'ACCOUNT CREDENTIALS',
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF81C784)),
                            ),
                            child: const Text(
                              'Required Credentials',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2E7D32)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.phone_android, size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Mobile Number *', style: TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.w600)),
                                  Text(
                                    (_customerPhone != null && _customerPhone!.isNotEmpty) ? _customerPhone! : 'Not linked (Required)',
                                    style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 18, color: AppColors.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Email Address *', style: TextStyle(fontSize: 10, color: AppColors.outline, fontWeight: FontWeight.w600)),
                                  Text(
                                    (_customerEmail != null && _customerEmail!.isNotEmpty) ? _customerEmail! : 'Not linked (Required)',
                                    style: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            if (_customerEmail != null && _customerEmail!.isNotEmpty)
                              const Icon(Icons.check_circle, size: 16, color: Color(0xFF2E7D32))
                            else
                              const Text('Action Required', style: TextStyle(fontSize: 10, color: AppColors.error, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.outlineVariant),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: _showEditCredentialsDialog,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Update Credentials & Address', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _buildProfileTile(Icons.location_on_outlined, 'Saved Addresses'.tr(), 'Manage home and work addresses'.tr(), onTap: _showSavedAddressesDialog),
                _buildProfileTile(Icons.translate, 'Language Settings'.tr(), 'मराठी / English / हिंदी', onTap: _showLanguageDialog),
                _buildProfileTile(Icons.shield_outlined, 'Cooperative Welfare Guarantee'.tr(), 'Direct deposit & damage protection policy'.tr(), onTap: _showWelfareGuaranteeDialog),
                _buildProfileTile(Icons.headset_mic_outlined, 'Union Help & Support'.tr(), '1800-266-9090 (Toll free)', onTap: _showHelpSupportDialog),
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
                    label: Text('Logout from ShramSetu'.tr()),
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
    return ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (context, _) {
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
                height: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.account_balance_outlined, Icons.account_balance, 'Home'.tr()),
                    _buildNavItem(1, Icons.handyman_outlined, Icons.handyman, 'Services'.tr()),
                    _buildNavItem(2, Icons.verified_user_outlined, Icons.verified_user, 'Bookings'.tr(), hasBadge: true),
                    _buildNavItem(3, Icons.badge_outlined, Icons.badge, 'Profile'.tr()),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
          _buildDesktopNavItem(0, Icons.home_outlined, Icons.home, 'Home'.tr()),
          _buildDesktopNavItem(1, Icons.grid_view_outlined, Icons.grid_view, 'Services'.tr()),
          _buildDesktopNavItem(2, Icons.calendar_month_outlined, Icons.calendar_month, 'My Bookings'.tr()),
          _buildDesktopNavItem(3, Icons.account_circle_outlined, Icons.account_circle, 'Profile & Settings'.tr()),
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
                        ? (_customerName == 'Add Your Name' || RegExp(r'^\+?\d+$').hasMatch(_customerName)
                            ? const Icon(Icons.person_outline, size: 18, color: AppColors.primary)
                            : Text(
                                _customerName.isNotEmpty ? _customerName[0].toUpperCase() : 'C',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ))
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
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isSelected ? iconFilled : iconOutlined,
                  color: isSelected ? AppColors.secondary : AppColors.onSurfaceVariant,
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
                        color: AppColors.secondaryContainer,
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
                color: isSelected ? AppColors.secondary : AppColors.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 14,
              height: 2,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.secondaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(1),
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
    final pinCtrl = TextEditingController();

    String selectedState = 'Maharashtra';
    String selectedDistrict = 'Pune';
    List<String> availableDistricts = IndiaGeographyService.getDistricts(selectedState);
    List<String> availableAreas = IndiaGeographyService.getAreasForDistrict(selectedState, selectedDistrict);
    String selectedArea = availableAreas.isNotEmpty ? availableAreas.first : 'Kothrud';
    bool isResolvingPincode = false;
    String? pincodeFeedback;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) {
          Future<void> handlePincode(String val) async {
            final clean = val.replaceAll(RegExp(r'\D'), '').trim();
            if (clean.length == 6) {
              setDlgState(() {
                isResolvingPincode = true;
                pincodeFeedback = 'Resolving location...';
              });
              final res = await IndiaGeographyService.lookupPincode(clean);
              if (res != null) {
                setDlgState(() {
                  selectedState = res.state;
                  availableDistricts = IndiaGeographyService.getDistricts(res.state);
                  selectedDistrict = availableDistricts.contains(res.district)
                      ? res.district
                      : (availableDistricts.isNotEmpty ? availableDistricts.first : res.district);
                  final areas = res.areas.isNotEmpty
                      ? res.areas
                      : IndiaGeographyService.getAreasForDistrict(selectedState, selectedDistrict);
                  availableAreas = areas;
                  selectedArea = areas.isNotEmpty ? areas.first : res.city;
                  isResolvingPincode = false;
                  pincodeFeedback = 'Detected: $selectedDistrict, $selectedState (${res.isFromNetwork ? "Live Post Office" : "Postal Directory"})';
                });
              } else {
                setDlgState(() {
                  isResolvingPincode = false;
                  pincodeFeedback = null;
                });
              }
            } else {
              if (pincodeFeedback != null) {
                setDlgState(() => pincodeFeedback = null);
              }
            }
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Add New Address', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: lineCtrl,
                      decoration: const InputDecoration(
                        labelText: 'House / Flat / Street *',
                        border: OutlineInputBorder(),
                        hintText: 'e.g. Flat 301, Silver Oak Society',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: pinCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              labelText: 'PIN Code *',
                              counterText: '',
                              border: const OutlineInputBorder(),
                              hintText: '411038',
                              isDense: true,
                              suffixIcon: isResolvingPincode
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                    )
                                  : (pincodeFeedback != null
                                      ? const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18)
                                      : null),
                            ),
                            onChanged: handlePincode,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: IndiaGeographyService.states.contains(selectedState)
                                ? selectedState
                                : IndiaGeographyService.states.first,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'State *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: IndiaGeographyService.states.map((st) {
                              return DropdownMenuItem(
                                value: st,
                                child: Text(st, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() {
                                  selectedState = val;
                                  availableDistricts = IndiaGeographyService.getDistricts(val);
                                  selectedDistrict = availableDistricts.isNotEmpty ? availableDistricts.first : 'Pune';
                                  availableAreas = IndiaGeographyService.getAreasForDistrict(val, selectedDistrict);
                                  selectedArea = availableAreas.isNotEmpty ? availableAreas.first : selectedDistrict;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (pincodeFeedback != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        pincodeFeedback!,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF1B5E20), fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('add_dist_${selectedState}_$selectedDistrict'),
                            initialValue: availableDistricts.contains(selectedDistrict)
                                ? selectedDistrict
                                : (availableDistricts.isNotEmpty ? availableDistricts.first : null),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'District *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: availableDistricts.map((d) {
                              return DropdownMenuItem(
                                value: d,
                                child: Text(d, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() {
                                  selectedDistrict = val;
                                  availableAreas = IndiaGeographyService.getAreasForDistrict(selectedState, val);
                                  selectedArea = availableAreas.isNotEmpty ? availableAreas.first : val;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('add_area_${selectedDistrict}_$selectedArea'),
                            initialValue: availableAreas.contains(selectedArea)
                                ? selectedArea
                                : (availableAreas.isNotEmpty ? availableAreas.first : null),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Area / Locality *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: availableAreas.map((a) {
                              return DropdownMenuItem(
                                value: a,
                                child: Text(a, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() => selectedArea = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  if (lineCtrl.text.trim().isEmpty || pinCtrl.text.trim().isEmpty) {
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
                      area: selectedArea,
                      city: selectedDistrict,
                      district: selectedDistrict,
                      state: selectedState,
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
          );
        },
      ),
    );
  }

  void _showEditAddressDialog(CustomerAddress addr) {
    final lineCtrl = TextEditingController(text: addr.addressLine);
    final pinCtrl = TextEditingController(text: addr.postalCode);

    String selectedState = IndiaGeographyService.matchState(addr.state) ?? 'Maharashtra';
    List<String> availableDistricts = IndiaGeographyService.getDistricts(selectedState);
    String selectedDistrict = IndiaGeographyService.matchDistrict(selectedState, addr.city.isNotEmpty ? addr.city : 'Pune');
    if (!availableDistricts.contains(selectedDistrict) && availableDistricts.isNotEmpty) {
      selectedDistrict = availableDistricts.first;
    }
    List<String> availableAreas = IndiaGeographyService.getAreasForDistrict(selectedState, selectedDistrict);
    String selectedArea = addr.area.isNotEmpty ? addr.area : (availableAreas.isNotEmpty ? availableAreas.first : 'Central');
    if (!availableAreas.contains(selectedArea)) {
      availableAreas = [selectedArea, ...availableAreas];
    }
    bool isResolvingPincode = false;
    String? pincodeFeedback;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (dlgCtx, setDlgState) {
          Future<void> handlePincode(String val) async {
            final clean = val.replaceAll(RegExp(r'\D'), '').trim();
            if (clean.length == 6) {
              setDlgState(() {
                isResolvingPincode = true;
                pincodeFeedback = 'Resolving location...';
              });
              final res = await IndiaGeographyService.lookupPincode(clean);
              if (res != null) {
                setDlgState(() {
                  selectedState = res.state;
                  availableDistricts = IndiaGeographyService.getDistricts(res.state);
                  selectedDistrict = availableDistricts.contains(res.district)
                      ? res.district
                      : (availableDistricts.isNotEmpty ? availableDistricts.first : res.district);
                  final areas = res.areas.isNotEmpty
                      ? res.areas
                      : IndiaGeographyService.getAreasForDistrict(selectedState, selectedDistrict);
                  availableAreas = areas;
                  selectedArea = areas.isNotEmpty ? areas.first : res.city;
                  isResolvingPincode = false;
                  pincodeFeedback = 'Detected: $selectedDistrict, $selectedState (${res.isFromNetwork ? "Live Post Office" : "Postal Directory"})';
                });
              } else {
                setDlgState(() {
                  isResolvingPincode = false;
                  pincodeFeedback = null;
                });
              }
            } else {
              if (pincodeFeedback != null) {
                setDlgState(() => pincodeFeedback = null);
              }
            }
          }

          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.edit_location_alt_outlined, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Edit Address', style: TextStyle(fontSize: 16)),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: lineCtrl,
                      decoration: const InputDecoration(
                        labelText: 'House / Flat / Street *',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: pinCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: InputDecoration(
                              labelText: 'PIN Code *',
                              counterText: '',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              suffixIcon: isResolvingPincode
                                  ? const Padding(
                                      padding: EdgeInsets.all(10),
                                      child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                                    )
                                  : (pincodeFeedback != null
                                      ? const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 18)
                                      : null),
                            ),
                            onChanged: handlePincode,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            initialValue: IndiaGeographyService.states.contains(selectedState)
                                ? selectedState
                                : IndiaGeographyService.states.first,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'State *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: IndiaGeographyService.states.map((st) {
                              return DropdownMenuItem(
                                value: st,
                                child: Text(st, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() {
                                  selectedState = val;
                                  availableDistricts = IndiaGeographyService.getDistricts(val);
                                  selectedDistrict = availableDistricts.isNotEmpty ? availableDistricts.first : 'Pune';
                                  availableAreas = IndiaGeographyService.getAreasForDistrict(val, selectedDistrict);
                                  selectedArea = availableAreas.isNotEmpty ? availableAreas.first : selectedDistrict;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (pincodeFeedback != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        pincodeFeedback!,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF1B5E20), fontWeight: FontWeight.bold),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('edit_dist_${selectedState}_$selectedDistrict'),
                            initialValue: availableDistricts.contains(selectedDistrict)
                                ? selectedDistrict
                                : (availableDistricts.isNotEmpty ? availableDistricts.first : null),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'District *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: availableDistricts.map((d) {
                              return DropdownMenuItem(
                                value: d,
                                child: Text(d, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() {
                                  selectedDistrict = val;
                                  availableAreas = IndiaGeographyService.getAreasForDistrict(selectedState, val);
                                  selectedArea = availableAreas.isNotEmpty ? availableAreas.first : val;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            key: ValueKey('edit_area_${selectedDistrict}_$selectedArea'),
                            initialValue: availableAreas.contains(selectedArea)
                                ? selectedArea
                                : (availableAreas.isNotEmpty ? availableAreas.first : null),
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Area / Locality *',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: availableAreas.map((a) {
                              return DropdownMenuItem(
                                value: a,
                                child: Text(a, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDlgState(() => selectedArea = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                onPressed: () async {
                  if (lineCtrl.text.trim().isEmpty || pinCtrl.text.trim().isEmpty) {
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
                      area: selectedArea,
                      city: selectedDistrict,
                      state: selectedState,
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
          );
        },
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

