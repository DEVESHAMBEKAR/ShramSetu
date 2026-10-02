import 'package:flutter/material.dart';

/// Supported interface languages across ShramSetu.
enum AppLanguage {
  english('en', 'English', 'EN', 'Default interface'),
  marathi('mr', 'मराठी', 'म', 'स्थानिक युनियन भाषा • पुणे'),
  hindi('hi', 'हिंदी', 'हिं', 'राष्ट्रभाषा इंटरफेस');

  final String code;
  final String label;
  final String shortCode;
  final String description;

  const AppLanguage(this.code, this.label, this.shortCode, this.description);

  static AppLanguage fromCode(String code) {
    switch (code.toLowerCase()) {
      case 'mr':
        return AppLanguage.marathi;
      case 'hi':
        return AppLanguage.hindi;
      case 'en':
      default:
        return AppLanguage.english;
    }
  }
}

/// Global reactive controller for app-wide language state.
class LocaleController extends ChangeNotifier {
  LocaleController._();
  static final LocaleController instance = LocaleController._();

  AppLanguage _currentLanguage = AppLanguage.english;

  AppLanguage get currentLanguage => _currentLanguage;
  String get languageCode => _currentLanguage.code;

  bool get isMarathi => _currentLanguage == AppLanguage.marathi;
  bool get isHindi => _currentLanguage == AppLanguage.hindi;
  bool get isEnglish => _currentLanguage == AppLanguage.english;

  /// Changes the application language and notifies all listening widgets.
  void setLanguage(String code) {
    final newLang = AppLanguage.fromCode(code);
    if (_currentLanguage != newLang) {
      _currentLanguage = newLang;
      notifyListeners();
    }
  }

  /// Cycles between English -> Marathi -> Hindi -> English.
  void toggleNextLanguage() {
    switch (_currentLanguage) {
      case AppLanguage.english:
        setLanguage('mr');
        break;
      case AppLanguage.marathi:
        setLanguage('hi');
        break;
      case AppLanguage.hindi:
        setLanguage('en');
        break;
    }
  }

  /// Resets to default language (English). Useful for test isolation.
  @visibleForTesting
  void reset() {
    _currentLanguage = AppLanguage.english;
    notifyListeners();
  }
}
