import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/booking_models.dart';
import '../../../customer/presentation/screens/customer_live_tracking_screen.dart';

class BookingConfirmationScreen extends StatelessWidget {
  final String? bookingId;

  const BookingConfirmationScreen({super.key, this.bookingId});

  @override
  Widget build(BuildContext context) {
    final worker = bookingFlowState.selectedWorker;
    final workerName = worker?.name ?? 'Rahul Patil';
    final serviceName = bookingFlowState.selectedCategory?.name ?? 'Plumbing Service';
    final date = bookingFlowState.selectedDate ?? 'Today';
    final time = bookingFlowState.selectedTime ?? '10:00 AM';

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.marginMobile),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.tertiaryFixed,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
                ),
                child: const Icon(Icons.check, size: 40, color: AppColors.onTertiaryFixedVariant),
              ),
              const SizedBox(height: AppSpacing.spacingLg),
              Text(
                'Booking Confirmed!',
                style: AppTypography.displayLgMobile.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.spacingXs),
              Text(
                'Your payment is safely reserved in Escrow.',
                style: AppTypography.bodyMd.copyWith(color: AppColors.primaryFixedDim),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.spacing2xl),
              Container(
                padding: const EdgeInsets.all(AppSpacing.spacingMd),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: AppRadius.radiusXl,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
                          child: const Icon(Icons.person, color: AppColors.outline),
                        ),
                        const SizedBox(width: AppSpacing.spacingSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(workerName, style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                              Text(serviceName, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Date & Time', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                            Text('$date • $time', style: AppTypography.labelMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Status', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                            Text('Confirmed', style: AppTypography.labelMd.copyWith(color: AppColors.onTertiaryContainer, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (bookingId != null && bookingId!.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: AppColors.onSecondary,
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                      elevation: 2,
                    ),
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => CustomerLiveTrackingScreen(bookingId: bookingId!),
                        ),
                      );
                    },
                    icon: const Icon(Icons.near_me, size: 20),
                    label: Text(
                      'Track Live Job',
                      style: AppTypography.labelLg.copyWith(color: AppColors.onSecondary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.spacingSm),
              ],
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/customer/home', (route) => false);
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: AppRadius.radiusLg,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Return to Home',
                    style: AppTypography.labelLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
