import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';
import 'package:app/features/admin/presentation/screens/super_admin_federations_screen.dart';

void main() {
  setUp(() {
    DI.setup();
  });

  group('Super Admin Federations Filtering & Sorting Tests', () {
    testWidgets('1. Renders Filter and Sort Bar with State, District, and Sort dropdowns', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SuperAdminFederationsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header elements
      expect(find.text('Federation Registry & Scoping'), findsOneWidget);

      // Verify Filter Bar Search field
      expect(find.widgetWithText(TextField, 'Search by name, district...'), findsOneWidget);

      // Verify State Dropdown
      expect(find.text('All States'), findsWidgets);

      // Verify District Dropdown
      expect(find.text('All Districts'), findsWidgets);

      // Verify Sort Dropdown (Default: State (A → Z))
      expect(find.text('State (A → Z)'), findsWidgets);
    });

    testWidgets('2. Filters Cooperatives when searching by district name', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SuperAdminFederationsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Initially, Chhatrapati Sambhajinagar is visible
      expect(find.text('Chhatrapati Sambhajinagar Labour Federation'), findsOneWidget);

      // Enter search query 'Sambhajinagar'
      await tester.enterText(find.byType(TextField).first, 'Sambhajinagar');
      await tester.pumpAndSettle();

      // Expect Sambhajinagar federation visible
      expect(find.text('Chhatrapati Sambhajinagar Labour Federation'), findsOneWidget);

      // Verify filter badge '"Sambhajinagar"' appears
      expect(find.text('"Sambhajinagar"'), findsOneWidget);

      // Verify reset button appears and restores view
      final resetBtn = find.text('Reset');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      // Chhatrapati Sambhajinagar should still be visible
      expect(find.text('Chhatrapati Sambhajinagar Labour Federation'), findsOneWidget);
    });

    testWidgets('3. Empty filter state appears when query matches nothing, and Reset button clears', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SuperAdminFederationsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Search non-existent term
      await tester.enterText(find.byType(TextField).first, 'NonExistentPlaceXYZ');
      await tester.pumpAndSettle();

      // Verify Empty state
      expect(find.text('No cooperatives match the active filters'), findsOneWidget);
      expect(find.text('Reset All Filters'), findsOneWidget);

      // Tap Reset All Filters
      await tester.tap(find.text('Reset All Filters'));
      await tester.pumpAndSettle();

      // Verify items restored
      expect(find.text('Chhatrapati Sambhajinagar Labour Federation'), findsOneWidget);
    });

    testWidgets('4. Switching to Federation Admins Directory tab applies filter bar', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: SuperAdminFederationsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find Federation Admins tab
      final adminTab = find.textContaining('Federation Admins');
      expect(adminTab, findsOneWidget);
      await tester.tap(adminTab);
      await tester.pumpAndSettle();

      // Verify filter bar is present on Admins directory view
      expect(find.textContaining('admins'), findsWidgets);
      expect(find.widgetWithText(TextField, 'Search by name, district...'), findsOneWidget);
    });
  });
}
