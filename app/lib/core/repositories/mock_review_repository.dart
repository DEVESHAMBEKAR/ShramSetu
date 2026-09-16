import 'i_review_repository.dart';
import '../models/review_models.dart';
import '../config/dependency_injection.dart';
import '../services/shared_booking_store.dart';
import '../../features/customer/data/repositories/mock_customer_repository.dart';

/// In-memory mock review repository for testing and offline development
class MockReviewRepository implements IReviewRepository {
  final Map<String, ReviewModel> _reviewsByBooking = {};
  bool simulateFailure = false;

  @override
  Future<ReviewModel> submitReview({
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (simulateFailure) {
      throw Exception('Simulated review submission error');
    }
    if (rating < 1 || rating > 5) {
      throw ArgumentError('Rating must be between 1 and 5');
    }

    final existing = _reviewsByBooking[bookingId];
    String workerId = existing?.workerId ?? 'mock-worker-id';
    try {
      final booking = DI.customerRepo is MockCustomerRepository 
          ? SharedBookingStore.instance.getBookingDetails(bookingId) 
          : null;
      if (booking != null && booking['worker_id'] != null) {
        workerId = booking['worker_id'] as String;
      }
    } catch (_) {}

    final review = ReviewModel(
      id: existing?.id ?? 'rev_mock_${DateTime.now().millisecondsSinceEpoch}',
      bookingId: bookingId,
      customerId: existing?.customerId ?? 'mock-customer-id',
      customerName: existing?.customerName ?? 'Priya D.',
      customerAvatarUrl: existing?.customerAvatarUrl,
      workerId: workerId,
      rating: rating,
      comment: comment?.trim(),
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: existing != null ? DateTime.now() : null,
    );

    _reviewsByBooking[bookingId] = review;

    try {
      DI.notificationRepo.sendPushNotification(
        recipientUserId: review.workerId,
        type: 'review_received',
        title: 'New Rating & Review Received',
        body: 'A customer gave you a $rating-star rating for their booking.',
        data: {'bookingId': bookingId, 'reviewId': review.id},
      );
    } catch (_) {}

    return review;
  }

  @override
  Future<ReviewModel?> getReviewForBooking(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    return _reviewsByBooking[bookingId];
  }

  @override
  Future<List<ReviewModel>> getWorkerReviews(String workerId, {int limit = 20, int offset = 0}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final list = _reviewsByBooking.values
        .where((r) => r.workerId == workerId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (offset >= list.length) return [];
    return list.skip(offset).take(limit).toList();
  }

  @override
  Future<WorkerRatingSummary> getWorkerRatingSummary(String workerId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final reviews = _reviewsByBooking.values.where((r) => r.workerId == workerId).toList();
    if (reviews.isEmpty) {
      return WorkerRatingSummary(workerId: workerId, averageRating: 0.0, reviewCount: 0);
    }

    final count = reviews.length;
    final sum = reviews.fold<int>(0, (prev, r) => prev + r.rating);
    final avg = double.parse((sum / count).toStringAsFixed(2));

    return WorkerRatingSummary(
      workerId: workerId,
      averageRating: avg,
      reviewCount: count,
      fiveStarCount: reviews.where((r) => r.rating == 5).length,
      fourStarCount: reviews.where((r) => r.rating == 4).length,
      threeStarCount: reviews.where((r) => r.rating == 3).length,
      twoStarCount: reviews.where((r) => r.rating == 2).length,
      oneStarCount: reviews.where((r) => r.rating == 1).length,
    );
  }

  @override
  Future<List<ReviewModel>> getAllReviews({int limit = 50, int offset = 0}) async {
    await Future.delayed(const Duration(milliseconds: 50));
    final list = _reviewsByBooking.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.skip(offset).take(limit).toList();
  }

  @override
  Future<bool> deleteReview(String reviewId) async {
    await Future.delayed(const Duration(milliseconds: 50));
    _reviewsByBooking.removeWhere((_, r) => r.id == reviewId);
    return true;
  }

  /// Helper for testing to inject pre-existing reviews
  void seedReview(ReviewModel review) {
    _reviewsByBooking[review.bookingId] = review;
  }

  void clear() {
    _reviewsByBooking.clear();
  }
}