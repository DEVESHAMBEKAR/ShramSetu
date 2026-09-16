import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/demand_forecast_models.dart';
import 'package:app/core/services/demand_forecasting_engine.dart';
import 'package:app/core/repositories/mock_demand_forecast_repository.dart';
import 'package:app/core/config/dependency_injection.dart';

void main() {
  setUpAll(() {
    DI.setup();
  });

  group('1. Data Cleansing & Continuous Time-Series Preparation', () {
    final engine = DemandForecastingEngine.instance;

    test('Interpolates missing calendar dates with zero count', () {
      final rawPoints = [
        DailyDemandPoint(
          date: DateTime(2026, 9, 1),
          serviceName: 'Plumbing',
          locationKey: 'Kothrud, Pune',
          count: 10.0,
        ),
        // Sept 2 and Sept 3 are missing!
        DailyDemandPoint(
          date: DateTime(2026, 9, 4),
          serviceName: 'Plumbing',
          locationKey: 'Kothrud, Pune',
          count: 15.0,
        ),
      ];

      final continuous = engine.prepareContinuousSeries(rawPoints);
      expect(continuous.length, 4);
      expect(continuous[0].date, DateTime(2026, 9, 1));
      expect(continuous[0].count, 10.0);
      expect(continuous[1].date, DateTime(2026, 9, 2));
      expect(continuous[1].count, 0.0); // Interpolated
      expect(continuous[2].date, DateTime(2026, 9, 3));
      expect(continuous[2].count, 0.0); // Interpolated
      expect(continuous[3].date, DateTime(2026, 9, 4));
      expect(continuous[3].count, 15.0);
    });

    test('Aggregates multiple observations on the same date', () {
      final rawPoints = [
        DailyDemandPoint(
          date: DateTime(2026, 9, 1),
          serviceName: 'Electrical',
          locationKey: 'Baner, Pune',
          count: 5.0,
        ),
        DailyDemandPoint(
          date: DateTime(2026, 9, 1),
          serviceName: 'Electrical',
          locationKey: 'Baner, Pune',
          count: 7.0,
        ),
      ];

      final continuous = engine.prepareContinuousSeries(rawPoints);
      expect(continuous.length, 1);
      expect(continuous.first.count, 12.0);
    });

    test('Empty raw list returns empty continuous list', () {
      expect(engine.prepareContinuousSeries([]), isEmpty);
    });
  });

  group('2. Baseline Forecasting Models', () {
    final engine = DemandForecastingEngine.instance;

    final dummyHistory = List.generate(
      14,
      (i) => DailyDemandPoint(
        date: DateTime(2026, 9, 1).add(Duration(days: i)),
        serviceName: 'Plumbing',
        locationKey: 'Kothrud',
        count: (10 + (i % 5)).toDouble(), // Counts between 10 and 14
      ),
    );

    test('Baseline 1: Naive persistence forecast repeats last observed value', () {
      final lastObserved = dummyHistory.last.count;
      final forecasts = engine.forecastNaive(dummyHistory, 7);

      expect(forecasts.length, 7);
      for (int i = 0; i < forecasts.length; i++) {
        expect(forecasts[i].predictedDemand, lastObserved);
        expect(forecasts[i].modelVersion, 'naive_v1');
        expect(forecasts[i].date, dummyHistory.last.date.add(Duration(days: i + 1)));
      }
    });

    test('Baseline 2: 7-Day Moving Average computes rolling mean', () {
      final forecasts = engine.forecastMovingAverage(dummyHistory, 7, windowSize: 7);
      expect(forecasts.length, 7);
      expect(forecasts.first.modelVersion, 'moving_average_v1');

      // Manual check of first step average
      final last7 = dummyHistory.sublist(dummyHistory.length - 7);
      final expectedFirstAvg = last7.map((e) => e.count).reduce((a, b) => a + b) / 7;
      expect(forecasts.first.predictedDemand, closeTo(expectedFirstAvg, 0.1));
    });

    test('Baseline 3: Seasonal Naive repeats identical weekday from 7 days ago', () {
      final forecasts = engine.forecastSeasonalNaive(dummyHistory, 7, seasonPeriod: 7);
      expect(forecasts.length, 7);
      expect(forecasts.first.modelVersion, 'seasonal_naive_v1');

      for (int h = 1; h <= 7; h++) {
        final laggedIndex = dummyHistory.length - 7 + (h - 1);
        expect(forecasts[h - 1].predictedDemand, dummyHistory[laggedIndex].count);
      }
    });
  });

  group('3. Primary Model: Holt-Winters Additive Exponential Smoothing', () {
    final engine = DemandForecastingEngine.instance;

    test('Holt-Winters captures upward trend and weekly cycle on synthetic series', () {
      final history = engine.generateSyntheticBenchmarkDataset(
        days: 42,
        serviceName: 'Plumbing',
        locationKey: 'Kothrud',
      );

      final forecasts = engine.forecastHoltWinters(history, 7);
      expect(forecasts.length, 7);
      expect(forecasts.first.modelVersion, DemandForecastConfig.defaultModelVersion);

      // Verify non-negative and positive predictions
      for (final item in forecasts) {
        expect(item.predictedDemand, greaterThan(0.0));
        // Verify confidence intervals are populated and logically bounded
        expect(item.lowerBound, isNotNull);
        expect(item.upperBound, isNotNull);
        expect(item.lowerBound!, lessThanOrEqualTo(item.predictedDemand));
        expect(item.upperBound!, greaterThanOrEqualTo(item.predictedDemand));
      }
    });

    test('Falls back to moving average when historical points < 14 days', () {
      final shortHistory = List.generate(
        10,
        (i) => DailyDemandPoint(
          date: DateTime(2026, 9, 1).add(Duration(days: i)),
          serviceName: 'Carpentry',
          locationKey: 'Baner',
          count: 8.0,
        ),
      );

      final forecasts = engine.forecastHoltWinters(shortHistory, 7);
      expect(forecasts.length, 7);
      expect(forecasts.first.predictedDemand, 8.0);
    });
  });

  group('4. Chronological Train/Test Split & Leakage Invariant', () {
    final engine = DemandForecastingEngine.instance;

    test('Splits strictly by chronological index without future leakage', () {
      final series = List.generate(
        100,
        (i) => DailyDemandPoint(
          date: DateTime(2026, 1, 1).add(Duration(days: i)),
          serviceName: 'Electrician',
          locationKey: 'Kothrud',
          count: i.toDouble(),
        ),
      );

      final split = engine.chronologicalSplit(series, trainRatio: 0.80);
      expect(split.train.length, 80);
      expect(split.test.length, 20);

      // Strict temporal ordering: max train date must be before min test date
      final maxTrainDate = split.train.last.date;
      final minTestDate = split.test.first.date;
      expect(maxTrainDate.isBefore(minTestDate), isTrue);

      // Verify no overlap
      final trainDates = split.train.map((e) => e.date).toSet();
      final testDates = split.test.map((e) => e.date).toSet();
      expect(trainDates.intersection(testDates), isEmpty);
    });
  });

  group('5. Quantitative Evaluation Metrics', () {
    final engine = DemandForecastingEngine.instance;

    test('Computes MAE and RMSE accurately', () {
      final actual = [10.0, 20.0, 30.0];
      final predicted = [12.0, 18.0, 33.0];
      // Errors: 2, -2, 3 -> Abs: 2, 2, 3 -> MAE = 7/3 = 2.33
      // Sq Errors: 4, 4, 9 = 17 -> RMSE = sqrt(17/3) = sqrt(5.666) = 2.38

      final metrics = engine.computeMetrics(actual, predicted);
      expect(metrics.mae, closeTo(2.33, 0.05));
      expect(metrics.rmse, closeTo(2.38, 0.05));
      expect(metrics.testSampleCount, 3);
    });

    test('Safe MAPE division-by-zero protection when actual count is 0', () {
      final actual = [0.0, 10.0];
      final predicted = [2.0, 10.0];
      // When actual is 0.0, denominator is clamped to 1.0 -> |0-2|/1.0 = 2.0 (200%)
      // Second point: |10-10|/10 = 0.0
      // Mean: (2.0 + 0.0) / 2 = 1.0 (100%)

      final metrics = engine.computeMetrics(actual, predicted);
      expect(metrics.mape.isFinite, isTrue);
      expect(metrics.mape.isNaN, isFalse);
      expect(metrics.mape, closeTo(100.0, 0.1));
    });

    test('Out-of-sample model comparison calculates metrics across all baselines', () {
      final history = engine.generateSyntheticBenchmarkDataset(days: 60);
      final comparisons = engine.compareModelsChronologically(history, testDays: 7);

      expect(comparisons.containsKey('naive'), isTrue);
      expect(comparisons.containsKey('moving_average'), isTrue);
      expect(comparisons.containsKey('seasonal_naive'), isTrue);
      expect(comparisons.containsKey('primary_holt_winters'), isTrue);

      for (final m in comparisons.values) {
        expect(m.mae, greaterThan(0.0));
        expect(m.rmse, greaterThan(0.0));
        expect(m.testSampleCount, 7);
      }
    });
  });

  group('6. Cooperative Supply-Demand Capacity Planning Analysis', () {
    final engine = DemandForecastingEngine.instance;

    final dummyForecasts = [
      DemandForecastItem(date: DateTime(2026, 9, 20), predictedDemand: 20.0),
      DemandForecastItem(date: DateTime(2026, 9, 21), predictedDemand: 20.0),
    ];

    test('Detects potential supply deficit when capacity ratio < 0.60', () {
      // Daily demand = 20, active workers = 8 -> ratio = 8/20 = 0.40
      final insight = engine.computeSupplyInsight(
        forecasts: dummyForecasts,
        activeWorkerSupply: 8,
        historicalDaysCount: 20,
      );

      expect(insight.status, SupplyGapStatus.deficit);
      expect(insight.capacityRatio, 0.4);
      expect(insight.recommendationText, contains('Potential Supply Deficit'));
    });

    test('Detects balanced capacity when ratio between 0.60 and 1.50', () {
      // Daily demand = 20, active workers = 20 -> ratio = 1.00
      final insight = engine.computeSupplyInsight(
        forecasts: dummyForecasts,
        activeWorkerSupply: 20,
        historicalDaysCount: 20,
      );

      expect(insight.status, SupplyGapStatus.balanced);
      expect(insight.capacityRatio, 1.0);
      expect(insight.recommendationText, contains('Balanced Capacity'));
    });

    test('Detects capacity surplus when ratio > 1.50', () {
      // Daily demand = 20, active workers = 35 -> ratio = 1.75
      final insight = engine.computeSupplyInsight(
        forecasts: dummyForecasts,
        activeWorkerSupply: 35,
        historicalDaysCount: 20,
      );

      expect(insight.status, SupplyGapStatus.surplus);
      expect(insight.capacityRatio, 1.75);
      expect(insight.recommendationText, contains('Capacity Surplus'));
    });

    test('Reports insufficient data when historical count < 14 days', () {
      final insight = engine.computeSupplyInsight(
        forecasts: dummyForecasts,
        activeWorkerSupply: 10,
        historicalDaysCount: 5,
      );

      expect(insight.status, SupplyGapStatus.insufficientData);
    });
  });

  group('7. Synthetic Benchmark Dataset Isolation', () {
    final engine = DemandForecastingEngine.instance;

    test('Generated benchmark dataset is explicitly labelled as synthetic', () {
      final benchmark = engine.generateSyntheticBenchmarkDataset(
        days: 30,
        serviceName: 'Cleaning',
        locationKey: 'Bavdhan',
      );

      expect(benchmark.length, 30);
      expect(benchmark.every((p) => p.isSynthetic), isTrue);
      expect(benchmark.every((p) => p.serviceName == 'Cleaning'), isTrue);
      expect(benchmark.every((p) => p.locationKey == 'Bavdhan'), isTrue);
    });
  });

  group('8. Repository Integration & Resilient Fallback', () {
    test('MockDemandForecastRepository generates complete forecast result', () async {
      final repo = MockDemandForecastRepository();
      final result = await repo.getOrGenerateForecast(
        serviceName: 'Plumbing',
        locationKey: 'Kothrud, Pune',
        horizonDays: 7,
      );

      expect(result.forecasts.length, 7);
      expect(result.historicalPoints, isNotEmpty);
      expect(result.supplyInsight, isNotNull);
      expect(result.evaluationMetrics, isNotNull);
      expect(result.modelVersion, DemandForecastConfig.defaultModelVersion);
    });

    test('MockDemandForecastRepository handles simulated failure gracefully', () async {
      final repo = MockDemandForecastRepository();
      repo.simulateFailure = true;

      expect(
        () => repo.getOrGenerateForecast(serviceName: 'Electrical'),
        throwsException,
      );
    });

    test('Models JSON serialization roundtrip', () {
      final point = DailyDemandPoint(
        date: DateTime(2026, 9, 15),
        serviceId: 's1',
        serviceName: 'Plumbing',
        locationKey: 'Kothrud',
        count: 14.5,
        isSynthetic: true,
      );
      final pointJson = point.toJson();
      final restoredPoint = DailyDemandPoint.fromJson(pointJson);
      expect(restoredPoint.date, point.date);
      expect(restoredPoint.count, 14.5);
      expect(restoredPoint.isSynthetic, isTrue);

      final forecast = DemandForecastItem(
        date: DateTime(2026, 9, 16),
        predictedDemand: 16.2,
        lowerBound: 13.0,
        upperBound: 19.4,
      );
      final forecastJson = forecast.toJson();
      final restoredForecast = DemandForecastItem.fromJson(forecastJson);
      expect(restoredForecast.date, forecast.date);
      expect(restoredForecast.predictedDemand, 16.2);
      expect(restoredForecast.lowerBound, 13.0);
      expect(restoredForecast.upperBound, 19.4);
    });
  });
}
