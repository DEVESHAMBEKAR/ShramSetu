import 'booking_status.dart';

class UnifiedBooking {
  final String id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String? customerLocation;
  
  final String workerId;
  final String workerName;
  
  final String serviceId;
  final String serviceName;
  
  final String scheduledDate;
  final String scheduledTime;
  final String address;
  final String? distanceKm;
  
  final double baseAmount;
  final double laborAllowance;
  final BookingStatus status;
  final String createdAt;
  
  final String? otp;

  double get totalAmount => baseAmount + laborAllowance;

  UnifiedBooking({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.customerLocation,
    required this.workerId,
    required this.workerName,
    required this.serviceId,
    required this.serviceName,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.address,
    this.distanceKm,
    required this.baseAmount,
    this.laborAllowance = 0.0,
    required this.status,
    required this.createdAt,
    this.otp,
  });

  UnifiedBooking copyWith({
    String? id,
    String? customerId,
    String? customerName,
    String? customerPhone,
    String? customerLocation,
    String? workerId,
    String? workerName,
    String? serviceId,
    String? serviceName,
    String? scheduledDate,
    String? scheduledTime,
    String? address,
    String? distanceKm,
    double? baseAmount,
    double? laborAllowance,
    BookingStatus? status,
    String? createdAt,
    String? otp,
  }) {
    return UnifiedBooking(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerLocation: customerLocation ?? this.customerLocation,
      workerId: workerId ?? this.workerId,
      workerName: workerName ?? this.workerName,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      address: address ?? this.address,
      distanceKm: distanceKm ?? this.distanceKm,
      baseAmount: baseAmount ?? this.baseAmount,
      laborAllowance: laborAllowance ?? this.laborAllowance,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      otp: otp ?? this.otp,
    );
  }
}
