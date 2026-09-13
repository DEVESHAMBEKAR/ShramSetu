import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/repositories/i_worker_repository.dart';
import '../models/worker_models.dart';

class SupabaseWorkerRepository implements IWorkerRepository {
  final SupabaseClient _supabase;

  SupabaseWorkerRepository(this._supabase);

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
      experience: '\ Years',
      rating: (workerRes['rating'] as num?)?.toDouble() ?? 5.0,
      completedJobs: workerRes['completed_jobs'] ?? 0,
      earnings: 0.0,
      isVerified: verificationStatus == VerificationStatus.approved,
      verificationStatus: verificationStatus,
      isAvailable: workerRes['is_available'] ?? false,
      serviceLocation: 'Pune, Maharashtra',
      guildName: 'ShramSetu Cooperative',
      guildId: '#',
    );
  }

  @override
  Future<void> updateAvailability(bool isAvailable) async {
    final userId = _supabase.auth.currentUser!.id;
    await _supabase.from('workers').update({'is_available': isAvailable}).eq('id', userId);
  }

  @override
  Future<List<JobRequest>> getWorkerBookings() async {
    final userId = _supabase.auth.currentUser!.id;
    final res = await _supabase
        .from('bookings')
        .select('*, users!customer_id(full_name, phone), services!service_id(name)')
        .eq('worker_id', userId)
        .order('created_at', ascending: false);

    return (res as List).map((row) {
      final user = row['users'] as Map<String, dynamic>? ?? {};
      final service = row['services'] as Map<String, dynamic>? ?? {};
      
      BookingStatus status;
      try {
        status = BookingStatus.values.byName((row['status'] as String).toLowerCase());
      } catch (_) {
        status = BookingStatus.pending;
      }
      
      return JobRequest(
        id: row['id'].toString(),
        customerId: row['customer_id'] ?? '',
        customerName: user['full_name'] ?? 'Unknown Customer',
        customerLocation: 'Pune',
        customerPhone: user['phone'] ?? '',
        serviceName: service['name'] ?? 'General Service',
        date: row['scheduled_date'] ?? 'Today',
        time: row['scheduled_time'] ?? 'Now',
        baseAmount: (row['amount'] as num?)?.toDouble() ?? 0.0,
        laborAllowance: 0.0,
        status: status,
        distanceKm: '2.0 km',
        createdAt: row['created_at'] != null 
            ? _formatTimeAgo(DateTime.parse(row['created_at']))
            : 'Just now',
      );
    }).toList();
  }

  @override
  Future<void> updateBookingStatus(String bookingId, BookingStatus newStatus) async {
    await _supabase.from('bookings').update({'status': newStatus.name.toUpperCase()}).eq('id', bookingId);
  }
  
  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '\m ago';
    if (diff.inHours < 24) return '\h ago';
    return '\d ago';
  }
}