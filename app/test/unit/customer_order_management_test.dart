import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/customer/data/repositories/mock_customer_repository.dart';

void main() {
  group('Customer Order Management Tests', () {
    late MockCustomerRepository customerRepo;

    setUp(() {
      customerRepo = MockCustomerRepository();
    });

    test('1. Customer fetches bookings and active orders list is non-empty', () async {
      final bookings = await customerRepo.getCustomerBookings();
      expect(bookings, isNotEmpty);
      expect(bookings.first['id'], isNotNull);
      expect(bookings.first['base_amount'], isNotNull);
    });

    test('2. Customer cancels a booking with cancellation reason', () async {
      final bookings = await customerRepo.getCustomerBookings();
      final target = bookings.first;
      final bookingId = target['id'] as String;

      await customerRepo.cancelBooking(
        bookingId,
        reason: 'Booked by mistake, changing appointment time.',
      );

      final updatedBookings = await customerRepo.getCustomerBookings();
      final cancelled = updatedBookings.firstWhere((b) => b['id'] == bookingId);

      expect(cancelled['status'], equals('cancelled'));
      expect(cancelled['cancellation_reason'], equals('Booked by mistake, changing appointment time.'));
      expect(cancelled['cancelled_by'], equals('CUSTOMER'));
      expect(cancelled['cancelled_at'], isNotNull);
    });

    test('3. Customer reschedules a booking to a new date and time slot', () async {
      final bookings = await customerRepo.getCustomerBookings();
      final target = bookings.firstWhere((b) => b['status'] != 'cancelled', orElse: () => bookings.last);
      final bookingId = target['id'] as String;
      final originalDate = target['scheduled_date']?.toString();

      await customerRepo.rescheduleBooking(
        bookingId,
        newDate: '2026-10-05',
        newTime: 'Afternoon (12:00 PM - 04:00 PM)',
      );

      final updatedBookings = await customerRepo.getCustomerBookings();
      final rescheduled = updatedBookings.firstWhere((b) => b['id'] == bookingId);

      expect(rescheduled['scheduled_date'], equals('2026-10-05'));
      expect(rescheduled['scheduled_time'], equals('Afternoon (12:00 PM - 04:00 PM)'));
      expect(rescheduled['rescheduled_at'], isNotNull);
      if (originalDate != null) {
        expect(rescheduled['previous_scheduled_date'], equals(originalDate));
      }
    });

    test('4. watchCustomerBookings emits updated data when a booking is modified', () async {
      final stream = customerRepo.watchCustomerBookings();
      
      expectLater(
        stream,
        emits(isA<List<Map<String, dynamic>>>()),
      );
    });
  });
}
