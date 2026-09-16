import '../models/payment_models.dart';

abstract class IPaymentRepository {
  /// Create a Razorpay order via Edge Function.
  /// Returns [PaymentOrderResult] with orderId, amount (paise), keyId.
  Future<PaymentOrderResult> createPaymentOrder(String bookingId);

  /// Verify payment server-side via Edge Function.
  /// Returns true if verified and escrow is now HELD.
  Future<bool> verifyPayment({
    required String bookingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  });

  /// Release escrow for a completed booking via Edge Function/RPC.
  Future<bool> releaseEscrow(String bookingId);

  /// Fetch the payment record for a booking (nullable if not yet created).
  Future<PaymentModel?> getPaymentForBooking(String bookingId);

  /// Fetch all released payments for a worker (earnings).
  Future<List<PaymentModel>> getWorkerReleasedPayments(String workerId);
}