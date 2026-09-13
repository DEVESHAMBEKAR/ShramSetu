import '../../features/worker/data/models/worker_models.dart';

abstract class IWorkerRepository {
  /// Fetch the worker's profile using their auth user ID
  Future<WorkerProfile> getWorkerProfile(String userId);

  /// Update the worker's availability status
  Future<void> updateAvailability(bool isAvailable);

  /// Fetch all active, pending, or completed jobs for the worker
  Future<List<JobRequest>> getWorkerBookings();

  /// Update the status of a specific booking (e.g. pending -> confirmed -> completed)
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus);
}
