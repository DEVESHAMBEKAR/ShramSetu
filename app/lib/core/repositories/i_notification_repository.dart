import '../models/notification_models.dart';

abstract class INotificationRepository {
  /// Registers or updates the FCM token for the currently authenticated user.
  Future<bool> registerDeviceToken({
    required String token,
    String platform = 'android',
    String? deviceId,
  });

  /// Deactivates an FCM device token upon logout to stop push delivery.
  Future<bool> deactivateDeviceToken(String token);

  /// Retrieves persistent in-app notifications for the authenticated user.
  Future<List<AppNotificationModel>> getUserNotifications({
    int limit = 20,
    int offset = 0,
  });

  /// Marks an individual notification as read.
  Future<bool> markNotificationAsRead(String notificationId);

  /// Triggers a push notification via backend Edge Function.
  Future<bool> sendPushNotification({
    required String recipientUserId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  });
}