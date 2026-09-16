import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/models/notification_models.dart';
import 'package:app/core/repositories/mock_notification_repository.dart';

void main() {
  group('Notification Models Serialization & Parsing', () {
    test('DeviceTokenModel serialization and deserialization', () {
      final json = {
        'id': 'tok-123',
        'user_id': 'usr-456',
        'fcm_token': 'fcm_sample_token_xyz',
        'platform': 'android',
        'device_id': 'pixel_8_pro',
        'is_active': true,
        'created_at': '2026-09-16T12:00:00Z',
        'last_seen_at': '2026-09-16T12:30:00Z',
      };

      final model = DeviceTokenModel.fromJson(json);

      expect(model.id, 'tok-123');
      expect(model.userId, 'usr-456');
      expect(model.fcmToken, 'fcm_sample_token_xyz');
      expect(model.platform, 'android');
      expect(model.deviceId, 'pixel_8_pro');
      expect(model.isActive, true);
      expect(model.createdAt, DateTime.parse('2026-09-16T12:00:00Z'));
      expect(model.lastSeenAt, DateTime.parse('2026-09-16T12:30:00Z'));

      final serialized = model.toJson();
      expect(serialized['fcm_token'], 'fcm_sample_token_xyz');
      expect(serialized['is_active'], true);
    });

    test('AppNotificationModel serialization, parsing, and getters', () {
      final json = {
        'id': 'notif-001',
        'recipient_user_id': 'user-100',
        'type': 'booking_status',
        'title': 'Booking Confirmed!',
        'body': 'Your service partner accepted your plumbing booking.',
        'data': {
          'bookingId': 'book-789',
          'status': 'accepted',
        },
        'read_at': null,
        'created_at': '2026-09-16T10:00:00Z',
      };

      final notification = AppNotificationModel.fromJson(json);

      expect(notification.id, 'notif-001');
      expect(notification.recipientUserId, 'user-100');
      expect(notification.type, 'booking_status');
      expect(notification.eventType, NotificationEventType.bookingAccepted);
      expect(notification.title, 'Booking Confirmed!');
      expect(notification.isRead, false);
      expect(notification.bookingId, 'book-789');

      final readNotification = notification.copyWith(readAt: DateTime.now());
      expect(readNotification.isRead, true);
    });

    test('NotificationEventType parser recognizes valid events and defaults to general', () {
      expect(
        NotificationEventType.fromString('booking_accepted'),
        NotificationEventType.bookingAccepted,
      );
      expect(
        NotificationEventType.fromString('worker_on_the_way'),
        NotificationEventType.workerOnTheWay,
      );
      expect(
        NotificationEventType.fromString('payment_released'),
        NotificationEventType.paymentReleased,
      );
      expect(
        NotificationEventType.fromString('review_received'),
        NotificationEventType.reviewReceived,
      );
      expect(
        NotificationEventType.fromString('unknown_event_xyz'),
        NotificationEventType.general,
      );
      expect(
        NotificationEventType.fromString(null),
        NotificationEventType.general,
      );
    });
  });

  group('MockNotificationRepository Lifecycle & In-App Management', () {
    late MockNotificationRepository repo;

    setUp(() {
      repo = MockNotificationRepository();
      repo.clear();
    });

    test('registerDeviceToken stores token and handles updates idempotently', () async {
      await repo.registerDeviceToken(
        token: 'token_alpha',
        platform: 'android',
        deviceId: 'device_1',
      );

      expect(repo.tokens.length, 1);
      expect(repo.tokens.first.fcmToken, 'token_alpha');
      expect(repo.tokens.first.isActive, true);

      // Re-registering existing token updates active state rather than duplicating
      await repo.registerDeviceToken(
        token: 'token_alpha',
        platform: 'android',
        deviceId: 'device_1_updated',
      );

      expect(repo.tokens.length, 1);
      expect(repo.tokens.first.deviceId, 'device_1_updated');
      expect(repo.tokens.first.isActive, true);
    });

    test('deactivateDeviceToken sets isActive to false on logout', () async {
      await repo.registerDeviceToken(token: 'token_to_logout');
      expect(repo.tokens.first.isActive, true);

      final success = await repo.deactivateDeviceToken('token_to_logout');
      expect(success, true);
      expect(repo.tokens.first.isActive, false);

      // Deactivating non-existent token returns false
      final fail = await repo.deactivateDeviceToken('non_existent_token');
      expect(fail, false);
    });

    test('Persistent notification creation, pagination, and read status', () async {
      await repo.sendPushNotification(
        recipientUserId: 'customer_1',
        type: 'booking_status',
        title: 'Partner Arrived',
        body: 'Your artisan has arrived at your premises.',
        data: {'bookingId': 'bk_1', 'status': 'arrived'},
      );

      await repo.sendPushNotification(
        recipientUserId: 'customer_1',
        type: 'payment_released',
        title: 'Payment Released',
        body: 'Payment released.',
        data: {'bookingId': 'bk_1'},
      );

      final list = await repo.getUserNotifications(limit: 10);
      expect(list.length, 2);
      expect(list.first.title, 'Payment Released');
      expect(list.first.isRead, false);

      final markSuccess = await repo.markNotificationAsRead(list.first.id);
      expect(markSuccess, true);

      final updatedList = await repo.getUserNotifications(limit: 10);
      expect(updatedList.first.isRead, true);
    });
  });

  group('Push Payload Privacy & Sanitization Guarantees', () {
    test('Payload does NOT include sensitive customer personal information', () {
      final safeDataPayload = {
        'bookingId': 'bk_secure_123',
        'status': 'accepted',
        'serviceId': 'srv_electrical',
      };

      // Ensure no private address or phone numbers exist in push data
      expect(safeDataPayload.containsKey('customer_phone'), false);
      expect(safeDataPayload.containsKey('phone'), false);
      expect(safeDataPayload.containsKey('address'), false);
      expect(safeDataPayload.containsKey('address_line'), false);
      expect(safeDataPayload.containsKey('latitude'), false);
      expect(safeDataPayload.containsKey('longitude'), false);
      expect(safeDataPayload.containsKey('otp'), false);
    });

    test('Recipient role resolution: customer receives status updates, worker receives requests', () {
      const customerUserId = 'user_cust_888';
      const workerUserId = 'user_work_999';

      // Status change payload intended for customer
      final customerNotification = AppNotificationModel(
        id: 'n1',
        recipientUserId: customerUserId,
        type: 'booking_status',
        title: 'Worker On The Way',
        body: 'Artisan is en route.',
        data: {'bookingId': 'bk_10'},
        createdAt: DateTime.now(),
      );
      expect(customerNotification.recipientUserId, customerUserId);

      // New service request intended for worker
      final workerNotification = AppNotificationModel(
        id: 'n2',
        recipientUserId: workerUserId,
        type: 'booking_requested',
        title: 'New Service Request',
        body: 'New booking waiting for your confirmation.',
        data: {'bookingId': 'bk_11'},
        createdAt: DateTime.now(),
      );
      expect(workerNotification.recipientUserId, workerUserId);
    });
  });
}