
enum PaymentStatus { pending, paid, refunded, failed, cancelled }
enum EscrowStatus { notFunded, held, releasePending, released, refundPending, refunded }
enum ComplaintStatus { open, inReview, resolved, closed }
enum ServiceStatus { active, inactive }

class PaymentRecord {
  final String id;
  final String bookingId;
  final String customerName;
  final String workerName;
  final double amount;
  final PaymentStatus status;
  final EscrowStatus escrowStatus;
  final DateTime date;
  final String method;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;

  PaymentRecord({
    required this.id,
    required this.bookingId,
    required this.customerName,
    required this.workerName,
    required this.amount,
    required this.status,
    this.escrowStatus = EscrowStatus.notFunded,
    required this.date,
    required this.method,
    this.razorpayOrderId,
    this.razorpayPaymentId,
  });
}

class Complaint {
  final String id;
  final String customerName;
  final String workerName;
  final String bookingId;
  final String subject;
  final String description;
  final DateTime date;
  final String priority; // 'High', 'Medium', 'Low'
  final ComplaintStatus status;

  Complaint({
    required this.id,
    required this.customerName,
    required this.workerName,
    required this.bookingId,
    required this.subject,
    required this.description,
    required this.date,
    required this.priority,
    required this.status,
  });
}

class WelfareRecord {
  final String id;
  final String title;
  final String details;
  final String type;
  final String status;

  WelfareRecord({
    required this.id,
    required this.title,
    required this.details,
    required this.type,
    required this.status,
  });
}

class AdminDashboardStats {
  final int totalWorkers;
  final int verifiedWorkers;
  final int pendingVerifications;
  final int activeBookings;
  final double escrowLocked;
  final double welfarePool;
  final double fairWorkIndex;

  AdminDashboardStats({
    required this.totalWorkers,
    required this.verifiedWorkers,
    required this.pendingVerifications,
    required this.activeBookings,
    required this.escrowLocked,
    required this.welfarePool,
    required this.fairWorkIndex,
  });
}

class AdminCustomerProfile {
  final String id;
  final String name;
  final String phone;
  final int totalBookings;
  final DateTime lastBooking;
  final String status;

  AdminCustomerProfile({
    required this.id,
    required this.name,
    required this.phone,
    required this.totalBookings,
    required this.lastBooking,
    required this.status,
  });
}

class AdminService {
  final String id;
  final String name;
  final String icon;
  final ServiceStatus status;

  AdminService({
    required this.id,
    required this.name,
    required this.icon,
    required this.status,
  });
}
