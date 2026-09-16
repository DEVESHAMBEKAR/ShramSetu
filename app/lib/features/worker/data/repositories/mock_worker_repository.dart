import '../../../../core/repositories/i_worker_repository.dart';
import '../../../../core/config/dependency_injection.dart';
import '../models/worker_models.dart';

class MockWorkerRepository implements IWorkerRepository {
  static final MockWorkerRepository _instance = MockWorkerRepository._internal();
  factory MockWorkerRepository() => _instance;

  MockWorkerRepository._internal() {
    _initDemoData();
  }

  late WorkerProfile currentWorker;
  List<JobRequest> _jobRequests = [];

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

    _jobRequests = [
      JobRequest(
        id: 'j1',
        customerId: 'c1',
        customerName: 'Ananya Sharma',
        customerLocation: 'Flat 402, Sai Shraddha Apts',
        customerPhone: '+91 91234 56789',
        serviceName: 'Plumbing Inspection',
        date: 'Today',
        time: '11:00 AM',
        baseAmount: 399.0,
        laborAllowance: 86.0,
        status: BookingStatus.pending,
        distanceKm: '1.8 km',
        createdAt: '4m ago',
      ),
    ];
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
    return _jobRequests;
  }

  @override
  Stream<List<JobRequest>> watchWorkerBookings() {
    return Stream.value(List<JobRequest>.from(_jobRequests));
  }

  @override
  Future<List<JobRequest>> getJobRequests(String workerId) async {
    return _jobRequests;
  }

  @override
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    final index = _jobRequests.indexWhere((j) => j.id == bookingId);
    if (index != -1) {
      final job = _jobRequests[index];
      _jobRequests[index] = job.copyWith(status: newStatus);
      try {
        await DI.notificationRepo.sendPushNotification(
          recipientUserId: job.customerId,
          type: 'booking_status',
          title: 'Booking Update',
          body: 'Booking status updated to ${newStatus.label}',
          data: {'bookingId': bookingId, 'status': newStatus.toDbString()},
        );
      } catch (_) {}
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getVerificationDocuments(String workerId) async { return []; }

  @override
  Future<void> submitVerificationDocument(String workerId, String documentType, String storagePath, String fileName, String mimeType, int fileSize) async {}

  @override
  Future<void> submitForVerification(String workerId) async {}
}
