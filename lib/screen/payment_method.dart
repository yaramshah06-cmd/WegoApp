import 'package:flutter/material.dart';

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
                  const Text(
                    'Payment Method',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7A1730),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: Color(0xFF7A1730),
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // ── Section 1: Credit & Debit Card ───
              Text(
                'Credit & Debit Card',
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
                        color: isDarkMode ? Colors.white12 : const Color(0xFFFBEAEE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.credit_card_outlined,
                        color: Color(0xFF7A1730),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'Add New Card',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7A1730),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Section 2: More Payment Option ───
              Text(
                'More Payment Option',
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
                    const Text(
                      'Apple Pay',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7A1730),
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
                    const Text(
                      'Paypal',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7A1730),
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
                    const Text(
                      'Google Pay',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF7A1730),
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
          color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFFBEAEE),
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
                  color: const Color(0xFF7A1730),
                  width: selected ? 0 : 1.8,
                ),
                color: selected ? const Color(0xFF7A1730) : Colors.transparent,
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

// Apple Pay Icon (Apple logo)
class _ApplePayIcon extends StatelessWidget {
  final bool isDarkMode;
  const _ApplePayIcon({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white12 : const Color(0xFFFBEAEE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Icon(
          Icons.apple,
          color: Color(0xFF7A1730),
          size: 22,
        ),
      ),
    );
  }
}

// Paypal Icon (text-based P logo)
class _PaypalIcon extends StatelessWidget {
  final bool isDarkMode;
  const _PaypalIcon({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white12 : const Color(0xFFFBEAEE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'P',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A1730),
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

// Google Pay Icon (GP text logo)
class _GooglePayIcon extends StatelessWidget {
  final bool isDarkMode;
  const _GooglePayIcon({required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white12 : const Color(0xFFFBEAEE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'GP',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: Color(0xFF7A1730),
          ),
        ),
      ),
    );
  }
}
