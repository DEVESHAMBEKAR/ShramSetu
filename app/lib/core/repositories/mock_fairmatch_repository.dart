import '../models/fairmatch_models.dart';
import '../services/fairmatch_engine.dart';
import '../../features/customer/data/repositories/mock_customer_repository.dart';
import 'i_fairmatch_repository.dart';

class MockFairMatchRepository implements IFairMatchRepository {
  final FairMatchEngine _engine;
  final MockCustomerRepository _customerRepo;
  bool simulateFailure = false;

  MockFairMatchRepository({
    FairMatchEngine? engine,
    MockCustomerRepository? customerRepo,
  })  : _engine = engine ?? FairMatchEngine.instance,
        _customerRepo = customerRepo ?? MockCustomerRepository();

  @override
  Future<List<FairMatchResult>> recommendWorkers({
    required String serviceId,
    double? customerLat,
    double? customerLng,
    FairMatchWeights? weights,
    int limit = FairMatchConfig.defaultTopN,
    String algorithm = FairMatchConfig.version,
  }) async {
    if (simulateFailure) {
      throw Exception('Simulated FairMatch engine failure for fallback testing');
    }

    await Future.delayed(const Duration(milliseconds: 50));

    // Convert mock workers to candidates
    final candidates = _customerRepo.workers.map((w) {
      // Map category/service matching
      final matchesSkill = w.categoryId == serviceId;
      final expYears = int.tryParse(w.experience.replaceAll(RegExp(r'[^0-9]'), '')) ?? 4;
      // Simulated workload based on completed jobs / id
      final active = w.id == 'w1' ? 1 : 0;
      final recent7d = w.id == 'w3' ? 4 : 1;

      return FairMatchCandidate(
        worker: w,
        hasVerifiedSkill: matchesSkill,
        isAvailable: true,
        distanceKm: w.distanceKm,
        hasCoordinates: true,
        rating: w.rating,
        reviewCount: w.reviewCount,
        experienceYears: expYears,
        activeBookings: active,
        recent7dBookings: recent7d,
      );
    }).toList();

    return _engine.rankCandidates(
      candidates,
      weights: weights,
      limit: limit,
      algorithm: algorithm,
    );
  }
}