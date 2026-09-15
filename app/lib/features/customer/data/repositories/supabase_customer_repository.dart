import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
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
                full_name,
                avatar_url
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
          rate: 350,
          rating: (wData['rating'] as num?)?.toDouble() ?? 4.0,
          reviewCount: 0,
          jobsCompleted: wData['jobs_completed'] ?? 0,
          distanceKm: 2.0,
          experience: '${wData['experience_years'] ?? 1} yrs exp',
          availability: 'Available',
          specializations: [],
          locationTag: 'Local Area',
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

      final bookingResult = await _client.from('bookings').insert({
        'customer_id': customerId,
        'worker_id': workerId,
        'service_id': serviceId,
        'address_id': finalAddressId,
        'scheduled_date': scheduledDate,
        'scheduled_time': scheduledTime,
        'base_amount': amount,
        'labor_allowance': 35.0,
        'distance_km': 2.1,
        'status': 'pending',
        'otp': randomOtp,
        'notes': notes ?? '',
      }).select('id').single();

      return bookingResult['id'] as String;
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
}
