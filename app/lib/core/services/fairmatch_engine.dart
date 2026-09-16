import 'dart:math';
import '../models/fairmatch_models.dart';
import '../../features/customer/data/models/customer_models.dart';

/// Reusable, deterministic FairMatch scoring & ranking engine.
/// Provides feature normalization, weighted scoring, deterministic tie-breaking,
/// and research baseline implementations.
class FairMatchEngine {
  static final FairMatchEngine instance = FairMatchEngine._internal();
  factory FairMatchEngine() => instance;
  FairMatchEngine._internal();

  /// Computes strictly normalized feature vector for a candidate (each score in [0.0, 1.0]).
  FairMatchFeatures computeFeatures(
    FairMatchCandidate candidate, {
    double maxDistanceKm = FairMatchConfig.maxDistanceKm,
    double maxExperienceYears = FairMatchConfig.maxExperienceYears,
    double maxWorkloadIndex = FairMatchConfig.maxWorkloadIndex,
  }) {
    // 1. Skill Compatibility Score
    final double skillScore = candidate.hasVerifiedSkill ? 1.0 : 0.0;

    // 2. Distance Score: Proximity normalization
    final double distanceScore;
    if (candidate.hasCoordinates && candidate.distanceKm != null) {
      final d = candidate.distanceKm!;
      distanceScore = max(0.0, min(1.0, 1.0 - (d / maxDistanceKm)));
    } else {
      // Documented neutral fallback when coordinates are missing
      distanceScore = FairMatchConfig.missingCoordinatesDistanceScore;
    }

    // 3. Availability Score
    final double availabilityScore = candidate.isAvailable ? 1.0 : 0.0;

    // 4. Rating Score with cold-start correction
    final double ratingScore;
    if (candidate.reviewCount > 0) {
      // Linear mapping: [1.0, 5.0] -> [0.0, 1.0]
      ratingScore = max(0.0, min(1.0, (candidate.rating - 1.0) / 4.0));
    } else {
      // Cold-start rule: neutral baseline 0.5 (equivalent to 3.0 stars)
      ratingScore = FairMatchConfig.coldStartRatingScore;
    }

    // 5. Experience Score
    final double experienceScore =
        max(0.0, min(1.0, candidate.experienceYears / maxExperienceYears));

    // 6. Fairness / Workload Score (Inverse recent workload)
    final double rawWorkload =
        (candidate.activeBookings * 2.0) + candidate.recent7dBookings.toDouble();
    final double fairnessScore =
        max(0.0, min(1.0, 1.0 - (rawWorkload / maxWorkloadIndex)));

    return FairMatchFeatures(
      skillScore: _roundTo4(skillScore),
      distanceScore: _roundTo4(distanceScore),
      availabilityScore: _roundTo4(availabilityScore),
      ratingScore: _roundTo4(ratingScore),
      experienceScore: _roundTo4(experienceScore),
      fairnessScore: _roundTo4(fairnessScore),
    );
  }

  /// Calculates total weighted FairMatch score strictly in [0.0, 1.0].
  double computeTotalScore(FairMatchFeatures features, FairMatchWeights weights) {
    assert(weights.isValid, 'FairMatch weights must sum to 1.0');

    final score = (weights.skillWeight * features.skillScore) +
        (weights.distanceWeight * features.distanceScore) +
        (weights.availabilityWeight * features.availabilityScore) +
        (weights.ratingWeight * features.ratingScore) +
        (weights.experienceWeight * features.experienceScore) +
        (weights.fairnessWeight * features.fairnessScore);

    return _roundTo4(max(0.0, min(1.0, score)));
  }

  /// Generates customer-friendly, explainable reason tags (no sensitive values exposed).
  List<String> generateExplanationTags(
    FairMatchFeatures features,
    FairMatchCandidate candidate,
  ) {
    final List<String> tags = [];

    if (features.skillScore >= 0.9) tags.add('Verified Skill');
    if (features.availabilityScore >= 0.9) tags.add('Available Now');
    if (features.distanceScore >= 0.6) tags.add('Nearby');
    if (candidate.rating >= 4.5 && candidate.reviewCount >= 1) {
      tags.add('Top Rated');
    } else if (features.ratingScore >= 0.6) {
      tags.add('Good Rating');
    }
    if (candidate.experienceYears >= 8) {
      tags.add('Veteran Artisan');
    } else if (features.experienceScore >= 0.4) {
      tags.add('Experienced');
    }
    if (features.fairnessScore >= 0.7) {
      tags.add('Cooperative Partner');
    }

    if (tags.isEmpty) {
      tags.addAll(['Verified Skill', 'Available Now']);
    }

    return tags;
  }

  /// Evaluates strict pre-scoring eligibility filter.
  bool isEligible(FairMatchCandidate candidate) {
    if (!candidate.hasVerifiedSkill) return false;
    if (!candidate.isAvailable) return false;
    return true;
  }

  /// Primary multi-factor FairMatch ranking with deterministic tie-breaking.
  List<FairMatchResult> rankCandidates(
    List<FairMatchCandidate> candidates, {
    FairMatchWeights? weights,
    int limit = FairMatchConfig.defaultTopN,
    String algorithm = FairMatchConfig.version,
  }) {
    final effectiveWeights = weights ?? FairMatchWeights.defaultWeights();

    // 1. Eligibility Filter
    final eligible = candidates.where(isEligible).toList();
    if (eligible.isEmpty) return [];

    // 2. Feature extraction & Scoring
    final List<_CandidateScoreTuple> scored = eligible.map((c) {
      final features = computeFeatures(c);
      final score = computeTotalScore(features, effectiveWeights);
      final tags = generateExplanationTags(features, c);
      return _CandidateScoreTuple(
        candidate: c,
        features: features,
        totalScore: score,
        explanationTags: tags,
      );
    }).toList();

    // 3. Deterministic Tie-Breaking:
    //    1) totalScore DESC
    //    2) skillScore DESC
    //    3) distanceKm ASC
    //    4) worker.id ASC (stable deterministic order)
    scored.sort((a, b) {
      final scoreCmp = b.totalScore.compareTo(a.totalScore);
      if (scoreCmp != 0) return scoreCmp;

      final skillCmp = b.features.skillScore.compareTo(a.features.skillScore);
      if (skillCmp != 0) return skillCmp;

      final distA = a.candidate.distanceKm ?? 999.0;
      final distB = b.candidate.distanceKm ?? 999.0;
      final distCmp = distA.compareTo(distB);
      if (distCmp != 0) return distCmp;

      return a.candidate.worker.id.compareTo(b.candidate.worker.id);
    });

    // 4. Bounded Top-N Slicing & Ranking assignment
    final sliced = scored.take(limit).toList();
    final List<FairMatchResult> results = [];

    for (int i = 0; i < sliced.length; i++) {
      final item = sliced[i];
      final rank = i + 1;
      final original = item.candidate.worker;

      final workerWithTag = Worker(
        id: original.id,
        name: original.name,
        categoryId: original.categoryId,
        rate: original.rate,
        rating: original.rating,
        reviewCount: original.reviewCount,
        jobsCompleted: original.jobsCompleted,
        distanceKm: item.candidate.distanceKm ?? original.distanceKm,
        experience: original.experience,
        availability: original.availability,
        specializations: original.specializations.isNotEmpty
            ? original.specializations
            : item.explanationTags,
        locationTag: original.locationTag,
        imageUrl: original.imageUrl,
        isUnionGold: original.isUnionGold,
        isCoopMaster: original.isCoopMaster,
        customTag: rank == 1 ? 'FairMatch Recommended' : null,
        bio: original.bio,
        federationId: original.federationId,
        insuranceAmount: original.insuranceAmount,
        languages: original.languages,
        serviceAreas: original.serviceAreas,
      );

      results.add(FairMatchResult(
        worker: workerWithTag,
        totalScore: item.totalScore,
        rank: rank,
        features: item.features,
        explanationTags: item.explanationTags,
        algorithmVersion: algorithm,
      ));
    }

    return results;
  }

  // ===========================================================================
  // Research Baselines for Experimental Evaluation
  // ===========================================================================

  /// Baseline 1: Nearest Worker heuristic.
  List<FairMatchResult> rankNearest(
    List<FairMatchCandidate> candidates, {
    int limit = FairMatchConfig.defaultTopN,
  }) {
    return rankCandidates(
      candidates,
      weights: FairMatchWeights.nearest(),
      limit: limit,
      algorithm: 'nearest',
    );
  }

  /// Baseline 2: Highest Rated Worker heuristic.
  List<FairMatchResult> rankHighestRated(
    List<FairMatchCandidate> candidates, {
    int limit = FairMatchConfig.defaultTopN,
  }) {
    return rankCandidates(
      candidates,
      weights: FairMatchWeights.highestRated(),
      limit: limit,
      algorithm: 'highest_rated',
    );
  }

  /// Baseline 3: Combined Rating + Distance heuristic.
  List<FairMatchResult> rankRatingDistance(
    List<FairMatchCandidate> candidates, {
    int limit = FairMatchConfig.defaultTopN,
  }) {
    return rankCandidates(
      candidates,
      weights: FairMatchWeights.ratingDistance(),
      limit: limit,
      algorithm: 'rating_distance',
    );
  }

  double _roundTo4(double val) => (val * 10000).round() / 10000.0;
}

class _CandidateScoreTuple {
  final FairMatchCandidate candidate;
  final FairMatchFeatures features;
  final double totalScore;
  final List<String> explanationTags;

  _CandidateScoreTuple({
    required this.candidate,
    required this.features,
    required this.totalScore,
    required this.explanationTags,
  });
}