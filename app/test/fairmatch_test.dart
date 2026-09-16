import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/fairmatch_models.dart';
import 'package:app/core/services/fairmatch_engine.dart';
import 'package:app/core/repositories/mock_fairmatch_repository.dart';
import 'package:app/features/customer/data/models/customer_models.dart';
import 'package:app/features/customer/data/repositories/mock_customer_repository.dart';
import 'package:app/core/config/dependency_injection.dart';

Worker createDummyWorker({
  required String id,
  required String name,
  String categoryId = 'c2',
  double rating = 4.8,
  int reviewCount = 50,
  double distanceKm = 2.0,
  String experience = '5 yrs exp',
}) {
  return Worker(
    id: id,
    name: name,
    categoryId: categoryId,
    rate: 350,
    rating: rating,
    reviewCount: reviewCount,
    jobsCompleted: 100,
    distanceKm: distanceKm,
    experience: experience,
    availability: 'Available Today',
    specializations: ['Plumbing'],
    locationTag: 'Kothrud, Pune',
    imageUrl: '',
  );
}

void main() {
  setUpAll(() {
    DI.setup();
  });

  group('1. FairMatch Weights Validation & Presets', () {
    test('Default weights sum strictly to 1.0 and are valid', () {
      final weights = FairMatchWeights.defaultWeights();
      expect(weights.isValid, isTrue);
      expect(weights.sum, closeTo(1.0, 0.0001));
      expect(weights.skillWeight, 0.35);
      expect(weights.distanceWeight, 0.20);
      expect(weights.availabilityWeight, 0.15);
      expect(weights.ratingWeight, 0.10);
      expect(weights.experienceWeight, 0.10);
      expect(weights.fairnessWeight, 0.10);
    });

    test('Invalid weights that do not sum to 1.0 fail validation', () {
      const invalidOver = FairMatchWeights(
        skillWeight: 0.5,
        distanceWeight: 0.5,
        availabilityWeight: 0.2,
        ratingWeight: 0.1,
        experienceWeight: 0.1,
        fairnessWeight: 0.1,
      );
      expect(invalidOver.isValid, isFalse);

      const invalidUnder = FairMatchWeights(
        skillWeight: 0.2,
        distanceWeight: 0.2,
        availabilityWeight: 0.1,
        ratingWeight: 0.1,
        experienceWeight: 0.1,
        fairnessWeight: 0.1,
      );
      expect(invalidUnder.isValid, isFalse);
    });

    test('Negative weight component fails validation', () {
      const negativeWeight = FairMatchWeights(
        skillWeight: 0.5,
        distanceWeight: -0.1,
        availabilityWeight: 0.2,
        ratingWeight: 0.2,
        experienceWeight: 0.1,
        fairnessWeight: 0.1,
      );
      expect(negativeWeight.isValid, isFalse);
    });

    test('Research baseline weights presets are properly normalized', () {
      final nearest = FairMatchWeights.nearest();
      expect(nearest.isValid, isTrue);
      expect(nearest.distanceWeight, 1.0);
      expect(nearest.ratingWeight, 0.0);

      final highestRated = FairMatchWeights.highestRated();
      expect(highestRated.isValid, isTrue);
      expect(highestRated.ratingWeight, 1.0);
      expect(highestRated.distanceWeight, 0.0);

      final ratingDist = FairMatchWeights.ratingDistance();
      expect(ratingDist.isValid, isTrue);
      expect(ratingDist.ratingWeight, 0.5);
      expect(ratingDist.distanceWeight, 0.5);
    });
  });

  group('2. Feature Extraction & Normalization', () {
    final engine = FairMatchEngine.instance;

    test('Feature normalization: all scores must strictly be in [0.0, 1.0]', () {
      final candidate = FairMatchCandidate(
        worker: createDummyWorker(id: 'w1', name: 'Test Worker'),
        hasVerifiedSkill: true,
        isAvailable: true,
        distanceKm: 4.5,
        hasCoordinates: true,
        rating: 4.5,
        reviewCount: 30,
        experienceYears: 6,
        activeBookings: 1,
        recent7dBookings: 2,
      );

      final features = engine.computeFeatures(candidate);
      expect(features.areAllNormalized, isTrue);
      expect(features.skillScore, inInclusiveRange(0.0, 1.0));
      expect(features.distanceScore, inInclusiveRange(0.0, 1.0));
      expect(features.availabilityScore, inInclusiveRange(0.0, 1.0));
      expect(features.ratingScore, inInclusiveRange(0.0, 1.0));
      expect(features.experienceScore, inInclusiveRange(0.0, 1.0));
      expect(features.fairnessScore, inInclusiveRange(0.0, 1.0));
    });

    test('Skill matching score: 1.0 for verified skill, 0.0 for unverified', () {
      final verified = FairMatchCandidate(
        worker: createDummyWorker(id: 'w1', name: 'Verified'),
        hasVerifiedSkill: true,
      );
      final unverified = FairMatchCandidate(
        worker: createDummyWorker(id: 'w2', name: 'Unverified'),
        hasVerifiedSkill: false,
      );

      expect(engine.computeFeatures(verified).skillScore, 1.0);
      expect(engine.computeFeatures(unverified).skillScore, 0.0);
    });

    test('Distance decay: 0km -> 1.0, 7.5km -> 0.5, >=15km -> 0.0', () {
      final c0 = FairMatchCandidate(
        worker: createDummyWorker(id: 'w0', name: '0km'),
        distanceKm: 0.0,
      );
      final c7 = FairMatchCandidate(
        worker: createDummyWorker(id: 'w7', name: '7.5km'),
        distanceKm: 7.5,
      );
      final c20 = FairMatchCandidate(
        worker: createDummyWorker(id: 'w20', name: '20km'),
        distanceKm: 20.0,
      );

      expect(engine.computeFeatures(c0).distanceScore, closeTo(1.0, 0.001));
      expect(engine.computeFeatures(c7).distanceScore, closeTo(0.5, 0.001));
      expect(engine.computeFeatures(c20).distanceScore, closeTo(0.0, 0.001));
    });

    test('Missing coordinates fallback to neutral 0.5 distance score', () {
      final missingCoords = FairMatchCandidate(
        worker: createDummyWorker(id: 'w_no_loc', name: 'No Location'),
        hasCoordinates: false,
        distanceKm: null,
      );

      final features = engine.computeFeatures(missingCoords);
      expect(features.distanceScore, FairMatchConfig.missingCoordinatesDistanceScore);
      expect(features.distanceScore, 0.5);
    });

    test('Rating normalization: 5.0 -> 1.0, 3.0 -> 0.5, 1.0 -> 0.0', () {
      final r5 = FairMatchCandidate(
        worker: createDummyWorker(id: 'w5', name: '5 Star'),
        rating: 5.0,
        reviewCount: 20,
      );
      final r3 = FairMatchCandidate(
        worker: createDummyWorker(id: 'w3', name: '3 Star'),
        rating: 3.0,
        reviewCount: 15,
      );
      final r1 = FairMatchCandidate(
        worker: createDummyWorker(id: 'w1', name: '1 Star'),
        rating: 1.0,
        reviewCount: 10,
      );

      expect(engine.computeFeatures(r5).ratingScore, closeTo(1.0, 0.001));
      expect(engine.computeFeatures(r3).ratingScore, closeTo(0.5, 0.001));
      expect(engine.computeFeatures(r1).ratingScore, closeTo(0.0, 0.001));
    });

    test('Cold-start rule: worker with 0 reviews gets neutral 0.5 rating score', () {
      final coldStartWorker = FairMatchCandidate(
        worker: createDummyWorker(id: 'w_cold', name: 'New Worker'),
        rating: 0.0,
        reviewCount: 0,
      );
      final coldStartWithOldRating = FairMatchCandidate(
        worker: createDummyWorker(id: 'w_cold2', name: 'New Worker 2'),
        rating: 5.0, // Should be ignored because reviewCount is 0
        reviewCount: 0,
      );

      expect(engine.computeFeatures(coldStartWorker).ratingScore, FairMatchConfig.coldStartRatingScore);
      expect(engine.computeFeatures(coldStartWithOldRating).ratingScore, FairMatchConfig.coldStartRatingScore);
    });

    test('Experience score: 0 yrs -> 0.0, 1 yr -> 0.1, 5 yrs -> 0.5, >=10 yrs -> 1.0', () {
      final e0 = FairMatchCandidate(
        worker: createDummyWorker(id: 'we0', name: '0yr'),
        experienceYears: 0,
      );
      final e1 = FairMatchCandidate(
        worker: createDummyWorker(id: 'we1', name: '1yr'),
        experienceYears: 1,
      );
      final e5 = FairMatchCandidate(
        worker: createDummyWorker(id: 'we5', name: '5yr'),
        experienceYears: 5,
      );
      final e12 = FairMatchCandidate(
        worker: createDummyWorker(id: 'we12', name: '12yr'),
        experienceYears: 12,
      );

      expect(engine.computeFeatures(e0).experienceScore, closeTo(0.0, 0.001));
      expect(engine.computeFeatures(e1).experienceScore, closeTo(0.1, 0.001));
      expect(engine.computeFeatures(e5).experienceScore, closeTo(0.5, 0.001));
      expect(engine.computeFeatures(e12).experienceScore, closeTo(1.0, 0.001));
    });

    test('Fairness / Workload score: zero workload -> 1.0, high workload -> 0.0', () {
      // Workload index = 2 * active + 1 * recent7d
      // Zero workload: W = 0 -> score = 1.0
      final zeroLoad = FairMatchCandidate(
        worker: createDummyWorker(id: 'wf0', name: 'Idle Worker'),
        activeBookings: 0,
        recent7dBookings: 0,
      );
      expect(engine.computeFeatures(zeroLoad).fairnessScore, closeTo(1.0, 0.001));

      // Moderate workload: active=1, recent7d=4 -> W = 2(1) + 4 = 6 -> score = 1 - 0.6 = 0.4
      final modLoad = FairMatchCandidate(
        worker: createDummyWorker(id: 'wf1', name: 'Moderate Worker'),
        activeBookings: 1,
        recent7dBookings: 4,
      );
      expect(engine.computeFeatures(modLoad).fairnessScore, closeTo(0.4, 0.001));

      // Heavy workload: active=3, recent7d=8 -> W = 6 + 8 = 14 >= 10 -> score = 0.0
      final heavyLoad = FairMatchCandidate(
        worker: createDummyWorker(id: 'wf2', name: 'Busy Worker'),
        activeBookings: 3,
        recent7dBookings: 8,
      );
      expect(engine.computeFeatures(heavyLoad).fairnessScore, closeTo(0.0, 0.001));
    });
  });

  group('3. Eligibility & Hard Filtering', () {
    final engine = FairMatchEngine.instance;

    test('Candidate missing verified skill is excluded from ranking', () {
      final unverified = FairMatchCandidate(
        worker: createDummyWorker(id: 'w_no_skill', name: 'No Skill'),
        hasVerifiedSkill: false,
        isAvailable: true,
      );
      expect(engine.isEligible(unverified), isFalse);

      final results = engine.rankCandidates([unverified]);
      expect(results, isEmpty);
    });

    test('Unavailable candidate is excluded from ranking', () {
      final unavailable = FairMatchCandidate(
        worker: createDummyWorker(id: 'w_busy', name: 'Unavailable Worker'),
        hasVerifiedSkill: true,
        isAvailable: false,
      );
      expect(engine.isEligible(unavailable), isFalse);

      final results = engine.rankCandidates([unavailable]);
      expect(results, isEmpty);
    });

    test('Candidate with verified skill and available is eligible', () {
      final eligible = FairMatchCandidate(
        worker: createDummyWorker(id: 'w_ok', name: 'Eligible Worker'),
        hasVerifiedSkill: true,
        isAvailable: true,
      );
      expect(engine.isEligible(eligible), isTrue);

      final results = engine.rankCandidates([eligible]);
      expect(results.length, 1);
    });
  });

  group('4. Deterministic Tie-Breaking & Reproducibility', () {
    final engine = FairMatchEngine.instance;

    test('Identical scores break ties deterministically on worker ID (UUID string sort)', () {
      // Create two candidates with exact identical properties except ID
      final workerA = FairMatchCandidate(
        worker: createDummyWorker(id: 'w_alpha', name: 'Worker Alpha'),
        hasVerifiedSkill: true,
        isAvailable: true,
        distanceKm: 2.0,
        rating: 4.5,
        reviewCount: 10,
        experienceYears: 5,
      );
      final workerB = FairMatchCandidate(
        worker: createDummyWorker(id: 'w_beta', name: 'Worker Beta'),
        hasVerifiedSkill: true,
        isAvailable: true,
        distanceKm: 2.0,
        rating: 4.5,
        reviewCount: 10,
        experienceYears: 5,
      );

      // Order 1: Alpha first
      final rank1 = engine.rankCandidates([workerA, workerB]);
      expect(rank1[0].worker.id, 'w_alpha');
      expect(rank1[1].worker.id, 'w_beta');

      // Order 2: Beta passed first into list -> output must still deterministically put Alpha first
      final rank2 = engine.rankCandidates([workerB, workerA]);
      expect(rank2[0].worker.id, 'w_alpha');
      expect(rank2[1].worker.id, 'w_beta');
    });

    test('Distance breaks tie if totalScore is identical', () {
      // Construct identical candidates where distance is different
      // With custom weights distance has 0 weight to produce identical score
      const testWeights = FairMatchWeights(
        skillWeight: 0.5,
        distanceWeight: 0.0,
        availabilityWeight: 0.5,
        ratingWeight: 0.0,
        experienceWeight: 0.0,
        fairnessWeight: 0.0,
      );

      final near = FairMatchCandidate(
        worker: createDummyWorker(id: 'w_near', name: 'Near Worker'),
        hasVerifiedSkill: true,
        isAvailable: true,
        distanceKm: 1.0,
      );
      final far = FairMatchCandidate(
        worker: createDummyWorker(id: 'w_far', name: 'Far Worker'),
        hasVerifiedSkill: true,
        isAvailable: true,
        distanceKm: 5.0,
      );

      final results = engine.rankCandidates([far, near], weights: testWeights);
      expect(results[0].worker.id, 'w_near');
      expect(results[1].worker.id, 'w_far');
    });
  });

  group('5. Explainability & Recommendation Badges', () {
    final engine = FairMatchEngine.instance;

    test('Top ranked candidate receives FairMatch Recommended badge', () {
      final c1 = FairMatchCandidate(
        worker: createDummyWorker(id: 'w1', name: 'Top Worker'),
        hasVerifiedSkill: true,
        isAvailable: true,
        distanceKm: 1.0,
        rating: 5.0,
        reviewCount: 20,
      );
      final c2 = FairMatchCandidate(
        worker: createDummyWorker(id: 'w2', name: 'Second Worker'),
        hasVerifiedSkill: true,
        isAvailable: true,
        distanceKm: 8.0,
        rating: 4.0,
        reviewCount: 5,
      );

      final results = engine.rankCandidates([c2, c1]);
      expect(results.length, 2);
      expect(results[0].rank, 1);
      expect(results[0].worker.customTag, 'FairMatch Recommended');
      expect(results[1].rank, 2);
      expect(results[1].worker.customTag, isNull);
    });

    test('Explanation tags are human-readable and do not expose raw math floats', () {
      final candidate = FairMatchCandidate(
        worker: createDummyWorker(id: 'w1', name: 'Skilled Artisan'),
        hasVerifiedSkill: true,
        isAvailable: true,
        distanceKm: 1.2,
        rating: 4.9,
        reviewCount: 50,
        experienceYears: 8,
        activeBookings: 0,
        recent7dBookings: 1,
      );

      final results = engine.rankCandidates([candidate]);
      final tags = results.first.explanationTags;
      expect(tags, isNotEmpty);

      // Verify no raw float scores (e.g., '0.84', '0.9') leak into customer-facing tags
      for (final tag in tags) {
        expect(RegExp(r'\d+\.\d+').hasMatch(tag), isFalse,
            reason: 'Explanation tag "$tag" should not contain raw floating-point score.');
      }

      expect(tags, contains('Verified Skill'));
      expect(tags, contains('Available Now'));
      expect(tags, contains('Nearby'));
      expect(tags, contains('Top Rated'));
    });
  });

  group('6. Top-N Bounded Ranking & Limits', () {
    final engine = FairMatchEngine.instance;

    test('Limit parameter bounds the returned list size', () {
      final candidates = List.generate(
        10,
        (i) => FairMatchCandidate(
          worker: createDummyWorker(id: 'w$i', name: 'Worker $i'),
          hasVerifiedSkill: true,
          isAvailable: true,
          distanceKm: (i + 1) * 1.0,
          rating: 4.5,
          reviewCount: 10,
        ),
      );

      final top3 = engine.rankCandidates(candidates, limit: 3);
      expect(top3.length, 3);
      expect(top3[0].rank, 1);
      expect(top3[1].rank, 2);
      expect(top3[2].rank, 3);
    });

    test('Empty candidate list safely returns empty result list', () {
      final results = engine.rankCandidates([]);
      expect(results, isEmpty);
    });
  });

  group('7. Research Baselines Comparison', () {
    final engine = FairMatchEngine.instance;

    // Setup 3 contrasting candidates:
    // Candidate A: Very close (0.5km), lower rating (4.0), high workload
    // Candidate B: Farther (6.0km), highest rating (5.0), high workload
    // Candidate C: Moderate (2.0km), good rating (4.8), zero workload, experienced
    final candidateA = FairMatchCandidate(
      worker: createDummyWorker(id: 'w_near', name: 'Worker Near'),
      hasVerifiedSkill: true,
      isAvailable: true,
      distanceKm: 0.5,
      rating: 4.0,
      reviewCount: 25,
      activeBookings: 3,
      recent7dBookings: 5,
    );

    final candidateB = FairMatchCandidate(
      worker: createDummyWorker(id: 'w_highest_rated', name: 'Worker Highest Rated'),
      hasVerifiedSkill: true,
      isAvailable: true,
      distanceKm: 6.0,
      rating: 5.0,
      reviewCount: 80,
      activeBookings: 2,
      recent7dBookings: 6,
    );

    final candidateC = FairMatchCandidate(
      worker: createDummyWorker(id: 'w_balanced', name: 'Worker FairMatch Pick'),
      hasVerifiedSkill: true,
      isAvailable: true,
      distanceKm: 1.8,
      rating: 4.8,
      reviewCount: 40,
      experienceYears: 8,
      activeBookings: 0,
      recent7dBookings: 0,
    );

    final candidates = [candidateA, candidateB, candidateC];

    test('Baseline 1: Nearest Worker ranks candidate A first', () {
      final nearestRank = engine.rankNearest(candidates);
      expect(nearestRank.first.worker.id, 'w_near');
    });

    test('Baseline 2: Highest Rated Worker ranks candidate B first', () {
      final ratingRank = engine.rankHighestRated(candidates);
      expect(ratingRank.first.worker.id, 'w_highest_rated');
    });

    test('Baseline 3: Rating + Distance balances rating and proximity', () {
      final ratingDistRank = engine.rankRatingDistance(candidates);
      expect(ratingDistRank, isNotEmpty);
      expect(ratingDistRank.first.features.areAllNormalized, isTrue);
    });

    test('FairMatch multi-factor formula provides equitable balanced matching', () {
      final fairMatchRank = engine.rankCandidates(candidates);
      expect(fairMatchRank, isNotEmpty);
      // Candidate C excels in fairness, skill, good rating and close proximity
      expect(fairMatchRank.first.worker.id, 'w_balanced');
    });
  });

  group('8. Repository Integration & Resilient Fallback', () {
    test('MockFairMatchRepository recommends workers using FairMatchEngine', () async {
      final repo = MockFairMatchRepository();
      final results = await repo.recommendWorkers(serviceId: 'c2');

      expect(results, isNotEmpty);
      expect(results.first.rank, 1);
      expect(results.first.worker.customTag, 'FairMatch Recommended');
    });

    test('MockCustomerRepository falls back gracefully when FairMatch fails', () async {
      final mockFairMatch = MockFairMatchRepository();
      mockFairMatch.simulateFailure = true; // Trigger failure
      DI.fairMatchRepo = mockFairMatch;

      final customerRepo = MockCustomerRepository();
      // Should not throw; should fall back to standard list
      final workers = await customerRepo.getEligibleWorkers('c2');
      expect(workers, isNotEmpty);
      expect(workers.every((w) => w.categoryId == 'c2'), isTrue);
    });

    test('FairMatchResult JSON serialization roundtrip', () {
      final sampleJson = {
        'id': 'w_json_test',
        'name': 'Ramesh Sawant',
        'category_id': 'c2',
        'rate': 400,
        'rating': 4.7,
        'review_count': 45,
        'completed_jobs': 80,
        'distance_km': 2.3,
        'experience_years': 5,
        'location_tag': 'Kothrud',
        'avatar_url': 'https://example.com/avatar.jpg',
        'bio': 'Reliable plumber',
        'is_union_gold': true,
        'is_coop_master': false,
        'total_score': 0.825,
        'skill_score': 1.0,
        'distance_score': 0.85,
        'availability_score': 1.0,
        'rating_score': 0.925,
        'experience_score': 0.5,
        'fairness_score': 0.7,
        'explanation_tags': ['Verified Skill', 'Nearby Worker'],
      };

      final result = FairMatchResult.fromJson(sampleJson, 1);
      expect(result.worker.id, 'w_json_test');
      expect(result.worker.name, 'Ramesh Sawant');
      expect(result.totalScore, 0.825);
      expect(result.rank, 1);
      expect(result.worker.customTag, 'FairMatch Recommended');
      expect(result.explanationTags, contains('Nearby Worker'));

      final jsonOut = result.toJson();
      expect(jsonOut['worker_id'], 'w_json_test');
      expect(jsonOut['total_score'], 0.825);
      expect(jsonOut['rank'], 1);
    });
  });
}
