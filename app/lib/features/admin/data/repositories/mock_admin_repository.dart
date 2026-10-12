import '../../../../core/repositories/i_admin_repository.dart';
import '../../../../core/services/shared_booking_store.dart';
import '../../../../core/models/insurance_models.dart';
import '../../../../core/models/federation_models.dart';
import '../../../../core/config/dependency_injection.dart';
import '../models/admin_models.dart';
import '../../../worker/data/models/worker_models.dart';
import '../../../customer/data/models/customer_models.dart';
import '../../../customer/data/repositories/mock_customer_repository.dart';

class MockAdminRepository implements IAdminRepository {
  static final MockAdminRepository _instance = MockAdminRepository._internal();
  factory MockAdminRepository() => _instance;
  MockAdminRepository._internal() {
    _initializeMockData();
  }

  late AdminDashboardStats _dashboardStats;
  List<WorkerProfile> _workers = [];
  List<PaymentRecord> _payments = [];
  List<Complaint> _complaints = [];
  List<WelfareRecord> _welfareRecords = [];
  List<AdminCustomerProfile> _customers = [];
  List<AdminService> _services = [];

  Future<List<String>> _getFederationFilter() async {
    try {
      final scope = DI.federationScopeService;
      if (scope == null) return [];
      return await scope.getAuthorizedFederationIds();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<AdminDashboardStats> getDashboardStats() async {
    final scopedWorkers = await getWorkers();
    final bookings = SharedBookingStore.instance.getAllBookings();
    _dashboardStats = AdminDashboardStats(
      totalWorkers: scopedWorkers.length,
      verifiedWorkers: scopedWorkers.where((w) => w.verificationStatus == VerificationStatus.approved).length,
      pendingVerifications: scopedWorkers.where((w) => w.verificationStatus == VerificationStatus.pending).length,
      activeBookings: bookings.where((b) => b.status != BookingStatus.completed && b.status != BookingStatus.rejected && b.status != BookingStatus.cancelled).length,
      escrowLocked: 148200.0,
      welfarePool: 482000.0,
      fairWorkIndex: 88.0,
    );
    return _dashboardStats;
  }

  @override
  Future<List<WorkerProfile>> getWorkers() async {
    final federationFilter = await _getFederationFilter();
    if (federationFilter.isEmpty) {
      return _workers;
    }
    return _workers.where((w) {
      return w.federationRefId != null && federationFilter.contains(w.federationRefId);
    }).toList();
  }

  @override
  Future<List<JobRequest>> getBookings() async => SharedBookingStore.instance.getAllBookings();

  @override
  Stream<List<JobRequest>> watchBookings() => SharedBookingStore.instance.watchAllBookings();

  @override
  Future<List<PaymentRecord>> getPayments() async => _payments;
  @override
  Future<List<Complaint>> getComplaints() async => _complaints;
  @override
  Future<List<WelfareRecord>> getWelfareRecords() async => _welfareRecords;

  @override
  Future<List<AdminCustomerProfile>> getCustomers() async {
    final federationFilter = await _getFederationFilter();
    if (federationFilter.isEmpty) {
      return _customers;
    }
    return _customers.where((c) {
      if (c.federationId != null && federationFilter.contains(c.federationId)) {
        return true;
      }
      for (final fedId in federationFilter) {
        final pool = FederationModel.activePool;
        final fed = pool.firstWhere(
          (f) => f.id == fedId,
          orElse: () => FederationModel.resolveFederation(federationId: fedId),
        );
        if ((c.district != null && c.district!.toLowerCase() == fed.district.toLowerCase()) ||
            (c.city != null && c.city!.toLowerCase() == fed.city.toLowerCase()) ||
            (c.federationName != null && c.federationName!.toLowerCase().contains(fed.name.toLowerCase()))) {
          return true;
        }
      }
      return false;
    }).toList();
  }

  @override
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
  }) async {
    final targetFedId = federationId ??
        FederationModel.resolveFederation(
          district: district,
          city: city,
          state: state,
          location: area,
          address: address,
        ).id;
    final fedName = FederationModel.resolveFederation(federationId: targetFedId).name;

    final index = _customers.indexWhere((c) => c.id == customerId);
    if (index != -1) {
      final old = _customers[index];
      _customers[index] = AdminCustomerProfile(
        id: old.id,
        name: fullName.trim(),
        phone: phone.trim(),
        email: email?.trim() ?? old.email,
        totalBookings: old.totalBookings,
        lastBooking: old.lastBooking,
        status: old.status,
        state: state ?? old.state,
        district: district ?? old.district,
        city: city ?? old.city,
        area: area ?? address ?? old.area,
        federationId: targetFedId,
        federationName: fedName,
        createdAt: old.createdAt,
      );
    } else {
      _customers.insert(
        0,
        AdminCustomerProfile(
          id: customerId,
          name: fullName.trim(),
          phone: phone.trim(),
          email: email?.trim(),
          totalBookings: 0,
          lastBooking: DateTime.now(),
          status: 'Active',
          state: state ?? 'Maharashtra',
          district: district ?? 'Pune',
          city: city ?? 'Pune',
          area: area ?? address ?? '',
          federationId: targetFedId,
          federationName: fedName,
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  @override
  Future<void> modifyBooking({
    required String bookingId,
    BookingStatus? status,
    String? scheduledDate,
    String? scheduledTime,
    String? notes,
  }) async {
    await SharedBookingStore.instance.updateBookingDetails(
      bookingId,
      status: status,
      scheduledDate: scheduledDate,
      scheduledTime: scheduledTime,
      notes: notes,
    );
    _recalculateStats();
  }

  @override
  Future<List<AdminService>> getServices() async => _services;

  List<WorkerProfile> get pendingVerifications => _workers.where((w) => w.verificationStatus == VerificationStatus.pending).toList();



  final List<WorkerVerificationHistoryItem> _history = [];

  @override
  Future<List<WorkerVerificationHistoryItem>> getVerificationHistory(String workerId) async {
    return _history.where((h) => h.workerId == workerId).toList();
  }

  void _recordHistory(String workerId, String prevStatus, String newStatus, String action, String? remarks) {
    _history.insert(0, WorkerVerificationHistoryItem(
      id: 'vh_${DateTime.now().millisecondsSinceEpoch}',
      workerId: workerId,
      adminId: 'admin_officer_01',
      adminName: 'Federation Officer Desk',
      previousStatus: prevStatus,
      newStatus: newStatus,
      action: action,
      remarks: remarks,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<void> startReview(String workerId, {String? remarks}) async {
    final index = _workers.indexWhere((w) => w.id == workerId);
    if (index != -1) {
      final prev = _workers[index].verificationStatus.name.toUpperCase();
      _workers[index] = _workers[index].copyWith(
        verificationStatus: VerificationStatus.underReview,
        verificationRemarks: remarks ?? 'Federation Officer has initiated document review',
      );
      _recordHistory(workerId, prev, 'UNDER_REVIEW', 'START_REVIEW', remarks);
      _recalculateStats();
    }
  }

  @override
  Future<void> approveWorker(String workerId, {String? remarks}) async {
    final index = _workers.indexWhere((w) => w.id == workerId);
    if (index != -1) {
      final prev = _workers[index].verificationStatus.name.toUpperCase();
      final updatedProfile = _workers[index].copyWith(
        verificationStatus: VerificationStatus.approved,
        isVerified: true,
        isAvailable: true,
        verificationRemarks: remarks ?? 'Verified by Federation Officer',
      );
      _workers[index] = updatedProfile;
      _recordHistory(workerId, prev, 'APPROVED', 'APPROVE', remarks);
      _recalculateStats();

      // Ensure approved worker is immediately accessible in Customer console
      final catId = updatedProfile.skills.any((s) => s.toLowerCase().contains('elect'))
          ? 'c1'
          : updatedProfile.skills.any((s) => s.toLowerCase().contains('clean'))
              ? 'c4'
              : 'c2';

      MockCustomerRepository.registerOrUpdateWorker(Worker(
        id: updatedProfile.id,
        name: updatedProfile.name,
        categoryId: catId,
        rate: 349,
        rating: updatedProfile.rating > 0 ? updatedProfile.rating : 4.85,
        reviewCount: updatedProfile.reviewCount > 0 ? updatedProfile.reviewCount : 15,
        jobsCompleted: updatedProfile.completedJobs,
        distanceKm: 1.8,
        experience: updatedProfile.experience,
        availability: 'Available Today',
        specializations: updatedProfile.skills,
        locationTag: updatedProfile.serviceLocation.contains('Pune')
            ? updatedProfile.serviceLocation
            : '${updatedProfile.serviceLocation}, Pune',
        imageUrl: updatedProfile.profileImage,
        customTag: 'Union Approved Artisan',
        bio: 'Certified union artisan registered with Pune Cooperative Federation.',
        federationId: updatedProfile.guildId,
        insuranceAmount: 'Up to ₹1,50,000',
        languages: const ['मराठी', 'हिंदी'],
        serviceAreas: [
          updatedProfile.serviceLocation.replaceAll(', Pune', '').trim(),
          'Pune',
          'All Areas'
        ],
        isUnionGold: true,
        isCoopMaster: true,
      ));
    }
  }

  @override
  Future<void> requestChanges(String workerId, {required String remarks}) async {
    final index = _workers.indexWhere((w) => w.id == workerId);
    if (index != -1) {
      final prev = _workers[index].verificationStatus.name.toUpperCase();
      _workers[index] = _workers[index].copyWith(
        verificationStatus: VerificationStatus.changesRequired,
        isVerified: false,
        verificationRemarks: remarks,
      );
      _recordHistory(workerId, prev, 'CHANGES_REQUIRED', 'REQUEST_CHANGES', remarks);
      _recalculateStats();
    }
  }

  @override
  Future<void> rejectWorker(String workerId, {String? remarks}) async {
    final index = _workers.indexWhere((w) => w.id == workerId);
    if (index != -1) {
      final prev = _workers[index].verificationStatus.name.toUpperCase();
      _workers[index] = _workers[index].copyWith(
        verificationStatus: VerificationStatus.rejected,
        isVerified: false,
        isAvailable: false,
        verificationRemarks: remarks ?? 'Application rejected',
      );
      _recordHistory(workerId, prev, 'REJECTED', 'REJECT', remarks);
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
    await SharedBookingStore.instance.updateBookingStatus(bookingId, newStatus);
    _recalculateStats();
  }

  void _recalculateStats() {
    final bookings = SharedBookingStore.instance.getAllBookings();
    _dashboardStats = AdminDashboardStats(
      totalWorkers: _workers.length,
      verifiedWorkers: _workers.where((w) => w.verificationStatus == VerificationStatus.approved).length,
      pendingVerifications: _workers.where((w) => w.verificationStatus == VerificationStatus.pending).length,
      activeBookings: bookings.where((b) => b.status != BookingStatus.completed && b.status != BookingStatus.rejected && b.status != BookingStatus.cancelled).length,
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
        district: 'Pune',
        state: 'Maharashtra',
        guildId: 'MH-PUN-01',
        guildName: 'Pune District Labour Cooperative Federation',
        federationRefId: '11111111-0000-0000-0000-000000000001',
        rating: 4.8,
        completedJobs: 18,
        earnings: 14280,
        isAvailable: true,
        isVerified: false,
        verificationStatus: VerificationStatus.pending,
        trade: 'Electrician',
        primarySkill: 'Wiring & Panels',
        registeredAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      WorkerProfile(
        id: 'W2',
        name: 'Sunita Kamble',
        profileImage: '',
        phone: '+91 98765 43211',
        skills: ['Deep Cleaning'],
        experience: '3+ years',
        serviceLocation: 'Shivaji Nagar',
        district: 'Pune',
        state: 'Maharashtra',
        guildId: 'MH-PUN-02',
        guildName: 'Pune District Labour Cooperative Federation',
        federationRefId: '11111111-0000-0000-0000-000000000001',
        rating: 4.9,
        completedJobs: 45,
        earnings: 28000,
        isAvailable: true,
        isVerified: false,
        verificationStatus: VerificationStatus.pending,
        trade: 'Housekeeping',
        primarySkill: 'Deep Sanitization',
        registeredAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      WorkerProfile(
        id: 'W3',
        name: 'Ramesh Deshpande',
        profileImage: '',
        phone: '+91 98765 43212',
        skills: ['Plumber'],
        experience: '10+ years',
        serviceLocation: 'Kothrud',
        district: 'Pune',
        state: 'Maharashtra',
        guildId: 'MH-PUN-03',
        guildName: 'Pune District Labour Cooperative Federation',
        federationRefId: '11111111-0000-0000-0000-000000000001',
        rating: 4.7,
        completedJobs: 120,
        earnings: 85000,
        isAvailable: true,
        isVerified: true,
        verificationStatus: VerificationStatus.approved,
        trade: 'Plumber',
        primarySkill: 'Pipe Fitting & Leakage',
        registeredAt: DateTime.now().subtract(const Duration(days: 20)),
      ),
      WorkerProfile(
        id: 'W4',
        name: 'Kavita More',
        profileImage: '',
        phone: '+91 98765 43213',
        skills: ['Carpenter'],
        experience: '7+ years',
        serviceLocation: 'Panchavati',
        district: 'Nashik',
        state: 'Maharashtra',
        guildId: 'MH-NSK-01',
        guildName: 'Nashik District Artisans Cooperative Union',
        federationRefId: '22222222-0000-0000-0000-000000000002',
        rating: 4.8,
        completedJobs: 62,
        earnings: 52000,
        isAvailable: true,
        isVerified: false,
        verificationStatus: VerificationStatus.pending,
        trade: 'Carpenter',
        primarySkill: 'Furniture & Woodwork',
        registeredAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      WorkerProfile(
        id: 'W5',
        name: 'Mohd Rafiq',
        profileImage: '',
        phone: '+91 98765 43214',
        skills: ['Painter'],
        experience: '8+ years',
        serviceLocation: 'Andheri West',
        district: 'Mumbai City',
        state: 'Maharashtra',
        guildId: 'MH-MUM-01',
        guildName: 'Mumbai Metropolitan Labour Federation',
        federationRefId: '33333333-0000-0000-0000-000000000003',
        rating: 4.6,
        completedJobs: 88,
        earnings: 67000,
        isAvailable: true,
        isVerified: false,
        verificationStatus: VerificationStatus.pending,
        trade: 'Painter',
        primarySkill: 'Interior Texture Painting',
        registeredAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      WorkerProfile(
        id: 'W6',
        name: 'Santosh Bisen',
        profileImage: '',
        phone: '+91 98765 43215',
        skills: ['Mason'],
        experience: '12+ years',
        serviceLocation: 'Sitabuldi',
        district: 'Nagpur',
        state: 'Maharashtra',
        guildId: 'MH-NGP-01',
        guildName: 'Nagpur District Shramik Cooperative Union',
        federationRefId: '55555555-0000-0000-0000-000000000005',
        rating: 4.9,
        completedJobs: 140,
        earnings: 94000,
        isAvailable: true,
        isVerified: true,
        verificationStatus: VerificationStatus.approved,
        trade: 'Mason',
        primarySkill: 'Tiling & Structural Masonry',
        registeredAt: DateTime.now().subtract(const Duration(days: 45)),
      ),
    ];

    _customers = [
      AdminCustomerProfile(
        id: 'C1',
        name: 'Amit Patil',
        phone: '+91 9988776655',
        email: 'amit.patil@gmail.com',
        totalBookings: 5,
        lastBooking: DateTime.now().subtract(const Duration(days: 2)),
        status: 'Active',
        city: 'Pune',
        district: 'Pune',
        state: 'Maharashtra',
        area: 'Kothrud',
        federationId: '11111111-0000-0000-0000-000000000001',
        federationName: 'Pune District Labour Cooperative Federation',
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
      AdminCustomerProfile(
        id: 'C2',
        name: 'Neha Sharma',
        phone: '+91 9988776656',
        email: 'neha.sharma@gmail.com',
        totalBookings: 12,
        lastBooking: DateTime.now().subtract(const Duration(days: 10)),
        status: 'Active',
        city: 'Pune',
        district: 'Pune',
        state: 'Maharashtra',
        area: 'Baner',
        federationId: '11111111-0000-0000-0000-000000000001',
        federationName: 'Pune District Labour Cooperative Federation',
        createdAt: DateTime.now().subtract(const Duration(days: 120)),
      ),
      AdminCustomerProfile(
        id: 'C3',
        name: 'Rajesh Jadhav',
        phone: '+91 9988776657',
        email: 'rajesh.jadhav@gmail.com',
        totalBookings: 3,
        lastBooking: DateTime.now().subtract(const Duration(days: 4)),
        status: 'Active',
        city: 'Nashik',
        district: 'Nashik',
        state: 'Maharashtra',
        area: 'College Road',
        federationId: '22222222-0000-0000-0000-000000000002',
        federationName: 'Nashik District Artisans Cooperative Union',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      AdminCustomerProfile(
        id: 'C4',
        name: 'Priya Merchant',
        phone: '+91 9988776658',
        email: 'priya.merchant@gmail.com',
        totalBookings: 9,
        lastBooking: DateTime.now().subtract(const Duration(days: 1)),
        status: 'Active',
        city: 'Mumbai',
        district: 'Mumbai City',
        state: 'Maharashtra',
        area: 'Bandra West',
        federationId: '33333333-0000-0000-0000-000000000003',
        federationName: 'Mumbai Metropolitan Labour Federation',
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
      ),
      AdminCustomerProfile(
        id: 'C5',
        name: 'Manoj Verma',
        phone: '+91 9988776659',
        email: 'manoj.verma@gmail.com',
        totalBookings: 2,
        lastBooking: DateTime.now().subtract(const Duration(days: 15)),
        status: 'Active',
        city: 'Nagpur',
        district: 'Nagpur',
        state: 'Maharashtra',
        area: 'Dharampeth',
        federationId: '55555555-0000-0000-0000-000000000005',
        federationName: 'Nagpur District Shramik Cooperative Union',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
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
  Future<void> suspendWorker(String workerId, {String? remarks}) async {
    final index = _workers.indexWhere((w) => w.id == workerId);
    if (index != -1) {
      final prev = _workers[index].verificationStatus.name.toUpperCase();
      _workers[index] = _workers[index].copyWith(
        verificationStatus: VerificationStatus.suspended,
        isVerified: false,
        isAvailable: false,
        verificationRemarks: remarks ?? 'Account suspended by administrator',
      );
      _recordHistory(workerId, prev, 'SUSPENDED', 'SUSPEND', remarks);
      _recalculateStats();
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getWorkerDocuments(String workerId) async {
    return [
      {
        'id': 'doc_01',
        'worker_id': workerId,
        'document_type': 'IDENTITY',
        'file_name': 'aadhaar_card_${workerId.toLowerCase()}.pdf',
        'mime_type': 'application/pdf',
        'file_size': 1024 * 450,
        'storage_path': '$workerId/IDENTITY-sample.pdf',
        'status': 'PENDING',
        'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      },
      {
        'id': 'doc_02',
        'worker_id': workerId,
        'document_type': 'ADDRESS',
        'file_name': 'electricity_bill_pune.jpg',
        'mime_type': 'image/jpeg',
        'file_size': 1024 * 780,
        'storage_path': '$workerId/ADDRESS-sample.jpg',
        'status': 'PENDING',
        'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      },
      {
        'id': 'doc_03',
        'worker_id': workerId,
        'document_type': 'SKILL_CERTIFICATE',
        'file_name': 'iti_trade_certificate.pdf',
        'mime_type': 'application/pdf',
        'file_size': 1024 * 920,
        'storage_path': '$workerId/SKILL_CERTIFICATE-sample.pdf',
        'status': 'PENDING',
        'created_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      },
    ];
  }

  @override
  Future<void> updateDocumentStatus(String documentId, String status, {String? remarks}) async {
    // Mock: no persistent state — documents regenerated fresh per getWorkerDocuments() call.
    await Future.delayed(const Duration(milliseconds: 200));
  }

  static final WorkerInsuranceModel _samplePolicy = WorkerInsuranceModel(
    workerId: 'test-worker-01',
    policyNumber: 'NIC-GRP-2026-8941',
    coverageAmount: 500000.0,
    status: InsuranceStatus.active,
    verificationStatus: InsuranceVerificationStatus.verified,
  );

  final Map<String, WorkerInsuranceModel> _insuranceMap = {
    'test-worker-01': _samplePolicy,
  };

  @override
  Future<WorkerInsuranceModel?> getWorkerInsurance(String workerId) async {
    return _insuranceMap[workerId];
  }

  @override
  Future<void> updateWorkerInsurance(WorkerInsuranceModel insurance) async {
    _insuranceMap[insurance.workerId] = insurance;
  }

  @override
  Future<WorkerInsuranceModel> approveWorkerInsurance(String workerId, {String? remarks}) async {
    final year = DateTime.now().year;
    final suffix = (workerId.hashCode.abs() % 9000 + 1000).toString();
    final policyNumber = 'POL-$year-$suffix';
    final approved = WorkerInsuranceModel(
      workerId: workerId,
      policyNumber: policyNumber,
      coverageAmount: 500000.0,
      status: InsuranceStatus.active,
      verificationStatus: InsuranceVerificationStatus.verified,
      providerName: 'Maharashtra State Cooperative Labour Federation Welfare Pool',
      claimSupportPhone: '1800-266-9090',
      claimInstructions: 'In case of workplace injury or hospitalization, notify your local federation secretary within 48 hours with hospital discharge summary.',
      startDate: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 365)),
      adminRemarks: remarks ?? 'Approved and policy issued by Federation Admin',
      isExternalIntegrationPending: true,
    );
    _insuranceMap[workerId] = approved;
    return approved;
  }

  @override
  Future<void> transferWorkerFederation(
    String workerId,
    String newFederationId,
    String newFederationName, {
    String? reason,
  }) async {
    final idx = _workers.indexWhere((w) => w.id == workerId);
    if (idx != -1) {
      final old = _workers[idx];
      final pool = FederationModel.activePool;
      final targetFed = pool.firstWhere(
        (f) => f.id == newFederationId,
        orElse: () => FederationModel.resolveFederation(
          federationId: newFederationId,
          federationName: newFederationName,
        ),
      );
      _workers[idx] = WorkerProfile(
        id: old.id,
        name: old.name,
        phone: old.phone,
        profileImage: old.profileImage,
        skills: old.skills,
        experience: old.experience,
        rating: old.rating,
        completedJobs: old.completedJobs,
        isVerified: old.isVerified,
        isAvailable: old.isAvailable,
        verificationStatus: old.verificationStatus,
        earnings: old.earnings,
        guildId: old.guildId,
        guildName: newFederationName,
        serviceLocation: targetFed.city.isNotEmpty ? targetFed.city : targetFed.district,
        dob: old.dob,
        gender: old.gender,
        district: targetFed.district,
        city: targetFed.city,
        state: targetFed.state,
        pinCode: old.pinCode,
        trade: old.trade,
        primarySkill: old.primarySkill,
        skillLevel: old.skillLevel,
        membershipId: old.membershipId,
        verificationRemarks: old.verificationRemarks,
        registeredAt: old.registeredAt,
        federationRefId: newFederationId,
      );
    }
  }

  void resetMockData() {
    _initializeMockData();
    _federationAdmins.clear();
    _federationAdmins.addAll([
      {
        'id': 'scope-pune-admin-1',
        'user_id': 'ambekar-devesh-pune-uid',
        'email': 'ambekardevesh2@gmail.com',
        'full_name': 'Devesh Ambekar',
        'phone': '+91 98220 12345',
        'role': 'FEDERATION_ADMIN',
        'federation_id': '11111111-0000-0000-0000-000000000001',
        'federation_name': 'Pune District Labour Cooperative Federation',
        'scope_level': 'FEDERATION',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'scope-nashik-admin-1',
        'user_id': 'adil-atar-nashik-uid',
        'email': 'adilatar9494@gmail.com',
        'full_name': 'Adil Atar',
        'phone': '7822027271',
        'role': 'FEDERATION_ADMIN',
        'federation_id': '22222222-0000-0000-0000-000000000002',
        'federation_name': 'Nashik District Artisans Cooperative Union',
        'scope_level': 'FEDERATION',
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      },
    ]);
  }

  final List<Map<String, dynamic>> _federationAdmins = [
    {
      'id': 'scope-pune-admin-1',
      'user_id': 'ambekar-devesh-pune-uid',
      'email': 'ambekardevesh2@gmail.com',
      'full_name': 'Devesh Ambekar',
      'phone': '+91 98220 12345',
      'role': 'FEDERATION_ADMIN',
      'federation_id': '11111111-0000-0000-0000-000000000001',
      'federation_name': 'Pune District Labour Cooperative Federation',
      'scope_level': 'FEDERATION',
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'scope-nashik-admin-1',
      'user_id': 'adil-atar-nashik-uid',
      'email': 'adilatar9494@gmail.com',
      'full_name': 'Adil Atar',
      'phone': '7822027271',
      'role': 'FEDERATION_ADMIN',
      'federation_id': '22222222-0000-0000-0000-000000000002',
      'federation_name': 'Nashik District Artisans Cooperative Union',
      'scope_level': 'FEDERATION',
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    },
  ];

  @override
  Future<Map<String, dynamic>> createFederationAdmin({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String federationId,
  }) async {
    final entry = {
      'id': 'scope-${DateTime.now().millisecondsSinceEpoch}',
      'user_id': 'user-${DateTime.now().millisecondsSinceEpoch}',
      'email': email.trim().toLowerCase(),
      'full_name': fullName.trim(),
      'phone': phone.trim(),
      'role': 'FEDERATION_ADMIN',
      'federation_id': federationId,
      'scope_level': 'FEDERATION',
      'is_active': true,
      'created_at': DateTime.now().toIso8601String(),
    };
    _federationAdmins.add(entry);
    return {'success': true, 'admin': entry};
  }

  @override
  Future<List<Map<String, dynamic>>> getFederationAdmins({String? federationId}) async {
    if (federationId != null) {
      return _federationAdmins.where((a) => a['federation_id'] == federationId).toList();
    }
    return List.from(_federationAdmins);
  }

  @override
  Future<void> reassignFederationAdmin({
    required String userId,
    required String newFederationId,
    String? oldFederationId,
  }) async {
    final index = _federationAdmins.indexWhere((a) =>
        a['user_id'] == userId &&
        (oldFederationId == null || a['federation_id'] == oldFederationId));
    if (index != -1) {
      final old = _federationAdmins[index];
      String newFedName = 'Assigned Cooperative';
      final fed = FederationModel.defaultFederations.where((f) => f.id == newFederationId).firstOrNull;
      if (fed != null) {
        newFedName = fed.name;
      }
      _federationAdmins[index] = {
        ...old,
        'federation_id': newFederationId,
        'federation_name': newFedName,
        'updated_at': DateTime.now().toIso8601String(),
      };
    }
  }

  @override
  Future<void> removeFederationAdmin({
    required String userId,
    required String federationId,
  }) async {
    _federationAdmins.removeWhere((a) =>
        a['user_id'] == userId && a['federation_id'] == federationId);
  }

  @override
  Future<void> resetFederationAdminPassword({
    required String userId,
    required String newPassword,
    bool requirePasswordChange = true,
  }) async {
    final index = _federationAdmins.indexWhere((a) => a['user_id'] == userId || a['email'] == userId);
    if (index != -1) {
      _federationAdmins[index] = {
        ..._federationAdmins[index],
        'requires_password_change': requirePasswordChange,
        'password': newPassword,
        'updated_at': DateTime.now().toIso8601String(),
      };
    }
  }

  @override
  Future<void> updateFederationAdminDetails({
    required String userId,
    String? fullName,
    String? phone,
  }) async {
    final index = _federationAdmins.indexWhere((a) => a['user_id'] == userId || a['email'] == userId);
    if (index != -1) {
      final old = _federationAdmins[index];
      _federationAdmins[index] = {
        ...old,
        if (fullName != null && fullName.trim().isNotEmpty) 'full_name': fullName.trim(),
        if (phone != null) 'phone': phone.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    }
  }
}
