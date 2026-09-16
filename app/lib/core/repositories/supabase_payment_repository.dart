import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'i_payment_repository.dart';
import '../models/payment_models.dart';
import '../config/dependency_injection.dart';

class SupabasePaymentRepository implements IPaymentRepository {
  final SupabaseClient _client;

  SupabasePaymentRepository(this._client);

  @override
  Future<PaymentOrderResult> createPaymentOrder(String bookingId) async {
    final response = await _client.functions.invoke(
      'create-payment-order',
      body: {'bookingId': bookingId},
    );
    if (response.status != 200 && response.status != 201) {
      final err = (response.data is Map) ? response.data['error'] : response.data;
      throw Exception('Failed to create payment order: $err');
    }
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : jsonDecode(response.data.toString()) as Map<String, dynamic>;
    return PaymentOrderResult.fromJson(data);
  }

  @override
  Future<bool> verifyPayment({
    required String bookingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final response = await _client.functions.invoke(
      'verify-payment',
      body: {
        'bookingId': bookingId,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      },
    );
    if (response.status != 200) return false;
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : jsonDecode(response.data.toString()) as Map<String, dynamic>;
    return (data['success'] as bool?) ?? false;
  }

  @override
  Future<bool> releaseEscrow(String bookingId) async {
    final response = await _client.functions.invoke(
      'release-escrow',
      body: {'bookingId': bookingId},
    );
    if (response.status != 200) return false;
    final data = response.data is Map<String, dynamic>
        ? response.data as Map<String, dynamic>
        : jsonDecode(response.data.toString()) as Map<String, dynamic>;
    final success = (data['success'] as bool?) ?? false;

    if (success) {
      try {
        final payment = await getPaymentForBooking(bookingId);
        if (payment != null && payment.workerId != null) {
          DI.notificationRepo.sendPushNotification(
            recipientUserId: payment.workerId!,
            type: 'payment_released',
            title: 'Payment Released!',
            body: 'Escrow payment of ₹${payment.amount.toStringAsFixed(0)} has been released to your cooperative wallet.',
            data: {'bookingId': bookingId, 'paymentId': payment.id},
          );
        }
      } catch (_) {}
    }

    return success;
  }

  @override
  Future<PaymentModel?> getPaymentForBooking(String bookingId) async {
    final res = await _client
        .from('payments')
        .select()
        .eq('booking_id', bookingId)
        .maybeSingle();
    if (res == null) return null;
    return PaymentModel.fromJson(res);
  }

  @override
  Future<List<PaymentModel>> getWorkerReleasedPayments(String workerId) async {
    final res = await _client
        .from('payments')
        .select()
        .eq('worker_id', workerId)
        .eq('escrow_status', 'released')
        .order('updated_at', ascending: false);
    return (res as List)
        .map((r) => PaymentModel.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}