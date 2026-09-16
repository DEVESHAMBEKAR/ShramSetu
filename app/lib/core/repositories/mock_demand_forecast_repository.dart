import '../models/demand_forecast_models.dart';
import '../services/demand_forecasting_engine.dart';
import 'i_demand_forecast_repository.dart';

class MockDemandForecastRepository implements IDemandForecastRepository {
  final DemandForecastingEngine _engine;
  bool simulateFailure = false;
  bool simulateEmptyData = false;

  MockDemandForecastRepository({
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
    if (simulateFailure) {
      throw Exception('Simulated Demand Forecast repository failure');
    }

    if (simulateEmptyData) {
      return [];
    }

    await Future.delayed(const Duration(milliseconds: 50));

    return _engine.generateSyntheticBenchmarkDataset(
      days: 60,
      serviceId: serviceId ?? '22222222-2222-2222-2222-222222222222',
      serviceName: 'Plumbing',
      locationKey: locationKey ?? 'Kothrud, Pune',
    );
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
    if (simulateFailure) {
      throw Exception('Simulated Demand Forecast repository failure');
    }

    final history = await getHistoricalDemand(
      serviceId: serviceId,
      locationKey: locationKey,
      useSyntheticBenchmarkIfSparse: true,
    );

    if (history.isEmpty) {
      return DemandForecastResult(
        serviceId: serviceId,
        serviceName: serviceName,
        locationKey: locationKey,
        historicalPoints: [],
        forecasts: [],
        modelVersion: DemandForecastConfig.defaultModelVersion,
        generatedAt: DateTime.now(),
        isSynthetic: true,
        supplyInsight: const CooperativeSupplyInsight(
          forecastedDailyAverage: 0.0,
          activeWorkerSupply: 0,
          capacityRatio: 1.0,
          status: SupplyGapStatus.insufficientData,
          recommendationText: 'Insufficient historical data for forecasting.',
        ),
      );
    }

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

    final supplyInsight = _engine.computeSupplyInsight(
      forecasts: forecasts,
      activeWorkerSupply: 8, // Mock active workers in Kothrud
      historicalDaysCount: history.length,
    );

    final comparisons = _engine.compareModelsChronologically(history, testDays: 7);
    final metrics = comparisons[modelType] ?? comparisons['primary_holt_winters'];

    return DemandForecastResult(
      serviceId: serviceId,
      serviceName: serviceName,
      locationKey: locationKey,
      historicalPoints: history,
      forecasts: forecasts,
      modelVersion: modelVersion,
      generatedAt: DateTime.now(),
      isSynthetic: true,
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
