import '../models/fairmatch_models.dart';

abstract class IFairMatchRepository {
  /// Recommends and ranks eligible workers for a service request using FairMatch
  /// or comparative research baseline algorithms.
  Future<List<FairMatchResult>> recommendWorkers({
    required String serviceId,
    double? customerLat,
    double? customerLng,
    FairMatchWeights? weights,
    int limit = FairMatchConfig.defaultTopN,
    String algorithm = FairMatchConfig.version,
  });
}