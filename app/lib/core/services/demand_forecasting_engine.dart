import 'dart:math' as math;
import '../models/demand_forecast_models.dart';

/// Core analytical engine for demand time-series processing, baseline forecasting,
/// Holt-Winters additive smoothing, chronological validation, and supply-demand gap analysis.
class DemandForecastingEngine {
  static final DemandForecastingEngine instance = DemandForecastingEngine._internal();
  DemandForecastingEngine._internal();
  factory DemandForecastingEngine() => instance;

  /// Sorts historical records chronologically and fills missing calendar dates with 0.0 count
  /// to ensure a continuous time-series for seasonal lag computations.
  List<DailyDemandPoint> prepareContinuousSeries(
    List<DailyDemandPoint> rawPoints, {
    String? fallbackServiceName,
    String? fallbackLocationKey,
  }) {
    if (rawPoints.isEmpty) return [];

    // 1. Group points by date (sum counts if multiple records exist on the same date)
    final Map<DateTime, double> dateCountMap = {};
    final Map<DateTime, bool> dateSyntheticMap = {};
    String serviceName = fallbackServiceName ?? 'All Services';
    String? serviceId;
    String locationKey = fallbackLocationKey ?? 'All';

    for (final p in rawPoints) {
      serviceName = p.serviceName;
      serviceId ??= p.serviceId;
      locationKey = p.locationKey;

      final normalizedDate = DateTime(p.date.year, p.date.month, p.date.day);
      dateCountMap[normalizedDate] = (dateCountMap[normalizedDate] ?? 0.0) + p.count;
      dateSyntheticMap[normalizedDate] = p.isSynthetic;
    }

    final sortedDates = dateCountMap.keys.toList()..sort();
    if (sortedDates.isEmpty) return [];

    final startDate = sortedDates.first;
    final endDate = sortedDates.last;

    // 2. Continuous day interpolation
    final List<DailyDemandPoint> continuous = [];
    DateTime current = startDate;

    while (!current.isAfter(endDate)) {
      final count = dateCountMap[current] ?? 0.0;
      final isSynth = dateSyntheticMap[current] ?? false;

      continuous.add(DailyDemandPoint(
        date: current,
        serviceId: serviceId,
        serviceName: serviceName,
        locationKey: locationKey,
        count: count,
        isSynthetic: isSynth,
      ));

      current = current.add(const Duration(days: 1));
    }

    return continuous;
  }

  /// Baseline 1: Naive Persistence Forecast
  /// Forecast at horizon h equals the most recently observed value.
  List<DemandForecastItem> forecastNaive(
    List<DailyDemandPoint> history,
    int horizonDays, {
    String modelVersion = 'naive_v1',
  }) {
    if (history.isEmpty || horizonDays <= 0) return [];

    final lastObserved = history.last.count;
    final lastDate = history.last.date;
    final List<DemandForecastItem> items = [];

    for (int h = 1; h <= horizonDays; h++) {
      items.add(DemandForecastItem(
        date: lastDate.add(Duration(days: h)),
        predictedDemand: math.max(0.0, lastObserved),
        modelVersion: modelVersion,
      ));
    }

    return items;
  }

  /// Baseline 2: Moving Average Forecast
  /// Multi-step rolling average of the preceding windowSize observations.
  List<DemandForecastItem> forecastMovingAverage(
    List<DailyDemandPoint> history,
    int horizonDays, {
    int windowSize = 7,
    String modelVersion = 'moving_average_v1',
  }) {
    if (history.isEmpty || horizonDays <= 0) return [];

    final List<double> workingSeries = history.map((e) => e.count).toList();
    final lastDate = history.last.date;
    final List<DemandForecastItem> items = [];

    for (int h = 1; h <= horizonDays; h++) {
      final effectiveWindow = math.min(workingSeries.length, windowSize);
      final recent = workingSeries.sublist(workingSeries.length - effectiveWindow);
      final avg = recent.reduce((a, b) => a + b) / effectiveWindow;
      final roundedAvg = (avg * 10).round() / 10.0;

      workingSeries.add(roundedAvg);
      items.add(DemandForecastItem(
        date: lastDate.add(Duration(days: h)),
        predictedDemand: math.max(0.0, roundedAvg),
        modelVersion: modelVersion,
      ));
    }

    return items;
  }

  /// Baseline 3: Seasonal Naive Forecast
  /// Projects demand from the identical weekday of the preceding cycle (L = 7 days).
  List<DemandForecastItem> forecastSeasonalNaive(
    List<DailyDemandPoint> history,
    int horizonDays, {
    int seasonPeriod = 7,
    String modelVersion = 'seasonal_naive_v1',
  }) {
    if (history.isEmpty || horizonDays <= 0) return [];

    final lastDate = history.last.date;
    final List<DemandForecastItem> items = [];
    final n = history.length;

    for (int h = 1; h <= horizonDays; h++) {
      // Look back seasonPeriod steps from the forecast step
      final lagIndex = n - seasonPeriod + ((h - 1) % seasonPeriod);
      final projected = (lagIndex >= 0 && lagIndex < n)
          ? history[lagIndex].count
          : history.last.count;

      items.add(DemandForecastItem(
        date: lastDate.add(Duration(days: h)),
        predictedDemand: math.max(0.0, projected),
        modelVersion: modelVersion,
      ));
    }

    return items;
  }

  /// Primary Model: Holt-Winters Additive Exponential Smoothing (Level, Trend, Seasonality).
  /// Captures linear growth trend and 7-day cyclical variations.
  List<DemandForecastItem> forecastHoltWinters(
    List<DailyDemandPoint> history,
    int horizonDays, {
    double alpha = DemandForecastConfig.defaultAlpha,
    double beta = DemandForecastConfig.defaultBeta,
    double gamma = DemandForecastConfig.defaultGamma,
    int seasonPeriod = DemandForecastConfig.defaultSeasonLength,
    String modelVersion = DemandForecastConfig.defaultModelVersion,
  }) {
    if (history.isEmpty || horizonDays <= 0) return [];

    // If historical points are too few (< 2 * seasonPeriod = 14 days), fall back to moving average
    if (history.length < seasonPeriod * 2) {
      return forecastMovingAverage(
        history,
        horizonDays,
        windowSize: math.max(3, history.length),
        modelVersion: modelVersion,
      );
    }

    final series = history.map((e) => e.count).toList();
    final n = series.length;
    final L = seasonPeriod;

    // 1. Initialize Level and Trend from the first 2 seasons
    double level = 0.0;
    for (int i = 0; i < L; i++) {
      level += series[i];
    }
    level /= L;

    double trend = 0.0;
    for (int i = 0; i < L; i++) {
      trend += (series[i + L] - series[i]) / L;
    }
    trend /= L;

    // 2. Initialize Seasonal Indices
    final List<double> seasonals = List.filled(n + horizonDays + L, 0.0);
    for (int i = 0; i < L; i++) {
      seasonals[i] = series[i] - level;
    }

    // 3. Track Residuals for empirical prediction interval
    final List<double> residuals = [];

    // 4. In-Sample Forward Filtering
    for (int t = L; t < n; t++) {
      final y = series[t];
      final prevLevel = level;
      final prevTrend = trend;
      final sPrev = seasonals[t - L];

      // Level update
      level = alpha * (y - sPrev) + (1.0 - alpha) * (prevLevel + prevTrend);
      // Trend update
      trend = beta * (level - prevLevel) + (1.0 - beta) * prevTrend;
      // Seasonality update
      seasonals[t] = gamma * (y - level) + (1.0 - gamma) * sPrev;

      final oneStepAheadPred = prevLevel + prevTrend + sPrev;
      residuals.add(y - oneStepAheadPred);
    }

    // Compute standard deviation of residuals for confidence bounds
    double residualVariance = 1.0;
    if (residuals.isNotEmpty) {
      final meanRes = residuals.reduce((a, b) => a + b) / residuals.length;
      final sumSq = residuals.fold<double>(
        0.0,
        (acc, r) => acc + math.pow(r - meanRes, 2),
      );
      residualVariance = math.max(0.5, sumSq / residuals.length);
    }
    final residualStd = math.sqrt(residualVariance);

    // 5. Out-of-Sample Forecasting
    final lastDate = history.last.date;
    final List<DemandForecastItem> items = [];

    for (int h = 1; h <= horizonDays; h++) {
      final targetDate = lastDate.add(Duration(days: h));
      final sIndex = n + h - 1 - L * ((h - 1) ~/ L + 1);
      final seasonalComponent = (sIndex >= 0 && sIndex < seasonals.length)
          ? seasonals[sIndex]
          : 0.0;

      final pointForecast = math.max(0.0, level + h * trend + seasonalComponent);
      final roundedPoint = (pointForecast * 10).round() / 10.0;

      // 95% prediction interval: +/- 1.96 * std * sqrt(h)
      final margin = 1.96 * residualStd * math.sqrt(h);
      final lower = math.max(0.0, ((roundedPoint - margin) * 10).round() / 10.0);
      final upper = ((roundedPoint + margin) * 10).round() / 10.0;

      items.add(DemandForecastItem(
        date: targetDate,
        predictedDemand: roundedPoint,
        lowerBound: lower,
        upperBound: upper,
        modelVersion: modelVersion,
      ));
    }

    return items;
  }

  /// Splits a continuous series chronologically without future observation leakage.
  ({List<DailyDemandPoint> train, List<DailyDemandPoint> test}) chronologicalSplit(
    List<DailyDemandPoint> series, {
    double trainRatio = 0.80,
  }) {
    if (series.isEmpty) {
      return (train: <DailyDemandPoint>[], test: <DailyDemandPoint>[]);
    }

    final splitIndex = (series.length * trainRatio).floor().clamp(1, series.length - 1);
    final train = series.sublist(0, splitIndex);
    final test = series.sublist(splitIndex);

    return (train: train, test: test);
  }

  /// Calculates MAE, RMSE, and MAPE with safe zero-division guard.
  ForecastEvaluationMetrics computeMetrics(
    List<double> actual,
    List<double> predicted, {
    String modelName = 'Holt-Winters Additive',
  }) {
    final n = math.min(actual.length, predicted.length);
    if (n == 0) {
      return ForecastEvaluationMetrics(
        mae: 0.0,
        rmse: 0.0,
        mape: 0.0,
        testSampleCount: 0,
        modelName: modelName,
      );
    }

    double sumAbsError = 0.0;
    double sumSqError = 0.0;
    double sumPctError = 0.0;

    for (int i = 0; i < n; i++) {
      final err = actual[i] - predicted[i];
      final absErr = err.abs();

      sumAbsError += absErr;
      sumSqError += err * err;

      // Safe MAPE guard: if actual is 0, denominator is protected with 1.0 to avoid division by zero
      final denom = math.max(actual[i], 1.0);
      sumPctError += (absErr / denom);
    }

    final mae = (sumAbsError / n * 100).round() / 100.0;
    final rmse = (math.sqrt(sumSqError / n) * 100).round() / 100.0;
    final mape = ((sumPctError / n) * 100.0 * 10).round() / 10.0;

    return ForecastEvaluationMetrics(
      mae: mae,
      rmse: rmse,
      mape: mape,
      testSampleCount: n,
      modelName: modelName,
    );
  }

  /// Evaluates models comparatively using out-of-sample chronological test set.
  Map<String, ForecastEvaluationMetrics> compareModelsChronologically(
    List<DailyDemandPoint> continuousSeries, {
    int testDays = 7,
  }) {
    if (continuousSeries.length < testDays + DemandForecastConfig.minHistoricalDaysRequired) {
      return {};
    }

    final train = continuousSeries.sublist(0, continuousSeries.length - testDays);
    final test = continuousSeries.sublist(continuousSeries.length - testDays);
    final actual = test.map((e) => e.count).toList();

    // 1. Naive
    final naiveForecasts = forecastNaive(train, testDays).map((e) => e.predictedDemand).toList();
    final naiveMetrics = computeMetrics(actual, naiveForecasts, modelName: 'Naive (t-1)');

    // 2. Moving Average
    final maForecasts = forecastMovingAverage(train, testDays).map((e) => e.predictedDemand).toList();
    final maMetrics = computeMetrics(actual, maForecasts, modelName: '7-Day Moving Avg');

    // 3. Seasonal Naive
    final sNaiveForecasts = forecastSeasonalNaive(train, testDays).map((e) => e.predictedDemand).toList();
    final sNaiveMetrics = computeMetrics(actual, sNaiveForecasts, modelName: 'Seasonal Naive (t-7)');

    // 4. Holt-Winters Primary
    final hwForecasts = forecastHoltWinters(train, testDays).map((e) => e.predictedDemand).toList();
    final hwMetrics = computeMetrics(actual, hwForecasts, modelName: 'Holt-Winters Additive');

    return {
      'naive': naiveMetrics,
      'moving_average': maMetrics,
      'seasonal_naive': sNaiveMetrics,
      'primary_holt_winters': hwMetrics,
    };
  }

  /// Computes cooperative capacity planning insight comparing predicted demand with active registered worker supply.
  CooperativeSupplyInsight computeSupplyInsight({
    required List<DemandForecastItem> forecasts,
    required int activeWorkerSupply,
    required int historicalDaysCount,
  }) {
    if (forecasts.isEmpty || historicalDaysCount < DemandForecastConfig.minHistoricalDaysRequired) {
      return const CooperativeSupplyInsight(
        forecastedDailyAverage: 0.0,
        activeWorkerSupply: 0,
        capacityRatio: 1.0,
        status: SupplyGapStatus.insufficientData,
        recommendationText: 'Insufficient historical data for reliable capacity planning (minimum 14 days required).',
      );
    }

    final totalForecast = forecasts.fold<double>(0.0, (acc, item) => acc + item.predictedDemand);
    final dailyAvg = (totalForecast / forecasts.length * 10).round() / 10.0;

    final ratio = dailyAvg > 0
        ? ((activeWorkerSupply / dailyAvg) * 100).round() / 100.0
        : 1.0;

    final SupplyGapStatus status;
    final String recommendation;

    if (ratio < 0.60) {
      status = SupplyGapStatus.deficit;
      recommendation = 'Potential Supply Deficit: Expected demand ($dailyAvg/day) exceeds current artisan coverage ($activeWorkerSupply active). Recommend mobilizing apprentice roster or scheduling overtime.';
    } else if (ratio > 1.50) {
      status = SupplyGapStatus.surplus;
      recommendation = 'Capacity Surplus: Available artisan supply ($activeWorkerSupply) significantly exceeds projected demand ($dailyAvg/day). Consider cross-trade training or marketing outreach.';
    } else {
      status = SupplyGapStatus.balanced;
      recommendation = 'Balanced Capacity: Verified artisan supply ($activeWorkerSupply) closely matches forecasted daily demand ($dailyAvg/day). Standard scheduling sufficient.';
    }

    return CooperativeSupplyInsight(
      forecastedDailyAverage: dailyAvg,
      activeWorkerSupply: activeWorkerSupply,
      capacityRatio: ratio,
      status: status,
      recommendationText: recommendation,
    );
  }

  /// Generates a reproducible, strictly isolated synthetic benchmark dataset for offline research and testing.
  /// Clearly labelled with isSynthetic: true so it is never confused with production data.
  List<DailyDemandPoint> generateSyntheticBenchmarkDataset({
    int days = 60,
    String? serviceId,
    String serviceName = 'Plumbing',
    String locationKey = 'Kothrud, Pune',
    DateTime? anchorDate,
  }) {
    final now = anchorDate ?? DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: days));
    final List<DailyDemandPoint> points = [];

    // Deterministic pseudo-random seasonal pattern
    for (int d = 0; d < days; d++) {
      final date = startDate.add(Duration(days: d));
      final weekday = date.weekday; // 1 = Mon, 7 = Sun

      // Baseline: 12 bookings
      double demand = 12.0;

      // Upward trend: +0.06 per day
      demand += d * 0.06;

      // Weekend surge (Saturday & Sunday peak demand)
      if (weekday == DateTime.saturday) {
        demand += 5.5;
      } else if (weekday == DateTime.sunday) {
        demand += 6.0;
      } else if (weekday == DateTime.friday) {
        demand += 2.0;
      } else if (weekday == DateTime.wednesday) {
        demand -= 1.5; // Mid-week lull
      }

      // Small deterministic pseudo-variance
      final pseudoNoise = math.sin(d * 1.3) * 1.2;
      demand = math.max(1.0, (demand + pseudoNoise).roundToDouble());

      points.add(DailyDemandPoint(
        date: date,
        serviceId: serviceId ?? '22222222-2222-2222-2222-222222222222',
        serviceName: serviceName,
        locationKey: locationKey,
        count: demand,
        isSynthetic: true,
      ));
    }

    return points;
  }
}
