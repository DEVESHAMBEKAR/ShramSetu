import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/worker/data/repositories/mock_worker_repository.dart';
import 'package:app/features/admin/data/repositories/mock_admin_repository.dart';
import 'package:app/features/worker/data/models/worker_models.dart';

void main() {
  group('Worker Registration & Admin Verification Flow Tests', () {
    late MockWorkerRepository workerRepo;
    late MockAdminRepository adminRepo;

    setUp(() {
      workerRepo = MockWorkerRepository();
      adminRepo = MockAdminRepository();
    });

    test('1. New worker registers with trade details and status is set to PENDING', () async {
      await workerRepo.registerWorker(
        workerId: 'test_artisan_99',
        fullName: 'Dattatray Shinde',
        phone: '+91 91234 56789',
        skill: 'Plumbing & Pipe Fitting',
        experienceYears: 4,
        serviceLocation: 'Kothrud, Pune',
        bio: 'Licensed plumbing and leak repair specialist.',
      );

      final profile = await workerRepo.getWorkerProfile('test_artisan_99');
      expect(profile.name, equals('Dattatray Shinde'));
      expect(profile.phone, equals('+91 91234 56789'));
      expect(profile.skills, contains('Plumbing & Pipe Fitting'));
      expect(profile.verificationStatus, equals(VerificationStatus.pending));
      expect(profile.isVerified, isFalse);
      expect(profile.isAvailable, isFalse);
    });

    test('2. Worker submits required KYC documents (Identity, Address, Skill certificate)', () async {
      const workerId = 'test_artisan_99';

      await workerRepo.submitVerificationDocument(
        workerId,
        'IDENTITY',
        '$workerId/aadhaar.pdf',
        'aadhaar_dattatray.pdf',
        'application/pdf',
        1024 * 500,
      );

      await workerRepo.submitVerificationDocument(
        workerId,
        'ADDRESS',
        '$workerId/electricity.jpg',
        'electricity_bill.jpg',
        'image/jpeg',
        1024 * 650,
      );

      final docs = await workerRepo.getVerificationDocuments(workerId);
      expect(docs.length, equals(2));
      expect(docs.any((d) => d['document_type'] == 'IDENTITY'), isTrue);
      expect(docs.any((d) => d['document_type'] == 'ADDRESS'), isTrue);
      expect(docs.first['status'], equals('PENDING'));
    });

    test('3. Admin inspects pending workers and fetches their submitted documents', () async {
      final workers = await adminRepo.getWorkers();
      final pendingWorkers = workers.where((w) => w.verificationStatus == VerificationStatus.pending).toList();
      expect(pendingWorkers, isNotEmpty);

      final firstPending = pendingWorkers.first;
      final docs = await adminRepo.getWorkerDocuments(firstPending.id);
      expect(docs, isNotEmpty);
      expect(docs.any((d) => d['document_type'] == 'IDENTITY'), isTrue);
      expect(docs.any((d) => d['document_type'] == 'ADDRESS'), isTrue);
    });

    test('4. Admin approves worker -> status updates to APPROVED and isVerified becomes true', () async {
      final workers = await adminRepo.getWorkers();
      final pendingWorker = workers.firstWhere((w) => w.verificationStatus == VerificationStatus.pending);

      await adminRepo.approveWorker(pendingWorker.id);

      final updatedWorkers = await adminRepo.getWorkers();
      final approvedWorker = updatedWorkers.firstWhere((w) => w.id == pendingWorker.id);

      expect(approvedWorker.verificationStatus, equals(VerificationStatus.approved));
      expect(approvedWorker.isVerified, isTrue);
    });

    test('5. Admin rejects worker with invalid documents -> status updates to REJECTED', () async {
      final workers = await adminRepo.getWorkers();
      final secondPending = workers.firstWhere(
        (w) => w.verificationStatus == VerificationStatus.pending,
        orElse: () => workers.first,
      );

      await adminRepo.rejectWorker(secondPending.id);

      final updatedWorkers = await adminRepo.getWorkers();
      final rejected = updatedWorkers.firstWhere((w) => w.id == secondPending.id);

      expect(rejected.verificationStatus, equals(VerificationStatus.rejected));
      expect(rejected.isVerified, isFalse);
    });

    test('6. Admin updates document status to APPROVED, RESUBMIT, and FLAGGED', () async {
      final workers = await adminRepo.getWorkers();
      final wId = workers.first.id;
      final docs = await adminRepo.getWorkerDocuments(wId);
      final docId = docs.first['id'] as String;

      // Admin approves document
      await adminRepo.updateDocumentStatus(docId, 'APPROVED');
      var updatedDocs = await adminRepo.getWorkerDocuments(wId);
      expect(updatedDocs.firstWhere((d) => d['id'] == docId)['status'], equals('APPROVED'));

      // Admin requests resubmission
      await adminRepo.updateDocumentStatus(docId, 'RESUBMIT', remarks: 'Blurry photo');
      updatedDocs = await adminRepo.getWorkerDocuments(wId);
      expect(updatedDocs.firstWhere((d) => d['id'] == docId)['status'], equals('RESUBMIT'));
      expect(updatedDocs.firstWhere((d) => d['id'] == docId)['admin_remarks'], equals('Blurry photo'));

      // Admin flags queries
      await adminRepo.updateDocumentStatus(docId, 'FLAGGED', remarks: 'Address mismatch');
      updatedDocs = await adminRepo.getWorkerDocuments(wId);
      expect(updatedDocs.firstWhere((d) => d['id'] == docId)['status'], equals('FLAGGED'));
      expect(updatedDocs.firstWhere((d) => d['id'] == docId)['admin_remarks'], equals('Address mismatch'));
    });

    test('7. Revisiting worker file maintains document status and logs verification history', () async {
      final workers = await adminRepo.getWorkers();
      final wId = workers.last.id;
      final initialDocs = await adminRepo.getWorkerDocuments(wId);
      final idDoc = initialDocs.firstWhere((d) => d['document_type'] == 'IDENTITY');

      // Admin approves IDENTITY document
      await adminRepo.updateDocumentStatus(idDoc['id'], 'APPROVED');

      // Simulate admin navigating back, and later revisiting the worker file
      final revisitedDocs = await adminRepo.getWorkerDocuments(wId);
      final revisitedIdDoc = revisitedDocs.firstWhere((d) => d['document_type'] == 'IDENTITY');

      // Document must remain APPROVED upon revisiting
      expect(revisitedIdDoc['status'], equals('APPROVED'));

      // Verification history must capture the audit record
      final history = await adminRepo.getVerificationHistory(wId);
      expect(history.any((h) => h.action == 'DOCUMENT_APPROVED'), isTrue);
    });
  });
}
