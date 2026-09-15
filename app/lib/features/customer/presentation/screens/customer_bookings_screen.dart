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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.amber.shade800;
      case 'accepted': return AppColors.primary;
      case 'onTheWay': return AppColors.secondary;
      case 'arrived': return AppColors.primaryContainer;
      case 'inProgress': return AppColors.secondaryContainer;
      case 'completed': return AppColors.onTertiaryContainer;
      case 'cancelled': return AppColors.error;
      default: return AppColors.outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        title: Text('My Bookings', style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshBookings(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _bookingsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}', style: AppTypography.bodyMd));
            }
            
            final bookings = snapshot.data ?? [];
            if (bookings.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 48, color: AppColors.outline),
                    const SizedBox(height: AppSpacing.spacingSm),
                    Text('No bookings found.', style: AppTypography.titleMd.copyWith(color: AppColors.outline)),
                    const SizedBox(height: AppSpacing.spacingXs),
                    Text('Your active orders and job requests will appear here.', style: AppTypography.bodySm.copyWith(color: AppColors.outline)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              itemCount: bookings.length,
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final bookingId = booking['id']?.toString() ?? '';
                final status = (booking['status']?.toString() ?? 'pending');
                final serviceData = booking['services'] as Map<String, dynamic>?;
                final workerData = booking['workers'] as Map<String, dynamic>?;
                final workerUserData = workerData?['users'] as Map<String, dynamic>?;

                final serviceName = serviceData?['name']?.toString() ?? 'Artisan Service';
                final workerName = workerUserData?['full_name']?.toString() ?? 'Assigned Artisan';
                final amount = (booking['base_amount'] as num?)?.toDouble() ?? 
                               (booking['amount'] as num?)?.toDouble() ?? 450.0;

                return GestureDetector(
                  onTap: () async {
                    if (bookingId.isNotEmpty) {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerLiveTrackingScreen(bookingId: bookingId),
                        ),
                      );
                      _refreshBookings();
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
                    padding: const EdgeInsets.all(AppSpacing.spacingMd),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: AppRadius.radiusLg,
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(serviceName, style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status).withValues(alpha: 0.15),
                                borderRadius: AppRadius.radiusFull,
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: AppTypography.labelSm.copyWith(color: _getStatusColor(status), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.spacingXs),
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 16, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(workerName, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.schedule, size: 16, color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text('${booking['scheduled_date']} • ${booking['scheduled_time']}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total: ₹${amount.toStringAsFixed(0)}', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                            Row(
                              children: [
                                Text('Track Live', style: AppTypography.labelMd.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold)),
                                const Icon(Icons.chevron_right, size: 18, color: AppColors.secondary),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}