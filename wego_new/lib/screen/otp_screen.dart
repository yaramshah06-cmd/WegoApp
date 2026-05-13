import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wego_marriage/screen/user_gendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final Map<String, dynamic> userInfo;
  final PhoneAuthCredential? autoCredential;

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.userInfo,
    this.autoCredential,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isResending = false;
  bool _canResend = false;
  bool _isLoading = false;
  int _countdownSeconds = 60;
  late Timer _timer;
  String _currentVerificationId = '';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const Color primaryBlue = Color(0xFF3333FF);

  @override
  void initState() {
    super.initState();
    _currentVerificationId = widget.verificationId;
    _startCountdown();

    if (widget.autoCredential != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyWithCredential(widget.autoCredential!);
      });
    }
  }

  void _startCountdown() {
    _countdownSeconds = 60;
    _canResend = false;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdownSeconds > 0) {
        setState(() => _countdownSeconds--);
      } else {
        timer.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  @override
  void dispose() {
    if (_timer.isActive) _timer.cancel();
    for (var c in _controllers) c.dispose();
    for (var f in _focusNodes) f.dispose();
    super.dispose();
  }

  void _onChanged(String value, int index) {
    if (value.length == 1 && index < 5) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }
    setState(() {});
  }

  bool get _isOTPComplete =>
      _controllers.every((c) => c.text.isNotEmpty);

  Future<void> _handleContinue() async {
    final otp = _controllers.map((c) => c.text).join();

    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter complete 6 digit OTP'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    _showLoadingDialog();

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _currentVerificationId,
        smsCode: otp,
      );
      await _verifyWithCredential(credential);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _verifyWithCredential(PhoneAuthCredential credential) async {
    try {
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) return;

      // 🔑 Firebase ne unique UID assign ki — confirm karo
      debugPrint('✅ Firebase UID assigned (phone signup): ${user.uid}');
      debugPrint('   📱 Phone: ${user.phoneNumber ?? widget.phoneNumber}');

      // ✅ Firestore mein save — provider: 'phone' bhi add kiya
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'fullName': widget.userInfo['fullName'] ?? '',
        'email': widget.userInfo['email'] ?? '',
        'mobileNumber': widget.phoneNumber,
        'dateOfBirth': widget.userInfo['dateOfBirth'] ?? '',
        'uid': user.uid,
        'provider': 'phone', // ✅ yeh add kiya
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // ✅ merge: true taake purana data overwrite na ho

      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone verified successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const GenderScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isLoading = false);

      String msg;
      switch (e.code) {
        case 'invalid-verification-code':
          msg = 'Wrong OTP. Please check and try again.';
          break;
        case 'session-expired':
          msg = 'OTP expired. Please resend.';
          break;
        case 'invalid-verification-id':
          msg = 'Session expired. Please go back and try again.';
          break;
        default:
          msg = 'Verification failed: ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Data save failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleResendOTP() async {
    if (!_canResend || _isResending) return;

    setState(() => _isResending = true);

    await _auth.verifyPhoneNumber(
      phoneNumber: widget.phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _verifyWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() => _isResending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Resend failed: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _isResending = false;
          _currentVerificationId = verificationId;
        });

        for (var c in _controllers) c.clear();
        FocusScope.of(context).requestFocus(_focusNodes[0]);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP resent successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        _startCountdown();
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _currentVerificationId = verificationId;
      },
    );
  }

  void _showLoadingDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                height: 40,
                width: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(primaryBlue),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Verifying OTP...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Icon(
                  Icons.arrow_back_ios,
                  color: isDark ? Colors.white70 : Colors.grey,
                  size: 20,
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                'Enter OTP.',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: primaryBlue,
                  letterSpacing: 0.3,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Code sent to ${widget.phoneNumber}',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),

              const SizedBox(height: 48),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  return SizedBox(
                    width: 44,
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white38
                                : Colors.black38,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide:
                          BorderSide(color: primaryBlue, width: 2),
                        ),
                        contentPadding:
                        const EdgeInsets.only(bottom: 8),
                        isDense: true,
                      ),
                      onChanged: (value) => _onChanged(value, index),
                    ),
                  );
                }),
              ),

              const SizedBox(height: 24),

              Center(
                child: GestureDetector(
                  onTap: _canResend ? _handleResendOTP : null,
                  child: Text(
                    _isResending
                        ? 'SENDING...'
                        : _canResend
                        ? 'RESEND'
                        : 'RESEND IN $_countdownSeconds S',
                    style: TextStyle(
                      fontSize: 13,
                      color: _canResend
                          ? primaryBlue
                          : (isDark ? Colors.white38 : Colors.grey),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                  (_isOTPComplete && !_isLoading) ? _handleContinue : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    disabledBackgroundColor:
                    primaryBlue.withValues(alpha: 0.4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'CONTINUE',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}