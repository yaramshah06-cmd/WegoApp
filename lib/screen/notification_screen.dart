import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wego_marriage/providers/settings_provider.dart';

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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Color(0xFF7A1730),
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Notification Setting',
          style: TextStyle(
            color: Color(0xFF7A1730),
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
              label: 'General Notification',
              value: settings.generalNotification,
              onChanged: (val) => settings.setGeneralNotification(val),
              textColor: textColor,
            ),
            _buildToggleItem(
              label: 'Sound',
              value: settings.sound,
              onChanged: (val) => settings.setSound(val),
              textColor: textColor,
            ),
            _buildToggleItem(
              label: 'Sound Call',
              value: settings.soundCall,
              onChanged: (val) => settings.setSoundCall(val),
              textColor: textColor,
            ),
            _buildToggleItem(
              label: 'Vibrate',
              value: settings.vibrate,
              onChanged: (val) => settings.setVibrate(val),
              textColor: textColor,
            ),
            _buildToggleItem(
              label: 'Special Offers',
              value: settings.specialOffers,
              onChanged: (val) => settings.setSpecialOffers(val),
              textColor: textColor,
            ),
            _buildToggleItem(
              label: 'Payments',
              value: settings.payments,
              onChanged: (val) => settings.setPayments(val),
              textColor: textColor,
            ),
            _buildToggleItem(
              label: 'Promo And Discount',
              value: settings.promoAndDiscount,
              onChanged: (val) => settings.setPromoAndDiscount(val),
              textColor: textColor,
            ),
            _buildToggleItem(
              label: 'Cashback',
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
              activeTrackColor: const Color(0xFF7A1730),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFFBEAEE),
              trackOutlineColor:
              WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }
}