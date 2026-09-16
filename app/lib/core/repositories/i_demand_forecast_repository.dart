import '../models/demand_forecast_models.dart';

/// Contract for Demand Forecasting data access, model execution, and evaluation.
abstract class IDemandForecastRepository {
  /// Fetches historical realized daily demand aggregated by date, service, and location.
  Future<List<DailyDemandPoint>> getHistoricalDemand({
    String? serviceId,
    String? locationKey,
    DateTime? startDate,
    DateTime? endDate,
    bool useSyntheticBenchmarkIfSparse = true,
  });

  /// Computes or retrieves cached forecasts for a specific service, area, and horizon.
  Future<DemandForecastResult> getOrGenerateForecast({
    String? serviceId,
    String serviceName = 'All Services',
    String locationKey = 'All',
    int horizonDays = DemandForecastConfig.defaultHorizonDays,
    String modelType = 'primary_holt_winters',
    bool forceRefresh = false,
  });

  /// Evaluates and compares all baseline models and the primary model on out-of-sample data.
  Future<Map<String, ForecastEvaluationMetrics>> getModelComparison({
    String? serviceId,
    String? locationKey,
  });
}
