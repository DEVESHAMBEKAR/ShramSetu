import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/review_models.dart';
import 'package:app/core/repositories/mock_review_repository.dart';

void main() {
  group('ReviewModel Serialization & Deserialization', () {
    test('ReviewModel fromJson correctly parses all fields with joined user', () {
      final json = {
        'id': 'rev-001',
        'booking_id': 'book-100',
        'customer_id': 'cust-200',
        'worker_id': 'work-300',
        'rating': 5,
        'comment': 'Exceptional plumbing work, polite and punctual.',
        'created_at': '2026-09-15T10:30:00Z',
        'updated_at': '2026-09-15T11:00:00Z',
        'users': {
          'full_name': 'Priya Deshmukh',
          'avatar_url': 'https://example.com/avatar.jpg',
        },
      };

      final review = ReviewModel.fromJson(json);

      expect(review.id, 'rev-001');
      expect(review.bookingId, 'book-100');
      expect(review.customerId, 'cust-200');
      expect(review.customerName, 'Priya D.'); // Privacy masked
      expect(review.customerAvatarUrl, 'https://example.com/avatar.jpg');
      expect(review.workerId, 'work-300');
      expect(review.rating, 5);
      expect(review.comment, 'Exceptional plumbing work, polite and punctual.');
      expect(review.createdAt, DateTime.parse('2026-09-15T10:30:00Z'));
      expect(review.updatedAt, DateTime.parse('2026-09-15T11:00:00Z'));
    });

    test('ReviewModel toJson correctly serializes data', () {
      final review = ReviewModel(
        id: 'rev-002',
        bookingId: 'book-101',
        customerId: 'cust-201',
        customerName: 'Sunil K.',
        workerId: 'work-301',
        rating: 4,
        comment: 'Good service',
        createdAt: DateTime.parse('2026-09-15T12:00:00Z'),
      );

      final json = review.toJson();
      expect(json['id'], 'rev-002');
      expect(json['booking_id'], 'book-101');
      expect(json['rating'], 4);
      expect(json['comment'], 'Good service');
      expect(json['created_at'], '2026-09-15T12:00:00.000Z');
      expect(json.containsKey('updated_at'), false);
    });
  });

  group('Customer Privacy Name Masking', () {
    test('masks two-part names to First Name and Last Initial', () {
      expect(ReviewModel.maskCustomerName('Priya Deshmukh'), 'Priya D.');
      expect(ReviewModel.maskCustomerName('Sunil Kulkarni'), 'Sunil K.');
      expect(ReviewModel.maskCustomerName('Rahul Ashok Patil'), 'Rahul P.');
    });

    test('handles single names and edge cases gracefully', () {
      expect(ReviewModel.maskCustomerName('Amit'), 'Amit');
      expect(ReviewModel.maskCustomerName(''), 'Customer');
      expect(ReviewModel.maskCustomerName(null), 'Customer');
      expect(ReviewModel.maskCustomerName('   '), 'Customer');
    });
  });

  group('Relative Date Formatting', () {
    test('formats relative date cleanly', () {
      final now = DateTime.now();
      final justNow = ReviewModel(
        id: '1', bookingId: '1', customerId: '1', customerName: 'A',
        workerId: '1', rating: 5, createdAt: now.subtract(const Duration(minutes: 1)),
      );
      expect(justNow.relativeDateString, 'Just now');

      final twoHoursAgo = ReviewModel(
        id: '2', bookingId: '2', customerId: '1', customerName: 'A',
        workerId: '1', rating: 5, createdAt: now.subtract(const Duration(hours: 2)),
      );
      expect(twoHoursAgo.relativeDateString, '2 hours ago');

      final yesterday = ReviewModel(
        id: '3', bookingId: '3', customerId: '1', customerName: 'A',
        workerId: '1', rating: 5, createdAt: now.subtract(const Duration(days: 1)),
      );
      expect(yesterday.relativeDateString, 'Yesterday');

      final threeDaysAgo = ReviewModel(
        id: '4', bookingId: '4', customerId: '1', customerName: 'A',
        workerId: '1', rating: 5, createdAt: now.subtract(const Duration(days: 3)),
      );
      expect(threeDaysAgo.relativeDateString, '3 days ago');
    });
  });

  group('WorkerRatingSummary Aggregation Calculations', () {
    test('empty summary returns 0 reviews and 0.0 rating', () {
      const summary = WorkerRatingSummary.empty;
      expect(summary.reviewCount, 0);
      expect(summary.averageRating, 0.0);
      expect(summary.hasReviews, false);
      expect(summary.formattedRating, 'No reviews yet');
    });

    test('calculates exact fractional average rating for 5, 4, 5', () {
      // 5 + 4 + 5 = 14 / 3 = 4.6666... -> 4.67
      final avg = double.parse(((5 + 4 + 5) / 3).toStringAsFixed(2));
      final summary = WorkerRatingSummary(
        workerId: 'w-1',
        averageRating: avg,
        reviewCount: 3,
        fiveStarCount: 2,
        fourStarCount: 1,
      );

      expect(summary.averageRating, 4.67);
      expect(summary.reviewCount, 3);
      expect(summary.hasReviews, true);
      expect(summary.formattedRating, '4.7');
    });

    test('calculates exact rating for uniform ratings 1, 1, 1', () {
      final summary = WorkerRatingSummary(
        workerId: 'w-2',
        averageRating: 1.0,
        reviewCount: 3,
        oneStarCount: 3,
      );

      expect(summary.averageRating, 1.0);
      expect(summary.reviewCount, 3);
      expect(summary.formattedRating, '1.0');
    });

    test('deserializes from SQL json response', () {
      final json = {
        'worker_id': 'work-99',
        'average_rating': 4.75,
        'review_count': 12,
        'five_star_count': 9,
        'four_star_count': 3,
        'three_star_count': 0,
        'two_star_count': 0,
        'one_star_count': 0,
      };

      final summary = WorkerRatingSummary.fromJson(json);
      expect(summary.workerId, 'work-99');
      expect(summary.averageRating, 4.75);
      expect(summary.reviewCount, 12);
      expect(summary.fiveStarCount, 9);
      expect(summary.fourStarCount, 3);
    });
  });

  group('MockReviewRepository Operations', () {
    late MockReviewRepository repo;

    setUp(() {
      repo = MockReviewRepository();
    });

    test('submitReview creates valid review with 1-5 rating', () async {
      final review = await repo.submitReview(
        bookingId: 'booking-alpha',
        rating: 5,
        comment: 'Great work fixing the tap!',
      );

      expect(review.bookingId, 'booking-alpha');
      expect(review.rating, 5);
      expect(review.comment, 'Great work fixing the tap!');
    });

    test('submitReview rejects invalid ratings (< 1 or > 5)', () async {
      expect(
        () => repo.submitReview(bookingId: 'b-bad-1', rating: 0),
        throwsArgumentError,
      );
      expect(
        () => repo.submitReview(bookingId: 'b-bad-2', rating: 6),
        throwsArgumentError,
      );
      expect(
        () => repo.submitReview(bookingId: 'b-bad-3', rating: -1),
        throwsArgumentError,
      );
    });

    test('one-review-per-booking: re-submitting updates existing review without duplicating', () async {
      // First submission
      final first = await repo.submitReview(
        bookingId: 'booking-unique',
        rating: 4,
        comment: 'Initial feedback',
      );

      // Re-submission for same booking
      final second = await repo.submitReview(
        bookingId: 'booking-unique',
        rating: 5,
        comment: 'Updated feedback after further inspection',
      );

      // IDs should match (same review record updated)
      expect(second.id, first.id);
      expect(second.rating, 5);
      expect(second.comment, 'Updated feedback after further inspection');

      // Total reviews for worker must be 1, not 2
      final reviews = await repo.getWorkerReviews(first.workerId);
      expect(reviews.length, 1);
    });

    test('getReviewForBooking returns correct review or null', () async {
      await repo.submitReview(bookingId: 'b-123', rating: 5);

      final found = await repo.getReviewForBooking('b-123');
      expect(found, isNotNull);
      expect(found?.rating, 5);

      final notFound = await repo.getReviewForBooking('b-nonexistent');
      expect(notFound, isNull);
    });

    test('getWorkerRatingSummary aggregates worker reviews accurately', () async {
      // Seed reviews for worker-X
      repo.seedReview(ReviewModel(
        id: 'r1', bookingId: 'b1', customerId: 'c1', customerName: 'A',
        workerId: 'worker-X', rating: 5, createdAt: DateTime.now(),
      ));
      repo.seedReview(ReviewModel(
        id: 'r2', bookingId: 'b2', customerId: 'c2', customerName: 'B',
        workerId: 'worker-X', rating: 4, createdAt: DateTime.now(),
      ));
      repo.seedReview(ReviewModel(
        id: 'r3', bookingId: 'b3', customerId: 'c3', customerName: 'C',
        workerId: 'worker-X', rating: 5, createdAt: DateTime.now(),
      ));

      final summary = await repo.getWorkerRatingSummary('worker-X');
      expect(summary.reviewCount, 3);
      expect(summary.averageRating, 4.67);
      expect(summary.fiveStarCount, 2);
      expect(summary.fourStarCount, 1);
    });

    test('deleteReview removes review and updates count', () async {
      final review = await repo.submitReview(bookingId: 'b-del', rating: 3);
      expect(await repo.getReviewForBooking('b-del'), isNotNull);

      final deleted = await repo.deleteReview(review.id);
      expect(deleted, true);
      expect(await repo.getReviewForBooking('b-del'), isNull);
    });
  });
}