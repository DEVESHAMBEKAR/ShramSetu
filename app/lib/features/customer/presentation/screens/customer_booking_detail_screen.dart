import 'package:flutter/material.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import 'customer_live_tracking_screen.dart';
import '../widgets/review_rating_modal.dart';
import '../../../../core/models/invoice_models.dart';
import '../dialogs/invoice_view_dialog.dart';

class CustomerBookingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> booking;

  const CustomerBookingDetailScreen({
    super.key,
    required this.booking,
  });

  @override
  State<CustomerBookingDetailScreen> createState() =>
      _CustomerBookingDetailScreenState();
}

class _CustomerBookingDetailScreenState
    extends State<CustomerBookingDetailScreen> {
  late Map<String, dynamic> _booking;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  Future<void> _refreshBooking() async {
    setState(() => _isLoading = true);
    try {
      final allBookings = await DI.customerRepo.getCustomerBookings();
      final fresh = allBookings
          .where((b) => b['id']?.toString() == _booking['id']?.toString())
          .firstOrNull;
      if (fresh != null && mounted) {
        setState(() => _booking = fresh);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _handleCancelBooking() async {
    final bookingId = _booking['id']?.toString() ?? '';
    final reasons = [
      'Booked by mistake',
      'Artisan delayed / unavailable',
      'Found alternate solution',
      'Price or scope disagreement',
      'Emergency or changed plans',
      'Other reason',
    ];
    String selectedReason = reasons.first;
    final otherController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: AppColors.error),
              SizedBox(width: 8),
              Text('Cancel Booking'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Please select a reason for cancellation. Under cooperative policy, cancellations made before dispatch incur zero cancellation penalty.',
                  style: TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                ...[
                  RadioGroup<String>(
                    groupValue: selectedReason,
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedReason = val);
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: reasons.map((r) => RadioListTile<String>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(r, style: const TextStyle(fontSize: 13)),
                            value: r,
                          )).toList(),
                    ),
                  ),
                ],
                if (selectedReason == 'Other reason') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: otherController,
                    decoration: const InputDecoration(
                      labelText: 'Specify reason *',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Booking'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (selectedReason == 'Other reason' &&
                    otherController.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Confirm Cancellation'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final reasonText = selectedReason == 'Other reason'
          ? otherController.text.trim()
          : selectedReason;

      setState(() => _isLoading = true);
      try {
        await DI.customerRepo.cancelBooking(bookingId, reason: reasonText);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: AppColors.onTertiaryContainer,
              content: Text('✓ Booking cancelled successfully. Escrow funds refunded.'),
            ),
          );
        }
        await _refreshBooking();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel booking: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRescheduleBooking() async {
    final bookingId = _booking['id']?.toString() ?? '';
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (pickedDate == null || !mounted) return;

    final slots = [
      'Morning (09:00 AM - 12:00 PM)',
      'Afternoon (12:00 PM - 04:00 PM)',
      'Evening (04:00 PM - 08:00 PM)',
    ];
    String selectedSlot = slots.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.calendar_month, color: AppColors.primary),
              SizedBox(width: 8),
              Text('Select New Time Slot'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rescheduling to: ${pickedDate.day}/${pickedDate.month}/${pickedDate.year}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              ...[
                RadioGroup<String>(
                  groupValue: selectedSlot,
                  onChanged: (val) {
                    if (val != null) {
                      setModalState(() => selectedSlot = val);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: slots.map((s) => RadioListTile<String>(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(s, style: const TextStyle(fontSize: 13)),
                          value: s,
                        )).toList(),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirm Reschedule'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final dateStr = '${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}';
      setState(() => _isLoading = true);
      try {
        await DI.customerRepo.rescheduleBooking(
          bookingId,
          newDate: dateStr,
          newTime: selectedSlot,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.onTertiaryContainer,
              content: Text('✓ Booking rescheduled to $dateStr ($selectedSlot)'),
            ),
          );
        }
        await _refreshBooking();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reschedule: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = (_booking['status']?.toString() ?? 'pending').toLowerCase();
    final serviceData = _booking['services'] as Map<String, dynamic>?;
    final workerData = _booking['workers'] as Map<String, dynamic>?;
    final workerUserData = workerData?['users'] as Map<String, dynamic>?;

    final serviceName = serviceData?['name']?.toString() ?? 'Home Maintenance Service';
    final workerName = workerUserData?['full_name']?.toString() ?? 'Rahul Patil';
    final workerPhone = workerUserData?['phone']?.toString() ?? '+91 98220 12345';
    final workerRating = (workerData?['rating'] as num?)?.toDouble() ?? 4.8;
    final workerTrade = workerData?['trade']?.toString() ?? 'Certified Artisan';
    final federationName = workerData?['federation_name']?.toString() ?? 'Pune District Labour Cooperative Federation';
    final amount = (_booking['base_amount'] as num?)?.toDouble() ?? 399.0;
    final otp = _booking['otp']?.toString() ?? '8492';
    final bookingId = _booking['id']?.toString() ?? '';
    final scheduledDate = _booking['scheduled_date']?.toString() ?? 'Today';
    final scheduledTime = _booking['scheduled_time']?.toString() ?? '10:00 AM - 01:00 PM';
    final address = _booking['address']?.toString() ?? 'Model Colony, Shivajinagar, Pune';
    final cancellationReason = _booking['cancellation_reason']?.toString();
    final cancelledAt = _booking['cancelled_at']?.toString();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Order Details',
          style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _refreshBooking,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.marginMobile),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusHeader(status, bookingId),
                      const SizedBox(height: 16),
                      _buildDynamicActionSection(
                        status: status,
                        bookingId: bookingId,
                        workerName: workerName,
                        serviceName: serviceName,
                        workerPhone: workerPhone,
                        otp: otp,
                      ),
                      if (cancellationReason != null && cancellationReason.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildCancellationReasonCard(cancellationReason, cancelledAt),
                      ],
                      const SizedBox(height: 16),
                      _buildWorkerCard(
                        workerName: workerName,
                        workerPhone: workerPhone,
                        workerRating: workerRating,
                        workerTrade: workerTrade,
                        federationName: federationName,
                      ),
                      const SizedBox(height: 16),
                      _buildServiceAndScheduleCard(
                        serviceName: serviceName,
                        scheduledDate: scheduledDate,
                        scheduledTime: scheduledTime,
                        address: address,
                      ),
                      const SizedBox(height: 16),
                      _buildPaymentBreakdownCard(amount: amount, status: status),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatusHeader(String status, String bookingId) {
    Color bg;
    Color fg;
    String label;
    IconData icon;
    String description;

    switch (status) {
      case 'accepted':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        label = 'BOOKING CONFIRMED';
        icon = Icons.assignment_turned_in;
        description = 'An artisan partner has accepted your booking and is preparing for dispatch.';
        break;
      case 'ontheway':
      case 'on_the_way':
        bg = const Color(0xFFEDE7F6);
        fg = const Color(0xFF512DA8);
        label = 'ARTISAN EN ROUTE';
        icon = Icons.navigation;
        description = 'Artisan partner is on their way to your doorstep. Track live location below.';
        break;
      case 'arrived':
        bg = const Color(0xFFE0F2F1);
        fg = const Color(0xFF00796B);
        label = 'ARTISAN ARRIVED';
        icon = Icons.pin_drop;
        description = 'Artisan has arrived at your address. Provide your release OTP to begin work.';
        break;
      case 'in_progress':
      case 'inprogress':
        bg = const Color(0xFFE0F7FA);
        fg = const Color(0xFF00838F);
        label = 'WORK IN PROGRESS';
        icon = Icons.handyman;
        description = 'Service is actively underway. Release payment OTP only after satisfactory completion.';
        break;
      case 'completed':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        label = 'ORDER COMPLETED';
        icon = Icons.verified;
        description = 'Service completed successfully. Escrow funds transferred to artisan.';
        break;
      case 'cancelled':
      case 'rejected':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        label = 'ORDER CANCELLED';
        icon = Icons.cancel;
        description = 'This booking has been cancelled. Any collected escrow payment has been refunded.';
        break;
      case 'pending':
      default:
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57C00);
        label = 'FINDING ARTISAN PARTNER';
        icon = Icons.hourglass_top;
        description = 'Your request has been broadcasted to certified local union artisans in your ward.';
        break;
    }

    final orderRef = bookingId.length >= 6 ? bookingId.substring(0, 6).toUpperCase() : bookingId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: fg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '#SS-$orderRef',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: fg),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(fontSize: 13, color: fg.withValues(alpha: 0.9), height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicActionSection({
    required String status,
    required String bookingId,
    required String workerName,
    required String serviceName,
    required String workerPhone,
    required String otp,
  }) {
    final isPending = status == 'pending';
    final isAccepted = status == 'accepted';
    final isEnRouteOrArrived = status == 'ontheway' || status == 'on_the_way' || status == 'arrived';
    final isInProgress = status == 'inprogress' || status == 'in_progress';
    final isCompleted = status == 'completed';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Actions',
            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 14),

          // Doorstep Release OTP (for active dispatches)
          if (isAccepted || isEnRouteOrArrived || isInProgress) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tertiaryContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.onTertiaryContainer.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AppColors.onTertiaryContainer),
                      SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Doorstep Release OTP',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onTertiaryContainer),
                          ),
                          Text(
                            'Share with partner only after work is done',
                            style: TextStyle(fontSize: 10, color: AppColors.onTertiaryContainer),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      otp,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Action buttons depending on state
          if (isPending) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _handleCancelBooking,
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel Booking'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _handleRescheduleBooking,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: const Text('Reschedule'),
                  ),
                ),
              ],
            ),
          ] else if (isAccepted) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CustomerLiveTrackingScreen(bookingId: bookingId),
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Track Artisan'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.outlineVariant),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _handleRescheduleBooking,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: const Text('Reschedule'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: _handleCancelBooking,
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: const Text('Cancel Booking (Subject to dispatch status)'),
              ),
            ),
          ] else if (isEnRouteOrArrived) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CustomerLiveTrackingScreen(bookingId: bookingId),
                    ),
                  );
                },
                icon: const Icon(Icons.navigation, size: 18),
                label: const Text('Track Live Location & ETA', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ] else if (isInProgress) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.timer_outlined, color: AppColors.primary),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Artisan is currently performing the requested service. Once complete, you will be asked to confirm and rate the service.',
                      style: TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (isCompleted) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      ReviewRatingModal.show(
                        context,
                        bookingId: bookingId,
                        workerName: workerName,
                        serviceName: serviceName,
                      );
                    },
                    icon: const Icon(Icons.star_rounded, size: 18),
                    label: const Text('Rate & Review', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.outlineVariant),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      final invoice = InvoiceModel.fromBooking(
                        _booking,
                        worker: (_booking['workers'] as Map<String, dynamic>?),
                        customer: (_booking['customers'] as Map<String, dynamic>?),
                        payment: (_booking['payments'] is List && (_booking['payments'] as List).isNotEmpty
                            ? (_booking['payments'] as List).first as Map<String, dynamic>
                            : (_booking['payments'] as Map<String, dynamic>?)),
                      );
                      InvoiceViewDialog.show(context, invoice: invoice);
                    },
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('View Invoice'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCancellationReasonCard(String reason, String? cancelledAt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.error, size: 18),
              SizedBox(width: 6),
              Text(
                'Cancellation Record',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Reason: $reason',
            style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
          if (cancelledAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Cancelled on: $cancelledAt',
              style: const TextStyle(fontSize: 11, color: AppColors.outline),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkerCard({
    required String workerName,
    required String workerPhone,
    required double workerRating,
    required String workerTrade,
    required String federationName,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assigned Artisan Partner',
            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.primaryContainer,
                child: Text(
                  workerName.isNotEmpty ? workerName[0].toUpperCase() : 'A',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          workerName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified, size: 16, color: AppColors.onTertiaryContainer),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$workerTrade • $workerRating ★',
                      style: const TextStyle(fontSize: 12, color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      federationName,
                      style: const TextStyle(fontSize: 11, color: AppColors.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceAndScheduleCard({
    required String serviceName,
    required String scheduledDate,
    required String scheduledTime,
    required String address,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service & Appointment',
            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
          const SizedBox(height: 14),
          _buildDetailRow(Icons.build_circle_outlined, 'Service', serviceName),
          const Divider(height: 16),
          _buildDetailRow(Icons.calendar_today, 'Date & Slot', '$scheduledDate • $scheduledTime'),
          const Divider(height: 16),
          _buildDetailRow(Icons.location_on_outlined, 'Service Address', address),
        ],
      ),
    );
  }

  Widget _buildPaymentBreakdownCard({
    required double amount,
    required String status,
  }) {
    final isCancelled = status == 'cancelled' || status == 'rejected';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Summary',
                style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isCancelled ? AppColors.surfaceContainerHigh : AppColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCancelled ? 'REFUNDED' : 'ESCROW SECURED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isCancelled ? AppColors.outline : AppColors.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildPriceRow('Standard Service Fee', amount),
          _buildPriceRow('Union Fair-Wage Guarantee', 0.0, isZeroCommission: true),
          _buildPriceRow('Intermediary Commission', 0.0, isZeroCommission: true),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
              Text('₹${amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.outline)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(String label, double price, {bool isZeroCommission = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.onSurfaceVariant)),
          Text(
            isZeroCommission ? '₹0 (0% Commission)' : '₹${price.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isZeroCommission ? AppColors.onTertiaryContainer : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
