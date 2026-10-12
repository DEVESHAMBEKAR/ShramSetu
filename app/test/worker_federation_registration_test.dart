import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/federation_models.dart';
import 'package:app/features/worker/data/repositories/mock_worker_repository.dart';
import 'package:app/features/admin/data/repositories/mock_admin_repository.dart';
import 'package:app/features/worker/presentation/screens/worker_registration_screen.dart';

void main() {
  group('Worker Federation Auto-Routing and Resolution Tests', () {
    test('Nashik location auto-resolves to Nashik District Artisans Cooperative Union', () {
      final fed = FederationModel.resolveFederation(
        location: 'Nashik Road, Nashik',
        district: 'Nashik',
      );

      expect(fed.id, '22222222-0000-0000-0000-000000000002');
      expect(fed.name, 'Nashik District Artisans Cooperative Union');
      expect(fed.city, 'Nashik');
    });

    test('Nagpur location auto-resolves to Nagpur District Shramik Cooperative Union', () {
      final fed = FederationModel.resolveFederation(
        location: 'Dharampeth & Sitabuldi, Nagpur',
        city: 'Nagpur',
      );

      expect(fed.id, '55555555-0000-0000-0000-000000000005');
      expect(fed.name, 'Nagpur District Shramik Cooperative Union');
    });

    test('Hyderabad federation matches canonical sequential UUID format', () {
      const customFed = FederationModel(
        id: '66666666-0000-0000-0000-000000000006',
        name: 'Hyderabad District Labour Cooperation',
        state: 'Telangana',
        district: 'Hyderabad',
        city: 'Gandhi Bhawan (Hyderabad)',
      );

      final fullPool = [...FederationModel.defaultFederations, customFed];

      final fed = FederationModel.resolveFederation(
        location: 'Gandhi Bhawan, Hyderabad',
        district: 'Hyderabad',
        federationsList: fullPool,
      );

      expect(fed.id, '66666666-0000-0000-0000-000000000006');
      expect(fed.name, contains('Hyderabad'));
      expect(fed.state, 'Telangana');
    });

    test('generateNextFederationId follows canonical pattern sequentially', () {
      // With default federations (1 to 5), the next sequential ID is 6 (assigned to Hyderabad)
      expect(FederationModel.generateNextFederationId(FederationModel.defaultFederations), '66666666-0000-0000-0000-000000000006');

      // With Hyderabad present in pool (1 to 6), next sequential ID is 7
      const hydFed = FederationModel(
        id: '66666666-0000-0000-0000-000000000006',
        name: 'Hyderabad District Labour Cooperation',
        state: 'Telangana',
        district: 'Hyderabad',
        city: 'Hyderabad',
      );
      final nextWithHyd = FederationModel.generateNextFederationId([...FederationModel.defaultFederations, hydFed]);
      expect(nextWithHyd, '77777777-0000-0000-0000-000000000007');

      // Test formatting across indices
      expect(FederationModel.formatFederationId(1), '11111111-0000-0000-0000-000000000001');
      expect(FederationModel.formatFederationId(6), '66666666-0000-0000-0000-000000000006');
      expect(FederationModel.formatFederationId(7), '77777777-0000-0000-0000-000000000007');
      expect(FederationModel.formatFederationId(8), '88888888-0000-0000-0000-000000000008');
      expect(FederationModel.formatFederationId(10), 'aaaaaaaa-0000-0000-0000-000000000010');
    });

    test('Trade category sub-skills are partitioned per category and not mixed', () {
      final plumbingSkills = WorkerRegistrationScreen.tradeSubSkills['Plumbing']!;
      expect(plumbingSkills, contains('Plumbing & Pipe Fitting'));
      expect(plumbingSkills, contains('Drainage & Sewage Line Cleaning'));
      expect(plumbingSkills, isNot(contains('Electrical & Home Wiring')));

      final electricalSkills = WorkerRegistrationScreen.tradeSubSkills['Electrical']!;
      expect(electricalSkills, contains('Electrical & Home Wiring'));
      expect(electricalSkills, contains('Switchboard & MCB Fuse Installation'));
      expect(electricalSkills, isNot(contains('Furniture Assembly & Repair')));

      final carpentrySkills = WorkerRegistrationScreen.tradeSubSkills['Carpentry']!;
      expect(carpentrySkills, contains('Furniture Assembly & Repair'));
      expect(carpentrySkills, isNot(contains('Plumbing & Pipe Fitting')));
    });

    test('Worker registration passes and records federation affiliation correctly', () async {
      final repo = MockWorkerRepository();
      
      await repo.registerWorker(
        workerId: 'worker_nashik_01',
        fullName: 'Ganesh Shinde',
        phone: '+91 98220 12345',
        skill: 'Carpentry & Woodwork',
        experienceYears: 4,
        serviceLocation: 'Nashik Road, Nashik',
        district: 'Nashik',
        city: 'Nashik',
      );

      final worker = repo.currentWorker;
      expect(worker.name, 'Ganesh Shinde');
      expect(worker.federationRefId, '22222222-0000-0000-0000-000000000002');
      expect(worker.guildName, 'Nashik District Artisans Cooperative Union');
      expect(worker.federationName, 'Nashik District Artisans Cooperative Union');
    });

    test('Nagpur locality in serviceLocation resolves to Nagpur even if district field was defaulted to Pune', () {
      final fed = FederationModel.resolveFederation(
        district: 'Pune',
        city: 'Kothrud',
        location: 'Dharampeth & Sitabuldi, Nagpur',
      );

      expect(fed.id, '55555555-0000-0000-0000-000000000005');
      expect(fed.name, 'Nagpur District Shramik Cooperative Union');
      expect(fed.district, 'Nagpur');
    });

    test('MockWorkerRepository auto-heals stale Pune assignment when service location is in Nagpur', () async {
      final repo = MockWorkerRepository();
      repo.currentWorker = repo.currentWorker.copyWith(
        name: 'Sushil',
        serviceLocation: 'Dharampeth & Sitabuldi, Nagpur',
        guildName: 'Pune District Labour Cooperative Federation',
        federationRefId: '11111111-0000-0000-0000-000000000001',
      );

      final profile = await repo.getWorkerProfile('sushil_01');
      expect(profile.federationRefId, '55555555-0000-0000-0000-000000000005');
      expect(profile.federationName, 'Nagpur District Shramik Cooperative Union');
      expect(profile.district, 'Nagpur');
    });

    test('Federation transfer updates worker profile, federationRefId and geographic details', () async {
      final adminRepo = MockAdminRepository();
      
      // Transfer worker W1 (initially Pune) to Nagpur federation
      await adminRepo.transferWorkerFederation(
        'W1',
        '55555555-0000-0000-0000-000000000005',
        'Nagpur District Shramik Cooperative Union',
        reason: 'Relocated to Nagpur central district',
      );

      final workers = await adminRepo.getWorkers();
      final transferred = workers.firstWhere((w) => w.id == 'W1');
      expect(transferred.federationRefId, '55555555-0000-0000-0000-000000000005');
      expect(transferred.guildName, 'Nagpur District Shramik Cooperative Union');
      expect(transferred.district, 'Nagpur');
      expect(transferred.city, 'Nagpur');
    });

    test('Nagpur selection explicitly NEVER yields Sambhajinagar even if pool is sorted alphabetically', () {
      final pool = List<FederationModel>.from(FederationModel.defaultFederations)
        ..sort((a, b) => a.name.compareTo(b.name));
      // First in sorted list is Chhatrapati Sambhajinagar
      expect(pool.first.name, contains('Chhatrapati Sambhajinagar'));

      final byId = FederationModel.resolveFederation(
        federationId: '55555555-0000-0000-0000-000000000005',
        federationsList: pool,
      );
      expect(byId.name, 'Nagpur District Shramik Cooperative Union');
      expect(byId.name, isNot(contains('Sambhajinagar')));

      final byName = FederationModel.resolveFederation(
        federationName: 'Nagpur District Shramik Cooperative Union',
        federationsList: pool,
      );
      expect(byName.name, 'Nagpur District Shramik Cooperative Union');
      expect(byName.name, isNot(contains('Sambhajinagar')));
    });

    test('Null or unmatched parameters default safely to Pune, NEVER Sambhajinagar', () {
      final pool = List<FederationModel>.from(FederationModel.defaultFederations)
        ..sort((a, b) => a.name.compareTo(b.name));
      expect(pool.first.name, contains('Chhatrapati Sambhajinagar'));

      final defaultRes = FederationModel.resolveFederation(
        federationsList: pool,
      );
      expect(defaultRes.id, '11111111-0000-0000-0000-000000000001');
      expect(defaultRes.name, contains('Pune'));
      expect(defaultRes.name, isNot(contains('Sambhajinagar')));
    });
  });
}

