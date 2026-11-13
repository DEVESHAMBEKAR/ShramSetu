import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
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
  String? _federationName;
  String? _federationRegion;
  String? _federationRegNo;
  String? _scopeLevel;
  bool _isSuperAdmin = false;
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
        final roleStr = (dbUser?['role'] as String?)?.toUpperCase() ??
            (user.userMetadata?['role'] as String?)?.toUpperCase() ??
            'ADMIN';

        _isSuperAdmin = roleStr == 'SUPER_ADMIN';

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

        _adminRole = 'Verified $roleStr Administrator';

        // Load assigned federation and region
        if (_isSuperAdmin) {
          _federationName = 'National Cooperative Federation Pool';
          _federationRegion = 'All States & Union Territories (India)';
          _federationRegNo = 'NATIONAL-SUPER-ADMIN-SCOPE';
          _scopeLevel = 'NATIONAL';
        } else {
          // 1. Try to load from repository
          try {
            final admins = await DI.adminRepo.getFederationAdmins();
            final myScope = admins.firstWhere(
              (a) =>
                  a['user_id'] == user.id ||
                  a['email']?.toString().trim().toLowerCase() == user.email?.trim().toLowerCase(),
              orElse: () => {},
            );

            if (myScope.isNotEmpty && myScope['federation_name'] != null && myScope['federation_name'].toString().isNotEmpty) {
              _federationName = myScope['federation_name'];
              _scopeLevel = myScope['scope_level'] ?? 'FEDERATION';
            }
          } catch (e) {
            debugPrint('[AdminProfile] getFederationAdmins error: $e');
          }

          // 2. If null, query Supabase directly for scope & federation
          if (_federationName == null && !AppConfig.useMockData) {
            try {
              final client = Supabase.instance.client;
              final scopeRes = await client
                  .from('admin_federation_scope')
                  .select('federation_id, scope_level')
                  .eq('user_id', user.id)
                  .eq('is_active', true)
                  .maybeSingle();

              if (scopeRes != null && scopeRes['federation_id'] != null) {
                final fedRes = await client
                    .from('federations')
                    .select('name, district, state, registration_no, federation_code')
                    .eq('id', scopeRes['federation_id'])
                    .maybeSingle();

                if (fedRes != null) {
                  _federationName = fedRes['name'];
                  _federationRegion = '${fedRes['district']}, ${fedRes['state']}';
                  _federationRegNo = fedRes['registration_no'] ?? fedRes['federation_code'];
                  _scopeLevel = scopeRes['scope_level'] ?? 'FEDERATION';
                }
              }
            } catch (e) {
              debugPrint('[AdminProfile] direct query error: $e');
            }
          }

          // 3. Fallback based on specific admin identity
          if (_federationName == null) {
            final emailLower = user.email?.trim().toLowerCase() ?? '';
            if (emailLower.contains('nashik') || emailLower == 'adilatar9494@gmail.com') {
              _federationName = 'Nashik District Artisans Cooperative Union';
              _federationRegion = 'Nashik, Maharashtra';
              _federationRegNo = 'MH-NSK-COOP-2020-14';
              _scopeLevel = 'FEDERATION';
            } else if (emailLower.contains('pune') || emailLower == 'ambekardevesh2@gmail.com') {
              _federationName = 'Pune District Labour Cooperative Federation';
              _federationRegion = 'Pune, Maharashtra';
              _federationRegNo = 'MH-PUN-COOP-2018-88';
              _scopeLevel = 'FEDERATION';
            } else if (emailLower.contains('nagpur') || emailLower == 'omshinde@gmail.com') {
              _federationName = 'Nagpur District Shramik Cooperative Union';
              _federationRegion = 'Nagpur, Maharashtra';
              _federationRegNo = 'MH-NGP-COOP-2022-77';
              _scopeLevel = 'FEDERATION';
            }
          }
        }

        if (mounted) setState(() => _isLoading = false);
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
                      if (_federationName != null) ...[
                        const SizedBox(height: AppSpacing.spacingMd),
                        _buildFederationCard(),
                      ],
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
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.primaryContainer, borderRadius: AppRadius.radiusFull),
                      child: Text(_adminRole, style: AppTypography.labelSm.copyWith(color: AppColors.onPrimaryContainer, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFederationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.corporate_fare, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSuperAdmin ? 'National Administrative Scope' : 'Assigned Cooperative Federation',
                      style: const TextStyle(color: AppColors.outline, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _federationName!,
                      style: AppTypography.titleMd.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, color: AppColors.success, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _scopeLevel ?? 'Active',
                      style: const TextStyle(color: AppColors.onSuccessContainer, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              if (_federationRegion != null)
                _buildInfoBadge(Icons.location_on_outlined, 'Assigned Region', _federationRegion!),
              if (_federationRegNo != null)
                _buildInfoBadge(Icons.badge_outlined, 'Registration No.', _federationRegNo!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.outline),
        const SizedBox(width: 4),
        Text('$label: ', style: const TextStyle(color: AppColors.outline, fontSize: 11)),
        Text(value, style: const TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 11)),
      ],
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
          _buildMenuItem(context, Icons.engineering, 'Worker Management', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminWorkersScreen(isSuperAdmin: _isSuperAdmin)))),
          const Divider(height: 1, indent: 56),
          _buildMenuItem(context, Icons.group, 'Customer Management', () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminCustomersScreen(isSuperAdmin: _isSuperAdmin)))),
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
