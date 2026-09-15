import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/i_admin_repository.dart';
import '../models/admin_models.dart';
import '../../../worker/data/models/worker_models.dart';
import '../../../../core/models/booking_status.dart';

class SupabaseAdminRepository implements IAdminRepository {
  final SupabaseClient _client;

  SupabaseAdminRepository(this._client);

  @override
  Future<AdminDashboardStats> getDashboardStats() async {
    final totalWorkersRes = await _client.from('workers').select('id').count(CountOption.exact);
    final verifiedWorkersRes = await _client.from('workers').select('id').eq('worker_status', 'ACTIVE').count(CountOption.exact);
    final pendingRes = await _client.from('workers').select('id').eq('worker_status', 'PENDING_VERIFICATION').count(CountOption.exact);
    final activeBookingsRes = await _client.from('bookings').select('id').inFilter('status', ['pending', 'accepted', 'inProgress']).count(CountOption.exact);

    return AdminDashboardStats(
      totalWorkers: totalWorkersRes.count ?? 0,
      verifiedWorkers: verifiedWorkersRes.count ?? 0,
      pendingVerifications: pendingRes.count ?? 0,
      activeBookings: activeBookingsRes.count ?? 0,
      escrowLocked: 0.0,
      welfarePool: 0.0,
      fairWorkIndex: 98.5,
    );
  }

  @override
  Future<List<WorkerProfile>> getWorkers() async {
    final response = await _client.from('workers').select('''
      id, bio, experience_years, rating, completed_jobs, is_available, worker_status, location_tag,
      users!inner(full_name, phone)
    ''').order('created_at', ascending: false).limit(100);

    return (response as List).map((json) {
      final uData = json['users'] ?? {};
      return WorkerProfile(
        id: json['id'],
        name: uData['full_name'] ?? 'Unknown',
        phone: uData['phone'] ?? 'Unknown',
        skills: ['General Services'],
        experience: '${json['experience_years'] ?? 0} Years',
        rating: (json['rating'] ?? 0).toDouble(),
        completedJobs: json['completed_jobs'] ?? 0,
        isVerified: json['worker_status'] == 'ACTIVE',
        isAvailable: json['is_available'] ?? false,
        verificationStatus: _mapVerificationStatus(json['worker_status']),
        earnings: 0.0,
        profileImage: 'assets/images/workers/default.jpg',
        guildId: 'None',
        guildName: 'None',
        serviceLocation: json['location_tag'] ?? 'Local',
      );
    }).toList();
  }

  @override
  Future<void> approveWorker(String workerId) async {
    final current = await _client.from('workers').select('worker_status').eq('id', workerId).single();
    if (current['worker_status'] == 'PENDING_VERIFICATION') {
      await _client.from('workers').update({'worker_status': 'ACTIVE'}).eq('id', workerId);
    }
  }

  @override
  Future<void> rejectWorker(String workerId) async {
    await _client.from('workers').update({'worker_status': 'REJECTED'}).eq('id', workerId);
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
        status: _mapBookingStatus(b['status']),
        distanceKm: '0.0 km',
        createdAt: b['created_at'] ?? '',
      );
    }).toList();
  }

  @override
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    String strStatus = 'pending';
    switch (newStatus) {
      case BookingStatus.pending: strStatus = 'pending'; break;
      case BookingStatus.accepted: strStatus = 'accepted'; break;
      case BookingStatus.onTheWay: strStatus = 'onTheWay'; break;
      case BookingStatus.inProgress: strStatus = 'inProgress'; break;
      case BookingStatus.completed: strStatus = 'completed'; break;
      case BookingStatus.cancelled: strStatus = 'cancelled'; break;
      default: strStatus = 'pending'; break;
    }
    await _client.from('bookings').update({'status': strStatus}).eq('id', bookingId);
  }

  @override
  Future<List<PaymentRecord>> getPayments() async {
    final response = await _client.from('payments').select('''
      id, booking_id, amount, status, payment_method, created_at,
      bookings(id),
      users!customer_id(full_name)
    ''').order('created_at', ascending: false).limit(100);
    
    return (response as List).map((p) {
      final cData = p['users'] ?? {};
      return PaymentRecord(
        id: p['id'].toString(),
        bookingId: p['booking_id'] ?? '',
        customerName: cData['full_name'] ?? 'Unknown',
        workerName: 'Worker', 
        amount: (p['amount'] ?? 0).toDouble(),
        date: p['created_at'] != null ? DateTime.parse(p['created_at']) : DateTime.now(),
        status: p['status'] == 'PAID' ? PaymentStatus.paid : PaymentStatus.pending,
        method: p['payment_method'] ?? 'Transfer',
      );
    }).toList();
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

  VerificationStatus _mapVerificationStatus(String? status) {
    switch (status) {
      case 'ACTIVE': return VerificationStatus.approved;
      case 'REJECTED': return VerificationStatus.rejected;
      default: return VerificationStatus.pending;
    }
  }

  BookingStatus _mapBookingStatus(String? status) {
    switch (status) {
      case 'accepted': return BookingStatus.accepted;
      case 'onTheWay': return BookingStatus.onTheWay;
      case 'inProgress': return BookingStatus.inProgress;
      case 'completed': return BookingStatus.completed;
      case 'cancelled': return BookingStatus.cancelled;
      default: return BookingStatus.pending;
    }
  }

  @override
  Future<void> suspendWorker(String workerId) async {
    await _client
        .from('workers')
        .update({'worker_status': 'SUSPENDED'})
        .eq('id', workerId);
  }

  @override
  Future<List<Map<String, dynamic>>> getWorkerDocuments(String workerId) async {
    return await _client
        .from('worker_verification_documents')
        .select()
        .eq('worker_id', workerId)
        .order('created_at');
  }
}
