import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../config/dependency_injection.dart';
import '../../features/customer/presentation/screens/customer_live_tracking_screen.dart';
import '../../features/worker/presentation/screens/worker_job_detail_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[NotificationService] Background message received: ${message.messageId}');
}

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final NotificationService instance = NotificationService._internal();

  factory NotificationService() => instance;
  NotificationService._internal();

  bool _isInitialized = false;
  bool _isFirebaseAvailable = false;
  String? _currentFcmToken;
  StreamSubscription<String>? _tokenRefreshSub;

  bool get isInitialized => _isInitialized;
  bool get isFirebaseAvailable => _isFirebaseAvailable;
  String? get currentFcmToken => _currentFcmToken;

  /// Initializes notification infrastructure with graceful fallback.
  /// Never crashes the app if Firebase configuration or credentials are not yet present.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _isFirebaseAvailable = true;

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Register message listeners
      _setupMessageListeners();

      debugPrint('[NotificationService] Firebase initialized successfully.');
    } catch (e) {
      _isFirebaseAvailable = false;
      debugPrint('[NotificationService] Firebase unavailable ($e). Operating in fallback mode.');
    }

    _isInitialized = true;
  }

  /// Request runtime permissions on Android 13+ and iOS.
  Future<bool> requestPermissions() async {
    if (!_isFirebaseAvailable) return true;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      debugPrint('[NotificationService] Notification permission granted: $granted');
      return granted;
    } catch (e) {
      debugPrint('[NotificationService] Error requesting notification permissions: $e');
      return false;
    }
  }

  /// Registers current device token in the database upon user authentication.
  Future<String?> registerDeviceToken({required String userId, String? platform}) async {
    final effectivePlatform = platform ??
        (kIsWeb
            ? 'web'
            : defaultTargetPlatform == TargetPlatform.iOS
                ? 'ios'
                : 'android');

    if (!_isFirebaseAvailable) {
      final fallbackToken = 'dev_token_${userId.length > 8 ? userId.substring(0, 8) : userId}';
      _currentFcmToken = fallbackToken;
      await DI.notificationRepo.registerDeviceToken(
        token: fallbackToken,
        platform: effectivePlatform,
      );
      debugPrint('[NotificationService] Registered fallback token: $fallbackToken');
      return fallbackToken;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        _currentFcmToken = token;
        await DI.notificationRepo.registerDeviceToken(
          token: token,
          platform: effectivePlatform,
        );
        debugPrint('[NotificationService] Registered FCM token: ${token.substring(0, token.length > 12 ? 12 : token.length)}...');

        // Listen for token rotations
        _tokenRefreshSub?.cancel();
        _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
          _currentFcmToken = newToken;
          DI.notificationRepo.registerDeviceToken(
            token: newToken,
            platform: effectivePlatform,
          );
        });

        return token;
      }
    } catch (e) {
      debugPrint('[NotificationService] Error fetching FCM token: $e');
    }
    return null;
  }

  /// Deactivates device token upon logout to stop push notifications.
  Future<void> deactivateCurrentToken() async {
    final token = _currentFcmToken;
    if (token != null) {
      await DI.notificationRepo.deactivateDeviceToken(token);
      _currentFcmToken = null;
    }
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    debugPrint('[NotificationService] Deactivated current FCM token.');
  }

  void _setupMessageListeners() {
    // 1. Foreground message handler
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[NotificationService] Foreground message: ${message.notification?.title}');
      _showForegroundNotification(message);
    });

    // 2. Notification tap from background state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[NotificationService] Message opened app: ${message.data}');
      handleNotificationTap(message.data);
    });

    // 3. Notification tap from terminated state
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('[NotificationService] Initial message: ${message.data}');
        handleNotificationTap(message.data);
      }
    });
  }

  /// Displays non-intrusive in-app banner for foreground pushes.
  void _showForegroundNotification(RemoteMessage message) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final title = message.notification?.title ?? 'Notification';
    final body = message.notification?.body ?? '';
    final data = message.data;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            if (body.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                body,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          textColor: const Color(0xFFF59E0B),
          onPressed: () {
            handleNotificationTap(data);
          },
        ),
      ),
    );
  }

  /// Handles notification tap and navigates to the relevant booking or screen.
  Future<void> handleNotificationTap(Map<String, dynamic> data) async {
    final navState = navigatorKey.currentState;
    if (navState == null) return;

    final bookingId = data['bookingId']?.toString() ?? data['booking_id']?.toString();
    if (bookingId == null || bookingId.isEmpty) {
      debugPrint('[NotificationService] No bookingId in notification data.');
      return;
    }

    try {
      final role = await DI.authRepo.getUserRole();
      if (role == 'WORKER') {
        navState.push(
          MaterialPageRoute(
            builder: (_) => WorkerJobDetailScreen(jobId: bookingId),
          ),
        );
      } else {
        navState.push(
          MaterialPageRoute(
            builder: (_) => CustomerLiveTrackingScreen(bookingId: bookingId),
          ),
        );
      }
    } catch (e) {
      debugPrint('[NotificationService] Error routing notification tap: $e');
    }
  }
}