import 'package:flutter/material.dart';
import 'app_translations.dart';

// ─────────────────────────────────────────
//  PAYMENT METHOD SCREEN
// ─────────────────────────────────────────
class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({super.key});

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  // 0 = Add New Card, 1 = Apple Pay, 2 = Paypal, 3 = Google Pay
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Top Bar ──────────────────────────
              Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    AppTranslations.translate('payment_method', lang),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2B4DE0),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: Color(0xFF3A5DE0),
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // ── Section 1: Credit & Debit Card ───
              Text(
                AppTranslations.translate('credit_debit_card', lang),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 12),

              // Add New Card Row
              _PaymentTile(
                selected: _selectedIndex == 0,
                onTap: () => setState(() => _selectedIndex = 0),
                isDarkMode: isDarkMode,
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white12 : const Color(0xFFE8ECFF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.credit_card_outlined,
                        color: Color(0xFF3A5DE0),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      AppTranslations.translate('add_new_card', lang),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3A5DE0),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Section 2: More Payment Option ───
              Text(
                AppTranslations.translate('more_payment_option', lang),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),

              const SizedBox(height: 12),

              // Apple Pay
              _PaymentTile(
                selected: _selectedIndex == 1,
                onTap: () => setState(() => _selectedIndex = 1),
                isDarkMode: isDarkMode,
                child: Row(
                  children: [
                    _ApplePayIcon(isDarkMode: isDarkMode),
                    const SizedBox(width: 14),
                    Text(
                      AppTranslations.translate('apple_pay', lang),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3A5DE0),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Paypal
              _PaymentTile(
                selected: _selectedIndex == 2,
                onTap: () => setState(() => _selectedIndex = 2),
                isDarkMode: isDarkMode,
                child: Row(
                  children: [
                    _PaypalIcon(isDarkMode: isDarkMode),
                    const SizedBox(width: 14),
                    Text(
                      AppTranslations.translate('paypal', lang),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3A5DE0),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Google Pay
              _PaymentTile(
                selected: _selectedIndex == 3,
                onTap: () => setState(() => _selectedIndex = 3),
                isDarkMode: isDarkMode,
                child: Row(
                  children: [
                    _GooglePayIcon(isDarkMode: isDarkMode),
                    const SizedBox(width: 14),
                    Text(
                      AppTranslations.translate('google_pay', lang),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF3A5DE0),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  PAYMENT TILE (row with radio)
// ─────────────────────────────────────────
class _PaymentTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  final bool isDarkMode;

  const _PaymentTile({
    required this.selected,
    required this.onTap,
    required this.child,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFF0F3FF),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Expanded(child: child),
            // Radio button
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF3A5DE0),
                  width: selected ? 0 : 1.8,
                ),
                color: selected ? const Color(0xFF3A5DE0) : Colors.transparent,
              ),
              child: selected
                  ? Center(
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              )
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  CUSTOM ICONS
// ─────────────────────────────────────────

class _ApplePayIcon extends StatelessWidget {
  final bool isDarkMode;
  const _ApplePayIcon({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white12 : const Color(0xFFE8ECFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.apple,
          color: Color(0xFF3A5DE0),
          size: 22,
        ),
      ),
    );
  }
}

class _PaypalIcon extends StatelessWidget {
  final bool isDarkMode;
  const _PaypalIcon({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white12 : const Color(0xFFE8ECFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'P',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF3A5DE0),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

class _GooglePayIcon extends StatelessWidget {
  final bool isDarkMode;
  const _GooglePayIcon({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white12 : const Color(0xFFE8ECFF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'GP',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Color(0xFF3A5DE0),
          ),
        ),
      ),
    );
  }
}