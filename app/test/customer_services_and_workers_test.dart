import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';

void main() {
  setUp(() {
    DI.setup();
  });

  test('Verify Customer Repo returns active services and workers', () async {
    final services = await DI.customerRepo.getActiveServices();
    print('\n[TEST] Active Services Count: ${services.length}');
    for (final s in services) {
      print('Service: id=${s.id}, name=${s.name}, icon=${s.iconData}');
    }
    expect(services.isNotEmpty, isTrue);

    final plumbingWorkers = await DI.customerRepo.getEligibleWorkers('c2');
    print('\n[TEST] Plumbing Workers Count: ${plumbingWorkers.length}');
    for (final w in plumbingWorkers) {
      print('Worker: name=${w.name}, cat=${w.categoryId}, rating=${w.rating}, loc=${w.locationTag}, areas=${w.serviceAreas}');
    }
    expect(plumbingWorkers.isNotEmpty, isTrue);

    final allWorkers = await DI.customerRepo.getAllWorkers();
    print('\n[TEST] All Workers Count: ${allWorkers.length}');
    expect(allWorkers.isNotEmpty, isTrue);
  });
}
