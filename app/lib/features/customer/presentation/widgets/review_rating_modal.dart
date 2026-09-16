import 'package:flutter/material.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/models/review_models.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

class ReviewRatingModal extends StatefulWidget {
  final String bookingId;
  final String workerName;
  final String serviceName;
  final ReviewModel? existingReview;
  final void Function(ReviewModel review)? onReviewSubmitted;

  const ReviewRatingModal({
    super.key,
    required this.bookingId,
    required this.workerName,
    required this.serviceName,
    this.existingReview,
    this.onReviewSubmitted,
  });

  static Future<ReviewModel?> show(
    BuildContext context, {
    required String bookingId,
    required String workerName,
    required String serviceName,
    ReviewModel? existingReview,
  }) {
    return showModalBottomSheet<ReviewModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: ReviewRatingModal(
          bookingId: bookingId,
          workerName: workerName,
          serviceName: serviceName,
          existingReview: existingReview,
        ),
      ),
    );
  }

  @override
  State<ReviewRatingModal> createState() => _ReviewRatingModalState();
}

class _ReviewRatingModalState extends State<ReviewRatingModal> {
  late int _selectedRating;
  late final TextEditingController _commentController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedRating = widget.existingReview?.rating ?? 5;
    _commentController = TextEditingController(text: widget.existingReview?.comment ?? '');
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor Service';
      case 2:
        return 'Fair / Below Expectation';
      case 3:
        return 'Good / Satisfactory';
      case 4:
        return 'Very Good / Recommended';
      case 5:
      default:
        return 'Excellent / Highly Recommended';
    }
  }

  Future<void> _handleSubmit() async {
    if (_selectedRating < 1 || _selectedRating > 5) return;

    setState(() => _isSubmitting = true);
    try {
      final review = await DI.reviewRepo.submitReview(
        bookingId: widget.bookingId,
        rating: _selectedRating,
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      );

      if (mounted) {
        widget.onReviewSubmitted?.call(review);
        Navigator.of(context).pop(review);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingReview != null
                ? 'Review updated successfully!'
                : 'Thank you! Your feedback supports our cooperative artisans.'),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: '),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.marginMobile, vertical: AppSpacing.spacingMd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.spacingMd),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.existingReview != null ? 'Edit Your Review' : 'Rate Your Experience',
                      style: AppTypography.titleLg.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ' • ',
                      style: AppTypography.bodySm.copyWith(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.outline),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(height: 24),

          // Star Rating Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNumber = index + 1;
              final isFilled = starNumber <= _selectedRating;
              return GestureDetector(
                onTap: _isSubmitting ? null : () => setState(() => _selectedRating = starNumber),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(
                    isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 40,
                    color: isFilled ? AppColors.starRating : AppColors.outlineVariant,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),

          // Dynamic Rating Label Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: AppRadius.radiusFull,
            ),
            child: Text(
              _getRatingLabel(_selectedRating),
              style: AppTypography.labelSm.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.spacingMd),

          // Feedback Input Field
          TextField(
            controller: _commentController,
            enabled: !_isSubmitting,
            maxLines: 3,
            maxLength: 300,
            decoration: InputDecoration(
              hintText: 'Share your feedback on work quality, punctuality, and professionalism...',
              hintStyle: AppTypography.bodySm.copyWith(color: AppColors.outline),
              filled: true,
              fillColor: AppColors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: AppRadius.radiusLg,
                borderSide: BorderSide(color: AppColors.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.radiusLg,
                borderSide: BorderSide(color: AppColors.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.radiusLg,
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(AppSpacing.spacingSm),
            ),
          ),
          const SizedBox(height: AppSpacing.spacingSm),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
                elevation: 0,
              ),
              onPressed: _isSubmitting ? null : _handleSubmit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      widget.existingReview != null ? 'Update Review' : 'Submit Review',
                      style: AppTypography.labelLg.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.spacingSm),
        ],
      ),
    );
  }
}