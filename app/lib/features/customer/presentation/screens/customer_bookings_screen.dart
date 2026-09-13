import 'package:flutter/material.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';

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
    _bookingsFuture = DI.customerRepo.getCustomerBookings();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        title: Text('My Bookings', style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
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
            return Center(child: Text('No bookings found.', style: AppTypography.bodyMd.copyWith(color: AppColors.outline)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.marginMobile),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final booking = bookings[index];
              return Container(
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
                        Text('Service ID: ${booking['service_id'] ?? 'Unknown'}', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.tertiaryContainer,
                            borderRadius: AppRadius.radiusFull,
                          ),
                          child: Text(
                            '${booking['status'] ?? 'pending'}'.toUpperCase(),
                            style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.spacingXs),
                    Text('Worker: ${booking['worker_id']}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    Text('Scheduled: ${booking['scheduled_date']} at ${booking['scheduled_time']}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: AppSpacing.spacingSm),
                    Text('Total: ₹${booking['total_amount']}', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          );
        }
      ),
    );
  }
}