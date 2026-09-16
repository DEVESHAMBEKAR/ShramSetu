import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../data/models/admin_models.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  late Future<List<AdminService>> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _servicesFuture = DI.adminRepo.getServices();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AdminService>>(
      future: _servicesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ')));
        }
        
        final services = snapshot.data!;

        return Scaffold(
          backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Service Catalog', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary),
            onPressed: () {
              // Mock adding a service
            },
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        itemCount: services.length,
        itemBuilder: (context, index) {
          final service = services[index];
          final isActive = service.status == ServiceStatus.active;

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: AppRadius.radiusLg),
                  child: Icon(_getIconData(service.icon), color: AppColors.primary),
                ),
                const SizedBox(width: AppSpacing.spacingMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(service.name, style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
                      Text(isActive ? 'Active' : 'Inactive', style: AppTypography.labelSm.copyWith(color: isActive ? AppColors.onTertiaryContainer : AppColors.outline, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Switch(
                  value: isActive,
                  activeThumbImage: null,
                  activeColor: AppColors.primary, // Actually let's just use activeColor for now since activeThumbColor isn't enough to style everything, but wait, the warning said "Use activeThumbColor instead".
                  onChanged: (val) {
                    () async { await DI.adminRepo.toggleServiceStatus(service.id); _refreshData(); }();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.onSurfaceVariant),
                  onPressed: () {},
                ),
              ],
            ),
          );
        },
      ),
    );
        }
      );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'bolt': return Icons.bolt;
      case 'plumbing': return Icons.plumbing;
      case 'cleaning_services': return Icons.cleaning_services;
      case 'format_paint': return Icons.format_paint;
      case 'carpenter': return Icons.carpenter;
      case 'ac_unit': return Icons.ac_unit;
      default: return Icons.home_repair_service;
    }
  }
}
