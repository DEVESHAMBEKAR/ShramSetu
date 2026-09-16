import 'package:flutter/material.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import 'customer_live_tracking_screen.dart';

class CustomerBookingsScreen extends StatefulWidget {
  const CustomerBookingsScreen({super.key});

  @override
  State<CustomerBookingsScreen> createState() => _CustomerBookingsScreenState();
}

class _CustomerBookingsScreenState extends State<CustomerBookingsScreen> {
  int _selectedTab = 0; // 0: Active, 1: Past
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _refreshBookings();
  }

  void _refreshBookings() {
    setState(() {
      _bookingsFuture = DI.customerRepo.getCustomerBookings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: AppSpacing.marginMobile,
        title: Text(
          'My Bookings & Orders',
          style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Segmented Tabs: Active Bookings vs Past Orders
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 8),
            child: Container(
              height: 44,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppRadius.radiusLg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? Colors.white : Colors.transparent,
                          borderRadius: AppRadius.radiusMd,
                          boxShadow: _selectedTab == 0 ? [const BoxShadow(color: Colors.black12, blurRadius: 3)] : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Active Orders',
                          style: AppTypography.labelSm.copyWith(
                            color: _selectedTab == 0 ? AppColors.primary : AppColors.outline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? Colors.white : Colors.transparent,
                          borderRadius: AppRadius.radiusMd,
                          boxShadow: _selectedTab == 1 ? [const BoxShadow(color: Colors.black12, blurRadius: 3)] : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Past Orders',
                          style: AppTypography.labelSm.copyWith(
                            color: _selectedTab == 1 ? AppColors.primary : AppColors.outline,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEAEAEA)),

          // Bookings Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refreshBookings(),
              color: AppColors.secondary,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _bookingsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.secondary));
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: AppTypography.bodyMd));
                  }

                  final allBookings = snapshot.data ?? [];
                  final activeBookings = allBookings.where((b) {
                    final s = (b['status']?.toString() ?? '').toLowerCase();
                    return s != 'completed' && s != 'cancelled' && s != 'rejected';
                  }).toList();

                  final pastBookings = allBookings.where((b) {
                    final s = (b['status']?.toString() ?? '').toLowerCase();
                    return s == 'completed' || s == 'cancelled' || s == 'rejected';
                  }).toList();

                  final currentList = _selectedTab == 0 ? activeBookings : pastBookings;

                  if (currentList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedTab == 0 ? Icons.inventory_2_outlined : Icons.history,
                            size: 48,
                            color: AppColors.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _selectedTab == 0 ? 'No active orders in progress' : 'No past orders yet',
                            style: AppTypography.titleMd.copyWith(color: AppColors.outline),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.marginMobile),
                    itemCount: currentList.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final booking = currentList[index];
                      return _buildUrbanCompanyOrderCard(booking, isPast: _selectedTab == 1);
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUrbanCompanyOrderCard(Map<String, dynamic> booking, {required bool isPast}) {
    final bookingId = booking['id']?.toString() ?? '';
    final status = (booking['status']?.toString() ?? 'pending');
    final serviceData = booking['services'] as Map<String, dynamic>?;
    final workerData = booking['workers'] as Map<String, dynamic>?;
    final workerUserData = workerData?['users'] as Map<String, dynamic>?;

    final serviceName = serviceData?['name']?.toString() ?? 'Home Maintenance Service';
    final workerName = workerUserData?['full_name']?.toString() ?? 'Rahul Patil';
    final amount = (booking['base_amount'] as num?)?.toDouble() ?? 399.0;
    final otp = booking['otp']?.toString() ?? '8492';
    final orderRef = bookingId.length >= 4 ? bookingId.substring(0, 4).toUpperCase() : '8942';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip
          if (!isPast)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: AppColors.primary,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status == 'onTheWay' ? 'PARTNER EN ROUTE' : status.toUpperCase(),
                        style: AppTypography.labelSm.copyWith(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: AppRadius.radiusSm,
                    ),
                    child: Text('Arriving shortly', style: AppTypography.labelSm.copyWith(color: Colors.white, fontSize: 10)),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              color: AppColors.surfaceContainerLow,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Completed Order', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, fontWeight: FontWeight.bold)),
                  Text('${booking['scheduled_date']}', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 11)),
                ],
              ),
            ),

          // Content body
          Padding(
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(serviceName, style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppRadius.radiusSm,
                      ),
                      child: Text('#SS-$orderRef', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Worker info pill
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: AppRadius.radiusLg,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.surfaceContainerHigh,
                            child: const Icon(Icons.person, size: 20, color: AppColors.primary),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(workerName, style: AppTypography.labelLg.copyWith(fontWeight: FontWeight.bold)),
                              Text('Certified Artisan • 4.9 ★', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.verified, size: 18, color: AppColors.onTertiaryContainer),
                    ],
                  ),
                ),

                if (!isPast) ...[
                  const SizedBox(height: 10),
                  // Escrow OTP Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.tertiaryContainer,
                      borderRadius: AppRadius.radiusLg,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lock, size: 16, color: AppColors.onTertiaryContainer),
                            const SizedBox(width: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Doorstep Release OTP', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontWeight: FontWeight.bold)),
                                Text('Share after service completion', style: AppTypography.bodySm.copyWith(color: AppColors.onTertiaryContainer, fontSize: 9)),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: AppRadius.radiusSm,
                          ),
                          child: Text(
                            otp,
                            style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const Divider(height: 24),

                // Footer CTA Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Amount', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
                        Text('₹${amount.toStringAsFixed(0)}', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    if (!isPast)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          elevation: 0,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerLiveTrackingScreen(bookingId: bookingId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.navigation, size: 14, color: Color(0xFF34D399)),
                        label: Text('Track Live', style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                      )
                    else
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.outlineVariant),
                          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerLiveTrackingScreen(bookingId: bookingId),
                            ),
                          );
                        },
                        child: Text('View Details', style: AppTypography.labelSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
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
}