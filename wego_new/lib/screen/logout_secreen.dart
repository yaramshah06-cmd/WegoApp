import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import 'app_localizations.dart';
import 'app_translations.dart';

class LogoutScreen extends StatefulWidget {
  const LogoutScreen({super.key});

  @override
  State<LogoutScreen> createState() => _LogoutScreenState();
}

class _LogoutScreenState extends State<LogoutScreen> {
  static const Color primaryBlue = Color(0xFF4A6CF7);
  static const Color accentPink = Color(0xFFDD2A7B);

  Future<void> _handleLogout(BuildContext ctx) async {
    await context.read<SettingsProvider>().resetLanguageToDefault();
    if (ctx.mounted) Navigator.pop(ctx);
    // await FirebaseAuth.instance.signOut();
    // if (context.mounted) {
    //   Navigator.pushAndRemoveUntil(
    //     context,
    //     MaterialPageRoute(builder: (_) => const LoginScreen()),
    //     (route) => false,
    //   );
    // }
  }

  void _showLogoutDialog(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle bar ──────────────────────────────────
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.grey[300],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 32),

            // ── Icon ────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.red,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),

            // ── Title ✅ TRANSLATED ──────────────────────────
            Text(
              context.tr('logout'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // ── Subtitle ✅ TRANSLATED ───────────────────────
            Text(
              context.tr('logout_msg'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // ── Buttons ─────────────────────────────────────
            Row(
              children: [
                // Cancel ✅ TRANSLATED
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      context.tr('cancel'),
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Yes Logout ✅ TRANSLATED
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleLogout(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      context.tr('yes_logout'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white60 : Colors.black45;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(textColor),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildProfileHeader(isDark, textColor, subTextColor),
                    const SizedBox(height: 32),

                    // ─── Account Settings ✅ TRANSLATED ─────
                    _buildMenuSection(
                      context,
                      context.tr('account_settings'),
                      [
                        _MenuItemData(
                          Icons.person_outline_rounded,
                          context.tr('personal_profile'),
                          context.tr('manage_info'),
                        ),
                        _MenuItemData(
                          Icons.favorite_outline_rounded,
                          context.tr('my_favorites'),
                          context.tr('people_liked'),
                        ),
                        _MenuItemData(
                          Icons.account_balance_wallet_outlined,
                          context.tr('payment_methods'),
                          context.tr('subscriptions'),
                        ),
                      ],
                      isDark,
                    ),

                    const SizedBox(height: 20),

                    // ─── Preferences ✅ TRANSLATED ───────────
                    _buildMenuSection(
                      context,
                      context.tr('preferences'),
                      [
                        _MenuItemData(
                          Icons.lock_outline_rounded,
                          context.tr('privacy_policy'),
                          context.tr('secure_account'),
                        ),
                        _MenuItemData(
                          Icons.settings_outlined,
                          context.tr('app_settings'),
                          context.tr('themes_notifications'),
                        ),
                        _MenuItemData(
                          Icons.help_outline_rounded,
                          context.tr('help_center'),
                          context.tr('faqs_support'),
                        ),
                      ],
                      isDark,
                    ),

                    const SizedBox(height: 40),
                    _buildLogoutButton(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
            color: primaryBlue,
            onPressed: () => Navigator.maybePop(context),
          ),
          // ✅ TRANSLATED
          Text(
            context.tr('settings'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
      bool isDark, Color textColor, Color subTextColor) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [primaryBlue, accentPink],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(3),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(2),
                child: const CircleAvatar(
                  radius: 50,
                  backgroundImage: NetworkImage(
                    'https://randomuser.me/api/portraits/men/32.jpg',
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: primaryBlue,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF121212)
                        : Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ✅ TRANSLATED — user_name
        Text(
          context.tr('user_name'),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),

        // ✅ TRANSLATED — user_email
        Text(
          context.tr('user_email'),
          style: TextStyle(
            fontSize: 14,
            color: subTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(
      BuildContext context,
      String title,
      List<_MenuItemData> items,
      bool isDark,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: primaryBlue.withValues(alpha: 0.8),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Column(
            children: List.generate(items.length, (index) {
              final item = items[index];
              return Column(
                children: [
                  _buildMenuItem(
                    item.icon,
                    item.label,
                    item.subtitle,
                    isDark ? Colors.white : Colors.black87,
                  ),
                  if (index != items.length - 1)
                    Padding(
                      padding: const EdgeInsets.only(left: 64, right: 20),
                      child: Divider(
                        height: 1,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey[100],
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(
      IconData icon, String label, String subtitle, Color textColor) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: primaryBlue, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: textColor.withValues(alpha: 0.2),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () => _showLogoutDialog(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.redAccent.withValues(alpha: 0.1),
                Colors.red.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Colors.redAccent.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.power_settings_new_rounded,
                color: Colors.redAccent,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                context.tr('sign_out'), // ✅ TRANSLATED
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuItemData {
  final IconData icon;
  final String label;
  final String subtitle;

  _MenuItemData(this.icon, this.label, this.subtitle);
}