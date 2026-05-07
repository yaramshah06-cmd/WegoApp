import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wego_marriage/providers/settings_provider.dart';
import 'app_translations.dart';

class NotificationSettingScreen extends StatefulWidget {
  const NotificationSettingScreen({super.key});

  @override
  State<NotificationSettingScreen> createState() =>
      _NotificationSettingScreenState();
}

class _NotificationSettingScreenState
    extends State<NotificationSettingScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1A1A2E);
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF4169E1),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          AppTranslations.translate('notification_setting', lang),
          style: const TextStyle(
            color: Color(0xFF4169E1),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
        child: ListView(
          children: [
            _buildToggleItem(
              label: AppTranslations.translate('general_notification', lang),
              value: settings.generalNotification,
              onChanged: (val) => settings.setGeneralNotification(val),
              textColor: textColor,
            ),
            _buildToggleItem(
              label: AppTranslations.translate('sound', lang),
              value: settings.sound,
              onChanged: (val) => settings.setSound(val),
              textColor: textColor,
            ),
            _buildToggleItem(
              label: AppTranslations.translate('sound_call', lang),
              value: settings.soundCall,
              onChanged: (val) => settings.setSoundCall(val),
              textColor: textColor,
            ),
            _buildToggleItem(
              label: AppTranslations.translate('vibrate', lang),
              value: settings.vibrate,
              onChanged: (val) => settings.setVibrate(val),
              textColor: textColor,
            ),
            _buildToggleItem(
              label: AppTranslations.translate('special_offers', lang),
              value: settings.specialOffers,
              onChanged: (val) => settings.setSpecialOffers(val),
              textColor: textColor,
            ),
            _buildToggleItem(
              label: AppTranslations.translate('payments', lang),
              value: settings.payments,
              onChanged: (val) => settings.setPayments(val),
              textColor: textColor,
            ),
            _buildToggleItem(
              label: AppTranslations.translate('promo_and_discount', lang),
              value: settings.promoAndDiscount,
              onChanged: (val) => settings.setPromoAndDiscount(val),
              textColor: textColor,
            ),
            _buildToggleItem(
              label: AppTranslations.translate('cashback', lang),
              value: settings.cashback,
              onChanged: (val) => settings.setCashback(val),
              textColor: textColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: textColor,
              fontWeight: FontWeight.w400,
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFF4169E1),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFDDE3F0),
              trackOutlineColor:
              WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}