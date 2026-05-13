import 'package:flutter/material.dart'; // ✅ YE ADD KARO — Locale class yahan hai
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  bool _generalNotification = true;
  bool _sound = true;
  bool _soundCall = true;
  bool _vibrate = false;
  bool _specialOffers = false;
  bool _payments = true;
  bool _promoAndDiscount = false;
  bool _cashback = true;
  bool _isDarkMode = false;
  String _preferredLanguage = 'English';

  // ✅ Supported languages (with full translations available)
  final List<Map<String, String>> languageList = [
    {'name': 'English',              'native': 'English',            'code': 'en',     'flag': '🇬🇧'},
    {'name': 'Urdu',                 'native': 'اردو',               'code': 'ur',     'flag': '🇵🇰'},
    {'name': 'Hindi',                'native': 'हिन्दी',              'code': 'hi',     'flag': '🇮🇳'},
    {'name': 'Arabic',               'native': 'العربية',            'code': 'ar',     'flag': '🇸🇦'},
    {'name': 'Chinese Simplified',   'native': '中文(简体)',           'code': 'zh',     'flag': '🇨🇳'},
    {'name': 'Korean',               'native': '한국어',              'code': 'ko',     'flag': '🇰🇷'},
    {'name': 'Japanese',             'native': '日本語',              'code': 'ja',     'flag': '🇯🇵'},
    {'name': 'French',               'native': 'Français',           'code': 'fr',     'flag': '🇫🇷'},
    {'name': 'Spanish',              'native': 'Español',            'code': 'es',     'flag': '🇪🇸'},
    {'name': 'Turkish',              'native': 'Türkçe',             'code': 'tr',     'flag': '🇹🇷'},
    {'name': 'German',               'native': 'Deutsch',            'code': 'de',     'flag': '🇩🇪'},
  ];

  // ✅ Backward compatibility ke liye — purana code kaam karta rahe
  Map<String, String> get availableLanguages {
    return {for (var lang in languageList) lang['name']!: lang['code']!};
  }

  SettingsProvider() {
    _loadSettings();
  }

  // ─── Getters ───────────────────────────────────────────────────
  bool get generalNotification  => _generalNotification;
  bool get sound                => _sound;
  bool get soundCall            => _soundCall;
  bool get vibrate              => _vibrate;
  bool get specialOffers        => _specialOffers;
  bool get payments             => _payments;
  bool get promoAndDiscount     => _promoAndDiscount;
  bool get cashback             => _cashback;
  bool get isDarkMode           => _isDarkMode;
  String get preferredLanguage  => _preferredLanguage;

  // ✅ Language code getter — main.dart mein locale ke liye
  String get preferredLanguageCode {
    final found = languageList.firstWhere(
          (l) => l['name'] == _preferredLanguage,
      orElse: () => {'code': 'en'},
    );
    return found['code'] ?? 'en';
  }

  // ✅ Locale getter — seedha MaterialApp mein use karo
  Locale get currentLocale => Locale(preferredLanguageCode);

  // ─── Load from SharedPreferences ──────────────────────────────
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _generalNotification = prefs.getBool('generalNotification') ?? true;
    _sound               = prefs.getBool('sound')               ?? true;
    _soundCall           = prefs.getBool('soundCall')           ?? true;
    _vibrate             = prefs.getBool('vibrate')             ?? false;
    _specialOffers       = prefs.getBool('specialOffers')       ?? false;
    _payments            = prefs.getBool('payments')            ?? true;
    _promoAndDiscount    = prefs.getBool('promoAndDiscount')    ?? false;
    _cashback            = prefs.getBool('cashback')            ?? true;
    _isDarkMode          = prefs.getBool('isDarkMode')          ?? false;
    _preferredLanguage   = prefs.getString('preferredLanguage') ?? 'English';
    notifyListeners();
  }

  // ─── Setters ───────────────────────────────────────────────────
  Future<void> setPreferredLanguage(String language) async {
    _preferredLanguage = language;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferredLanguage', language);
  }

  Future<void> toggleTheme(bool value) async {
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', value);
  }

  Future<void> setGeneralNotification(bool value) async {
    _generalNotification = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('generalNotification', value);
  }

  Future<void> setSound(bool value) async {
    _sound = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('sound', value);
  }

  Future<void> setSoundCall(bool value) async {
    _soundCall = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundCall', value);
  }

  Future<void> setVibrate(bool value) async {
    _vibrate = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibrate', value);
  }

  Future<void> setSpecialOffers(bool value) async {
    _specialOffers = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('specialOffers', value);
  }

  Future<void> setPayments(bool value) async {
    _payments = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('payments', value);
  }

  Future<void> setPromoAndDiscount(bool value) async {
    _promoAndDiscount = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('promoAndDiscount', value);
  }

  Future<void> setCashback(bool value) async {
    _cashback = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('cashback', value);
  }

  // ✅ Logout ke baad English reset — jahan bhi logout ho wahan call karo
  Future<void> resetLanguageToDefault() async {
    _preferredLanguage = 'English';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('preferredLanguage', 'English');
  }
}