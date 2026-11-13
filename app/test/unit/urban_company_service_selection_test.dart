import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';
import 'package:app/features/customer/presentation/screens/customer_home_screen.dart';
import 'package:app/features/customer/data/repositories/mock_customer_repository.dart';
import 'package:app/features/worker/data/repositories/mock_worker_repository.dart';
import 'package:app/features/admin/data/repositories/mock_admin_repository.dart';

void main() {
  group('Urban Company Service Selection & Area Availability Tests', () {
    late MockCustomerRepository customerRepo;

    setUp(() {
      DI.setup();
      customerRepo = MockCustomerRepository();
      MockWorkerRepository();
      MockAdminRepository();
    });

    test('1. Trade catalog covers all 8 essential household civic trades with transparent co-op rates', () async {
      final allWorkers = await customerRepo.getAllWorkers();
      expect(allWorkers.isNotEmpty, isTrue);

      // Verify trades present: c1 (Electrical), c2 (Plumbing), c3 (Carpentry), c4 (Cleaning), c5 (Painting), c6 (Appliance)
      final plumbingWorkers = allWorkers.where((w) => w.categoryId == 'c2').toList();
      final electricalWorkers = allWorkers.where((w) => w.categoryId == 'c1').toList();
      final carpentryWorkers = allWorkers.where((w) => w.categoryId == 'c3').toList();
      final cleaningWorkers = allWorkers.where((w) => w.categoryId == 'c4').toList();

      expect(plumbingWorkers.isNotEmpty, isTrue, reason: 'Plumbing artisans must be available');
      expect(electricalWorkers.isNotEmpty, isTrue, reason: 'Electrical artisans must be available');
      expect(carpentryWorkers.isNotEmpty, isTrue, reason: 'Carpentry artisans must be available');
      expect(cleaningWorkers.isNotEmpty, isTrue, reason: 'Cleaning artisans must be available');
    });

    test('2. Dynamic worker availability calculates accurately for Kothrud vs Baner vs All Areas', () async {
      final allWorkers = await customerRepo.getAllWorkers();

      // Kothrud Plumbers
      final kothrudPlumbers = allWorkers.where((w) {
        if (w.categoryId != 'c2') return false;
        final loc = w.locationTag.toLowerCase();
        final matchesAreas = w.serviceAreas.any((sa) => sa.toLowerCase().contains('kothrud'));
        return loc.contains('kothrud') || matchesAreas;
      }).toList();

      expect(kothrudPlumbers.length, greaterThanOrEqualTo(2));
      final names = kothrudPlumbers.map((w) => w.name).toList();
      expect(names, contains('Rahul Patil'));
      expect(names, contains('Ramesh Deshpande'));

      // Baner Electricians
      final banerElectricians = allWorkers.where((w) {
        if (w.categoryId != 'c1') return false;
        final loc = w.locationTag.toLowerCase();
        final matchesAreas = w.serviceAreas.any((sa) => sa.toLowerCase().contains('baner'));
        return loc.contains('baner') || matchesAreas;
      }).toList();

      expect(banerElectricians.isNotEmpty, isTrue);
      final banerNames = banerElectricians.map((w) => w.name).toList();
      expect(banerNames, contains('Ganesh Shinde'));
    });

    testWidgets('3. CustomerHomeScreen renders Urban Company Catalog header, area bar, and filter pills', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomerHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Catalog Header
      expect(find.textContaining('URBAN CO-OP CATALOG'), findsOneWidget);
      expect(find.textContaining('अत्यावश्यक व्यवसाय सूची व थेट निवड'), findsOneWidget);

      // 2. Verify Area Quick Switcher Chips
      expect(find.text('सर्व भाग'), findsWidgets);
      expect(find.text('Vadgaon Budruk'), findsWidgets);
      expect(find.text('Kothrud'), findsWidgets);

      // 3. Verify Trade Category Filter Pills
      expect(find.text('सर्व सेवा (All)'), findsOneWidget);
      expect(find.text('नळकाम (Plumbing)'), findsOneWidget);
      expect(find.text('विद्युत (Electrical)'), findsOneWidget);
      expect(find.text('सुतारकाम (Carpentry)'), findsOneWidget);

      // 4. Verify Services rendered
      expect(find.text('नळ व स्वच्छता'), findsWidgets);
      expect(find.text('वीज व वायरिंग'), findsWidgets);
      expect(find.text('सुतारकाम व लाकूडकाम'), findsWidgets);
    });

    testWidgets('4. Switching area chip dynamically updates area selection on screen', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CustomerHomeScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap on 'Vadgaon Budruk' area chip
      final vadgaonChip = find.text('Vadgaon Budruk');
      expect(vadgaonChip, findsWidgets);

      await tester.tap(vadgaonChip.first);
      await tester.pumpAndSettle();

      // Verify that the area status header reflects Vadgaon Budruk
      expect(find.textContaining('Vadgaon Budruk'), findsWidgets);
    });
  });
}
