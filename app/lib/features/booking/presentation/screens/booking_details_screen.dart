import '../../../../core/config/dependency_injection.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../data/models/booking_models.dart';
import 'booking_confirmation_screen.dart';

class BookingDetailsScreen extends StatefulWidget {
  const BookingDetailsScreen({super.key});

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  String _paymentMode = 'upi';
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final worker = bookingFlowState.selectedWorker!;
    
    // Calculate prices based on worker rate
    final baseRate = worker.rate;
    final cess = (baseRate * 0.03).round();
    final gst = (baseRate * 0.18).round();
    final total = baseRate + cess + gst;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.9),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Flow', style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            Text('Cooperative Verified Protection', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              children: [
                _buildProgressStepper(),
                const SizedBox(height: AppSpacing.spacingSm),
                _buildEscrowBanner(),
                const SizedBox(height: AppSpacing.spacingMd),
                _buildBookingSummaryCard(total),
                const SizedBox(height: AppSpacing.spacingMd),
                _buildPricingCard(baseRate, cess, gst, total),
                const SizedBox(height: AppSpacing.spacingMd),
                _buildPaymentModes(),
              ],
            ),
          ),
          _buildBottomAction(total),
        ],
      ),
    );
  }

  Widget _buildProgressStepper() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.spacingSm),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStep('Service', true),
          _buildLine(true),
          _buildStep('Worker', true),
          _buildLine(true),
          _buildStep('Address', true),
          _buildLine(true),
          _buildStep('Pay', true, current: true),
        ],
      ),
    );
  }

  Widget _buildStep(String label, bool completed, {bool current = false}) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: completed && !current ? AppColors.tertiaryContainer : (current ? AppColors.primary : AppColors.surfaceContainerHigh),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: completed && !current
              ? const Icon(Icons.check, size: 14, color: AppColors.tertiaryFixed)
              : Text('4', style: AppTypography.labelSm.copyWith(color: AppColors.onPrimary)),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(color: current || completed ? AppColors.primary : AppColors.onSurfaceVariant, fontWeight: current ? FontWeight.bold : FontWeight.normal),
        ),
      ],
    );
  }

  Widget _buildLine(bool completed) {
    return Container(
      width: 24,
      height: 2,
      color: completed ? AppColors.primary : AppColors.outlineVariant,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
    );
  }

  Widget _buildEscrowBanner() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingSm),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusXl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: AppColors.tertiaryFixed.withValues(alpha: 0.3), shape: BoxShape.circle),
            child: const Icon(Icons.verified_user, color: AppColors.onTertiaryFixedVariant, size: 22),
          ),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Cooperative Escrow Guarantee', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: AppSpacing.spacingXs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.tertiaryContainer, borderRadius: AppRadius.radiusFull),
                      child: Text('100% Safe', style: AppTypography.labelSm.copyWith(color: AppColors.tertiaryFixed)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Your payment is safely reserved in Pune Union Escrow and released to ${bookingFlowState.selectedWorker?.name.split(' ')[0]} only upon your OTP approval after job completion.',
                  style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingSummaryCard(int total) {
    final worker = bookingFlowState.selectedWorker!;
    
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('APPOINTMENT DETAILS', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, letterSpacing: 1.2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: 2),
                decoration: BoxDecoration(color: AppColors.surfaceContainer, borderRadius: AppRadius.radiusFull),
                child: Text('Step 4 of 5', style: AppTypography.labelSm.copyWith(color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(color: AppColors.surfaceContainer, shape: BoxShape.circle),
                child: const Icon(Icons.person, color: AppColors.outline),
              ),
              const SizedBox(width: AppSpacing.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(worker.name, style: AppTypography.titleMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                        const SizedBox(width: AppSpacing.spacingXs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.surfaceContainerHigh, borderRadius: AppRadius.radiusSm),
                          child: Text('Pune Guild', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                        ),
                      ],
                    ),
                    Text('Plumbing Inspection & Repair', style: AppTypography.bodyMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          Container(
            padding: const EdgeInsets.all(AppSpacing.spacingSm),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_month, size: 18, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.spacingXs),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Service Slot', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                        Text('${bookingFlowState.selectedDate} • ${bookingFlowState.selectedTime}', style: AppTypography.titleMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.spacingSm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on, size: 18, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.spacingXs),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Job Location', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                          Text(bookingFlowState.address ?? '', style: AppTypography.bodySm.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                        ],
                      ),
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

  Widget _buildPricingCard(int base, int cess, int gst, int total) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Standard Cooperative Bill', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusFull),
                child: Text('Fair Wage Index', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingSm),
          _buildPriceRow('Base Inspection Fee', base.toString()),
          _buildPriceRow('Standard Labor (Up to 1 hr)', 'FREE', isFree: true),
          _buildPriceRow('Cooperative Welfare Cess (3%)', cess.toString()),
          _buildPriceRow('GST (18%)', gst.toString()),
          const SizedBox(height: AppSpacing.spacingSm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.spacingSm),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Payable', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    Text('Includes all union taxes', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
                Text('₹$total', style: AppTypography.currencyDisplay.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool isFree = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
          Text(isFree ? value : '₹$value', style: AppTypography.bodyMd.copyWith(color: isFree ? AppColors.onTertiaryContainer : AppColors.onSurface, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPaymentModes() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusXl, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Select Payment Mode', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.tertiaryContainer, borderRadius: AppRadius.radiusFull),
                child: Text('Instant Verification', style: AppTypography.labelSm.copyWith(color: AppColors.tertiaryFixedDim, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.spacingMd),
          _buildPaymentOption('upi', 'UPI', 'Google Pay, PhonePe, Paytm', Icons.bolt, recommended: true),
          _buildPaymentOption('card', 'Credit / Debit Card', 'Visa, RuPay, Mastercard', Icons.credit_card),
          _buildPaymentOption('cash', 'Cash on Completion', 'Direct cash handover', Icons.local_atm),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, String title, String subtitle, IconData icon, {bool recommended = false}) {
    final isSelected = _paymentMode == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMode = value),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.spacingSm),
        padding: const EdgeInsets.all(AppSpacing.spacingSm),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surfaceContainerLow : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: isSelected ? AppColors.primary : Colors.transparent),
        ),
        child: Row(
          children: [
            Radio(
              value: value,
              groupValue: _paymentMode,
              onChanged: (val) => setState(() => _paymentMode = val.toString()),
              activeColor: AppColors.primary,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title, style: AppTypography.titleMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                      if (recommended) ...[
                        const SizedBox(width: AppSpacing.spacingXs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(color: AppColors.secondaryFixed, borderRadius: AppRadius.radiusFull),
                          child: Text('RECOMMENDED', style: AppTypography.labelSm.copyWith(color: AppColors.onSecondaryFixed, fontSize: 9, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(subtitle, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            Icon(icon, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(int total) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.spacingSm, AppSpacing.marginMobile, 32),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, -4))],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('₹$total', style: AppTypography.currencyDisplay.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 22)),
                  const SizedBox(width: 4),
                  Text('all incl.', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
                ],
              ),
              Text('View Details', style: AppTypography.labelSm.copyWith(color: AppColors.secondary, decoration: TextDecoration.underline)),
            ],
          ),
          const SizedBox(width: AppSpacing.spacingMd),
          Expanded(
            child: GestureDetector(
              onTap: _isSubmitting ? null : () async {
                setState(() {
                  _isSubmitting = true;
                });
                try {
                  final workerId = bookingFlowState.selectedWorker!.id;
                  final categoryId = bookingFlowState.selectedCategory?.id ?? 'c1'; // Fallback
                  final date = bookingFlowState.selectedDate ?? '2023-11-01';
                  final time = bookingFlowState.selectedTime ?? '10:00 AM';
                  final address = bookingFlowState.address ?? '';
                  
                  final newBookingId = await DI.customerRepo.createBooking(
                    workerId: workerId,
                    serviceId: categoryId,
                    scheduledDate: date,
                    scheduledTime: time,
                    amount: total.toDouble(),
                  );
                  
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => BookingConfirmationScreen(bookingId: newBookingId)),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to book: ${e.toString()}')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isSubmitting = false;
                    });
                  }
                }
              },
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: _isSubmitting ? AppColors.outlineVariant : AppColors.primary,
                  borderRadius: AppRadius.radiusXl,
                ),
                alignment: Alignment.center,
                child: _isSubmitting
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: AppColors.onPrimary, strokeWidth: 2))
                  : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, color: AppColors.onPrimary, size: 20),
                    const SizedBox(width: AppSpacing.spacingXs),
                    Text(
                      _paymentMode == 'upi' ? 'Pay ₹$total via UPI' : 'Confirm Booking',
                      style: AppTypography.titleMd.copyWith(color: AppColors.onPrimary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


}

