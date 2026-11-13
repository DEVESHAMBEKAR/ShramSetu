import 'local_storage_service_stub.dart'
    if (dart.library.html) 'local_storage_service_web.dart' as platform;

/// Cross-platform local key-value persistence.
/// Uses `window.localStorage` on web (survives refreshes, tabs, and sessions)
/// and an in-memory store on native/testing environments.
class LocalStorageService {
  static String? getString(String key) => platform.LocalStoragePlatform.getString(key);

  static void setString(String key, String value) => platform.LocalStoragePlatform.setString(key, value);

  static void remove(String key) => platform.LocalStoragePlatform.remove(key);

  static bool? getBool(String key) {
    final val = getString(key);
    if (val == null) return null;
    return val == 'true' || val == '1';
  }

  static void setBool(String key, bool value) {
    setString(key, value ? 'true' : 'false');
  }

  static void clear() => platform.LocalStoragePlatform.clear();
}
