import 'package:flutter/material.dart';
import 'app_translations.dart';

// ─────────────────────────────────────────
//  PAYMENT SCREEN
// ─────────────────────────────────────────
class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subTextColor = isDarkMode ? Colors.white70 : Colors.black54;
    final dividerColor = isDarkMode ? Colors.white24 : const Color(0xFFE0E4F0);
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Blue Header ───────────────────────
          _BlueHeader(lang: lang),

          // ── Scrollable Body ───────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),

                    // ── Doctor Card ───────────────
                    _DoctorCard(
                      isDarkMode: isDarkMode,
                      textColor: textColor,
                      subTextColor: subTextColor,
                    ),

                    const SizedBox(height: 20),

                    Divider(color: dividerColor, thickness: 1),

                    const SizedBox(height: 14),

                    // ── Appointment Info ──────────
                    _InfoRow(
                      label: AppTranslations.translate('date_hour', lang),
                      value: 'Month 24, Year / 10:00 AM',
                      valueStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: AppTranslations.translate('duration', lang),
                      value: '30 Minutes',
                      valueStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: AppTranslations.translate('booking_for', lang),
                      value: AppTranslations.translate('another_person', lang),
                      valueStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                    ),

                    const SizedBox(height: 14),

                    Divider(color: dividerColor, thickness: 1),

                    const SizedBox(height: 14),

                    // ── Billing Info ──────────────
                    _InfoRow(
                      label: AppTranslations.translate('amount', lang),
                      value: '\$100.00',
                      valueStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(
                      label: AppTranslations.translate('duration', lang),
                      value: '30 Minutes',
                      valueStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                    ),

                    const SizedBox(height: 14),

                    Divider(color: dividerColor, thickness: 1),

                    const SizedBox(height: 14),

                    // ── Total ─────────────────────
                    _InfoRow(
                      label: AppTranslations.translate('total', lang),
                      value: '\$100',
                      labelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF3A5DE0),
                      ),
                      valueStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                    ),

                    const SizedBox(height: 14),

                    Divider(color: dividerColor, thickness: 1),

                    const SizedBox(height: 14),

                    // ── Payment Method ────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppTranslations.translate('payment_method', lang),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3A5DE0),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              AppTranslations.translate('card', lang),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {},
                              child: Text(
                                AppTranslations.translate('change', lang),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF3A5DE0),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),

          // ── Pay Now Button ────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Pay now logic
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A5DE0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: Text(
                  AppTranslations.translate('pay_now', lang),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  BLUE HEADER
// ─────────────────────────────────────────
class _BlueHeader extends StatelessWidget {
  final String lang;
  const _BlueHeader({required this.lang});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF3A5DE0),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    AppTranslations.translate('payment', lang),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.chevron_left_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Amount (dynamic — no key)
              const Text(
                '\$ 100.00',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  DOCTOR CARD
// ─────────────────────────────────────────
class _DoctorCard extends StatelessWidget {
  final bool isDarkMode;
  final Color textColor;
  final Color subTextColor;

  const _DoctorCard({
    required this.isDarkMode,
    required this.textColor,
    required this.subTextColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Avatar
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 70,
            height: 70,
            color: isDarkMode ? Colors.white10 : const Color(0xFFD0D8F0),
            child: Image.network(
              'https://i.pravatar.cc/200?img=47',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.person,
                size: 40,
                color: Color(0xFF3A5DE0),
              ),
            ),
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Dr. Olivia Turner, M.D.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3A5DE0),
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white12 : const Color(0xFFE8ECFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_outlined,
                      color: Color(0xFF3A5DE0),
                      size: 16,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 3),

              Text(
                'Dermato-Endocrinology',
                style: TextStyle(
                  fontSize: 12,
                  color: subTextColor,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 8),

              Row(
                children: [
                  _StatChip(
                    icon: Icons.star,
                    iconColor: const Color(0xFF3A5DE0),
                    label: '5',
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.chat_bubble_outline,
                    iconColor: const Color(0xFF3A5DE0),
                    label: '60',
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
//  STAT CHIP
// ─────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final bool isDarkMode;
  final Color textColor;

  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isDarkMode,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white12 : const Color(0xFFF0F3FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  INFO ROW
// ─────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _InfoRow({
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: labelStyle ??
              const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF3A5DE0),
              ),
        ),
        Text(
          value,
          style: valueStyle ??
              const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
        ),
      ],
    );
  }
}