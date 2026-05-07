import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wego_marriage/screen/login_screen.dart';
import 'app_localizations.dart';
import 'app_translations.dart';
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _passwordError;
  String? _confirmPasswordError;

  static const Color primaryBlue = Color(0xFF3D5AFE);

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_clearErrors);
    _confirmPasswordController.addListener(_clearErrors);
  }

  void _clearErrors() {
    if (_passwordError != null || _confirmPasswordError != null) {
      setState(() {
        _passwordError = null;
        _confirmPasswordError = null;
      });
    }
  }

  @override
  void dispose() {
    _passwordController.removeListener(_clearErrors);
    _confirmPasswordController.removeListener(_clearErrors);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleCreatePassword() async {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    setState(() {
      _passwordError = null;
      _confirmPasswordError = null;
    });

    if (password.isEmpty || confirm.isEmpty) {
      setState(() {
        _passwordError = 'Please enter your password';
        _confirmPasswordError = 'Please confirm your password';
      });
      return;
    }

    if (password.length < 6) {
      setState(() {
        _passwordError = 'Password must be at least 6 characters';
      });
      return;
    }

    if (password != confirm) {
      setState(() {
        _confirmPasswordError = 'Passwords do not match';
      });
      return;
    }

    // Save password to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_password', password);

    _showSnackbar('Password created successfully!');

    // Show loading animation
    _showLoadingDialog();

    // Simulate small delay then navigate
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.pop(context); // Remove loading dialog

    // Navigate to LoginScreen
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
      (route) => false,
    );
  }

  void _showLoadingDialog() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[900] : Colors.white,
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3D5AFE)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading...',
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

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // App Bar
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
                        'Set Password',
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

              const SizedBox(height: 24),

              // Description Text
              Text(
                'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod '
                    'tempor incididunt ut labore et dolore magna aliqua.',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                  fontSize: 13.5,
                  height: 1.5,
                  letterSpacing: 0.1,
                ),
              ),

              const SizedBox(height: 36),

              // Password Label
              _buildLabel('Password', isDark ? Colors.white : Colors.black),
              const SizedBox(height: 10),
              _buildPasswordField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                errorText: _passwordError,
                isDark: isDark,
                onToggle: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),

              const SizedBox(height: 28),

              // Confirm Password Label
              _buildLabel('Confirm Password', isDark ? Colors.white : Colors.black),
              const SizedBox(height: 10),
              _buildPasswordField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                errorText: _confirmPasswordError,
                isDark: isDark,
                onToggle: () {
                  setState(() => _obscureConfirm = !_obscureConfirm);
                },
              ),

              const SizedBox(height: 48),

              // Create New Password Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _handleCreatePassword,
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
                    'Create New Password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
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

  Widget _buildLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggle,
    required bool isDark,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFEEF0FF),
            borderRadius: BorderRadius.circular(14),
            border: errorText != null
                ? Border.all(color: Colors.red, width: 1.5)
                : null,
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 15,
              letterSpacing: 2,
            ),
            decoration: InputDecoration(
              hintText: '••••••••••••',
              hintStyle: TextStyle(
                color: isDark ? Colors.white30 : Colors.grey[400],
                fontSize: 15,
                letterSpacing: 3,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: isDark ? Colors.white70 : Colors.grey[500],
                  size: 22,
                ),
                onPressed: onToggle,
              ),
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
}