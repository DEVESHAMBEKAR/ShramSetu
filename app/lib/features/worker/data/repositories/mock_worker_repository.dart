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

  @override
  Future<List<Map<String, dynamic>>> getVerificationDocuments(String workerId) async { return []; }

  @override
  Future<void> submitVerificationDocument(String workerId, String documentType, String storagePath, String fileName, String mimeType, int fileSize) async {}

  @override
  Future<void> submitForVerification(String workerId) async {}
}
