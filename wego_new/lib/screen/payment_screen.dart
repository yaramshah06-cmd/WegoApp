import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wego_marriage/screen/xp_service.dart';

class PaymentScreen extends StatefulWidget {
  final String planTitle;
  final String planDuration;
  final int    planPrice;
  final String planBadge;
  final Color  accentColor;
  final List<String> perks;
  final String currency; // ✅ NAYA

  const PaymentScreen({
    super.key,
    this.planTitle    = 'Weekly Plan',
    this.planDuration = 'Weekly',
    this.planPrice    = 160,
    this.planBadge    = '',
    this.accentColor  = const Color(0xFF7F77DD),
    this.perks        = const ['Unlimited matches', 'Weekly boost', 'Level 5'],
    this.currency     = 'Yen', // ✅ NAYA
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const Color kBg      = Color(0xFFF2F3F7);
  static const Color kCard    = Colors.white;
  static const Color kBorder  = Color(0xFFE8E8EE);
  static const Color kText    = Color(0xFF111111);
  static const Color kSubText = Color(0xFFAAAAAA);
  static const Color kLabel   = Color(0xFF999999);

  Color get kPrimary   => widget.accentColor;
  Color get kPrimaryBg => widget.accentColor.withValues(alpha: 0.12);

  String _selected  = 'wechat';
  bool   _isLoading = false;

  final _cardNumCtrl = TextEditingController();
  final _expiryCtrl  = TextEditingController();
  final _cvvCtrl     = TextEditingController();
  final _holderCtrl  = TextEditingController();
  final _formKey     = GlobalKey<FormState>();

  bool get _showCardForm => _selected == 'credit' || _selected == 'debit';

  @override
  void dispose() {
    _cardNumCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  Future<void> _processPayment() async {
    if (_showCardForm && !(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User logged in nahi hai');

      await user.getIdToken(true);

      final Map<String, dynamic> paymentData = {
        'userId'        : user.uid,
        'planTitle'     : widget.planTitle,
        'planDuration'  : widget.planDuration,
        'amount'        : widget.planPrice,
        'planBadge'     : widget.planBadge,
        'currency'      : widget.currency, // ✅ FIX — 'Yen' ki jagah dynamic
        'paymentMethod' : _selected,
        'status'        : 'pending',
        'createdAt'     : FieldValue.serverTimestamp(),
      };

      if (_showCardForm) {
        final raw = _cardNumCtrl.text.replaceAll(' ', '');
        paymentData['cardLast4']  = raw.length >= 4 ? raw.substring(raw.length - 4) : '****';
        paymentData['cardHolder'] = _holderCtrl.text.trim();
        paymentData['cardExpiry'] = _expiryCtrl.text.trim();
      }

      final docRef = await FirebaseFirestore.instance
          .collection('payments')
          .doc(user.uid)
          .collection('records')
          .add(paymentData);

      await docRef.update({'status': 'completed'});

      // 🎁 Topup level boost — PKR 10,000 ya USD 100 pe +1 level
      final currency = widget.currency.toUpperCase(); // ✅ FIX
      final amount = widget.planPrice.toDouble();
      double pkr = 0;
      double usd = 0;
      if (currency == 'PKR') {
        pkr = amount;
      } else if (currency == 'USD') {
        usd = amount;
      }
      if (pkr > 0 || usd > 0) {
        await XPService.addXP(
          user.uid,
          XPAction.topup,
          topupAmountPKR: pkr,
          topupAmountUSD: usd,
        );
      }

      if (mounted) _showSuccessDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment fail hua: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: kPrimaryBg, shape: BoxShape.circle),
              child: Icon(Icons.check_rounded, color: kPrimary, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Payment Successful!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: kText)),
            const SizedBox(height: 8),
            Text(
              '${widget.planTitle} active ho gaya!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kSubText),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                child: const Text('Continue', style: TextStyle(color: Colors.white, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _planCard(),
                      const SizedBox(height: 12),
                      _sectionLabel('SELECT PAYMENT METHOD'),
                      const SizedBox(height: 8),
                      _methodsCard(),
                      if (_showCardForm) ...[
                        const SizedBox(height: 12),
                        _cardForm(),
                      ],
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: const BoxDecoration(
        color: kCard,
        border: Border(bottom: BorderSide(color: Color(0xFFEFEFEF), width: 0.5)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(color: kBg, shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: kText),
              ),
            ),
          ),
          const Text('Payment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: kText)),
        ],
      ),
    );
  }

  Widget _planCard() {
    final badge = widget.planBadge.isNotEmpty
        ? widget.planBadge.toUpperCase()
        : widget.planDuration.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: kPrimaryBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(badge,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPrimary, letterSpacing: 1)),
                          ),
                          const SizedBox(height: 5),
                          Text(widget.planTitle,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: kText)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${widget.planPrice}',
                            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: kPrimary)),
                        Text(widget.currency, // ✅ FIX — dynamic currency
                            style: const TextStyle(fontSize: 11, color: kSubText)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.perks.map((p) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: kPrimaryBg,
                        border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(p, style: TextStyle(fontSize: 11, color: kPrimary)),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kLabel, letterSpacing: 1.2)),
  );

  Widget _methodsCard() {
    final methods = [
      _Method('wechat', 'WeChat Pay',  'Pay with WeChat wallet',       _iconWechat()),
      _Method('jazz',   'JazzCash',    'Pay with JazzCash account',    _iconJazz()),
      _Method('easy',   'Easypaisa',   'Pay with Easypaisa wallet',    _iconEasy()),
      _Method('credit', 'Credit Card', 'Visa / Mastercard / UnionPay', _iconCredit()),
      _Method('debit',  'Debit Card',  'Mastercard debit',             _iconDebit()),
    ];

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: methods.asMap().entries.map((e) {
          final i      = e.key;
          final m      = e.value;
          final sel    = _selected == m.id;
          final isLast = i == methods.length - 1;

          return GestureDetector(
            onTap: () => setState(() => _selected = m.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: sel ? kPrimaryBg : kCard,
                borderRadius: BorderRadius.vertical(
                  top:    i == 0 ? const Radius.circular(16) : Radius.zero,
                  bottom: isLast ? const Radius.circular(16) : Radius.zero,
                ),
                border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF2F2F2), width: 0.5)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  m.icon,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kText)),
                        const SizedBox(height: 1),
                        Text(m.sub, style: const TextStyle(fontSize: 11, color: kSubText)),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: sel ? kPrimary : const Color(0xFFDDDDDD), width: 2),
                    ),
                    child: sel
                        ? Center(child: Container(width: 11, height: 11, decoration: BoxDecoration(color: kPrimary, shape: BoxShape.circle)))
                        : null,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _cardForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          _field(
            label: 'Card number',
            ctrl: _cardNumCtrl,
            hint: '1234  5678  9012  3456',
            type: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly, _CardNumberFormatter()],
            validator: (v) => (v == null || v.replaceAll(' ', '').length < 16) ? 'Valid card number daalo' : null,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _field(
                  label: 'Expiry',
                  ctrl: _expiryCtrl,
                  hint: 'MM / YY',
                  type: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly, _ExpiryFormatter()],
                  validator: (v) => (v == null || v.length < 7) ? 'Invalid expiry' : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _field(
                  label: 'CVV',
                  ctrl: _cvvCtrl,
                  hint: '•••',
                  type: TextInputType.number,
                  obscure: true,
                  formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                  validator: (v) => (v == null || v.length < 3) ? 'Invalid CVV' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _field(
            label: 'Cardholder name',
            ctrl: _holderCtrl,
            hint: 'Name on card',
            type: TextInputType.name,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Naam daalo' : null,
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController ctrl,
    required String hint,
    TextInputType type = TextInputType.text,
    List<TextInputFormatter>? formatters,
    bool obscure = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: kLabel)),
        const SizedBox(height: 3),
        TextFormField(
          controller: ctrl,
          keyboardType: type,
          inputFormatters: formatters,
          obscureText: obscure,
          validator: validator,
          style: const TextStyle(fontSize: 14, color: kText),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE0E0E0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: kPrimary, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.redAccent)),
          ),
        ),
      ],
    );
  }

  Widget _footer() {
    return Container(
      color: kBg,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline_rounded, size: 13, color: kPrimary),
              const SizedBox(width: 5),
              const Text('Secure & encrypted payment',
                  style: TextStyle(fontSize: 11, color: Color(0xFFBBBBBB))),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                disabledBackgroundColor: kPrimary.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 0,
              ),
              onPressed: _isLoading ? null : _processPayment,
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                'Pay Now — ${widget.planPrice} ${widget.currency}', // ✅ FIX
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: 0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconWechat() => _iconBox(color: const Color(0xFF07C160), child: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22));
  Widget _iconJazz()   => _iconBox(color: const Color(0xFFCC0000), child: const Text('J', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)));
  Widget _iconCredit() => _iconBox(color: const Color(0xFF1A1F71), child: const Icon(Icons.credit_card_rounded, color: Colors.white, size: 22));
  Widget _iconDebit()  => _iconBox(color: const Color(0xFFEB001B), child: const Icon(Icons.payment_rounded, color: Colors.white, size: 22));

  Widget _iconEasy() => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFEEEEEE))),
    child: const Center(child: Text('EP', style: TextStyle(color: Color(0xFF47A248), fontWeight: FontWeight.w800, fontSize: 13))),
  );

  Widget _iconBox({required Color color, required Widget child}) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Center(child: child),
  );
}

class _Method {
  final String id, name, sub;
  final Widget icon;
  const _Method(this.id, this.name, this.sub, this.icon);
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue cur) {
    final digits  = cur.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(0, digits.length.clamp(0, 16));
    final buf     = StringBuffer();
    for (int i = 0; i < limited.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write('  ');
      buf.write(limited[i]);
    }
    final s = buf.toString();
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue cur) {
    final digits  = cur.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.substring(0, digits.length.clamp(0, 4));
    final s       = limited.length >= 3 ? '${limited.substring(0, 2)} / ${limited.substring(2)}' : limited;
    return TextEditingValue(text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}