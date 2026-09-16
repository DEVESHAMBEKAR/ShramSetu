import '../../../../core/config/dependency_injection.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
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
  String? _pendingBookingId;
  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (_pendingBookingId == null) return;
    if (!mounted) return;

    setState(() => _isSubmitting = true);
    try {
      // CRITICAL: Verify payment server-side — never trust client callback alone
      final verified = await DI.paymentRepo.verifyPayment(
        bookingId: _pendingBookingId!,
        razorpayOrderId: response.orderId ?? '',
        razorpayPaymentId: response.paymentId ?? '',
        razorpaySignature: response.signature ?? '',
      );

      if (!mounted) return;

      if (verified) {
        final bookingId = _pendingBookingId!;
        _pendingBookingId = null;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => BookingConfirmationScreen(bookingId: bookingId),
          ),
          (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment verification failed. Please contact support.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _pendingBookingId = null;
    if (!mounted) return;
    final msg = response.message ?? 'Payment cancelled or failed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: $msg'),
        backgroundColor: Colors.red,
      ),
    );
    setState(() => _isSubmitting = false);
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // External wallets (Paytm etc.) redirect externally — treat as pending
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Redirecting to ${response.walletName}...')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final worker = bookingFlowState.selectedWorker!;
    
    // Calculate transparent pricing
    final baseRate = worker.rate;
    final cess = (baseRate * 0.03).round();
    final gst = (baseRate * 0.18).round();
    final total = baseRate + cess + gst;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Checkout', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            Text('Pune Guild Protection', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Step Indicator
          _buildStepIndicator(),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.marginMobile),
              children: [
                // 1. Premium Escrow Guarantee Card
                _buildEscrowGuaranteeBanner(total),

                const SizedBox(height: 12),

                // 2. Booking Summary Card
                _buildSummaryCard(worker),

                const SizedBox(height: 12),

                // 3. Transparent Cost Breakdown
                _buildFareBreakdown(baseRate, cess, gst, total),

                const SizedBox(height: 12),

                // 4. Payment Modes
                _buildPaymentModes(),
              ],
            ),
          ),

          // Bottom Action Bar
          _buildBottomAction(total),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStepItem('Service', isDone: true),
          _buildStepDivider(isDone: true),
          _buildStepItem('Worker', isDone: true),
          _buildStepDivider(isDone: true),
          _buildStepItem('Address', isDone: true),
          _buildStepDivider(isDone: false),
          _buildStepItem('Payment', isCurrent: true),
        ],
      ),
    );
  }

  Widget _buildStepItem(String title, {bool isDone = false, bool isCurrent = false}) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: isDone
                ? AppColors.tertiaryContainer
                : (isCurrent ? AppColors.primary : AppColors.surfaceContainerLow),
            shape: BoxShape.circle,
          ),
          child: isDone
              ? const Icon(Icons.check, size: 12, color: AppColors.onTertiaryContainer)
              : Center(
                  child: Text(
                    isCurrent ? '4' : '',
                    style: AppTypography.labelSm.copyWith(
                      color: isCurrent ? Colors.white : AppColors.outline,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: AppTypography.labelSm.copyWith(
            color: isCurrent ? AppColors.primary : (isDone ? AppColors.onTertiaryContainer : AppColors.outline),
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider({required bool isDone}) {
    return Expanded(
      child: Container(
        height: 1,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: isDone ? AppColors.onTertiaryContainer.withValues(alpha: 0.3) : AppColors.outlineVariant,
      ),
    );
  }

  Widget _buildEscrowGuaranteeBanner(int total) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.onPrimaryFixedVariant.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: const Icon(Icons.verified_user, color: AppColors.tertiaryFixed, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Cooperative Escrow', style: AppTypography.titleMd.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.tertiaryContainer.withValues(alpha: 0.2),
                        borderRadius: AppRadius.radiusFull,
                        border: Border.all(color: AppColors.tertiaryFixed.withValues(alpha: 0.4)),
                      ),
                      child: Text('100% SAFE', style: AppTypography.labelSm.copyWith(color: AppColors.tertiaryFixed, fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Your ₹$total is safely locked in Pune Union Escrow and released to Rahul strictly after OTP approval upon complete satisfaction.',
                  style: AppTypography.bodySm.copyWith(color: AppColors.primaryFixedDim, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(dynamic worker) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('BOOKING OVERVIEW', style: AppTypography.labelSm.copyWith(color: AppColors.outline, letterSpacing: 0.8)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusSm),
                child: Text('Step 4 of 5', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 9)),
              ),
            ],
          ),
          const Divider(height: 18),
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.surfaceContainerLow,
                    child: const Icon(Icons.person, size: 24, color: AppColors.primary),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.onTertiaryContainer,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.check, size: 8, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(worker.name, style: AppTypography.labelLg.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusSm),
                          child: Text('Guild #128', style: AppTypography.labelSm.copyWith(color: AppColors.outline, fontSize: 9)),
                        ),
                      ],
                    ),
                    Text(bookingFlowState.selectedCategory?.name ?? 'Plumbing Service', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: AppRadius.radiusLg),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('${bookingFlowState.selectedDate ?? "Today"} at ${bookingFlowState.selectedTime ?? "10:00 AM"}', style: AppTypography.bodySm.copyWith(fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareBreakdown(int base, int cess, int gst, int total) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('COST BREAKDOWN', style: AppTypography.labelSm.copyWith(color: AppColors.outline, letterSpacing: 0.8)),
              Text('0% Commission', style: AppTypography.labelSm.copyWith(color: AppColors.onTertiaryContainer, fontWeight: FontWeight.bold, fontSize: 10)),
            ],
          ),
          const Divider(height: 18),
          _buildFareRow('Standard Diagnostic / Base Rate', '₹$base'),
          const SizedBox(height: 6),
          _buildFareRow('Worker Union Welfare Pool (3%)', '₹$cess'),
          const SizedBox(height: 6),
          _buildFareRow('Govt. GST (18%)', '₹$gst'),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Amount Locked', style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  Text('Held in Pune Union Escrow', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
                ],
              ),
              Text('₹$total', style: AppTypography.currencyDisplay.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFareRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11)),
        Text(value, style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPaymentModes() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.spacingMd),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SELECT PAYMENT METHOD', style: AppTypography.labelSm.copyWith(color: AppColors.outline, letterSpacing: 0.8)),
          const Divider(height: 18),
          _buildPaymentRadio('upi', 'Instant UPI / QR', 'Google Pay, PhonePe, Paytm, BHIM', Icons.qr_code_2),
          const SizedBox(height: 8),
          _buildPaymentRadio('wallet', 'Union Escrow Balance', 'Available: ₹1,250', Icons.account_balance_wallet_outlined),
          const SizedBox(height: 8),
          _buildPaymentRadio('cash', 'Pay After Service (Cash on Sign-off)', 'Direct to artisan upon satisfaction', Icons.payments_outlined),
        ],
      ),
    );
  }

  Widget _buildPaymentRadio(String value, String title, String subtitle, IconData icon) {
    final isSelected = _paymentMode == value;
    return GestureDetector(
      onTap: () => setState(() => _paymentMode = value),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.secondaryFixed.withValues(alpha: 0.3) : AppColors.surfaceContainerLow,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: isSelected ? AppColors.secondary : AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppColors.secondary : AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  Text(subtitle, style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.secondary : AppColors.outline,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction(int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Total Payable', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 10)),
                Text('₹$total', style: AppTypography.titleLg.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                ),
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        setState(() => _isSubmitting = true);
                        try {
                          final workerId = bookingFlowState.selectedWorker!.id;
                          final categoryId = bookingFlowState.selectedCategory?.id ?? 'c2';
                          final date = bookingFlowState.selectedDate ?? '2023-11-01';
                          final time = bookingFlowState.selectedTime ?? '10:00 AM';

                          // Step 1: Create the booking record
                          final newBookingId = await DI.customerRepo.createBooking(
                            workerId: workerId,
                            serviceId: categoryId,
                            scheduledDate: date,
                            scheduledTime: time,
                            amount: total.toDouble(),
                            addressId: bookingFlowState.addressId,
                          );

                          if (newBookingId == null) {
                            throw Exception('Failed to generate booking ID.');
                          }

                          _pendingBookingId = newBookingId;

                          // Step 2: Create Razorpay order via Edge Function
                          // Amount comes from DB, not from client-side calculation
                          final orderResult = await DI.paymentRepo.createPaymentOrder(newBookingId);

                          // Step 3: Open Razorpay checkout
                          final options = <String, dynamic>{
                            'key': orderResult.keyId,
                            'amount': orderResult.amountPaise,
                            'currency': orderResult.currency,
                            'order_id': orderResult.orderId,
                            'name': 'ShramSetu',
                            'description': 'Cooperative Escrow Payment',
                            'prefill': {'contact': '', 'email': ''},
                            'theme': {'color': '#5B2EFF'},
                          };
                          _razorpay.open(options);
                          // Payment result handled by _handlePaymentSuccess / _handlePaymentError
                        } catch (e) {
                          _pendingBookingId = null;
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to initiate payment: $e')),
                            );
                            setState(() => _isSubmitting = false);
                          }
                        }
                      },
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.lock_outline, size: 16, color: AppColors.tertiaryFixed),
                label: Text(
                  _isSubmitting ? 'Processing...' : 'Pay via Razorpay',
                  style: AppTypography.labelLg.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
