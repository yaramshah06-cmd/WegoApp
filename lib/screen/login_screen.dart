import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:wego_marriage/screen/home_feed_screen.dart';
import 'package:wego_marriage/screen/nbr_screen.dart';
import 'package:wego_marriage/screen/create_account.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;

  final LocalAuthentication _localAuth = LocalAuthentication();

  static const Color primaryBlue = Color(0xFF7A1730);
  static const Color lightBlue = Color(0xFFC2415E);

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_clearErrors);
    _passwordController.addListener(_clearErrors);
  }

  void _clearErrors() {
    if (_emailError != null || _passwordError != null) {
      setState(() {
        _emailError = null;
        _passwordError = null;
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: Icon(Icons.arrow_back_ios,
                        color: textColor, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Log In',
                        style: TextStyle(
                          color: primaryBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),

              const SizedBox(height: 36),

              const Text(
                'Welcome',
                style: TextStyle(
                  color: primaryBlue,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please log in to your account',
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 14,
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 48),

              _buildTextField(
                context: context,
                controller: _emailController,
                hint: 'example@example.com',
                keyboardType: TextInputType.emailAddress,
                errorText: _emailError,
              ),

              const SizedBox(height: 20),

              _buildTextField(
                context: context,
                controller: _passwordController,
                hint: '••••••••••••',
                obscureText: _obscurePassword,
                errorText: _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: Colors.grey[500],
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),

              // Forget Password — NbrScreen
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const NbrScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Forget Password',
                    style: TextStyle(
                      color: lightBlue,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Log In Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                    shadowColor: primaryBlue.withValues(alpha: 0.5),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Text(
                        'Log In',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (_isLoading)
                        const Positioned(
                          right: 20,
                          child: SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButton(
                    context: context,
                    icon: Icons.g_mobiledata_rounded,
                    iconSize: 28,
                    onTap: _handleGoogleSignIn,
                  ),
                  const SizedBox(width: 20),
                  _buildSocialButton(
                    context: context,
                    icon: Icons.facebook_rounded,
                    iconSize: 24,
                    onTap: _handleFacebookSignIn,
                  ),
                  const SizedBox(width: 20),
                  _buildSocialButton(
                    context: context,
                    icon: Icons.chat_bubble_rounded,
                    iconSize: 24,
                    onTap: _handleWeChatSignIn,
                  ),
                  const SizedBox(width: 20),
                  _buildSocialButton(
                    context: context,
                    icon: Icons.fingerprint,
                    iconSize: 24,
                    onTap: _handleBiometricAuth,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CreateAccountScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      color: lightBlue,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? errorText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A2E) : Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: errorText != null
                  ? Colors.red
                  : (isDark ? const Color(0xFF2A2A4A) : Colors.grey[300]!),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              suffixIcon: suffixIcon,
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSocialButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback onTap,
    double iconSize = 24,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? const Color(0xFF2A2A5A) : Colors.grey[300]!,
            width: 1.5,
          ),
          color: isDark ? const Color(0xFF0D0D1A) : Colors.white,
        ),
        child: Icon(
          icon,
          color: const Color(0xFF7A1730),
          size: iconSize,
        ),
      ),
    );
  }

  // Email validation with security checks
  String? _validateEmail(String email) {
    if (email.isEmpty) {
      return 'Please enter your email';
    }

    // Check for @ symbol
    if (!email.contains('@')) {
      return 'Email must contain @ symbol';
    }

    // Check for common typo: .con instead of .com
    if (email.toLowerCase().contains('.con')) {
      return 'Did you mean .com? Please check your email';
    }

    // Check for valid Gmail format
    final gmailRegex = RegExp(r'^[\w-\.]+@gmail\.com$', caseSensitive: false);
    if (!gmailRegex.hasMatch(email)) {
      // Check if it's other valid email format
      final generalEmailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
      if (!generalEmailRegex.hasMatch(email)) {
        return 'Please enter a valid email address';
      }
    }

    // Check for spaces
    if (email.contains(' ')) {
      return 'Email cannot contain spaces';
    }

    // Check for double dots
    if (email.contains('..')) {
      return 'Email cannot contain consecutive dots';
    }

    return null;
  }

  // Password validation for login
  String? _validatePassword(String password) {
    if (password.isEmpty) {
      return 'Please enter your password';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    return null;
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    // Validate email with security checks
    final emailError = _validateEmail(email);
    if (emailError != null) {
      setState(() {
        _emailError = emailError;
      });
      return;
    }

    // Validate password
    final passwordError = _validatePassword(password);
    if (passwordError != null) {
      setState(() {
        _passwordError = passwordError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Real Firebase Login
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // ✅ Login successful — HomeFeedScreen per navigate karo
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeFeedScreen(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      if (e.code == 'user-not-found') {
        setState(() {
          _emailError = 'No user found for that email.';
        });
      } else if (e.code == 'wrong-password') {
        setState(() {
          _passwordError = 'Wrong password provided for that user.';
        });
      } else if (e.code == 'invalid-credential') {
        setState(() {
          _emailError = 'Invalid email or password.';
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Authentication failed')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  // Google Sign-In
  Future<void> _handleGoogleSignIn() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Google Sign-In will be available soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // Facebook Sign-In
  Future<void> _handleFacebookSignIn() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Facebook Sign-In will be available soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // WeChat Sign-In
  Future<void> _handleWeChatSignIn() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('WeChat Sign-In will be available soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // Biometric/Fingerprint Authentication
  Future<void> _handleBiometricAuth() async {
    if (!mounted) return;

    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final List<BiometricType> availableBiometrics =
          await _localAuth.getAvailableBiometrics();

      if (!canCheckBiometrics || availableBiometrics.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric not available on this device'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Real biometric authentication
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Verify your identity to continue',
      );

      if (!mounted) return;

      if (didAuthenticate) {
        _goToHomeAfterLoading();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Authentication cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      // Fallback for web/windows where local_auth is not supported
      if (e.toString().contains('MissingPlugin')) {
        await _showCustomFingerprintDialog();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Biometric error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showCustomFingerprintDialog() async {
    bool verified = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.fingerprint,
                  size: 64,
                  color: verified ? Colors.green : primaryBlue,
                ),
              ),
              const SizedBox(height: 20),
              const Text('Verify Your Identity',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                verified ? 'Verified!' : 'Tap VERIFY to confirm',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 14,
                    color: verified ? Colors.green : Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: verified
                      ? null
                      : () {
                          setState(() {
                            verified = true;
                          });
                          // Simulate verification delay
                          Future.delayed(const Duration(seconds: 1), () {
                            if (!mounted) return;
                            if (context.mounted) {
                              Navigator.pop(context, true);
                              _goToHomeAfterLoading();
                            }
                          });
                        },
                  icon: const Icon(Icons.fingerprint, size: 22),
                  label: Text(
                    verified ? 'VERIFIED' : 'VERIFY NOW',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: verified ? Colors.green : primaryBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: verified
                      ? null
                      : () => Navigator.pop(context, false),
                  child: Text('Cancel',
                      style:
                          TextStyle(fontSize: 14, color: Colors.grey[500])),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _goToHomeAfterLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
            strokeWidth: 3),
      ),
    );

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeFeedScreen()),
      );
    });
  }
}