import 'i_payment_repository.dart';
import '../models/payment_models.dart';
import '../config/dependency_injection.dart';

/// Mock implementation for USE_MOCK_DATA=true.
class MockPaymentRepository implements IPaymentRepository {
  final Map<String, PaymentModel> _payments = {};
  bool simulateSuccess = true;

  @override
  Future<PaymentOrderResult> createPaymentOrder(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final orderId = 'order_mock_';
    const amountPaise = 50000;
    _payments[bookingId] = PaymentModel(
      id: 'pay_mock_',
      bookingId: bookingId,
      customerId: 'mock-customer-id',
      workerId: 'mock-worker-id',
      amount: 500.0,
      amountPaise: amountPaise,
      status: PaymentStatus.pending,
      escrowStatus: EscrowStatus.notFunded,
      razorpayOrderId: orderId,
      paymentMethod: 'razorpay',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return PaymentOrderResult(
      orderId: orderId,
      amountPaise: amountPaise,
      currency: 'INR',
      keyId: 'rzp_test_mock_key_id',
      bookingId: bookingId,
    );
  }

  @override
  Future<bool> verifyPayment({
    required String bookingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    if (!simulateSuccess) {
      _updateStatus(bookingId, PaymentStatus.failed, EscrowStatus.notFunded);
      return false;
    }
    final existing = _payments[bookingId];
    if (existing?.status == PaymentStatus.paid) return true;

    _payments[bookingId] = PaymentModel(
      id: existing?.id ?? 'pay_mock_',
      bookingId: bookingId,
      customerId: existing?.customerId ?? 'mock-customer-id',
      workerId: existing?.workerId,
      amount: existing?.amount ?? 500.0,
      amountPaise: existing?.amountPaise ?? 50000,
      status: PaymentStatus.paid,
      escrowStatus: EscrowStatus.held,
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
      paymentMethod: 'razorpay',
      createdAt: existing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return true;
  }

  @override
  Future<bool> releaseEscrow(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final payment = _payments[bookingId];
    if (payment == null || !payment.canReleaseEscrow) return false;
    _payments[bookingId] = PaymentModel(
      id: payment.id,
      bookingId: payment.bookingId,
      customerId: payment.customerId,
      workerId: payment.workerId,
      amount: payment.amount,
      amountPaise: payment.amountPaise,
      status: payment.status,
      escrowStatus: EscrowStatus.released,
      razorpayOrderId: payment.razorpayOrderId,
      razorpayPaymentId: payment.razorpayPaymentId,
      razorpaySignature: payment.razorpaySignature,
      paymentMethod: payment.paymentMethod,
      createdAt: payment.createdAt,
      updatedAt: DateTime.now(),
    );

    if (payment.workerId != null) {
      try {
        DI.notificationRepo.sendPushNotification(
          recipientUserId: payment.workerId!,
          type: 'payment_released',
          title: 'Payment Released!',
          body: 'Escrow payment of ₹${payment.amount.toStringAsFixed(0)} has been released to your cooperative wallet.',
          data: {'bookingId': bookingId, 'paymentId': payment.id},
        );
      } catch (_) {}
    }

    return true;
  }

  @override
  Future<PaymentModel?> getPaymentForBooking(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _payments[bookingId];
  }

  @override
  Future<List<PaymentModel>> getWorkerReleasedPayments(String workerId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return _payments.values
        .where((p) => p.workerId == workerId && p.escrowStatus == EscrowStatus.released)
        .toList();
  }

  void _updateStatus(String bookingId, PaymentStatus status, EscrowStatus escrow) {
    final p = _payments[bookingId];
    if (p == null) return;
    _payments[bookingId] = PaymentModel(
      id: p.id, bookingId: p.bookingId, customerId: p.customerId, workerId: p.workerId,
      amount: p.amount, amountPaise: p.amountPaise, status: status, escrowStatus: escrow,
      razorpayOrderId: p.razorpayOrderId, paymentMethod: p.paymentMethod,
      createdAt: p.createdAt, updatedAt: DateTime.now(),
    );
  }
}