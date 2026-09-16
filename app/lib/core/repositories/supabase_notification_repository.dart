import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_models.dart';
import 'i_notification_repository.dart';

class SupabaseNotificationRepository implements INotificationRepository {
  final SupabaseClient _supabase;

  SupabaseNotificationRepository(this._supabase);

  @override
  Future<bool> registerDeviceToken({
    required String token,
    String platform = 'android',
    String? deviceId,
  }) async {
    try {
      final res = await _supabase.rpc('register_device_token', params: {
        'p_fcm_token': token,
        'p_platform': platform,
        ?'p_device_id': deviceId,
      });

      if (res is Map && res['success'] == true) {
        debugPrint('[NotificationRepo] Registered FCM token successfully.');
        return true;
      }
      debugPrint('[NotificationRepo] register_device_token response: $res');
      return false;
    } catch (e) {
      debugPrint('[NotificationRepo] Error registering device token: $e');
      return false;
    }
  }

  @override
  Future<bool> deactivateDeviceToken(String token) async {
    try {
      final res = await _supabase.rpc('deactivate_device_token', params: {
        'p_fcm_token': token,
      });

      if (res is Map && res['success'] == true) {
        debugPrint('[NotificationRepo] Deactivated FCM token successfully.');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[NotificationRepo] Error deactivating device token: $e');
      return false;
    }
  }

  @override
  Future<List<AppNotificationModel>> getUserNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final response = await _supabase
          .from('notifications')
          .select()
          .eq('recipient_user_id', user.id)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((row) => AppNotificationModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[NotificationRepo] Error fetching notifications: $e');
      return [];
    }
  }

  @override
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final res = await _supabase.rpc('mark_notification_read', params: {
        'p_notification_id': notificationId,
      });

      return res is Map && res['success'] == true;
    } catch (e) {
      debugPrint('[NotificationRepo] Error marking notification as read: $e');
      return false;
    }
  }

  @override
  Future<bool> sendPushNotification({
    required String recipientUserId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final res = await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'recipientUserId': recipientUserId,
          'type': type,
          'title': title,
          'body': body,
          'data': data ?? {},
        },
      );

      debugPrint('[NotificationRepo] send-push-notification status: ${res.status}');
      return res.status == 200;
    } catch (e) {
      debugPrint('[NotificationRepo] Non-blocking push dispatch exception: $e');
      return false;
    }
  }
}