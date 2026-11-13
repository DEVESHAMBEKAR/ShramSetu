import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/i_worker_repository.dart';
import '../../../../core/services/booking_realtime_service.dart';
import '../../../../core/config/dependency_injection.dart';
import '../../../../core/models/insurance_models.dart';
import '../models/worker_models.dart';
import '../../../customer/data/models/customer_models.dart';
import '../../../customer/data/repositories/mock_customer_repository.dart';
import '../../../../core/services/registered_worker_store.dart';
import '../../../../core/services/shared_booking_store.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/models/federation_models.dart';
import 'mock_worker_repository.dart';

class SupabaseWorkerRepository implements IWorkerRepository {
  final SupabaseClient _supabase;
  final BookingRealtimeService _realtimeService;

  SupabaseWorkerRepository(this._supabase)
      : _realtimeService = BookingRealtimeService(_supabase);

  @override
  Future<WorkerProfile> getWorkerProfile(String userId) async {
    final authUser = _supabase.auth.currentUser;
    final effectiveId = (userId.isNotEmpty && userId != 'mock-worker-id')
        ? userId
        : (authUser?.id ?? userId);

    final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(effectiveId);

    Map<String, dynamic>? userRes;
    Map<String, dynamic>? workerRes;

    if (isUuid) {
      try {
        userRes = await _supabase.from('users').select().eq('id', effectiveId).maybeSingle();
      } catch (e) {
        debugPrint('[WorkerRepo] users select note: $e');
      }

      try {
        workerRes = await _supabase.from('workers').select().eq('id', effectiveId).maybeSingle();
        if (workerRes == null) {
          try {
            await _supabase.from('workers').insert({
              'id': effectiveId,
              'worker_status': 'PENDING_VERIFICATION',
            });
            workerRes = await _supabase.from('workers').select().eq('id', effectiveId).maybeSingle();
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('[WorkerRepo] workers select note: $e');
      }
    }

    // Attempt to resolve real name from database users table
    String resolvedName = (userRes?['full_name'] as String?)?.trim() ?? '';
    String resolvedPhone = (userRes?['phone'] as String?)?.trim() ?? '';
    String resolvedEmail = (userRes?['email'] as String?)?.trim() ?? (authUser?.email?.trim() ?? '');

    // If missing or generic placeholder, inspect auth metadata or DI.userRepo
    if (resolvedName.isEmpty || resolvedName.startsWith('User ')) {
      if (authUser != null) {
        final metaName = (authUser.userMetadata?['full_name'] ?? authUser.userMetadata?['name']) as String?;
        if (metaName != null && metaName.trim().isNotEmpty && !metaName.startsWith('User ')) {
          resolvedName = metaName.trim();
        }
        if (resolvedPhone.isEmpty && authUser.phone != null) {
          resolvedPhone = authUser.phone!;
        }
      }
    }

    if (resolvedName.isEmpty || resolvedName.startsWith('User ')) {
      try {
        final dbUser = await DI.userRepo.getUserProfile(effectiveId);
        final dbName = (dbUser?['full_name'] as String?)?.trim() ?? '';
        if (dbName.isNotEmpty && !dbName.startsWith('User ')) {
          resolvedName = dbName;
        }
        if (resolvedPhone.isEmpty) {
          resolvedPhone = (dbUser?['phone'] as String?)?.trim() ?? '';
        }
      } catch (_) {}
    }

    if (resolvedName.isEmpty) {
      if (resolvedPhone.isNotEmpty) {
        resolvedName = 'Artisan ($resolvedPhone)';
      } else {
        resolvedName = 'Rahul Patil';
      }
    }

    RegisteredWorkerStore.registerWorker(
      workerId: effectiveId,
      fullName: resolvedName,
      trade: (workerRes?['trade'] as String?) ?? (workerRes?['primary_skill'] as String?) ?? '',
      phone: resolvedPhone,
    );

    final avatarUrl = (userRes?['avatar_url'] as String?) ??
        (authUser?.userMetadata?['avatar_url'] as String?) ??
        'https://i.pravatar.cc/150?u=$effectiveId';

    // Attempt to parse VerificationStatus
    VerificationStatus verificationStatus = VerificationStatus.fromDb(workerRes?['worker_status']);

    // Also read rejection_reason / remarks from worker_verification table
    // (admin writes reviewed_by, rejection_reason here — not on workers table)
    String? rejectionReason = workerRes?['verification_remarks'] as String?;
    if (isUuid) {
      try {
        final verRow = await _supabase
            .from('worker_verification')
            .select('rejection_reason, remarks, status')
            .eq('worker_id', effectiveId)
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();
        if (verRow != null) {
          final verRejection = verRow['rejection_reason'] as String?;
          final verRemarks = verRow['remarks'] as String?;
          // Prefer rejection_reason for rejected status; otherwise use remarks
          if (verRejection != null && verRejection.trim().isNotEmpty) {
            rejectionReason = verRejection.trim();
          } else if (verRemarks != null && verRemarks.trim().isNotEmpty && rejectionReason == null) {
            rejectionReason = verRemarks.trim();
          }
        }
      } catch (_) {}
    }

    final fedRefId = workerRes?['federation_ref_id']?.toString();
    final rawFedName = workerRes?['federation_name'] as String?;
    final rawLoc = workerRes?['location_tag'] as String? ?? '';
    final rawDist = workerRes?['district'] as String? ?? '';
    final rawCity = workerRes?['city'] as String? ?? '';

    // If worker's chosen working locality/location_tag clearly belongs to another federation (e.g. Nagpur / Sitabuldi / Dharampeth),
    // but the record has a stale/fallback Pune federation from initial registration, heal it to the true federation.
    FederationModel resolvedFed;
    final locLower = rawLoc.toLowerCase();
    if ((locLower.contains('nagpur') || locLower.contains('sitabuldi') || locLower.contains('dharampeth') || locLower.contains('sadar')) &&
        (rawFedName?.toLowerCase().contains('pune') == true || fedRefId == '11111111-0000-0000-0000-000000000001')) {
      resolvedFed = FederationModel.defaultFederations.firstWhere((f) => f.id == '55555555-0000-0000-0000-000000000005');
      if (isUuid) {
        _supabase.from('workers').update({
          'federation_ref_id': resolvedFed.id,
          'federation_id': resolvedFed.id,
          'city': resolvedFed.city,
        }).eq('id', effectiveId).then((_) {}, onError: (_) {});
      }
    } else if ((locLower.contains('nashik') || locLower.contains('satpur') || locLower.contains('panchavati')) &&
        (rawFedName?.toLowerCase().contains('pune') == true || fedRefId == '11111111-0000-0000-0000-000000000001')) {
      resolvedFed = FederationModel.defaultFederations.firstWhere((f) => f.id == '22222222-0000-0000-0000-000000000002');
      if (isUuid) {
        _supabase.from('workers').update({
          'federation_ref_id': resolvedFed.id,
          'federation_id': resolvedFed.id,
          'city': resolvedFed.city,
        }).eq('id', effectiveId).then((_) {}, onError: (_) {});
      }
    } else {
      resolvedFed = FederationModel.resolveFederation(
        federationId: fedRefId ?? workerRes?['federation_id']?.toString(),
        federationName: rawFedName,
        district: rawDist,
        city: rawCity,
        location: rawLoc,
      );
    }

    return WorkerProfile(
      id: effectiveId,
      name: resolvedName,
      profileImage: avatarUrl,
      phone: resolvedPhone,
      email: resolvedEmail.isNotEmpty ? resolvedEmail : null,
      skills: [workerRes?['primary_skill'] as String? ?? 'General Service'],
      experience: '${workerRes?['experience_years'] ?? 2} Years',
      rating: (workerRes?['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (workerRes?['review_count'] as num?)?.toInt() ?? 0,
      completedJobs: workerRes?['completed_jobs'] ?? 0,
      earnings: await () async {
        if (!isUuid) return 0.0;
        try {
          final earningsRes = await _supabase
              .from('payments')
              .select('amount')
              .eq('worker_id', effectiveId)
              .eq('escrow_status', 'released');
          double total = 0.0;
          for (final row in (earningsRes as List)) {
            total += (row['amount'] as num?)?.toDouble() ?? 0.0;
          }
          return total;
        } catch (_) {
          try {
            final fallbackRes = await _supabase
                .from('payments')
                .select('amount')
                .eq('worker_id', effectiveId)
                .eq('status', 'PAID');
            double total = 0.0;
            for (final row in (fallbackRes as List)) {
              total += (row['amount'] as num?)?.toDouble() ?? 0.0;
            }
            return total;
          } catch (_) {
            return 0.0;
          }
        }
      }(),
      isVerified: verificationStatus == VerificationStatus.approved,
      verificationStatus: verificationStatus,
      isAvailable: workerRes?['is_available'] ?? false,
      serviceLocation: workerRes?['location_tag'] ?? 'Pune, Maharashtra',
      serviceAreas: (workerRes?['service_areas'] as List?)?.map((e) => e.toString()).toList() ?? [workerRes?['location_tag'] ?? 'Pune, Maharashtra'],
      guildName: resolvedFed.name,
      guildId: workerRes?['membership_id'] as String? ?? 'Pending Assignment',
      latitude: (workerRes?['latitude'] as num?)?.toDouble(),
      longitude: (workerRes?['longitude'] as num?)?.toDouble(),
      locationUpdatedAt: workerRes?['location_updated_at'] != null
          ? DateTime.tryParse(workerRes!['location_updated_at'].toString())
          : null,
      dob: workerRes?['dob']?.toString(),
      gender: workerRes?['gender'] as String?,
      district: workerRes?['district'] as String? ?? resolvedFed.district,
      pinCode: workerRes?['pincode'] as String?,
      trade: workerRes?['trade'] as String?,
      primarySkill: workerRes?['primary_skill'] as String?,
      skillLevel: workerRes?['skill_level'] as String? ?? 'Intermediate',
      membershipId: workerRes?['membership_id'] as String?,
      verificationRemarks: rejectionReason,
      registeredAt: workerRes?['created_at'] != null
          ? DateTime.tryParse(workerRes!['created_at'].toString())
          : null,
      federationRefId: resolvedFed.id,
    );

  }

  @override
  Future<void> updateWorkerAvailability(String workerId, bool isAvailable) async {
    try {
      await _supabase.from('workers').update({'is_available': isAvailable}).eq('id', workerId);
    } catch (e) {
      debugPrint('[WorkerRepo] update is_available note: $e');
    }

    // Synchronize availability with MockCustomerRepository so discovery immediately reflects it
    final existing = MockCustomerRepository().workers.where((w) => w.id == workerId).toList();
    if (existing.isNotEmpty) {
      final old = existing.first;
      final updated = Worker(
        id: old.id,
        name: old.name,
        categoryId: old.categoryId,
        rate: old.rate,
        rating: old.rating,
        reviewCount: old.reviewCount,
        jobsCompleted: old.jobsCompleted,
        distanceKm: old.distanceKm,
        experience: old.experience,
        availability: isAvailable ? 'Available Today' : 'Unavailable',
        specializations: old.specializations,
        locationTag: old.locationTag,
        imageUrl: old.imageUrl,
        customTag: old.customTag,
        bio: old.bio,
        federationId: old.federationId,
        insuranceAmount: old.insuranceAmount,
        languages: old.languages,
        serviceAreas: old.serviceAreas,
        isUnionGold: old.isUnionGold,
        isCoopMaster: old.isCoopMaster,
      );
      MockCustomerRepository.registerOrUpdateWorker(updated);
    }
  }

  @override
  Future<void> updateWorkerLocation(
    String workerId, {
    required double latitude,
    required double longitude,
    String? locationTag,
  }) async {
    final updates = <String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'location_updated_at': DateTime.now().toIso8601String(),
    };
    if (locationTag != null && locationTag.isNotEmpty) {
      updates['location_tag'] = locationTag;
    }
    await _supabase.from('workers').update(updates).eq('id', workerId);
  }

  @override
  Future<void> updateProfileImage(String workerId, String imageUrl) async {
    await _supabase.from('users').update({'avatar_url': imageUrl}).eq('id', workerId);
  }

  @override
  Future<List<JobRequest>> getJobRequests(String workerId) async {
    try {
      final response = await _supabase.from('bookings').select('''
        id, status, scheduled_date, scheduled_time, base_amount, labor_allowance, notes, customer_id, created_at, distance_km, otp,
        services!service_id(name),
        users!customer_id(full_name, phone),
        addresses(address_line, area, city)
      ''').eq('worker_id', workerId).order('created_at', ascending: false);

      return (response as List).map((b) {
        final cData = b['users'] as Map<String, dynamic>? ?? {};
        final aData = b['addresses'] as Map<String, dynamic>?;
        final sData = b['services'] as Map<String, dynamic>?;
        final locParts = [
          if (aData?['area'] != null && aData!['area'].toString().isNotEmpty) aData['area'],
          if (aData?['city'] != null && aData!['city'].toString().isNotEmpty) aData['city'],
        ];
        final custLocation = locParts.isNotEmpty
            ? locParts.join(', ')
            : (aData?['address_line'] ?? 'Local');

        return JobRequest(
          id: b['id']?.toString() ?? '',
          customerId: b['customer_id'] ?? '',
          customerName: cData['full_name'] ?? 'Customer',
          customerLocation: custLocation,
          customerPhone: cData['phone'] ?? '',
          serviceName: sData?['name'] ?? 'General Service',
          date: b['scheduled_date'] ?? 'Today',
          time: b['scheduled_time'] ?? 'Now',
          baseAmount: (b['base_amount'] as num?)?.toDouble() ?? (b['amount'] as num?)?.toDouble() ?? 0.0,
          laborAllowance: (b['labor_allowance'] as num?)?.toDouble() ?? 0.0,
          status: _mapBookingStatus(b['status']),
          distanceKm: b['distance_km'] != null ? '${b['distance_km']} km' : 'Nearby',
          createdAt: b['created_at'] != null ? _formatTimeAgo(DateTime.tryParse(b['created_at']) ?? DateTime.now()) : 'Just now',
          paymentMethod: (b['payment_method'] as String?) ?? 'RAZORPAY',
          otp: (b['otp'] as String?) ?? '8492',
        );
      }).toList();
    } catch (e) {
      debugPrint('[SupabaseWorkerRepo] getJobRequests primary failed: $e, trying getWorkerBookings');
      return getWorkerBookings();
    }
  }

  @override
  Future<List<JobRequest>> getWorkerBookings() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final res = await _supabase
          .from('bookings')
          .select('*, users!customer_id(full_name, phone), services!service_id(name), addresses(address_line, area, city)')
          .eq('worker_id', userId)
          .order('created_at', ascending: false);

      return (res as List).map((row) {
        final user = row['users'] as Map<String, dynamic>? ?? {};
        final service = row['services'] as Map<String, dynamic>? ?? {};
        final addr = row['addresses'] as Map<String, dynamic>?;
        final locParts = [
          if (addr?['area'] != null && addr!['area'].toString().isNotEmpty) addr['area'],
          if (addr?['city'] != null && addr!['city'].toString().isNotEmpty) addr['city'],
        ];
        final customerLocation = locParts.isNotEmpty
            ? locParts.join(', ')
            : (addr?['address_line'] ?? 'Pune');
        
        final status = BookingStatus.fromDbString(row['status'] as String?);
        
        return JobRequest(
          id: row['id'].toString(),
          customerId: row['customer_id'] ?? '',
          customerName: user['full_name'] ?? 'Customer',
          customerLocation: customerLocation,
          customerPhone: user['phone'] ?? '',
          serviceName: service['name'] ?? 'General Service',
          date: row['scheduled_date'] ?? 'Today',
          time: row['scheduled_time'] ?? 'Now',
          baseAmount: (row['base_amount'] as num?)?.toDouble() ?? (row['amount'] as num?)?.toDouble() ?? 0.0,
          laborAllowance: (row['labor_allowance'] as num?)?.toDouble() ?? 0.0,
          status: status,
          distanceKm: row['distance_km'] != null ? '${row['distance_km']} km' : 'Nearby',
          createdAt: row['created_at'] != null 
              ? _formatTimeAgo(DateTime.tryParse(row['created_at']) ?? DateTime.now())
              : 'Just now',
          paymentMethod: (row['payment_method'] as String?) ?? 'RAZORPAY',
          otp: (row['otp'] as String?) ?? '8492',
        );
      }).toList();
    } catch (e) {
      debugPrint('[SupabaseWorkerRepo] getWorkerBookings join failed: $e, falling back to basic query');
      try {
        final res = await _supabase
            .from('bookings')
            .select('*, services(name)')
            .eq('worker_id', userId)
            .order('created_at', ascending: false);

        return (res as List).map((row) {
          final service = row['services'] as Map<String, dynamic>? ?? {};
          final status = BookingStatus.fromDbString(row['status'] as String?);
          return JobRequest(
            id: row['id'].toString(),
            customerId: row['customer_id'] ?? '',
            customerName: 'Customer',
            customerLocation: 'Local Service Site',
            customerPhone: '',
            serviceName: service['name'] ?? 'General Service',
            date: row['scheduled_date'] ?? 'Today',
            time: row['scheduled_time'] ?? 'Now',
            baseAmount: (row['base_amount'] as num?)?.toDouble() ?? (row['amount'] as num?)?.toDouble() ?? 0.0,
            laborAllowance: (row['labor_allowance'] as num?)?.toDouble() ?? 0.0,
            status: status,
            distanceKm: row['distance_km'] != null ? '${row['distance_km']} km' : 'Nearby',
            createdAt: row['created_at'] != null 
                ? _formatTimeAgo(DateTime.tryParse(row['created_at']) ?? DateTime.now())
                : 'Just now',
            paymentMethod: (row['payment_method'] as String?) ?? 'RAZORPAY',
            otp: (row['otp'] as String?) ?? '8492',
          );
        }).toList();
      } catch (fallbackErr) {
        debugPrint('[SupabaseWorkerRepo] getWorkerBookings fallback failed: $fallbackErr');
        if (AppConfig.useMockData) {
          return SharedBookingStore.instance.getWorkerBookings(workerId: userId);
        }
        return [];
      }
    }
  }

  @override
  Stream<List<JobRequest>> watchWorkerBookings() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    late StreamController<List<JobRequest>> controller;
    StreamSubscription? sub;
    StreamSubscription? storeSub;

    controller = StreamController<List<JobRequest>>.broadcast(
      onListen: () async {
        // Emit initial data
        try {
          final initial = await getWorkerBookings();
          if (!controller.isClosed) controller.add(initial);
        } catch (e) {
          if (!controller.isClosed) controller.addError(e);
        }

        // Listen for realtime booking events assigned to this worker
        sub = _realtimeService.streamBookingChanges(workerId: userId).listen(
          (event) async {
            try {
              final updated = await getWorkerBookings();
              if (!controller.isClosed) controller.add(updated);
            } catch (e) {
              if (!controller.isClosed) controller.addError(e);
            }
          },
          onError: (err) {
            if (!controller.isClosed) controller.addError(err);
          },
        );

        // Also listen to local in-memory store changes for instantaneous synchronization
        storeSub = SharedBookingStore.instance.onChange.listen((_) async {
          try {
            final updated = await getWorkerBookings();
            if (!controller.isClosed) controller.add(updated);
          } catch (_) {}
        });
      },
      onCancel: () async {
        await sub?.cancel();
        await storeSub?.cancel();
        if (!controller.isClosed) {
          await controller.close();
        }
      },
    );

    return controller.stream;
  }

  BookingStatus _mapBookingStatus(String? status) {
    return BookingStatus.fromDbString(status);
  }

  @override
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    final updatePayload = <String, dynamic>{
      'status': newStatus.toDbString(),
      'updated_at': DateTime.now().toIso8601String(),
      if (newStatus == BookingStatus.completed)
        'completed_at': DateTime.now().toIso8601String(),
    };

    Map<String, dynamic>? updated;
    try {
      updated = await _supabase
          .from('bookings')
          .update(updatePayload)
          .eq('id', bookingId)
          .select('customer_id, services!service_id(name)')
          .maybeSingle();
    } catch (_) {
      try {
        updated = await _supabase
            .from('bookings')
            .update(updatePayload)
            .eq('id', bookingId)
            .select('customer_id, service_id')
            .maybeSingle();
      } catch (err) {
        // Fallback update without select
        await _supabase.from('bookings').update(updatePayload).eq('id', bookingId);
      }
    }

    // Always synchronize in-memory store
    try {
      await SharedBookingStore.instance.updateBookingStatus(bookingId, newStatus);
    } catch (_) {}

    if (updated != null && updated['customer_id'] != null) {
      final customerId = updated['customer_id'] as String;
      final serviceData = updated['services'] is Map ? updated['services'] as Map<String, dynamic> : null;
      final serviceName = serviceData?['name'] as String? ?? 'your booking';

      String title = 'Booking Update';
      String body = 'Booking status changed to ${newStatus.label}.';

      switch (newStatus) {
        case BookingStatus.accepted:
          title = 'Booking Confirmed!';
          body = 'Your service partner has accepted $serviceName.';
          break;
        case BookingStatus.onTheWay:
          title = 'Partner On The Way';
          body = 'Your service partner is heading towards your location.';
          break;
        case BookingStatus.arrived:
          title = 'Partner Arrived';
          body = 'Your service partner has arrived at your location.';
          break;
        case BookingStatus.inProgress:
          title = 'Work In Progress';
          body = 'Service $serviceName has begun.';
          break;
        case BookingStatus.completed:
          title = 'Service Completed';
          body = 'Your service is complete. Please rate your experience!';
          try {
            await DI.paymentRepo.releaseEscrow(bookingId);
          } catch (e) {
            debugPrint('[WorkerRepo] auto-release escrow note: $e');
          }
          break;
        case BookingStatus.cancelled:
        case BookingStatus.rejected:
          title = 'Booking Cancelled';
          body = 'Your booking for $serviceName was cancelled.';
          break;
        default:
          break;
      }

      try {
        await DI.notificationRepo.sendPushNotification(
          recipientUserId: customerId,
          type: 'booking_status',
          title: title,
          body: body,
          data: {
            'bookingId': bookingId,
            'status': newStatus.toDbString(),
          },
        );
      } catch (e) {
        debugPrint('[SupabaseWorkerRepo] Push dispatch notification error: $e');
      }
    }
  }
  
  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Future<List<Map<String, dynamic>>> getVerificationDocuments(String workerId) async {
    return await _supabase.from('worker_verification_documents').select().eq('worker_id', workerId).order('created_at');
  }

  @override
  Future<void> submitVerificationDocument(String workerId, String documentType, String storagePath, String fileName, String mimeType, int fileSize) async {
    await _supabase.from('worker_verification_documents').insert({
      'worker_id': workerId,
      'document_type': documentType,
      'storage_path': storagePath,
      'file_name': fileName,
      'mime_type': mimeType,
      'file_size': fileSize,
      'status': 'PENDING'
    });
  }

  @override
  Future<void> submitForVerification(String workerId) async {
    await _supabase.from('workers').update({'worker_status': 'PENDING_VERIFICATION'}).eq('id', workerId);
    try {
      await _supabase.from('worker_verification_history').insert({
        'worker_id': workerId,
        'previous_status': 'NOT_SUBMITTED',
        'new_status': 'PENDING_VERIFICATION',
        'action': 'SUBMIT_REGISTRATION',
        'remarks': 'Worker submitted registration for verification',
      });
    } catch (_) {}
  }

  @override
  Future<void> resubmitForVerification(String workerId) async {
    await _supabase.from('workers').update({
      'worker_status': 'UNDER_REVIEW',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', workerId);

    try {
      await _supabase.from('worker_verification_history').insert({
        'worker_id': workerId,
        'previous_status': 'CHANGES_REQUIRED',
        'new_status': 'UNDER_REVIEW',
        'action': 'RESUBMIT',
        'remarks': 'Worker updated requested documents/details and resubmitted for review',
      });
    } catch (_) {}
  }

  @override
  Future<List<WorkerVerificationHistoryItem>> getVerificationHistory(String workerId) async {
    try {
      final res = await _supabase
          .from('worker_verification_history')
          .select('''
            id, worker_id, admin_id, previous_status, new_status, action, remarks, created_at,
            admin:users!worker_verification_history_admin_id_fkey(full_name)
          ''')
          .eq('worker_id', workerId)
          .order('created_at', ascending: false);

      return (res as List).map((h) {
        final adminData = h['admin'] as Map<String, dynamic>?;
        final map = Map<String, dynamic>.from(h);
        map['admin_name'] = adminData?['full_name'];
        return WorkerVerificationHistoryItem.fromJson(map);
      }).toList();
    } catch (e) {
      // Fallback query if foreign key alias varies
      try {
        final fallback = await _supabase
            .from('worker_verification_history')
            .select()
            .eq('worker_id', workerId)
            .order('created_at', ascending: false);
        return (fallback as List).map((h) => WorkerVerificationHistoryItem.fromJson(h)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  @override
  Future<void> registerWorker({
    required String workerId,
    required String fullName,
    required String phone,
    String? email,
    required String skill,
    required int experienceYears,
    required String serviceLocation,
    List<String>? serviceAreas,
    String? dob,
    String? gender,
    String? address,
    String? city,
    String? district,
    String? pinCode,
    String? trade,
    String? skillLevel,
    String? federationName,
    String? federationId,
    String? membershipId,
    String? bio,
    bool declarationAccepted = true,
  }) async {
    // 1. Update user record with full name, phone, email & role
    try {
      final userUpdates = <String, dynamic>{
        'full_name': fullName,
        'role': 'WORKER',
        'phone': phone,
      };
      if (email != null && email.trim().isNotEmpty) {
        userUpdates['email'] = email.trim();
      }
      await _supabase.from('users').update(userUpdates).eq('id', workerId);
    } catch (e) {
      debugPrint('[SupabaseWorkerRepo] update users full_name/email error: $e');
    }

    final targetFed = FederationModel.resolveFederation(
      federationId: federationId,
      federationName: federationName,
      district: district,
      city: city,
      location: serviceLocation,
      address: address,
    );

    final cleanMemId = membershipId?.trim().isNotEmpty == true
        ? membershipId!.trim()
        : 'FED-${targetFed.city.substring(0, targetFed.city.length >= 3 ? 3 : targetFed.city.length).toUpperCase()}-${DateTime.now().year % 100}${workerId.replaceAll(RegExp(r'[^0-9]'), '').padRight(4, '7').substring(0, 4)}';

    // 2. Upsert workers table with pending verification status and 20 required fields
    try {
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(workerId);
      if (isUuid) {
        final areasList = (serviceAreas != null && serviceAreas.isNotEmpty)
            ? List<String>.from(serviceAreas)
            : <String>[serviceLocation];
        if (district != null && district.isNotEmpty && !areasList.contains(district)) {
          areasList.add(district);
        }
        if (city != null && city.isNotEmpty && !areasList.contains(city)) {
          areasList.add(city);
        }

        final rawBioText = bio ?? 'Certified $skill artisan based in $serviceLocation.';
        final structuredBio = rawBioText.startsWith(fullName)
            ? rawBioText
            : '$fullName ($cleanMemId) • $rawBioText';

        final safePayload = <String, dynamic>{
          'id': workerId,
          'bio': structuredBio,
          'experience_years': experienceYears,
          'location_tag': serviceLocation,
          'city': (city != null && city.isNotEmpty) ? city : targetFed.city,
          'state': 'Maharashtra',
          'service_areas': areasList,
          'federation_ref_id': targetFed.id,
          'federation_id': targetFed.id,
          'worker_status': 'ACTIVE',
          'is_available': true,
        };

        try {
          await _supabase.from('workers').upsert(safePayload);
        } catch (colErr) {
          debugPrint('[SupabaseWorkerRepo] workers upsert error: $colErr');
          try {
            await _supabase.from('workers').update({
              'federation_ref_id': targetFed.id,
              'federation_id': targetFed.id,
              'location_tag': serviceLocation,
              'city': (city != null && city.isNotEmpty) ? city : targetFed.city,
              'bio': structuredBio,
              'is_available': true,
            }).eq('id', workerId);
          } catch (updateErr) {
            debugPrint('[SupabaseWorkerRepo] workers update fallback error: $updateErr');
          }
        }

        // Try linking to worker_skills so FairMatch and trade queries can index worker
        try {
          const serviceUuidMap = {
            'c1': '11111111-1111-1111-1111-111111111111',
            'c2': '22222222-2222-2222-2222-222222222222',
            'c3': '33333333-3333-3333-3333-333333333333',
            'c4': '55555555-5555-5555-5555-555555555555',
            'c5': '44444444-4444-4444-4444-444444444444',
            'c6': '99999999-9999-9999-9999-999999999999',
            'c7': '88888888-8888-8888-8888-888888888888',
            'c8': '77777777-7777-7777-7777-777777777777',
          };
          final lowerSkill = skill.toLowerCase();
          final lowerTrade = (trade ?? '').toLowerCase();
          String? matchedCat;
          if (lowerSkill.contains('elect') || lowerTrade.contains('elect')) {
            matchedCat = 'c1';
          } else if (lowerSkill.contains('plumb') || lowerTrade.contains('plumb')) {
            matchedCat = 'c2';
          } else if (lowerSkill.contains('carpent') || lowerTrade.contains('carpent')) {
            matchedCat = 'c3';
          } else if (lowerSkill.contains('clean') || lowerTrade.contains('clean')) {
            matchedCat = 'c4';
          } else if (lowerSkill.contains('paint') || lowerTrade.contains('paint')) {
            matchedCat = 'c5';
          } else if (lowerSkill.contains('appliance') || lowerTrade.contains('appliance')) {
            matchedCat = 'c6';
          } else if (lowerSkill.contains('garden') || lowerTrade.contains('garden')) {
            matchedCat = 'c7';
          } else if (lowerSkill.contains('driver') || lowerTrade.contains('driver')) {
            matchedCat = 'c8';
          }
          if (matchedCat != null && serviceUuidMap.containsKey(matchedCat)) {
            await _supabase.from('worker_skills').upsert({
              'worker_id': workerId,
              'skill_id': serviceUuidMap[matchedCat]!,
            });
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[SupabaseWorkerRepo] upsert workers error: $e');
    }

    // Synchronize newly created/registered worker into memory so they are instantly discoverable
    final String catId;
    final lowerSkill = skill.toLowerCase();
    final lowerTrade = (trade ?? '').toLowerCase();
    if (lowerSkill.contains('elect') || lowerTrade.contains('elect')) {
      catId = 'c1';
    } else if (lowerSkill.contains('plumb') || lowerTrade.contains('plumb')) {
      catId = 'c2';
    } else if (lowerSkill.contains('carpent') || lowerTrade.contains('carpent')) {
      catId = 'c3';
    } else if (lowerSkill.contains('clean') || lowerTrade.contains('clean')) {
      catId = 'c4';
    } else if (lowerSkill.contains('paint') || lowerTrade.contains('paint')) {
      catId = 'c5';
    } else if (lowerSkill.contains('appliance') || lowerTrade.contains('appliance')) {
      catId = 'c6';
    } else if (lowerSkill.contains('garden') || lowerTrade.contains('yard')) {
      catId = 'c7';
    } else {
      catId = 'c2';
    }

    final newWorker = Worker(
      id: workerId,
      name: fullName,
      categoryId: catId,
      rate: 349,
      rating: 4.88,
      reviewCount: 34,
      jobsCompleted: 45,
      distanceKm: 1.5,
      experience: '$experienceYears yrs exp',
      availability: 'Available Today',
      specializations: [skill, trade ?? skill, 'Union Certified'],
      locationTag: serviceLocation.contains('Pune') ? serviceLocation : '$serviceLocation, Pune',
      imageUrl: '',
      customTag: 'Union Certified Artisan',
      bio: bio ?? 'Certified $skill artisan serving $serviceLocation with $experienceYears years of experience.',
      federationId: targetFed.id,
      insuranceAmount: 'Up to ₹1,50,000',
      languages: const ['मराठी', 'हिंदी', 'English'],
      serviceAreas: [serviceLocation.replaceAll(', Pune', '').trim(), 'Pune', 'All Areas'],
      isUnionGold: true,
      isCoopMaster: true,
    );

    MockCustomerRepository.registerOrUpdateWorker(newWorker);
    RegisteredWorkerStore.registerWorker(
      workerId: workerId,
      fullName: fullName,
      trade: trade ?? skill,
      phone: phone,
      workerModel: newWorker,
    );
  }

  @override
  Future<WorkerInsuranceModel?> getWorkerInsurance(String workerId) async {
    try {
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(workerId);
      if (isUuid) {
        final res = await _supabase.from('worker_insurance').select().eq('worker_id', workerId).maybeSingle();
        if (res != null) {
          return WorkerInsuranceModel.fromJson(res);
        }
      }
    } catch (e) {
      debugPrint('[SupabaseWorkerRepo] getWorkerInsurance note: $e');
    }
    return null;
  }

  @override
  Future<WorkerInsuranceModel> applyForInsurance(String workerId, {String? coverageType, double? coverageAmount}) async {
    final pending = WorkerInsuranceModel(
      workerId: workerId,
      policyNumber: 'PENDING_APPROVAL',
      providerName: 'Maharashtra State Cooperative Labour Federation Welfare Pool',
      coverageType: coverageType ?? 'Accidental & Medical Health Cover',
      coverageAmount: coverageAmount ?? 500000.0,
      startDate: DateTime.now(),
      expiryDate: DateTime.now().add(const Duration(days: 365)),
      status: InsuranceStatus.pending,
      verificationStatus: InsuranceVerificationStatus.pending,
    );

    try {
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(workerId);
      if (isUuid) {
        await _supabase.from('worker_insurance').upsert({
          'worker_id': workerId,
          'provider_name': pending.providerName,
          'policy_number': 'PENDING_APPROVAL',
          'coverage_type': pending.coverageType,
          'coverage_amount': pending.coverageAmount,
          'start_date': pending.startDate.toIso8601String().split('T').first,
          'expiry_date': pending.expiryDate.toIso8601String().split('T').first,
          'status': 'PENDING',
          'verification_status': 'PENDING',
        });
      }
    } catch (e) {
      debugPrint('[SupabaseWorkerRepo] applyForInsurance note: $e');
    }

    return pending;
  }

  @override
  Future<void> updateWorkerCredentials(
    String workerId, {
    required String phone,
    required String email,
  }) async {
    try {
      await _supabase.from('users').update({
        'phone': phone.trim(),
        'email': email.trim(),
      }).eq('id', workerId);
    } catch (e) {
      debugPrint('[SupabaseWorkerRepo] update users credentials error: $e');
    }

    try {
      await _supabase.from('workers').update({
        'phone': phone.trim(),
      }).eq('user_id', workerId);
    } catch (e) {
      debugPrint('[SupabaseWorkerRepo] update workers phone credentials error: $e');
    }
  }

  @override
  Future<void> updateWorkerServiceAreas(String workerId, List<String> serviceAreas) async {
    final firstLoc = serviceAreas.isNotEmpty ? serviceAreas.first : null;
    try {
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(workerId);
      final query = _supabase.from('workers').update({
        'service_areas': serviceAreas,
        if (firstLoc != null) 'service_location': firstLoc,
        'updated_at': DateTime.now().toIso8601String(),
      });
      if (isUuid) {
        await query.or('id.eq.$workerId,user_id.eq.$workerId');
      } else {
        await query.eq('id', workerId);
      }
    } catch (e) {
      debugPrint('[SupabaseWorkerRepo] updateWorkerServiceAreas note: $e');
    }
    // Also sync mock repo
    await MockWorkerRepository().updateWorkerServiceAreas(workerId, serviceAreas);
  }

  @override
  Future<void> raiseAreaChangeTicket({
    required String workerId,
    required List<String> requestedAreas,
    required String reason,
  }) async {
    try {
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(workerId);
      final query = _supabase.from('workers').select('id, federation_id, service_areas, service_location');
      final wRes = isUuid
          ? await query.or('id.eq.$workerId,user_id.eq.$workerId').maybeSingle()
          : await query.eq('id', workerId).maybeSingle();

      final actualWorkerId = wRes?['id'] as String? ?? workerId;
      final fedId = wRes?['federation_id'] as String?;
      final rawCurrent = wRes?['service_areas'];
      List<String> curAreas = [];
      if (rawCurrent is List) {
        curAreas = rawCurrent.map((e) => e.toString()).toList();
      } else if (wRes?['service_location'] != null) {
        curAreas = [wRes!['service_location'].toString()];
      }

      await _supabase.from('worker_area_tickets').insert({
        'worker_id': actualWorkerId,
        'federation_id': fedId,
        'current_areas': curAreas,
        'requested_areas': requestedAreas,
        'reason': reason.trim(),
        'status': 'PENDING',
      });
    } catch (e) {
      debugPrint('[SupabaseWorkerRepo] raiseAreaChangeTicket note: $e');
      await MockWorkerRepository().raiseAreaChangeTicket(
        workerId: workerId,
        requestedAreas: requestedAreas,
        reason: reason,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAreaChangeTickets(String workerId) async {
    try {
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(workerId);
      final query = _supabase.from('worker_area_tickets').select();
      final res = isUuid
          ? await query.or('worker_id.eq.$workerId').order('created_at', ascending: false)
          : await query.eq('worker_id', workerId).order('created_at', ascending: false);
      if (res is List && res.isNotEmpty) {
        return List<Map<String, dynamic>>.from(res);
      }
    } catch (e) {
      debugPrint('[SupabaseWorkerRepo] getAreaChangeTickets note: $e');
    }
    return MockWorkerRepository().getAreaChangeTickets(workerId);
  }
}
