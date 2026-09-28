import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/i_admin_repository.dart';
import '../../../../core/services/booking_realtime_service.dart';
import '../models/admin_models.dart';
import '../../../worker/data/models/worker_models.dart';

class SupabaseAdminRepository implements IAdminRepository {
  final SupabaseClient _client;
  final BookingRealtimeService _realtimeService;

  SupabaseAdminRepository(this._client)
      : _realtimeService = BookingRealtimeService(_client);

  @override
  Future<AdminDashboardStats> getDashboardStats() async {
    final totalWorkersRes = await _client.from('workers').select('id').count(CountOption.exact);
    final verifiedWorkersRes = await _client.from('workers').select('id').eq('worker_status', 'ACTIVE').count(CountOption.exact);
    final pendingRes = await _client.from('workers').select('id').eq('worker_status', 'PENDING_VERIFICATION').count(CountOption.exact);
    final activeBookingsRes = await _client.from('bookings').select('id').inFilter('status', ['pending', 'accepted', 'inProgress']).count(CountOption.exact);

    return AdminDashboardStats(
      totalWorkers: totalWorkersRes.count,
      verifiedWorkers: verifiedWorkersRes.count,
      pendingVerifications: pendingRes.count,
      activeBookings: activeBookingsRes.count,
      escrowLocked: 0.0,
      welfarePool: 0.0,
      fairWorkIndex: 98.5,
    );
  }

  @override
  @override
  Future<List<WorkerProfile>> getWorkers() async {
    try {
      final response = await _client.from('workers').select('''
        id, bio, experience_years, rating, completed_jobs, is_available, worker_status, location_tag,
        dob, gender, trade, primary_skill, skill_level, district, pincode, federation_name, membership_id, verification_remarks, created_at,
        users!inner(full_name, phone, avatar_url)
      ''').order('created_at', ascending: false).limit(100);

      return (response as List).map((json) {
        final uData = json['users'] ?? {};
        final status = VerificationStatus.fromDb(json['worker_status']);
        final pSkill = json['primary_skill'] as String? ?? (json['trade'] as String? ?? 'General Services');

        return WorkerProfile(
          id: json['id'],
          name: uData['full_name'] ?? 'Unknown',
          phone: uData['phone'] ?? 'Unknown',
          profileImage: uData['avatar_url'] ?? 'assets/images/workers/default.jpg',
          skills: [pSkill],
          experience: '${json['experience_years'] ?? 0} Years',
          rating: (json['rating'] ?? 0).toDouble(),
          completedJobs: json['completed_jobs'] ?? 0,
          isVerified: status == VerificationStatus.approved,
          isAvailable: json['is_available'] ?? false,
          verificationStatus: status,
          earnings: 0.0,
          guildId: json['membership_id'] ?? 'None',
          guildName: json['federation_name'] ?? 'Pune District Labour Cooperative Federation',
          serviceLocation: json['location_tag'] ?? 'Pune',
          dob: json['dob']?.toString(),
          gender: json['gender'] as String?,
          district: json['district'] as String? ?? 'Pune',
          pinCode: json['pincode'] as String?,
          trade: json['trade'] as String?,
          primarySkill: pSkill,
          skillLevel: json['skill_level'] as String? ?? 'Intermediate',
          membershipId: json['membership_id'] as String?,
          verificationRemarks: json['verification_remarks'] as String?,
          registeredAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
        );
      }).toList();
    } catch (e) {
      // Fallback query without newer optional columns if needed
      final response = await _client.from('workers').select('''
        id, bio, experience_years, rating, completed_jobs, is_available, worker_status, location_tag,
        users!inner(full_name, phone)
      ''').order('created_at', ascending: false).limit(100);

      return (response as List).map((json) {
        final uData = json['users'] ?? {};
        final status = VerificationStatus.fromDb(json['worker_status']);

        return WorkerProfile(
          id: json['id'],
          name: uData['full_name'] ?? 'Unknown',
          phone: uData['phone'] ?? 'Unknown',
          skills: ['General Services'],
          experience: '${json['experience_years'] ?? 0} Years',
          rating: (json['rating'] ?? 0).toDouble(),
          completedJobs: json['completed_jobs'] ?? 0,
          isVerified: status == VerificationStatus.approved,
          isAvailable: json['is_available'] ?? false,
          verificationStatus: status,
          earnings: 0.0,
          profileImage: 'assets/images/workers/default.jpg',
          guildId: 'None',
          guildName: 'Pune District Labour Cooperative Federation',
          serviceLocation: json['location_tag'] ?? 'Local',
        );
      }).toList();
    }
  }

  Future<void> _executeVerificationAction(String workerId, String action, String? remarks, String newWorkerStatus) async {
    final adminId = _client.auth.currentUser?.id;
    // 1. Try secure RPC
    try {
      await _client.rpc('admin_verify_worker', params: {
        'p_worker_id': workerId,
        'p_action': action,
        'p_remarks': remarks,
      });
      return;
    } catch (_) {}

    // 2. Direct database update fallback
    String prevStatus = 'PENDING_VERIFICATION';
    try {
      final current = await _client.from('workers').select('worker_status').eq('id', workerId).maybeSingle();
      if (current != null && current['worker_status'] != null) {
        prevStatus = current['worker_status'].toString();
      }
    } catch (_) {}

    final corePayload = <String, dynamic>{
      'worker_status': newWorkerStatus,
      'is_available': newWorkerStatus == 'ACTIVE',
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Try updating workers table (try rich payload with remarks/verified_at if columns exist, fallback to core)
    try {
      final richPayload = Map<String, dynamic>.from(corePayload);
      if (remarks != null && remarks.isNotEmpty) {
        richPayload['verification_remarks'] = remarks;
      }
      if (newWorkerStatus == 'ACTIVE') {
        richPayload['verified_at'] = DateTime.now().toIso8601String();
      }
      await _client.from('workers').update(richPayload).eq('id', workerId);
    } catch (_) {
      try {
        await _client.from('workers').update(corePayload).eq('id', workerId);
      } catch (err) {
        // Last resort: write a baseline status that is always allowed
        final safeStatus = (newWorkerStatus == 'ACTIVE')
            ? 'ACTIVE'
            : (newWorkerStatus == 'REJECTED' || newWorkerStatus == 'INACTIVE')
                ? 'REJECTED'
                : (newWorkerStatus == 'SUSPENDED')
                    ? 'SUSPENDED'
                    : 'PENDING_VERIFICATION';
        try {
          await _client.from('workers').update({
            'worker_status': safeStatus,
            'is_available': safeStatus == 'ACTIVE',
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', workerId);
        } catch (_) {
          rethrow;
        }
      }
    }

    // 3. Update or insert into worker_verification table (reviewed_by and rejection_reason belong here)
    try {
      final verExisting = await _client
          .from('worker_verification')
          .select('id')
          .eq('worker_id', workerId)
          .maybeSingle();

      String verStatus = 'PENDING';
      if (newWorkerStatus == 'ACTIVE') {
        verStatus = 'APPROVED';
      } else if (newWorkerStatus == 'REJECTED') {
        verStatus = 'REJECTED';
      }

      final verData = <String, dynamic>{
        'worker_id': workerId,
        'status': verStatus,
        'reviewed_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (adminId != null) verData['reviewed_by'] = adminId;
      if (remarks != null && remarks.isNotEmpty) {
        verData['rejection_reason'] = remarks;
      }

      if (verExisting != null && verExisting['id'] != null) {
        await _client.from('worker_verification').update(verData).eq('id', verExisting['id']);
      } else {
        await _client.from('worker_verification').insert(verData);
      }
    } catch (_) {}

    // 4. Log history entry
    try {
      await _client.from('worker_verification_history').insert({
        'worker_id': workerId,
        'admin_id': adminId,
        'previous_status': prevStatus,
        'new_status': newWorkerStatus,
        'action': action,
        'remarks': remarks,
      });
    } catch (_) {}
  }

  @override
  Future<void> startReview(String workerId, {String? remarks}) async {
    await _executeVerificationAction(workerId, 'START_REVIEW', remarks ?? 'Review initiated by administrator', 'UNDER_REVIEW');
  }

  @override
  Future<void> approveWorker(String workerId, {String? remarks}) async {
    await _executeVerificationAction(workerId, 'APPROVE', remarks ?? 'Verified and approved for marketplace', 'ACTIVE');
  }

  @override
  Future<void> requestChanges(String workerId, {required String remarks}) async {
    await _executeVerificationAction(workerId, 'REQUEST_CHANGES', remarks, 'CHANGES_REQUIRED');
  }

  @override
  Future<void> rejectWorker(String workerId, {String? remarks}) async {
    await _executeVerificationAction(workerId, 'REJECT', remarks ?? 'Application does not meet federation criteria', 'REJECTED');
  }

  @override
  Future<List<JobRequest>> getBookings() async {
    final response = await _client.from('bookings').select('''
      id, status, scheduled_date, scheduled_time, amount, notes, customer_id, created_at,
      services(name),
      workers(users(full_name)),
      users!customer_id(full_name, phone)
    ''').order('created_at', ascending: false).limit(100);

    return (response as List).map((b) {
      final cData = b['users'] ?? {};
      return JobRequest(
        id: b['id'],
        customerId: b['customer_id'] ?? '',
        customerName: cData['full_name'] ?? 'Unknown',
        customerLocation: 'Local',
        customerPhone: cData['phone'] ?? 'Unknown',
        serviceName: b['services'] != null ? b['services']['name'] : 'Unknown',
        date: b['scheduled_date'] ?? '',
        time: b['scheduled_time'] ?? '',
        baseAmount: (b['amount'] ?? 0).toDouble(),
        laborAllowance: 0.0,
        status: BookingStatus.fromDbString(b['status']),
        distanceKm: '0.0 km',
        createdAt: b['created_at'] ?? '',
      );
    }).toList();
  }

  @override
  Stream<List<JobRequest>> watchBookings() {
    late StreamController<List<JobRequest>> controller;
    StreamSubscription? sub;

    controller = StreamController<List<JobRequest>>.broadcast(
      onListen: () async {
        // Emit initial data
        try {
          final initial = await getBookings();
          if (!controller.isClosed) controller.add(initial);
        } catch (e) {
          if (!controller.isClosed) controller.addError(e);
        }

        // Listen for all booking changes (Admin RLS permits reading all)
        sub = _realtimeService.streamBookingChanges().listen(
          (event) async {
            try {
              final updated = await getBookings();
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
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    await _client.from('bookings').update({
      'status': newStatus.toDbString(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }


  @override
  Future<List<Complaint>> getComplaints() async {
    final response = await _client.from('complaints').select('''
      id, booking_id, subject, description, status, priority, created_at,
      users!customer_id(full_name)
    ''').order('created_at', ascending: false).limit(100);

    return (response as List).map((c) {
      final cData = c['users'] ?? {};
      return Complaint(
        id: c['id'].toString(),
        customerName: cData['full_name'] ?? 'Unknown',
        workerName: 'Worker',
        bookingId: c['booking_id'] ?? '',
        subject: c['subject'] ?? 'No Subject',
        description: c['description'] ?? '',
        date: c['created_at'] != null ? DateTime.parse(c['created_at']) : DateTime.now(),
        status: c['status'] == 'OPEN' ? ComplaintStatus.open : ComplaintStatus.resolved,
        priority: c['priority'] ?? 'NORMAL',
      );
    }).toList();
  }

  @override
  Future<void> updateComplaintStatus(String complaintId, ComplaintStatus newStatus) async {
    String status = newStatus == ComplaintStatus.open ? 'OPEN' : 'RESOLVED';
    await _client.from('complaints').update({'status': status}).eq('id', complaintId);
  }

  @override
  Future<List<WelfareRecord>> getWelfareRecords() async {
    final response = await _client.from('welfare_records').select('''
      id, amount, type, status, description, created_at,
      workers(users(full_name))
    ''').order('created_at', ascending: false).limit(100);

    return (response as List).map((w) {
      return WelfareRecord(
        id: w['id'].toString(),
        title: w['type'] ?? 'General',
        details: w['description'] ?? '',
        type: w['type'] ?? 'General',
        status: w['status'] ?? 'PENDING',
      );
    }).toList();
  }

  @override
  Future<List<AdminCustomerProfile>> getCustomers() async {
    final response = await _client.from('users').select('''
      id, full_name, phone, created_at
    ''').eq('role', 'CUSTOMER').order('created_at', ascending: false).limit(100);

    return (response as List).map((c) => AdminCustomerProfile(
      id: c['id'],
      name: c['full_name'] ?? 'Unknown',
      phone: c['phone'] ?? 'Unknown',
      totalBookings: 0,
      lastBooking: DateTime.now(),
      status: 'Active',
    )).toList();
  }

  @override
  Future<List<AdminService>> getServices() async {
    final response = await _client.from('services').select('''
      id, name, icon_name, is_active
    ''').order('name', ascending: true).limit(100);

    return (response as List).map((s) => AdminService(
      id: s['id'].toString(),
      name: s['name'] ?? 'Unknown',
      icon: s['icon_name'] ?? 'build',
      status: s['is_active'] == true ? ServiceStatus.active : ServiceStatus.inactive,
    )).toList();
  }

  @override
  Future<void> toggleServiceStatus(String serviceId) async {
    final current = await _client.from('services').select('is_active').eq('id', serviceId).single();
    await _client.from('services').update({'is_active': !(current['is_active'] ?? true)}).eq('id', serviceId);
  }

  @override
  Future<void> suspendWorker(String workerId, {String? remarks}) async {
    await _executeVerificationAction(workerId, 'SUSPEND', remarks ?? 'Worker suspended by administrator', 'SUSPENDED');
  }

  @override
  Future<List<WorkerVerificationHistoryItem>> getVerificationHistory(String workerId) async {
    try {
      final res = await _client
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
      try {
        final fallback = await _client
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
  Future<List<Map<String, dynamic>>> getWorkerDocuments(String workerId) async {
    return await _client
        .from('worker_verification_documents')
        .select()
        .eq('worker_id', workerId)
        .order('created_at');
  }

  @override
  Future<void> updateDocumentStatus(String documentId, String status, {String? remarks}) async {
    final payload = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (remarks != null && remarks.isNotEmpty) {
      payload['admin_remarks'] = remarks;
    }
    try {
      await _client
          .from('worker_verification_documents')
          .update(payload)
          .eq('id', documentId);
    } catch (_) {
      // Column may not exist in older schema — silently ignore
    }
  }

  @override
  Future<List<PaymentRecord>> getPayments() async {
    final response = await _client.from('payments').select('''
      id, booking_id, amount, status, escrow_status,
      payment_method, razorpay_order_id, razorpay_payment_id,
      created_at,
      customer:users!payments_customer_id_fkey(full_name),
      worker:workers!payments_worker_id_fkey(users(full_name))
    ''').order('created_at', ascending: false).limit(100);

    return (response as List).map((p) {
      final customerName =
          (p['customer'] as Map<String, dynamic>?)?['full_name'] as String? ?? 'Unknown';
      final workerData = p['worker'] as Map<String, dynamic>?;
      final workerName =
          (workerData?['users'] as Map<String, dynamic>?)?['full_name'] as String? ?? 'Unknown';

      final statusStr = (p['status'] as String?)?.toUpperCase() ?? 'PENDING';
      final status = switch (statusStr) {
        'PAID' => PaymentStatus.paid,
        'FAILED' => PaymentStatus.failed,
        'REFUNDED' => PaymentStatus.refunded,
        'CANCELLED' => PaymentStatus.cancelled,
        _ => PaymentStatus.pending,
      };

      final escrowStr = (p['escrow_status'] as String?) ?? 'not_funded';
      final escrow = switch (escrowStr) {
        'held' => EscrowStatus.held,
        'release_pending' => EscrowStatus.releasePending,
        'released' => EscrowStatus.released,
        'refund_pending' => EscrowStatus.refundPending,
        'refunded' => EscrowStatus.refunded,
        _ => EscrowStatus.notFunded,
      };

      return PaymentRecord(
        id: p['id'] as String,
        bookingId: p['booking_id'] as String,
        customerName: customerName,
        workerName: workerName,
        amount: (p['amount'] as num).toDouble(),
        status: status,
        escrowStatus: escrow,
        date: DateTime.parse(p['created_at'] as String),
        method: (p['payment_method'] as String?) ?? 'razorpay',
        razorpayOrderId: p['razorpay_order_id'] as String?,
        razorpayPaymentId: p['razorpay_payment_id'] as String?,
      );
    }).toList();
  }
}
