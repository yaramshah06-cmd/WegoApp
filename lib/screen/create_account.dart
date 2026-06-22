import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  bool _obscurePassword = true;

  static const Color primaryBlue = Color(0xFF7A1730);
  static const Color lightBlue = Color(0xFFC2415E);

  @override
  void dispose() {
    _fullNameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark 
                ? const ColorScheme.dark(
                    primary: primaryBlue,
                    onPrimary: Colors.white,
                    onSurface: Colors.white,
                  )
                : const ColorScheme.light(
                    primary: primaryBlue,
                    onPrimary: Colors.white,
                    onSurface: Colors.black,
                  ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
        '${picked.day.toString().padLeft(2, '0')} / '
            '${picked.month.toString().padLeft(2, '0')} / '
            '${picked.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Bar Row
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.maybePop(context),
                    icon: Icon(Icons.arrow_back_ios,
                        color: isDark ? Colors.white : primaryBlue, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'New Account',
                        style: TextStyle(
                          color: isDark ? Colors.white : primaryBlue,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),

              const SizedBox(height: 28),

              // Full Name
              _buildLabel('Full name', isDark),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _fullNameController,
                hint: 'John Doe',
                keyboardType: TextInputType.name,
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              // Password
              _buildLabel('Password', isDark),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _passwordController,
                hint: '••••••••••••',
                obscureText: _obscurePassword,
                isDark: isDark,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: isDark ? Colors.white54 : Colors.grey[500],
                    size: 22,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),

              const SizedBox(height: 20),

              // Email
              _buildLabel('Email', isDark),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _emailController,
                hint: 'example@example.com',
                keyboardType: TextInputType.emailAddress,
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              // Mobile Number
              _buildLabel('Mobile Number', isDark),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _mobileController,
                hint: '+1 234 567 890',
                keyboardType: TextInputType.phone,
                isDark: isDark,
              ),

              const SizedBox(height: 20),

              // Date of Birth
              _buildLabel('Date Of Birth', isDark),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: _buildTextField(
                    controller: _dobController,
                    hint: 'DD / MM / YYY',
                    hintColor: isDark ? Colors.white54 : primaryBlue,
                    isDark: isDark,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Terms Text
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey[600],
                      fontSize: 12.5,
                    ),
                    children: [
                      const TextSpan(text: 'By continuing, you agree to\n'),
                      TextSpan(
                        text: 'Terms of Use',
                        style: TextStyle(
                          color: isDark ? Colors.white : primaryBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy.',
                        style: TextStyle(
                          color: isDark ? Colors.white : primaryBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Sign Up Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 4,
                    shadowColor: primaryBlue.withValues(alpha: 0.4),
                  ),
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Or sign up with
              Center(
                child: Text(
                  'or sign up with',
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Social Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildSocialButton(
                    icon: Icons.g_mobiledata_rounded,
                    iconSize: 28,
                    onTap: () {},
                    isDark: isDark,
                  ),
                  const SizedBox(width: 20),
                  _buildSocialButton(
                    icon: Icons.facebook_rounded,
                    iconSize: 24,
                    onTap: () {},
                    isDark: isDark,
                  ),
                  const SizedBox(width: 20),
                  _buildSocialButton(
                    icon: Icons.chat_bubble_rounded,
                    iconSize: 24,
                    onTap: _handleWeChatSignUp,
                    isDark: isDark,
                  ),
                  const SizedBox(width: 20),
                  _buildSocialButton(
                    icon: Icons.fingerprint,
                    iconSize: 24,
                    onTap: () {},
                    isDark: isDark,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Already have an account
              Center(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey[600],
                      fontSize: 13.5,
                    ),
                    children: [
                      const TextSpan(text: 'already have an account? '),
                      TextSpan(
                        text: 'Log in',
                        style: TextStyle(
                          color: isDark ? Colors.white : lightBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // WeChat Sign-Up
  void _handleWeChatSignUp() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('WeChat Sign-Up will be available soon'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    Color? hintColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : const Color(0xFFFBEAEE),
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: hintColor ?? (isDark ? Colors.white38 : Colors.grey[400]),
            fontSize: 14.5,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    double iconSize = 24,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white24 : const Color(0xFFFBEAEE),
            width: 1.5,
          ),
          color: isDark ? Colors.grey[900] : const Color(0xFFFBEAEE),
        ),
        child: Icon(
          icon,
          color: isDark ? Colors.white : const Color(0xFF7A1730),
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

    // Check for spaces
    if (email.contains(' ')) {
      return 'Email cannot contain spaces';
    }

    // Check for double dots
    if (email.contains('..')) {
      return 'Email cannot contain consecutive dots';
    }

    // Validate email format
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // Strong password validation
  String? _validateStrongPassword(String password) {
    if (password.isEmpty) {
      return 'Please enter a password';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    // Check for at least one uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    // Check for at least one lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    // Check for at least one number
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    // Check for at least one special character
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character (!@#\$%^&*)';
    }

    // Check for spaces
    if (password.contains(' ')) {
      return 'Password cannot contain spaces';
    }

    return null;
  }

  void _handleSignUp() async {
    final name = _fullNameController.text.trim();
    final password = _passwordController.text;
    final email = _emailController.text.trim();
    final mobile = _mobileController.text.trim();
    final dob = _dobController.text.trim();

    if (name.isEmpty ||
        password.isEmpty ||
        email.isEmpty ||
        mobile.isEmpty ||
        dob.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate email
    final emailError = _validateEmail(email);
    if (emailError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(emailError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validate strong password
    final passwordError = _validateStrongPassword(password);
    if (passwordError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(passwordError),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      // 1. Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // 2. Real Firebase Sign-Up
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      // 3. Update Profile (Name)
      await userCredential.user?.updateDisplayName(name);

      // 4. Save extra info to SharedPreferences (optional, but good for offline)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setString('user_email', email);

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully in Firebase!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to login or home
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      String message = 'An error occurred';
      if (e.code == 'weak-password') {
        message = 'The password provided is too weak.';
      } else if (e.code == 'email-already-in-use') {
        message = 'The account already exists for that email.';
      } else {
        message = e.message ?? message;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }
}
