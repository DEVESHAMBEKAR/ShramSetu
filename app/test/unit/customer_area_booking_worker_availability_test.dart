import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';
import 'package:app/features/customer/data/repositories/mock_customer_repository.dart';
import 'package:app/features/worker/data/repositories/mock_worker_repository.dart';
import 'package:app/features/admin/data/repositories/mock_admin_repository.dart';

void main() {
  group('Customer Area & Registered Worker Availability Tests', () {
    late MockCustomerRepository customerRepo;
    late MockWorkerRepository workerRepo;

    setUp(() {
      DI.setup();
      customerRepo = MockCustomerRepository();
      workerRepo = MockWorkerRepository();
      MockAdminRepository(); // Initialize for side effects
    });

    test('1. Registered workers exist in customer repository and are available', () async {
      final allWorkers = await customerRepo.getAllWorkers();
      expect(allWorkers.isNotEmpty, isTrue);

      // Verify registered worker Rahul Patil (w101) in Kothrud
      final rahul = allWorkers.firstWhere((w) => w.id == 'w101');
      expect(rahul.name, equals('Rahul Patil'));
      expect(rahul.locationTag, contains('Kothrud'));
      expect(rahul.availability, equals('Available Today'));
      expect(rahul.serviceAreas, contains('Kothrud'));

      // Verify registered worker Ramesh Deshpande (W3) in Kothrud
      final ramesh = allWorkers.firstWhere((w) => w.id == 'W3');
      expect(ramesh.name, equals('Ramesh Deshpande'));
      expect(ramesh.locationTag, contains('Kothrud'));
      expect(ramesh.availability, equals('Available Today'));

      // Verify registered worker Ganesh Shinde (W1) in Baner
      final ganesh = allWorkers.firstWhere((w) => w.id == 'W1');
      expect(ganesh.name, equals('Ganesh Shinde'));
      expect(ganesh.locationTag, contains('Baner'));
      expect(ganesh.availability, equals('Available Today'));
    });

    test('2. Area filtering returns matching registered workers for Kothrud', () async {
      final allWorkers = await customerRepo.getAllWorkers();
      final target = 'kothrud';
      final kothrudWorkers = allWorkers.where((w) {
        final loc = w.locationTag.toLowerCase();
        final matchesAreas = w.serviceAreas.any((sa) => sa.toLowerCase().contains(target));
        return loc.contains(target) || matchesAreas;
      }).toList();

      expect(kothrudWorkers.length, greaterThanOrEqualTo(2));
      final names = kothrudWorkers.map((w) => w.name).toList();
      expect(names, contains('Rahul Patil'));
      expect(names, contains('Ramesh Deshpande'));
      expect(names, contains('Rameshwar Shinde'));
    });

    test('3. New worker registration dynamically adds worker to customer console', () async {
      const newWorkerId = 'new_artisan_pune_01';
      await workerRepo.registerWorker(
        workerId: newWorkerId,
        fullName: 'Mahesh Gaikwad',
        phone: '+91 98888 77777',
        skill: 'Carpentry & Woodwork',
        experienceYears: 7,
        serviceLocation: 'Aundh, Pune',
      );

      final allWorkers = await customerRepo.getAllWorkers();
      final mahesh = allWorkers.firstWhere((w) => w.id == newWorkerId);
      expect(mahesh.name, equals('Mahesh Gaikwad'));
      expect(mahesh.categoryId, equals('c3')); // Carpentry mapped to c3
      expect(mahesh.locationTag, contains('Aundh'));
      expect(mahesh.availability, equals('Available Today'));
      expect(mahesh.serviceAreas, contains('Aundh'));
    });

    test('4. Customer can book an available registered worker in their area', () async {
      final eligiblePlumbers = await customerRepo.getEligibleWorkers('c2');
      expect(eligiblePlumbers.isNotEmpty, isTrue);

      final selectedWorker = eligiblePlumbers.firstWhere((w) => w.name == 'Rahul Patil');
      expect(selectedWorker.availability, equals('Available Today'));

      // Create booking for Rahul Patil
      final bookingId = await customerRepo.createBooking(
        workerId: selectedWorker.id,
        serviceId: 'c2',
        scheduledDate: '2026-10-05',
        scheduledTime: '10:00 AM',
        amount: selectedWorker.rate.toDouble(),
        notes: 'Pipe leakage under kitchen sink in Kothrud',
      );

      expect(bookingId, isNotNull);
      expect(bookingId!.isNotEmpty, isTrue);

      // Verify booking exists in customer bookings
      final bookings = await customerRepo.getCustomerBookings();
      final myBooking = bookings.firstWhere((b) => b['id'] == bookingId);
      expect(myBooking['worker_name'], equals('Rahul Patil'));
      expect(myBooking['status'], isNotNull);
      expect(myBooking['base_amount'] ?? myBooking['amount'], equals(selectedWorker.rate.toDouble()));
    });
  });
}
