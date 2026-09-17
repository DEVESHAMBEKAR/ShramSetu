import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  static const String defaultSupabaseUrl = 'https://epcevntwhwyrrexlezco.supabase.co';
  static const String defaultSupabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVwY2V2bnR3aHd5cnJleGxlemNvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg0NTY4NDAsImV4cCI6MjEwNDAzMjg0MH0.m9gDAC3owCym6DMOlqKHAK2YJAUpaJ7UEzGEpBJroHo';

  static String? _configurationError;

  static String? get configurationError => _configurationError;
  static bool get hasConfigurationError => _configurationError != null;

  static Future<void> initialize() async {
    _configurationError = null;
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint('[AppConfig] .env not loaded from root, trying fallback: $e');
      try {
        await dotenv.load(fileName: "assets/.env");
      } catch (_) {}
    }

    String supabaseUrl = dotenv.isInitialized ? (dotenv.env['SUPABASE_URL'] ?? '') : '';
    if (supabaseUrl.isEmpty) {
      supabaseUrl = const String.fromEnvironment('SUPABASE_URL', defaultValue: defaultSupabaseUrl);
    }

    String supabaseAnonKey = dotenv.isInitialized ? (dotenv.env['SUPABASE_ANON_KEY'] ?? '') : '';
    if (supabaseAnonKey.isEmpty) {
      supabaseAnonKey = const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: defaultSupabaseAnonKey);
    }

    final useMock = useMockData;

    if (!useMock) {
      if (supabaseUrl.isEmpty || !supabaseUrl.startsWith('https://') || supabaseUrl.contains('your-project-id')) {
        _configurationError = 'Invalid or missing SUPABASE_URL for LIVE mode.';
        debugPrint('[AppConfig] ERROR: $_configurationError');
        return;
      }

      if (supabaseAnonKey.isEmpty || supabaseAnonKey.contains('your-publishable-anon-key')) {
        _configurationError = 'Invalid or missing SUPABASE_ANON_KEY for LIVE mode.';
        debugPrint('[AppConfig] ERROR: $_configurationError');
        return;
      }

      try {
        // Prevent re-initialization error if client is already active
        try {
          final _ = Supabase.instance.client;
          debugPrint('[AppConfig] Supabase already initialized.');
          return;
        } catch (_) {}

        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
        );
        debugPrint('[AppConfig] Connected to Supabase LIVE backend successfully.');
      } catch (e) {
        _configurationError = 'Failed to connect to Supabase: $e';
        debugPrint('[AppConfig] ERROR: $_configurationError');
      }
    } else {
      debugPrint('[AppConfig] Operating in MOCK / TESTING MODE.');
    }
  }

  static bool get isSupabaseInitialized {
    try {
      final _ = Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool get useMockData {
    // In unit tests (no Supabase initialized), always use mock
    if (!isSupabaseInitialized) return true;
    if (dotenv.isInitialized && dotenv.env['USE_MOCK_DATA'] != null) {
      return dotenv.env['USE_MOCK_DATA'] == 'true';
    }
    const envMock = String.fromEnvironment('USE_MOCK_DATA', defaultValue: 'false');
    return envMock == 'true';
  }

  static String get environmentName {
    return useMockData ? 'MOCK / TESTING' : 'LIVE';
  }

  static SupabaseClient get supabaseClient {
    return Supabase.instance.client;
  }
}
