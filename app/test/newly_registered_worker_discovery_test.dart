import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/config/dependency_injection.dart';

void main() {
  setUp(() {
    DI.setup();
  });

  test('Dynamically registered worker appears in Customer Discovery and is online', () async {
    const testWorkerId = 'worker_test_9876543210';
    const testWorkerName = 'Vikram Shinde';

    // 1. Worker registers
    await DI.workerRepo.registerWorker(
      workerId: testWorkerId,
      fullName: testWorkerName,
      phone: '9876543210',
      skill: 'Plumbing',
      experienceYears: 7,
      serviceLocation: 'Kothrud, Pune',
      trade: 'Plumber',
    );

    // 2. Worker goes online
    await DI.workerRepo.updateWorkerAvailability(testWorkerId, true);

    // 3. Customer queries plumbing workers in "All Areas"
    final plumbingWorkers = await DI.customerRepo.getEligibleWorkers('c2');
    final found = plumbingWorkers.where((w) => w.name == testWorkerName || w.id == testWorkerId).toList();
    print('\n[TEST] Found newly registered worker in Plumbing Discovery: ${found.length}');
    expect(found.isNotEmpty, isTrue);
    expect(found.first.availability, equals('Available Today'));
    expect(found.first.serviceAreas.contains('All Areas'), isTrue);

    // 4. Customer queries with specific ward
    final wardWorkers = await DI.customerRepo.getEligibleWorkers('c2', serviceArea: 'Kothrud');
    final foundInWard = wardWorkers.where((w) => w.name == testWorkerName).toList();
    expect(foundInWard.isNotEmpty, isTrue);
    print('[TEST] Found newly registered worker in Kothrud ward: ${foundInWard.first.name}');
  });
}
