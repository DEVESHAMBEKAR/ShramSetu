import '../../../../core/repositories/i_worker_repository.dart';
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
      profileImage: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAo50UE2TDpCrs0o9APTS_r4zhN7e_iEI76JZkY_6xhmXkf8YwnmzZ40CceO-8ajPaD6Zbg6W6j0w64zgwkkYGWcrWo6r6FcioBvYb-1EhemAfrZrnghpAqoDwb5ZVqHB9Zxahhh4_nl_apEk4e7NVa-klCmmnxKt1Rbe3t7NEkLaSy90ujsklxQflCjzgfayMkuMfb5TXCobG3HwSti1ixVIFgFzOFimU1Ck35ckMJ9H8Cxc44Lm3X_A',
      phone: '+91 98765 43210',
      skills: ['Plumbing', 'Pipe Fitting'],
      experience: '5 Years',
      rating: 4.88,
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
        customerLocation: 'Flat 402, Sai Shraddha Apts, Ideal Colony',
        customerPhone: '+91 91234 56789',
        serviceName: 'Plumbing Inspection & Tap Leakage Repair',
        date: 'Today',
        time: '11:00 AM – 12:00 PM',
        baseAmount: 399.0,
        laborAllowance: 86.0,
        status: BookingStatus.pending,
        distanceKm: '1.8 km',
        createdAt: '4m ago',
      ),
      JobRequest(
        id: 'j2',
        customerId: 'c2',
        customerName: 'Rajesh Deshmukh',
        customerLocation: 'Pratik Nagar',
        customerPhone: '+91 90000 00001',
        serviceName: 'Kitchen Sink Clog',
        date: 'Today',
        time: '09:15 AM',
        baseAmount: 499.0,
        laborAllowance: 151.0,
        status: BookingStatus.completed,
        distanceKm: '3.2 km',
        createdAt: '5h ago',
      ),
      JobRequest(
        id: 'j3',
        customerId: 'c3',
        customerName: 'Meera Joshi',
        customerLocation: 'Karve Road',
        customerPhone: '+91 90000 00002',
        serviceName: 'Flush Valve Replacement',
        date: 'Today',
        time: '10:20 AM',
        baseAmount: 399.0,
        laborAllowance: 21.0,
        status: BookingStatus.completed,
        distanceKm: '2.1 km',
        createdAt: '4h ago',
      ),
    ];
  }

  @override
  Future<WorkerProfile> getWorkerProfile(String userId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return currentWorker;
  }

  @override
  Future<List<JobRequest>> getWorkerBookings() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _jobRequests.toList();
  }

  @override
  Future<void> updateAvailability(bool isAvailable) async {
    await Future.delayed(const Duration(milliseconds: 300));
    currentWorker = currentWorker.copyWith(isAvailable: isAvailable);
  }

  @override
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _jobRequests.indexWhere((j) => j.id == bookingId);
    if (index != -1) {
      final job = _jobRequests[index];
      
      // Simulate earnings update on completion
      if (newStatus == BookingStatus.completed && job.status != BookingStatus.completed) {
        currentWorker = currentWorker.copyWith(
          completedJobs: currentWorker.completedJobs + 1,
          earnings: currentWorker.earnings + job.totalAmount,
        );
      }
      
      _jobRequests[index] = job.copyWith(status: newStatus);
    }
  }
}
