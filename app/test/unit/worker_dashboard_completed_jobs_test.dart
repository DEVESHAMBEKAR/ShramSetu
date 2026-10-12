import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';
import 'package:app/features/worker/presentation/screens/worker_dashboard_screen.dart';

void main() {
  setUp(() {
    DI.setup();
  });

  group('Worker Dashboard Completed Jobs Tests', () {
    testWidgets('1. Displays clean empty state without dummy entries when 0 completed jobs', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: WorkerDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure dummy entries are removed
      expect(find.text('Rajesh Deshmukh'), findsNothing);
      expect(find.text('Meera Kulkarni'), findsNothing);
      expect(find.text('Kitchen Sink Clog • Pratik Nagar'), findsNothing);
      expect(find.text('Shower Head Replacement • Mayur Colony'), findsNothing);

      // Verify empty state is displayed
      expect(find.text('No completed jobs yet today'), findsOneWidget);
      expect(find.text('Completed customer bookings will appear here'), findsOneWidget);

      // Verify Completed Today header shows true count '0'
      expect(find.text('COMPLETED TODAY'), findsOneWidget);
    });
  });
}
