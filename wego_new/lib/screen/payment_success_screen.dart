import 'package:flutter/material.dart';
import 'app_translations.dart';

// ─────────────────────────────────────────
//  PAYMENT SUCCESS SCREEN
// ─────────────────────────────────────────
class PaymentSuccessScreen extends StatelessWidget {
  const PaymentSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final primaryColor = const Color(0xFF3A5DE0);
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Back Button ───────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 10),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.chevron_left_rounded,
                  color: primaryColor,
                  size: 32,
                ),
              ),
            ),

            // ── Body (centered) ───────────────────
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // ── Big Check Circle ──────────
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: primaryColor,
                            width: 3.5,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.check_rounded,
                            color: primaryColor,
                            size: 90,
                          ),
                        ),
                      ),

                      const SizedBox(height: 36),

                      // ── Congratulation ────────────
                      Text(
                        AppTranslations.translate('congratulation', lang),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                          letterSpacing: 0.3,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ── Subtitle ──────────────────
                      Text(
                        AppTranslations.translate('payment_success', lang),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: textColor,
                        ),
                      ),

                      const SizedBox(height: 50),

                      // ── Booking Info Card ─────────
                      _BookingInfoCard(
                        isDarkMode: isDarkMode,
                        primaryColor: primaryColor,
                        textColor: textColor,
                        lang: lang,
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  BOOKING INFO CARD
// ─────────────────────────────────────────
class _BookingInfoCard extends StatelessWidget {
  final bool isDarkMode;
  final Color primaryColor;
  final Color textColor;
  final String lang;

  const _BookingInfoCard({
    required this.isDarkMode,
    required this.primaryColor,
    required this.textColor,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withValues(alpha: 0.1) : primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.50),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description text
          Center(
            child: Text(
              AppTranslations.translate('booking_success_msg', lang),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: textColor,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Doctor Name (dynamic)
          Text(
            'Dr. Olivia Turner, M.D.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: primaryColor,
            ),
          ),

          const SizedBox(height: 12),

          // Date + Time row (dynamic)
          Row(
            children: [
              // Date
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.calendar_today_outlined,
                      color: primaryColor,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Month 24, Year',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 20),

              // Time
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.access_time_rounded,
                      color: primaryColor,
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '10:00 AM',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}