import '../../features/admin/data/models/admin_models.dart';
import '../../features/worker/data/models/worker_models.dart';

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

  /// Fetch verification history audit trail for a worker.
  Future<List<WorkerVerificationHistoryItem>> getVerificationHistory(String workerId);

  Future<List<JobRequest>> getBookings();
  Stream<List<JobRequest>> watchBookings();
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus);

  Future<List<PaymentRecord>> getPayments();

  Future<List<Complaint>> getComplaints();
  Future<void> updateComplaintStatus(String complaintId, ComplaintStatus newStatus);

  Future<List<WelfareRecord>> getWelfareRecords();

  Future<List<AdminCustomerProfile>> getCustomers();

  Future<List<AdminService>> getServices();
  Future<void> toggleServiceStatus(String serviceId);
}
