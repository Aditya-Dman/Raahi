import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService {
  static const String _languageKey = 'selected_language';

  // Save selected language
  static Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  // Get saved language
  static Future<String> getSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'en'; // Default to English
  }

  // Get locale from language code
  static Locale getLocaleFromLanguageCode(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return const Locale('hi', 'IN');
      case 'en':
      default:
        return const Locale('en', 'US');
    }
  }

  // Get available languages
  static List<Map<String, String>> getAvailableLanguages() {
    return [
      {'code': 'en', 'name': 'English', 'nativeName': 'English'},
      {'code': 'hi', 'name': 'Hindi', 'nativeName': 'हिंदी'},
    ];
  }
}

// Language notifier for state management
class LanguageNotifier extends ChangeNotifier {
  Locale _currentLocale = const Locale('en', 'US');

  Locale get currentLocale => _currentLocale;

  Future<void> loadSavedLanguage() async {
    final savedLanguageCode = await LanguageService.getSavedLanguage();
    _currentLocale = LanguageService.getLocaleFromLanguageCode(
      savedLanguageCode,
    );
    notifyListeners();
  }

  Future<void> changeLanguage(String languageCode) async {
    print('🔤 Changing language to: $languageCode');
    await LanguageService.saveLanguage(languageCode);
    _currentLocale = LanguageService.getLocaleFromLanguageCode(languageCode);
    print('🔤 New locale: $_currentLocale');
    notifyListeners();
    print('🔤 Language change complete, notified listeners');
  }
}
