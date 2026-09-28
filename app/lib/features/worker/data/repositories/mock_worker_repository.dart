import '../../../../core/repositories/i_worker_repository.dart';
import '../../../../core/services/shared_booking_store.dart';
import '../models/worker_models.dart';

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
      profileImage: 'https://via.placeholder.com/150',
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
  }
}
