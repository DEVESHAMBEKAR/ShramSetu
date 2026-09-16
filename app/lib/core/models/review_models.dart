/// Review and Rating models for ShramSetu Phase 20 — Reviews, Ratings & Worker Reputation
library;

class ReviewModel {
  final String id;
  final String bookingId;
  final String customerId;
  final String customerName;
  final String? customerAvatarUrl;
  final String workerId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ReviewModel({
    required this.id,
    required this.bookingId,
    required this.customerId,
    required this.customerName,
    this.customerAvatarUrl,
    required this.workerId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.updatedAt,
  });

  /// Factory deserializer from Supabase query row with optional joined user profile.
  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>? ?? json['customer'] as Map<String, dynamic>?;
    final rawName = user?['full_name'] as String? ?? json['customer_name'] as String?;
    final masked = maskCustomerName(rawName);

    return ReviewModel(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      customerId: json['customer_id'] as String,
      customerName: masked,
      customerAvatarUrl: user?['avatar_url'] as String? ?? json['customer_avatar_url'] as String?,
      workerId: json['worker_id'] as String,
      rating: (json['rating'] as num).toInt(),
      comment: json['comment'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'booking_id': bookingId,
    'customer_id': customerId,
    'customer_name': customerName,
    'customer_avatar_url': customerAvatarUrl,
    'worker_id': workerId,
    'rating': rating,
    'comment': comment,
    'created_at': createdAt.toIso8601String(),
    if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
  };

  /// Privacy masking helper: e.g. "Priya Deshmukh" -> "Priya D.", "Rahul" -> "Rahul"
  static String maskCustomerName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return 'Customer';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first;
    final firstName = parts.first;
    final lastInitial = parts.last[0].toUpperCase();
    return '$firstName $lastInitial.';
  }

  /// Format date into user-friendly relative or calendar string
  String get relativeDateString {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes <= 1) return 'Just now';
        return '${difference.inMinutes} mins ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    } else {
      return '${createdAt.day} ${_monthName(createdAt.month)} ${createdAt.year}';
    }
  }

  static String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (month >= 1 && month <= 12) return months[month - 1];
    return '';
  }
}

/// Worker aggregated rating summary
class WorkerRatingSummary {
  final String workerId;
  final double averageRating;
  final int reviewCount;
  final int fiveStarCount;
  final int fourStarCount;
  final int threeStarCount;
  final int twoStarCount;
  final int oneStarCount;

  const WorkerRatingSummary({
    required this.workerId,
    required this.averageRating,
    required this.reviewCount,
    this.fiveStarCount = 0,
    this.fourStarCount = 0,
    this.threeStarCount = 0,
    this.twoStarCount = 0,
    this.oneStarCount = 0,
  });

  factory WorkerRatingSummary.fromJson(Map<String, dynamic> json) {
    return WorkerRatingSummary(
      workerId: json['worker_id'] as String? ?? '',
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      fiveStarCount: (json['five_star_count'] as num?)?.toInt() ?? 0,
      fourStarCount: (json['four_star_count'] as num?)?.toInt() ?? 0,
      threeStarCount: (json['three_star_count'] as num?)?.toInt() ?? 0,
      twoStarCount: (json['two_star_count'] as num?)?.toInt() ?? 0,
      oneStarCount: (json['one_star_count'] as num?)?.toInt() ?? 0,
    );
  }

  static const WorkerRatingSummary empty = WorkerRatingSummary(
    workerId: '',
    averageRating: 0.0,
    reviewCount: 0,
  );

  bool get hasReviews => reviewCount > 0;

  String get formattedRating => hasReviews ? averageRating.toStringAsFixed(1) : 'No reviews yet';
}