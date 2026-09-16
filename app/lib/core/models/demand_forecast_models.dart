import 'package:flutter/foundation.dart';

/// Single historical daily observation of realized demand for a service and location.
@immutable
class DailyDemandPoint {
  final DateTime date;
  final String? serviceId;
  final String serviceName;
  final String locationKey;
  final double count;
  final bool isSynthetic;

  const DailyDemandPoint({
    required this.date,
    this.serviceId,
    required this.serviceName,
    required this.locationKey,
    required this.count,
    this.isSynthetic = false,
  });

  factory DailyDemandPoint.fromJson(Map<String, dynamic> json) {
    final rawDate = json['demand_date'] ?? json['date'];
    final parsedDate = rawDate is DateTime
        ? rawDate
        : DateTime.parse(rawDate.toString().split('T').first);

    return DailyDemandPoint(
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      serviceId: json['service_id']?.toString(),
      serviceName: json['service_name']?.toString() ?? 'All Services',
      locationKey: json['location_key']?.toString() ?? 'All',
      count: (json['booking_count'] ?? json['count'] as num?)?.toDouble() ?? 0.0,
      isSynthetic: json['is_synthetic'] == true || json['data_source'] == 'synthetic_benchmark',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String().split('T').first,
      'service_id': serviceId,
      'service_name': serviceName,
      'location_key': locationKey,
      'count': count,
      'is_synthetic': isSynthetic,
    };
  }

  DailyDemandPoint copyWith({
    DateTime? date,
    String? serviceId,
    String? serviceName,
    String? locationKey,
    double? count,
    bool? isSynthetic,
  }) {
    return DailyDemandPoint(
      date: date ?? this.date,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      locationKey: locationKey ?? this.locationKey,
      count: count ?? this.count,
      isSynthetic: isSynthetic ?? this.isSynthetic,
    );
  }

  @override
  String toString() =>
      'DailyDemandPoint(${date.toIso8601String().split('T').first}, $serviceName, $locationKey, count: $count, synthetic: $isSynthetic)';
}

/// A forecasted future point for a specific date with optional uncertainty bounds.
@immutable
class DemandForecastItem {
  final DateTime date;
  final double predictedDemand;
  final double? lowerBound;
  final double? upperBound;
  final String modelVersion;

  const DemandForecastItem({
    required this.date,
    required this.predictedDemand,
    this.lowerBound,
    this.upperBound,
    this.modelVersion = DemandForecastConfig.defaultModelVersion,
  });

  factory DemandForecastItem.fromJson(Map<String, dynamic> json) {
    final rawDate = json['forecast_date'] ?? json['date'];
    final parsedDate = rawDate is DateTime
        ? rawDate
        : DateTime.parse(rawDate.toString().split('T').first);

    return DemandForecastItem(
      date: DateTime(parsedDate.year, parsedDate.month, parsedDate.day),
      predictedDemand: (json['predicted_demand'] as num?)?.toDouble() ?? 0.0,
      lowerBound: (json['lower_bound'] as num?)?.toDouble(),
      upperBound: (json['upper_bound'] as num?)?.toDouble(),
      modelVersion: json['model_version']?.toString() ?? DemandForecastConfig.defaultModelVersion,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'forecast_date': date.toIso8601String().split('T').first,
      'predicted_demand': predictedDemand,
      'lower_bound': lowerBound,
      'upper_bound': upperBound,
      'model_version': modelVersion,
    };
  }
}

/// Quantitative evaluation metrics for research and model comparison.
@immutable
class ForecastEvaluationMetrics {
  final double mae;
  final double rmse;
  final double mape;
  final int testSampleCount;
  final String modelName;

  const ForecastEvaluationMetrics({
    required this.mae,
    required this.rmse,
    required this.mape,
    required this.testSampleCount,
    this.modelName = 'Holt-Winters Additive',
  });

  factory ForecastEvaluationMetrics.fromJson(Map<String, dynamic> json) {
    return ForecastEvaluationMetrics(
      mae: (json['mae'] as num?)?.toDouble() ?? 0.0,
      rmse: (json['rmse'] as num?)?.toDouble() ?? 0.0,
      mape: (json['mape'] as num?)?.toDouble() ?? 0.0,
      testSampleCount: (json['test_sample_count'] as num?)?.toInt() ?? 0,
      modelName: json['model_name']?.toString() ?? 'Holt-Winters Additive',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mae': mae,
      'rmse': rmse,
      'mape': mape,
      'test_sample_count': testSampleCount,
      'model_name': modelName,
    };
  }
}

/// Status of cooperative capacity balance.
enum SupplyGapStatus {
  deficit,
  balanced,
  surplus,
  insufficientData;

  String get label {
    switch (this) {
      case SupplyGapStatus.deficit:
        return 'Potential Supply Deficit';
      case SupplyGapStatus.balanced:
        return 'Balanced Capacity';
      case SupplyGapStatus.surplus:
        return 'Capacity Surplus';
      case SupplyGapStatus.insufficientData:
        return 'Insufficient Data';
    }
  }
}

/// Analytical indicator comparing predicted demand with active registered worker supply.
@immutable
class CooperativeSupplyInsight {
  final double forecastedDailyAverage;
  final int activeWorkerSupply;
  final double capacityRatio;
  final SupplyGapStatus status;
  final String recommendationText;

  const CooperativeSupplyInsight({
    required this.forecastedDailyAverage,
    required this.activeWorkerSupply,
    required this.capacityRatio,
    required this.status,
    required this.recommendationText,
  });

  factory CooperativeSupplyInsight.fromJson(Map<String, dynamic> json) {
    return CooperativeSupplyInsight(
      forecastedDailyAverage: (json['forecasted_daily_average'] as num?)?.toDouble() ?? 0.0,
      activeWorkerSupply: (json['active_worker_supply'] as num?)?.toInt() ?? 0,
      capacityRatio: (json['capacity_ratio'] as num?)?.toDouble() ?? 1.0,
      status: SupplyGapStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SupplyGapStatus.insufficientData,
      ),
      recommendationText: json['recommendation_text']?.toString() ?? 'Standard operations.',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'forecasted_daily_average': forecastedDailyAverage,
      'active_worker_supply': activeWorkerSupply,
      'capacity_ratio': capacityRatio,
      'status': status.name,
      'recommendation_text': recommendationText,
    };
  }
}

/// Aggregate result payload returned from the forecasting service to the admin repository.
@immutable
class DemandForecastResult {
  final String? serviceId;
  final String serviceName;
  final String locationKey;
  final List<DailyDemandPoint> historicalPoints;
  final List<DemandForecastItem> forecasts;
  final String modelVersion;
  final DateTime generatedAt;
  final bool isSynthetic;
  final ForecastEvaluationMetrics? evaluationMetrics;
  final CooperativeSupplyInsight? supplyInsight;

  const DemandForecastResult({
    this.serviceId,
    required this.serviceName,
    required this.locationKey,
    required this.historicalPoints,
    required this.forecasts,
    this.modelVersion = DemandForecastConfig.defaultModelVersion,
    required this.generatedAt,
    this.isSynthetic = false,
    this.evaluationMetrics,
    this.supplyInsight,
  });

  factory DemandForecastResult.fromJson(Map<String, dynamic> json) {
    final historyList = (json['historical_points'] as List? ?? [])
        .map((e) => DailyDemandPoint.fromJson(e as Map<String, dynamic>))
        .toList();

    final forecastList = (json['forecasts'] as List? ?? [])
        .map((e) => DemandForecastItem.fromJson(e as Map<String, dynamic>))
        .toList();

    return DemandForecastResult(
      serviceId: json['service_id']?.toString(),
      serviceName: json['service_name']?.toString() ?? 'All Services',
      locationKey: json['location_key']?.toString() ?? 'All',
      historicalPoints: historyList,
      forecasts: forecastList,
      modelVersion: json['model_version']?.toString() ?? DemandForecastConfig.defaultModelVersion,
      generatedAt: json['generated_at'] != null
          ? DateTime.parse(json['generated_at'].toString())
          : DateTime.now(),
      isSynthetic: json['is_synthetic'] == true,
      evaluationMetrics: json['evaluation_metrics'] != null
          ? ForecastEvaluationMetrics.fromJson(json['evaluation_metrics'] as Map<String, dynamic>)
          : null,
      supplyInsight: json['supply_insight'] != null
          ? CooperativeSupplyInsight.fromJson(json['supply_insight'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'service_id': serviceId,
      'service_name': serviceName,
      'location_key': locationKey,
      'historical_points': historicalPoints.map((e) => e.toJson()).toList(),
      'forecasts': forecasts.map((e) => e.toJson()).toList(),
      'model_version': modelVersion,
      'generated_at': generatedAt.toIso8601String(),
      'is_synthetic': isSynthetic,
      'evaluation_metrics': evaluationMetrics?.toJson(),
      'supply_insight': supplyInsight?.toJson(),
    };
  }
}

/// Static configuration constants for Demand Forecasting.
class DemandForecastConfig {
  static const String defaultModelVersion = 'demand_forecast_v1';
  static const int defaultHorizonDays = 7;
  static const int extendedHorizonDays = 14;
  static const int minHistoricalDaysRequired = 14;
  static const double defaultAlpha = 0.30;
  static const double defaultBeta = 0.10;
  static const double defaultGamma = 0.20;
  static const int defaultSeasonLength = 7;
}
