import '../../features/customer/data/models/customer_models.dart';

/// Central weights configuration for FairMatch scoring.
/// All weights must be non-negative and sum strictly to 1.0 within tolerance.
class FairMatchWeights {
  final double skillWeight;
  final double distanceWeight;
  final double availabilityWeight;
  final double ratingWeight;
  final double experienceWeight;
  final double fairnessWeight;

  const FairMatchWeights({
    this.skillWeight = 0.35,
    this.distanceWeight = 0.20,
    this.availabilityWeight = 0.15,
    this.ratingWeight = 0.10,
    this.experienceWeight = 0.10,
    this.fairnessWeight = 0.10,
  });

  /// Sum of all factor weights.
  double get sum =>
      skillWeight +
      distanceWeight +
      availabilityWeight +
      ratingWeight +
      experienceWeight +
      fairnessWeight;

  /// Validates that weights sum to 1.0 within floating point tolerance.
  bool get isValid {
    if (skillWeight < 0 ||
        distanceWeight < 0 ||
        availabilityWeight < 0 ||
        ratingWeight < 0 ||
        experienceWeight < 0 ||
        fairnessWeight < 0) {
      return false;
    }
    return (sum - 1.0).abs() < 0.001;
  }

  /// Initial experimental baseline weights for FairMatch v1.
  factory FairMatchWeights.defaultWeights() => const FairMatchWeights();

  /// Baseline 1: Nearest Worker heuristic.
  factory FairMatchWeights.nearest() => const FairMatchWeights(
        skillWeight: 0.0,
        distanceWeight: 1.0,
        availabilityWeight: 0.0,
        ratingWeight: 0.0,
        experienceWeight: 0.0,
        fairnessWeight: 0.0,
      );

  /// Baseline 2: Highest Rated Worker heuristic.
  factory FairMatchWeights.highestRated() => const FairMatchWeights(
        skillWeight: 0.0,
        distanceWeight: 0.0,
        availabilityWeight: 0.0,
        ratingWeight: 1.0,
        experienceWeight: 0.0,
        fairnessWeight: 0.0,
      );

  /// Baseline 3: Combined Rating + Proximity heuristic.
  factory FairMatchWeights.ratingDistance() => const FairMatchWeights(
        skillWeight: 0.0,
        distanceWeight: 0.50,
        availabilityWeight: 0.0,
        ratingWeight: 0.50,
        experienceWeight: 0.0,
        fairnessWeight: 0.0,
      );

  factory FairMatchWeights.fromJson(Map<String, dynamic> json) {
    return FairMatchWeights(
      skillWeight: (json['skill'] as num?)?.toDouble() ?? 0.35,
      distanceWeight: (json['distance'] as num?)?.toDouble() ?? 0.20,
      availabilityWeight: (json['availability'] as num?)?.toDouble() ?? 0.15,
      ratingWeight: (json['rating'] as num?)?.toDouble() ?? 0.10,
      experienceWeight: (json['experience'] as num?)?.toDouble() ?? 0.10,
      fairnessWeight: (json['fairness'] as num?)?.toDouble() ?? 0.10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'skill': skillWeight,
      'distance': distanceWeight,
      'availability': availabilityWeight,
      'rating': ratingWeight,
      'experience': experienceWeight,
      'fairness': fairnessWeight,
    };
  }
}

/// Normalized feature vector for a worker candidate.
/// Every individual score must strictly satisfy 0.0 <= score <= 1.0.
class FairMatchFeatures {
  final double skillScore;
  final double distanceScore;
  final double availabilityScore;
  final double ratingScore;
  final double experienceScore;
  final double fairnessScore;

  const FairMatchFeatures({
    required this.skillScore,
    required this.distanceScore,
    required this.availabilityScore,
    required this.ratingScore,
    required this.experienceScore,
    required this.fairnessScore,
  });

  bool get areAllNormalized =>
      skillScore >= 0.0 && skillScore <= 1.0 &&
      distanceScore >= 0.0 && distanceScore <= 1.0 &&
      availabilityScore >= 0.0 && availabilityScore <= 1.0 &&
      ratingScore >= 0.0 && ratingScore <= 1.0 &&
      experienceScore >= 0.0 && experienceScore <= 1.0 &&
      fairnessScore >= 0.0 && fairnessScore <= 1.0;

  factory FairMatchFeatures.fromJson(Map<String, dynamic> json) {
    return FairMatchFeatures(
      skillScore: (json['skill_score'] as num?)?.toDouble() ?? 0.0,
      distanceScore: (json['distance_score'] as num?)?.toDouble() ?? 0.0,
      availabilityScore: (json['availability_score'] as num?)?.toDouble() ?? 0.0,
      ratingScore: (json['rating_score'] as num?)?.toDouble() ?? 0.0,
      experienceScore: (json['experience_score'] as num?)?.toDouble() ?? 0.0,
      fairnessScore: (json['fairness_score'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'skill_score': skillScore,
      'distance_score': distanceScore,
      'availability_score': availabilityScore,
      'rating_score': ratingScore,
      'experience_score': experienceScore,
      'fairness_score': fairnessScore,
    };
  }
}

/// Raw candidate representation used for local feature calculation & simulation.
class FairMatchCandidate {
  final Worker worker;
  final bool hasVerifiedSkill;
  final bool isAvailable;
  final double? distanceKm;
  final bool hasCoordinates;
  final double rating;
  final int reviewCount;
  final int experienceYears;
  final int activeBookings;
  final int recent7dBookings;

  const FairMatchCandidate({
    required this.worker,
    this.hasVerifiedSkill = true,
    this.isAvailable = true,
    this.distanceKm,
    this.hasCoordinates = true,
    this.rating = 0.0,
    this.reviewCount = 0,
    this.experienceYears = 1,
    this.activeBookings = 0,
    this.recent7dBookings = 0,
  });
}

/// Final matched & ranked result object returned to callers.
class FairMatchResult {
  final Worker worker;
  final double totalScore;
  final int rank;
  final FairMatchFeatures features;
  final List<String> explanationTags;
  final String algorithmVersion;

  const FairMatchResult({
    required this.worker,
    required this.totalScore,
    required this.rank,
    required this.features,
    required this.explanationTags,
    this.algorithmVersion = FairMatchConfig.version,
  });

  factory FairMatchResult.fromJson(Map<String, dynamic> json, int rank) {
    final tags = (json['explanation_tags'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        ['Verified Skill', 'Available Now'];

    final worker = Worker(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Artisan',
      categoryId: json['category_id']?.toString() ?? 'c2',
      rate: (json['rate'] as num?)?.toInt() ?? 350,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['review_count'] as num?)?.toInt() ?? 0,
      jobsCompleted: (json['completed_jobs'] as num?)?.toInt() ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 2.0,
      experience: '${json['experience_years'] ?? 1} yrs exp',
      availability: 'Available Now',
      specializations: tags,
      locationTag: json['location_tag']?.toString() ?? 'Pune Area',
      imageUrl: json['avatar_url']?.toString() ?? '',
      bio: json['bio']?.toString(),
      isUnionGold: json['is_union_gold'] == true,
      isCoopMaster: json['is_coop_master'] == true,
      customTag: rank == 1 ? 'FairMatch Recommended' : null,
    );

    return FairMatchResult(
      worker: worker,
      totalScore: (json['total_score'] as num?)?.toDouble() ?? 0.0,
      rank: rank,
      features: FairMatchFeatures.fromJson(json),
      explanationTags: tags,
      algorithmVersion: json['algorithm_version']?.toString() ?? FairMatchConfig.version,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'worker_id': worker.id,
      'name': worker.name,
      'total_score': totalScore,
      'rank': rank,
      'features': features.toJson(),
      'explanation_tags': explanationTags,
      'algorithm_version': algorithmVersion,
    };
  }
}

/// Global FairMatch configuration constants.
class FairMatchConfig {
  static const String version = 'fairmatch_v1';
  static const double maxDistanceKm = 15.0;
  static const double maxExperienceYears = 10.0;
  static const double maxWorkloadIndex = 10.0;
  static const double coldStartRatingScore = 0.5;
  static const double missingCoordinatesDistanceScore = 0.5;
  static const int defaultTopN = 10;
}