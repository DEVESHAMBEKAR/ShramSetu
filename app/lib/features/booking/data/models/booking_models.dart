export '../../../../core/models/booking_status.dart';
import '../../../customer/data/models/customer_models.dart';
import '../../../../core/models/booking_status.dart';

class Booking {
  final String id;
  final String customerId;
  final String workerId;
  final String serviceId;
  final String serviceName;
  final String workerName;
  final String scheduledDate;
  final String scheduledTime;
  final String address;
  final double amount;
  final BookingStatus status;

  Booking({
    required this.id,
    required this.customerId,
    required this.workerId,
    required this.serviceId,
    required this.serviceName,
    required this.workerName,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.address,
    required this.amount,
    this.status = BookingStatus.pending,
  });
}

class BookingFlowState {
  ServiceCategory? selectedCategory;
  Worker? selectedWorker;
  String? selectedDate;
  String? selectedTime;
  String? address;
  String? addressId;
  double? latitude;
  double? longitude;

  BookingFlowState({
    this.selectedCategory,
    this.selectedWorker,
    this.selectedDate,
    this.selectedTime,
    this.address = 'Flat 402, Sai Shraddha Apts, Ideal Colony, Kothrud, Pune - 411038',
    this.addressId,
    this.latitude,
    this.longitude,
  });
}

// Global mutable state for demo purposes (to pass between screens easily without Provider)
final bookingFlowState = BookingFlowState();

