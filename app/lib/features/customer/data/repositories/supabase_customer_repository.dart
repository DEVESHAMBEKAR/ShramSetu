import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/i_customer_repository.dart';
import '../../../../core/services/booking_realtime_service.dart';
import '../../../../core/utils/distance_calculator.dart';
import '../../../../core/config/dependency_injection.dart';
import '../models/customer_models.dart';

class SupabaseCustomerRepository implements ICustomerRepository {
  final SupabaseClient _client;
  final BookingRealtimeService _realtimeService;

  SupabaseCustomerRepository(this._client)
      : _realtimeService = BookingRealtimeService(_client);

  @override
  Future<List<ServiceCategory>> getActiveServices() async {
    try {
      final response = await _client
          .from('services')
          .select()
          .eq('is_active', true)
          .order('name');
          
      return (response as List).map((row) => ServiceCategory(
        id: row['id'],
        name: row['name'],
        iconData: row['icon_name'] ?? row['icon_data'] ?? 'handyman',
      )).toList();
    } catch (e) {
      throw Exception('Failed to load active services: $e');
    }
  }

  @override
  Future<List<Worker>> getEligibleWorkers(String serviceId) async {
    try {
      // 1. Fetch customer coordinates for proximity calculation if authenticated
      double? customerLat;
      double? customerLng;
      final currentUserId = _client.auth.currentUser?.id;
      if (currentUserId != null) {
        try {
          final custAddr = await _client
              .from('addresses')
              .select('latitude, longitude')
              .eq('user_id', currentUserId)
              .eq('is_default', true)
              .maybeSingle();
          if (custAddr != null) {
            customerLat = (custAddr['latitude'] as num?)?.toDouble();
            customerLng = (custAddr['longitude'] as num?)?.toDouble();
          }
        } catch (_) {}
      }

      // 2. Attempt FairMatch recommendation first via FairMatchService
      try {
        final fairMatchResults = await DI.fairMatchService.getRecommendedWorkers(
          serviceId: serviceId,
          customerLat: customerLat,
          customerLng: customerLng,
        );
        if (fairMatchResults.isNotEmpty) {
          debugPrint('[CustomerRepo] Returned ${fairMatchResults.length} FairMatch ranked workers.');
          return fairMatchResults.map((r) => r.worker).toList();
        }
      } catch (e) {
        debugPrint('[CustomerRepo] FairMatch unavailable ($e), falling back to standard query.');
      }

      final response = await _client
          .from('worker_skills')
          .select('''
            worker_id,
            workers!inner (
              rating,
              review_count,
              completed_jobs,
              is_available,
              worker_status,
              experience_years,
              bio,
              location_tag,
              latitude,
              longitude,
              users!inner (
                full_name,
                avatar_url
              )
            )
          ''')
          .eq('skill_id', serviceId)
          .eq('workers.is_available', true)
          .eq('workers.worker_status', 'ACTIVE');

      final List<Worker> results = [];
      for (final row in response) {
        final wData = row['workers'];
        final uData = wData['users'];
        final workerLat = (wData['latitude'] as num?)?.toDouble();
        final workerLng = (wData['longitude'] as num?)?.toDouble();

        final calculatedDistance = HaversineDistanceUtil.calculateDistance(
          customerLat,
          customerLng,
          workerLat,
          workerLng,
        ) ?? 2.0;

        results.add(Worker(
          id: row['worker_id'],
          name: uData['full_name'] ?? 'Worker',
          categoryId: serviceId,
          rate: 350,
          rating: (wData['rating'] as num?)?.toDouble() ?? 0.0,
          reviewCount: (wData['review_count'] as num?)?.toInt() ?? 0,
          jobsCompleted: (wData['completed_jobs'] as num?)?.toInt() ?? 0,
          distanceKm: calculatedDistance,
          experience: '${wData['experience_years'] ?? 1} yrs exp',
          availability: 'Available',
          specializations: [],
          locationTag: wData['location_tag'] ?? 'Pune Area',
          imageUrl: uData['avatar_url'] ?? '',
          bio: wData['bio'],
        ));
      }

      results.sort((a, b) => b.rating.compareTo(a.rating));
      return results;
    } catch (e) {
      throw Exception('Failed to discover workers: $e');
    }
  }

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
    try {
      final customerId = _client.auth.currentUser?.id;
      if (customerId == null) throw Exception('Customer not authenticated');

      // Double-booking check
      final existing = await _client
          .from('bookings')
          .select('id')
          .eq('worker_id', workerId)
          .eq('scheduled_date', scheduledDate)
          .eq('scheduled_time', scheduledTime)
          .inFilter('status', ['pending', 'accepted', 'inProgress']);

      if (existing.isNotEmpty) {
        throw Exception('Worker is already booked for this time slot.');
      }

      // Determine default address if none provided
      String finalAddressId = addressId ?? '';
      if (finalAddressId.isEmpty) {
        final addrResponse = await _client
            .from('addresses')
            .select('id')
            .eq('user_id', customerId)
            .limit(1)
            .maybeSingle();

        if (addrResponse == null) {
          final newAddr = await _client.from('addresses').insert({
            'user_id': customerId,
            'address_line': 'Default Customer Address',
            'city': 'Pune',
            'state': 'MH',
            'postal_code': '411001',
            'is_default': true,
          }).select('id').single();
          finalAddressId = newAddr['id'];
        } else {
          finalAddressId = addrResponse['id'];
        }
      }

      // Generate a secure 4-digit escrow release OTP
      final randomOtp = (1000 + Random().nextInt(9000)).toString();

      // Compute real geographic distance if coordinates exist
      double distanceKm = 2.0;
      try {
        final addressRow = await _client
            .from('addresses')
            .select('latitude, longitude')
            .eq('id', finalAddressId)
            .maybeSingle();
        final workerRow = await _client
            .from('workers')
            .select('latitude, longitude')
            .eq('id', workerId)
            .maybeSingle();

        if (addressRow != null && workerRow != null) {
          final cLat = (addressRow['latitude'] as num?)?.toDouble();
          final cLng = (addressRow['longitude'] as num?)?.toDouble();
          final wLat = (workerRow['latitude'] as num?)?.toDouble();
          final wLng = (workerRow['longitude'] as num?)?.toDouble();
          final calc = HaversineDistanceUtil.calculateDistance(cLat, cLng, wLat, wLng);
          if (calc != null) distanceKm = calc;
        }
      } catch (_) {}

      final bookingResult = await _client.from('bookings').insert({
        'customer_id': customerId,
        'worker_id': workerId,
        'service_id': serviceId,
        'address_id': finalAddressId,
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
        'base_amount': amount,
        'labor_allowance': 35.0,
        'distance_km': distanceKm,
        'status': 'pending',
        'otp': randomOtp,
        'notes': notes ?? '',
      }).select('id').single();

      final newBookingId = bookingResult['id'] as String;

      try {
        DI.notificationRepo.sendPushNotification(
          recipientUserId: workerId,
          type: 'booking_requested',
          title: 'New Service Request',
          body: 'You have a new booking request for $scheduledDate at $scheduledTime.',
          data: {
            'bookingId': newBookingId,
            'status': 'pending',
          },
        );
      } catch (_) {}

      return newBookingId;
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCustomerBookings() async {
    final customerId = _client.auth.currentUser?.id;
    if (customerId == null) return [];
    
    try {
      final response = await _client
          .from('bookings')
          .select('''
            id,
            status,
            scheduled_date,
            scheduled_time,
            base_amount,
            labor_allowance,
            distance_km,
            otp,
            notes,
            created_at,
            services (id, name),
            workers (
              id,
              rating,
              completed_jobs,
              users (full_name, avatar_url)
            )
          ''')
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getBookingDetails(String bookingId) async {
    try {
      final response = await _client
          .from('bookings')
          .select('''
            id,
            status,
            scheduled_date,
            scheduled_time,
            base_amount,
            labor_allowance,
            distance_km,
            otp,
            notes,
            created_at,
            services (
              id,
              name,
              description,
              category
            ),
            workers (
              id,
              rating,
              completed_jobs,
              location_tag,
              experience_years,
              is_union_gold,
              is_coop_master,
              worker_status,
              users (
                full_name,
                phone,
                avatar_url
              )
            ),
            addresses (
              id,
              address_line,
              area,
              city,
              state,
              postal_code
            )
          ''')
          .eq('id', bookingId)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> cancelBooking(String bookingId, {String? reason}) async {
    try {
      final customerId = _client.auth.currentUser?.id;
      if (customerId == null) throw Exception('Customer not authenticated');

      final current = await _client
          .from('bookings')
          .select('status')
          .eq('id', bookingId)
          .eq('customer_id', customerId)
          .maybeSingle();

      if (current == null) throw Exception('Booking not found');
      final status = current['status'] as String? ?? '';
      if (status != 'pending' && status != 'accepted') {
        throw Exception('Cannot cancel booking in $status state');
      }

      await _client
          .from('bookings')
          .update({
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId)
          .eq('customer_id', customerId);

      return true;
    } catch (e) {
      throw Exception('Failed to cancel booking: $e');
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> watchCustomerBookings() {
    final customerId = _client.auth.currentUser?.id;
    if (customerId == null) {
      return Stream.value([]);
    }

    late StreamController<List<Map<String, dynamic>>> controller;
    StreamSubscription? sub;

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () async {
        // Emit initial data
        try {
          final initial = await getCustomerBookings();
          if (!controller.isClosed) controller.add(initial);
        } catch (e) {
          if (!controller.isClosed) controller.addError(e);
        }

        // Listen to realtime events
        sub = _realtimeService.streamBookingChanges(customerId: customerId).listen(
          (event) async {
            try {
              final updated = await getCustomerBookings();
              if (!controller.isClosed) controller.add(updated);
            } catch (e) {
              if (!controller.isClosed) controller.addError(e);
            }
          },
          onError: (err) {
            if (!controller.isClosed) controller.addError(err);
          },
        );
      },
      onCancel: () async {
        await sub?.cancel();
        if (!controller.isClosed) {
          await controller.close();
        }
      },
    );

    return controller.stream;
  }

  @override
  Stream<Map<String, dynamic>?> watchBookingDetails(String bookingId) {
    late StreamController<Map<String, dynamic>?> controller;
    StreamSubscription? sub;

    controller = StreamController<Map<String, dynamic>?>.broadcast(
      onListen: () async {
        // Emit initial state
        try {
          final initial = await getBookingDetails(bookingId);
          if (!controller.isClosed) controller.add(initial);
        } catch (e) {
          if (!controller.isClosed) controller.addError(e);
        }

        // Listen for targeted updates to this booking
        sub = _realtimeService.streamBookingChanges(bookingId: bookingId).listen(
          (event) async {
            try {
              final updated = await getBookingDetails(bookingId);
              if (!controller.isClosed) controller.add(updated);
            } catch (e) {
              if (!controller.isClosed) controller.addError(e);
            }
          },
          onError: (err) {
            if (!controller.isClosed) controller.addError(err);
          },
        );
      },
      onCancel: () async {
        await sub?.cancel();
        if (!controller.isClosed) {
          await controller.close();
        }
      },
    );

    return controller.stream;
  }
}
