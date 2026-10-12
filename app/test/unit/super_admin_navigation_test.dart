import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';
import 'package:app/features/admin/presentation/screens/super_admin_main_layout.dart';
import 'package:app/features/admin/presentation/screens/admin_customers_screen.dart';

void main() {
  setUp(() {
    DI.setup();
  });

  group('Super Admin Main Layout Navigation Tests', () {
    testWidgets('1. Desktop Sidebar contains Customers option and navigates to AdminCustomersScreen', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SuperAdminMainLayout(),
        ),
      );
      await tester.pumpAndSettle();

      // Check sidebar navigation items
      expect(find.widgetWithText(InkWell, 'Dashboard'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Federations'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'All Workers'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Customers'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Audit Logs'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Settings'), findsOneWidget);

      // Tap on Customers in the sidebar
      await tester.tap(find.widgetWithText(InkWell, 'Customers'));
      await tester.pumpAndSettle();

      // Should display AdminCustomersScreen
      expect(find.byType(AdminCustomersScreen), findsOneWidget);
    });

    testWidgets('2. Mobile Bottom Navigation contains Customers nav item', (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SuperAdminMainLayout(),
        ),
      );
      await tester.pumpAndSettle();

      // Find bottom nav bar
      final bottomNavBarFinder = find.byType(SafeArea);
      expect(find.descendant(of: bottomNavBarFinder, matching: find.text('Overview')), findsOneWidget);
      expect(find.descendant(of: bottomNavBarFinder, matching: find.text('Federations')), findsOneWidget);
      expect(find.descendant(of: bottomNavBarFinder, matching: find.text('Workers')), findsOneWidget);
      expect(find.descendant(of: bottomNavBarFinder, matching: find.text('Customers')), findsOneWidget);
      expect(find.descendant(of: bottomNavBarFinder, matching: find.text('Audit')), findsOneWidget);
      expect(find.descendant(of: bottomNavBarFinder, matching: find.text('Settings')), findsOneWidget);

      // Tap Customers bottom nav item
      await tester.tap(find.descendant(of: bottomNavBarFinder, matching: find.text('Customers')));
      await tester.pumpAndSettle();

      // Should display AdminCustomersScreen
      expect(find.byType(AdminCustomersScreen), findsOneWidget);
    });
  });
}
