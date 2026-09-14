import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LanguageProvider extends ChangeNotifier {
  Locale _currentLocale = const Locale('ar');
  Map<String, String>? _localizedStrings;

  String? get guestPrompt => translate('guest_login_prompt');
  Locale get currentLocale => _currentLocale;

  Future<void> loadLanguage(Locale locale) async {
    _currentLocale = locale;
    String jsonString = await rootBundle.loadString('assets/lang/${locale.languageCode}.json');
    Map<String, dynamic> jsonMap = json.decode(jsonString);

    _localizedStrings = jsonMap.map((key, value) {
      return MapEntry(key, value.toString());
    });
    notifyListeners();
  }

  void changeLanguage(Locale locale) async {
    await loadLanguage(locale);
  }

  String translate(String key) {
    if (_localizedStrings == null) return key;
    return _localizedStrings![key] ?? key;
  }
}
