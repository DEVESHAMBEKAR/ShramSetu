import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';
import 'package:app/features/worker/presentation/widgets/worker_top_app_bar_actions.dart';
import 'package:app/features/worker/data/models/worker_models.dart';

void main() {
  setUp(() {
    DI.setup();
  });

  final testWorker = WorkerProfile(
    id: 'worker-101',
    name: 'Devesh Ambekar',
    profileImage: '',
    phone: '+919876543210',
    skills: const ['Electrician'],
    experience: '5 years',
    rating: 4.8,
    reviewCount: 24,
    completedJobs: 12,
    earnings: 25000.0,
    isVerified: true,
    verificationStatus: VerificationStatus.approved,
    isAvailable: true,
    serviceLocation: 'Pune',
    guildId: '101',
    guildName: 'Pune District Labour Cooperative Federation',
  );

  group('WorkerTopAppBarActions Widget Tests', () {
    testWidgets('1. Renders Language toggle, Support Agent icon, and Initials Avatar', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                WorkerTopAppBarActions(worker: testWorker, showAvatar: true),
              ],
            ),
          ),
        ),
      );

      // Verify initials "DA" from "Devesh Ambekar"
      expect(find.text('DA'), findsOneWidget);
      // Verify Support Agent icon
      expect(find.byIcon(Icons.support_agent), findsOneWidget);
      // Verify RichText with 'म' and '/EN'
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('2. Tapping म/EN opens Language Selection modal sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                WorkerTopAppBarActions(worker: testWorker, showAvatar: true),
              ],
            ),
          ),
        ),
      );

      // Tap on the language toggle
      await tester.tap(find.byType(RichText).first);
      await tester.pumpAndSettle();

      // Language modal sheet should appear
      expect(find.text('Select Language / भाषा निवडा'), findsOneWidget);
      expect(find.text('मराठी (Marathi)'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('हिंदी (Hindi)'), findsOneWidget);

      // Tap on English
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      // Modal is dismissed
      expect(find.text('Select Language / भाषा निवडा'), findsNothing);
    });

    testWidgets('3. Tapping Support Agent icon opens Helpdesk sheet', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                WorkerTopAppBarActions(worker: testWorker, showAvatar: true),
              ],
            ),
          ),
        ),
      );

      // Tap Support icon
      await tester.tap(find.byIcon(Icons.support_agent));
      await tester.pumpAndSettle();

      // Helpdesk modal sheet should appear
      expect(find.text('Worker Support & Guild Desk'), findsOneWidget);
      expect(find.text('Union Cooperative Toll-Free Helpline'), findsOneWidget);
      expect(find.text('1800-266-9090 (Toll-Free, 9 AM - 7 PM)'), findsOneWidget);
      expect(find.text('On-Site Safety & Dispute SOS'), findsOneWidget);
    });

    testWidgets('4. Tapping Avatar circle navigates to WorkerProfileSettingsScreen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              actions: [
                WorkerTopAppBarActions(worker: testWorker, showAvatar: true),
              ],
            ),
          ),
        ),
      );

      // Tap Avatar circle
      await tester.tap(find.text('DA'));
      await tester.pumpAndSettle();

      // Should have navigated to Profile Settings Screen
      expect(find.text('Profile & Settings'), findsOneWidget);
    });
  });
}
