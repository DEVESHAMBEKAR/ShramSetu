import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/booking_status.dart';
import 'package:app/core/services/booking_realtime_service.dart';
import 'package:app/features/customer/data/repositories/mock_customer_repository.dart';
import 'package:app/features/worker/data/repositories/mock_worker_repository.dart';
import 'package:app/features/admin/data/repositories/mock_admin_repository.dart';

void main() {
  group('1. BookingStatus DB Serialization & Deserialization', () {
    test('converts enum to exact database string', () {
      expect(BookingStatus.pending.toDbString(), 'pending');
      expect(BookingStatus.accepted.toDbString(), 'accepted');
      expect(BookingStatus.onTheWay.toDbString(), 'onTheWay');
      expect(BookingStatus.arrived.toDbString(), 'arrived');
      expect(BookingStatus.inProgress.toDbString(), 'inProgress');
      expect(BookingStatus.completed.toDbString(), 'completed');
      expect(BookingStatus.rejected.toDbString(), 'rejected');
      expect(BookingStatus.cancelled.toDbString(), 'cancelled');
    });

    test('deserializes database status strings robustly (case & spelling insensitive)', () {
      expect(BookingStatus.fromDbString('pending'), BookingStatus.pending);
      expect(BookingStatus.fromDbString('PENDING'), BookingStatus.pending);
      expect(BookingStatus.fromDbString('accepted'), BookingStatus.accepted);
      expect(BookingStatus.fromDbString('ACCEPTED'), BookingStatus.accepted);
      expect(BookingStatus.fromDbString('onTheWay'), BookingStatus.onTheWay);
      expect(BookingStatus.fromDbString('ontheway'), BookingStatus.onTheWay);
      expect(BookingStatus.fromDbString('arrived'), BookingStatus.arrived);
      expect(BookingStatus.fromDbString('inProgress'), BookingStatus.inProgress);
      expect(BookingStatus.fromDbString('inprogress'), BookingStatus.inProgress);
      expect(BookingStatus.fromDbString('completed'), BookingStatus.completed);
      expect(BookingStatus.fromDbString('rejected'), BookingStatus.rejected);
      expect(BookingStatus.fromDbString('cancelled'), BookingStatus.cancelled);
      expect(BookingStatus.fromDbString('canceled'), BookingStatus.cancelled);
      expect(BookingStatus.fromDbString(null), BookingStatus.pending);
      expect(BookingStatus.fromDbString('unknown_status'), BookingStatus.pending);
    });
  });

  group('2. BookingRealtimeEvent Model & Event Types', () {
    test('creates INSERT event with new record and extracts bookingId', () {
      final event = BookingRealtimeEvent(
        eventType: BookingRealtimeEventType.insert,
        newRecord: {'id': 'bk-001', 'status': 'pending', 'customer_id': 'cust-1'},
        oldRecord: {},
        bookingId: 'bk-001',
      );

      expect(event.eventType, BookingRealtimeEventType.insert);
      expect(event.bookingId, 'bk-001');
      expect(event.newRecord['status'], 'pending');
      expect(event.toString(), contains('bk-001'));
    });

    test('creates UPDATE event with transitions from accepted to onTheWay', () {
      final event = BookingRealtimeEvent(
        eventType: BookingRealtimeEventType.update,
        newRecord: {'id': 'bk-002', 'status': 'onTheWay', 'worker_id': 'w-1'},
        oldRecord: {'id': 'bk-002', 'status': 'accepted', 'worker_id': 'w-1'},
        bookingId: 'bk-002',
      );

      expect(event.eventType, BookingRealtimeEventType.update);
      expect(event.oldRecord['status'], 'accepted');
      expect(event.newRecord['status'], 'onTheWay');
      final newStatus = BookingStatus.fromDbString(event.newRecord['status']);
      expect(newStatus, BookingStatus.onTheWay);
    });

    test('creates DELETE event with old record', () {
      final event = BookingRealtimeEvent(
        eventType: BookingRealtimeEventType.delete,
        newRecord: {},
        oldRecord: {'id': 'bk-003', 'status': 'cancelled'},
        bookingId: 'bk-003',
      );

      expect(event.eventType, BookingRealtimeEventType.delete);
      expect(event.bookingId, 'bk-003');
      expect(event.oldRecord['status'], 'cancelled');
    });
  });

  group('3. Customer Repository Realtime Streams', () {
    test('watchCustomerBookings emits initial booking list and can be listened to', () async {
      final repo = MockCustomerRepository();
      await repo.createBooking(
        workerId: 'w1',
        serviceId: 'c2',
        scheduledDate: '2026-09-20',
        scheduledTime: '10:00 AM',
        amount: 399.0,
      );
      final stream = repo.watchCustomerBookings();

      final firstEmission = await stream.first;
      expect(firstEmission, isA<List<Map<String, dynamic>>>());
      expect(firstEmission.isNotEmpty, isTrue);
      expect(firstEmission.first['status'], 'onTheWay');
    });

    test('watchBookingDetails emits specific booking by id', () async {
      final repo = MockCustomerRepository();
      final stream = repo.watchBookingDetails('b_active');

      final details = await stream.first;
      expect(details, isNotNull);
      expect(details!['id'], 'b_active');
    });

    test('subscription can be cancelled cleanly without errors', () async {
      final repo = MockCustomerRepository();
      final stream = repo.watchCustomerBookings();

      StreamSubscription? sub;
      sub = stream.listen((_) {});
      await sub.cancel();
      expect(sub, isNotNull);
    });
  });

  group('4. Worker Repository Realtime Streams', () {
    test('watchWorkerBookings emits assigned job requests', () async {
      final repo = MockWorkerRepository();
      final stream = repo.watchWorkerBookings();

      final jobs = await stream.first;
      expect(jobs, isNotNull);
      expect(jobs, isNotEmpty);
      expect(jobs.first.id, isNotEmpty);
    });

    test('worker status update alters job state', () async {
      final repo = MockWorkerRepository();
      final initialJobs = await repo.getWorkerBookings();
      final firstJob = initialJobs.first;

      await repo.updateBookingStatus(firstJob.id, BookingStatus.onTheWay);
      final updatedJobs = await repo.getWorkerBookings();
      final updatedJob = updatedJobs.firstWhere((j) => j.id == firstJob.id);
      expect(updatedJob.status, BookingStatus.onTheWay);
    });
  });

  group('5. Admin Repository Realtime Streams', () {
    test('watchBookings emits all platform bookings for admin', () async {
      final repo = MockAdminRepository();
      final stream = repo.watchBookings();

      final bookings = await stream.first;
      expect(bookings, isNotNull);
      expect(bookings, isNotEmpty);
    });

    test('admin updateBookingStatus modifies status cleanly', () async {
      final repo = MockAdminRepository();
      final all = await repo.getBookings();
      final b = all.first;

      await repo.updateBookingStatus(b.id, BookingStatus.completed);
      final refreshed = await repo.getBookings();
      final completed = refreshed.firstWhere((item) => item.id == b.id);
      expect(completed.status, BookingStatus.completed);
    });
  });
}
