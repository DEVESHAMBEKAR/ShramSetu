import 'dart:async';
import '../../features/worker/data/models/worker_models.dart';
import '../config/dependency_injection.dart';
import '../config/app_config.dart';

/// Single source of truth for mock & demo booking state across Customer, Worker, and Admin.
/// Uses a broadcast stream to synchronize state changes across roles in real-time.
class SharedBookingStore {
  static final SharedBookingStore instance = SharedBookingStore._internal();

  factory SharedBookingStore() => instance;

  SharedBookingStore._internal() {
    _initDefaultBookings();
  }

  final List<Map<String, dynamic>> _bookings = [];
  final StreamController<void> _changeController = StreamController<void>.broadcast();

  Stream<void> get onChange => _changeController.stream;

  void _initDefaultBookings() {
    _bookings.clear();
    // Only pre-seed demo bookings in mock or unit-test mode where Supabase is absent.
    // Live mode strictly reflects database records without ghost dummy bookings.
    if (!AppConfig.isSupabaseInitialized || AppConfig.useMockData) {
      _seedDemoBookings();
    }
  }

  void _seedDemoBookings() {
    _bookings.add({
      'id': 'j1',
      'worker_id': 'w1',
      'customer_id': 'mock-customer-1',
      'customer_name': 'Ananya Sharma',
      'customer_phone': '+91 91234 56789',
      'customer_location': 'Flat 402, Sai Shraddha Apts, Paud Road, Kothrud',
      'service_id': 'c2',
      'service_name': 'Plumbing Inspection & Tap Repair',
      'scheduled_date': 'Today',
      'scheduled_time': '11:00 AM',
      'base_amount': 399.0,
      'labor_allowance': 86.0,
      'distance_km': 1.8,
      'status': BookingStatus.onTheWay.toDbString(),
      'otp': '8492',
      'payment_method': 'RAZORPAY',
      'notes': 'Kitchen sink faucet leaking steadily.',
      'created_at': 'Just now',
      'services': {
        'id': 'c2',
        'name': 'Plumbing Inspection & Tap Repair',
        'description': 'Includes standard gasket replacement + pressure test',
        'category': 'Plumbing',
      },
      'workers': {
        'id': 'w1',
        'rating': 4.8,
        'completed_jobs': 184,
        'location_tag': 'Sector 4, Kothrud',
        'experience_years': 6,
        'is_union_gold': true,
        'is_coop_master': true,
        'worker_status': 'ACTIVE',
        'users': {
          'full_name': 'Rahul Patil',
          'phone': '+91 98765 43210',
          'avatar_url': 'https://lh3.googleusercontent.com/aida-public/AB6AXuCFWmnrpgJ4kd56nQH1OgpgB-Go8-4UJrte6eOqT6EXAvAeIC-ldV519i-40O0beZWiHN1I8tEP73Fgfr5k494CA9lm4PpYPy4-GUwbsZBPVsdV5iUEJG5mTHa9vUJlAyqPgr8sNunCXE3JpT34qQKh5p-pL5Rc7v98w1BlDg8ls00g9yw6owMLyeUPWbh9_dF_WmJtMZKum-FX-vv0YUZdr5X6RhdMkEICHMX_9eibi7oiEEgKDe9hJw',
        }
      },
      'addresses': {
        'id': 'mock_addr_1',
        'address_line': 'Flat 402, Sai Shraddha Apts, Paud Road',
        'area': 'Kothrud',
        'city': 'Pune',
        'state': 'Maharashtra',
        'postal_code': '411038',
      }
    });
  }

  // ─────────────────────── Customer Methods ───────────────────────

  Future<String> createBooking({
    required String workerId,
    required String serviceId,
    required String serviceName,
    required String workerName,
    required String scheduledDate,
    required String scheduledTime,
    required double amount,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerLocation,
    String? addressId,
    String? notes,
    String bookingType = 'NORMAL',
    String paymentMethod = 'RAZORPAY',
  }) async {
    final newId = 'bk_${DateTime.now().millisecondsSinceEpoch}';
    final effectiveCustomerId = customerId ?? 'mock-customer-1';
    final effectiveCustomerName = (customerName != null && customerName.isNotEmpty) ? customerName : 'Priya Sharma';

    final bookingMap = <String, dynamic>{
      'id': newId,
      'worker_id': workerId,
      'worker_name': workerName,
      'customer_id': effectiveCustomerId,
      'customer_name': effectiveCustomerName,
      'customer_phone': customerPhone ?? '+91 98765 43210',
      'customer_location': customerLocation ?? '45 Deccan Gymkhana Road, Pune',
      'service_id': serviceId,
      'service_name': serviceName,
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'base_amount': amount,
      'booking_type': bookingType,
      'payment_method': paymentMethod,
      'labor_allowance': 50.0,
      'distance_km': 1.4,
      'status': BookingStatus.onTheWay.toDbString(),
      'otp': '8492',
      'notes': notes ?? '',
      'created_at': 'Just now',
      'services': {
        'id': serviceId,
        'name': serviceName,
        'description': 'Certified repair & maintenance',
        'category': 'Home Maintenance',
      },
      'workers': {
        'id': workerId,
        'rating': 4.8,
        'completed_jobs': 126,
        'location_tag': 'Kothrud, Pune',
        'experience_years': 6,
        'is_union_gold': true,
        'is_coop_master': true,
        'worker_status': 'ACTIVE',
        'users': {
          'full_name': workerName,
          'phone': '+91 98000 12345',
          'avatar_url': null,
        }
      },
      'addresses': {
        'id': addressId ?? 'addr_${DateTime.now().millisecondsSinceEpoch}',
        'address_line': customerLocation ?? '45 Deccan Gymkhana Road',
        'area': 'Deccan',
        'city': 'Pune',
        'state': 'Maharashtra',
        'postal_code': '411004',
      }
    };

    _bookings.insert(0, bookingMap);
    _changeController.add(null);

    // Notify Worker
    try {
      DI.notificationRepo.sendPushNotification(
        recipientUserId: workerId,
        type: 'booking_requested',
        title: 'New Service Request',
        body: 'You have a new booking request for $scheduledDate at $scheduledTime.',
        data: {'bookingId': newId, 'status': 'pending'},
      );
    } catch (_) {}

    return newId;
  }

  List<Map<String, dynamic>> getCustomerBookings({String? customerId}) {
    return List<Map<String, dynamic>>.from(_bookings);
  }

  Stream<List<Map<String, dynamic>>> watchCustomerBookings({String? customerId}) async* {
    yield getCustomerBookings(customerId: customerId);
    yield* _changeController.stream.map((_) => getCustomerBookings(customerId: customerId));
  }

  Map<String, dynamic>? getBookingDetails(String bookingId) {
    final index = _bookings.indexWhere((b) => b['id'] == bookingId);
    if (index != -1) return Map<String, dynamic>.from(_bookings[index]);
    return {
      'id': bookingId,
      'status': 'onTheWay',
      'scheduled_date': '2023-11-01',
      'scheduled_time': '10:00 AM',
      'base_amount': 450.0,
      'labor_allowance': 35.0,
      'distance_km': 1.4,
      'otp': '8492',
      'notes': 'Tap leakage repair',
      'customer_id': 'mock-customer-1',
      'services': {
        'id': 'c1',
        'name': 'Plumbing Inspection & Tap Leakage Repair',
        'description': 'Includes standard gasket replacement + pressure test',
        'category': 'Plumbing',
      },
      'workers': {
        'id': 'w1',
        'rating': 4.8,
        'completed_jobs': 342,
        'location_tag': 'Kothrud Stand',
        'experience_years': 8,
        'is_union_gold': true,
        'is_coop_master': true,
        'worker_status': 'ACTIVE',
        'users': {
          'full_name': 'Rahul Patil',
          'phone': '+91 98000 12345',
          'avatar_url': null,
        }
      },
      'addresses': {
        'id': 'addr_1',
        'address_line': 'Flat 402, Sai Shraddha Apts, Paud Road',
        'area': 'Kothrud',
        'city': 'Pune',
        'state': 'Maharashtra',
        'postal_code': '411038',
      }
    };
  }

  Stream<Map<String, dynamic>?> watchBookingDetails(String bookingId) async* {
    yield getBookingDetails(bookingId);
    yield* _changeController.stream.map((_) => getBookingDetails(bookingId));
  }

  Future<bool> cancelBooking(String bookingId, {String? reason}) async {
    final index = _bookings.indexWhere((b) => b['id'] == bookingId);
    if (index != -1) {
      _bookings[index]['status'] = BookingStatus.cancelled.toDbString();
      _bookings[index]['cancellation_reason'] = reason ?? 'Cancelled by user';
      _bookings[index]['cancelled_by'] = 'CUSTOMER';
      _bookings[index]['cancelled_at'] = DateTime.now().toIso8601String();
      _changeController.add(null);

      // Notify Worker
      final workerId = _bookings[index]['worker_id'] as String?;
      if (workerId != null) {
        try {
          DI.notificationRepo.sendPushNotification(
            recipientUserId: workerId,
            type: 'booking_status',
            title: 'Booking Cancelled',
            body: 'Customer cancelled the booking: ${reason ?? "No reason specified"}',
            data: {'bookingId': bookingId, 'status': 'cancelled'},
          );
        } catch (_) {}
      }
    }
    return true;
  }

  Future<bool> rescheduleBooking(
    String bookingId, {
    required String newDate,
    required String newTime,
    String? addressId,
    String? notes,
  }) async {
    final index = _bookings.indexWhere((b) => b['id'] == bookingId);
    if (index != -1) {
      _bookings[index]['previous_scheduled_date'] = _bookings[index]['scheduled_date'];
      _bookings[index]['previous_scheduled_time'] = _bookings[index]['scheduled_time'];
      _bookings[index]['scheduled_date'] = newDate;
      _bookings[index]['scheduled_time'] = newTime;
      _bookings[index]['rescheduled_at'] = DateTime.now().toIso8601String();
      if (notes != null && notes.isNotEmpty) {
        _bookings[index]['notes'] = notes;
      }
      _changeController.add(null);

      // Notify Worker
      final workerId = _bookings[index]['worker_id'] as String?;
      if (workerId != null) {
        try {
          DI.notificationRepo.sendPushNotification(
            recipientUserId: workerId,
            type: 'booking_rescheduled',
            title: 'Booking Rescheduled',
            body: 'Customer has rescheduled booking to $newDate at $newTime.',
            data: {'bookingId': bookingId, 'status': _bookings[index]['status']},
          );
        } catch (_) {}
      }
      return true;
    }
    return false;
  }

  // ─────────────────────── Worker Methods ───────────────────────

  List<JobRequest> getWorkerBookings({String? workerId}) {
    return _bookings.map((b) {
      final status = BookingStatus.fromDbString(b['status'] as String?);
      final base = (b['base_amount'] as num?)?.toDouble() ?? 399.0;
      final allowance = (b['labor_allowance'] as num?)?.toDouble() ?? 50.0;
      final dist = b['distance_km'] != null ? '${b['distance_km']} km' : '1.8 km';

      return JobRequest(
        id: b['id'] as String,
        customerId: b['customer_id'] as String? ?? 'mock-customer-1',
        customerName: b['customer_name'] as String? ?? 'Customer',
        customerLocation: b['customer_location'] as String? ?? 'Pune',
        customerPhone: b['customer_phone'] as String? ?? '+91 98000 00000',
        serviceName: b['service_name'] as String? ?? 'Service',
        date: b['scheduled_date'] as String? ?? 'Today',
        time: b['scheduled_time'] as String? ?? '10:00 AM',
        baseAmount: base,
        laborAllowance: allowance,
        status: status,
        distanceKm: dist,
        createdAt: b['created_at'] as String? ?? 'Recently',
        workerId: b['worker_id'] as String?,
        workerName: b['worker_name'] as String?,
        federationRefId: b['federation_ref_id'] as String?,
        federationName: b['federation_name'] as String?,
        paymentMethod: b['payment_method'] as String? ?? 'RAZORPAY',
        otp: b['otp'] as String? ?? '8492',
      );
    }).toList();
  }

  Stream<List<JobRequest>> watchWorkerBookings({String? workerId}) async* {
    yield getWorkerBookings(workerId: workerId);
    yield* _changeController.stream.map((_) => getWorkerBookings(workerId: workerId));
  }

  void addExternalBooking(Map<String, dynamic> booking) {
    final id = booking['id']?.toString();
    if (id == null) return;
    final index = _bookings.indexWhere((b) => b['id'] == id);
    if (index != -1) {
      _bookings[index].addAll(booking);
    } else {
      _bookings.insert(0, Map<String, dynamic>.from(booking));
    }
    _changeController.add(null);
  }

  Future<bool> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    final index = _bookings.indexWhere((b) => b['id'] == bookingId);
    if (index != -1) {
      _bookings[index]['status'] = newStatus.toDbString();
    } else {
      _bookings.add({
        'id': bookingId,
        'status': newStatus.toDbString(),
        'customer_id': 'mock-customer-1',
      });
    }

    if (newStatus == BookingStatus.completed) {
      try {
        await DI.paymentRepo.releaseEscrow(bookingId);
      } catch (_) {}
    }

    _changeController.add(null);

    // Send push notification to customer
    final targetIndex = index != -1 ? index : (_bookings.length - 1);
    final customerId = _bookings[targetIndex]['customer_id'] as String?;
    if (customerId != null) {
      try {
        DI.notificationRepo.sendPushNotification(
          recipientUserId: customerId,
          type: 'booking_status',
          title: 'Booking Status: ${newStatus.label}',
          body: 'Your artisan is now ${newStatus.label.toLowerCase()}.',
          data: {'bookingId': bookingId, 'status': newStatus.toDbString()},
        );
      } catch (_) {}
    }

    return true;
  }

  Future<bool> updateBookingDetails(
    String bookingId, {
    BookingStatus? status,
    String? scheduledDate,
    String? scheduledTime,
    String? notes,
  }) async {
    final index = _bookings.indexWhere((b) => b['id'] == bookingId);
    if (index != -1) {
      if (status != null) _bookings[index]['status'] = status.toDbString();
      if (scheduledDate != null) _bookings[index]['scheduled_date'] = scheduledDate;
      if (scheduledTime != null) _bookings[index]['scheduled_time'] = scheduledTime;
      if (notes != null) _bookings[index]['notes'] = notes;
      _changeController.add(null);
      return true;
    }
    return false;
  }

  Future<bool> updatePaymentMethod(String bookingId, String paymentMethod) async {
    final index = _bookings.indexWhere((b) => b['id'] == bookingId);
    if (index != -1) {
      _bookings[index]['payment_method'] = paymentMethod;
      _changeController.add(null);
      return true;
    }
    return false;
  }

  Map<String, dynamic>? getBookingById(String bookingId) {
    final index = _bookings.indexWhere((b) => b['id'] == bookingId);
    if (index != -1) return Map<String, dynamic>.from(_bookings[index]);
    return null;
  }


  // ─────────────────────── Admin Methods ───────────────────────

  List<JobRequest> getAllBookings() => getWorkerBookings();

  Stream<List<JobRequest>> watchAllBookings() => watchWorkerBookings();

  void resetDemoData() {
    _bookings.clear();
    _seedDemoBookings();
    _changeController.add(null);
  }
}
