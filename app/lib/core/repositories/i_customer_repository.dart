import '../../features/customer/data/models/customer_models.dart';

abstract class ICustomerRepository {
  /// Fetch all active service categories
  Future<List<ServiceCategory>> getActiveServices();

  /// Fetch active, verified workers providing a specific service
  Future<List<Worker>> getEligibleWorkers(String serviceId);

  /// Create a booking and return the created booking ID
  Future<String?> createBooking({
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

  /// Get full detailed information for a specific booking
  Future<Map<String, dynamic>?> getBookingDetails(String bookingId);

  /// Cancel a booking if permitted by the state machine
  Future<bool> cancelBooking(String bookingId, {String? reason});

  /// Realtime stream watching the authenticated customer's booking list
  Stream<List<Map<String, dynamic>>> watchCustomerBookings();

  /// Realtime stream watching a specific booking's state changes
  Stream<Map<String, dynamic>?> watchBookingDetails(String bookingId);
}
