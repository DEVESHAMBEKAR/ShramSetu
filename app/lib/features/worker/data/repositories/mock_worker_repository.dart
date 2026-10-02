import '../../../../core/repositories/i_worker_repository.dart';
import '../../../../core/services/shared_booking_store.dart';
import '../models/worker_models.dart';
import '../../../../core/models/insurance_models.dart';
import '../../../customer/data/models/customer_models.dart';
import '../../../customer/data/repositories/mock_customer_repository.dart';

class MockWorkerRepository implements IWorkerRepository {
  static final MockWorkerRepository _instance = MockWorkerRepository._internal();
  factory MockWorkerRepository() => _instance;

  MockWorkerRepository._internal() {
    _initDemoData();
  }

  late WorkerProfile currentWorker;

  void _initDemoData() {
    currentWorker = WorkerProfile(
      id: 'w101',
      name: 'Rahul Patil',
      profileImage: '',
      phone: '+91 98765 43210',
      skills: ['Plumbing', 'Pipe Fitting'],
      experience: '5 Years',
      rating: 4.88,
      reviewCount: 42,
      completedJobs: 126,
      earnings: 1850.0,
      isVerified: true,
      verificationStatus: VerificationStatus.approved,
      isAvailable: true,
      serviceLocation: 'Kothrud, Pune',
      guildName: 'Pune Plumbers Guild',
      guildId: '#128',
    );
  }

  @override
  Future<WorkerProfile> getWorkerProfile(String workerId) async {
    return currentWorker;
  }

  @override
  Future<void> updateWorkerAvailability(String workerId, bool isAvailable) async {
    currentWorker = currentWorker.copyWith(isAvailable: isAvailable);
  }

  @override
  Future<void> updateWorkerLocation(
    String workerId, {
    required double latitude,
    required double longitude,
    String? locationTag,
  }) async {
    currentWorker = currentWorker.copyWith(
      latitude: latitude,
      longitude: longitude,
      locationUpdatedAt: DateTime.now(),
      serviceLocation: locationTag ?? currentWorker.serviceLocation,
    );
  }

  @override
  Future<void> updateProfileImage(String workerId, String imageUrl) async {
    currentWorker = currentWorker.copyWith(profileImage: imageUrl);
  }

  @override
  Future<List<JobRequest>> getWorkerBookings() async {
    return SharedBookingStore.instance.getWorkerBookings();
  }

  @override
  Stream<List<JobRequest>> watchWorkerBookings() {
    return SharedBookingStore.instance.watchWorkerBookings();
  }

  @override
  Future<List<JobRequest>> getJobRequests(String workerId) async {
    return SharedBookingStore.instance.getWorkerBookings(workerId: workerId);
  }

  @override
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    await SharedBookingStore.instance.updateBookingStatus(bookingId, newStatus);
  }

  final List<Map<String, dynamic>> _mockDocuments = [];

  @override
  Future<List<Map<String, dynamic>>> getVerificationDocuments(String workerId) async {
    return _mockDocuments.where((d) => d['worker_id'] == workerId).toList();
  }

  @override
  Future<void> submitVerificationDocument(
    String workerId,
    String documentType,
    String storagePath,
    String fileName,
    String mimeType,
    int fileSize,
  ) async {
    _mockDocuments.removeWhere((d) => d['worker_id'] == workerId && d['document_type'] == documentType);
    _mockDocuments.add({
      'id': 'doc_${DateTime.now().millisecondsSinceEpoch}',
      'worker_id': workerId,
      'document_type': documentType,
      'storage_path': storagePath,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size': fileSize,
      'status': 'PENDING',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  final List<WorkerVerificationHistoryItem> _mockHistory = [];

  @override
  Future<List<WorkerVerificationHistoryItem>> getVerificationHistory(String workerId) async {
    return _mockHistory.where((h) => h.workerId == workerId).toList();
  }

  void addHistoryItem(WorkerVerificationHistoryItem item) {
    _mockHistory.insert(0, item);
  }

  @override
  Future<void> submitForVerification(String workerId) async {
    currentWorker = currentWorker.copyWith(
      verificationStatus: VerificationStatus.pending,
      isVerified: false,
    );
    addHistoryItem(WorkerVerificationHistoryItem(
      id: 'h_${DateTime.now().millisecondsSinceEpoch}',
      workerId: workerId,
      previousStatus: 'NOT_SUBMITTED',
      newStatus: 'PENDING',
      action: 'SUBMIT_REGISTRATION',
      remarks: 'Worker submitted registration for verification',
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<void> resubmitForVerification(String workerId) async {
    final prev = currentWorker.verificationStatus.label;
    currentWorker = currentWorker.copyWith(
      verificationStatus: VerificationStatus.underReview,
      isVerified: false,
    );
    addHistoryItem(WorkerVerificationHistoryItem(
      id: 'h_${DateTime.now().millisecondsSinceEpoch}',
      workerId: workerId,
      previousStatus: prev,
      newStatus: 'UNDER_REVIEW',
      action: 'RESUBMIT',
      remarks: 'Worker corrected and resubmitted required information',
      createdAt: DateTime.now(),
    ));
  }

  @override
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
  }) async {
    currentWorker = currentWorker.copyWith(
      id: workerId,
      name: fullName,
      phone: phone,
      skills: [skill],
      experience: '$experienceYears Years',
      serviceLocation: serviceLocation,
      dob: dob,
      gender: gender,
      address: address,
      city: city,
      district: district ?? 'Pune',
      pinCode: pinCode,
      trade: trade ?? skill,
      primarySkill: skill,
      skillLevel: skillLevel ?? 'Intermediate',
      guildName: federationName ?? 'Pune District Labour Cooperative Federation',
      membershipId: membershipId,
      bio: bio,
      declarationAccepted: declarationAccepted,
      isVerified: false,
      verificationStatus: VerificationStatus.pending,
      isAvailable: false,
    );

    final String catId;
    final lowerSkill = skill.toLowerCase();
    final lowerTrade = (trade ?? '').toLowerCase();
    if (lowerSkill.contains('elect') || lowerTrade.contains('elect')) {
      catId = 'c1';
    } else if (lowerSkill.contains('plumb') || lowerTrade.contains('plumb')) {
      catId = 'c2';
    } else if (lowerSkill.contains('carpent') || lowerTrade.contains('carpent')) {
      catId = 'c3';
    } else if (lowerSkill.contains('clean') || lowerTrade.contains('clean')) {
      catId = 'c4';
    } else if (lowerSkill.contains('paint') || lowerTrade.contains('paint')) {
      catId = 'c5';
    } else if (lowerSkill.contains('appliance') || lowerTrade.contains('appliance')) {
      catId = 'c6';
    } else if (lowerSkill.contains('garden') || lowerTrade.contains('yard')) {
      catId = 'c7';
    } else {
      catId = 'c2';
    }

    final newWorker = Worker(
      id: workerId,
      name: fullName,
      categoryId: catId,
      rate: 349,
      rating: 4.88,
      reviewCount: 34,
      jobsCompleted: 45,
      distanceKm: 1.5,
      experience: '$experienceYears yrs exp',
      availability: 'Available Today',
      specializations: [skill, trade ?? skill, 'Union Certified'],
      locationTag: serviceLocation.contains('Pune') ? serviceLocation : '$serviceLocation, Pune',
      imageUrl: '',
      customTag: 'Union Certified Artisan',
      bio: bio ?? 'Certified $skill artisan serving $serviceLocation with $experienceYears years of experience.',
      federationId: membershipId ?? 'PUN-UNION-2024',
      insuranceAmount: 'Up to ₹1,50,000',
      languages: ['मराठी', 'हिंदी', 'English'],
      serviceAreas: [serviceLocation.replaceAll(', Pune', '').trim(), 'Pune', 'All Areas'],
      isUnionGold: true,
      isCoopMaster: true,
    );

    MockCustomerRepository.registerOrUpdateWorker(newWorker);
  }

  @override
  Future<WorkerInsuranceModel?> getWorkerInsurance(String workerId) async {
    return WorkerInsuranceModel(
      workerId: workerId,
      policyNumber: 'FED-GRP-2024-${workerId.hashCode.abs() % 10000}',
      coverageAmount: 500000.0,
      status: InsuranceStatus.active,
      verificationStatus: InsuranceVerificationStatus.verified,
      providerName: 'Maharashtra State Cooperative Labour Federation Welfare Pool',
      claimSupportPhone: '1800-266-9090',
      claimInstructions: 'In case of workplace injury or hospitalization, notify your local federation secretary within 48 hours with hospital discharge summary.',
      validUntil: DateTime.now().add(const Duration(days: 240)),
      isExternalIntegrationPending: true,
    );
  }
}
