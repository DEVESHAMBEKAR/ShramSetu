/// Typed Digital Invoice model for ShramSetu.
/// Generated for bookings and payments in compliance with cooperative marketplace standards.
library;

class InvoiceModel {
  final String invoiceId;
  final String bookingId;
  final String customerName;
  final String? customerPhone;
  final String workerName;
  final String? workerTrade;
  final String? federationName;
  final String? federationRegNo;
  final String serviceName;
  final String serviceLocation;
  final String scheduledDate;
  final String scheduledTime;
  final double baseAmount;
  final double cessAmount;
  final double gstAmount;
  final double totalAmount;
  final String paymentStatus;
  final String? paymentMethod;
  final String? transactionRef;
  final DateTime issuedAt;

  const InvoiceModel({
    required this.invoiceId,
    required this.bookingId,
    required this.customerName,
    this.customerPhone,
    required this.workerName,
    this.workerTrade,
    this.federationName = 'Labour Cooperative Federation',
    this.federationRegNo,
    required this.serviceName,
    required this.serviceLocation,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.baseAmount,
    required this.cessAmount,
    required this.gstAmount,
    required this.totalAmount,
    required this.paymentStatus,
    this.paymentMethod = 'UPI / Escrow',
    this.transactionRef,
    required this.issuedAt,
  });

  String get invoiceNumber => invoiceId;
  DateTime get issueDate => issuedAt;
  String get serviceAddress => serviceLocation;
  String get artisanName => workerName;
  String get tradeName => workerTrade ?? serviceName;
  double get welfareCessAmount => cessAmount;
  String get paymentMode => paymentMethod ?? 'UPI / Union Escrow';
  String? get razorpayPaymentId => transactionRef;
  String get escrowStatus => isPaid ? 'Secured in Federation Escrow' : 'Payment Pending';
  String? get federationRegNumber => federationRegNo;
  bool get isPaid => paymentStatus.toUpperCase() == 'PAID' || paymentStatus.toUpperCase() == 'COMPLETED';

  factory InvoiceModel.fromBooking(
    Map<String, dynamic> booking, {
    Map<String, dynamic>? worker,
    Map<String, dynamic>? customer,
    Map<String, dynamic>? payment,
  }) {
    final effectiveBooking = Map<String, dynamic>.from(booking);
    if (worker != null) effectiveBooking['worker'] = worker;
    if (customer != null) effectiveBooking['customer'] = customer;
    return InvoiceModel.fromBookingAndPayment(
      booking: effectiveBooking,
      payment: payment,
    );
  }

  factory InvoiceModel.fromBookingAndPayment({
    required Map<String, dynamic> booking,
    Map<String, dynamic>? payment,
  }) {
    final bookingId = (booking['id'] ?? '').toString();
    final cleanId = bookingId.length > 8 ? bookingId.substring(0, 8).toUpperCase() : bookingId.toUpperCase();
    final invoiceId = 'INV-${DateTime.now().year}-$cleanId';

    final total = (booking['base_amount'] as num?)?.toDouble() ?? 399.0;
    // Transparent pricing breakdown: base + 3% union cess + 18% GST = total
    final base = (total / 1.21);
    final cess = base * 0.03;
    final gst = base * 0.18;

    final customer = booking['customer'] as Map<String, dynamic>? ?? {};
    final worker = booking['worker'] as Map<String, dynamic>? ?? {};
    final address = booking['address'] as Map<String, dynamic>? ?? {};

    final addrLine = (address['address_line'] as String?) ?? '';
    final area = (address['area'] as String?) ?? '';
    final city = (address['city'] as String?) ?? (booking['district'] as String?) ?? 'Pune';
    final location = [if (addrLine.isNotEmpty) addrLine, if (area.isNotEmpty) area, city].join(', ');

    return InvoiceModel(
      invoiceId: invoiceId,
      bookingId: bookingId,
      customerName: (customer['full_name'] as String?) ?? 'Valued Customer',
      customerPhone: customer['phone'] as String?,
      workerName: (worker['name'] ?? worker['full_name'] ?? 'Certified Union Artisan').toString(),
      workerTrade: (worker['trade'] ?? worker['primary_skill'] ?? 'Specialist Artisan').toString(),
      federationName: (worker['federation_name'] as String?) ?? 'Pune District Labour Cooperative Federation',
      federationRegNo: (worker['federation_reg_no'] as String?) ?? 'MH-COOP-VERIFIED',
      serviceName: (booking['service_name'] as String?) ?? 'Home Maintenance Service',
      serviceLocation: location.isNotEmpty ? location : 'Service Address, Maharashtra',
      scheduledDate: (booking['scheduled_date'] ?? 'Today').toString(),
      scheduledTime: (booking['scheduled_time'] ?? '10:00 AM').toString(),
      baseAmount: double.parse(base.toStringAsFixed(2)),
      cessAmount: double.parse(cess.toStringAsFixed(2)),
      gstAmount: double.parse(gst.toStringAsFixed(2)),
      totalAmount: double.parse(total.toStringAsFixed(2)),
      paymentStatus: (payment?['status'] as String?)?.toUpperCase() ?? 'PAID',
      paymentMethod: (payment?['payment_method'] as String?) ?? 'UPI / Union Escrow',
      transactionRef: (payment?['transaction_reference'] ?? payment?['razorpay_payment_id'] ?? 'TXN-$cleanId').toString(),
      issuedAt: DateTime.now(),
    );
  }

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    return InvoiceModel(
      invoiceId: json['invoice_id'] as String? ?? 'INV-00000',
      bookingId: json['booking_id'] as String? ?? '',
      customerName: json['customer_name'] as String? ?? 'Customer',
      customerPhone: json['customer_phone'] as String?,
      workerName: json['worker_name'] as String? ?? 'Worker',
      workerTrade: json['worker_trade'] as String?,
      federationName: json['federation_name'] as String?,
      federationRegNo: json['federation_reg_no'] as String?,
      serviceName: json['service_name'] as String? ?? 'Service',
      serviceLocation: json['service_location'] as String? ?? '',
      scheduledDate: json['scheduled_date'] as String? ?? '',
      scheduledTime: json['scheduled_time'] as String? ?? '',
      baseAmount: (json['base_amount'] as num?)?.toDouble() ?? 0.0,
      cessAmount: (json['cess_amount'] as num?)?.toDouble() ?? 0.0,
      gstAmount: (json['gst_amount'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['payment_status'] as String? ?? 'PAID',
      paymentMethod: json['payment_method'] as String?,
      transactionRef: json['transaction_ref'] as String?,
      issuedAt: DateTime.tryParse(json['issued_at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'invoice_id': invoiceId,
    'booking_id': bookingId,
    'customer_name': customerName,
    if (customerPhone != null) 'customer_phone': customerPhone,
    'worker_name': workerName,
    if (workerTrade != null) 'worker_trade': workerTrade,
    if (federationName != null) 'federation_name': federationName,
    if (federationRegNo != null) 'federation_reg_no': federationRegNo,
    'service_name': serviceName,
    'service_location': serviceLocation,
    'scheduled_date': scheduledDate,
    'scheduled_time': scheduledTime,
    'base_amount': baseAmount,
    'cess_amount': cessAmount,
    'gst_amount': gstAmount,
    'total_amount': totalAmount,
    'payment_status': paymentStatus,
    if (paymentMethod != null) 'payment_method': paymentMethod,
    if (transactionRef != null) 'transaction_ref': transactionRef,
    'issued_at': issuedAt.toIso8601String(),
  };
}
