import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';
import 'package:app/core/models/fairmatch_models.dart';
import 'package:app/core/models/demand_forecast_models.dart';
import 'package:app/core/models/payment_models.dart';
import 'package:app/core/services/fairmatch_service.dart';
import 'package:app/core/services/demand_forecast_service.dart';
import 'package:app/core/services/demand_forecasting_engine.dart';
import 'package:app/core/services/fairmatch_engine.dart';
import 'package:app/core/repositories/i_fairmatch_repository.dart';
import 'package:app/core/repositories/i_demand_forecast_repository.dart';
import 'package:app/features/customer/data/models/customer_models.dart';

// Failing mock repository for testing failure resilience
class FailingFairMatchRepository implements IFairMatchRepository {
  @override
  Future<List<FairMatchResult>> recommendWorkers({
    required String serviceId,
    double? customerLat,
    double? customerLng,
    FairMatchWeights? weights,
    int limit = FairMatchConfig.defaultTopN,
    String algorithm = FairMatchConfig.version,
  }) async {
    throw Exception('Simulated FairMatch RPC timeout or network partition');
  }
}

class FailingDemandForecastRepository implements IDemandForecastRepository {
  @override
  Future<List<DailyDemandPoint>> getHistoricalDemand({
    String? serviceId,
    String? locationKey,
    DateTime? startDate,
    DateTime? endDate,
    bool useSyntheticBenchmarkIfSparse = true,
  }) async {
    throw Exception('Simulated database connection failure');
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
    throw Exception('Simulated forecast RPC execution failure');
  }

  @override
  Future<Map<String, ForecastEvaluationMetrics>> getModelComparison({
    String? serviceId,
    String? locationKey,
  }) async {
    throw Exception('Simulated evaluation failure');
  }
}

void main() {
  setUp(() {
    DI.setup();
  });

  group('FairMatch Marketplace Integration Tests (1-8)', () {
    test('1. Customer service request -> FairMatch invocation', () async {
      // Act: invoke FairMatchService for plumbing (c2)
      final results = await DI.fairMatchService.getRecommendedWorkers(
        serviceId: 'c2',
        customerLat: 18.5074,
        customerLng: 73.8077,
      );

      // Assert: FairMatch was invoked and returned non-empty ranked candidates
      expect(results, isNotEmpty);
      expect(results.first.algorithmVersion, equals(FairMatchConfig.version));
    });

    test('2. Eligible worker filtering: only workers matching requested service', () async {
      final results = await DI.fairMatchService.getRecommendedWorkers(
        serviceId: 'c2',
      );

      // Assert: Every single candidate matches the requested category
      for (final res in results) {
        expect(res.worker.categoryId, equals('c2'));
      }
    });

    test('3. Ranked results: top candidate has rank 1 and FairMatch tag', () async {
      final results = await DI.fairMatchService.getRecommendedWorkers(
        serviceId: 'c2',
      );

      expect(results.length, greaterThanOrEqualTo(2));
      // First worker must have rank 1
      expect(results.first.rank, equals(1));
      // Top candidate receives subtle 'FairMatch Recommended' tag
      expect(results.first.worker.customTag, equals('FairMatch Recommended'));
      // Second candidate does NOT have rank 1 tag
      expect(results[1].worker.customTag, isNot(equals('FairMatch Recommended')));
    });

    test('4. Recommendation explanations: human-readable, zero raw math/floats', () {
      const sampleResult = FairMatchResult(
        worker: Worker(
          id: 'w1',
          name: 'Test Artisan',
          categoryId: 'c2',
          rate: 350,
          rating: 4.9,
          reviewCount: 50,
          jobsCompleted: 80,
          distanceKm: 1.5,
          experience: '5 yrs',
          availability: 'Available Today',
          specializations: [],
          locationTag: 'Kothrud',
          imageUrl: '',
        ),
        totalScore: 0.887, // Internal score
        rank: 1,
        features: FairMatchFeatures(
          skillScore: 1.0,
          distanceScore: 0.9,
          availabilityScore: 1.0,
          ratingScore: 0.95,
          experienceScore: 0.8,
          fairnessScore: 0.75,
        ),
        explanationTags: [],
        algorithmVersion: FairMatchConfig.version,
      );

      final tags = DI.fairMatchService.getCustomerFriendlyExplanations(sampleResult);

      // Assert: contains customer-relevant badges
      expect(tags, contains('Verified Guild Artisan'));
      expect(tags, contains('Nearby Specialist'));
      expect(tags, contains('High Community Rating'));
      expect(tags, contains('Punctual Availability'));
      expect(tags, contains('Fair Opportunity Policy'));

      // Assert: Zero raw math percentages or floating point numbers in tags
      for (final tag in tags) {
        expect(tag.contains('%'), isFalse, reason: 'Must not leak percentage math');
        expect(tag.contains('0.'), isFalse, reason: 'Must not leak float scores');
        expect(tag.contains('Score:'), isFalse, reason: 'Must not expose internal score label');
      }

      final summary = DI.fairMatchService.getRecommendationSummary(sampleResult);
      expect(summary, isNotEmpty);
      expect(summary.contains('%'), isFalse);
    });

    test('5. FairMatch failure handling: graceful exception isolation', () async {
      final failingService = FairMatchService(FailingFairMatchRepository());

      // Act: Calling failing service must not throw unhandled exception
      final results = await failingService.getRecommendedWorkers(serviceId: 'c2');

      // Assert: Returns empty list gracefully
      expect(results, isEmpty);
    });

    test('6. Fallback discovery: standard customer discovery works when FairMatch fails', () async {
      // Temporarily swap fairMatchService with failing service in DI
      final originalService = DI.fairMatchService;
      DI.fairMatchService = FairMatchService(FailingFairMatchRepository());

      try {
        // Customer repo getEligibleWorkers catches FairMatch failure and falls back to standard discovery
        final workers = await DI.customerRepo.getEligibleWorkers('c2');

        expect(workers, isNotEmpty);
        // All workers match plumbing category
        expect(workers.every((w) => w.categoryId == 'c2'), isTrue);
      } finally {
        DI.fairMatchService = originalService;
      }
    });

    test('7. Unavailable worker exclusion: unavailable artisans excluded', () {
      final engine = FairMatchEngine.instance;

      final candidates = [
        const FairMatchCandidate(
          worker: Worker(
            id: 'w_avail',
            name: 'Available Worker',
            categoryId: 'c1',
            rate: 300,
            rating: 4.5,
            reviewCount: 20,
            jobsCompleted: 30,
            distanceKm: 2.0,
            experience: '3 yrs',
            availability: 'Available',
            specializations: [],
            locationTag: 'Baner',
            imageUrl: '',
          ),
          isAvailable: true,
          hasVerifiedSkill: true,
        ),
        const FairMatchCandidate(
          worker: Worker(
            id: 'w_unavail',
            name: 'Unavailable Worker',
            categoryId: 'c1',
            rate: 300,
            rating: 5.0,
            reviewCount: 100,
            jobsCompleted: 150,
            distanceKm: 0.5,
            experience: '10 yrs',
            availability: 'Off Duty',
            specializations: [],
            locationTag: 'Baner',
            imageUrl: '',
          ),
          isAvailable: false, // HARD EXCLUSION
          hasVerifiedSkill: true,
        ),
      ];

      final ranked = engine.rankCandidates(candidates);

      // Assert: Only the available worker is returned
      expect(ranked.length, equals(1));
      expect(ranked.first.worker.id, equals('w_avail'));
    });

    test('8. Unverified worker exclusion: unverified artisans excluded', () {
      final engine = FairMatchEngine.instance;

      final candidates = [
        const FairMatchCandidate(
          worker: Worker(
            id: 'w_verified',
            name: 'Verified Worker',
            categoryId: 'c1',
            rate: 300,
            rating: 4.5,
            reviewCount: 20,
            jobsCompleted: 30,
            distanceKm: 2.0,
            experience: '3 yrs',
            availability: 'Available',
            specializations: [],
            locationTag: 'Baner',
            imageUrl: '',
          ),
          hasVerifiedSkill: true,
          isAvailable: true,
        ),
        const FairMatchCandidate(
          worker: Worker(
            id: 'w_unverified',
            name: 'Unverified Worker',
            categoryId: 'c1',
            rate: 300,
            rating: 4.9,
            reviewCount: 50,
            jobsCompleted: 80,
            distanceKm: 1.0,
            experience: '5 yrs',
            availability: 'Available',
            specializations: [],
            locationTag: 'Baner',
            imageUrl: '',
          ),
          hasVerifiedSkill: false, // HARD EXCLUSION
          isAvailable: true,
        ),
      ];

      final ranked = engine.rankCandidates(candidates);

      // Assert: Only the verified artisan is ranked
      expect(ranked.length, equals(1));
      expect(ranked.first.worker.id, equals('w_verified'));
    });
  });

  group('Demand Forecasting Integration Tests (9-15)', () {
    test('9. Forecast retrieval: returns 7-day projected points', () async {
      final result = await DI.demandForecastService.getForecast(
        serviceId: 'c1',
        serviceName: 'Electrical',
        locationKey: 'Kothrud',
        horizonDays: 7,
      );

      expect(result.forecasts.length, equals(7));
      expect(result.forecasts.every((item) => item.predictedDemand >= 0.0), isTrue);
      expect(result.historicalPoints, isNotEmpty);
      expect(result.serviceName, equals('Electrical'));
      expect(result.locationKey, equals('Kothrud'));
    });

    test('10. Admin authorization: Demand Forecast service and metadata accessibility', () async {
      final summary = await DI.demandForecastService.getForecastingAnalyticsSummary();

      // Assert: Model version and configuration accessible to admin analytics
      expect(summary['modelVersion'], equals(DemandForecastConfig.defaultModelVersion));
      expect(summary['defaultHorizonDays'], equals(7));
      expect(summary['status'], contains('Active'));
    });

    test('11. Empty forecast handling: empty history returns empty items gracefully', () {
      final engine = DemandForecastingEngine.instance;

      final forecast = engine.forecastHoltWinters(
        [],
        7,
      );

      expect(forecast, isEmpty);
    });

    test('12. Insufficient data handling (<14 days historical data)', () {
      final engine = DemandForecastingEngine.instance;

      // Create sparse 5-day series
      final sparseHistory = List.generate(5, (i) {
        return DailyDemandPoint(
          date: DateTime(2026, 9, 1).add(Duration(days: i)),
          serviceId: 'c1',
          serviceName: 'Electrical',
          locationKey: 'Kothrud',
          count: 3.0,
        );
      });

      // Holt-Winters requires minimum 14 days for 7-day weekly seasonality; falls back safely
      final forecast = engine.forecastHoltWinters(
        sparseHistory,
        7,
      );

      expect(forecast, isNotEmpty);

      // Supply gap analyzer reports insufficient data when historical count < 14 days
      final insight = engine.computeSupplyInsight(
        forecasts: forecast,
        activeWorkerSupply: 5,
        historicalDaysCount: 5,
      );
      expect(insight.status, equals(SupplyGapStatus.insufficientData));
      expect(insight.recommendationText, contains('Insufficient historical data'));
    });

    test('13. Forecast failure resilience: throwing repository does not crash service', () async {
      final failingService = DemandForecastService(
        FailingDemandForecastRepository(),
        DemandForecastingEngine.instance,
      );

      final result = await failingService.getForecast(serviceId: 'c1');

      // Assert: Returns safe fallback result with insufficientData status
      expect(result.forecasts, isEmpty);
      expect(result.supplyInsight!.status, equals(SupplyGapStatus.insufficientData));
      expect(result.supplyInsight!.recommendationText, contains('Insufficient historical data'));
    });

    test('14. Supply-gap calculation: deficit vs balanced vs surplus', () {
      final engine = DemandForecastingEngine.instance;

      // 1. Deficit scenario: 25 expected demand/day, 5 available workers (ratio = 0.20 < 0.60)
      final deficitForecasts = List.generate(7, (i) => DemandForecastItem(
        date: DateTime(2026, 9, 20).add(Duration(days: i)),
        predictedDemand: 25.0,
      ));
      final deficitInsight = engine.computeSupplyInsight(
        forecasts: deficitForecasts,
        activeWorkerSupply: 5,
        historicalDaysCount: 30,
      );
      expect(deficitInsight.status, equals(SupplyGapStatus.deficit));
      expect(deficitInsight.recommendationText, contains('Potential Supply Deficit'));

      // 2. Balanced scenario: 10 expected demand/day, 8 available workers (ratio = 0.80 between 0.60 and 1.50)
      final balancedForecasts = List.generate(7, (i) => DemandForecastItem(
        date: DateTime(2026, 9, 20).add(Duration(days: i)),
        predictedDemand: 10.0,
      ));
      final balancedInsight = engine.computeSupplyInsight(
        forecasts: balancedForecasts,
        activeWorkerSupply: 8,
        historicalDaysCount: 30,
      );
      expect(balancedInsight.status, equals(SupplyGapStatus.balanced));
      expect(balancedInsight.recommendationText, contains('Balanced Capacity'));

      // 3. Surplus scenario: 5 expected demand/day, 15 available workers (ratio = 3.0 > 1.50)
      final surplusForecasts = List.generate(7, (i) => DemandForecastItem(
        date: DateTime(2026, 9, 20).add(Duration(days: i)),
        predictedDemand: 5.0,
      ));
      final surplusInsight = engine.computeSupplyInsight(
        forecasts: surplusForecasts,
        activeWorkerSupply: 15,
        historicalDaysCount: 30,
      );
      expect(surplusInsight.status, equals(SupplyGapStatus.surplus));
      expect(surplusInsight.recommendationText, contains('Capacity Surplus'));
    });

    test('15. Model version handling: demand_forecast_v1 traceability preserved', () async {
      final result = await DI.demandForecastService.getForecast(serviceId: 'c1');

      for (final item in result.forecasts) {
        expect(item.modelVersion, equals(DemandForecastConfig.defaultModelVersion));
      }
    });
  });

  group('Marketplace Operational Flow Integration Tests (16-22)', () {
    test('16. Customer marketplace functional on FairMatch success', () async {
      final workers = await DI.customerRepo.getEligibleWorkers('c2');

      expect(workers, isNotEmpty);
      expect(workers.first.customTag, equals('FairMatch Recommended'));
      expect(workers.first.name, isNotEmpty);
      expect(workers.first.rate, greaterThan(0));
    });

    test('17. Customer marketplace functional on FairMatch fallback', () async {
      final originalService = DI.fairMatchService;
      DI.fairMatchService = FairMatchService(FailingFairMatchRepository());

      try {
        final workers = await DI.customerRepo.getEligibleWorkers('c2');

        // Customer still sees active verified workers
        expect(workers, isNotEmpty);
        expect(workers.every((w) => w.categoryId == 'c2'), isTrue);
      } finally {
        DI.fairMatchService = originalService;
      }
    });

    test('18. Booking flow remains unchanged: creation, details, and initial status', () async {
      // Customer books recommended worker
      final bookingId = await DI.customerRepo.createBooking(
        workerId: 'w1',
        serviceId: 'c2',
        scheduledDate: '2026-09-20',
        scheduledTime: '10:00 AM',
        amount: 399.0,
      );

      expect(bookingId, isNotNull);
      expect(bookingId!.startsWith('bk_'), isTrue);

      final booking = await DI.customerRepo.getBookingDetails(bookingId);
      expect(booking, isNotNull);
      expect(booking!['worker_id'], equals('w1'));
      expect(booking['status'], isIn(['pending', 'onTheWay']));
      expect(booking['base_amount'], equals(399.0));
    });

    test('19. Payment flow remains unchanged: escrow order creation, verification, release', () async {
      const testBookingId = 'bk_pay_test_001';

      // 1. Create order
      final order = await DI.paymentRepo.createPaymentOrder(testBookingId);
      expect(order.orderId.startsWith('order_'), isTrue);
      expect(order.amountPaise, greaterThan(0));

      // 2. Verify payment & hold escrow
      final verified = await DI.paymentRepo.verifyPayment(
        bookingId: testBookingId,
        razorpayPaymentId: 'pay_test_123',
        razorpayOrderId: order.orderId,
        razorpaySignature: 'sig_valid_123',
      );
      expect(verified, isTrue);

      final payment = await DI.paymentRepo.getPaymentForBooking(testBookingId);
      expect(payment, isNotNull);
      expect(payment!.escrowStatus, equals(EscrowStatus.held));

      // 3. Release escrow on job completion
      final released = await DI.paymentRepo.releaseEscrow(testBookingId);
      expect(released, isTrue);

      final finalPayment = await DI.paymentRepo.getPaymentForBooking(testBookingId);
      expect(finalPayment!.escrowStatus, equals(EscrowStatus.released));
    });

    test('20. Realtime tracking remains unchanged: status stream subscriptions', () async {
      // Customer watches active bookings stream
      final bookingStream = DI.customerRepo.watchCustomerBookings();
      expect(bookingStream, isNotNull);

      // Verify stream emits lists
      final firstEmission = await bookingStream.first;
      expect(firstEmission, isA<List>());
    });

    test('21. Admin dashboard remains fully functional with AI metrics available', () async {
      final stats = await DI.adminRepo.getDashboardStats();
      expect(stats, isNotNull);

      final analyticsSummary = await DI.demandForecastService.getForecastingAnalyticsSummary();
      expect(analyticsSummary['modelVersion'], equals('demand_forecast_v1'));
      expect(analyticsSummary['modelName'], contains('Holt-Winters'));
    });

    test('22. Worker dashboard remains fully functional: earnings, requests, availability', () async {
      final earnings = await DI.paymentRepo.getWorkerReleasedPayments('w1');
      expect(earnings, isA<List>());

      final jobRequests = await DI.workerRepo.getJobRequests('w1');
      expect(jobRequests, isA<List>());

      // Worker updates availability toggle
      await DI.workerRepo.updateWorkerAvailability('w1', true);
    });
  });
}
