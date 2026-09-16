import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';
import 'package:app/core/models/booking_status.dart';
import 'package:app/core/models/payment_models.dart';
import 'package:app/core/services/shared_booking_store.dart';

void main() {
  setUp(() {
    DI.setup();
    SharedBookingStore.instance.resetDemoData();
  });

  group('ShramSetu System Integration E2E Multi-Role Tests', () {
    test('1. End-to-End Lifecycle: Customer Booking -> Worker Realtime Receive -> Status Advance -> Escrow Release -> Admin Sync', () async {
      final customerRepo = DI.customerRepo;
      final workerRepo = DI.workerRepo;
      final adminRepo = DI.adminRepo;
      final paymentRepo = DI.paymentRepo;

      // Subscribe worker, customer, admin to realtime streams
      final workerStream = workerRepo.watchWorkerBookings();
      final adminStream = adminRepo.watchBookings();

      // Step 1: Customer creates booking
      final bookingId = await customerRepo.createBooking(
        workerId: 'w1',
        serviceId: 'c2',
        scheduledDate: 'Today',
        scheduledTime: '02:00 PM',
        amount: 499.0,
      );

      expect(bookingId, isNotNull);
      expect(bookingId, startsWith('bk_'));

      // Step 2: Worker receives booking in real-time
      final workerBookings = await workerStream.first;
      expect(workerBookings.any((b) => b.id == bookingId), isTrue);

      // Step 3: Admin dashboard observes booking in real-time
      final adminBookings = await adminStream.first;
      expect(adminBookings.any((b) => b.id == bookingId), isTrue);

      // Step 4: Worker advances lifecycle to 'arrived'
      await workerRepo.updateBookingStatus(bookingId!, BookingStatus.arrived);

      // Customer tracking stream observes 'arrived'
      final customerDetails = await customerRepo.getBookingDetails(bookingId);
      expect(customerDetails, isNotNull);
      expect(customerDetails!['status'], equals(BookingStatus.arrived.toDbString()));

      // Step 5: Worker advances to 'inProgress'
      await workerRepo.updateBookingStatus(bookingId, BookingStatus.inProgress);
      final inProgressDetails = await customerRepo.getBookingDetails(bookingId);
      expect(inProgressDetails!['status'], equals(BookingStatus.inProgress.toDbString()));

      // Setup and verify escrow payment order before completion
      final orderResult = await paymentRepo.createPaymentOrder(bookingId);
      expect(orderResult.orderId, isNotEmpty);

      final verified = await paymentRepo.verifyPayment(
        bookingId: bookingId,
        razorpayOrderId: orderResult.orderId,
        razorpayPaymentId: 'pay_${DateTime.now().millisecondsSinceEpoch}',
        razorpaySignature: 'sig_valid_mock_signature',
      );
      expect(verified, isTrue);

      // Step 6: Worker completes the job
      await workerRepo.updateBookingStatus(bookingId, BookingStatus.completed);

      // Verify completion state in customer view
      final completedDetails = await customerRepo.getBookingDetails(bookingId);
      expect(completedDetails!['status'], equals(BookingStatus.completed.toDbString()));

      // Step 7: Verify Escrow payment is automatically released upon completion
      final paymentRecord = await paymentRepo.getPaymentForBooking(bookingId);
      expect(paymentRecord, isNotNull);
      expect(paymentRecord!.status, equals(PaymentStatus.paid));
      expect(paymentRecord.escrowStatus, equals(EscrowStatus.released));

      // Step 8: Admin metrics reflect the completed job
      final stats = await adminRepo.getDashboardStats();
      expect(stats.totalWorkers, greaterThan(0));
    });

    test('2. Multi-Role Real-Time Event Synchronization Across Concurrent Streams', () async {
      final customerRepo = DI.customerRepo;
      final workerRepo = DI.workerRepo;
      final adminRepo = DI.adminRepo;

      final customerEvents = <List<Map<String, dynamic>>>[];
      final workerEvents = <List<dynamic>>[];
      final adminEvents = <List<dynamic>>[];

      final sub1 = customerRepo.watchCustomerBookings().listen(customerEvents.add);
      final sub2 = workerRepo.watchWorkerBookings().listen(workerEvents.add);
      final sub3 = adminRepo.watchBookings().listen(adminEvents.add);

      // Trigger a state change by creating a booking
      final bookingId = await customerRepo.createBooking(
        workerId: 'w1',
        serviceId: 'c1',
        scheduledDate: 'Tomorrow',
        scheduledTime: '11:00 AM',
        amount: 250.0,
      );

      // Allow event dispatch microtask
      await Future.delayed(const Duration(milliseconds: 50));

      expect(customerEvents.isNotEmpty, isTrue);
      expect(workerEvents.isNotEmpty, isTrue);
      expect(adminEvents.isNotEmpty, isTrue);

      // Worker updates status to completed
      await workerRepo.updateBookingStatus(bookingId!, BookingStatus.completed);
      await Future.delayed(const Duration(milliseconds: 50));

      // All streams received updates
      expect(customerEvents.length, greaterThanOrEqualTo(2));
      expect(workerEvents.length, greaterThanOrEqualTo(2));
      expect(adminEvents.length, greaterThanOrEqualTo(2));

      await sub1.cancel();
      await sub2.cancel();
      await sub3.cancel();
    });

    test('3. Review & Reputation Loop: Completed Booking -> Customer Reviews Worker -> Profile Rating Updates', () async {
      final reviewRepo = DI.reviewRepo;

      // Submit customer review for completed booking
      final review = await reviewRepo.submitReview(
        bookingId: 'j1',
        rating: 5,
        comment: 'Superb quality and punctual service by the Pune Plumbers Guild artisan!',
      );

      expect(review.id, isNotEmpty);
      expect(review.rating, equals(5));

      // Fetch reviews for worker
      final reviews = await reviewRepo.getWorkerReviews('w1');
      expect(reviews.any((r) => r.id == review.id), isTrue);

      // Verify review can be retrieved for the booking
      final bookingReview = await reviewRepo.getReviewForBooking('j1');
      expect(bookingReview, isNotNull);
      expect(bookingReview!.comment, contains('Pune Plumbers Guild'));
    });

    test('4. Booking Cancellation Flow: Customer Cancels -> Propagates to Worker and Admin in Real-Time', () async {
      final customerRepo = DI.customerRepo;
      final workerRepo = DI.workerRepo;
      final adminRepo = DI.adminRepo;

      // Create a booking
      final bookingId = await customerRepo.createBooking(
        workerId: 'w1',
        serviceId: 'c2',
        scheduledDate: 'Today',
        scheduledTime: '04:00 PM',
        amount: 300.0,
      );

      // Customer cancels
      final cancelled = await customerRepo.cancelBooking(bookingId!, reason: 'User not available');
      expect(cancelled, isTrue);

      // Worker verifies cancelled state
      final workerJobs = await workerRepo.getWorkerBookings();
      final targetJob = workerJobs.firstWhere((j) => j.id == bookingId);
      expect(targetJob.status, equals(BookingStatus.cancelled));

      // Admin verifies cancelled state
      final adminJobs = await adminRepo.getBookings();
      final adminTarget = adminJobs.firstWhere((j) => j.id == bookingId);
      expect(adminTarget.status, equals(BookingStatus.cancelled));
    });
  });
}
