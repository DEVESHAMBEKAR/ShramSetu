import '../../features/worker/data/models/worker_models.dart';

abstract class IWorkerRepository {
  /// Fetch the worker's profile using their auth user ID
  Future<WorkerProfile> getWorkerProfile(String workerId);
  Future<void> updateWorkerAvailability(String workerId, bool isAvailable);
  Future<void> updateProfileImage(String workerId, String imageUrl);
  Future<List<JobRequest>> getJobRequests(String workerId);
  Future<List<Map<String, dynamic>>> getVerificationDocuments(String workerId);
  Future<void> submitVerificationDocument(String workerId, String documentType, String storagePath, String fileName, String mimeType, int fileSize);
  Future<void> submitForVerification(String workerId);


  /// Fetch all active, pending, or completed jobs for the worker
  Future<List<JobRequest>> getWorkerBookings();

  /// Realtime stream watching all assigned jobs for the authenticated worker
  Stream<List<JobRequest>> watchWorkerBookings();

  /// Update the worker's current service location coordinates and timestamp
  Future<void> updateWorkerLocation(
    String workerId, {
    required double latitude,
    required double longitude,
    String? locationTag,
  });

  /// Update the status of a specific booking (e.g. pending -> confirmed -> completed)
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus);
}
