import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/settings_provider.dart';
import 'notification_screen.dart';
import 'password_manager.dart';
import 'language_screen.dart';
import 'profile_edit.dart';
import 'policy_privacy.dart';
import 'help_center_screen.dart';
import 'connection_secreen.dart';
import 'welcome_screen.dart';
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
        child: ListView(
          children: [
            SettingsMenuItem(
              icon: Icons.person_outline,
              label: context.tr('edit_profile'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileEditScreen(),
                  ),
                );
              },
            ),
            SettingsMenuItem(
              icon: Icons.notifications_outlined,
              label: context.tr('notifications'),
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
              icon: Icons.privacy_tip_outlined,
              label: context.tr('privacy'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
            SettingsMenuItem(
              icon: Icons.favorite_border,
              label: context.tr('favorites'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MatchesScreen(),
                  ),
                );
              },
            ),
            SettingsMenuItem(
              icon: Icons.help_outline,
              label: context.tr('help_support'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HelpCenterScreen(),
                  ),
                );
              },
            ),
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
            SettingsMenuItem(
              icon: Icons.logout,
              label: context.tr('logout'),
              isDestructive: true,
              onTap: () {
                _showLogoutDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          context.tr('logout'),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        content: Text(
          context.tr('logout_confirm'),
          style: const TextStyle(color: Colors.black54, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              context.tr('cancel'),
              style: const TextStyle(color: Color(0xFF4A6CF7)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              // Logout se PEHLE presence offline kar do — auth.uid abhi
              // valid hai, isliye RTDB write allowed hai. signOut ke baad
              // RTDB rule reject kar deta.
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                try {
                  // onDisconnect cancel — taki phantom reconnect na ho.
                  await FirebaseDatabase.instance
                      .ref('presence/$uid')
                      .onDisconnect()
                      .cancel();
                  await FirebaseDatabase.instanceFor(
                      app: Firebase.app(),
                      databaseURL:
                          'https://wego-talk-default-rtdb.firebaseio.com',
                    ).ref('presence/$uid').set({
                    'online': false,
                    'lastSeen': ServerValue.timestamp,
                  });
                } catch (_) {}
              }

              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                await context
                    .read<SettingsProvider>()
                    .resetLanguageToDefault();
              }
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              context.tr('logout'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
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
            onPressed: () async {
              Navigator.pop(context);

              final user = FirebaseAuth.instance.currentUser;
              if (user == null) return;
              final uid = user.uid;

              try {
                // 1. Presence ko abhi offline mark kar do — auth still valid.
                await FirebaseDatabase.instance
                    .ref('presence/$uid')
                    .onDisconnect()
                    .cancel();
                await FirebaseDatabase.instanceFor(
                      app: Firebase.app(),
                      databaseURL:
                          'https://wego-talk-default-rtdb.firebaseio.com',
                    ).ref('presence/$uid').set({
                  'online': false,
                  'lastSeen': ServerValue.timestamp,
                });

                // 2. Firestore user doc delete (privacy subdoc bhi
                //    Firestore cascade rule ke under nahi hota — explicit
                //    delete kar dete hain).
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .collection('privacy')
                    .doc('settings')
                    .delete()
                    .catchError((_) {});
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .delete()
                    .catchError((_) {});

                // 3. Auth user delete. Yeh recent-login require karta hai —
                //    agar fail ho to user ko re-login bolna chahiye.
                await user.delete();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Delete failed: $e')),
                  );
                }
                return;
              }

              if (context.mounted) {
                await context
                    .read<SettingsProvider>()
                    .resetLanguageToDefault();
              }
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                  (route) => false,
                );
              }
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