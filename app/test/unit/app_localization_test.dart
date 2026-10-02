import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/localization/locale_controller.dart';
import 'package:app/core/localization/app_strings.dart';

void main() {
  group('LocaleController & AppStrings Unit Tests', () {
    setUp(() {
      LocaleController.instance.reset();
    });

    tearDown(() {
      LocaleController.instance.reset();
    });

    test('LocaleController initializes with English and toggles through languages', () {
      expect(LocaleController.instance.languageCode, equals('en'));
      expect(LocaleController.instance.isEnglish, isTrue);
      expect(LocaleController.instance.isMarathi, isFalse);
      expect(LocaleController.instance.isHindi, isFalse);

      LocaleController.instance.toggleNextLanguage();
      expect(LocaleController.instance.languageCode, equals('mr'));
      expect(LocaleController.instance.isMarathi, isTrue);

      LocaleController.instance.toggleNextLanguage();
      expect(LocaleController.instance.languageCode, equals('hi'));
      expect(LocaleController.instance.isHindi, isTrue);

      LocaleController.instance.toggleNextLanguage();
      expect(LocaleController.instance.languageCode, equals('en'));
      expect(LocaleController.instance.isEnglish, isTrue);
    });

    test('LocaleController notifies listeners on language change', () {
      int notifyCount = 0;
      void listener() {
        notifyCount++;
      }

      LocaleController.instance.addListener(listener);

      LocaleController.instance.setLanguage('mr');
      expect(notifyCount, equals(1));
      expect(LocaleController.instance.languageCode, equals('mr'));

      // Setting same language should not redundantly notify
      LocaleController.instance.setLanguage('mr');
      expect(notifyCount, equals(1));

      LocaleController.instance.setLanguage('hi');
      expect(notifyCount, equals(2));
      expect(LocaleController.instance.languageCode, equals('hi'));

      LocaleController.instance.removeListener(listener);
    });

    test('AppStrings translates correctly in English, Marathi, and Hindi', () {
      // English
      expect(AppStrings.tr('Dashboard', 'en'), equals('Dashboard'));
      expect(AppStrings.tr('Worker Earnings', 'en'), equals('Worker Earnings'));
      expect(AppStrings.tr('Popular Services', 'en'), equals('Popular Services'));
      expect(AppStrings.tr('Services Near You', 'en'), equals('Services Near You'));

      // Marathi
      expect(AppStrings.tr('Dashboard', 'mr'), equals('डॅशबोर्ड'));
      expect(AppStrings.tr('Worker Earnings', 'mr'), equals('कामगार कमाई'));
      expect(AppStrings.tr('Popular Services', 'mr'), equals('लोकप्रिय सेवा'));
      expect(AppStrings.tr('Services Near You', 'mr'), equals('आपल्या परिसरातील सेवा'));
      expect(AppStrings.tr('Electrician', 'mr'), equals('इलेक्ट्रिशियन'));
      expect(AppStrings.tr('Plumber', 'mr'), equals('प्लंबर'));

      // Hindi
      expect(AppStrings.tr('Dashboard', 'hi'), equals('डैशबोर्ड'));
      expect(AppStrings.tr('Worker Earnings', 'hi'), equals('श्रमिक कमाई'));
      expect(AppStrings.tr('Popular Services', 'hi'), equals('लोकप्रिय सेवाएं'));
      expect(AppStrings.tr('Services Near You', 'hi'), equals('आपके आस-पास की सेवाएं'));
      expect(AppStrings.tr('Electrician', 'hi'), equals('इलेक्ट्रीशियन'));
      expect(AppStrings.tr('Plumber', 'hi'), equals('प्लंबर'));
    });

    test('String extension .tr() resolves dynamically according to LocaleController', () {
      LocaleController.instance.setLanguage('en');
      expect('Home'.tr(), equals('Home'));
      expect('Earnings'.tr(), equals('Earnings'));

      LocaleController.instance.setLanguage('mr');
      expect('Home'.tr(), equals('मुख्यपृष्ठ'));
      expect('Earnings'.tr(), equals('कमाई'));

      LocaleController.instance.setLanguage('hi');
      expect('Home'.tr(), equals('होम'));
      expect('Earnings'.tr(), equals('कमाई'));
    });

    test('AppStrings safely falls back for missing or unknown keys', () {
      expect('NonExistentKey_12345'.tr('en'), equals('NonExistentKey_12345'));
      expect('NonExistentKey_12345'.tr('mr'), equals('NonExistentKey_12345'));
      expect('NonExistentKey_12345'.tr('hi'), equals('NonExistentKey_12345'));
    });
  });

  group('Reactive Widget Localization Tests', () {
    setUp(() {
      LocaleController.instance.reset();
    });

    tearDown(() {
      LocaleController.instance.reset();
    });

    testWidgets('Widget rebuilds and updates text across languages upon LocaleController change', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: LocaleController.instance,
              builder: (context, _) {
                return Column(
                  children: [
                    Text('Dashboard'.tr()),
                    Text('Popular Services'.tr()),
                    Text('Services Near You'.tr()),
                  ],
                );
              },
            ),
          ),
        ),
      );

      // Verify English default
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Popular Services'), findsOneWidget);
      expect(find.text('Services Near You'), findsOneWidget);

      // Switch to Marathi
      LocaleController.instance.setLanguage('mr');
      await tester.pumpAndSettle();

      expect(find.text('डॅशबोर्ड'), findsOneWidget);
      expect(find.text('लोकप्रिय सेवा'), findsOneWidget);
      expect(find.text('आपल्या परिसरातील सेवा'), findsOneWidget);
      expect(find.text('Dashboard'), findsNothing);

      // Switch to Hindi
      LocaleController.instance.setLanguage('hi');
      await tester.pumpAndSettle();

      expect(find.text('डैशबोर्ड'), findsOneWidget);
      expect(find.text('लोकप्रिय सेवाएं'), findsOneWidget);
      expect(find.text('आपके आस-पास की सेवाएं'), findsOneWidget);
      expect(find.text('डॅशबोर्ड'), findsNothing);

      // Switch back to English
      LocaleController.instance.setLanguage('en');
      await tester.pumpAndSettle();

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Popular Services'), findsOneWidget);
      expect(find.text('Services Near You'), findsOneWidget);
    });
  });
}
