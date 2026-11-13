import 'package:flutter/material.dart';
import '../../core/models/booking_status.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../../core/localization/app_strings.dart';

/// Distinct, accessible badge for booking and order statuses.
///
/// **Accessibility Note**:
/// In compliance with accessibility standards and WCAG 1.4.1 (Use of Color),
/// this badge does NOT rely on color alone to convey status. Every status
/// pairs a dedicated, distinct semantic icon, high-contrast text label,
/// subtle enclosing border, and explicit [Semantics] screen reader announcement.
class BookingStatusBadge extends StatelessWidget {
  final BookingStatus status;
  final bool isCompact;
  final String? customLabel;

  const BookingStatusBadge({
    super.key,
    required this.status,
    this.isCompact = false,
    this.customLabel,
  });

  /// Factory constructor to parse status safely from a raw string.
  factory BookingStatusBadge.fromString(
    String? rawStatus, {
    Key? key,
    bool isCompact = false,
    String? customLabel,
  }) {
    return BookingStatusBadge(
      key: key,
      status: BookingStatus.fromDbString(rawStatus),
      isCompact: isCompact,
      customLabel: customLabel,
    );
  }

  /// Returns a distinct icon for every booking status state.
  static IconData iconForStatus(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return Icons.schedule_rounded;
      case BookingStatus.accepted:
        return Icons.check_circle_outline_rounded;
      case BookingStatus.onTheWay:
        return Icons.near_me_rounded;
      case BookingStatus.arrived:
        return Icons.location_on_rounded;
      case BookingStatus.inProgress:
        return Icons.build_circle_rounded;
      case BookingStatus.completed:
        return Icons.verified_rounded;
      case BookingStatus.rejected:
        return Icons.highlight_off_rounded;
      case BookingStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fgColor = AppColors.bookingStatusTextColor(status);
    final bgColor = AppColors.bookingStatusContainer(status);
    final borderColor = AppColors.bookingStatusColor(status).withValues(alpha: 0.35);
    final iconData = iconForStatus(status);
    final labelText = customLabel ?? status.label.tr();

    return Semantics(
      label: 'Booking status: ${status.label}',
      readOnly: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 8.0 : 10.0,
          vertical: isCompact ? 3.0 : 5.0,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: AppRadius.radiusFull,
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              iconData,
              size: isCompact ? 13.0 : 15.0,
              color: fgColor,
            ),
            const SizedBox(width: 5.0),
            Flexible(
              child: Text(
                labelText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSm.copyWith(
                  color: fgColor,
                  fontWeight: FontWeight.w700,
                  fontSize: isCompact ? 11.0 : 12.0,
                  height: 1.1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
