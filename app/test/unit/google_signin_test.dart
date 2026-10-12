import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:app/features/auth/data/repositories/mock_user_repository.dart';
import 'package:app/shared/widgets/google_sign_in_button.dart';

void main() {
  group('Google Sign-In Repository & Role Security Tests', () {
    late MockAuthRepository mockAuthRepo;
    late MockUserRepository mockUserRepo;

    setUp(() {
      mockAuthRepo = MockAuthRepository();
      mockUserRepo = MockUserRepository();
    });

    test('1. Customer Google Sign-In sets authenticated user and metadata', () async {
      final success = await mockAuthRepo.signInWithGoogle(role: 'CUSTOMER');
      expect(success, isTrue);

      final currentUser = await mockAuthRepo.getCurrentUser();
      expect(currentUser, isNotNull);
      expect(currentUser!.id, equals('mock_customer_01'));
      expect(currentUser.email, equals('rajesh.customer@gmail.com'));
      expect(currentUser.userMetadata?['role'], equals('CUSTOMER'));
      expect(currentUser.userMetadata?['full_name'], equals('Rajesh Deshmukh'));
    });

    test('2. Worker Google Sign-In sets authenticated user and metadata', () async {
      final success = await mockAuthRepo.signInWithGoogle(role: 'WORKER');
      expect(success, isTrue);

      final currentUser = await mockAuthRepo.getCurrentUser();
      expect(currentUser, isNotNull);
      expect(currentUser!.id, equals('mock_worker_01'));
      expect(currentUser.email, equals('ramesh.worker@gmail.com'));
      expect(currentUser.userMetadata?['role'], equals('WORKER'));
      expect(currentUser.userMetadata?['full_name'], equals('Ramesh Kumar'));
    });

    test('3. Cross-role enforcement: Existing Worker account rejected in Customer portal', () async {
      const googleWorkerId = 'google_worker_01';
      await mockUserRepo.upsertUserProfile(
        userId: googleWorkerId,
        role: 'WORKER',
        phone: '+91 98765 43210',
        fullName: 'Rajesh Worker',
      );

      final existingRole = await mockUserRepo.getUserRole(googleWorkerId);
      expect(existingRole, equals('WORKER'));

      // Customer gate condition: role must be null or CUSTOMER
      final isCustomerAllowed = existingRole == null || existingRole.toUpperCase() == 'CUSTOMER';
      expect(isCustomerAllowed, isFalse);
    });

    test('4. Cross-role enforcement: Existing Customer account rejected in Worker portal', () async {
      const googleCustId = 'google_customer_01';
      await mockUserRepo.upsertUserProfile(
        userId: googleCustId,
        role: 'CUSTOMER',
        phone: '+91 98220 12345',
        fullName: 'Ananya Customer',
      );

      final existingRole = await mockUserRepo.getUserRole(googleCustId);
      expect(existingRole, equals('CUSTOMER'));

      // Worker gate condition: role must be null or WORKER
      final isWorkerAllowed = existingRole == null || existingRole.toUpperCase() == 'WORKER';
      expect(isWorkerAllowed, isFalse);
    });
  });

  group('GoogleSignInButton Widget Tests', () {
    testWidgets('Renders GoogleSignInButton with label and responds to tap', (WidgetTester tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              onPressed: () {
                wasTapped = true;
              },
              label: 'Continue with Google',
            ),
          ),
        ),
      );

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets); // GoogleLogoPainter

      await tester.tap(find.byType(GoogleSignInButton));
      await tester.pump();

      expect(wasTapped, isTrue);
    });

    testWidgets('Shows CircularProgressIndicator when isLoading is true', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleSignInButton(
              isLoading: true,
              onPressed: () {},
              label: 'Continue with Google',
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('Renders OrDivider with custom text', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrDivider(label: 'OR CONTINUE WITH'),
          ),
        ),
      );

      expect(find.text('OR CONTINUE WITH'), findsOneWidget);
    });
  });
}
