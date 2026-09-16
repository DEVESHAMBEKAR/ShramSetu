import '../models/review_models.dart';

abstract class IReviewRepository {
  /// Submit or update a review for a completed booking.
  Future<ReviewModel> submitReview({
    required String bookingId,
    required int rating,
    String? comment,
  });

  /// Fetch the review submitted for a specific booking (null if none).
  Future<ReviewModel?> getReviewForBooking(String bookingId);

  /// Fetch list of reviews for a worker (privacy-safe customer info).
  Future<List<ReviewModel>> getWorkerReviews(String workerId, {int limit = 20, int offset = 0});

  /// Fetch aggregated rating summary for a worker.
  Future<WorkerRatingSummary> getWorkerRatingSummary(String workerId);

  /// Admin: Fetch all reviews across the platform.
  Future<List<ReviewModel>> getAllReviews({int limit = 50, int offset = 0});

  /// Admin: Delete a review for moderation.
  Future<bool> deleteReview(String reviewId);
}