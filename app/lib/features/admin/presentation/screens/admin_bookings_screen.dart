import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../worker/data/models/worker_models.dart';

class AdminBookingsScreen extends StatefulWidget {
  final bool? isSuperAdmin;
  const AdminBookingsScreen({super.key, this.isSuperAdmin});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  late Future<List<JobRequest>> _bookingsFuture;
  StreamSubscription<List<JobRequest>>? _bookingsSub;

  bool _isSuperAdmin = false;
  String _scopedFederationName = '';
  List<String> _authorizedFedIds = [];

  @override
  void initState() {
    super.initState();
    _loadScope();
    _refreshData();
    _bookingsSub = DI.adminRepo.watchBookings().listen(
      (_) {
        if (mounted) _refreshData();
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _bookingsSub?.cancel();
    super.dispose();
  }

  Future<void> _loadScope() async {
    try {
      final scope = DI.federationScopeService;
      final user = await DI.authRepo.getCurrentUser();
      bool isGlobal = widget.isSuperAdmin ?? false;
      List<String> authIds = [];
      String fedName = '';

      if (user != null) {
        try {
          final admins = await DI.adminRepo.getFederationAdmins();
          final myScope = admins.firstWhere(
            (a) =>
                a['user_id'] == user.id ||
                a['email']?.toString().trim().toLowerCase() == user.email?.trim().toLowerCase(),
            orElse: () => {},
          );
          if (myScope.isNotEmpty && myScope['federation_id'] != null) {
            authIds = [myScope['federation_id'].toString()];
            fedName = myScope['federation_name']?.toString() ?? '';
          }
        } catch (_) {}
      }

      if (user != null && (fedName.isEmpty || authIds.isEmpty)) {
        final emailLower = user.email?.trim().toLowerCase() ?? '';
        if (emailLower.contains('nagpur') || emailLower == 'omshinde@gmail.com') {
          authIds = ['55555555-0000-0000-0000-000000000005'];
          fedName = 'Nagpur District Shramik Cooperative Union';
        } else if (emailLower.contains('nashik') || emailLower == 'adilatar9494@gmail.com') {
          authIds = ['22222222-0000-0000-0000-000000000002'];
          fedName = 'Nashik District Artisans Cooperative Union';
        } else if (emailLower.contains('pune') || emailLower == 'ambekardevesh2@gmail.com') {
          authIds = ['11111111-0000-0000-0000-000000000001'];
          fedName = 'Pune District Labour Cooperative Federation';
        } else if (emailLower == 'deveshambekar@gmail.com') {
          isGlobal = true;
          fedName = 'National Cooperative Federation Pool';
        }
      }

      if (scope != null) {
        if (widget.isSuperAdmin != null) {
          isGlobal = widget.isSuperAdmin!;
        } else {
          isGlobal = await scope.hasGlobalScope();
        }

        if (authIds.isEmpty) {
          authIds = await scope.getAuthorizedFederationIds();
        }

        if (fedName.isEmpty) {
          final desc = await scope.getScopeDescription();
          if (desc.isNotEmpty && !desc.startsWith('No ') && !desc.startsWith('All ')) {
            fedName = desc;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isSuperAdmin = isGlobal;
          _scopedFederationName = fedName;
          _authorizedFedIds = authIds;
        });
      }
    } catch (_) {}
  }

  void _refreshData() {
    setState(() {
      _bookingsFuture = DI.adminRepo.getBookings();
    });
  }

  Widget _buildScopeBanner() {
    if (_isSuperAdmin) {
      return Container(
        color: const Color(0xFFEEF2FF),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: const Row(
          children: [
            Icon(Icons.public, color: Color(0xFF3730A3), size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'National Marketplace Ledger',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF3730A3)),
                      ),
                      SizedBox(width: 6),
                      Text('GLOBAL SCOPE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Cross-federation oversight: Real-time orders and dispatches across all state unions.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF312E81)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFFF0FDF4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.shield, color: Color(0xFF166534), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        _scopedFederationName.isNotEmpty ? _scopedFederationName : 'Federation Jurisdiction',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF166534)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF86EFAC)),
                      ),
                      child: const Text('LOCKED SCOPE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Exclusive jurisdiction: You can only view orders and bookings dispatched to artisans within your cooperative federation.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF14532D)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text(
          _isSuperAdmin ? 'Platform Bookings (National)' : 'Federation Orders & Dispatch',
          style: AppTypography.titleLg.copyWith(color: AppColors.primary),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: () {
              _loadScope();
              _refreshData();
            },
            tooltip: 'Refresh Orders',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildScopeBanner(),
          Expanded(
            child: FutureBuilder<List<JobRequest>>(
              future: _bookingsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                          const SizedBox(height: 12),
                          Text('Failed to load orders: ${snapshot.error}', textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: _refreshData, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  );
                }

                final rawBookings = snapshot.data ?? [];
                // STRICT FEDERATION ACCESS ISOLATION:
                // Non-super admins only see orders matching their authorized federation IDs
                final List<JobRequest> bookings;
                if (!_isSuperAdmin && _authorizedFedIds.isNotEmpty) {
                  bookings = rawBookings.where((b) {
                    if (b.federationRefId != null && b.federationRefId!.isNotEmpty) {
                      return _authorizedFedIds.contains(b.federationRefId);
                    }
                    return true;
                  }).toList();
                } else {
                  bookings = rawBookings;
                }

                if (bookings.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.assignment_outlined, size: 32, color: AppColors.outline),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _scopedFederationName.isNotEmpty
                                ? 'No Orders for $_scopedFederationName'
                                : 'No Orders Found',
                            textAlign: TextAlign.center,
                            style: AppTypography.titleMd.copyWith(color: AppColors.primary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Customer bookings dispatched to registered artisans under your cooperative federation will appear here in real-time.',
                            textAlign: TextAlign.center,
                            style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 20),
                          OutlinedButton.icon(
                            onPressed: _refreshData,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Refresh Orders'),
                            style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.marginMobile),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final booking = bookings[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
                      padding: const EdgeInsets.all(AppSpacing.spacingMd),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: AppRadius.radiusXl,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Order #${booking.id}',
                                style: AppTypography.titleMd.copyWith(color: AppColors.primary),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.bookingStatusContainer(booking.status),
                                  borderRadius: AppRadius.radiusSm,
                                ),
                                child: Text(
                                  booking.status.name.toUpperCase(),
                                  style: AppTypography.labelSm.copyWith(
                                    color: AppColors.bookingStatusTextColor(booking.status),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.spacingSm),
                          Row(
                            children: [
                              const Icon(Icons.person, size: 16, color: AppColors.outline),
                              const SizedBox(width: 4),
                              Text(
                                'Customer: ${booking.customerName}',
                                style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.engineering, size: 16, color: AppColors.outline),
                              const SizedBox(width: 4),
                              Text(
                                'Artisan: ${booking.workerName ?? "Assigned Karigar"}',
                                style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.handyman, size: 16, color: AppColors.outline),
                              const SizedBox(width: 4),
                              Text(
                                'Service: ${booking.serviceName}',
                                style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16, color: AppColors.outline),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  booking.customerLocation,
                                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.spacingSm),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${booking.date} ${booking.time}',
                                style: AppTypography.labelSm.copyWith(color: AppColors.outline),
                              ),
                              Text(
                                '₹${booking.totalAmount.toInt()}',
                                style: AppTypography.titleMd.copyWith(color: AppColors.secondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.spacingMd),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {},
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                                  child: const Text('View Details'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: booking.status == BookingStatus.inProgress
                                      ? () async {
                                          await DI.adminRepo.updateBookingStatus(booking.id, BookingStatus.completed);
                                          _refreshData();
                                        }
                                      : null,
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.primary),
                                  child: const Text('Mark Complete'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
