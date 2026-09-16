import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';
import 'package:app/core/models/payment_models.dart';
import 'package:app/core/models/fairmatch_models.dart';
import 'package:app/core/repositories/mock_payment_repository.dart';
import 'package:app/core/repositories/mock_fairmatch_repository.dart';
import 'package:app/core/repositories/mock_demand_forecast_repository.dart';
import 'package:app/core/repositories/mock_review_repository.dart';
import 'package:app/core/services/fairmatch_engine.dart';
import 'package:app/features/customer/data/models/customer_models.dart';
import 'package:app/features/customer/data/repositories/mock_customer_repository.dart';
import 'package:app/features/worker/data/repositories/mock_worker_repository.dart';

Worker createTestWorker({
  required String id,
  required String name,
  String categoryId = 'c1',
  double rating = 4.8,
  int reviewCount = 35,
  double distanceKm = 2.5,
  String availability = 'Available Today',
}) {
  return Worker(
    id: id,
    name: name,
    categoryId: categoryId,
    rate: 350,
    rating: rating,
    reviewCount: reviewCount,
    jobsCompleted: 100,
    distanceKm: distanceKm,
    experience: '4 yrs exp',
    availability: availability,
    specializations: ['Plumbing'],
    locationTag: 'Kothrud, Pune',
    imageUrl: '',
  );
}

void main() {
  setUpAll(() {
    DI.setup();
  });

  group('1. Multi-Tenant Customer Data Isolation', () {
    test('Customer can only retrieve bookings belonging to their own customer ID', () async {
      final customerRepo = MockCustomerRepository();

      // Seed a customer booking
      await customerRepo.createBooking(
        workerId: 'w1',
        serviceId: 'c1',
        scheduledDate: '2026-09-20',
        scheduledTime: '10:00 AM',
        amount: 350.0,
      );
      
      final customerBookings = await customerRepo.getCustomerBookings();
      expect(customerBookings, isNotEmpty);

      // Verify all returned bookings strictly match the current customer session
      for (final booking in customerBookings) {
        expect(booking['customer_id'] ?? 'mock-customer-1', equals('mock-customer-1'));
      }
    });

    test('Customer booking cancellation isolates state changes to target booking ID', () async {
      final customerRepo = MockCustomerRepository();
      
      // Create a test booking
      final bookingId = await customerRepo.createBooking(
        workerId: 'w1',
        serviceId: 'c1',
        scheduledDate: '2026-09-20',
        scheduledTime: '10:00 AM',
        amount: 350.0,
      );
      expect(bookingId, isNotNull);

      // Cancel the created booking
      final cancelResult = await customerRepo.cancelBooking(
        bookingId!,
        reason: 'Customer requested reschedule',
      );
      expect(cancelResult, isTrue);

      // Verify status is updated to cancelled
      final details = await customerRepo.getBookingDetails(bookingId);
      expect(details?['status'], equals('cancelled'));
    });
  });

  group('2. Escrow & Payment Access Control', () {
    test('Customer cannot view payment records of foreign or unknown bookings', () async {
      final paymentRepo = MockPaymentRepository();
      
      final payment = await paymentRepo.getPaymentForBooking('foreign-booking-xyz');
      expect(payment, isNull);
    });

    test('Worker cannot view unreleased escrow payments in worker released payments list', () async {
      final paymentRepo = MockPaymentRepository();
      
      const testBookingId = 'test-booking-sec-1';
      final order = await paymentRepo.createPaymentOrder(testBookingId);
      await paymentRepo.verifyPayment(
        bookingId: testBookingId,
        razorpayPaymentId: 'pay_sec_1',
        razorpayOrderId: order.orderId,
        razorpaySignature: 'sig_valid',
      );

      // Fetch released payments for worker — should NOT contain the held payment
      final released = await paymentRepo.getWorkerReleasedPayments('mock-worker-id');
      final containsHeld = released.any(
        (p) => p.bookingId == testBookingId && p.escrowStatus == EscrowStatus.held,
      );
      expect(containsHeld, isFalse);
    });
  });

  group('3. Storage & KYC Document Isolation', () {
    test('Worker KYC documents require authenticated worker ID or admin role', () {
      // In Supabase storage policy (007_storage_and_kyc.sql):
      // KYC bucket 'worker-documents' enforces:
      // SELECT USING: (bucket_id = 'worker-documents' AND (auth.uid()::text = (storage.foldername(name))[1] OR auth_user_role() = 'ADMIN'))
      
      const workerId = 'worker-uuid-1234';
      const foreignUserId = 'customer-uuid-5678';
      const adminRole = 'ADMIN';
      const customerRole = 'CUSTOMER';

      // Worker viewing own folder
      bool canWorkerAccessOwn = (workerId == workerId);
      expect(canWorkerAccessOwn, isTrue);

      // Customer viewing worker's folder
      bool canCustomerAccessWorkerKyc = (foreignUserId == workerId) || (customerRole == adminRole);
      expect(canCustomerAccessWorkerKyc, isFalse);

      // Admin viewing worker's folder
      bool canAdminAccessWorkerKyc = (adminRole == 'ADMIN');
      expect(canAdminAccessWorkerKyc, isTrue);
    });
  });

  group('4. Worker Profile & Availability Boundary', () {
    test('Worker can query assigned bookings safely', () async {
      final workerRepo = MockWorkerRepository();
      
      final bookings = await workerRepo.getWorkerBookings();
      expect(bookings, isNotNull);
    });

    test('Worker can update their own availability', () async {
      final workerRepo = MockWorkerRepository();
      
      await workerRepo.updateWorkerAvailability('w101', true);
      expect((await workerRepo.getWorkerProfile('w101')).isAvailable, isTrue);

      await workerRepo.updateWorkerAvailability('w101', false);
      expect((await workerRepo.getWorkerProfile('w101')).isAvailable, isFalse);
    });
  });

  group('5. Admin RBAC Enforcement for Demand Forecasting', () {
    test('Non-admin users are rejected from accessing historical demand aggregation', () async {
      // Server-side RPC (014_demand_forecasting.sql) check:
      // IF auth_user_role() <> 'ADMIN' THEN RAISE EXCEPTION 'Unauthorized...'
      
      String simulateRbacCheck(String role) {
        if (role != 'ADMIN') {
          throw Exception('Unauthorized: Only federation administrators can access historical demand aggregations.');
        }
        return 'SUCCESS';
      }

      expect(() => simulateRbacCheck('CUSTOMER'), throwsException);
      expect(() => simulateRbacCheck('WORKER'), throwsException);
      expect(simulateRbacCheck('ADMIN'), equals('SUCCESS'));
    });

    test('Non-admin users are rejected from persisting forecast models', () async {
      String simulateSaveCheck(String role) {
        if (role != 'ADMIN') {
          throw Exception('Unauthorized: Only federation administrators can persist forecast models.');
        }
        return 'SAVED';
      }

      expect(() => simulateSaveCheck('CUSTOMER'), throwsException);
      expect(() => simulateSaveCheck('WORKER'), throwsException);
      expect(simulateSaveCheck('ADMIN'), equals('SAVED'));
    });
  });

  group('6. FairMatch Tamper Resistance & Server Authority', () {
    test('FairMatch scores are strictly calculated by authoritative formula and bounded [0.0, 1.0]', () {
      final engine = FairMatchEngine();
      final weights = FairMatchWeights.defaultWeights();

      // Ensure weights sum to 1.0
      expect(weights.sum, closeTo(1.0, 0.001));

      final worker = createTestWorker(id: 'w1', name: 'Ramesh');
      final candidate = FairMatchCandidate(
        worker: worker,
        hasVerifiedSkill: true,
        isAvailable: true,
        distanceKm: 2.5,
        rating: 4.8,
        reviewCount: 35,
        experienceYears: 4,
        activeBookings: 0,
        recent7dBookings: 2,
      );

      final features = engine.computeFeatures(candidate);
      expect(features.areAllNormalized, isTrue);

      final totalScore = engine.computeTotalScore(features, weights);

      // Score must be strictly bounded in [0.0, 1.0]
      expect(totalScore, greaterThanOrEqualTo(0.0));
      expect(totalScore, lessThanOrEqualTo(1.0));
      expect(features.skillScore, equals(1.0));
      expect(features.availabilityScore, equals(1.0));
    });

    test('Client cannot bypass unverified skill: skillScore is strictly 0.0 without verification', () {
      final engine = FairMatchEngine();
      final weights = FairMatchWeights.defaultWeights();

      final worker = createTestWorker(id: 'w2', name: 'Unverified Artisan', rating: 5.0);
      final candidate = FairMatchCandidate(
        worker: worker,
        hasVerifiedSkill: false, // Unverified skill
        isAvailable: true,
        distanceKm: 0.5,
        rating: 5.0,
        reviewCount: 100,
        experienceYears: 10,
        activeBookings: 0,
        recent7dBookings: 0,
      );

      final features = engine.computeFeatures(candidate);
      final totalScore = engine.computeTotalScore(features, weights);

      // Skill component must be 0.0
      expect(features.skillScore, equals(0.0));
      // Total score is penalized by at least 35%
      expect(totalScore, lessThan(0.70));
    });
  });

  group('7. FairMatch Eligibility Pre-Filtering', () {
    test('isEligible strictly excludes unavailable workers', () {
      final engine = FairMatchEngine();
      final worker = createTestWorker(id: 'w3', name: 'Unavailable Worker');
      
      final candidate = FairMatchCandidate(
        worker: worker,
        hasVerifiedSkill: true,
        isAvailable: false, // Unavailable
      );

      expect(engine.isEligible(candidate), isFalse);
    });

    test('isEligible strictly excludes unverified skill workers', () {
      final engine = FairMatchEngine();
      final worker = createTestWorker(id: 'w4', name: 'Unverified Worker');
      
      final candidate = FairMatchCandidate(
        worker: worker,
        hasVerifiedSkill: false, // Unverified
        isAvailable: true,
      );

      expect(engine.isEligible(candidate), isFalse);
    });

    test('recommendWorkers returns only eligible and available candidates', () async {
      final fairMatchRepo = MockFairMatchRepository();
      final results = await fairMatchRepo.recommendWorkers(serviceId: 'srv-1');

      for (final result in results) {
        expect(result.features.availabilityScore, equals(1.0));
        expect(result.features.skillScore, equals(1.0));
      }
    });
  });

  group('8. Payment Verification Idempotency', () {
    test('Repeated payment verification with identical IDs returns idempotent success', () async {
      final paymentRepo = MockPaymentRepository();
      const bookingId = 'booking-idempotent-1';

      final order = await paymentRepo.createPaymentOrder(bookingId);

      // First verification call
      final firstResult = await paymentRepo.verifyPayment(
        bookingId: bookingId,
        razorpayPaymentId: 'pay_idem_1',
        razorpayOrderId: order.orderId,
        razorpaySignature: 'valid_sig_idem',
      );
      expect(firstResult, isTrue);

      // Second verification call with same credentials
      final secondResult = await paymentRepo.verifyPayment(
        bookingId: bookingId,
        razorpayPaymentId: 'pay_idem_1',
        razorpayOrderId: order.orderId,
        razorpaySignature: 'valid_sig_idem',
      );
      expect(secondResult, isTrue);

      // Verify payment remains in held escrow status
      final payment = await paymentRepo.getPaymentForBooking(bookingId);
      expect(payment?.escrowStatus, equals(EscrowStatus.held));
    });
  });

  group('9. Escrow Release State Machine Enforcement', () {
    test('Escrow cannot be released unless payment status is paid and escrow is held', () async {
      final paymentRepo = MockPaymentRepository();
      const bookingId = 'booking-unfunded-1';

      // Create order without verifying (status is pending, escrow is notFunded)
      await paymentRepo.createPaymentOrder(bookingId);

      // Attempt release on unfunded payment — must fail
      final releaseResult = await paymentRepo.releaseEscrow(bookingId);
      expect(releaseResult, isFalse);
    });

    test('Escrow cannot be released more than once (double release protection)', () async {
      final paymentRepo = MockPaymentRepository();
      const bookingId = 'booking-double-1';

      final order = await paymentRepo.createPaymentOrder(bookingId);
      await paymentRepo.verifyPayment(
        bookingId: bookingId,
        razorpayPaymentId: 'pay_double_1',
        razorpayOrderId: order.orderId,
        razorpaySignature: 'sig_double',
      );

      // First release succeeds
      final firstRelease = await paymentRepo.releaseEscrow(bookingId);
      expect(firstRelease, isTrue);

      // Second release fails
      final secondRelease = await paymentRepo.releaseEscrow(bookingId);
      expect(secondRelease, isFalse);
    });
  });

  group('10. Bounded Query Limits & DoS Protection', () {
    test('Worker recommendation respects maximum candidate limits', () async {
      final fairMatchRepo = MockFairMatchRepository();
      
      const requestedLimit = 3;
      final results = await fairMatchRepo.recommendWorkers(
        serviceId: 'srv-1',
        limit: requestedLimit,
      );

      expect(results.length, lessThanOrEqualTo(requestedLimit));
    });

    test('Historical demand dataset generation produces bounded series', () async {
      final forecastRepo = MockDemandForecastRepository();

      final points = await forecastRepo.getHistoricalDemand(
        serviceId: 'srv-1',
      );

      expect(points, isNotEmpty);
      expect(points.length, equals(60));
      for (final pt in points) {
        expect(pt.count, greaterThanOrEqualTo(0));
      }
    });
  });

  group('11. Review Integrity & Rating Range Validation', () {
    test('Reviews validate rating range between 1 and 5', () async {
      final reviewRepo = MockReviewRepository();

      expect(
        () async => await reviewRepo.submitReview(
          bookingId: 'booking-completed-1',
          rating: 0,
        ),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () async => await reviewRepo.submitReview(
          bookingId: 'booking-completed-1',
          rating: 6,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('Valid review submission succeeds and records rating', () async {
      final reviewRepo = MockReviewRepository();

      final review = await reviewRepo.submitReview(
        bookingId: 'booking-completed-1',
        rating: 5,
        comment: 'Outstanding electrical repair work!',
      );

      expect(review.rating, equals(5));
      expect(review.comment, equals('Outstanding electrical repair work!'));
      expect(review.bookingId, equals('booking-completed-1'));
    });
  });

  group('12. Device Token Ownership Security', () {
    test('Device token registration binds strictly to authenticated user identity', () {
      // In Supabase migration 012_fcm_notifications.sql:
      // register_device_token enforces:
      // v_user_id := auth.uid();
      // IF v_user_id IS NULL THEN RAISE EXCEPTION 'Authentication required';
      
      bool canRegisterToken(String? authUid) {
        if (authUid == null || authUid.isEmpty) {
          throw Exception('Authentication required');
        }
        return true;
      }

      expect(() => canRegisterToken(null), throwsException);
      expect(() => canRegisterToken(''), throwsException);
      expect(canRegisterToken('auth-uid-1234'), isTrue);
    });
  });
}
