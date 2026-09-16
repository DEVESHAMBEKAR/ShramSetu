import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/payment_models.dart';
import 'package:app/core/repositories/mock_payment_repository.dart';

void main() {
  // ─── PaymentStatus enum ───────────────────────────────────────────────────
  group('PaymentStatus', () {
    test('toDbString returns uppercase', () {
      expect(PaymentStatus.pending.toDbString(), 'PENDING');
      expect(PaymentStatus.paid.toDbString(), 'PAID');
      expect(PaymentStatus.failed.toDbString(), 'FAILED');
      expect(PaymentStatus.refunded.toDbString(), 'REFUNDED');
      expect(PaymentStatus.cancelled.toDbString(), 'CANCELLED');
    });

    test('fromDbString handles all values case-insensitively', () {
      expect(PaymentStatus.fromDbString('PAID'), PaymentStatus.paid);
      expect(PaymentStatus.fromDbString('paid'), PaymentStatus.paid);
      expect(PaymentStatus.fromDbString('FAILED'), PaymentStatus.failed);
      expect(PaymentStatus.fromDbString('REFUNDED'), PaymentStatus.refunded);
      expect(PaymentStatus.fromDbString('CANCELLED'), PaymentStatus.cancelled);
      expect(PaymentStatus.fromDbString('PENDING'), PaymentStatus.pending);
      expect(PaymentStatus.fromDbString(null), PaymentStatus.pending);
      expect(PaymentStatus.fromDbString('UNKNOWN'), PaymentStatus.pending);
    });
  });

  // ─── EscrowStatus enum ────────────────────────────────────────────────────
  group('EscrowStatus', () {
    test('toDbString maps correctly', () {
      expect(EscrowStatus.notFunded.toDbString(), 'not_funded');
      expect(EscrowStatus.held.toDbString(), 'held');
      expect(EscrowStatus.releasePending.toDbString(), 'release_pending');
      expect(EscrowStatus.released.toDbString(), 'released');
      expect(EscrowStatus.refundPending.toDbString(), 'refund_pending');
      expect(EscrowStatus.refunded.toDbString(), 'refunded');
    });

    test('fromDbString handles all values', () {
      expect(EscrowStatus.fromDbString('held'), EscrowStatus.held);
      expect(EscrowStatus.fromDbString('release_pending'), EscrowStatus.releasePending);
      expect(EscrowStatus.fromDbString('released'), EscrowStatus.released);
      expect(EscrowStatus.fromDbString('refund_pending'), EscrowStatus.refundPending);
      expect(EscrowStatus.fromDbString('refunded'), EscrowStatus.refunded);
      expect(EscrowStatus.fromDbString(null), EscrowStatus.notFunded);
      expect(EscrowStatus.fromDbString('not_funded'), EscrowStatus.notFunded);
    });
  });

  // ─── PaymentUtils ─────────────────────────────────────────────────────────
  group('PaymentUtils', () {
    test('amountToPaise converts correctly', () {
      expect(PaymentUtils.amountToPaise(500.0), 50000);
      expect(PaymentUtils.amountToPaise(1.0), 100);
      expect(PaymentUtils.amountToPaise(0.50), 50);
      expect(PaymentUtils.amountToPaise(999.99), 99999);
    });

    test('amountToPaise rejects non-positive amounts', () {
      expect(() => PaymentUtils.amountToPaise(0.0), throwsArgumentError);
      expect(() => PaymentUtils.amountToPaise(-10.0), throwsArgumentError);
    });

    test('paiseToAmount converts correctly', () {
      expect(PaymentUtils.paiseToAmount(50000), 500.0);
      expect(PaymentUtils.paiseToAmount(100), 1.0);
    });

    test('isValidAmount rejects boundary values', () {
      expect(PaymentUtils.isValidAmount(0), false);
      expect(PaymentUtils.isValidAmount(-1), false);
      expect(PaymentUtils.isValidAmount(1000000), false);
      expect(PaymentUtils.isValidAmount(500), true);
      expect(PaymentUtils.isValidAmount(0.01), true);
    });
  });

  // ─── PaymentModel.fromJson ────────────────────────────────────────────────
  group('PaymentModel', () {
    test('fromJson maps all fields correctly', () {
      final json = {
        'id': 'pay-123',
        'booking_id': 'book-456',
        'customer_id': 'cust-789',
        'worker_id': 'work-101',
        'amount': 500.0,
        'amount_paise': 50000,
        'status': 'PAID',
        'escrow_status': 'held',
        'razorpay_order_id': 'order_abc',
        'razorpay_payment_id': 'pay_xyz',
        'razorpay_signature': 'sig123',
        'payment_method': 'razorpay',
        'created_at': '2024-01-01T10:00:00Z',
        'updated_at': '2024-01-01T10:05:00Z',
      };
      final model = PaymentModel.fromJson(json);
      expect(model.id, 'pay-123');
      expect(model.status, PaymentStatus.paid);
      expect(model.escrowStatus, EscrowStatus.held);
      expect(model.amountPaise, 50000);
      expect(model.canReleaseEscrow, true);
    });

    test('canReleaseEscrow is false when not PAID+held', () {
      PaymentModel makeModel(PaymentStatus s, EscrowStatus e) => PaymentModel(
        id: 'x', bookingId: 'b', customerId: 'c', amount: 500, amountPaise: 50000,
        status: s, escrowStatus: e, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      expect(makeModel(PaymentStatus.pending, EscrowStatus.notFunded).canReleaseEscrow, false);
      expect(makeModel(PaymentStatus.paid, EscrowStatus.released).canReleaseEscrow, false);
      expect(makeModel(PaymentStatus.failed, EscrowStatus.held).canReleaseEscrow, false);
    });
  });

  // ─── MockPaymentRepository ────────────────────────────────────────────────
  group('MockPaymentRepository', () {
    late MockPaymentRepository repo;

    setUp(() {
      repo = MockPaymentRepository();
      repo.simulateSuccess = true;
    });

    test('createPaymentOrder returns valid order result', () async {
      final result = await repo.createPaymentOrder('booking-001');
      expect(result.orderId, startsWith('order_mock_'));
      expect(result.amountPaise, greaterThan(0));
      expect(result.currency, 'INR');
      expect(result.keyId, isNotEmpty);
    });

    test('verifyPayment returns true on success', () async {
      await repo.createPaymentOrder('booking-001');
      final verified = await repo.verifyPayment(
        bookingId: 'booking-001',
        razorpayOrderId: 'order_abc',
        razorpayPaymentId: 'pay_xyz',
        razorpaySignature: 'valid_sig',
      );
      expect(verified, true);
    });

    test('verifyPayment returns false on simulated failure', () async {
      repo.simulateSuccess = false;
      await repo.createPaymentOrder('booking-002');
      final verified = await repo.verifyPayment(
        bookingId: 'booking-002',
        razorpayOrderId: 'order_abc',
        razorpayPaymentId: 'pay_xyz',
        razorpaySignature: 'invalid_sig',
      );
      expect(verified, false);
    });

    test('verifyPayment is idempotent — second call returns true without re-updating', () async {
      await repo.createPaymentOrder('booking-003');
      await repo.verifyPayment(
        bookingId: 'booking-003',
        razorpayOrderId: 'order_abc',
        razorpayPaymentId: 'pay_xyz',
        razorpaySignature: 'sig',
      );
      // Call again with same IDs
      final secondCall = await repo.verifyPayment(
        bookingId: 'booking-003',
        razorpayOrderId: 'order_abc',
        razorpayPaymentId: 'pay_xyz',
        razorpaySignature: 'sig',
      );
      expect(secondCall, true);
    });

    test('releaseEscrow succeeds after paid+held state', () async {
      await repo.createPaymentOrder('booking-004');
      await repo.verifyPayment(
        bookingId: 'booking-004',
        razorpayOrderId: 'order_abc',
        razorpayPaymentId: 'pay_xyz',
        razorpaySignature: 'sig',
      );
      final released = await repo.releaseEscrow('booking-004');
      expect(released, true);

      final payment = await repo.getPaymentForBooking('booking-004');
      expect(payment?.escrowStatus, EscrowStatus.released);
      expect(payment?.isEscrowReleased, true);
    });

    test('releaseEscrow fails if not in held state', () async {
      await repo.createPaymentOrder('booking-005');
      // Do NOT verify — escrow is still notFunded
      final released = await repo.releaseEscrow('booking-005');
      expect(released, false);
    });

    test('releaseEscrow cannot be called twice', () async {
      await repo.createPaymentOrder('booking-006');
      await repo.verifyPayment(bookingId: 'booking-006', razorpayOrderId: 'o', razorpayPaymentId: 'p', razorpaySignature: 's');
      await repo.releaseEscrow('booking-006');
      // Second release should fail
      final secondRelease = await repo.releaseEscrow('booking-006');
      expect(secondRelease, false);
    });

    test('getPaymentForBooking returns null for unknown booking', () async {
      final payment = await repo.getPaymentForBooking('nonexistent');
      expect(payment, isNull);
    });

    test('getWorkerReleasedPayments returns only released payments', () async {
      final r = MockPaymentRepository();
      r.simulateSuccess = true;
      await r.createPaymentOrder('b1');
      await r.verifyPayment(bookingId: 'b1', razorpayOrderId: 'o1', razorpayPaymentId: 'p1', razorpaySignature: 's1');
      await r.releaseEscrow('b1');

      await r.createPaymentOrder('b2');
      // b2 not released

      final released = await r.getWorkerReleasedPayments('mock-worker-id');
      expect(released.length, 1);
      expect(released.first.bookingId, 'b1');
    });
  });
}
