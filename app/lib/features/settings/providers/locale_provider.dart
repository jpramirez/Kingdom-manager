import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_constants.dart';

class LocaleNotifier extends StateNotifier<Locale?> {
  LocaleNotifier() : super(null) {
    _loadLocale();
  }

  static const _supportedLocales = ['en', 'zh', 'ms', 'tl', 'id', 'my'];

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(AppConstants.keySelectedLocale);
    if (code != null && _supportedLocales.contains(code)) {
      state = Locale(code);
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (!_supportedLocales.contains(locale.languageCode)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keySelectedLocale, locale.languageCode);
    state = locale;
  }

  Future<void> clearLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keySelectedLocale);
    state = null;
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>((ref) {
  return LocaleNotifier();
});

class LocaleInfo {
  final Locale locale;
  final String nativeName;
  final String englishName;

  const LocaleInfo({required this.locale, required this.nativeName, required this.englishName});
}

const availableLocales = [
  LocaleInfo(locale: Locale('en'), nativeName: 'English', englishName: 'English'),
  LocaleInfo(locale: Locale('zh'), nativeName: '简体中文', englishName: 'Chinese (Simplified)'),
  LocaleInfo(locale: Locale('ms'), nativeName: 'Bahasa Melayu', englishName: 'Malay'),
  LocaleInfo(locale: Locale('tl'), nativeName: 'Tagalog', englishName: 'Tagalog'),
  LocaleInfo(locale: Locale('id'), nativeName: 'Bahasa Indonesia', englishName: 'Indonesian'),
  LocaleInfo(locale: Locale('my'), nativeName: 'မြန်မာ', englishName: 'Myanmar (Burmese)'),
];
