import '../../../../core/repositories/i_admin_repository.dart';
import '../models/admin_models.dart';
import '../../../worker/data/models/worker_models.dart';

class MockAdminRepository implements IAdminRepository {
  static final MockAdminRepository _instance = MockAdminRepository._internal();
  factory MockAdminRepository() => _instance;
  MockAdminRepository._internal() {
    _initializeMockData();
  }



  late AdminDashboardStats _dashboardStats;
  List<WorkerProfile> _workers = [];
  List<JobRequest> _bookings = [];
  List<PaymentRecord> _payments = [];
  List<Complaint> _complaints = [];
  List<WelfareRecord> _welfareRecords = [];
  List<AdminCustomerProfile> _customers = [];
  List<AdminService> _services = [];

  @override
  Future<AdminDashboardStats> getDashboardStats() async => _dashboardStats;
  @override
  Future<List<WorkerProfile>> getWorkers() async => _workers;
  @override
  Future<List<JobRequest>> getBookings() async => _bookings;
  @override
  Stream<List<JobRequest>> watchBookings() => Stream.value(List<JobRequest>.from(_bookings));
  @override
  Future<List<PaymentRecord>> getPayments() async => _payments;
  @override
  Future<List<Complaint>> getComplaints() async => _complaints;
  @override
  Future<List<WelfareRecord>> getWelfareRecords() async => _welfareRecords;
  @override
  Future<List<AdminCustomerProfile>> getCustomers() async => _customers;
  @override
  Future<List<AdminService>> getServices() async => _services;

  List<WorkerProfile> get pendingVerifications => _workers.where((w) => w.verificationStatus == VerificationStatus.pending).toList();



  @override
  Future<void> approveWorker(String workerId) async {
    final index = _workers.indexWhere((w) => w.id == workerId);
    if (index != -1) {
      _workers[index] = _workers[index].copyWith(
        verificationStatus: VerificationStatus.approved,
        isVerified: true,
      );
      _recalculateStats();
      
    }
  }

  @override
  Future<void> rejectWorker(String workerId) async {
    final index = _workers.indexWhere((w) => w.id == workerId);
    if (index != -1) {
      _workers[index] = _workers[index].copyWith(
        verificationStatus: VerificationStatus.rejected,
        isVerified: false,
        isAvailable: false,
      );
      _recalculateStats();
      
    }
  }

  @override
  Future<void> updateComplaintStatus(String complaintId, ComplaintStatus newStatus) async {
    final index = _complaints.indexWhere((c) => c.id == complaintId);
    if (index != -1) {
      final old = _complaints[index];
      _complaints[index] = Complaint(
        id: old.id,
        customerName: old.customerName,
        workerName: old.workerName,
        bookingId: old.bookingId,
        subject: old.subject,
        description: old.description,
        date: old.date,
        priority: old.priority,
        status: newStatus,
      );
      
    }
  }

  @override
  Future<void> toggleServiceStatus(String serviceId) async {
    final index = _services.indexWhere((s) => s.id == serviceId);
    if (index != -1) {
      final old = _services[index];
      _services[index] = AdminService(
        id: old.id,
        name: old.name,
        icon: old.icon,
        status: old.status == ServiceStatus.active ? ServiceStatus.inactive : ServiceStatus.active,
      );
      
    }
  }

  @override
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    final index = _bookings.indexWhere((b) => b.id == bookingId);
    if (index != -1) {
      _bookings[index] = _bookings[index].copyWith(status: newStatus);
      
    }
  }

  void _recalculateStats() {
    _dashboardStats = AdminDashboardStats(
      totalWorkers: _workers.length,
      verifiedWorkers: _workers.where((w) => w.verificationStatus == VerificationStatus.approved).length,
      pendingVerifications: _workers.where((w) => w.verificationStatus == VerificationStatus.pending).length,
      activeBookings: _bookings.where((b) => b.status != BookingStatus.completed && b.status != BookingStatus.rejected).length,
      escrowLocked: 148200.0,
      welfarePool: 482000.0,
      fairWorkIndex: 88.0,
    );
  }

  void _initializeMockData() {
    _workers = [
      WorkerProfile(
        id: 'W1',
        name: 'Ganesh Shinde',
        profileImage: '',
        phone: '+91 98765 43210',
        skills: ['Electrician'],
        experience: '5+ years',
        serviceLocation: 'Pune West',
        guildId: 'MH-8219',
        guildName: 'Pune Plumbers Guild',
        rating: 4.8,
        completedJobs: 18,
        earnings: 14280,
        isAvailable: true,
        isVerified: false,
        verificationStatus: VerificationStatus.pending,
      ),
      WorkerProfile(
        id: 'W2',
        name: 'Sunita Kamble',
        profileImage: '',
        phone: '+91 98765 43211',
        skills: ['Deep Cleaning'],
        experience: '3+ years',
        serviceLocation: 'Pune City',
        guildId: 'SHG-102',
        guildName: 'Pune Women Collective',
        rating: 4.9,
        completedJobs: 45,
        earnings: 28000,
        isAvailable: true,
        isVerified: false,
        verificationStatus: VerificationStatus.pending,
      ),
      WorkerProfile(
        id: 'W3',
        name: 'Ramesh Deshpande',
        profileImage: '',
        phone: '+91 98765 43212',
        skills: ['Plumber'],
        experience: '10+ years',
        serviceLocation: 'Kothrud',
        guildId: 'MH-1122',
        guildName: 'Pune Plumbers Guild',
        rating: 4.7,
        completedJobs: 120,
        earnings: 85000,
        isAvailable: true,
        isVerified: true,
        verificationStatus: VerificationStatus.approved,
      ),
    ];

    _customers = [
      AdminCustomerProfile(id: 'C1', name: 'Amit Patil', phone: '+91 9988776655', totalBookings: 5, lastBooking: DateTime.now().subtract(const Duration(days: 2)), status: 'Active'),
      AdminCustomerProfile(id: 'C2', name: 'Neha Sharma', phone: '+91 9988776656', totalBookings: 12, lastBooking: DateTime.now().subtract(const Duration(days: 10)), status: 'Active'),
    ];

    _bookings = [
      JobRequest(
        id: 'SS-8941',
        customerId: 'C1',
        customerName: 'Amit Patil',
        customerLocation: 'Kothrud, Pune',
        customerPhone: '+91 9988776655',
        serviceName: 'Plumbing Repair',
        date: 'Today',
        time: '10:00 AM',
        baseAmount: 100,
        laborAllowance: 20,
        status: BookingStatus.inProgress,
        createdAt: DateTime.now().toString(),
      ),
      JobRequest(
        id: 'SS-8942',
        customerId: 'C2',
        customerName: 'Neha Sharma',
        customerLocation: 'Baner, Pune',
        customerPhone: '+91 9988776656',
        serviceName: 'AC Servicing',
        date: 'Yesterday',
        time: '04:00 PM',
        baseAmount: 600,
        laborAllowance: 200,
        status: BookingStatus.completed,
        createdAt: DateTime.now().subtract(const Duration(days: 1)).toString(),
      ),
    ];

    _payments = [
      PaymentRecord(id: 'P1', bookingId: 'SS-8942', customerName: 'Neha Sharma', workerName: 'Ganesh Shinde', amount: 800, status: PaymentStatus.paid, date: DateTime.now().subtract(const Duration(days: 1)), method: 'UPI'),
      PaymentRecord(id: 'P2', bookingId: 'SS-8941', customerName: 'Amit Patil', workerName: 'Ramesh Deshpande', amount: 120, status: PaymentStatus.pending, date: DateTime.now(), method: 'Escrow'),
    ];

    _complaints = [
      Complaint(id: 'CMP-01', customerName: 'Amit Patil', workerName: 'Ramesh Deshpande', bookingId: 'SS-8941', subject: 'Extra Pipe Fitting Charge', description: 'Plumber replaced an unlisted brass elbow fitting due to leakage risk. Customer requested guild tariff verification.', date: DateTime.now(), priority: 'High', status: ComplaintStatus.open),
    ];

    _welfareRecords = [
      WelfareRecord(id: 'WLF-01', title: 'Tool Loan Applications', details: '2 requests • Subsidized 4% APR', type: 'Loan', status: 'Pending Review'),
      WelfareRecord(id: 'WLF-02', title: 'Hospitalization Cover Claim', details: '1 claim • Ward #12 Cashless Pool', type: 'Insurance', status: 'Pending Review'),
    ];

    _services = [
      AdminService(id: 'S1', name: 'Electrician', icon: 'electric_bolt', status: ServiceStatus.active),
      AdminService(id: 'S2', name: 'Plumber', icon: 'plumbing', status: ServiceStatus.active),
      AdminService(id: 'S3', name: 'Cleaner', icon: 'cleaning_services', status: ServiceStatus.active),
      AdminService(id: 'S4', name: 'Carpenter', icon: 'carpenter', status: ServiceStatus.active),
    ];

    _recalculateStats();
  }

  @override
  Future<void> suspendWorker(String workerId) async {}

  @override
  Future<List<Map<String, dynamic>>> getWorkerDocuments(String workerId) async {
    return [];
  }
}
