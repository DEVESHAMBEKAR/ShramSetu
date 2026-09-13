import 'package:supabase_flutter/supabase_flutter.dart' ;
import '../../../../core/repositories/i_customer_repository.dart';
import '../models/customer_models.dart';

class SupabaseCustomerRepository implements ICustomerRepository {
  final SupabaseClient _client;

  SupabaseCustomerRepository(this._client);

  @override
  Future<List<ServiceCategory>> getActiveServices() async {
    try {
      final response = await _client
          .from('services')
          .select()
          .eq('is_active', true)
          .order('name');
          
      return (response as List).map((row) => ServiceCategory(
        id: row['id'].toString(),
        name: row['name'],
        iconData: row['icon_name'] ?? 'build',
      )).toList();
    } catch (e) {
      throw Exception('Failed to load services: $e');
    }
  }

  @override
  Future<List<Worker>> getEligibleWorkers(String serviceId) async {
    try {
      // 1. Get all workers who have this skill (serviceId maps directly to skills for this baseline)
      // Note: A more complex match would query worker_skills -> skills -> services
      // Assuming 'skills.id' is what 'serviceId' aligns with in the mock structure.
      final response = await _client
          .from('worker_skills')
          .select('''
            worker_id,
            workers!inner (
              rating,
              jobs_completed,
              is_available,
              verification_status,
              experience_years,
              bio,
              users!inner (
                full_name
              )
            )
          ''')
          .eq('skill_id', serviceId)
          .eq('workers.is_available', true)
          .eq('workers.verification_status', 'APPROVED');

      final List<Worker> results = [];
      for (final row in response) {
        final wData = row['workers'];
        final uData = wData['users'];
        results.add(Worker(
          id: row['worker_id'],
          name: uData['full_name'] ?? 'Worker',
          categoryId: serviceId,
          rate: 350, // Baseline mock rate, real pricing follows in a later stage
          rating: (wData['rating'] as num?)?.toDouble() ?? 4.0,
          reviewCount: 0,
          jobsCompleted: wData['jobs_completed'] ?? 0,
          distanceKm: 2.0, // Mock distance
          experience: '${wData['experience_years'] ?? 1} yrs exp',
          availability: 'Available',
          specializations: [],
          locationTag: 'Local Area',
          imageUrl: '',
          bio: wData['bio'],
        ));
      }

      // Sorting Baseline: Sort by rating descending
      results.sort((a, b) => b.rating.compareTo(a.rating));
      return results;
    } catch (e) {
      throw Exception('Failed to discover workers: $e');
    }
  }

  @override
  Future<bool> createBooking({
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
        final addrResponse = await _client.from('addresses').select('id').eq('user_id', customerId).limit(1).maybeSingle();
        if (addrResponse == null) {
          // Create dummy address for now
          final newAddr = await _client.from('addresses').insert({
            'user_id': customerId,
            'address_line1': 'Default Customer Address',
            'city': 'Pune',
            'state': 'MH',
            'pincode': '411001'
          }).select('id').single();
          finalAddressId = newAddr['id'];
        } else {
          finalAddressId = addrResponse['id'];
        }
      }

      await _client.from('bookings').insert({
        'customer_id': customerId,
        'worker_id': workerId,
        'service_id': serviceId,
        'address_id': finalAddressId,
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
        'amount': amount,
        'status': 'pending',
        'notes': notes ?? '',
      });

      return true;
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCustomerBookings() async {
    final customerId = _client.auth.currentUser?.id;
    if (customerId == null) return [];
    
    try {
      return await _client
          .from('bookings')
          .select('''
            id,
            status,
            scheduled_date,
            scheduled_time,
            amount,
            services (name),
            workers (users (full_name))
          ''')
          .eq('customer_id', customerId)
          .order('scheduled_date', ascending: false);
    } catch (e) {
      return [];
    }
  }
}
