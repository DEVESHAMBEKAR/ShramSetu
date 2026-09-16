import 'package:flutter/foundation.dart';
import '../models/fairmatch_models.dart';
import '../repositories/i_fairmatch_repository.dart';
import '../../features/customer/data/models/customer_models.dart';

/// Service interface for the FairMatch operational recommendation engine.
abstract class IFairMatchService {
  /// Recommends and ranks eligible artisans for a customer service request.
  Future<List<FairMatchResult>> getRecommendedWorkers({
    required String serviceId,
    double? customerLat,
    double? customerLng,
    int limit = FairMatchConfig.defaultTopN,
  });

  /// Derives customer-facing, human-readable explanation tags from FairMatch results.
  /// Strictly avoids exposing raw floating-point scores or competitor workloads.
  List<String> getCustomerFriendlyExplanations(FairMatchResult result);

  /// Provides an explainable rationale sentence for a recommended artisan.
  String getRecommendationSummary(FairMatchResult result);
}

/// Production implementation of FairMatchService.
class FairMatchService implements IFairMatchService {
  final IFairMatchRepository _fairMatchRepository;

  FairMatchService(this._fairMatchRepository);

  @override
  Future<List<FairMatchResult>> getRecommendedWorkers({
    required String serviceId,
    double? customerLat,
    double? customerLng,
    int limit = FairMatchConfig.defaultTopN,
  }) async {
    try {
      final results = await _fairMatchRepository.recommendWorkers(
        serviceId: serviceId,
        customerLat: customerLat,
        customerLng: customerLng,
        limit: limit,
      );

      // Enhance workers with customer-friendly explanation tags
      return results.map((res) {
        final friendlyTags = getCustomerFriendlyExplanations(res);
        final updatedWorker = Worker(
          id: res.worker.id,
          name: res.worker.name,
          categoryId: res.worker.categoryId,
          rate: res.worker.rate,
          rating: res.worker.rating,
          reviewCount: res.worker.reviewCount,
          jobsCompleted: res.worker.jobsCompleted,
          distanceKm: res.worker.distanceKm,
          experience: res.worker.experience,
          availability: res.worker.availability,
          specializations: friendlyTags,
          locationTag: res.worker.locationTag,
          imageUrl: res.worker.imageUrl,
          bio: res.worker.bio,
          federationId: res.worker.federationId,
          insuranceAmount: res.worker.insuranceAmount,
          languages: res.worker.languages,
          serviceAreas: res.worker.serviceAreas,
          isUnionGold: res.worker.isUnionGold,
          isCoopMaster: res.worker.isCoopMaster,
          customTag: res.rank == 1 ? 'FairMatch Recommended' : null,
        );

        return FairMatchResult(
          worker: updatedWorker,
          totalScore: res.totalScore,
          rank: res.rank,
          features: res.features,
          explanationTags: friendlyTags,
          algorithmVersion: res.algorithmVersion,
        );
      }).toList();
    } catch (e) {
      debugPrint('[FairMatchService] Failed to retrieve recommendations: $e');
      // Graceful failure isolation: return empty list to trigger repository fallback
      return [];
    }
  }

  @override
  List<String> getCustomerFriendlyExplanations(FairMatchResult result) {
    final tags = <String>[];

    // 1. Skill verification
    if (result.features.skillScore >= 0.8) {
      tags.add('Verified Guild Artisan');
    }

    // 2. Proximity factor
    if (result.worker.distanceKm <= 3.0 || result.features.distanceScore >= 0.7) {
      tags.add('Nearby Specialist');
    }

    // 3. Rating & Community track record
    if (result.worker.rating >= 4.7 || result.features.ratingScore >= 0.8) {
      tags.add('High Community Rating');
    }

    // 4. Availability
    if (result.features.availabilityScore >= 0.7) {
      tags.add('Punctual Availability');
    }

    // 5. Cooperative fairness
    if (result.features.fairnessScore >= 0.6) {
      tags.add('Fair Opportunity Policy');
    }

    if (tags.isEmpty) {
      tags.addAll(['Verified Guild Member', 'Available Locally']);
    }

    return tags;
  }

  @override
  String getRecommendationSummary(FairMatchResult result) {
    final reasons = <String>[];
    if (result.features.skillScore >= 0.8) reasons.add('certified trade skill');
    if (result.worker.distanceKm <= 3.0) reasons.add('immediate local proximity');
    if (result.worker.rating >= 4.7) reasons.add('consistently high customer satisfaction');
    if (result.features.fairnessScore >= 0.6) reasons.add('equitable cooperative distribution');

    if (reasons.isEmpty) {
      return 'Recommended based on verified guild credentials and active availability.';
    }

    return 'Recommended based on ${reasons.join(', ')}.';
  }
}
