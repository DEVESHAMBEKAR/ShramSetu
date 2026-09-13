import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/admin/data/repositories/mock_admin_repository.dart';
import 'package:app/features/admin/data/models/admin_models.dart';
import 'package:app/features/worker/data/models/worker_models.dart';

void main() {
  group('MockAdminRepository Tests', () {
    late MockAdminRepository repo;

    setUp(() {
      repo = MockAdminRepository();
    });

    test('admin mock login', () async {
      bool success = await repo.login('admin@shramsetu.demo', 'admin123');
      expect(success, isTrue);
      expect(repo.isAuthenticated, isTrue);

      bool fail = await repo.login('wrong', 'wrong');
      expect(fail, isFalse);
    });

    test('worker verification approval', () {
      final pendingWorker = repo.workers.firstWhere((w) => w.verificationStatus == VerificationStatus.pending);
      repo.approveWorker(pendingWorker.id);
      
      final updatedWorker = repo.workers.firstWhere((w) => w.id == pendingWorker.id);
      expect(updatedWorker.verificationStatus, equals(VerificationStatus.approved));
      expect(updatedWorker.isVerified, isTrue);
    });

    test('worker verification rejection', () {
      final pendingWorker = repo.workers.firstWhere((w) => w.verificationStatus == VerificationStatus.pending);
      repo.rejectWorker(pendingWorker.id);
      
      final updatedWorker = repo.workers.firstWhere((w) => w.id == pendingWorker.id);
      expect(updatedWorker.verificationStatus, equals(VerificationStatus.rejected));
      expect(updatedWorker.isVerified, isFalse);
      expect(updatedWorker.isAvailable, isFalse);
    });

    test('service active/inactive state', () {
      final service = repo.services.first;
      final initialStatus = service.status;
      
      repo.toggleServiceStatus(service.id);
      
      final updatedService = repo.services.firstWhere((s) => s.id == service.id);
      expect(updatedService.status, isNot(equals(initialStatus)));
    });

    test('complaint resolution', () {
      final openComplaint = repo.complaints.firstWhere((c) => c.status == ComplaintStatus.open);
      repo.updateComplaintStatus(openComplaint.id, ComplaintStatus.resolved);
      
      final updatedComplaint = repo.complaints.firstWhere((c) => c.id == openComplaint.id);
      expect(updatedComplaint.status, equals(ComplaintStatus.resolved));
    });
  });
}
