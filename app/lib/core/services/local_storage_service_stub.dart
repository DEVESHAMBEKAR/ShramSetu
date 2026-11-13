class LocalStoragePlatform {
  static final Map<String, String> _memStore = {};

  static String? getString(String key) => _memStore[key];

  static void setString(String key, String value) {
    _memStore[key] = value;
  }

  static void remove(String key) {
    _memStore.remove(key);
  }

  static void clear() {
    _memStore.clear();
  }
}
