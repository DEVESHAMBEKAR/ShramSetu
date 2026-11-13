import '../../features/customer/data/models/customer_models.dart';

abstract class ICustomerRepository {
  /// Fetch all active service categories
  Future<List<ServiceCategory>> getActiveServices();

  /// Fetch active, verified workers providing a specific service for customer location
  Future<List<Worker>> getEligibleWorkers(
    String serviceId, {
    double? customerLat,
    double? customerLng,
    String? serviceArea,
    bool isEmergency = false,
  });

  /// Fetch all active, verified registered workers across regions
  Future<List<Worker>> getAllWorkers({String? city, String? federationId});

  /// Check if there are available verified artisans/workers in the given area or federation
  Future<bool> hasWorkersInArea({String? federationId, String? district, String? city, String? pincode});

  /// Create a booking and return the created booking ID
  Future<String?> createBooking({
    required String workerId,
    required String serviceId,
    required String scheduledDate,
    required String scheduledTime,
    required double amount,
    String? addressId,
    String? notes,
    String bookingType = 'NORMAL',
    String paymentMethod = 'RAZORPAY',
  });

  /// Get the authenticated customer's booking history
  Future<List<Map<String, dynamic>>> getCustomerBookings();

  /// Get full detailed information for a specific booking
  Future<Map<String, dynamic>?> getBookingDetails(String bookingId);

  /// Cancel a booking if permitted by the state machine
  Future<bool> cancelBooking(String bookingId, {String? reason});

  /// Reschedule an active booking (date, time, optional address/notes)
  Future<bool> rescheduleBooking(
    String bookingId, {
    required String newDate,
    required String newTime,
    String? addressId,
    String? notes,
  });

  /// Realtime stream watching the authenticated customer's booking list
  Stream<List<Map<String, dynamic>>> watchCustomerBookings();

  /// Realtime stream watching a specific booking's state changes
  Stream<Map<String, dynamic>?> watchBookingDetails(String bookingId);
}
