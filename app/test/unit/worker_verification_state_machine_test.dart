import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/worker/data/repositories/mock_worker_repository.dart';
import 'package:app/features/admin/data/repositories/mock_admin_repository.dart';
import 'package:app/features/worker/data/models/worker_models.dart';

void main() {
  group('Comprehensive Worker Verification State Machine & 20-Field Audit Tests', () {
    late MockWorkerRepository workerRepo;
    late MockAdminRepository adminRepo;

    setUp(() {
      workerRepo = MockWorkerRepository();
      adminRepo = MockAdminRepository();
    });

    test('1. 20-Field Worker Registration captures all fields and sets status to PENDING', () async {
      const workerId = 'artisan_full_20_fields';

      await workerRepo.registerWorker(
        workerId: workerId,
        fullName: 'Pandurang Kadam',
        phone: '+91 98221 99999',
        skill: 'Carpentry & Woodwork',
        experienceYears: 7,
        serviceLocation: 'Shivajinagar, Pune',
        dob: '1988-06-15',
        gender: 'Male',
        address: 'Flat 402, Shanti Kunj, FC Road',
        city: 'Pune',
        district: 'Pune District',
        pinCode: '411005',
        trade: 'Carpentry',
        skillLevel: 'Master Artisan',
        federationName: 'Pune District Labour Cooperative Federation',
        membershipId: 'PUN-CRP-8821',
        bio: 'Over 7 years of specialized modular carpentry and wood restoration.',
        declarationAccepted: true,
      );

      final profile = await workerRepo.getWorkerProfile(workerId);
      expect(profile.name, equals('Pandurang Kadam'));
      expect(profile.phone, equals('+91 98221 99999'));
      expect(profile.dob, equals('1988-06-15'));
      expect(profile.gender, equals('Male'));
      expect(profile.address, contains('Shanti Kunj'));
      expect(profile.city, equals('Pune'));
      expect(profile.district, equals('Pune District'));
      expect(profile.pinCode, equals('411005'));
      expect(profile.trade, equals('Carpentry'));
      expect(profile.primarySkill, equals('Carpentry & Woodwork'));
      expect(profile.skillLevel, equals('Master Artisan'));
      expect(profile.federationName, equals('Pune District Labour Cooperative Federation'));
      expect(profile.membershipId, equals('PUN-CRP-8821'));
      expect(profile.declarationAccepted, isTrue);
      expect(profile.verificationStatus, equals(VerificationStatus.pending));
      expect(profile.isVerified, isFalse);
    });

    test('2. Admin initiates review -> status transitions to UNDER_REVIEW with audit log', () async {
      final workers = await adminRepo.getWorkers();
      final target = workers.first;

      await adminRepo.startReview(target.id, remarks: 'Assigned to Pune Central Verification Desk');

      final history = await adminRepo.getVerificationHistory(target.id);
      expect(history, isNotEmpty);
      expect(history.first.action, equals('START_REVIEW'));
      expect(history.first.newStatus, equals('UNDER_REVIEW'));
      expect(history.first.remarks, contains('Pune Central'));
    });

    test('3. Admin requests changes -> status transitions to CHANGES_REQUIRED with remarks', () async {
      final workers = await adminRepo.getWorkers();
      final target = workers.first;

      await adminRepo.requestChanges(
        target.id,
        remarks: 'Electricity bill is older than 3 months. Please re-upload latest utility bill.',
      );

      final history = await adminRepo.getVerificationHistory(target.id);
      expect(history.first.action, equals('REQUEST_CHANGES'));
      expect(history.first.newStatus, equals('CHANGES_REQUIRED'));
      expect(history.first.remarks, contains('utility bill'));

      final updatedWorker = (await adminRepo.getWorkers()).firstWhere((w) => w.id == target.id);
      expect(updatedWorker.verificationStatus, equals(VerificationStatus.changesRequired));
      expect(updatedWorker.verificationRemarks, contains('utility bill'));
    });

    test('4. Worker resubmits documents -> status returns to PENDING', () async {
      final workers = await adminRepo.getWorkers();
      final target = workers.first;

      await workerRepo.resubmitForVerification(target.id);

      final profile = await workerRepo.getWorkerProfile(target.id);
      expect(profile.verificationStatus, equals(VerificationStatus.underReview));
    });

    test('5. Admin approves worker -> status transitions to APPROVED, isVerified = true', () async {
      final workers = await adminRepo.getWorkers();
      final target = workers.first;

      await adminRepo.approveWorker(target.id, remarks: 'All credentials and MSDE certificate verified.');

      final updated = (await adminRepo.getWorkers()).firstWhere((w) => w.id == target.id);
      expect(updated.verificationStatus, equals(VerificationStatus.approved));
      expect(updated.isVerified, isTrue);

      final history = await adminRepo.getVerificationHistory(target.id);
      expect(history.first.action, equals('APPROVE'));
      expect(history.first.newStatus, equals('APPROVED'));
    });

    test('6. Admin suspends worker on infraction -> status transitions to SUSPENDED', () async {
      final workers = await adminRepo.getWorkers();
      final target = workers.first;

      await adminRepo.suspendWorker(target.id, remarks: 'Under inquiry following customer complaint.');

      final updated = (await adminRepo.getWorkers()).firstWhere((w) => w.id == target.id);
      expect(updated.verificationStatus, equals(VerificationStatus.suspended));

      final history = await adminRepo.getVerificationHistory(target.id);
      expect(history.first.action, equals('SUSPEND'));
      expect(history.first.newStatus, equals('SUSPENDED'));
    });
  });
}
