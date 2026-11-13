import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Default FirebaseOptions configuration for ShramSetu.
/// - On Web: Configured with your Firebase Web credentials (and fallback to .env).
/// - On Android / iOS: Automatically resolved from google-services.json / GoogleService-Info.plist.
class DefaultFirebaseOptions {
  static const String webApiKey = "AIzaSyBrg0NouNMXyEvFZTVjIDEuoFQjCO4AbtQ";
  static const String webAuthDomain = "shramsetu-ce290.firebaseapp.com";
  static const String webProjectId = "shramsetu-ce290";
  static const String webStorageBucket = "shramsetu-ce290.firebasestorage.app";
  static const String webMessagingSenderId = "1097217213581";
  static const String webAppId = "1:1097217213581:web:bc2da7205f04073cd1cec4";
  static const String webMeasurementId = "G-CYN3NR3L5X";

  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) {
      String getVal(String key, String fallback) {
        if (!dotenv.isInitialized) return fallback;
        final v = dotenv.env[key]?.trim();
        return (v != null && v.isNotEmpty) ? v : fallback;
      }

      final apiKey = getVal('FIREBASE_API_KEY', webApiKey);
      final projectId = getVal('FIREBASE_PROJECT_ID', webProjectId);
      final appId = getVal('FIREBASE_APP_ID', webAppId);
      final messagingSenderId = getVal('FIREBASE_MESSAGING_SENDER_ID', webMessagingSenderId);
      final authDomain = getVal('FIREBASE_AUTH_DOMAIN', webAuthDomain);
      final storageBucket = getVal('FIREBASE_STORAGE_BUCKET', webStorageBucket);
      final measurementId = getVal('FIREBASE_MEASUREMENT_ID', webMeasurementId);

      return FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
        measurementId: measurementId,
      );
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Automatically populated from google-services.json
        return null;
      case TargetPlatform.iOS:
        // Automatically populated from GoogleService-Info.plist
        return null;
      default:
        return null;
    }
  }
}
