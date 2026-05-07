import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'app_translations.dart';

extension AppLocalizationsExt on BuildContext {
  String tr(String key) {
    // ✅ listen: true — language change hone par UI auto-rebuild hogi
    final langCode =
        Provider.of<SettingsProvider>(this, listen: true)
            .preferredLanguageCode;
    return AppTranslations.translate(key, langCode);
  }
}