import '../../features/admin/data/models/admin_models.dart';
import '../../features/worker/data/models/worker_models.dart';

abstract class IAdminRepository {
  Future<AdminDashboardStats> getDashboardStats();

  Future<List<WorkerProfile>> getWorkers();
  Future<void> approveWorker(String workerId);
  Future<void> rejectWorker(String workerId);
  Future<void> suspendWorker(String workerId);

  /// Fetch KYC documents uploaded by a specific worker.
  Future<List<Map<String, dynamic>>> getWorkerDocuments(String workerId);

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
