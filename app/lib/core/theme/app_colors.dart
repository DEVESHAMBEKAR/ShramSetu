import 'package:flutter/material.dart';
import '../models/booking_status.dart';

/// Modern Urban Company / Elite Service Standard Color Palette for ShramSetu.
/// Features Obsidian Black, Urban Company Royal Purple/Violet, and Emerald Trust Green.
class AppColors {
  // Primary - Urban Company Obsidian / Pure Black
  static const Color primary = Color(0xFF111111);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF1C1B1B);
  static const Color onPrimaryContainer = Color(0xFF858383);
  static const Color primaryFixed = Color(0xFFE5E2E1);
  static const Color primaryFixedDim = Color(0xFFC8C6C5);
  static const Color onPrimaryFixed = Color(0xFF1C1B1B);
  static const Color onPrimaryFixedVariant = Color(0xFF474646);

  // Secondary - Urban Company Signature Royal Purple / Violet
  static const Color secondary = Color(0xFF5A38E4);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFF7357FE);
  static const Color onSecondaryContainer = Color(0xFFFFFBFF);
  static const Color secondaryFixed = Color(0xFFE5DEFF);
  static const Color secondaryFixedDim = Color(0xFFC8BFFF);
  static const Color onSecondaryFixed = Color(0xFF1A0063);
  static const Color onSecondaryFixedVariant = Color(0xFF4413D0);

  // Tertiary - Emerald Verified / Cooperative Trust Green
  static const Color tertiary = Color(0xFF002113);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFECFDF3);
  static const Color onTertiaryContainer = Color(0xFF027A48);
  static const Color tertiaryFixed = Color(0xFF8DF7C1);
  static const Color tertiaryFixedDim = Color(0xFF71DBA6);
  static const Color onTertiaryFixed = Color(0xFF002113);
  static const Color onTertiaryFixedVariant = Color(0xFF005235);

  // Error - Clean Coral / Crimson
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Surface & Background - Ultra Clean Urban Company Light Gray / Crisp Minimal
  static const Color background = Color(0xFFF8F8FA);
  static const Color onBackground = Color(0xFF1A1B1F);
  static const Color surface = Color(0xFFF8F8FA);
  static const Color onSurface = Color(0xFF1A1B1F);
  static const Color surfaceVariant = Color(0xFFE3E2E7);
  static const Color onSurfaceVariant = Color(0xFF6B7280);
  
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF4F3F8);
  static const Color surfaceContainer = Color(0xFFEFEDF3);
  static const Color surfaceContainerHigh = Color(0xFFE9E7ED);
  static const Color surfaceContainerHighest = Color(0xFFE3E2E7);
  
  static const Color surfaceBright = Color(0xFFFAF8FE);
  static const Color surfaceDim = Color(0xFFDBD9DF);
  static const Color surfaceTint = Color(0xFF5A38E4);

  // Outline - Subtle Modern Borders
  static const Color outline = Color(0xFF747878);
  static const Color outlineVariant = Color(0xFFEAEAEA);

  // Warning - Warm Amber / Gold
  static const Color warning = Color(0xFFB54708);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color warningContainer = Color(0xFFFEF0C7);
  static const Color onWarningContainer = Color(0xFF7A4100);

  // Success - Emerald Cooperative
  static const Color success = Color(0xFF027A48);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFECFDF3);
  static const Color onSuccessContainer = Color(0xFF027A48);

  // Info - Royal Violet
  static const Color info = Color(0xFF5A38E4);
  static const Color onInfo = Color(0xFFFFFFFF);
  static const Color infoContainer = Color(0xFFE5DEFF);
  static const Color onInfoContainer = Color(0xFF1A0063);

  // Semantic UI Aliases
  static const Color textPrimary = primary;
  static const Color textSecondary = onSurfaceVariant;
  static const Color textTertiary = outline;
  static const Color border = outlineVariant;
  static const Color divider = outlineVariant;
  static const Color cardBackground = surfaceContainerLowest;
  static const Color starRating = Color(0xFFF59E0B);
  static const Color disabled = Color(0xFF9E9E9E);
  static const Color disabledContainer = surfaceContainerLow;

  // National Identity & Civic Indicators
  static const Color flagSaffron = Color(0xFFFF9933);
  static const Color flagNavy = Color(0xFF000080);
  static const Color flagGreen = Color(0xFF138808);

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
