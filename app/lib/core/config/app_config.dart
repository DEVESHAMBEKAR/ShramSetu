import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  static String? _configurationError;

  static String? get configurationError => _configurationError;
  static bool get hasConfigurationError => _configurationError != null;

  static Future<void> initialize() async {
    _configurationError = null;
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint('[AppConfig] .env file not found or failed to load: $e');
    }

    final supabaseUrl = dotenv.isInitialized ? (dotenv.env['SUPABASE_URL'] ?? '') : '';
    final supabaseAnonKey = dotenv.isInitialized ? (dotenv.env['SUPABASE_ANON_KEY'] ?? '') : '';
    final useMock = useMockData;

    if (!useMock) {
      // Validate live configuration
      if (supabaseUrl.isEmpty || !supabaseUrl.startsWith('https://') || supabaseUrl.contains('your-project-id')) {
        _configurationError = 'Invalid or missing SUPABASE_URL in .env for LIVE mode.';
        debugPrint('[AppConfig] ERROR: $_configurationError');
        return;
      }

      if (supabaseAnonKey.isEmpty || supabaseAnonKey.contains('your-publishable-anon-key')) {
        _configurationError = 'Invalid or missing SUPABASE_ANON_KEY in .env for LIVE mode.';
        debugPrint('[AppConfig] ERROR: $_configurationError');
        return;
      }

      try {
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

  static bool get useMockData {
    if (!dotenv.isInitialized) return true;
    final val = dotenv.env['USE_MOCK_DATA'];
    // Default to mock mode only if explicitly set to true
    return val == 'true';
  }

  static String get environmentName {
    return useMockData ? 'MOCK / TESTING' : 'LIVE';
  }

  static SupabaseClient get supabaseClient {
    return Supabase.instance.client;
  }
}
