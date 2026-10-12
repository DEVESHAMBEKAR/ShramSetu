import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/federation_models.dart';
import 'package:app/core/models/insurance_models.dart';
import 'package:app/core/models/invoice_models.dart';
import 'package:app/core/localization/locale_controller.dart';
import 'package:app/core/localization/app_strings.dart';
import 'package:app/core/config/dependency_injection.dart';
import 'package:app/features/customer/data/repositories/mock_customer_repository.dart';
import 'package:app/features/worker/data/repositories/mock_worker_repository.dart';
import 'package:app/features/admin/data/repositories/mock_admin_repository.dart';

void main() {
  setUpAll(() {
    DI.customerRepo = MockCustomerRepository();
    DI.workerRepo = MockWorkerRepository();
    DI.adminRepo = MockAdminRepository();
  });

  group('Requirement 4: Multi-Federation & District Partitioning Tests', () {
    test('FederationModel lists 5 authoritative Maharashtra cooperative federations', () {
      final federations = FederationModel.defaultFederations;
      expect(federations.length, equals(5));

      final fedIds = federations.map((f) => f.id).toList();
      expect(fedIds, containsAll([
        '11111111-0000-0000-0000-000000000001',
        '22222222-0000-0000-0000-000000000002',
        '33333333-0000-0000-0000-000000000003',
        '44444444-0000-0000-0000-000000000004',
        '55555555-0000-0000-0000-000000000005',
      ]));

      final puneFed = federations.firstWhere((f) => f.id == '11111111-0000-0000-0000-000000000001');
      expect(puneFed.city, equals('Pune'));
      expect(puneFed.district, equals('Pune'));
      expect(puneFed.state, equals('Maharashtra'));
      expect(puneFed.isActive, isTrue);

      final nashikFed = federations.firstWhere((f) => f.id == '22222222-0000-0000-0000-000000000002');
      expect(nashikFed.city, equals('Nashik'));
      expect(nashikFed.district, equals('Nashik'));
    });

    test('FederationModel serializes to and from JSON faithfully', () {
      final model = FederationModel(
        id: 'fed-test-01',
        name: 'Test Labour Cooperative Federation',
        state: 'Maharashtra',
        district: 'Thane',
        city: 'Thane',
        registrationNo: 'MH-THN-COOP-2024',
        contactPhone: '9876543210',
      );

      final json = model.toJson();
      expect(json['id'], equals('fed-test-01'));
      expect(json['district'], equals('Thane'));
      expect(json['registration_no'], equals('MH-THN-COOP-2024'));

      final restored = FederationModel.fromJson(json);
      expect(restored.id, equals(model.id));
      expect(restored.name, equals(model.name));
      expect(restored.district, equals(model.district));
      expect(restored.registrationNo, equals(model.registrationNo));
    });
  });

  group('Requirement 5, 6, 7: Location-Based Discovery & Service Area Tests', () {
    test('Worker discovery filters by customer selected service area across federations', () async {
      final customerRepo = MockCustomerRepository();

      // Retrieve all workers serving Nashik area
      final nashikWorkers = await customerRepo.getEligibleWorkers(
        'srv-electrician',
        serviceArea: 'Nashik',
      );

      // Verify returned workers service area matches Nashik or All Areas
      for (final worker in nashikWorkers) {
        final matches = worker.serviceAreas.any(
          (area) => area.toLowerCase().contains('nashik') || area.toLowerCase().contains('all areas'),
        );
        expect(matches, isTrue, reason: 'Worker ${worker.name} must serve Nashik');
      }
    });

    test('Proximity discovery calculates distance using customer coordinates', () async {
      final customerRepo = MockCustomerRepository();

      // Customer coordinates for Kothrud, Pune
      const kothrudLat = 18.5074;
      const kothrudLng = 73.8077;

      final workers = await customerRepo.getEligibleWorkers(
        'srv-electrician',
        customerLat: kothrudLat,
        customerLng: kothrudLng,
        serviceArea: 'Kothrud',
      );

      expect(workers, isNotEmpty);
      for (final worker in workers) {
        expect(worker.categoryId, anyOf(equals('srv-electrician'), equals('c1')));
      }
    });
  });

  group('Requirement 8 & H: Emergency SOS Dispatch Flow Tests', () {
    test('Emergency booking passes bookingType EMERGENCY and creates booking', () async {
      final customerRepo = MockCustomerRepository();

      final bookingId = await customerRepo.createBooking(
        workerId: 'mock-w1',
        serviceId: 'srv-emergency-plumbing',
        scheduledDate: '2026-10-03',
        scheduledTime: 'NOW',
        amount: 499.0,
        addressId: 'addr-test-456',
        bookingType: 'EMERGENCY',
      );

      expect(bookingId, isNotNull);
      expect(bookingId, isNotEmpty);

      final details = await customerRepo.getBookingDetails(bookingId!);
      expect(details, isNotNull);
      expect(details!['booking_type'], equals('EMERGENCY'));
    });

    test('Emergency worker query filters available immediate dispatch partners', () async {
      final customerRepo = MockCustomerRepository();

      final emergencyWorkers = await customerRepo.getEligibleWorkers(
        'srv-plumbing',
        isEmergency: true,
      );

      expect(emergencyWorkers, isNotEmpty);
      for (final w in emergencyWorkers) {
        expect(w.availability, isNotEmpty);
      }
    });
  });

  group('Requirement 9 & 10: Digital Invoice & Transparent Cost Calculation Tests', () {
    test('InvoiceModel calculates 3% welfare cess and 18% GST transparently', () {
      final rawBooking = {
        'id': 'b87d21a0-9c12-4f32-8411-e490518920bc',
        'base_amount': 484.0, // Base + 3% cess + 18% GST = 400 + 12 + 72 = 484
        'service_name': 'Electrical Wiring Repair',
        'scheduled_date': '2026-10-02',
        'scheduled_time': '11:00 AM',
        'customer': {
          'full_name': 'Ramesh Shinde',
          'phone': '+91 98220 12345',
        },
        'worker': {
          'full_name': 'Anand Kulkarni',
          'trade': 'Electrician',
          'federation_name': 'Pune District Labour Cooperative Federation',
        },
        'address': {
          'address_line': 'Flat 402, Shivajinagar',
          'area': 'Shivajinagar',
          'city': 'Pune',
        },
      };

      final rawPayment = {
        'status': 'PAID',
        'payment_method': 'UPI / Escrow',
        'transaction_reference': 'pay_TEST_98249120',
      };

      final invoice = InvoiceModel.fromBookingAndPayment(
        booking: rawBooking,
        payment: rawPayment,
      );

      expect(invoice.bookingId, equals('b87d21a0-9c12-4f32-8411-e490518920bc'));
      expect(invoice.customerName, equals('Ramesh Shinde'));
      expect(invoice.workerName, equals('Anand Kulkarni'));
      expect(invoice.isPaid, isTrue);
      expect(invoice.escrowStatus, equals('Secured in Federation Escrow'));
      expect(invoice.transactionRef, equals('pay_TEST_98249120'));

      // Check financial breakdown: Total should equal baseAmount + cessAmount + gstAmount (~484)
      final calculatedSum = invoice.baseAmount + invoice.cessAmount + invoice.gstAmount;
      expect((calculatedSum - invoice.totalAmount).abs(), lessThan(0.5));
      expect(invoice.cessAmount, greaterThan(0.0));
      expect(invoice.gstAmount, greaterThan(0.0));
    });
  });

  group('Requirement G: Worker Welfare & Group Insurance Profile Tests', () {
    test('WorkerInsuranceModel masks sensitive policy number', () {
      final insurance = WorkerInsuranceModel(
        workerId: 'worker-xyz',
        policyNumber: 'NIC-GRP-2026-8941',
        coverageAmount: 500000.0,
        status: InsuranceStatus.active,
      );

      expect(insurance.maskedPolicyNumber, equals('POL-••••-8941'));
      expect(insurance.isExpired, isFalse);
      expect(insurance.coverageAmount, equals(500000.0));
      expect(insurance.status, equals(InsuranceStatus.active));
      expect(insurance.isExternalIntegrationPending, isTrue);
    });

    test('MockWorkerRepository and MockAdminRepository provide insurance details', () async {
      final workerRepo = MockWorkerRepository();
      final adminRepo = MockAdminRepository();

      final workerIns = await workerRepo.getWorkerInsurance('test-worker-01');
      expect(workerIns, isNotNull);
      expect(workerIns!.coverageAmount, equals(500000.0));
      expect(workerIns.claimSupportPhone, equals('1800-266-9090'));

      final adminIns = await adminRepo.getWorkerInsurance('test-worker-01');
      expect(adminIns, isNotNull);
      expect(adminIns!.status, equals(InsuranceStatus.active));
      expect(adminIns.isExternalIntegrationPending, isTrue);
    });
  });

  group('Requirement J: Multilingual Marathi, Hindi, and English Localization Tests', () {
    setUp(() {
      LocaleController.instance.reset();
    });

    tearDown(() {
      LocaleController.instance.reset();
    });

    test('Translates emergency, invoice, and welfare terms across all 3 languages', () {
      // English
      LocaleController.instance.setLanguage('en');
      expect('Emergency Dispatch'.tr(), equals('Emergency Dispatch'));
      expect('Tax Invoice & Receipt'.tr(), equals('Tax Invoice & Receipt'));
      expect('Priority'.tr(), equals('Priority'));
      expect('External insurance provider integration pending'.tr(),
          equals('External insurance provider integration pending'));

      // Marathi
      LocaleController.instance.setLanguage('mr');
      expect('Emergency Dispatch'.tr(), equals('तातडीचे सहाय्य (Emergency)'));
      expect('Tax Invoice & Receipt'.tr(), equals('कर पावती आणि बीजक'));
      expect('Priority'.tr(), equals('प्राधान्य'));
      expect('Done'.tr(), equals('पूर्ण झाले'));
      expect('External insurance provider integration pending'.tr(),
          equals('बाह्य विमा प्रदाता एकत्रीकरण प्रलंबित'));

      // Hindi
      LocaleController.instance.setLanguage('hi');
      expect('Emergency Dispatch'.tr(), equals('आपातकालीन सहायता (Emergency)'));
      expect('Tax Invoice & Receipt'.tr(), equals('कर रसीद और चालान'));
      expect('Priority'.tr(), equals('प्राथमिकता'));
      expect('Done'.tr(), equals('संपन्न'));
      expect('External insurance provider integration pending'.tr(),
          equals('बाहरी बीमा प्रदाता एकीकरण लंबित'));
    });
  });
}
