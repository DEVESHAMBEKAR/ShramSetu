import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/app_radius.dart';

/// Official Government of India / National DPI Brand Mark for ShramSetu.
/// Conforms to the `new_ui` visual specification.
class ShramSetuBrandMark extends StatelessWidget {
  final double height;
  final bool compact;
  final bool showSubtitle;
  final String? clusterName;

  const ShramSetuBrandMark({
    super.key,
    double? height,
    double? size,
    bool? compact,
    bool? showText,
    this.showSubtitle = true,
    String? clusterName,
    String? subtitle,
  })  : height = size ?? height ?? 36,
        compact = compact ?? (showText != null ? !showText : false),
        clusterName = subtitle ?? clusterName;


  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Emblem Container with Ashoka / Tricolor Civic Accent
        Container(
          width: height,
          height: height,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(height * 0.25),
            border: Border.all(color: AppColors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryContainer.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          padding: const EdgeInsets.all(3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(height * 0.18),
            child: Image.asset(
              'assets/images/brand_mark.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Image.asset(
                'assets/images/logo.jpg',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Text Hierarchy
        if (!compact)
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'श्रमसेतू',
                    style: AppTypography.headlineSm.copyWith(
                      color: AppColors.primaryContainer,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      height: 1.1,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'ShramSetu',
                    style: AppTypography.titleMd.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryContainer.withValues(alpha: 0.15),
                      borderRadius: AppRadius.radiusSm,
                      border: Border.all(color: AppColors.secondaryContainer.withValues(alpha: 0.4), width: 0.8),
                    ),
                    child: Text(
                      'DPI',
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w900,
                        fontSize: 8.5,
                      ),
                    ),
                  ),
                ],
              ),
              if (showSubtitle) ...[
                const SizedBox(height: 1),
                Text(
                  clusterName != null && clusterName!.isNotEmpty
                      ? clusterName!
                      : 'National Trade Cooperative Infrastructure',
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurfaceVariant,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// Official Tricolor Top Stripe (Saffron, White, Green) representing Sovereign Civic DPI.
class TricolorStripe extends StatelessWidget {
  final double height;
  const TricolorStripe({super.key, this.height = 3.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(child: Container(color: AppColors.secondaryContainer)), // Saffron
          Expanded(child: Container(color: Colors.white)), // White
          Expanded(child: Container(color: AppColors.onTertiaryContainer)), // Green
        ],
      ),
    );
  }
}
