import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'notification_screen.dart';
import 'password_manager.dart';
import 'language_screen.dart';
import 'app_localizations.dart';
import 'app_translations.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(
            Icons.arrow_back_ios,
            color: isDark ? Colors.white : const Color(0xFF4A6CF7),
            size: 20,
          ),
        ),
        title: Text(
          context.tr('settings'), // ✅ Translated
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF4A6CF7),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            SettingsMenuItem(
              icon: Icons.lightbulb_outline,
              label: context.tr('notification_setting'), // ✅
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationSettingScreen(),
                  ),
                );
              },
            ),
            SettingsMenuItem(
              icon: Icons.key_outlined,
              label: context.tr('password_manager'), // ✅
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PasswordManagerScreen(),
                  ),
                );
              },
            ),

            Consumer<SettingsProvider>(
              builder: (context, settingsProvider, _) {
                return SettingsMenuItem(
                  icon: Icons.language_outlined,
                  label: context.tr('language'), // ✅
                  subtitle: settingsProvider.preferredLanguage,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LanguageScreen(),
                      ),
                    );
                  },
                );
              },
            ),

            SettingsMenuItem(
              icon: Icons.dark_mode_outlined,
              label: context.tr('theme'), // ✅
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ThemeScreen(),
                  ),
                );
              },
            ),
            SettingsMenuItem(
              icon: Icons.person_remove_outlined,
              label: context.tr('delete_account'), // ✅
              isDestructive: true,
              onTap: () {
                _showDeleteAccountDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          context.tr('delete_account'), // ✅
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        content: Text(
          context.tr('delete_account_msg'), // ✅
          style: const TextStyle(color: Colors.black54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.tr('cancel'), // ✅
              style: const TextStyle(color: Color(0xFF4A6CF7)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Add delete account logic
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              context.tr('delete'), // ✅
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// ThemeScreen
// ─────────────────────────────────────────────────────────────────
class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(
            Icons.arrow_back_ios,
            color: isDark ? Colors.white : const Color(0xFF4A6CF7),
            size: 20,
          ),
        ),
        title: Text(
          context.tr('theme_setting'), // ✅
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF4A6CF7),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    settingsProvider.isDarkMode
                        ? Icons.dark_mode
                        : Icons.light_mode,
                    size: 100,
                    color: const Color(0xFF4A6CF7),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    settingsProvider.isDarkMode
                        ? context.tr('dark_mode')  // ✅
                        : context.tr('light_mode'), // ✅
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Switch.adaptive(
                    value: settingsProvider.isDarkMode,
                    onChanged: (value) {
                      settingsProvider.toggleTheme(value);
                    },
                    activeThumbColor: const Color(0xFF4A6CF7),
                    activeTrackColor:
                    const Color(0xFF4A6CF7).withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SettingsMenuItem — unchanged, already correct
// ─────────────────────────────────────────────────────────────────
class SettingsMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const SettingsMenuItem({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Row(
            children: [
              Icon(
                icon,
                color: isDestructive ? Colors.red : const Color(0xFF4A6CF7),
                size: 24,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDestructive
                            ? Colors.red
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: isDestructive ? Colors.red : const Color(0xFF4A6CF7),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}