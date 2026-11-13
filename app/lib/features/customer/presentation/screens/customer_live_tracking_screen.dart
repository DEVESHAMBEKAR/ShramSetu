import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/models/booking_status.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../widgets/review_rating_modal.dart';
import '../../../../core/localization/locale_controller.dart';
import '../../../../shared/widgets/booking_status_badge.dart';
import '../../../../shared/widgets/state_views.dart';
import '../../../../core/services/shared_booking_store.dart';

class CustomerLiveTrackingScreen extends StatefulWidget {
  final String bookingId;

  const CustomerLiveTrackingScreen({super.key, required this.bookingId});

  @override
  State<CustomerLiveTrackingScreen> createState() => _CustomerLiveTrackingScreenState();
}

class _CustomerLiveTrackingScreenState extends State<CustomerLiveTrackingScreen> {
  Map<String, dynamic>? _bookingData;
  bool _isLoading = true;
  String? _errorMessage;
  StreamSubscription<Map<String, dynamic>?>? _bookingSub;
  bool _copiedOtp = false;

  @override
  void initState() {
    super.initState();
    _subscribeToBookingUpdates();
  }

  @override
  void dispose() {
    _bookingSub?.cancel();
    super.dispose();
  }

  void _subscribeToBookingUpdates() {
    _bookingSub?.cancel();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    _bookingSub = DI.customerRepo.watchBookingDetails(widget.bookingId).listen(
      (data) {
        if (mounted) {
          final prevStatus = _bookingData?['status'] as String?;
          final newStatus = data?['status'] as String?;
          setState(() {
            _bookingData = data;
            _isLoading = false;
          });
          // Trigger escrow release when booking transitions to completed
          if (prevStatus != 'completed' && newStatus == 'completed') {
            _triggerEscrowRelease();
          }
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _errorMessage = e.toString();
            _isLoading = false;
          });
        }
      },
    );
  }

  Future<void> _triggerEscrowRelease() async {
    try {
      final released = await DI.paymentRepo.releaseEscrow(widget.bookingId);
      if (released && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Payment released to Karigar. Service complete!'),
            backgroundColor: Color(0xFF2E7D32),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Silently log — webhook will reconcile if Edge Function call fails
      debugPrint('[EscrowRelease] Non-critical error: $e');
    }
  }

  Future<void> _loadBookingDetails() async {
    _subscribeToBookingUpdates();
  }

  BookingStatus _parseStatus(String? statusStr) {
    return BookingStatus.fromDbString(statusStr);
  }

  String get _orderRef {
    final id = widget.bookingId;
    if (id.length >= 4) {
      return id.substring(0, 4).toUpperCase();
    }
    return id.toUpperCase();
  }

  void _copyOtp(String otp) {
    Clipboard.setData(ClipboardData(text: otp));
    setState(() => _copiedOtp = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Escrow Release Code $otp copied to clipboard!'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryContainer,
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copiedOtp = false);
    });
  }

  Future<void> _switchPaymentToRazorpay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        title: const Text('Pay via Razorpay / UPI', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
        content: const Text('Switch this order to Sovereign Online Escrow? You can pay immediately via UPI or Net Banking.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Cash')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Switch to Online'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DI.paymentRepo.createPaymentOrder(widget.bookingId);
        // Update local booking store
        SharedBookingStore.instance.addExternalBooking({
          'id': widget.bookingId,
          'payment_method': 'RAZORPAY',
        });
        _loadBookingDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Switched to Razorpay Online Escrow.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment switch note: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleCancelBooking() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        title: Text('Cancel Booking?', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
        content: Text(
          'Are you sure you want to cancel this booking? Full escrow payment will be immediately released back to you.',
          style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Booking', style: AppTypography.labelLg.copyWith(color: AppColors.outline)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.onError,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await DI.customerRepo.cancelBooking(widget.bookingId);
        _loadBookingDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Booking cancelled. Escrow refund initiated.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to cancel: $e')),
          );
        }
      }
    }
  }

  void _showUrgentHelpModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.marginMobile),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.errorContainer, shape: BoxShape.circle),
                  child: const Icon(Icons.emergency, color: AppColors.onErrorContainer, size: 24),
                ),
                const SizedBox(width: AppSpacing.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ShramSetu Dispatch Helpline', style: AppTypography.titleLg.copyWith(color: AppColors.primary)),
                      Text('Pune Cooperative Central Command', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            Text(
              'If you need immediate assistance with worker arrival, safety, or trade dispute, our cooperative rapid team is on standby.',
              style: AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.spacingLg),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(const ClipboardData(text: '1800-419-7868'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Helpline 1800-419-7868 copied to dialer!')),
                  );
                },
                icon: const Icon(Icons.phone_in_talk),
                label: const Text('Call Helpline: 1800-419-7868'),
              ),
            ),
            const SizedBox(height: AppSpacing.spacingSm),
          ],
        ),
      ),
    );
  }

  void _showContactAction(String type, String workerName, String? phone) {
    final cleanPhone = phone ?? '+91 98000 12345';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        title: Row(
          children: [
            Icon(type == 'Call' ? Icons.call : Icons.chat, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('$type $workerName', style: AppTypography.titleMd.copyWith(color: AppColors.primary)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contact Number:', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text(cleanPhone, style: AppTypography.titleLg.copyWith(fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: AppSpacing.spacingSm),
            Text(
              type == 'Call'
                ? 'Cooperative direct line connected without caller ID masking for complete transparency.'
                : 'Send direct WhatsApp message regarding booking #SS-$_orderRef.',
              style: AppTypography.bodySm.copyWith(color: AppColors.outline),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: cleanPhone));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Number $cleanPhone copied to dialer')),
              );
            },
            child: Text('Copy & Dial'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: const AppLoadingView(message: 'Tracking your live service order...'),
      );
    }

    if (_errorMessage != null || _bookingData == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: _buildAppBar(),
        body: AppErrorView(
          title: 'Could not load booking',
          message: _errorMessage ?? 'Booking not found',
          onRetry: _loadBookingDetails,
        ),
      );
    }

    final booking = _bookingData!;
    final status = _parseStatus(booking['status'] as String?);
    final worker = booking['workers'] as Map<String, dynamic>? ?? {};
    final workerUser = worker['users'] as Map<String, dynamic>? ?? {};
    final service = booking['services'] as Map<String, dynamic>? ?? {};
    final address = booking['addresses'] as Map<String, dynamic>? ?? {};

    final workerName = workerUser['full_name'] as String? ?? 'Shri Rahul Patil';
    final workerPhone = workerUser['phone'] as String? ?? '+91 98000 12345';
    final workerAvatar = workerUser['avatar_url'] as String? ?? '';
    final workerRating = (worker['rating'] as num?)?.toDouble() ?? 4.8;
    final jobsCompleted = worker['completed_jobs'] as int? ?? 342;
    final workerLocation = worker['location_tag'] as String? ?? 'Kothrud Stand';

    final serviceName = service['name'] as String? ?? 'General Service';
    final serviceDesc = service['description'] as String? ?? 'Includes cooperative standard check & repair';

    final baseAmount = (booking['base_amount'] as num?)?.toDouble() ?? 450.0;
    final laborAllowance = (booking['labor_allowance'] as num?)?.toDouble() ?? 35.0;
    final totalEscrow = baseAmount + laborAllowance;

    final customerAddress = address['address_line'] as String? ?? 'Flat 402, Paud Road, Pune';
    final otpCode = booking['otp'] as String? ?? '8492';
    final paymentMethod = (booking['payment_method'] as String?)?.toUpperCase() ?? 'RAZORPAY';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _loadBookingDetails,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Order Reference Header Strip
                  _buildOrderRefHeader(status),

                  // 2. Live Status Hero Card
                  _buildStatusHeroCard(status, workerName, workerLocation, customerAddress),

                  // 3. Visual Route & Location Map HUD
                  _buildMapHud(workerName, status, workerLocation),

                  // 4. Worker Trust & Direct Communications Card
                  _buildWorkerCard(workerName, workerAvatar, workerRating, jobsCompleted, workerPhone),

                  // 5. 4-Digit Escrow Release Security Box
                  _buildEscrowSecurityBox(otpCode, workerName, status, paymentMethod, totalEscrow),

                  // 6. Service Milestones Progress Timeline
                  _buildMilestoneTimeline(status),

                  // 7. Job & Fare Summary
                  _buildFareSummaryCard(serviceName, serviceDesc, baseAmount, laborAllowance, totalEscrow, paymentMethod, status, workerName),

                  // 8. Action Buttons (Reschedule / Cancel / Rate)
                  _buildActionButtons(status, workerName, serviceName),

                  // 9. Cooperative Assurance Footer
                  _buildAssuranceFooter(workerName),

                  const SizedBox(height: AppSpacing.spacing2xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.surface.withValues(alpha: 0.9),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.primary),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Image.asset('assets/images/logo.jpg', height: 26, width: 26, fit: BoxFit.contain),
          const SizedBox(width: AppSpacing.spacingXs),
          Text(
            'Live Job Tracking',
            style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        ListenableBuilder(
          listenable: LocaleController.instance,
          builder: (context, _) {
            return InkWell(
              borderRadius: AppRadius.radiusLg,
              onTap: () {
                LocaleController.instance.toggleNextLanguage();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacing2xs, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: AppRadius.radiusLg,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.translate, size: 14, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      LocaleController.instance.isMarathi
                          ? 'मराठी'
                          : (LocaleController.instance.isHindi ? 'हिंदी' : 'EN'),
                      style: AppTypography.labelSm.copyWith(color: AppColors.onSurface),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.support_agent, color: AppColors.onSurfaceVariant),
          tooltip: 'Cooperative Helpline',
          onPressed: _showUrgentHelpModal,
        ),
        const SizedBox(width: AppSpacing.spacingXs),
      ],
    );
  }

  Widget _buildOrderRefHeader(BookingStatus status) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.marginMobile, AppSpacing.spacingSm, AppSpacing.marginMobile, AppSpacing.spacingXs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.secondaryContainer,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.spacingXs),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'ORDER REFERENCE',
                        style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, letterSpacing: 1.1),
                      ),
                      const SizedBox(width: 8),
                      BookingStatusBadge(status: status, isCompact: true),
                    ],
                  ),
                  Text(
                    '#SS-$_orderRef',
                    style: AppTypography.headlineSm.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorContainer,
              foregroundColor: AppColors.onErrorContainer,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingSm, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
            ),
            onPressed: _showUrgentHelpModal,
            icon: const Icon(Icons.emergency_outlined, size: 18),
            label: Text('Urgent Help', style: AppTypography.labelMd.copyWith(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusHeroCard(BookingStatus status, String workerName, String workerLoc, String destAddress) {
    String badgeText;
    IconData badgeIcon;
    Color badgeBg;
    Color badgeColor;
    String etaText;
    String headline;

    switch (status) {
      case BookingStatus.pending:
        badgeText = 'Booking Placed';
        badgeIcon = Icons.hourglass_top;
        badgeBg = AppColors.surfaceContainerHigh;
        badgeColor = AppColors.onSurface;
        etaText = 'Matching worker';
        headline = 'Order confirmed, finding nearby cooperative artisan';
        break;
      case BookingStatus.accepted:
        badgeText = 'Worker Assigned';
        badgeIcon = Icons.assignment_turned_in;
        badgeBg = AppColors.primaryFixed;
        badgeColor = AppColors.onPrimaryFixed;
        etaText = 'Scheduled';
        headline = '$workerName has accepted your booking';
        break;
      case BookingStatus.onTheWay:
        badgeText = 'Worker On The Way';
        badgeIcon = Icons.two_wheeler;
        badgeBg = AppColors.tertiaryFixed;
        badgeColor = AppColors.onTertiaryFixed;
        etaText = '12 mins away';
        headline = '$workerName is en route from $workerLoc';
        break;
      case BookingStatus.arrived:
        badgeText = 'Worker Arrived';
        badgeIcon = Icons.location_on;
        badgeBg = AppColors.secondaryFixed;
        badgeColor = AppColors.onSecondaryFixed;
        etaText = 'At doorstep';
        headline = '$workerName has reached your address';
        break;
      case BookingStatus.inProgress:
        badgeText = 'Service Underway';
        badgeIcon = Icons.handyman;
        badgeBg = AppColors.secondaryContainer;
        badgeColor = AppColors.onSecondary;
        etaText = 'Active now';
        headline = 'Work is in progress. Inspect upon completion';
        break;
      case BookingStatus.completed:
        badgeText = 'Job Completed';
        badgeIcon = Icons.verified;
        badgeBg = AppColors.tertiaryContainer;
        badgeColor = AppColors.onTertiaryContainer;
        etaText = 'Settled';
        headline = 'Job completed and verified via Escrow OTP';
        break;
      case BookingStatus.cancelled:
        badgeText = 'Cancelled';
        badgeIcon = Icons.cancel;
        badgeBg = AppColors.errorContainer;
        badgeColor = AppColors.onErrorContainer;
        etaText = 'Refunded';
        headline = 'This booking was cancelled';
        break;
      default:
        badgeText = 'Active';
        badgeIcon = Icons.circle;
        badgeBg = AppColors.surfaceContainer;
        badgeColor = AppColors.onSurface;
        etaText = '';
        headline = 'Order in progress';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.spacingXs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusXl,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: 4),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: AppRadius.radiusFull),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(badgeIcon, size: 14, color: badgeColor),
                      const SizedBox(width: 4),
                      Text(badgeText, style: AppTypography.labelSm.copyWith(color: badgeColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                if (etaText.isNotEmpty)
                  Row(
                    children: [
                      Text(
                        etaText.split(' ').first,
                        style: AppTypography.headlineLgMobile.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        etaText.contains(' ') ? etaText.substring(etaText.indexOf(' ') + 1) : '',
                        style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingSm),
            Text(
              headline,
              style: AppTypography.titleMd.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.spacing2xs),
            Row(
              children: [
                const Icon(Icons.near_me, size: 16, color: AppColors.primary),
                const SizedBox(width: AppSpacing.spacing3xs),
                Expanded(
                  child: Text(
                    'Destination: $destAddress',
                    style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapHud(String workerName, BookingStatus status, String workerLocation) {
    final double workerTop;
    final double? workerLeft;
    final double? workerRight;
    final double? workerBottom;
    final String workerBadgeText;
    final IconData workerIcon;
    final String corridorPill;
    final double routeProgress;

    switch (status) {
      case BookingStatus.pending:
      case BookingStatus.accepted:
        workerTop = 85;
        workerLeft = 35;
        workerRight = null;
        workerBottom = null;
        workerBadgeText = '$workerName • Stand ($workerLocation)';
        workerIcon = Icons.storefront;
        corridorPill = 'Artisan Assigned • At Workshop Stand';
        routeProgress = 0.05;
        break;
      case BookingStatus.onTheWay:
        workerTop = 60;
        workerLeft = 140;
        workerRight = null;
        workerBottom = null;
        workerBadgeText = '$workerName (1.8 km • 12m away)';
        workerIcon = Icons.two_wheeler;
        corridorPill = 'In Transit • 3.5 km Ward Corridor';
        routeProgress = 0.55;
        break;
      case BookingStatus.arrived:
        workerTop = 90;
        workerLeft = null;
        workerRight = 90;
        workerBottom = null;
        workerBadgeText = '$workerName (At Doorstep)';
        workerIcon = Icons.location_on;
        corridorPill = 'Arrived • Ready for Inspection';
        routeProgress = 0.92;
        break;
      case BookingStatus.inProgress:
        workerTop = 85;
        workerLeft = null;
        workerRight = 75;
        workerBottom = null;
        workerBadgeText = '$workerName (Active Repair)';
        workerIcon = Icons.handyman;
        corridorPill = 'Service Underway • Active on Site';
        routeProgress = 1.0;
        break;
      case BookingStatus.completed:
        workerTop = 85;
        workerLeft = null;
        workerRight = 65;
        workerBottom = null;
        workerBadgeText = 'Job Verified & Completed ✓';
        workerIcon = Icons.verified;
        corridorPill = 'Completed • 100% Quality Guaranteed';
        routeProgress = 1.0;
        break;
      case BookingStatus.cancelled:
      case BookingStatus.rejected:
        workerTop = 85;
        workerLeft = 35;
        workerRight = null;
        workerBottom = null;
        workerBadgeText = 'Booking Cancelled';
        workerIcon = Icons.cancel;
        corridorPill = 'Cancelled';
        routeProgress = 0.0;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.spacingXs),
      child: Container(
        height: 210,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh,
          borderRadius: AppRadius.radiusXl,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Map stylized canvas grid & route background
            Positioned.fill(
              child: Container(
                color: const Color(0xFFE8EEF2),
                child: CustomPaint(
                  painter: _MapCanvasPainter(progress: routeProgress, status: status),
                ),
              ),
            ),

            // Live corridor alert pill top left
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingXs, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest.withValues(alpha: 0.95),
                  borderRadius: AppRadius.radiusLg,
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: status == BookingStatus.completed
                            ? AppColors.civicVerifiedGreen
                            : (status == BookingStatus.onTheWay ? AppColors.secondary : AppColors.primary),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      corridorPill,
                      style: AppTypography.labelSm.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),

            // 3.5 km Ward Radius indicator chip top right
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.9),
                  borderRadius: AppRadius.radiusSm,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radar, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      '3.5 km FairMatch Ward',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),

            // Cooperative Stand Pin (Origin)
            Positioned(
              top: 105,
              left: 28,
              child: Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHighest,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.outlineVariant),
                    ),
                    child: const Icon(Icons.storefront, size: 13, color: AppColors.primary),
                  ),
                  const SizedBox(height: 2),
                  Text('Stand Hub', style: AppTypography.labelSm.copyWith(fontSize: 9, color: AppColors.outline)),
                ],
              ),
            ),

            // Dynamic Worker Pin Marker (moves with stage)
            Positioned(
              top: workerTop,
              left: workerLeft,
              right: workerRight,
              bottom: workerBottom,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: status == BookingStatus.completed ? AppColors.civicVerifiedGreen : AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryFixed,
                          child: Icon(Icons.person, size: 18, color: AppColors.primary),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: status == BookingStatus.completed ? AppColors.civicVerifiedGreen : AppColors.secondaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(workerIcon, size: 10, color: status == BookingStatus.completed ? Colors.white : AppColors.onSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: status == BookingStatus.completed ? AppColors.civicVerifiedGreen : AppColors.primary,
                      borderRadius: AppRadius.radiusSm,
                    ),
                    child: Text(
                      workerBadgeText,
                      style: AppTypography.labelSm.copyWith(color: AppColors.onPrimary, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Customer Destination Pin (Target)
            Positioned(
              bottom: 16,
              right: 24,
              child: Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: AppColors.secondary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)],
                    ),
                    child: const Icon(Icons.home, color: AppColors.onSecondary, size: 20),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: AppRadius.radiusSm),
                    child: Text('Your Home', style: AppTypography.labelSm.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerCard(String name, String avatarUrl, double rating, int completedJobs, String phone) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.spacingXs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusXl,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryFixed,
                      backgroundImage: avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl.isEmpty ? const Icon(Icons.person, size: 32, color: AppColors.primary) : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: AppColors.tertiaryFixed, shape: BoxShape.circle),
                        child: const Icon(Icons.verified, size: 14, color: AppColors.onTertiaryFixed),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.spacingSm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      Text('Master Plumber • Guild Unit #128', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: AppColors.starRating),
                          const SizedBox(width: 3),
                          Text(rating.toStringAsFixed(1), style: AppTypography.labelSm.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 4),
                          Text('($completedJobs verified jobs)', style: AppTypography.bodySm.copyWith(color: AppColors.outline, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.tertiaryFixed.withValues(alpha: 0.3), borderRadius: AppRadius.radiusSm),
                  child: Text('Govt KYC OK', style: AppTypography.labelSm.copyWith(color: AppColors.tertiary, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                    ),
                    onPressed: () => _showContactAction('Call', name, phone),
                    icon: const Icon(Icons.call, size: 18),
                    label: Text('Call $name', style: AppTypography.labelLg),
                  ),
                ),
                const SizedBox(width: AppSpacing.spacingSm),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surfaceContainerHigh,
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                    ),
                    onPressed: () => _showContactAction('WhatsApp / SMS', name, phone),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: Text('Message', style: AppTypography.labelLg),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEscrowSecurityBox(String otp, String workerName, BookingStatus status, String paymentMethod, double totalAmount) {
    final isSettled = status == BookingStatus.completed;
    final isCash = paymentMethod == 'CASH';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.spacingXs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.radiusXl,
          border: Border.all(color: AppColors.outlineVariant, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(isCash ? Icons.payments_outlined : Icons.lock, size: 16, color: AppColors.secondary),
                    const SizedBox(width: 4),
                    Text(
                      isCash ? 'Order Verification Code' : 'Escrow Protection Code',
                      style: AppTypography.labelSm.copyWith(color: AppColors.secondary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSettled
                        ? AppColors.tertiaryFixed
                        : (isCash ? const Color(0xFFFFF3E0) : AppColors.tertiaryFixed.withValues(alpha: 0.5)),
                    borderRadius: AppRadius.radiusSm,
                  ),
                  child: Text(
                    isSettled
                        ? (isCash ? 'Service Settled' : 'Payment Released')
                        : (isCash ? 'Pay on Completion' : 'Payment Locked'),
                    style: AppTypography.labelSm.copyWith(
                      color: isCash ? const Color(0xFFE65100) : AppColors.tertiary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingSm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.spacingMd, vertical: AppSpacing.spacingSm),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppRadius.radiusLg,
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('COMPLETION OTP', style: AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant, letterSpacing: 1.1)),
                      const SizedBox(height: 4),
                      Row(
                        children: otp.split('').map((digit) {
                          return Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: AppRadius.radiusSm,
                            ),
                            child: Text(
                              digit,
                              style: AppTypography.currencyDisplay.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(_copiedOtp ? Icons.check : Icons.content_copy, color: _copiedOtp ? AppColors.tertiaryContainer : AppColors.primary),
                    tooltip: 'Copy Code',
                    onPressed: () => _copyOtp(otp),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.spacingXs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user_outlined, size: 16, color: AppColors.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isCash
                        ? 'Hand over ₹${totalAmount.toStringAsFixed(0)} cash and share this 4-digit code with $workerName ONLY after complete inspection.'
                        : 'Share this 4-digit code with $workerName ONLY after job inspection and complete satisfaction to release escrow.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMilestoneTimeline(BookingStatus status) {
    final statusIndex = status.index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.spacingXs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusXl,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timeline, color: AppColors.secondary, size: 20),
                const SizedBox(width: 6),
                Text('Service Milestones', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingMd),
            _buildTimelineStep('Booking Confirmed', 'Assigned to Pune Cooperative Union Pool', '10:15 AM', Icons.check, true, status == BookingStatus.pending),
            _buildTimelineStep('Worker Dispatched & Travelling', 'En route via Paud Phata bypass', '10:40 AM', Icons.two_wheeler, statusIndex >= BookingStatus.onTheWay.index, status == BookingStatus.onTheWay),
            _buildTimelineStep('Arrived at Customer Location', 'Doorstep verification check', 'Est 10:52 AM', Icons.pin_drop, statusIndex >= BookingStatus.arrived.index, status == BookingStatus.arrived),
            _buildTimelineStep('Service Underway', 'Inspection & tap leakage repair', 'Est 11:00 AM', Icons.handyman, statusIndex >= BookingStatus.inProgress.index, status == BookingStatus.inProgress),
            _buildTimelineStep('Inspection & Escrow Payout', 'OTP exchange completes booking', 'Est 11:35 AM', Icons.verified, statusIndex >= BookingStatus.completed.index, status == BookingStatus.completed, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep(String title, String subtitle, String time, IconData icon, bool isCompleted, bool isCurrent, {bool isLast = false}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCurrent
                    ? AppColors.secondary
                    : (isCompleted ? AppColors.tertiaryFixed : AppColors.surfaceContainerHigh),
                  shape: BoxShape.circle,
                  border: isCurrent ? Border.all(color: const Color(0xFFE5DBFF), width: 3) : null,
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: isCurrent ? AppColors.onSecondary : (isCompleted ? AppColors.onTertiaryFixed : AppColors.onSurfaceVariant),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? AppColors.tertiaryFixed : AppColors.surfaceContainerHigh,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.spacingSm),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.spacingMd),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: AppTypography.labelLg.copyWith(
                                  color: isCurrent ? AppColors.primary : (isCompleted ? AppColors.onSurface : AppColors.onSurfaceVariant),
                                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isCurrent) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: AppColors.secondaryContainer, borderRadius: AppRadius.radiusSm),
                                child: Text('ACTIVE', style: AppTypography.labelSm.copyWith(color: AppColors.onSecondary, fontSize: 9)),
                              ),
                            ],
                          ],
                        ),
                        Text(subtitle, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Text(time, style: AppTypography.labelSm.copyWith(color: isCurrent ? AppColors.primary : AppColors.outline, fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFareSummaryCard(
    String serviceName,
    String serviceDesc,
    double base,
    double allowance,
    double total,
    String paymentMethod,
    BookingStatus status,
    String workerName,
  ) {
    final isCash = paymentMethod == 'CASH';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.spacingXs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.radiusXl,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Job & Fare Summary', style: AppTypography.titleMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isCash ? const Color(0xFFFFF3E0) : AppColors.tertiaryFixedDim.withValues(alpha: 0.3),
                    borderRadius: AppRadius.radiusFull,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCash ? Icons.payments_outlined : Icons.lock,
                        size: 11,
                        color: isCash ? const Color(0xFFE65100) : AppColors.onTertiaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCash ? 'Cash on Service' : 'Safe Escrow Deposit',
                        style: AppTypography.labelSm.copyWith(
                          color: isCash ? const Color(0xFFE65100) : AppColors.onTertiaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(serviceName, style: AppTypography.labelLg.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.w600)),
                      Text(serviceDesc, style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text('₹${base.toStringAsFixed(0)}', style: AppTypography.labelLg.copyWith(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: AppSpacing.spacingXs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Cooperative Worker Insurance & Safety Fund', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
                Text('₹${allowance.toStringAsFixed(0)}', style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCash ? 'Total Cash Due on Sign-off' : 'Total Amount Locked',
                      style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      isCash
                          ? 'Pay directly to $workerName after OTP verification'
                          : 'Held securely in ShramSetu Cooperative Escrow',
                      style: AppTypography.labelSm.copyWith(color: AppColors.tertiary, fontSize: 11),
                    ),
                  ],
                ),
                Text('₹${total.toStringAsFixed(0)}', style: AppTypography.currencyDisplay.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            if (isCash && status != BookingStatus.completed) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _switchPaymentToRazorpay,
                  icon: const Icon(Icons.credit_card, size: 16),
                  label: const Text('Switch & Pay via Razorpay / Online UPI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BookingStatus status, String workerName, String serviceName) {
    final canCancel = status == BookingStatus.pending || status == BookingStatus.accepted;
    final isCompleted = status == BookingStatus.completed;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.spacingXs),
      child: Column(
        children: [
          if (isCompleted) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                  elevation: 0,
                ),
                onPressed: () {
                  ReviewRatingModal.show(
                    context,
                    bookingId: widget.bookingId,
                    workerName: workerName,
                    serviceName: serviceName,
                  );
                },
                icon: const Icon(Icons.star_rounded, size: 20, color: AppColors.starRating),
                label: Text('Rate Service & Artisan', style: AppTypography.labelLg.copyWith(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
            const SizedBox(height: AppSpacing.spacingXs),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surfaceContainer,
                foregroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
              ),
              onPressed: _showUrgentHelpModal,
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text('Need Help or Reschedule?', style: AppTypography.labelLg),
            ),
          ),
          if (canCancel) ...[
            const SizedBox(height: AppSpacing.spacingXs),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                onPressed: _handleCancelBooking,
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: Text('Cancel Booking (Free before worker arrives)', style: AppTypography.labelMd),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssuranceFooter(String workerName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.spacingSm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.spacingSm),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppRadius.radiusXl,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(color: AppColors.primaryFixed, shape: BoxShape.circle),
              child: const Icon(Icons.diversity_3, color: AppColors.onPrimaryFixed, size: 20),
            ),
            const SizedBox(width: AppSpacing.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('100% Cooperative Fair Guarantee', style: AppTypography.labelMd.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  Text(
                    'Zero platform commission deductions. 100% of labour fees go directly to $workerName upon OTP release.',
                    style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapCanvasPainter extends CustomPainter {
  final double progress;
  final BookingStatus status;

  _MapCanvasPainter({this.progress = 0.5, this.status = BookingStatus.onTheWay});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Urban street network grid
    final gridRoadPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..strokeWidth = 7
      ..style = PaintingStyle.stroke;

    final roadPath1 = Path()
      ..moveTo(0, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.35, size.width, size.height * 0.75);
    canvas.drawPath(roadPath1, gridRoadPaint);

    final roadPath2 = Path()
      ..moveTo(size.width * 0.25, 0)
      ..lineTo(size.width * 0.75, size.height);
    canvas.drawPath(roadPath2, gridRoadPaint);

    final roadPath3 = Path()
      ..moveTo(size.width * 0.05, size.height * 0.8)
      ..lineTo(size.width * 0.95, size.height * 0.2);
    canvas.drawPath(roadPath3, gridRoadPaint);

    // 2. 3.5 km Ward radius boundary circle
    final radiusPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), size.height * 0.46, radiusPaint);

    final radiusBorderPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), size.height * 0.46, radiusBorderPaint);

    // 3. Planned Corridor Path
    final startPt = Offset(45, size.height * 0.52);
    final controlPt = Offset(size.width * 0.48, size.height * 0.38);
    final endPt = Offset(size.width - 45, size.height - 35);

    final plannedPath = Path()
      ..moveTo(startPt.dx, startPt.dy)
      ..quadraticBezierTo(controlPt.dx, controlPt.dy, endPt.dx, endPt.dy);

    final bgRoutePaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.12)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawPath(plannedPath, bgRoutePaint);

    // 4. Traveled Route Progress Path (vibrant amber / teal)
    final activeRoutePaint = Paint()
      ..color = status == BookingStatus.completed ? AppColors.civicVerifiedGreen : AppColors.secondary
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final progressPath = Path();
    progressPath.moveTo(startPt.dx, startPt.dy);

    final clampedProgress = progress.clamp(0.01, 1.0);
    final currentX = startPt.dx + (endPt.dx - startPt.dx) * clampedProgress;
    final currentY = startPt.dy + (endPt.dy - startPt.dy) * clampedProgress;
    final ctrlCurrentX = startPt.dx + (controlPt.dx - startPt.dx) * clampedProgress;
    final ctrlCurrentY = startPt.dy + (controlPt.dy - startPt.dy) * clampedProgress;
    progressPath.quadraticBezierTo(ctrlCurrentX, ctrlCurrentY, currentX, currentY);

    canvas.drawPath(progressPath, activeRoutePaint);
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.status != status;
}
