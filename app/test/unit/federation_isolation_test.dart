import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';
import 'package:app/core/services/federation_scope_service.dart';
import 'package:app/features/admin/data/repositories/mock_admin_repository.dart';

class _FakeFederationScopeService extends Fake implements FederationScopeService {
  final bool _global;
  final List<String> _authIds;

  _FakeFederationScopeService({required bool isGlobal, required List<String> authorizedIds})
      : _global = isGlobal,
        _authIds = authorizedIds;

  @override
  Future<bool> hasGlobalScope() async => _global;

  @override
  Future<List<String>> getAuthorizedFederationIds() async => _global ? [] : _authIds;

  @override
  Future<String> getAdminRole() async => _global ? 'SUPER_ADMIN' : 'FEDERATION_ADMIN';

  @override
  Future<String> getScopeDescription() async =>
      _global ? 'All Federations (National)' : 'Pune District Labour Cooperative Federation';
}

void main() {
  setUp(() {
    DI.federationScopeService = null;
  });

  group('Strict Federation Worker and Customer Isolation Tests', () {
    test('Super Admin has global scope and accesses all workers across all federations', () async {
      DI.federationScopeService = _FakeFederationScopeService(
        isGlobal: true,
        authorizedIds: [],
      );

      final repo = MockAdminRepository();
      final workers = await repo.getWorkers();

      expect(workers.length, greaterThanOrEqualTo(5));

      // Contains workers across diverse federations
      final federationIds = workers.map((w) => w.federationRefId).toSet();
      expect(federationIds, contains('11111111-0000-0000-0000-000000000001')); // Pune
      expect(federationIds, contains('22222222-0000-0000-0000-000000000002')); // Nashik
      expect(federationIds, contains('33333333-0000-0000-0000-000000000003')); // Mumbai
      expect(federationIds, contains('55555555-0000-0000-0000-000000000005')); // Nagpur
    });

    test('Pune Federation Admin ONLY sees Pune workers, strictly zero leak from other federations', () async {
      DI.federationScopeService = _FakeFederationScopeService(
        isGlobal: false,
        authorizedIds: ['11111111-0000-0000-0000-000000000001'],
      );

      final repo = MockAdminRepository();
      final workers = await repo.getWorkers();

      expect(workers.isNotEmpty, isTrue);

      // Verify every single worker strictly belongs to Pune Federation
      for (final worker in workers) {
        expect(worker.federationRefId, equals('11111111-0000-0000-0000-000000000001'));
        expect(worker.district?.toLowerCase(), equals('pune'));
      }

      // Verify no leak of Nashik, Mumbai, or Nagpur workers
      final names = workers.map((w) => w.name).toList();
      expect(names, isNot(contains('Kavita More'))); // Nashik worker
      expect(names, isNot(contains('Mohd Rafiq'))); // Mumbai worker
      expect(names, isNot(contains('Santosh Bisen'))); // Nagpur worker
    });

    test('Nashik Federation Admin ONLY sees Nashik workers', () async {
      DI.federationScopeService = _FakeFederationScopeService(
        isGlobal: false,
        authorizedIds: ['22222222-0000-0000-0000-000000000002'],
      );

      final repo = MockAdminRepository();
      final workers = await repo.getWorkers();

      expect(workers.isNotEmpty, isTrue);

      for (final worker in workers) {
        expect(worker.federationRefId, equals('22222222-0000-0000-0000-000000000002'));
        expect(worker.district?.toLowerCase(), equals('nashik'));
      }

      final names = workers.map((w) => w.name).toList();
      expect(names, contains('Kavita More'));
      expect(names, isNot(contains('Ganesh Shinde'))); // Pune worker
      expect(names, isNot(contains('Mohd Rafiq'))); // Mumbai worker
    });

    test('Super Admin has global scope and accesses all customers across all federations and locations', () async {
      DI.federationScopeService = _FakeFederationScopeService(
        isGlobal: true,
        authorizedIds: [],
      );

      final repo = MockAdminRepository();
      final customers = await repo.getCustomers();

      expect(customers.length, greaterThanOrEqualTo(5));

      final cities = customers.map((c) => c.city).toSet();
      expect(cities, contains('Pune'));
      expect(cities, contains('Nashik'));
      expect(cities, contains('Mumbai'));
      expect(cities, contains('Nagpur'));
    });

    test('Pune Federation Admin ONLY sees Pune customers, strictly zero leak from other federations', () async {
      DI.federationScopeService = _FakeFederationScopeService(
        isGlobal: false,
        authorizedIds: ['11111111-0000-0000-0000-000000000001'],
      );

      final repo = MockAdminRepository();
      final customers = await repo.getCustomers();

      expect(customers.isNotEmpty, isTrue);

      for (final customer in customers) {
        final isPune = customer.federationId == '11111111-0000-0000-0000-000000000001' ||
            customer.district?.toLowerCase() == 'pune' ||
            customer.city?.toLowerCase() == 'pune';
        expect(isPune, isTrue);
      }

      final names = customers.map((c) => c.name).toList();
      expect(names, contains('Amit Patil'));
      expect(names, contains('Neha Sharma'));
      expect(names, isNot(contains('Rajesh Jadhav'))); // Nashik customer
      expect(names, isNot(contains('Priya Merchant'))); // Mumbai customer
      expect(names, isNot(contains('Manoj Verma'))); // Nagpur customer
    });

    test('Federation admin dashboard stats are scoped to their federation', () async {
      DI.federationScopeService = _FakeFederationScopeService(
        isGlobal: false,
        authorizedIds: ['11111111-0000-0000-0000-000000000001'],
      );

      final repo = MockAdminRepository();
      final stats = await repo.getDashboardStats();

      // Only Pune workers should be counted
      expect(stats.totalWorkers, equals(3));
    });

    test('FederationScopeService defaults to FEDERATION_ADMIN and Pune scope when unauthenticated or non-superadmin', () async {
      final scope = FederationScopeService();
      expect(await scope.getAdminRole(), equals('FEDERATION_ADMIN'));
      expect(await scope.hasGlobalScope(), isFalse);
      final authIds = await scope.getAuthorizedFederationIds();
      expect(authIds, contains('11111111-0000-0000-0000-000000000001'));
      expect(await scope.getScopeDescription(), equals('Pune District Labour Cooperative Federation'));
    });

    test('Federation admin cannot view worker application from another federation', () async {
      DI.federationScopeService = _FakeFederationScopeService(
        isGlobal: false,
        authorizedIds: ['11111111-0000-0000-0000-000000000001'],
      );

      final repo = MockAdminRepository();
      final workers = await repo.getWorkers();

      // All returned workers belong to Pune; Nashik worker Kavita is excluded
      expect(workers.any((w) => w.name == 'Kavita More'), isFalse);
      expect(workers.any((w) => w.federationRefId == '22222222-0000-0000-0000-000000000002'), isFalse);
    });
  });
}
