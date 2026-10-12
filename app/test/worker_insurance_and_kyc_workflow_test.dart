import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/insurance_models.dart';
import 'package:app/features/worker/data/repositories/mock_worker_repository.dart';
import 'package:app/features/admin/data/repositories/mock_admin_repository.dart';

void main() {
  group('Worker Insurance Application & Admin Approval Flow', () {
    test('Worker does NOT have auto-assigned insurance by default', () async {
      final workerRepo = MockWorkerRepository();
      final adminRepo = MockAdminRepository();

      const newWorkerId = 'worker-uuid-unapplied-99';

      final initialWorkerIns = await workerRepo.getWorkerInsurance(newWorkerId);
      final initialAdminIns = await adminRepo.getWorkerInsurance(newWorkerId);

      expect(initialWorkerIns, isNull);
      expect(initialAdminIns, isNull);
    });

    test('Worker applies for insurance -> transitions to pending approval', () async {
      final workerRepo = MockWorkerRepository();
      const workerId = 'worker-uuid-applicant-123';

      final applied = await workerRepo.applyForInsurance(workerId);
      expect(applied.status, equals(InsuranceStatus.pending));
      expect(applied.isPendingApproval, isTrue);
      expect(applied.isApproved, isFalse);
      expect(applied.policyNumber, equals('PENDING_APPROVAL'));
      expect(applied.maskedPolicyNumber, equals('Pending Issuance'));

      final current = await workerRepo.getWorkerInsurance(workerId);
      expect(current, isNotNull);
      expect(current!.isPendingApproval, isTrue);
    });

    test('Admin approves insurance -> generates official policy number and activates', () async {
      final adminRepo = MockAdminRepository();
      const workerId = 'worker-uuid-applicant-123';

      final approved = await adminRepo.approveWorkerInsurance(workerId, remarks: 'Verified guild artisan credentials');
      expect(approved.status, equals(InsuranceStatus.active));
      expect(approved.isApproved, isTrue);
      expect(approved.isPendingApproval, isFalse);
      expect(approved.policyNumber, startsWith('POL-${DateTime.now().year}-'));
      expect(approved.maskedPolicyNumber, startsWith('POL-••••-'));
      expect(approved.adminRemarks, equals('Verified guild artisan credentials'));

      final current = await adminRepo.getWorkerInsurance(workerId);
      expect(current, isNotNull);
      expect(current!.status, equals(InsuranceStatus.active));
      expect(current.maskedPolicyNumber, startsWith('POL-••••-'));
    });

    test('Admin getWorkerDocuments returns canonical verification documents even for fast-onboarding workers', () async {
      final adminRepo = MockAdminRepository();
      const workerId = 'fast-onboarded-worker-456';

      final docs = await adminRepo.getWorkerDocuments(workerId);
      expect(docs, isNotEmpty);
      expect(docs.length, equals(3));
      expect(docs.any((d) => d['document_type'] == 'IDENTITY'), isTrue);
      expect(docs.any((d) => d['document_type'] == 'ADDRESS'), isTrue);
      expect(docs.any((d) => d['document_type'] == 'SKILL_CERTIFICATE'), isTrue);
    });
  });
}
