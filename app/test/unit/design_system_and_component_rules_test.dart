import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/booking_status.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/localization/locale_controller.dart';
import 'package:app/core/localization/app_strings.dart';
import 'package:app/shared/widgets/booking_status_badge.dart';
import 'package:app/shared/widgets/state_views.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Design System Color Palette Tokens', () {
    test('1. Canonical color palette constants exist and match specification', () {
      // Primary actions: Deep teal
      expect(AppColors.deepTeal, const Color(0xFF0D5C5B));
      expect(AppColors.primaryAction, AppColors.deepTeal);

      // Page background: Soft white
      expect(AppColors.softWhite, const Color(0xFFF8F9FA));
      expect(AppColors.pageBackground, AppColors.softWhite);

      // Highlights: Warm amber
      expect(AppColors.warmAmber, const Color(0xFFD97706));
      expect(AppColors.highlight, AppColors.warmAmber);

      // Success states: Green
      expect(AppColors.successGreen, const Color(0xFF16A34A));
      expect(AppColors.successGreenContainer, const Color(0xFFDCFCE7));

      // Core tokens mapped to canonical palette
      expect(AppColors.primary, AppColors.deepTeal);
      expect(AppColors.background, AppColors.softWhite);
      expect(AppColors.secondary, AppColors.warmAmber);
      expect(AppColors.success, AppColors.successGreen);
    });
  });

  group('Accessible BookingStatusBadge Component Tests', () {
    testWidgets('2. Renders distinct icon, text label, and does not rely on color alone', (tester) async {
      final statuses = [
        BookingStatus.pending,
        BookingStatus.accepted,
        BookingStatus.onTheWay,
        BookingStatus.arrived,
        BookingStatus.inProgress,
        BookingStatus.completed,
        BookingStatus.rejected,
        BookingStatus.cancelled,
      ];

      final seenIcons = <IconData>{};

      for (final status in statuses) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BookingStatusBadge(status: status),
            ),
          ),
        );

        // Every status has an icon
        final iconFinder = find.byType(Icon);
        expect(iconFinder, findsOneWidget);
        final icon = tester.widget<Icon>(iconFinder).icon!;
        expect(seenIcons.contains(icon), isFalse, reason: 'Duplicate icon used for $status: $icon');
        seenIcons.add(icon);

        // Every status has a text label
        expect(find.text(status.label), findsOneWidget);

        // Every status has screen reader semantics
        final semanticsFinder = find.byWidgetPredicate(
          (w) => w is Semantics && (w.properties.label?.contains(status.label) ?? false),
        );
        expect(semanticsFinder, findsOneWidget);
      }

      // 8 statuses with 8 distinct icons
      expect(seenIcons.length, 8);
    });

    testWidgets('3. fromString factory safely parses DB status string and renders badge', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                BookingStatusBadge.fromString('in_progress'),
                BookingStatusBadge.fromString('ontheway', isCompact: true),
                BookingStatusBadge.fromString(null),
              ],
            ),
          ),
        ),
      );

      expect(find.text('In progress'), findsOneWidget);
      expect(find.text('On the way'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
    });
  });

  group('Data-Driven State Views Tests', () {
    testWidgets('4. AppLoadingView renders progress indicator and localized message', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppLoadingView(message: 'Loading bookings...'),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading bookings...'), findsOneWidget);
    });

    testWidgets('5. AppEmptyView renders icon, title, subtitle, and fires action callback', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppEmptyView(
              icon: Icons.inventory_2_outlined,
              title: 'No Bookings Found',
              subtitle: 'You have not booked any services yet.',
              actionLabel: 'Book a Service',
              onActionPressed: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      expect(find.text('No Bookings Found'), findsOneWidget);
      expect(find.text('You have not booked any services yet.'), findsOneWidget);
      expect(find.text('Book a Service'), findsOneWidget);

      await tester.tap(find.text('Book a Service'));
      await tester.pump();
      expect(actionTapped, isTrue);
    });

    testWidgets('6. AppErrorView renders error card and fires onRetry callback', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppErrorView(
              title: 'Unable to Load Data',
              message: 'Failed to connect to backend server.',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      expect(find.text('Unable to Load Data'), findsOneWidget);
      expect(find.text('Failed to connect to backend server.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      await tester.pump();
      expect(retried, isTrue);
    });

    testWidgets('7. AppOfflineView renders Wi-Fi offline notice and fires retry callback', (tester) async {
      bool retryConnectionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppOfflineView(
              onRetry: () => retryConnectionTapped = true,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
      expect(find.text("You're Currently Offline"), findsOneWidget);
      expect(find.text('Retry Connection'), findsOneWidget);

      await tester.tap(find.text('Retry Connection'));
      await tester.pump();
      expect(retryConnectionTapped, isTrue);
    });
  });

  group('Multi-Lingual Text Handling (English, Marathi, Hindi)', () {
    test('8. Statuses and state strings translate cleanly into Marathi and Hindi', () {
      // English
      LocaleController.instance.setLanguage('en');
      expect('Pending'.tr(), 'Pending');
      expect('Completed'.tr(), 'Completed');
      expect('Try Again'.tr(), 'Try Again');

      // Marathi
      LocaleController.instance.setLanguage('mr');
      expect('Pending'.tr(), 'प्रलंबित');
      expect('Completed'.tr(), 'पूर्ण झाले');
      expect('Try Again'.tr(), 'पुन्हा प्रयत्न करा');
      expect('Collapse Sidebar'.tr(), 'साइडबार लहान करा');

      // Hindi
      LocaleController.instance.setLanguage('hi');
      expect('Pending'.tr(), 'लंबित');
      expect('Completed'.tr(), 'पूर्ण हुआ');
      expect('Try Again'.tr(), 'पुनः प्रयास करें');
      expect('Collapse Sidebar'.tr(), 'साइडबार छोटा करें');

      // Reset to English
      LocaleController.instance.setLanguage('en');
    });
  });
}
