import '../models/notification_models.dart';
import 'i_notification_repository.dart';

class MockNotificationRepository implements INotificationRepository {
  final List<DeviceTokenModel> _tokens = [];
  final List<AppNotificationModel> _notifications = [];

  List<DeviceTokenModel> get tokens => List.unmodifiable(_tokens);
  List<AppNotificationModel> get notifications => List.unmodifiable(_notifications);

  void clear() {
    _tokens.clear();
    _notifications.clear();
  }

  void seedNotifications(List<AppNotificationModel> list) {
    _notifications.addAll(list);
  }

  @override
  Future<bool> registerDeviceToken({
    required String token,
    String platform = 'android',
    String? deviceId,
  }) async {
    final existingIndex = _tokens.indexWhere((t) => t.fcmToken == token);
    if (existingIndex >= 0) {
      _tokens[existingIndex] = _tokens[existingIndex].copyWith(
        isActive: true,
        platform: platform,
        deviceId: deviceId,
        lastSeenAt: DateTime.now(),
      );
    } else {
      _tokens.add(DeviceTokenModel(
        id: 'token_${_tokens.length + 1}',
        userId: 'mock_user_id',
        fcmToken: token,
        platform: platform,
        deviceId: deviceId,
        isActive: true,
        createdAt: DateTime.now(),
        lastSeenAt: DateTime.now(),
      ));
    }
    return true;
  }

  @override
  Future<bool> deactivateDeviceToken(String token) async {
    final index = _tokens.indexWhere((t) => t.fcmToken == token);
    if (index >= 0) {
      _tokens[index] = _tokens[index].copyWith(
        isActive: false,
        lastSeenAt: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  @override
  Future<List<AppNotificationModel>> getUserNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    final sorted = List<AppNotificationModel>.from(_notifications)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    if (offset >= sorted.length) return [];
    return sorted.skip(offset).take(limit).toList();
  }

  @override
  Future<bool> markNotificationAsRead(String notificationId) async {
    final index = _notifications.indexWhere((n) => n.id == notificationId);
    if (index >= 0) {
      _notifications[index] = _notifications[index].copyWith(
        readAt: DateTime.now(),
      );
      return true;
    }
    return false;
  }

  @override
  Future<bool> sendPushNotification({
    required String recipientUserId,
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    _notifications.insert(
      0,
      AppNotificationModel(
        id: 'notif_${_notifications.length + 1}',
        recipientUserId: recipientUserId,
        type: type,
        title: title,
        body: body,
        data: data ?? {},
        createdAt: DateTime.now(),
      ),
    );
    return true;
  }
}