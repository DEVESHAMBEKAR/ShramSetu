import '../../features/worker/data/models/worker_models.dart';
import '../models/insurance_models.dart';

abstract class IWorkerRepository {
  /// Fetch the worker's profile using their auth user ID
  Future<WorkerProfile> getWorkerProfile(String workerId);
  Future<void> updateWorkerAvailability(String workerId, bool isAvailable);
  Future<void> updateProfileImage(String workerId, String imageUrl);
  Future<List<JobRequest>> getJobRequests(String workerId);
  Future<List<Map<String, dynamic>>> getVerificationDocuments(String workerId);
  Future<void> submitVerificationDocument(String workerId, String documentType, String storagePath, String fileName, String mimeType, int fileSize);
  Future<void> submitForVerification(String workerId);

  /// Register or update worker profile details during initial onboarding with 20-field structure
  Future<void> registerWorker({
    required String workerId,
    required String fullName,
    required String phone,
    required String skill,
    required int experienceYears,
    required String serviceLocation,
    String? dob,
    String? gender,
    String? address,
    String? city,
    String? district,
    String? pinCode,
    String? trade,
    String? skillLevel,
    String? federationName,
    String? membershipId,
    String? bio,
    bool declarationAccepted = true,
  });

  /// Resubmit worker application after changes requested (transitions CHANGES_REQUIRED -> UNDER_REVIEW)
  Future<void> resubmitForVerification(String workerId);

  /// Fetch verification history audit trail
  Future<List<WorkerVerificationHistoryItem>> getVerificationHistory(String workerId);


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

  /// Fetch the worker's cooperative group insurance & welfare fund record
  Future<WorkerInsuranceModel?> getWorkerInsurance(String workerId);
}
