import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../data/models/admin_models.dart';
import '../../../worker/data/models/worker_models.dart';

class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> {
  late Future<List<JobRequest>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _bookingsFuture = DI.adminRepo.getBookings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<JobRequest>>(
      future: _bookingsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Error: ')));
        }
        
        final bookings = snapshot.data!;

        return Scaffold(
          backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        title: Text('Platform Bookings', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
            padding: const EdgeInsets.all(AppSpacing.spacingMd),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Order #${booking.id}', style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _getStatusColor(booking.status), borderRadius: AppRadius.radiusSm),
                      child: Text(booking.status.name.toUpperCase(), style: AppTypography.labelSm.copyWith(color: AppColors.onPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Text('Customer: ${booking.customerName}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.engineering, size: 16, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Text('Service: ${booking.serviceName}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: AppColors.outline),
                    const SizedBox(width: 4),
                    Expanded(child: Text(booking.customerLocation, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant))),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${booking.date} ${booking.time}', style: AppTypography.labelSm.copyWith(color: AppColors.outline)),
                    Text('₹${booking.totalAmount.toInt()}', style: AppTypography.titleMd.copyWith(color: AppColors.secondary)),
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
                        onPressed: booking.status == BookingStatus.inProgress ? () {
                          () async { await DI.adminRepo.updateBookingStatus(booking.id, BookingStatus.completed); _refreshData(); }();
                        } : null,
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
      ),
    );
        }
      );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.completed:
        return AppColors.tertiaryFixed;
      case BookingStatus.inProgress:
        return AppColors.secondary;
      case BookingStatus.rejected:
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }
}
