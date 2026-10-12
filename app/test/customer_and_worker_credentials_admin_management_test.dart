import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/admin/data/repositories/mock_admin_repository.dart';
import 'package:app/features/auth/data/repositories/mock_user_repository.dart';
import 'package:app/features/worker/data/repositories/mock_worker_repository.dart';
import 'package:app/features/worker/data/models/worker_models.dart';

void main() {
  group('Customer & Worker Credentials, Federation & Admin Management Tests', () {
    test('1. Admin can update customer details (name, phone, email, location & federation)', () async {
      final adminRepo = MockAdminRepository();
      final customersBefore = await adminRepo.getCustomers();
      expect(customersBefore.isNotEmpty, isTrue);

      final target = customersBefore.first;
      final targetId = target.id;

      // Update customer details with new email, phone, location & federation
      await adminRepo.updateCustomerDetails(
        customerId: targetId,
        fullName: 'Devesh Ambekar',
        phone: '9975811244',
        email: 'devesh@shramsetu.org',
        city: 'Nashik',
        district: 'Nashik',
        state: 'Maharashtra',
        address: 'College Road, Nashik',
        federationId: '22222222-0000-0000-0000-000000000002',
      );

      final customersAfter = await adminRepo.getCustomers();
      final updated = customersAfter.firstWhere((c) => c.id == targetId);

      expect(updated.name, equals('Devesh Ambekar'));
      expect(updated.phone, equals('9975811244'));
      expect(updated.email, equals('devesh@shramsetu.org'));
      expect(updated.locationSummary, contains('Nashik'));
      expect(updated.district, equals('Nashik'));
      expect(updated.federationId, equals('22222222-0000-0000-0000-000000000002'));
      expect(updated.federationName, equals('Nashik District Artisans Cooperative Union'));
    });

    test('2. Admin can inspect customer bookings and modify order status/schedule/notes', () async {
      final adminRepo = MockAdminRepository();
      final bookings = await adminRepo.getBookings();
      expect(bookings.isNotEmpty, isTrue);

      final targetBooking = bookings.first;
      final targetBookingId = targetBooking.id;

      // Modify order status, date, and time
      await adminRepo.modifyBooking(
        bookingId: targetBookingId,
        status: BookingStatus.inProgress,
        scheduledDate: '2026-10-15',
        scheduledTime: '02:30 PM',
        notes: 'Federation supervisor assigned and dispatched urgent tool kit.',
      );

      final bookingsAfter = await adminRepo.getBookings();
      final modified = bookingsAfter.firstWhere((b) => b.id == targetBookingId);

      expect(modified.status, equals(BookingStatus.inProgress));
      expect(modified.date, equals('2026-10-15'));
      expect(modified.time, equals('02:30 PM'));
    });

    test('3. Customer Profile supports required email and mobile credentials', () async {
      final userRepo = MockUserRepository();
      const testCustomerId = 'mock_customer_credential_test';

      // Update customer profile with phone and email
      await userRepo.updateCustomerProfile(
        userId: testCustomerId,
        fullName: 'Aarav Deshmukh',
        phone: '9876543210',
        email: 'aarav.deshmukh@example.com',
        federationId: '11111111-0000-0000-0000-000000000001',
      );

      final profile = await userRepo.getCustomerProfile(testCustomerId);
      expect(profile, isNotNull);
      expect(profile!.fullName, equals('Aarav Deshmukh'));
      expect(profile.phone, equals('9876543210'));
      expect(profile.email, equals('aarav.deshmukh@example.com'));
      expect(profile.federationId, equals('11111111-0000-0000-0000-000000000001'));
      expect(profile.federationName, equals('Pune District Labour Cooperative Federation'));
    });

    test('4. Worker registration and profile require and update email and phone credentials', () async {
      final workerRepo = MockWorkerRepository();
      const testWorkerId = 'mock_artisan_credential_test';

      // Register worker with email and phone
      await workerRepo.registerWorker(
        workerId: testWorkerId,
        fullName: 'Santosh Shinde',
        phone: '9123456789',
        email: 'santosh.plumbing@shramsetu.in',
        skill: 'Plumbing & Pipe Fitting',
        experienceYears: 5,
        serviceLocation: 'Kothrud, Pune',
        district: 'Pune',
        trade: 'Plumbing',
      );

      final workerProfile = await workerRepo.getWorkerProfile(testWorkerId);
      expect(workerProfile.name, equals('Santosh Shinde'));
      expect(workerProfile.phone, equals('9123456789'));
      expect(workerProfile.email, equals('santosh.plumbing@shramsetu.in'));

      // Update worker credentials
      await workerRepo.updateWorkerCredentials(
        testWorkerId,
        phone: '9888877777',
        email: 'santosh.master@shramsetu.in',
      );

      final updatedWorker = await workerRepo.getWorkerProfile(testWorkerId);
      expect(updatedWorker.phone, equals('9888877777'));
      expect(updatedWorker.email, equals('santosh.master@shramsetu.in'));
    });
  });
}
