import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_localizations.dart';
import 'app_translations.dart';

// ─────────────────────────────────────────
//  ADD CARD SCREEN
// ─────────────────────────────────────────
class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _nameController    = TextEditingController(text: 'John Doe');
  final _numberController  = TextEditingController();
  final _expiryController  = TextEditingController(text: '04/28');
  final _cvvController     = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // ── Top Bar ──────────────────────
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          context.tr('add_new_card'), // ✅
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF2B4DE0),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              color: isDark ? Colors.white : const Color(0xFF3A5DE0),
                              size: 30,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Credit Card Widget ────────────
                    _CreditCardWidget(
                      name:   _nameController.text,
                      number: _numberController.text,
                      expiry: _expiryController.text,
                    ),

                    const SizedBox(height: 28),

                    // ── Card Holder Name ──────────────
                    _FieldLabel(context.tr('card_holder_name')), // ✅
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _nameController,
                      hint: context.tr('card_holder_hint'), // ✅
                      keyboardType: TextInputType.name,
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 18),

                    // ── Card Number ───────────────────
                    _FieldLabel(context.tr('card_number')), // ✅
                    const SizedBox(height: 8),
                    _InputField(
                      controller: _numberController,
                      hint: '000 000 000 00',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _CardNumberFormatter(),
                      ],
                      onChanged: (_) => setState(() {}),
                    ),

                    const SizedBox(height: 18),

                    // ── Expiry Date + CVV ─────────────
                    Row(
                      children: [
                        // Expiry Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel(context.tr('expiry_date')), // ✅
                              const SizedBox(height: 8),
                              _InputField(
                                controller: _expiryController,
                                hint: '04/28',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  _ExpiryDateFormatter(),
                                ],
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 16),

                        // CVV
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FieldLabel(context.tr('cvv')), // ✅
                              const SizedBox(height: 8),
                              _InputField(
                                controller: _cvvController,
                                hint: '0000',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(4),
                                ],
                                obscureText: true,
                                onChanged: (_) => setState(() {}),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),

            // ── Save Card Button ──────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Save card logic
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
                    context.tr('save_card'), // ✅
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
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
//  CREDIT CARD WIDGET
// ─────────────────────────────────────────
class _CreditCardWidget extends StatelessWidget {
  final String name;
  final String number;
  final String expiry;

  const _CreditCardWidget({
    required this.name,
    required this.number,
    required this.expiry,
  });

  @override
  Widget build(BuildContext context) {
    final displayNumber =
    number.isEmpty ? '000 000 000 00' : number.padRight(14, '0');
    final displayExpiry = expiry.isEmpty ? '04/28' : expiry;
    final displayName   = name.isEmpty   ? 'John Doe' : name;

    return Container(
      width: double.infinity,
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4B6EF5),
            Color(0xFF2B4DE0),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: 30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: -20,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 50,
                      height: 22,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                Text(
                  displayNumber,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 14),

                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('card_holder_name'), // ✅
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 24),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('expiry_date'), // ✅
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayExpiry,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    const _ChipIcon(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
//  CHIP ICON
// ─────────────────────────────────────────
class _ChipIcon extends StatelessWidget {
  const _ChipIcon();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [_chipSquare(), const SizedBox(width: 3), _chipSquare()]),
        const SizedBox(height: 3),
        Row(mainAxisSize: MainAxisSize.min, children: [_chipSquare(), const SizedBox(width: 3), _chipSquare()]),
        const SizedBox(height: 3),
        Row(mainAxisSize: MainAxisSize.min, children: [_chipSquare(), const SizedBox(width: 3), _chipSquare()]),
      ],
    );
  }

  Widget _chipSquare() => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      border: Border.all(color: Colors.white60, width: 1),
      borderRadius: BorderRadius.circular(2),
    ),
  );
}

// ─────────────────────────────────────────
//  FIELD LABEL
// ─────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );
  }
}

// ─────────────────────────────────────────
//  INPUT FIELD
// ─────────────────────────────────────────
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final ValueChanged<String>? onChanged;

  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.obscureText = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : const Color(0xFFF0F3FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        obscureText: obscureText,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 15,
          color: isDark ? Colors.white : const Color(0xFF3A5DE0),
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white38 : const Color(0xFFADB8E8),
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
          contentPadding:
          const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  TEXT INPUT FORMATTERS
// ─────────────────────────────────────────
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digitsOnly.length > 11 ? digitsOnly.substring(0, 11) : digitsOnly;

    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i == 3 || i == 6 || i == 9) buffer.write(' ');
      buffer.write(limited[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue,
      TextEditingValue newValue,
      ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digitsOnly.length > 4 ? digitsOnly.substring(0, 4) : digitsOnly;

    final buffer = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i == 2) buffer.write('/');
      buffer.write(limited[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}