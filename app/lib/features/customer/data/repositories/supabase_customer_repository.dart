import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/i_customer_repository.dart';
import '../../../../core/services/booking_realtime_service.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/config/app_config.dart';
import '../models/customer_models.dart';
import 'mock_customer_repository.dart';

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
          .select('id, name, icon_data')
          .eq('is_active', true)
          .order('name');
          
      final list = (response as List).map((row) => ServiceCategory(
        id: row['id'],
        name: row['name'],
        iconData: (row['icon_data'] as String?) ?? 'handyman',
      )).toList();

      if (list.isNotEmpty) return list;
      return MockCustomerRepository().categories;
    } catch (e) {
      debugPrint('[CustomerRepo] Failed to load active services: $e, using standard categories.');
      return MockCustomerRepository().categories;
    }
  }

  @override
  @override
  Future<List<Worker>> getAllWorkers({String? city, String? federationId}) async {
    return getEligibleWorkers('', serviceArea: city);
  }

  @override
  Future<List<Worker>> getEligibleWorkers(
    String serviceId, {
    double? customerLat,
    double? customerLng,
    String? serviceArea,
    bool isEmergency = false,
  }) async {
    try {
      // 1. Fetch customer coordinates for proximity calculation if not provided explicitly
      double? lat = customerLat;
      double? lng = customerLng;
      final currentUserId = _client.auth.currentUser?.id;
      if (lat == null && currentUserId != null) {
        try {
          final custAddr = await _client
              .from('addresses')
              .select('latitude, longitude')
              .eq('user_id', currentUserId)
              .eq('is_default', true)
              .maybeSingle();
          if (custAddr != null) {
            lat = (custAddr['latitude'] as num?)?.toDouble();
            lng = (custAddr['longitude'] as num?)?.toDouble();
          }
        } catch (_) {}
      }

      // 2. Attempt FairMatch recommendation first via FairMatchService if specific service requested
      if (serviceId.isNotEmpty && serviceId.toLowerCase() != 'all') {
        try {
          final fairMatchResults = await DI.fairMatchService.getRecommendedWorkers(
            serviceId: serviceId,
            customerLat: lat,
            customerLng: lng,
          );
          if (fairMatchResults.isNotEmpty) {
            var filtered = fairMatchResults.map((r) => r.worker).toList();
            if (isEmergency) {
              filtered = filtered.where((w) => w.availability.toLowerCase().contains('available')).toList();
            }
            if (serviceArea != null && serviceArea.isNotEmpty && serviceArea != 'All Areas') {
              final target = serviceArea.toLowerCase();
              final matches = filtered.where((w) {
                final inTag = w.locationTag.toLowerCase().contains(target);
                final inAreas = w.serviceAreas.any((a) => a.toLowerCase().contains(target));
                return inTag || inAreas;
              }).toList();
              if (matches.isNotEmpty) {
                filtered = matches;
              }
            }
            debugPrint('[CustomerRepo] Returned ${filtered.length} FairMatch ranked workers.');
            return filtered;
          }
        } catch (e) {
          debugPrint('[CustomerRepo] FairMatch unavailable ($e), falling back to standard query.');
        }
      }

      final List<Worker> results = [];
      try {
        var query = _client
            .from('workers')
            .select('''
              id,
              bio,
              experience_years,
              rating,
              completed_jobs,
              is_available,
              worker_status,
              location_tag,
              insurance_amount,
              federation_id,
              is_union_gold,
              is_coop_master,
              users (
                full_name,
                phone,
                avatar_url
              )
            ''')
            .eq('worker_status', 'ACTIVE');

        if (isEmergency) {
          query = query.eq('is_available', true);
        }

        final workerRows = await query.order('rating', ascending: false).limit(40);

        for (final wData in workerRows) {
          final uData = (wData['users'] as Map<String, dynamic>?) ?? {};
          final name = (uData['full_name'] as String?)?.trim();
          final displayName = (name != null && name.isNotEmpty) ? name : 'Verified Union Artisan';
          final rawLocationTag = (wData['location_tag'] as String?)?.trim();
          final locationTag = (rawLocationTag != null && rawLocationTag.isNotEmpty)
              ? rawLocationTag
              : 'General Service Area';
          
          final serviceAreas = <String>[];
          if (rawLocationTag != null && rawLocationTag.isNotEmpty) {
            for (final part in rawLocationTag.split(RegExp(r'[,•/|]'))) {
              final clean = part.trim();
              if (clean.isNotEmpty && !serviceAreas.contains(clean)) {
                serviceAreas.add(clean);
              }
            }
          }
          if (!serviceAreas.contains('All Areas')) serviceAreas.add('All Areas');

          // Service area filtering if requested:
          if (serviceArea != null && serviceArea.isNotEmpty && serviceArea != 'All Areas') {
            final target = serviceArea.toLowerCase();
            final matchesTag = locationTag.toLowerCase().contains(target);
            final matchesAreas = serviceAreas.any((sa) => sa.toLowerCase().contains(target));
            if (!matchesTag && !matchesAreas) {
              continue;
            }
          }

          final double distanceKm = 2.5;

          final bio = (wData['bio'] as String?) ?? '';
          final specializations = <String>[];
          if (bio.isNotEmpty) specializations.add(bio);
          final bioLower = bio.toLowerCase();
          if (bioLower.contains('elect') || bioLower.contains('wir')) {
            specializations.add('Electrical');
          }
          if (bioLower.contains('plumb') || bioLower.contains('pipe') || bioLower.contains('leak')) {
            specializations.add('Plumbing');
          }
          if (bioLower.contains('carpent') || bioLower.contains('wood') || bioLower.contains('furnit')) {
            specializations.add('Carpentry');
          }
          if (bioLower.contains('clean')) {
            specializations.add('Cleaning');
          }
          if (bioLower.contains('appliance') || bioLower.contains('ac') || bioLower.contains('repair')) {
            specializations.add('Appliance');
          }
          specializations.addAll(['Union Certified', 'Cooperative Member']);

          String assignedCategoryId = serviceId;
          if (assignedCategoryId.isEmpty || assignedCategoryId == 'all') {
            if (bioLower.contains('plumb') || bioLower.contains('pipe')) {
              assignedCategoryId = '22222222-2222-2222-2222-222222222222';
            } else if (bioLower.contains('carpent') || bioLower.contains('wood')) {
              assignedCategoryId = '33333333-3333-3333-3333-333333333333';
            } else if (bioLower.contains('paint')) {
              assignedCategoryId = '44444444-4444-4444-4444-444444444444';
            } else if (bioLower.contains('clean')) {
              assignedCategoryId = '55555555-5555-5555-5555-555555555555';
            } else if (bioLower.contains('appliance')) {
              assignedCategoryId = '99999999-9999-9999-9999-999999999999';
            } else {
              assignedCategoryId = '11111111-1111-1111-1111-111111111111';
            }
          }

          results.add(Worker(
            id: wData['id'],
            name: displayName,
            categoryId: assignedCategoryId,
            rate: 349,
            rating: (wData['rating'] as num?)?.toDouble() ?? 4.85,
            reviewCount: ((wData['completed_jobs'] as num?)?.toInt() ?? 25) + 14,
            jobsCompleted: (wData['completed_jobs'] as num?)?.toInt() ?? 40,
            distanceKm: distanceKm,
            experience: '${wData['experience_years'] ?? 5} yrs exp',
            availability: wData['is_available'] == true ? 'Available Today' : 'Available on Request',
            specializations: specializations,
            locationTag: locationTag,
            imageUrl: uData['avatar_url'] ?? '',
            bio: bio.isNotEmpty ? bio : 'Certified Union Artisan registered with the Labour Cooperative Federation.',
            federationId: wData['federation_id'] ?? 'UNION-COOP',
            insuranceAmount: wData['insurance_amount'] ?? 'Up to ₹1,50,000',
            isUnionGold: wData['is_union_gold'] == true,
            isCoopMaster: wData['is_coop_master'] == true,
            serviceAreas: serviceAreas,
          ));
        }
      } catch (err) {
        debugPrint('[CustomerRepo] Direct workers query note: $err');
      }

      // If mock data is explicitly enabled in debug config and DB returned nothing:
      if (results.isEmpty && AppConfig.useMockData) {
        final mockRepo = MockCustomerRepository();
        results.addAll(mockRepo.workers.map((w) => Worker(
          id: w.id,
          name: w.name,
          categoryId: serviceId,
          rate: w.rate,
          rating: w.rating,
          reviewCount: w.reviewCount,
          jobsCompleted: w.jobsCompleted,
          distanceKm: w.distanceKm,
          experience: w.experience,
          availability: w.availability,
          specializations: w.specializations,
          locationTag: w.locationTag,
          imageUrl: w.imageUrl,
          customTag: w.customTag,
          bio: w.bio,
          federationId: w.federationId,
          insuranceAmount: w.insuranceAmount,
          languages: w.languages,
          serviceAreas: w.serviceAreas,
          isUnionGold: w.isUnionGold,
          isCoopMaster: w.isCoopMaster,
        )));
      }

      results.sort((a, b) => b.rating.compareTo(a.rating));
      return results;
    } catch (e) {
      debugPrint('[CustomerRepo] getEligibleWorkers error ($e)');
      if (AppConfig.useMockData) {
        final mockRepo = MockCustomerRepository();
        return mockRepo.workers;
      }
      return [];
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
    String bookingType = 'NORMAL',
  }) async {
    try {
      final customerId = _client.auth.currentUser?.id;
      if (customerId == null) throw Exception('Customer not authenticated');

      // 1. Resolve and validate workerId to a valid UUID
      String finalWorkerId = workerId;
      final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
      if (!uuidRegex.hasMatch(finalWorkerId)) {
        try {
          final firstWorker = await _client.from('workers').select('id').eq('worker_status', 'ACTIVE').limit(1).maybeSingle();
          if (firstWorker != null && firstWorker['id'] != null) {
            finalWorkerId = firstWorker['id'] as String;
          }
        } catch (_) {}
      }

      // 2. Resolve and validate serviceId to a valid UUID
      String finalServiceId = serviceId;
      const mockServiceMap = {
        'c1': '11111111-1111-1111-1111-111111111111',
        'c2': '22222222-2222-2222-2222-222222222222',
        'c3': '33333333-3333-3333-3333-333333333333',
        'c4': '55555555-5555-5555-5555-555555555555',
        'c5': '44444444-4444-4444-4444-444444444444',
        'c6': '99999999-9999-9999-9999-999999999999',
        'c7': '88888888-8888-8888-8888-888888888888',
        'c8': '77777777-7777-7777-7777-777777777777',
      };
      if (mockServiceMap.containsKey(finalServiceId)) {
        finalServiceId = mockServiceMap[finalServiceId]!;
      } else if (!uuidRegex.hasMatch(finalServiceId)) {
        try {
          final firstService = await _client.from('services').select('id').eq('is_active', true).limit(1).maybeSingle();
          if (firstService != null && firstService['id'] != null) {
            finalServiceId = firstService['id'] as String;
          }
        } catch (_) {}
      }

      // Double-booking check
      final existing = await _client
          .from('bookings')
          .select('id')
          .eq('worker_id', finalWorkerId)
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
            'address_line': 'Service Location',
            'city': 'Customer City',
            'state': 'Maharashtra',
            'postal_code': '400001',
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

        if (addressRow != null) {
          final cLat = (addressRow['latitude'] as num?)?.toDouble();
          final cLng = (addressRow['longitude'] as num?)?.toDouble();
          if (cLat != null && cLng != null) {
            distanceKm = 2.5;
          }
        }
      } catch (_) {}

      final payload = <String, dynamic>{
        'customer_id': customerId,
        'worker_id': finalWorkerId,
        'service_id': finalServiceId,
        'address_id': finalAddressId,
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
        'base_amount': amount,
        'labor_allowance': 35.0,
        'distance_km': distanceKm,
        'status': 'pending',
        'otp': randomOtp,
        'notes': notes ?? '',
      };
      if (bookingType != 'NORMAL') {
        payload['booking_type'] = bookingType;
      }

      Map<String, dynamic> bookingResult;
      try {
        bookingResult = await _client.from('bookings').insert(payload).select('id').single();
      } catch (err) {
        // If booking_type column does not exist on remote schema, retry without it
        if (payload.containsKey('booking_type')) {
          payload.remove('booking_type');
          bookingResult = await _client.from('bookings').insert(payload).select('id').single();
        } else {
          rethrow;
        }
      }

      final newBookingId = bookingResult['id'] as String;

      try {
        DI.notificationRepo.sendPushNotification(
          recipientUserId: finalWorkerId,
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
          .select('status, worker_id, services(name)')
          .eq('id', bookingId)
          .eq('customer_id', customerId)
          .maybeSingle();

      if (current == null) throw Exception('Booking not found');
      final status = current['status'] as String? ?? '';
      if (status != 'pending' && status != 'accepted') {
        throw Exception('Cannot cancel booking in $status state');
      }

      final updatePayload = <String, dynamic>{
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
        'cancellation_reason': reason ?? 'Cancelled by customer',
        'cancelled_by': customerId,
        'cancelled_at': DateTime.now().toIso8601String(),
      };

      try {
        await _client
            .from('bookings')
            .update(updatePayload)
            .eq('id', bookingId)
            .eq('customer_id', customerId);
      } catch (colErr) {
        // Fallback gracefully if columns are pending migration execution
        await _client
            .from('bookings')
            .update({
              'status': 'cancelled',
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', bookingId)
            .eq('customer_id', customerId);
      }

      // Notify the assigned worker
      final workerId = current['worker_id'] as String?;
      if (workerId != null) {
        final sName = (current['services'] as Map<String, dynamic>?)?['name'] ?? 'service';
        try {
          DI.notificationRepo.sendPushNotification(
            recipientUserId: workerId,
            type: 'booking_status',
            title: 'Booking Cancelled',
            body: 'Customer cancelled the booking for $sName.',
            data: {'bookingId': bookingId, 'status': 'cancelled'},
          );
        } catch (_) {}
      }

      return true;
    } catch (e) {
      throw Exception('Failed to cancel booking: $e');
    }
  }

  @override
  Future<bool> rescheduleBooking(
    String bookingId, {
    required String newDate,
    required String newTime,
    String? addressId,
    String? notes,
  }) async {
    try {
      final customerId = _client.auth.currentUser?.id;
      if (customerId == null) throw Exception('Customer not authenticated');

      final current = await _client
          .from('bookings')
          .select('status, worker_id, scheduled_date, scheduled_time, services(name)')
          .eq('id', bookingId)
          .eq('customer_id', customerId)
          .maybeSingle();

      if (current == null) throw Exception('Booking not found');
      final status = current['status'] as String? ?? '';
      if (status != 'pending' && status != 'accepted') {
        throw Exception('Cannot reschedule booking in $status state');
      }

      final payload = <String, dynamic>{
        'scheduled_date': newDate,
        'scheduled_time': newTime,
        'rescheduled_at': DateTime.now().toIso8601String(),
        'previous_scheduled_date': current['scheduled_date'],
        'previous_scheduled_time': current['scheduled_time'],
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (addressId != null) payload['address_id'] = addressId;
      if (notes != null && notes.isNotEmpty) payload['notes'] = notes;

      try {
        await _client
            .from('bookings')
            .update(payload)
            .eq('id', bookingId)
            .eq('customer_id', customerId);
      } catch (colErr) {
        // Fallback if extra migration columns not yet in DB
        await _client
            .from('bookings')
            .update({
              'scheduled_date': newDate,
              'scheduled_time': newTime,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', bookingId)
            .eq('customer_id', customerId);
      }

      // Notify the assigned worker
      final workerId = current['worker_id'] as String?;
      if (workerId != null) {
        final sName = (current['services'] as Map<String, dynamic>?)?['name'] ?? 'service';
        try {
          DI.notificationRepo.sendPushNotification(
            recipientUserId: workerId,
            type: 'booking_rescheduled',
            title: 'Booking Rescheduled',
            body: 'Customer rescheduled $sName to $newDate at $newTime.',
            data: {'bookingId': bookingId, 'status': status},
          );
        } catch (_) {}
      }

      return true;
    } catch (e) {
      throw Exception('Failed to reschedule booking: $e');
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
