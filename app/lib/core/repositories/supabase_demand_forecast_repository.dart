import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/demand_forecast_models.dart';
import '../services/demand_forecasting_engine.dart';
import 'i_demand_forecast_repository.dart';

class SupabaseDemandForecastRepository implements IDemandForecastRepository {
  final SupabaseClient _supabase;
  final DemandForecastingEngine _engine;

  SupabaseDemandForecastRepository(
    this._supabase, {
    DemandForecastingEngine? engine,
  }) : _engine = engine ?? DemandForecastingEngine.instance;

  @override
  Future<List<DailyDemandPoint>> getHistoricalDemand({
    String? serviceId,
    String? locationKey,
    DateTime? startDate,
    DateTime? endDate,
    bool useSyntheticBenchmarkIfSparse = true,
  }) async {
    try {
      final Map<String, dynamic> params = {};
      if (serviceId != null) params['p_service_id'] = serviceId;
      if (locationKey != null && locationKey != 'All') {
        params['p_location_key'] = locationKey;
      }
      if (startDate != null) {
        params['p_start_date'] = startDate.toIso8601String().split('T').first;
      }
      if (endDate != null) {
        params['p_end_date'] = endDate.toIso8601String().split('T').first;
      }

      final response = await _supabase.rpc('get_historical_booking_demand', params: params);

      final List<dynamic> rows = response is List ? response : [];
      final List<DailyDemandPoint> points = rows
          .map((row) => DailyDemandPoint.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();

      // If historical data in production is sparse and benchmark fallback is enabled:
      if (points.length < DemandForecastConfig.minHistoricalDaysRequired &&
          useSyntheticBenchmarkIfSparse) {
        debugPrint(
            '[DemandForecastRepo] Live history sparse (${points.length} days). Using isolated synthetic research benchmark.');
        return _engine.generateSyntheticBenchmarkDataset(
          days: 60,
          serviceId: serviceId,
          serviceName: points.isNotEmpty ? points.first.serviceName : 'Plumbing',
          locationKey: locationKey ?? 'Kothrud, Pune',
        );
      }

      return _engine.prepareContinuousSeries(
        points,
        fallbackLocationKey: locationKey,
      );
    } catch (e) {
      debugPrint('[DemandForecastRepo] Error querying live historical demand ($e). Falling back to isolated benchmark.');
      if (useSyntheticBenchmarkIfSparse) {
        return _engine.generateSyntheticBenchmarkDataset(
          days: 60,
          serviceId: serviceId,
          serviceName: 'Plumbing',
          locationKey: locationKey ?? 'Kothrud, Pune',
        );
      }
      return [];
    }
  }

  @override
  Future<DemandForecastResult> getOrGenerateForecast({
    String? serviceId,
    String serviceName = 'All Services',
    String locationKey = 'All',
    int horizonDays = DemandForecastConfig.defaultHorizonDays,
    String modelType = 'primary_holt_winters',
    bool forceRefresh = false,
  }) async {
    final history = await getHistoricalDemand(
      serviceId: serviceId,
      locationKey: locationKey,
      useSyntheticBenchmarkIfSparse: true,
    );

    final isSynthetic = history.any((p) => p.isSynthetic);

    // Compute forecasts according to selected model type
    final List<DemandForecastItem> forecasts;
    final String modelVersion;

    switch (modelType) {
      case 'naive':
        forecasts = _engine.forecastNaive(history, horizonDays);
        modelVersion = 'naive_v1';
        break;
      case 'moving_average':
        forecasts = _engine.forecastMovingAverage(history, horizonDays, windowSize: 7);
        modelVersion = 'moving_average_v1';
        break;
      case 'seasonal_naive':
        forecasts = _engine.forecastSeasonalNaive(history, horizonDays, seasonPeriod: 7);
        modelVersion = 'seasonal_naive_v1';
        break;
      case 'primary_holt_winters':
      default:
        forecasts = _engine.forecastHoltWinters(history, horizonDays);
        modelVersion = DemandForecastConfig.defaultModelVersion;
        break;
    }

    // Retrieve active worker count in this category/area for capacity analysis
    int activeWorkers = 5; // Default safe estimate
    try {
      var query = _supabase.from('workers').select('id').eq('worker_status', 'ACTIVE');
      if (locationKey != 'All') {
        query = query.eq('location_tag', locationKey);
      }
      final countRes = await query.count(CountOption.exact);
      activeWorkers = countRes.count;
    } catch (_) {}

    // Supply-demand insight
    final supplyInsight = _engine.computeSupplyInsight(
      forecasts: forecasts,
      activeWorkerSupply: activeWorkers,
      historicalDaysCount: history.length,
    );

    // Evaluation metrics
    ForecastEvaluationMetrics? metrics;
    if (history.length >= DemandForecastConfig.minHistoricalDaysRequired + 7) {
      final comparisons = _engine.compareModelsChronologically(history, testDays: 7);
      metrics = comparisons[modelType] ?? comparisons['primary_holt_winters'];
    }

    return DemandForecastResult(
      serviceId: serviceId,
      serviceName: serviceName,
      locationKey: locationKey,
      historicalPoints: history,
      forecasts: forecasts,
      modelVersion: modelVersion,
      generatedAt: DateTime.now(),
      isSynthetic: isSynthetic,
      evaluationMetrics: metrics,
      supplyInsight: supplyInsight,
    );
  }

  @override
  Future<Map<String, ForecastEvaluationMetrics>> getModelComparison({
    String? serviceId,
    String? locationKey,
  }) async {
    final history = await getHistoricalDemand(
      serviceId: serviceId,
      locationKey: locationKey,
      useSyntheticBenchmarkIfSparse: true,
    );

    return _engine.compareModelsChronologically(history, testDays: 7);
  }
}
