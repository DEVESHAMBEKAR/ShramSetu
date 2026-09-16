import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/fairmatch_models.dart';
import 'i_fairmatch_repository.dart';

class SupabaseFairMatchRepository implements IFairMatchRepository {
  final SupabaseClient _supabase;

  SupabaseFairMatchRepository(this._supabase);

  @override
  Future<List<FairMatchResult>> recommendWorkers({
    required String serviceId,
    double? customerLat,
    double? customerLng,
    FairMatchWeights? weights,
    int limit = FairMatchConfig.defaultTopN,
    String algorithm = FairMatchConfig.version,
  }) async {
    try {
      final Map<String, dynamic> params = {
        'p_service_id': serviceId,
        if (customerLat != null) 'p_customer_lat': customerLat,
        if (customerLng != null) 'p_customer_lng': customerLng,
        if (weights != null) 'p_weights': weights.toJson(),
        'p_limit': limit,
        'p_algorithm': algorithm,
      };

      final response = await _supabase.rpc('fairmatch_recommend_workers', params: params);

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

      final workersRaw = data['workers'] as List? ?? [];
      final List<FairMatchResult> results = [];

      for (int i = 0; i < workersRaw.length; i++) {
        final item = workersRaw[i] as Map<String, dynamic>;
        results.add(FairMatchResult.fromJson(item, i + 1));
      }

      debugPrint('[FairMatchRepo] Successfully fetched ${results.length} FairMatch ranked workers.');
      return results;
    } catch (e) {
      debugPrint('[FairMatchRepo] RPC error during recommendWorkers: $e');
      rethrow;
    }
  }
}