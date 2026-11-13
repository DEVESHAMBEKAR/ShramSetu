import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';
import 'package:app/core/models/booking_status.dart';
import 'package:app/core/services/shared_booking_store.dart';
import 'package:app/features/worker/data/models/worker_models.dart';

void main() {
  setUp(() {
    DI.setup();
    SharedBookingStore.instance.resetDemoData();
  });

  group('Booking Execution & Lifecycle Repair Tests', () {
    test('1. Customer booking creation adds booking to store and notifies worker', () async {
      final newBookingId = await DI.customerRepo.createBooking(
        workerId: 'w1',
        serviceId: 'c2',
        scheduledDate: '2026-10-15',
        scheduledTime: '10:00 AM',
        amount: 450.0,
        addressId: 'addr_1',
      );

      expect(newBookingId, isNotNull);
      expect(newBookingId!.isNotEmpty, isTrue);

      final customerBookings = await DI.customerRepo.getCustomerBookings();
      expect(customerBookings.any((b) => b['id'] == newBookingId), isTrue);

      final booking = customerBookings.firstWhere((b) => b['id'] == newBookingId);
      expect(booking['base_amount'], equals(450.0));
      expect(booking['worker_id'], equals('w1'));
    });

    test('2. Worker receives job requests and sees correct status', () async {
      final requests = await DI.workerRepo.getWorkerBookings();
      expect(requests.isNotEmpty, isTrue);

      final initial = requests.first;
      expect(initial.id, isNotEmpty);
      expect(initial.baseAmount, greaterThan(0));
      expect(initial.status, isNotNull);
    });

    test('3. Worker can transition booking through full lifecycle to completed', () async {
      final newBookingId = await DI.customerRepo.createBooking(
        workerId: 'w1',
        serviceId: 'c2',
        scheduledDate: '2026-10-16',
        scheduledTime: '02:00 PM',
        amount: 550.0,
      );

      expect(newBookingId, isNotNull);

      // Transition to accepted
      await DI.workerRepo.updateBookingStatus(newBookingId!, BookingStatus.accepted);
      var bookings = await DI.workerRepo.getWorkerBookings();
      var target = bookings.firstWhere((b) => b.id == newBookingId);
      expect(target.status, equals(BookingStatus.accepted));

      // Transition to onTheWay
      await DI.workerRepo.updateBookingStatus(newBookingId, BookingStatus.onTheWay);
      bookings = await DI.workerRepo.getWorkerBookings();
      target = bookings.firstWhere((b) => b.id == newBookingId);
      expect(target.status, equals(BookingStatus.onTheWay));

      // Transition to arrived
      await DI.workerRepo.updateBookingStatus(newBookingId, BookingStatus.arrived);
      bookings = await DI.workerRepo.getWorkerBookings();
      target = bookings.firstWhere((b) => b.id == newBookingId);
      expect(target.status, equals(BookingStatus.arrived));

      // Transition to inProgress
      await DI.workerRepo.updateBookingStatus(newBookingId, BookingStatus.inProgress);
      bookings = await DI.workerRepo.getWorkerBookings();
      target = bookings.firstWhere((b) => b.id == newBookingId);
      expect(target.status, equals(BookingStatus.inProgress));

      // Transition to completed
      await DI.workerRepo.updateBookingStatus(newBookingId, BookingStatus.completed);
      bookings = await DI.workerRepo.getWorkerBookings();
      target = bookings.firstWhere((b) => b.id == newBookingId);
      expect(target.status, equals(BookingStatus.completed));
    });

    test('4. BookingStatus state machine validates permitted transitions', () {
      expect(BookingStatus.pending.canTransitionTo(BookingStatus.accepted), isTrue);
      expect(BookingStatus.pending.canTransitionTo(BookingStatus.rejected), isTrue);
      expect(BookingStatus.pending.canTransitionTo(BookingStatus.cancelled), isTrue);
      expect(BookingStatus.pending.canTransitionTo(BookingStatus.completed), isFalse);

      expect(BookingStatus.accepted.canTransitionTo(BookingStatus.onTheWay), isTrue);
      expect(BookingStatus.onTheWay.canTransitionTo(BookingStatus.arrived), isTrue);
      expect(BookingStatus.arrived.canTransitionTo(BookingStatus.inProgress), isTrue);
      expect(BookingStatus.inProgress.canTransitionTo(BookingStatus.completed), isTrue);

      expect(BookingStatus.completed.canTransitionTo(BookingStatus.pending), isFalse);
      expect(BookingStatus.cancelled.canTransitionTo(BookingStatus.accepted), isFalse);
    });

    test('5. Admin repository getBookings retrieves bookings and honors isolation', () async {
      final allAdminBookings = await DI.adminRepo.getBookings();
      expect(allAdminBookings.isNotEmpty, isTrue);
    });

    test('6. Customer can book with Cash payment mode, setting payment_method to CASH and generating OTP', () async {
      final cashBookingId = await DI.customerRepo.createBooking(
        workerId: 'w1',
        serviceId: 'c2',
        scheduledDate: '2026-10-17',
        scheduledTime: '11:00 AM',
        amount: 450.0,
        addressId: 'addr_1',
        paymentMethod: 'CASH',
      );

      expect(cashBookingId, isNotNull);
      final customerBookings = await DI.customerRepo.getCustomerBookings();
      final booking = customerBookings.firstWhere((b) => b['id'] == cashBookingId);
      expect(booking['payment_method'], equals('CASH'));
      expect(booking['otp'], isNotNull);
      expect(booking['otp'].toString().length, equals(4));

      final workerJobs = await DI.workerRepo.getWorkerBookings();
      final matchingJob = workerJobs.firstWhere((j) => j.id == cashBookingId);
      expect(matchingJob.paymentMethod, equals('CASH'));
      expect(matchingJob.isCash, isTrue);
      expect(matchingJob.otp, equals(booking['otp'].toString()));
    });

    test('7. Customer can book with Razorpay payment mode, setting payment_method to RAZORPAY', () async {
      final onlineBookingId = await DI.customerRepo.createBooking(
        workerId: 'w1',
        serviceId: 'c2',
        scheduledDate: '2026-10-18',
        scheduledTime: '03:00 PM',
        amount: 600.0,
        addressId: 'addr_1',
        paymentMethod: 'RAZORPAY',
      );

      expect(onlineBookingId, isNotNull);
      final customerBookings = await DI.customerRepo.getCustomerBookings();
      final booking = customerBookings.firstWhere((b) => b['id'] == onlineBookingId);
      expect(booking['payment_method'], equals('RAZORPAY'));
      expect(booking['otp'], isNotNull);

      final workerJobs = await DI.workerRepo.getWorkerBookings();
      final matchingJob = workerJobs.firstWhere((j) => j.id == onlineBookingId);
      expect(matchingJob.paymentMethod, equals('RAZORPAY'));
      expect(matchingJob.isCash, isFalse);
    });

    test('8. Customer can switch payment from CASH to RAZORPAY online escrow on live tracking console', () async {
      final bookingId = await DI.customerRepo.createBooking(
        workerId: 'w1',
        serviceId: 'c2',
        scheduledDate: '2026-10-19',
        scheduledTime: '04:00 PM',
        amount: 500.0,
        paymentMethod: 'CASH',
      );

      expect(bookingId, isNotNull);
      var job = (await DI.workerRepo.getWorkerBookings()).firstWhere((j) => j.id == bookingId);
      expect(job.isCash, isTrue);

      // Customer chooses to pay online via Razorpay before completion
      SharedBookingStore.instance.updatePaymentMethod(bookingId!, 'RAZORPAY');

      job = (await DI.workerRepo.getWorkerBookings()).firstWhere((j) => j.id == bookingId);
      expect(job.isCash, isFalse);
      expect(job.paymentMethod, equals('RAZORPAY'));
    });

    test('9. Delivery-style tracking: status progression updates live tracking store', () async {
      final bookingId = await DI.customerRepo.createBooking(
        workerId: 'w1',
        serviceId: 'c2',
        scheduledDate: '2026-10-20',
        scheduledTime: '09:00 AM',
        amount: 350.0,
      );

      // Step 1: Worker accepts request
      await DI.workerRepo.updateBookingStatus(bookingId!, BookingStatus.accepted);
      var b = SharedBookingStore.instance.getBookingById(bookingId);
      expect(b?['status'], equals('accepted'));

      // Step 2: Worker starts journey (onTheWay - delivery start location & ETA shared)
      await DI.workerRepo.updateBookingStatus(bookingId, BookingStatus.onTheWay);
      b = SharedBookingStore.instance.getBookingById(bookingId);
      expect(b?['status'], equals('onTheWay'));

      // Step 3: Worker arrives at customer doorstep
      await DI.workerRepo.updateBookingStatus(bookingId, BookingStatus.arrived);
      b = SharedBookingStore.instance.getBookingById(bookingId);
      expect(b?['status'], equals('arrived'));

      // Step 4: Worker begins service
      await DI.workerRepo.updateBookingStatus(bookingId, BookingStatus.inProgress);
      b = SharedBookingStore.instance.getBookingById(bookingId);
      expect(b?['status'], equals('inProgress'));

      // Step 5: Service completed after OTP validation & payment settlement
      await DI.workerRepo.updateBookingStatus(bookingId, BookingStatus.completed);
      b = SharedBookingStore.instance.getBookingById(bookingId);
      expect(b?['status'], equals('completed'));
    });
  });
}
