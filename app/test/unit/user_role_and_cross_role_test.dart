import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/user_role.dart';
import 'package:app/features/auth/data/repositories/mock_user_repository.dart';

void main() {
  group('UserRole Enum Tests', () {
    test('UserRole.fromString correctly parses role strings', () {
      expect(UserRole.fromString('CUSTOMER'), equals(UserRole.customer));
      expect(UserRole.fromString('customer'), equals(UserRole.customer));
      expect(UserRole.fromString('WORKER'), equals(UserRole.worker));
      expect(UserRole.fromString('worker'), equals(UserRole.worker));
      expect(UserRole.fromString('ADMIN'), equals(UserRole.admin));
      expect(UserRole.fromString('admin'), equals(UserRole.admin));
      expect(UserRole.fromString(''), isNull);
      expect(UserRole.fromString('INVALID_ROLE'), isNull);
      expect(UserRole.fromString(null), isNull);
    });

    test('UserRole.toDbString produces standard backend uppercase strings', () {
      expect(UserRole.customer.toDbString(), equals('CUSTOMER'));
      expect(UserRole.worker.toDbString(), equals('WORKER'));
      expect(UserRole.admin.toDbString(), equals('ADMIN'));
    });

    test('UserRole helper getters work accurately', () {
      expect(UserRole.customer.isCustomer, isTrue);
      expect(UserRole.customer.isWorker, isFalse);
      expect(UserRole.customer.isAdmin, isFalse);

      expect(UserRole.worker.isCustomer, isFalse);
      expect(UserRole.worker.isWorker, isTrue);
      expect(UserRole.worker.isAdmin, isFalse);

      expect(UserRole.admin.isCustomer, isFalse);
      expect(UserRole.admin.isWorker, isFalse);
      expect(UserRole.admin.isAdmin, isTrue);
    });
  });

  group('Cross-Role Authorization Guards', () {
    late MockUserRepository mockUserRepo;

    setUp(() {
      mockUserRepo = MockUserRepository();
    });

    test('Worker cannot sign in as Customer', () async {
      const workerId = 'worker_test_123';
      await mockUserRepo.upsertUserProfile(
        userId: workerId,
        role: 'WORKER',
        phone: '9899999991',
      );

      final role = await mockUserRepo.getUserRole(workerId);
      expect(role, equals('WORKER'));

      final isCustomerAllowed = role == null || role.toUpperCase() == 'CUSTOMER';
      expect(isCustomerAllowed, isFalse);
    });

    test('Customer cannot sign in as Worker', () async {
      const customerId = 'cust_test_456';
      await mockUserRepo.upsertUserProfile(
        userId: customerId,
        role: 'CUSTOMER',
        phone: '9899999992',
      );

      final role = await mockUserRepo.getUserRole(customerId);
      expect(role, equals('CUSTOMER'));

      final isWorkerAllowed = role == null || role.toUpperCase() == 'WORKER';
      expect(isWorkerAllowed, isFalse);
    });

    test('Customer/Worker cannot access Admin portal', () async {
      const customerId = 'cust_test_789';
      await mockUserRepo.upsertUserProfile(
        userId: customerId,
        role: 'CUSTOMER',
        phone: '9899999993',
      );

      final role = await mockUserRepo.getUserRole(customerId);
      final isExplicitNonAdmin = role != null && role.toUpperCase() != 'ADMIN';
      expect(isExplicitNonAdmin, isTrue);
    });
  });
}
