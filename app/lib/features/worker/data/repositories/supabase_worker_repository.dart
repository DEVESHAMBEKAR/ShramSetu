import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/i_worker_repository.dart';
import '../../../../core/services/booking_realtime_service.dart';
import '../../../../core/config/dependency_injection.dart';
import '../models/worker_models.dart';

class SupabaseWorkerRepository implements IWorkerRepository {
  final SupabaseClient _supabase;
  final BookingRealtimeService _realtimeService;

  SupabaseWorkerRepository(this._supabase)
      : _realtimeService = BookingRealtimeService(_supabase);

  @override
  Future<WorkerProfile> getWorkerProfile(String userId) async {
    final userRes = await _supabase.from('users').select().eq('id', userId).single();
    final workerRes = await _supabase.from('workers').select().eq('id', userId).single();
    
    // Attempt to parse VerificationStatus
    VerificationStatus verificationStatus = VerificationStatus.pending;
    if (workerRes['worker_status'] == 'ACTIVE') {
      verificationStatus = VerificationStatus.approved;
    } else if (workerRes['worker_status'] == 'SUSPENDED') {
      verificationStatus = VerificationStatus.rejected;
    }
    
    return WorkerProfile(
      id: userId,
      name: userRes['full_name'] ?? 'Unknown',
      profileImage: 'https://i.pravatar.cc/150?u=',
      phone: userRes['phone'] ?? '',
      skills: ['General Service'],
      experience: '2 Years',
      rating: (workerRes['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (workerRes['review_count'] as num?)?.toInt() ?? 0,
      completedJobs: workerRes['completed_jobs'] ?? 0,
      earnings: 0.0,
      isVerified: verificationStatus == VerificationStatus.approved,
      verificationStatus: verificationStatus,
      isAvailable: workerRes['is_available'] ?? false,
      serviceLocation: workerRes['location_tag'] ?? 'Pune, Maharashtra',
      guildName: 'ShramSetu Cooperative',
      guildId: '#',
      latitude: (workerRes['latitude'] as num?)?.toDouble(),
      longitude: (workerRes['longitude'] as num?)?.toDouble(),
      locationUpdatedAt: workerRes['location_updated_at'] != null 
          ? DateTime.tryParse(workerRes['location_updated_at'].toString()) 
          : null,
    );
  }

  @override
  Future<void> updateWorkerAvailability(String workerId, bool isAvailable) async {
    await _supabase.from('workers').update({'is_available': isAvailable}).eq('id', workerId);
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
    // Return all bookings mapped to workerId
    final response = await _supabase.from('bookings').select('''
      id, status, scheduled_date, scheduled_time, amount, notes, customer_id, created_at, distance_km,
      services(name),
      users!customer_id(full_name, phone),
      addresses(address_line, area, city)
    ''').eq('worker_id', workerId).order('created_at', ascending: false);

    return (response as List).map((b) {
      final cData = b['users'] ?? {};
      final aData = b['addresses'] as Map<String, dynamic>?;
      final locParts = [
        if (aData?['area'] != null && aData!['area'].toString().isNotEmpty) aData['area'],
        if (aData?['city'] != null && aData!['city'].toString().isNotEmpty) aData['city'],
      ];
      final custLocation = locParts.isNotEmpty
          ? locParts.join(', ')
          : (aData?['address_line'] ?? 'Local');

      return JobRequest(
        id: b['id'],
        customerId: b['customer_id'] ?? '',
        customerName: cData['full_name'] ?? 'Unknown',
        customerLocation: custLocation,
        customerPhone: cData['phone'] ?? 'Unknown',
        serviceName: b['services'] != null ? b['services']['name'] : 'Unknown',
        date: b['scheduled_date'] ?? '',
        time: b['scheduled_time'] ?? '',
        baseAmount: (b['amount'] ?? 0).toDouble(),
        laborAllowance: 0.0,
        status: _mapBookingStatus(b['status']),
        distanceKm: b['distance_km'] != null ? '${b['distance_km']} km' : 'Nearby',
        createdAt: b['created_at'] ?? '',
      );
    }).toList();
  }



  @override
  Future<List<JobRequest>> getWorkerBookings() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

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
        customerName: user['full_name'] ?? 'Unknown Customer',
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
            ? _formatTimeAgo(DateTime.parse(row['created_at']))
            : 'Just now',
      );
    }).toList();
  }

  @override
  Stream<List<JobRequest>> watchWorkerBookings() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    late StreamController<List<JobRequest>> controller;
    StreamSubscription? sub;

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

  BookingStatus _mapBookingStatus(String? status) {
    return BookingStatus.fromDbString(status);
  }

  @override
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    final updated = await _supabase.from('bookings').update({
      'status': newStatus.toDbString(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId).select('customer_id, service_name').maybeSingle();

    if (updated != null && updated['customer_id'] != null) {
      final customerId = updated['customer_id'] as String;
      final serviceName = updated['service_name'] ?? 'your booking';

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
  }
}
