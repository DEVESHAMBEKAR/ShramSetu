import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/worker/data/repositories/mock_worker_repository.dart';
import 'package:app/core/models/booking_status.dart';

void main() {
  group('MockWorkerRepository Tests', () {
    late MockWorkerRepository repo;

    setUp(() {
      repo = MockWorkerRepository();
    });

    test('worker accepting a booking', () {
      final pendingJob = repo.activeRequests.first;
      expect(pendingJob.status, equals(BookingStatus.pending));

      repo.updateBookingStatus(pendingJob.id, BookingStatus.accepted);
      
      final updatedJob = repo.currentJobs.firstWhere((j) => j.id == pendingJob.id);
      expect(updatedJob.status, equals(BookingStatus.accepted));
    });

    test('worker status transitions', () {
      final job = repo.currentJobs.first; // It was already accepted in the previous test
      
      repo.updateBookingStatus(job.id, BookingStatus.onTheWay);
      repo.updateBookingStatus(job.id, BookingStatus.arrived);
      repo.updateBookingStatus(job.id, BookingStatus.inProgress);
      repo.updateBookingStatus(job.id, BookingStatus.completed);
      
      final completedJob = repo.completedJobs.firstWhere((j) => j.id == job.id);
      expect(completedJob.status, equals(BookingStatus.completed));
    });
  });
}
