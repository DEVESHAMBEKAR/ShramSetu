import 'package:flutter/material.dart';
import '../models/booking_status.dart';

/// National Civic Infrastructure / Bharat DPI Sovereign Palette for ShramSetu.
/// Reflects the Government of India Digital Public Infrastructure design system:
/// Deep Sovereign Navy (#001026), Civic Navy Blue (#0B2545), Bharat Saffron (#A83900 & #FC6018),
/// and Ashoka / Tricolor Civic Green (#001405 & #3A9E58).
class AppColors {
  // Primary - Deep Sovereign Navy / India Ink (#001026)
  static const Color primary = Color(0xFF001026);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF0B2545);
  static const Color onPrimaryContainer = Color(0xFF778DB2);
  static const Color primaryFixed = Color(0xFFD5E3FF);
  static const Color primaryFixedDim = Color(0xFFB1C7F0);
  static const Color onPrimaryFixed = Color(0xFF001C3B);
  static const Color onPrimaryFixedVariant = Color(0xFF314769);

  // Secondary - Sovereign Saffron Ochre & Vibrant Bharat Saffron (#A83900 & #FC6018)
  static const Color secondary = Color(0xFFA83900);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFC6018);
  static const Color onSecondaryContainer = Color(0xFF531800);
  static const Color secondaryFixed = Color(0xFFFFDBCF);
  static const Color secondaryFixedDim = Color(0xFFFFB59A);
  static const Color onSecondaryFixed = Color(0xFF380D00);
  static const Color onSecondaryFixedVariant = Color(0xFF802A00);

  // Tertiary - Ashoka / Tricolor Civic Green (#001405 & #3A9E58)
  static const Color tertiary = Color(0xFF001405);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF002C10);
  static const Color onTertiaryContainer = Color(0xFF3A9E58);
  static const Color tertiaryFixed = Color(0xFF93F8A8);
  static const Color tertiaryFixedDim = Color(0xFF77DB8E);
  static const Color onTertiaryFixed = Color(0xFF00210B);
  static const Color onTertiaryFixedVariant = Color(0xFF005224);

  // Error - Clean Crimson
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Surface & Background - Sovereign Light Civic (#F7F9FC)
  static const Color background = Color(0xFFF7F9FC);
  static const Color onBackground = Color(0xFF191C1E);
  static const Color surface = Color(0xFFF7F9FC);
  static const Color onSurface = Color(0xFF191C1E);
  static const Color surfaceVariant = Color(0xFFE0E3E6);
  static const Color onSurfaceVariant = Color(0xFF44474E);
  
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F4F7);
  static const Color surfaceContainer = Color(0xFFECEEF1);
  static const Color surfaceContainerHigh = Color(0xFFE6E8EB);
  static const Color surfaceContainerHighest = Color(0xFFE0E3E6);
  
  static const Color surfaceBright = Color(0xFFF7F9FC);
  static const Color surfaceDim = Color(0xFFD8DADD);
  static const Color surfaceTint = Color(0xFF495F82);

  // Outline - Subtle Civic Borders
  static const Color outline = Color(0xFF74777F);
  static const Color outlineVariant = Color(0xFFC4C6CF);

  // Warning - Warm Saffron Amber
  static const Color warning = Color(0xFFB54708);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color warningContainer = Color(0xFFFEF0C7);
  static const Color onWarningContainer = Color(0xFF7A4100);

  // Success - Ashoka Green
  static const Color success = Color(0xFF3A9E58);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFE6F7EC);
  static const Color onSuccessContainer = Color(0xFF005224);

  // Info - Deep Civic Blue
  static const Color info = Color(0xFF0B2545);
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color infoContainer = Color(0xFFD5E3FF);
  static const Color onInfoContainer = Color(0xFF001C3B);

  // Semantic UI Aliases
  static const Color textPrimary = primary;
  static const Color textSecondary = onSurfaceVariant;
  static const Color textTertiary = outline;
  static const Color border = outlineVariant;
  static const Color divider = outlineVariant;
  static const Color cardBackground = surfaceContainerLowest;
  static const Color starRating = Color(0xFFFC6018);
  static const Color disabled = Color(0xFF9E9E9E);
  static const Color disabledContainer = surfaceContainerLow;

  // National Identity & Civic Indicators (Tricolor)
  static const Color flagSaffron = Color(0xFFFC6018);
  static const Color flagNavy = Color(0xFF0B2545);
  static const Color flagGreen = Color(0xFF3A9E58);
  static const Color civicVerifiedGreen = Color(0xFF3A9E58);
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
        return secondary;
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
        return secondaryFixed;
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
        return onSecondaryFixed;
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
        return secondary;
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
        return secondaryFixed;
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
        return onSecondaryFixed;
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
