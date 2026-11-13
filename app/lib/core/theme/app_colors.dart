import 'package:flutter/material.dart';
import '../models/booking_status.dart';

/// National Civic Infrastructure / Bharat DPI Sovereign Palette for ShramSetu.
/// Reflects the Government of India Digital Public Infrastructure design system:
/// Deep Sovereign Navy (#001026), Civic Navy Blue (#0B2545), Bharat Saffron (#A83900 & #FC6018),
/// and Ashoka / Tricolor Civic Green (#001405 & #3A9E58).
class AppColors {
  // ──────────────── Core Suggested Color Palette ────────────────
  /// Deep teal - Primary actions (#0D5C5B)
  static const Color deepTeal = Color(0xFF0D5C5B);
  static const Color onDeepTeal = Color(0xFFFFFFFF);
  static const Color deepTealContainer = Color(0xFFE0F2F1);
  static const Color onDeepTealContainer = Color(0xFF00363A);
  static const Color primaryAction = deepTeal;
  static const Color onPrimaryAction = onDeepTeal;
  static const Color primaryActionContainer = deepTealContainer;
  static const Color onPrimaryActionContainer = onDeepTealContainer;

  /// Soft white - Page background (#F8F9FA)
  static const Color softWhite = Color(0xFFF8F9FA);
  static const Color pageBackground = softWhite;

  /// Warm amber - Highlights (#D97706)
  static const Color warmAmber = Color(0xFFD97706);
  static const Color onWarmAmber = Color(0xFFFFFFFF);
  static const Color warmAmberContainer = Color(0xFFFEF3C7);
  static const Color onWarmAmberContainer = Color(0xFF78350F);
  static const Color highlight = warmAmber;
  static const Color highlightContainer = warmAmberContainer;
  static const Color onHighlightContainer = onWarmAmberContainer;

  /// Green - Success states (#16A34A)
  static const Color successGreen = Color(0xFF16A34A);
  static const Color onSuccessGreen = Color(0xFFFFFFFF);
  static const Color successGreenContainer = Color(0xFFDCFCE7);
  static const Color onSuccessGreenContainer = Color(0xFF14532D);

  // Primary - Deep Teal (#0D5C5B)
  static const Color primary = deepTeal;
  static const Color onPrimary = onDeepTeal;
  static const Color primaryContainer = deepTealContainer;
  static const Color onPrimaryContainer = onDeepTealContainer;
  static const Color primaryFixed = Color(0xFFE0F2F1);
  static const Color primaryFixedDim = Color(0xFFB2DFDB);
  static const Color onPrimaryFixed = Color(0xFF00363A);
  static const Color onPrimaryFixedVariant = Color(0xFF0D5C5B);

  // Secondary - Warm Amber (#D97706)
  static const Color secondary = warmAmber;
  static const Color onSecondary = onWarmAmber;
  static const Color secondaryContainer = warmAmberContainer;
  static const Color onSecondaryContainer = onWarmAmberContainer;
  static const Color secondaryFixed = Color(0xFFFEF3C7);
  static const Color secondaryFixedDim = Color(0xFFFDE68A);
  static const Color onSecondaryFixed = Color(0xFF78350F);
  static const Color onSecondaryFixedVariant = Color(0xFFB45309);

  // Tertiary - Ashoka / Trust Green (#16A34A)
  static const Color tertiary = successGreen;
  static const Color onTertiary = onSuccessGreen;
  static const Color tertiaryContainer = successGreenContainer;
  static const Color onTertiaryContainer = onSuccessGreenContainer;
  static const Color tertiaryFixed = Color(0xFFDCFCE7);
  static const Color tertiaryFixedDim = Color(0xFFBBF7D0);
  static const Color onTertiaryFixed = Color(0xFF14532D);
  static const Color onTertiaryFixedVariant = Color(0xFF16A34A);

  // Error - Clean Crimson
  static const Color error = Color(0xFFDC2626);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onErrorContainer = Color(0xFF991B1B);

  // Surface & Background - Soft White (#F8F9FA) & Light Neutral Surfaces (#F1F5F9)
  static const Color background = softWhite;
  static const Color onBackground = Color(0xFF0F172A);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF0F172A);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color onSurfaceVariant = Color(0xFF475569);
  
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF8FAFC);
  static const Color surfaceContainer = Color(0xFFF1F5F9);
  static const Color surfaceContainerHigh = Color(0xFFE2E8F0);
  static const Color surfaceContainerHighest = Color(0xFFCBD5E1);
  
  static const Color surfaceBright = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFE2E8F0);
  static const Color surfaceTint = deepTeal;

  // Outline - Subtle Civic Borders
  static const Color outline = Color(0xFF64748B);
  static const Color outlineVariant = Color(0xFFE2E8F0);

  // Warning - Warm Amber
  static const Color warning = warmAmber;
  static const Color onWarning = onWarmAmber;
  static const Color warningContainer = warmAmberContainer;
  static const Color onWarningContainer = onWarmAmberContainer;

  // Success - Ashoka Green (#16A34A)
  static const Color success = successGreen;
  static const Color onSuccess = onSuccessGreen;
  static const Color successContainer = successGreenContainer;
  static const Color onSuccessContainer = onSuccessGreenContainer;

  // Info - Deep Civic Blue / Sky
  static const Color info = Color(0xFF0284C7);
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color infoContainer = Color(0xFFE0F2FE);
  static const Color onInfoContainer = Color(0xFF0369A1);

  // Semantic UI Aliases
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = onSurfaceVariant;
  static const Color textTertiary = outline;
  static const Color border = outlineVariant;
  static const Color divider = outlineVariant;
  static const Color cardBackground = surfaceContainerLowest;
  static const Color starRating = warmAmber;
  static const Color disabled = Color(0xFF94A3B8);
  static const Color disabledContainer = surfaceContainerLow;

  // National Identity & Civic Indicators (Tricolor)
  static const Color flagSaffron = warmAmber;
  static const Color flagNavy = deepTeal;
  static const Color flagGreen = successGreen;
  static const Color civicVerifiedGreen = successGreen;
  static const Color tertiaryFixedVariant = onTertiaryFixedVariant;

  // ──────────────── Status Visual Helpers ────────────────

  static Color bookingStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return warning;
      case BookingStatus.accepted:
      case BookingStatus.onTheWay:
      case BookingStatus.arrived:
      case BookingStatus.inProgress:
        return primary;
      case BookingStatus.completed:
        return success;
      case BookingStatus.rejected:
      case BookingStatus.cancelled:
        return error;
    }
  }

  static Color bookingStatusContainer(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return warningContainer;
      case BookingStatus.accepted:
      case BookingStatus.onTheWay:
      case BookingStatus.arrived:
      case BookingStatus.inProgress:
        return primaryContainer;
      case BookingStatus.completed:
        return successContainer;
      case BookingStatus.rejected:
      case BookingStatus.cancelled:
        return errorContainer;
    }
  }

  static Color bookingStatusTextColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return onWarningContainer;
      case BookingStatus.accepted:
      case BookingStatus.onTheWay:
      case BookingStatus.arrived:
      case BookingStatus.inProgress:
        return onPrimaryContainer;
      case BookingStatus.completed:
        return onSuccessContainer;
      case BookingStatus.rejected:
      case BookingStatus.cancelled:
        return onErrorContainer;
    }
  }

  static Color statusColorFromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
      case 'open':
      case 'in_review':
      case 'inreview':
        return warning;
      case 'accepted':
      case 'ontheway':
      case 'arrived':
      case 'inprogress':
      case 'in_progress':
        return primary;
      case 'completed':
      case 'paid':
      case 'resolved':
      case 'active':
      case 'approved':
      case 'verified':
        return success;
      case 'rejected':
      case 'cancelled':
      case 'canceled':
      case 'failed':
      case 'inactive':
      case 'closed':
        return error;
      default:
        return primary;
    }
  }

  static Color statusContainerFromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
      case 'open':
      case 'in_review':
      case 'inreview':
        return warningContainer;
      case 'accepted':
      case 'ontheway':
      case 'arrived':
      case 'inprogress':
      case 'in_progress':
        return primaryContainer;
      case 'completed':
      case 'paid':
      case 'resolved':
      case 'active':
      case 'approved':
      case 'verified':
        return successContainer;
      case 'rejected':
      case 'cancelled':
      case 'canceled':
      case 'failed':
      case 'inactive':
      case 'closed':
        return errorContainer;
      default:
        return surfaceContainerLow;
    }
  }

  static Color statusTextColorFromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
      case 'open':
      case 'in_review':
      case 'inreview':
        return onWarningContainer;
      case 'accepted':
      case 'ontheway':
      case 'arrived':
      case 'inprogress':
      case 'in_progress':
        return onPrimaryContainer;
      case 'completed':
      case 'paid':
      case 'resolved':
      case 'active':
      case 'approved':
      case 'verified':
        return onSuccessContainer;
      case 'rejected':
      case 'cancelled':
      case 'canceled':
      case 'failed':
      case 'inactive':
      case 'closed':
        return onErrorContainer;
      default:
        return onSurface;
    }
  }
}
