enum NotificationEventType {
  bookingRequested('booking_requested'),
  bookingAccepted('booking_accepted'),
  workerOnTheWay('worker_on_the_way'),
  workerArrived('worker_arrived'),
  jobInProgress('job_in_progress'),
  jobCompleted('job_completed'),
  bookingCancelled('booking_cancelled'),
  paymentHeld('payment_held'),
  paymentReleased('payment_released'),
  reviewReceived('review_received'),
  general('general');

  final String value;
  const NotificationEventType(this.value);

  static NotificationEventType fromString(String? val) {
    if (val == null) return NotificationEventType.general;
    return NotificationEventType.values.firstWhere(
      (e) => e.value == val.toLowerCase().trim(),
      orElse: () => NotificationEventType.general,
    );
  }

  static NotificationEventType fromTypeAndData(String? type, Map<String, dynamic>? data) {
    if (type == 'booking_status' && data != null && data['status'] != null) {
      final status = data['status'].toString().toLowerCase().replaceAll('_', '');
      if (status == 'accepted') return NotificationEventType.bookingAccepted;
      if (status == 'ontheway') return NotificationEventType.workerOnTheWay;
      if (status == 'arrived') return NotificationEventType.workerArrived;
      if (status == 'inprogress') return NotificationEventType.jobInProgress;
      if (status == 'completed') return NotificationEventType.jobCompleted;
      if (status == 'cancelled' || status == 'rejected') return NotificationEventType.bookingCancelled;
    }
    return NotificationEventType.fromString(type);
  }
}

class DeviceTokenModel {
  final String id;
  final String userId;
  final String fcmToken;
  final String platform;
  final String? deviceId;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastSeenAt;

  const DeviceTokenModel({
    required this.id,
    required this.userId,
    required this.fcmToken,
    this.platform = 'android',
    this.deviceId,
    this.isActive = true,
    this.createdAt,
    this.lastSeenAt,
  });

  factory DeviceTokenModel.fromJson(Map<String, dynamic> json) {
    return DeviceTokenModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      fcmToken: json['fcm_token'] as String? ?? '',
      platform: json['platform'] as String? ?? 'android',
      deviceId: json['device_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      lastSeenAt: json['last_seen_at'] != null ? DateTime.tryParse(json['last_seen_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'fcm_token': fcmToken,
      'platform': platform,
      if (deviceId != null) 'device_id': deviceId,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (lastSeenAt != null) 'last_seen_at': lastSeenAt!.toIso8601String(),
    };
  }

  DeviceTokenModel copyWith({
    String? id,
    String? userId,
    String? fcmToken,
    String? platform,
    String? deviceId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastSeenAt,
  }) {
    return DeviceTokenModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fcmToken: fcmToken ?? this.fcmToken,
      platform: platform ?? this.platform,
      deviceId: deviceId ?? this.deviceId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

class AppNotificationModel {
  final String id;
  final String recipientUserId;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotificationModel({
    required this.id,
    required this.recipientUserId,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  String? get bookingId => data['bookingId']?.toString() ?? data['booking_id']?.toString();

  NotificationEventType get eventType => NotificationEventType.fromTypeAndData(type, data);

  factory AppNotificationModel.fromJson(Map<String, dynamic> json) {
    return AppNotificationModel(
      id: json['id'] as String? ?? '',
      recipientUserId: json['recipient_user_id'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : {},
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipient_user_id': recipientUserId,
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      if (readAt != null) 'read_at': readAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotificationModel copyWith({
    String? id,
    String? recipientUserId,
    String? type,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      recipientUserId: recipientUserId ?? this.recipientUserId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}