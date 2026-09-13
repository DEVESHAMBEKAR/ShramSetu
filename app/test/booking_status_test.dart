import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/booking_status.dart';

void main() {
  group('BookingStatus Transitions', () {
    test('pending transitions', () {
      expect(BookingStatus.pending.canTransitionTo(BookingStatus.accepted), isTrue);
      expect(BookingStatus.pending.canTransitionTo(BookingStatus.rejected), isTrue);
      expect(BookingStatus.pending.canTransitionTo(BookingStatus.cancelled), isTrue);
      expect(BookingStatus.pending.canTransitionTo(BookingStatus.completed), isFalse);
    });

    test('accepted transitions', () {
      expect(BookingStatus.accepted.canTransitionTo(BookingStatus.onTheWay), isTrue);
      expect(BookingStatus.accepted.canTransitionTo(BookingStatus.cancelled), isTrue);
      expect(BookingStatus.accepted.canTransitionTo(BookingStatus.arrived), isFalse);
    });

    test('onTheWay transitions', () {
      expect(BookingStatus.onTheWay.canTransitionTo(BookingStatus.arrived), isTrue);
      expect(BookingStatus.onTheWay.canTransitionTo(BookingStatus.completed), isFalse);
    });

    test('arrived transitions', () {
      expect(BookingStatus.arrived.canTransitionTo(BookingStatus.inProgress), isTrue);
      expect(BookingStatus.arrived.canTransitionTo(BookingStatus.cancelled), isFalse);
    });

    test('inProgress transitions', () {
      expect(BookingStatus.inProgress.canTransitionTo(BookingStatus.completed), isTrue);
      expect(BookingStatus.inProgress.canTransitionTo(BookingStatus.pending), isFalse);
    });

    test('terminal states', () {
      expect(BookingStatus.completed.canTransitionTo(BookingStatus.pending), isFalse);
      expect(BookingStatus.rejected.canTransitionTo(BookingStatus.accepted), isFalse);
      expect(BookingStatus.cancelled.canTransitionTo(BookingStatus.onTheWay), isFalse);
    });
  });
}
