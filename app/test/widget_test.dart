import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/customer/presentation/screens/splash_screen.dart';

import 'package:app/core/config/dependency_injection.dart';
import 'package:app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:app/features/auth/data/repositories/mock_user_repository.dart';

import 'package:app/features/customer/data/repositories/mock_customer_repository.dart';

void main() {
  testWidgets('App starts with splash screen', (WidgetTester tester) async {
    DI.authRepo = MockAuthRepository();
    DI.userRepo = MockUserRepository();
    DI.customerRepo = MockCustomerRepository();

    await tester.pumpWidget(MaterialApp(
      home: const SplashScreen(),
      routes: {'/onboarding': (context) => const SizedBox()},
    ));

    // Verify that the splash screen shows the title.
    expect(find.text('ShramSetu'), findsOneWidget);
    expect(find.text('श्रमसेतू सहकार मंच'), findsOneWidget);

    // Fast-forward the splash screen timer to clear it
    await tester.pump(const Duration(seconds: 2));
  });
}
