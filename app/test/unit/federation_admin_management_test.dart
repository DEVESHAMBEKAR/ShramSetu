import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/admin/data/repositories/mock_admin_repository.dart';

void main() {
  group('Federation Admin Management Tests (Reassign, Remove, Reset Password)', () {
    late MockAdminRepository repo;

    setUp(() {
      repo = MockAdminRepository();
      repo.resetMockData();
    });

    test('1. Initial admin list contains Adil Atar for Nashik Federation', () async {
      final admins = await repo.getFederationAdmins();
      expect(admins, isNotEmpty);

      final nashikAdmins = await repo.getFederationAdmins(
        federationId: '22222222-0000-0000-0000-000000000002',
      );
      expect(nashikAdmins, isNotEmpty);
      final adil = nashikAdmins.firstWhere((a) => a['email'] == 'adilatar9494@gmail.com');
      expect(adil['full_name'], 'Adil Atar');
      expect(adil['phone'], '7822027271');
      expect(adil['role'], 'FEDERATION_ADMIN');
    });

    test('2. Super Admin can reset federation admin password with password change requirement', () async {
      final nashikAdmins = await repo.getFederationAdmins(
        federationId: '22222222-0000-0000-0000-000000000002',
      );
      final adil = nashikAdmins.first;
      final userId = adil['user_id'];

      // Reset password
      await repo.resetFederationAdminPassword(
        userId: userId,
        newPassword: 'SecureNewPassword123!',
        requirePasswordChange: true,
      );

      final updatedAdmins = await repo.getFederationAdmins(
        federationId: '22222222-0000-0000-0000-000000000002',
      );
      final updatedAdil = updatedAdmins.firstWhere((a) => a['user_id'] == userId);
      expect(updatedAdil['requires_password_change'], isTrue);
      expect(updatedAdil['password'], 'SecureNewPassword123!');
    });

    test('3. Super Admin can reassign / change admin to a different federation', () async {
      final nashikAdmins = await repo.getFederationAdmins(
        federationId: '22222222-0000-0000-0000-000000000002',
      );
      final adil = nashikAdmins.first;
      final userId = adil['user_id'];

      // Reassign Adil from Nashik to Mumbai (33333333-0000-0000-0000-000000000003)
      await repo.reassignFederationAdmin(
        userId: userId,
        newFederationId: '33333333-0000-0000-0000-000000000003',
        oldFederationId: '22222222-0000-0000-0000-000000000002',
      );

      // Verify Nashik now has no admin
      final remainingNashik = await repo.getFederationAdmins(
        federationId: '22222222-0000-0000-0000-000000000002',
      );
      expect(remainingNashik.where((a) => a['user_id'] == userId), isEmpty);

      // Verify Mumbai now has Adil
      final mumbaiAdmins = await repo.getFederationAdmins(
        federationId: '33333333-0000-0000-0000-000000000003',
      );
      expect(mumbaiAdmins.where((a) => a['user_id'] == userId), isNotEmpty);
      final reassigned = mumbaiAdmins.firstWhere((a) => a['user_id'] == userId);
      expect(reassigned['federation_name'], 'Mumbai Metropolitan Labour Federation');
    });

    test('4. Super Admin can update admin details (full name & phone)', () async {
      final admins = await repo.getFederationAdmins();
      final admin = admins.first;
      final userId = admin['user_id'];

      await repo.updateFederationAdminDetails(
        userId: userId,
        fullName: 'Adil A. Atar (Updated)',
        phone: '+91 99999 88888',
      );

      final refreshed = (await repo.getFederationAdmins()).firstWhere((a) => a['user_id'] == userId);
      expect(refreshed['full_name'], 'Adil A. Atar (Updated)');
      expect(refreshed['phone'], '+91 99999 88888');
    });

    test('5. Super Admin can remove admin from authorized cooperative admins', () async {
      // Re-initialize repo to test clean removal
      final freshRepo = MockAdminRepository();
      final nashikAdminsBefore = await freshRepo.getFederationAdmins(
        federationId: '22222222-0000-0000-0000-000000000002',
      );
      expect(nashikAdminsBefore, isNotEmpty);
      final adil = nashikAdminsBefore.first;

      // Remove from authorized
      await freshRepo.removeFederationAdmin(
        userId: adil['user_id'],
        federationId: '22222222-0000-0000-0000-000000000002',
      );

      final nashikAdminsAfter = await freshRepo.getFederationAdmins(
        federationId: '22222222-0000-0000-0000-000000000002',
      );
      expect(nashikAdminsAfter.where((a) => a['user_id'] == adil['user_id']), isEmpty);
    });
  });
}
