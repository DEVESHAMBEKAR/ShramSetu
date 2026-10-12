import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';

void main() {
  setUp(() {
    DI.setup();
  });

  test('Registered Electrician only appears under Electrical and NEVER under Plumbing (No dummy entries)', () async {
    const electricianId = 'worker_test_electrician_101';
    const electricianName = 'Anand Joshi';

    // 1. Worker registers as an Electrician
    await DI.workerRepo.registerWorker(
      workerId: electricianId,
      fullName: electricianName,
      phone: '9822001122',
      skill: 'Domestic Electrical Wiring & Repairs',
      experienceYears: 6,
      serviceLocation: 'Baner, Pune',
      trade: 'Electrician',
      bio: 'Certified Electrician & Union Guild Master. Expert in domestic wiring and emergency repairs.',
    );

    // 2. Query Plumbing (c2)
    final plumbingWorkers = await DI.customerRepo.getEligibleWorkers('c2');
    final electricianInPlumbing = plumbingWorkers.where((w) => w.id == electricianId || w.name == electricianName).toList();
    expect(electricianInPlumbing.isEmpty, isTrue, reason: 'Electrician must NEVER appear under Plumbing');

    // 3. Query Electrical (c1)
    final electricalWorkers = await DI.customerRepo.getEligibleWorkers('c1');
    final electricianInElectrical = electricalWorkers.where((w) => w.id == electricianId || w.name == electricianName).toList();
    expect(electricianInElectrical.isNotEmpty, isTrue, reason: 'Electrician MUST appear under Electrical');
    expect(electricianInElectrical.first.name, equals(electricianName));
    expect(electricianInElectrical.first.name, isNot(equals('Verified Union Artisan')));
    expect(electricianInElectrical.first.categoryId, equals('c1'));

    print('\n[TEST SUCCESS] Anand Joshi correctly appears in Electrical and is completely excluded from Plumbing.');
  });
}
