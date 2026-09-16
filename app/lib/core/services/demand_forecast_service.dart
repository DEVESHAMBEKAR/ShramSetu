import 'package:flutter/foundation.dart';
import '../models/demand_forecast_models.dart';
import '../repositories/i_demand_forecast_repository.dart';
import 'demand_forecasting_engine.dart';

/// Service interface for Demand Forecasting and cooperative capacity planning.
abstract class IDemandForecastService {
  /// Computes or retrieves demand forecasts for administrative capacity planning.
  Future<DemandForecastResult> getForecast({
    String? serviceId,
    String serviceName = 'All Services',
    String locationKey = 'All',
    int horizonDays = DemandForecastConfig.defaultHorizonDays,
    bool forceRefresh = false,
  });

  /// Evaluates the capacity gap between forecasted daily demand and active worker supply.
  Future<CooperativeSupplyInsight> getCapacityGapInsight({
    String? serviceId,
    String serviceName = 'All Services',
    String locationKey = 'All',
    int horizonDays = DemandForecastConfig.defaultHorizonDays,
    int? activeWorkerCountOverride,
  });

  /// Returns summary metrics and model metadata for display on the Admin Analytics screen.
  Future<Map<String, dynamic>> getForecastingAnalyticsSummary({
    String? serviceId,
    String? locationKey,
  });
}

/// Production implementation of DemandForecastService.
class DemandForecastService implements IDemandForecastService {
  final IDemandForecastRepository _repository;
  final DemandForecastingEngine _engine;

  DemandForecastService(this._repository, this._engine);

  @override
  Future<DemandForecastResult> getForecast({
    String? serviceId,
    String serviceName = 'All Services',
    String locationKey = 'All',
    int horizonDays = DemandForecastConfig.defaultHorizonDays,
    bool forceRefresh = false,
  }) async {
    try {
      return await _repository.getOrGenerateForecast(
        serviceId: serviceId,
        serviceName: serviceName,
        locationKey: locationKey,
        horizonDays: horizonDays,
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      debugPrint('[DemandForecastService] Forecast generation error: $e');
      // Return a safe empty result with an informative note
      return DemandForecastResult(
        serviceId: serviceId ?? 'all',
        serviceName: serviceName,
        locationKey: locationKey,
        forecasts: [],
        historicalPoints: [],
        evaluationMetrics: const ForecastEvaluationMetrics(
          mae: 0.0,
          rmse: 0.0,
          mape: 0.0,
          testSampleCount: 0,
        ),
        supplyInsight: const CooperativeSupplyInsight(
          forecastedDailyAverage: 0.0,
          activeWorkerSupply: 0,
          capacityRatio: 1.0,
          status: SupplyGapStatus.insufficientData,
          recommendationText: 'Insufficient historical data available for reliable demand forecasting.',
        ),
        generatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<CooperativeSupplyInsight> getCapacityGapInsight({
    String? serviceId,
    String serviceName = 'All Services',
    String locationKey = 'All',
    int horizonDays = DemandForecastConfig.defaultHorizonDays,
    int? activeWorkerCountOverride,
  }) async {
    final result = await getForecast(
      serviceId: serviceId,
      serviceName: serviceName,
      locationKey: locationKey,
      horizonDays: horizonDays,
    );

    if (activeWorkerCountOverride != null) {
      return _engine.computeSupplyInsight(
        forecasts: result.forecasts,
        activeWorkerSupply: activeWorkerCountOverride,
        historicalDaysCount: result.historicalPoints.length,
      );
    }

    return result.supplyInsight ??
        const CooperativeSupplyInsight(
          forecastedDailyAverage: 0.0,
          activeWorkerSupply: 0,
          capacityRatio: 1.0,
          status: SupplyGapStatus.insufficientData,
          recommendationText: 'No capacity insight available.',
        );
  }

  @override
  Future<Map<String, dynamic>> getForecastingAnalyticsSummary({
    String? serviceId,
    String? locationKey,
  }) async {
    try {
      final comparisons = await _repository.getModelComparison(
        serviceId: serviceId,
        locationKey: locationKey,
      );

      final primaryMetrics = comparisons['Primary (Holt-Winters)'];

      return {
        'modelVersion': DemandForecastConfig.defaultModelVersion,
        'modelName': 'Holt-Winters Additive Exponential Smoothing',
        'defaultHorizonDays': DemandForecastConfig.defaultHorizonDays,
        'minHistoryDays': DemandForecastConfig.minHistoricalDaysRequired,
        'baselines': [
          'Naive (t-1)',
          '7-Day Moving Average',
          'Seasonal Naive (t-7)',
        ],
        'mae': primaryMetrics?.mae ?? 0.0,
        'rmse': primaryMetrics?.rmse ?? 0.0,
        'mape': primaryMetrics?.mape ?? 0.0,
        'status': 'Active & Operational',
      };
    } catch (e) {
      debugPrint('[DemandForecastService] Analytics summary error: $e');
      return {
        'modelVersion': DemandForecastConfig.defaultModelVersion,
        'modelName': 'Holt-Winters Additive',
        'defaultHorizonDays': DemandForecastConfig.defaultHorizonDays,
        'status': 'Standby',
      };
    }
  }
}
