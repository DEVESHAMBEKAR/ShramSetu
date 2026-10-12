import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';
import 'package:app/features/worker/presentation/screens/worker_earnings_screen.dart';
import 'package:app/core/repositories/mock_payment_repository.dart';

void main() {
  setUp(() {
    DI.setup();
    if (DI.paymentRepo is MockPaymentRepository) {
      (DI.paymentRepo as MockPaymentRepository).networkDelay = Duration.zero;
    }
  });

  group('Worker Earnings Real Data Tests', () {
    testWidgets('1. Displays real zero state (₹0 not ₹14280) when worker has zero earnings', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WorkerEarningsScreen(),
        ),
      );

      // Wait for futures to resolve
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify that the fake ₹14280 is NEVER displayed
      expect(find.text('₹14280'), findsNothing);

      // Verify that real ₹0 payout and 0 Jobs are shown
      expect(find.text('₹0'), findsWidgets);
      expect(find.text('0'), findsWidgets);
      expect(find.text('Jobs'), findsOneWidget);
      expect(find.text('none'), findsOneWidget);
      expect(find.text('0.0'), findsOneWidget);
      expect(find.text('hrs'), findsOneWidget);
      expect(find.text('0% Payout'), findsOneWidget);

      // Verify honest disbursal note when zero payouts
      expect(find.textContaining('No payouts settled for this period'), findsOneWidget);

      // Verify empty state for released payouts
      expect(find.text('No released payouts yet'), findsOneWidget);
      expect(find.text('0 Settled'), findsOneWidget);
    });

    testWidgets('2. Switching period tabs updates period title properly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WorkerEarningsScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Default selected is "This Week" (index 1)
      expect(find.text('TOTAL WEEK PAYOUT'), findsOneWidget);

      // Tap "Today" tab
      await tester.tap(find.text('Today'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('TODAY\'S PAYOUT'), findsOneWidget);

      // Tap "This Month" tab
      await tester.tap(find.text('This Month'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('TOTAL MONTH PAYOUT'), findsOneWidget);
    });

    testWidgets('3. Reflects real released payments when escrow is released', (tester) async {
      final mockRepo = DI.paymentRepo as MockPaymentRepository;
      mockRepo.addReleasedPayment(
        bookingId: 'test-booking-101',
        workerId: 'mock-worker-id',
        amount: 500.0,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: WorkerEarningsScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Released payment was ₹500
      expect(find.text('₹500'), findsWidgets);
      expect(find.text('100% Payout'), findsOneWidget);
      expect(find.text('1'), findsWidgets);
      expect(find.text('Jobs'), findsOneWidget);
      expect(find.text('1 Settled'), findsOneWidget);

      // Verify disbursal to bank message is shown with checkmark
      expect(find.textContaining('Disbursed to Bank of Maharashtra'), findsOneWidget);

      // Verify settled payouts list contains Job #TEST-B
      expect(find.textContaining('TEST-B'), findsOneWidget);
    });

    testWidgets('4. Daily income chart displays real amounts and handles benchmark', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WorkerEarningsScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Daily breakdown chart header exists
      expect(find.text('Daily Income Breakdown'), findsOneWidget);
      expect(find.textContaining('Benchmark: ₹1,500/day'), findsOneWidget);
      expect(find.text('Fair Base'), findsOneWidget);

      // All 7 weekday labels are rendered
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
    });

    testWidgets('5. Partner Welfare & Protection reflects dynamic union cess and member details', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: WorkerEarningsScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Partner Welfare & Protection'), findsOneWidget);
      expect(find.text('100% Protected'), findsOneWidget);
      expect(find.text('Accidental & Health Insurance'), findsOneWidget);
      expect(find.text('Welfare Cess Accrued'), findsOneWidget);
      expect(find.text('Micro-Pension (PMSYM)'), findsOneWidget);
      expect(find.text('Tool Upgrade Loan'), findsOneWidget);
    });
  });
}
