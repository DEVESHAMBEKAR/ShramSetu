import '../../features/customer/data/models/customer_models.dart';

abstract class ICustomerRepository {
  /// Fetch all active service categories
  Future<List<ServiceCategory>> getActiveServices();

  /// Fetch active, verified workers providing a specific service
  Future<List<Worker>> getEligibleWorkers(String serviceId);

  /// Create a booking
  Future<bool> createBooking({
    required String workerId,
    required String serviceId,
    required String scheduledDate,
    required String scheduledTime,
    required double amount,
    String? addressId,
    String? notes,
  });

  /// Get the authenticated customer's booking history
  Future<List<Map<String, dynamic>>> getCustomerBookings();
}
