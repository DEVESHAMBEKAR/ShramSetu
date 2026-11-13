import '../../features/admin/data/models/admin_models.dart';
import '../../features/worker/data/models/worker_models.dart';
import '../models/insurance_models.dart';

abstract class IAdminRepository {
  Future<AdminDashboardStats> getDashboardStats();

  Future<List<WorkerProfile>> getWorkers();
  Future<void> startReview(String workerId, {String? remarks});
  Future<void> approveWorker(String workerId, {String? remarks});
  Future<void> requestChanges(String workerId, {required String remarks});
  Future<void> rejectWorker(String workerId, {String? remarks});
  Future<void> suspendWorker(String workerId, {String? remarks});

  /// Fetch KYC documents uploaded by a specific worker.
  Future<List<Map<String, dynamic>>> getWorkerDocuments(String workerId);

  /// Update inspection status for a specific uploaded document.
  Future<void> updateDocumentStatus(String documentId, String status, {String? remarks});

  /// Fetch verification history audit trail for a worker.
  Future<List<WorkerVerificationHistoryItem>> getVerificationHistory(String workerId);

  /// Fetch worker welfare & insurance policy
  Future<WorkerInsuranceModel?> getWorkerInsurance(String workerId);

  /// Update worker insurance policy / verification status
  Future<void> updateWorkerInsurance(WorkerInsuranceModel insurance);

  /// Approve worker insurance application, generate policy number and issue policy
  Future<WorkerInsuranceModel> approveWorkerInsurance(String workerId, {String? remarks});

  /// Update worker designated service areas (by admin)
  Future<void> updateWorkerServiceAreas(String workerId, List<String> serviceAreas);

  /// Fetch area change tickets raised by workers
  Future<List<Map<String, dynamic>>> getAreaChangeTickets({String? federationId});

  /// Resolve an area change ticket (approve or reject)
  Future<void> resolveAreaChangeTicket({
    required String ticketId,
    required String workerId,
    required bool isApproved,
    required List<String> approvedAreas,
    String? remarks,
  });

  Future<List<JobRequest>> getBookings();
  Stream<List<JobRequest>> watchBookings();
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus);

  Future<List<PaymentRecord>> getPayments();

  Future<List<Complaint>> getComplaints();
  Future<void> updateComplaintStatus(String complaintId, ComplaintStatus newStatus);

  Future<List<WelfareRecord>> getWelfareRecords();

  Future<List<AdminCustomerProfile>> getCustomers();

  /// Update customer details including name, phone, email, address, and assigned federation.
  Future<void> updateCustomerDetails({
    required String customerId,
    required String fullName,
    required String phone,
    String? email,
    String? state,
    String? district,
    String? city,
    String? area,
    String? address,
    String? federationId,
  });

  /// Modify customer booking / order (status, scheduled date/time, notes)
  Future<void> modifyBooking({
    required String bookingId,
    BookingStatus? status,
    String? scheduledDate,
    String? scheduledTime,
    String? notes,
  });

  Future<List<AdminService>> getServices();
  Future<void> toggleServiceStatus(String serviceId);

  /// Transfer a worker to a new cooperative federation (Super Admin action).
  Future<void> transferWorkerFederation(
    String workerId,
    String newFederationId,
    String newFederationName, {
    String? reason,
  });

  /// Provision a new Federation Admin with login credentials and assigned scope
  Future<Map<String, dynamic>> createFederationAdmin({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String federationId,
  });

  /// Get list of assigned federation admins, optionally filtered by federationId
  Future<List<Map<String, dynamic>>> getFederationAdmins({String? federationId});

  /// Reassign an assigned federation admin to a new federation.
  Future<void> reassignFederationAdmin({
    required String userId,
    required String newFederationId,
    String? oldFederationId,
  });

  /// Remove/de-assign an admin from a federation.
  Future<void> removeFederationAdmin({
    required String userId,
    required String federationId,
  });

  /// Reset or change a federation admin's password (Super Admin action).
  Future<void> resetFederationAdminPassword({
    required String userId,
    required String newPassword,
    bool requirePasswordChange = true,
  });

  /// Update federation admin user details (e.g. full name, phone).
  Future<void> updateFederationAdminDetails({
    required String userId,
    String? fullName,
    String? phone,
  });
}
