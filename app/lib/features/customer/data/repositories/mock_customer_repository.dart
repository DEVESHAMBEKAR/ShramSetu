import 'dart:async';
import '../../../../core/repositories/i_customer_repository.dart';
import '../../../../core/config/dependency_injection.dart';
import '../models/customer_models.dart';

class MockCustomerRepository implements ICustomerRepository {
  final List<ServiceCategory> categories = const [
    ServiceCategory(id: 'c1', name: 'Electrical', iconData: 'power'),
    ServiceCategory(id: 'c2', name: 'Plumbing', iconData: 'plumbing'),
    ServiceCategory(id: 'c3', name: 'Carpentry', iconData: 'carpenter'),
    ServiceCategory(id: 'c4', name: 'Cleaning', iconData: 'cleaning_services'),
    ServiceCategory(id: 'c5', name: 'Painting', iconData: 'format_paint'),
    ServiceCategory(id: 'c6', name: 'Appliance', iconData: 'home_repair_service'),
    ServiceCategory(id: 'c7', name: 'Gardening', iconData: 'yard'),
    ServiceCategory(id: 'c8', name: 'Driver', iconData: 'directions_car'),
  ];

  final List<Worker> workers = const [
    Worker(
      id: 'w1',
      name: 'Rahul Patil',
      categoryId: 'c2',
      rate: 399,
      rating: 4.8,
      reviewCount: 126,
      jobsCompleted: 184,
      distanceKm: 1.4,
      experience: '6 yrs exp',
      availability: 'Available Today, 10:30 AM',
      specializations: ['Leak Detection', 'Bath Fittings', 'Water Heater Installation'],
      locationTag: 'Sector 4, Kothrud',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCFWmnrpgJ4kd56nQH1OgpgB-Go8-4UJrte6eOqT6EXAvAeIC-ldV519i-40O0beZWiHN1I8tEP73Fgfr5k494CA9lm4PpYPy4-GUwbsZBPVsdV5iUEJG5mTHa9vUJlAyqPgr8sNunCXE3JpT34qQKh5p-pL5Rc7v98w1BlDg8ls00g9yw6owMLyeUPWbh9_dF_WmJtMZKum-FX-vv0YUZdr5X6RhdMkEICHMX_9eibi7oiEEgKDe9hJw',
      customTag: 'Excellent Match',
      bio: 'Certified plumber registered with Pune District Cooperative Labour Federation. Specializes in leak detection, bathroom fittings, solar water connections, and emergency repairs with own calibrated toolset.',
      federationId: 'PUN-PLM-2018-88',
      insuranceAmount: 'Up to ₹1,50,000',
      languages: ['मराठी (Native)', 'हिंदी', 'English'],
      serviceAreas: ['Kothrud', 'Bavdhan', 'Erandwane', 'Deccan', 'Karve Nagar'],
    ),
    Worker(
      id: 'w2',
      name: 'Santosh Shinde',
      categoryId: 'c2',
      rate: 349,
      rating: 4.7,
      reviewCount: 98,
      jobsCompleted: 142,
      distanceKm: 2.8,
      experience: '8 Yrs Experience',
      availability: 'Available Today, 1:00 PM',
      specializations: ['Drainage Unclogging', 'Heavy Pipe Fitting', 'Pressure Pumps'],
      locationTag: 'Bavdhan',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuAeeQvIUJTbnmWT1V9-X26KV_76HC4s7D3pGhOhAunSbsOlMlFVuMA1P7rT_n30VgpTihgoD3hPbVaOJVnzhZUOaxxROST4fZe5loh6d4vdEFJPcJxfDb7ST1ftNNlfOscwrOOf0syt0wZk8R8gRCkVV6-YCQUIFPR8py_b19g3Bt-EnYB6LvS2gBlF33pgR1HANwv-3-h48leAjyKa3XJeQnNdADYBRoCo8oCNSe3mNKjxns8qMhYlsA',
      isUnionGold: true,
    ),
    Worker(
      id: 'w3',
      name: 'Vikas Kulkarni',
      categoryId: 'c2',
      rate: 450,
      rating: 4.9,
      reviewCount: 310,
      jobsCompleted: 420,
      distanceKm: 3.5,
      experience: '14+ Yrs Trade Vet',
      availability: 'Available Tomorrow (Slot 1)',
      specializations: ['Commercial & Home Plumbing', 'Central Pipeline Overhaul'],
      locationTag: 'Shivaji Nagar',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCWIMvt4QiD8491szpNAgz6qtoF2oak9J_J5d572etL-J9njPqjWpNArufe8bqQKqjK0xEIUdWOMGFNyZqVx_x_pvMU-q7JpNTc-C5onCUYLkKusQO6MNINZYj_uDU-b11f1dzlB8Ja-vPD43OQdmslX0KR1K2zvWDo5_Vh0WxKjg_2he9hW-a43Dz0Hmj_nfAcyF11QkySe8GyB5BdE-Kkh2GrSYhEhqSxbfug8X2qUpNPB4si2C4_OQ',
      isCoopMaster: true,
    ),
    Worker(
      id: 'w4',
      name: 'Suresh Gaikwad',
      categoryId: 'c1',
      rate: 299,
      rating: 4.9,
      reviewCount: 214,
      jobsCompleted: 350,
      distanceKm: 2.1,
      experience: '9 yrs exp',
      availability: 'Available Today, 4:00 PM',
      specializations: ['Master Electrician', 'Wiring & Inverter'],
      locationTag: 'Kothrud',
      imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuDatl6mPyPeQtKgZwVVuZ8tx23q-vk1HnmX4GVP5kkw-VNTKxyzxPZb3ZLolPVk73CLbYp7zw2wHWyNliJu3z_osZRvf9hdRf3W7WYL2zn2jT0ZaTQ1k1yZfHV7eiEwlYgvwrP7K-q-q4khoqvAN4nCoGrPkX7lsLSlUv2b4W75936udvEFPFC0sxVBlNJIhRIPy7SMPR1zFyiMtONkWE_mTf1mtRZpZHpHH9doNHyzW41GswZZBNzzgw',
    ),
  ];

  @override
  Future<List<ServiceCategory>> getActiveServices() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return categories;
  }

  @override
  Future<List<Worker>> getEligibleWorkers(String serviceId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    try {
      final recommended = await DI.fairMatchService.getRecommendedWorkers(serviceId: serviceId);
      if (recommended.isNotEmpty) {
        return recommended.map((r) => r.worker).toList();
      }
    } catch (_) {
      // Fallback to standard mock filtering
    }
    return workers.where((w) => w.categoryId == serviceId).toList();
  }

  final List<Map<String, dynamic>> _mockBookings = [];

  @override
  Future<String?> createBooking({
    required String workerId,
    required String serviceId,
    required String scheduledDate,
    required String scheduledTime,
    required double amount,
    String? addressId,
    String? notes,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    final newId = 'bk_${DateTime.now().millisecondsSinceEpoch}';
    final worker = workers.firstWhere((w) => w.id == workerId, orElse: () => workers.first);
    final category = categories.firstWhere((c) => c.id == serviceId, orElse: () => categories.first);
    
    _mockBookings.add({
      'id': newId,
      'worker_id': workerId,
      'service_id': serviceId,
      'scheduled_date': scheduledDate,
      'scheduled_time': scheduledTime,
      'base_amount': amount,
      'labor_allowance': 35.0,
      'distance_km': 2.1,
      'status': 'onTheWay',
      'otp': '8492',
      'notes': notes ?? '',
      'services': {
        'id': category.id,
        'name': category.name,
        'description': 'Certified repair & maintenance',
        'category': 'Home Maintenance',
      },
      'workers': {
        'id': worker.id,
        'rating': worker.rating,
        'completed_jobs': worker.jobsCompleted,
        'location_tag': worker.locationTag,
        'experience_years': 6,
        'is_union_gold': true,
        'is_coop_master': true,
        'worker_status': 'ACTIVE',
        'users': {
          'full_name': worker.name,
          'phone': '+91 98000 12345',
          'avatar_url': worker.imageUrl,
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

    try {
      DI.notificationRepo.sendPushNotification(
        recipientUserId: workerId,
        type: 'booking_requested',
        title: 'New Service Request',
        body: 'You have a new booking request for $scheduledDate at $scheduledTime.',
        data: {
          'bookingId': newId,
          'status': 'pending',
        },
      );
    } catch (_) {}

    return newId;
  }

  @override
  Future<List<Map<String, dynamic>>> getCustomerBookings() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockBookings;
  }

  @override
  Future<Map<String, dynamic>?> getBookingDetails(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final match = _mockBookings.firstWhere(
      (b) => b['id'] == bookingId,
      orElse: () => {
        'id': bookingId,
        'status': 'onTheWay',
        'scheduled_date': '2023-11-01',
        'scheduled_time': '10:00 AM',
        'base_amount': 450.0,
        'labor_allowance': 35.0,
        'distance_km': 1.4,
        'otp': '8492',
        'notes': 'Tap leakage repair',
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
            'avatar_url': 'https://lh3.googleusercontent.com/aida-public/AB6AXuBoMxnCFfaYXOUtlUT20_jp0CHCFg18ufEeB4bGvIdK_GitTGcTnzkRBOH2rT5-6fZfjT-IVxktNJaZ7SNG5JB2fLTNVxA-6qRHx_RlDkifuF1zucZcUquYhQjxOEAqYklJxBLF59UnSnwAgPwMTI_H8lT1sYxAdbE_e_Qg4T8H8HSDCG2mC4lh-Jv6NnxGFmT4o6W6DKmI8FLuEa7EzRMLJkm9MYvEQ8uxJR5aW5YQM45FuQUgrqRALQ',
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
      },
    );
    return match;
  }

  @override
  Future<bool> cancelBooking(String bookingId, {String? reason}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _mockBookings.indexWhere((b) => b['id'] == bookingId);
    if (index != -1) {
      _mockBookings[index]['status'] = 'cancelled';
    }
    return true;
  }

  @override
  Stream<List<Map<String, dynamic>>> watchCustomerBookings() {
    return Stream.value(List<Map<String, dynamic>>.from(_mockBookings));
  }

  @override
  Stream<Map<String, dynamic>?> watchBookingDetails(String bookingId) {
    return Stream.fromFuture(getBookingDetails(bookingId));
  }
}
