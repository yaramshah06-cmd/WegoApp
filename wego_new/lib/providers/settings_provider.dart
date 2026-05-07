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

  // ✅ Duniya bhar ki 55+ original languages with flag & native script
  final List<Map<String, String>> languageList = [
    {'name': 'English',              'native': 'English',            'code': 'en',     'flag': '🇬🇧'},
    {'name': 'Urdu',                 'native': 'اردو',               'code': 'ur',     'flag': '🇵🇰'},
    {'name': 'Hindi',                'native': 'हिन्दी',              'code': 'hi',     'flag': '🇮🇳'},
    {'name': 'Arabic',               'native': 'العربية',            'code': 'ar',     'flag': '🇸🇦'},
    {'name': 'Chinese Simplified',   'native': '中文(简体)',           'code': 'zh',     'flag': '🇨🇳'},
    {'name': 'Chinese Traditional',  'native': '中文(繁體)',           'code': 'zh_TW',  'flag': '🇹🇼'},
    {'name': 'Korean',               'native': '한국어',              'code': 'ko',     'flag': '🇰🇷'},
    {'name': 'Japanese',             'native': '日本語',              'code': 'ja',     'flag': '🇯🇵'},
    {'name': 'French',               'native': 'Français',           'code': 'fr',     'flag': '🇫🇷'},
    {'name': 'Spanish',              'native': 'Español',            'code': 'es',     'flag': '🇪🇸'},
    {'name': 'German',               'native': 'Deutsch',            'code': 'de',     'flag': '🇩🇪'},
    {'name': 'Italian',              'native': 'Italiano',           'code': 'it',     'flag': '🇮🇹'},
    {'name': 'Portuguese',           'native': 'Português',          'code': 'pt',     'flag': '🇧🇷'},
    {'name': 'Russian',              'native': 'Русский',            'code': 'ru',     'flag': '🇷🇺'},
    {'name': 'Turkish',              'native': 'Türkçe',             'code': 'tr',     'flag': '🇹🇷'},
    {'name': 'Persian',              'native': 'فارسی',              'code': 'fa',     'flag': '🇮🇷'},
    {'name': 'Bengali',              'native': 'বাংলা',              'code': 'bn',     'flag': '🇧🇩'},
    {'name': 'Punjabi',              'native': 'ਪੰਜਾਬੀ',             'code': 'pa',     'flag': '🇮🇳'},
    {'name': 'Gujarati',             'native': 'ગુજરાતી',            'code': 'gu',     'flag': '🇮🇳'},
    {'name': 'Marathi',              'native': 'मराठी',              'code': 'mr',     'flag': '🇮🇳'},
    {'name': 'Tamil',                'native': 'தமிழ்',              'code': 'ta',     'flag': '🇮🇳'},
    {'name': 'Telugu',               'native': 'తెలుగు',             'code': 'te',     'flag': '🇮🇳'},
    {'name': 'Malayalam',            'native': 'മലയാളം',             'code': 'ml',     'flag': '🇮🇳'},
    {'name': 'Kannada',              'native': 'ಕನ್ನಡ',              'code': 'kn',     'flag': '🇮🇳'},
    {'name': 'Sinhala',              'native': 'සිංහල',              'code': 'si',     'flag': '🇱🇰'},
    {'name': 'Nepali',               'native': 'नेपाली',             'code': 'ne',     'flag': '🇳🇵'},
    {'name': 'Thai',                 'native': 'ภาษาไทย',            'code': 'th',     'flag': '🇹🇭'},
    {'name': 'Vietnamese',           'native': 'Tiếng Việt',         'code': 'vi',     'flag': '🇻🇳'},
    {'name': 'Indonesian',           'native': 'Bahasa Indonesia',   'code': 'id',     'flag': '🇮🇩'},
    {'name': 'Malay',                'native': 'Bahasa Melayu',      'code': 'ms',     'flag': '🇲🇾'},
    {'name': 'Filipino',             'native': 'Filipino',           'code': 'fil',    'flag': '🇵🇭'},
    {'name': 'Dutch',                'native': 'Nederlands',         'code': 'nl',     'flag': '🇳🇱'},
    {'name': 'Polish',               'native': 'Polski',             'code': 'pl',     'flag': '🇵🇱'},
    {'name': 'Ukrainian',            'native': 'Українська',         'code': 'uk',     'flag': '🇺🇦'},
    {'name': 'Romanian',             'native': 'Română',             'code': 'ro',     'flag': '🇷🇴'},
    {'name': 'Hungarian',            'native': 'Magyar',             'code': 'hu',     'flag': '🇭🇺'},
    {'name': 'Czech',                'native': 'Čeština',            'code': 'cs',     'flag': '🇨🇿'},
    {'name': 'Swedish',              'native': 'Svenska',            'code': 'sv',     'flag': '🇸🇪'},
    {'name': 'Norwegian',            'native': 'Norsk',              'code': 'no',     'flag': '🇳🇴'},
    {'name': 'Danish',               'native': 'Dansk',              'code': 'da',     'flag': '🇩🇰'},
    {'name': 'Finnish',              'native': 'Suomi',              'code': 'fi',     'flag': '🇫🇮'},
    {'name': 'Greek',                'native': 'Ελληνικά',           'code': 'el',     'flag': '🇬🇷'},
    {'name': 'Hebrew',               'native': 'עברית',              'code': 'he',     'flag': '🇮🇱'},
    {'name': 'Swahili',              'native': 'Kiswahili',          'code': 'sw',     'flag': '🇰🇪'},
    {'name': 'Amharic',              'native': 'አማርኛ',               'code': 'am',     'flag': '🇪🇹'},
    {'name': 'Hausa',                'native': 'Hausa',              'code': 'ha',     'flag': '🇳🇬'},
    {'name': 'Yoruba',               'native': 'Yorùbá',             'code': 'yo',     'flag': '🇳🇬'},
    {'name': 'Zulu',                 'native': 'isiZulu',            'code': 'zu',     'flag': '🇿🇦'},
    {'name': 'Burmese',              'native': 'မြန်မာဘာသာ',          'code': 'my',     'flag': '🇲🇲'},
    {'name': 'Khmer',                'native': 'ភាសាខ្មែរ',           'code': 'km',     'flag': '🇰🇭'},
    {'name': 'Lao',                  'native': 'ລາວ',                'code': 'lo',     'flag': '🇱🇦'},
    {'name': 'Mongolian',            'native': 'Монгол',             'code': 'mn',     'flag': '🇲🇳'},
    {'name': 'Kazakh',               'native': 'Қазақша',            'code': 'kk',     'flag': '🇰🇿'},
    {'name': 'Uzbek',                'native': 'Oʻzbek',             'code': 'uz',     'flag': '🇺🇿'},
    {'name': 'Azerbaijani',          'native': 'Azərbaycan',         'code': 'az',     'flag': '🇦🇿'},
    {'name': 'Georgian',             'native': 'ქართული',            'code': 'ka',     'flag': '🇬🇪'},
    {'name': 'Armenian',             'native': 'Հայերեն',            'code': 'hy',     'flag': '🇦🇲'},
    {'name': 'Serbian',              'native': 'Српски',             'code': 'sr',     'flag': '🇷🇸'},
    {'name': 'Croatian',             'native': 'Hrvatski',           'code': 'hr',     'flag': '🇭🇷'},
    {'name': 'Slovak',               'native': 'Slovenčina',         'code': 'sk',     'flag': '🇸🇰'},
    {'name': 'Bulgarian',            'native': 'Български',          'code': 'bg',     'flag': '🇧🇬'},
    {'name': 'Catalan',              'native': 'Català',             'code': 'ca',     'flag': '🇪🇸'},
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