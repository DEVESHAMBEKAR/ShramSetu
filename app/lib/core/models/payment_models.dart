/// Payment models for ShramSetu Phase 19 — Razorpay + Escrow
library;

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
  cancelled;

  String toDbString() => name.toUpperCase();

  static PaymentStatus fromDbString(String? val) {
    if (val == null) return PaymentStatus.pending;
    switch (val.trim().toUpperCase()) {
      case 'PAID':      return PaymentStatus.paid;
      case 'FAILED':    return PaymentStatus.failed;
      case 'REFUNDED':  return PaymentStatus.refunded;
      case 'CANCELLED': return PaymentStatus.cancelled;
      default:          return PaymentStatus.pending;
    }
  }

  String get displayLabel {
    switch (this) {
      case PaymentStatus.pending:   return 'Pending';
      case PaymentStatus.paid:      return 'Paid';
      case PaymentStatus.failed:    return 'Failed';
      case PaymentStatus.refunded:  return 'Refunded';
      case PaymentStatus.cancelled: return 'Cancelled';
    }
  }
}

enum EscrowStatus {
  notFunded,
  held,
  releasePending,
  released,
  refundPending,
  refunded;

  String toDbString() {
    switch (this) {
      case EscrowStatus.notFunded:      return 'not_funded';
      case EscrowStatus.held:           return 'held';
      case EscrowStatus.releasePending: return 'release_pending';
      case EscrowStatus.released:       return 'released';
      case EscrowStatus.refundPending:  return 'refund_pending';
      case EscrowStatus.refunded:       return 'refunded';
    }
  }

  static EscrowStatus fromDbString(String? val) {
    if (val == null) return EscrowStatus.notFunded;
    switch (val.trim().toLowerCase()) {
      case 'held':             return EscrowStatus.held;
      case 'release_pending':  return EscrowStatus.releasePending;
      case 'released':         return EscrowStatus.released;
      case 'refund_pending':   return EscrowStatus.refundPending;
      case 'refunded':         return EscrowStatus.refunded;
      default:                 return EscrowStatus.notFunded;
    }
  }

  String get displayLabel {
    switch (this) {
      case EscrowStatus.notFunded:      return 'Not Funded';
      case EscrowStatus.held:           return 'Held in Escrow';
      case EscrowStatus.releasePending: return 'Release Pending';
      case EscrowStatus.released:       return 'Released';
      case EscrowStatus.refundPending:  return 'Refund Pending';
      case EscrowStatus.refunded:       return 'Refunded';
    }
  }
}

class PaymentModel {
  final String id;
  final String bookingId;
  final String customerId;
  final String? workerId;
  final double amount;
  final int amountPaise;
  final PaymentStatus status;
  final EscrowStatus escrowStatus;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final String? paymentMethod;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentModel({
    required this.id,
    required this.bookingId,
    required this.customerId,
    this.workerId,
    required this.amount,
    required this.amountPaise,
    required this.status,
    required this.escrowStatus,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    this.paymentMethod,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final amt = (json['amount'] as num).toDouble();
    return PaymentModel(
      id: json['id'] as String,
      bookingId: json['booking_id'] as String,
      customerId: json['customer_id'] as String,
      workerId: json['worker_id'] as String?,
      amount: amt,
      amountPaise: (json['amount_paise'] as int?) ?? PaymentUtils.amountToPaise(amt),
      status: PaymentStatus.fromDbString(json['status'] as String?),
      escrowStatus: EscrowStatus.fromDbString(json['escrow_status'] as String?),
      razorpayOrderId: json['razorpay_order_id'] as String?,
      razorpayPaymentId: json['razorpay_payment_id'] as String?,
      razorpaySignature: json['razorpay_signature'] as String?,
      paymentMethod: json['payment_method'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get canReleaseEscrow =>
      status == PaymentStatus.paid && escrowStatus == EscrowStatus.held;

  bool get isEscrowReleased => escrowStatus == EscrowStatus.released;
}

class PaymentOrderResult {
  final String orderId;
  final int amountPaise;
  final String currency;
  final String keyId;
  final String bookingId;

  const PaymentOrderResult({
    required this.orderId,
    required this.amountPaise,
    required this.currency,
    required this.keyId,
    required this.bookingId,
  });

  factory PaymentOrderResult.fromJson(Map<String, dynamic> json) {
    return PaymentOrderResult(
      orderId: json['orderId'] as String,
      amountPaise: json['amount'] as int,
      currency: (json['currency'] as String?) ?? 'INR',
      keyId: json['keyId'] as String,
      bookingId: json['bookingId'] as String,
    );
  }
}

class PaymentUtils {
  static int amountToPaise(double amountRupees) {
    if (amountRupees <= 0) {
      throw ArgumentError('Payment amount must be positive: $amountRupees');
    }
    return (amountRupees * 100).round();
  }

  static double paiseToAmount(int paise) => paise / 100.0;

  static bool isValidAmount(double amount) => amount > 0 && amount < 1000000;
}