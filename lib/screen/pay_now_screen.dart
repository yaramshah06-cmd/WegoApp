import 'package:flutter/material.dart';

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
    final dividerColor = isDarkMode ? Colors.white24 : const Color(0xFFFBEAEE);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Blue Header ───────────────────────
          _BlueHeader(),

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
                    _DoctorCard(isDarkMode: isDarkMode, textColor: textColor, subTextColor: subTextColor),

                    const SizedBox(height: 20),

                    // Divider
                    Divider(color: dividerColor, thickness: 1),

                    const SizedBox(height: 14),

                    // ── Appointment Info ──────────
                    _InfoRow(
                      label: 'Date / Hour',
                      value: 'Month 24, Year / 10:00 AM',
                      valueStyle: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Duration', value: '30 Minutes', valueStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Booking for', value: 'Another Person', valueStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),),

                    const SizedBox(height: 14),

                    // Divider
                    Divider(color: dividerColor, thickness: 1),

                    const SizedBox(height: 14),

                    // ── Billing Info ──────────────
                    _InfoRow(label: 'Amount', value: '\$100.00', valueStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),),
                    const SizedBox(height: 10),
                    _InfoRow(label: 'Duration', value: '30 Minutes', valueStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),),

                    const SizedBox(height: 14),

                    // Divider
                    Divider(color: dividerColor, thickness: 1),

                    const SizedBox(height: 14),

                    // ── Total ─────────────────────
                    _InfoRow(
                      label: 'Total',
                      value: '\$100',
                      labelStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7A1730),
                      ),
                      valueStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Divider
                    Divider(color: dividerColor, thickness: 1),

                    const SizedBox(height: 14),

                    // ── Payment Method ────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Payment Method',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF7A1730),
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Card',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {},
                              child: const Text(
                                'Change',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF7A1730),
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
                  backgroundColor: const Color(0xFF7A1730),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                child: const Text(
                  'Pay Now',
                  style: TextStyle(
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
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF7A1730),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          child: Column(
            children: [
              // Top bar row
              Stack(
                alignment: Alignment.center,
                children: [
                  const Text(
                    'Payment',
                    style: TextStyle(
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

              // Amount
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

  const _DoctorCard({required this.isDarkMode, required this.textColor, required this.subTextColor});

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
            color: isDarkMode ? Colors.white10 : const Color(0xFFFBEAEE),
            child: Image.network(
              'https://i.pravatar.cc/200?img=47',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.person,
                size: 40,
                color: Color(0xFF7A1730),
              ),
            ),
          ),
        ),

        const SizedBox(width: 14),

        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + badge
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Dr. Olivia Turner, M.D.',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7A1730),
                      ),
                    ),
                  ),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.white12 : const Color(0xFFFBEAEE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_outlined,
                      color: Color(0xFF7A1730),
                      size: 16,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 3),

              // Specialty
              Text(
                'Dermato-Endocrinology',
                style: TextStyle(
                  fontSize: 12,
                  color: subTextColor,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const SizedBox(height: 8),

              // Stats row
              Row(
                children: [
                  _StatChip(
                    icon: Icons.star,
                    iconColor: const Color(0xFF7A1730),
                    label: '5',
                    isDarkMode: isDarkMode,
                    textColor: textColor,
                  ),
                  const SizedBox(width: 8),
                  _StatChip(
                    icon: Icons.chat_bubble_outline,
                    iconColor: const Color(0xFF7A1730),
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
        color: isDarkMode ? Colors.white12 : const Color(0xFFFBEAEE),
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
                color: Color(0xFF7A1730),
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
