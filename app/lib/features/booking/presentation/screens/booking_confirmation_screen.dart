import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/shramsetu_brand_mark.dart';
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
        child: Column(
          children: [
            const TricolorStripe(height: 3.5),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.marginMobile),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - (AppSpacing.marginMobile * 2)).clamp(0.0, double.infinity),
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.primaryContainer),
                              ),
                              child: const ShramSetuBrandMark(
                                compact: true,
                                showText: true,
                                subtitle: 'National Digital Public Infrastructure • Verified',
                              ),
                            ),
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
                              'Your payment is safely reserved in Sovereign Escrow.',
                              style: AppTypography.bodyMd.copyWith(color: AppColors.primaryFixedDim),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AppSpacing.spacingXl),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.surfaceContainerHigh),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  Container(height: 4, color: AppColors.secondaryContainer),
                                  Padding(
                                    padding: const EdgeInsets.all(AppSpacing.spacingMd),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 48,
                                              height: 48,
                                              decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
                                              child: const Icon(Icons.person, color: AppColors.primaryContainer),
                                            ),
                                            const SizedBox(width: AppSpacing.spacingSm),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(workerName, style: AppTypography.titleMd.copyWith(color: AppColors.primaryContainer, fontWeight: FontWeight.bold)),
                                                  Text(serviceName, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 28),
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
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.tertiaryContainer,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    'Escrow Locked',
                                                    style: AppTypography.labelSm.copyWith(
                                                      color: AppColors.onTertiaryContainer,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(height: AppSpacing.spacingLg),
                            if (bookingId != null && bookingId!.isNotEmpty) ...[
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.secondaryContainer,
                                    foregroundColor: AppColors.onPrimary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    elevation: 2,
                                  ),
                                  onPressed: () {
                                    Navigator.of(context).pushReplacement(
                                      MaterialPageRoute(
                                        builder: (_) => CustomerLiveTrackingScreen(bookingId: bookingId!),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.near_me, size: 20, color: AppColors.onPrimary),
                                  label: Text(
                                    'Track Live Job (थेट मागोवा)',
                                    style: AppTypography.labelLg.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.spacingSm),
                            ],
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                Navigator.of(context).pushNamedAndRemoveUntil('/customer/home', (route) => false);
                              },
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.surfaceContainerHigh),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Return to Home',
                                  style: AppTypography.labelLg.copyWith(color: AppColors.primaryContainer, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
