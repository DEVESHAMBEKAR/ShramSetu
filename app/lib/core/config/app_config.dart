import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppConfig {
  static Future<void> initialize() async {
    await dotenv.load(fileName: ".env");

    final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
    final useMockData = dotenv.env['USE_MOCK_DATA'] == 'true';

    if (!useMockData && supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
    }
  }

  static bool get useMockData {
    // If true, the app will use local Mock repositories instead of Supabase.
    // If false, it uses Supabase repositories (which will throw errors if not initialized).
    if (!dotenv.isInitialized) return true;
    return dotenv.env['USE_MOCK_DATA'] == 'true';
  }

  static SupabaseClient get supabaseClient {
    return Supabase.instance.client;
  }
}
