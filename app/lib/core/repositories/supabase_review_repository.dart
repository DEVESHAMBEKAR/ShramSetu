import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'i_review_repository.dart';
import '../models/review_models.dart';
import '../config/dependency_injection.dart';

class SupabaseReviewRepository implements IReviewRepository {
  final SupabaseClient _client;

  SupabaseReviewRepository(this._client);

  @override
  Future<ReviewModel> submitReview({
    required String bookingId,
    required int rating,
    String? comment,
  }) async {
    final response = await _client.rpc('submit_booking_review', params: {
      'p_booking_id': bookingId,
      'p_rating': rating,
      'p_comment': comment,
    });

    final Map<String, dynamic> data;
    if (response is Map<String, dynamic>) {
      data = response;
    } else if (response is Map) {
      data = Map<String, dynamic>.from(response);
    } else if (response is String) {
      data = jsonDecode(response) as Map<String, dynamic>;
    } else {
      data = {};
    }

    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to submit review');
    }

    final reviewId = data['review_id'] as String;

    // Fetch the created review with joined user profile for consistent formatting
    final row = await _client
        .from('reviews')
        .select('''
          id, booking_id, customer_id, worker_id, rating, comment, created_at, updated_at,
          users!customer_id(full_name, avatar_url)
        ''')
        .eq('id', reviewId)
        .single();

    final model = ReviewModel.fromJson(row);

    try {
      DI.notificationRepo.sendPushNotification(
        recipientUserId: model.workerId,
        type: 'review_received',
        title: 'New Rating & Review Received',
        body: 'A customer gave you a $rating-star rating for their booking.',
        data: {
          'bookingId': bookingId,
          'reviewId': reviewId,
        },
      );
    } catch (_) {}

    return model;
  }

  @override
  Future<ReviewModel?> getReviewForBooking(String bookingId) async {
    final row = await _client
        .from('reviews')
        .select('''
          id, booking_id, customer_id, worker_id, rating, comment, created_at, updated_at,
          users!customer_id(full_name, avatar_url)
        ''')
        .eq('booking_id', bookingId)
        .maybeSingle();

    if (row == null) return null;
    return ReviewModel.fromJson(row);
  }

  @override
  Future<List<ReviewModel>> getWorkerReviews(String workerId, {int limit = 20, int offset = 0}) async {
    final response = await _client
        .from('reviews')
        .select('''
          id, booking_id, customer_id, worker_id, rating, comment, created_at, updated_at,
          users!customer_id(full_name, avatar_url)
        ''')
        .eq('worker_id', workerId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((r) => ReviewModel.fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<WorkerRatingSummary> getWorkerRatingSummary(String workerId) async {
    try {
      final response = await _client.rpc('get_worker_rating_summary', params: {
        'p_worker_id': workerId,
      });

      final Map<String, dynamic> data;
      if (response is Map<String, dynamic>) {
        data = response;
      } else if (response is Map) {
        data = Map<String, dynamic>.from(response);
      } else if (response is String) {
        data = jsonDecode(response) as Map<String, dynamic>;
      } else {
        data = {};
      }

      return WorkerRatingSummary.fromJson(data);
    } catch (_) {
      // Fallback: aggregate from reviews table directly
      final reviews = await _client
          .from('reviews')
          .select('rating')
          .eq('worker_id', workerId);

      if ((reviews as List).isEmpty) {
        return WorkerRatingSummary(workerId: workerId, averageRating: 0.0, reviewCount: 0);
      }

      final count = reviews.length;
      final sum = reviews.fold<int>(0, (prev, r) => prev + ((r['rating'] as num?)?.toInt() ?? 0));
      final avg = count > 0 ? (sum / count) : 0.0;

      return WorkerRatingSummary(
        workerId: workerId,
        averageRating: double.parse(avg.toStringAsFixed(2)),
        reviewCount: count,
      );
    }
  }

  @override
  Future<List<ReviewModel>> getAllReviews({int limit = 50, int offset = 0}) async {
    final response = await _client
        .from('reviews')
        .select('''
          id, booking_id, customer_id, worker_id, rating, comment, created_at, updated_at,
          users!customer_id(full_name, avatar_url)
        ''')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List).map((r) => ReviewModel.fromJson(r as Map<String, dynamic>)).toList();
  }

  @override
  Future<bool> deleteReview(String reviewId) async {
    await _client.from('reviews').delete().eq('id', reviewId);
    return true;
  }
}