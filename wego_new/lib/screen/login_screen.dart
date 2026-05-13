import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wego_marriage/screen/home_feed_screen.dart';
import 'package:wego_marriage/screen/nbr_screen.dart';
import 'package:wego_marriage/screen/create_account.dart';
import 'package:wego_marriage/screen/xp_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ FIX: serverClientId add kiya — Google Sign-In ke liye zaroori
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  final LocalAuthentication _localAuth = LocalAuthentication();

  static const Color primaryBlue = Color(0xFF3D5AFE);
  static const Color lightBlue = Color(0xFF4D6FFF);

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

  void _goToHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomeFeedScreen()),
    );
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
          strokeWidth: 3,
        ),
      ),
    );
  }

  // ─── CHECK: Firestore mein account exist karta hai? ─────────────────────────
  Future<bool> _checkUserExistsInFirestore(String uid) async {
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      return docSnap.exists;
    } catch (e) {
      debugPrint('Firestore check error: $e');
      return false;
    }
  }

  // ─── Update lastLogin only ───────────────────────────────────────────────────
  Future<void> _updateLastLogin(String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'lastLogin': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint('lastLogin update error: $e');
    }
  }

  // ─── User ka purana level Firestore se fetch karo ─────────────────────────
  // Agar level/XP fields purane account mein missing hain, to safe defaults
  // se initialize karta hai — taake purana level kabhi reset na ho.
  Future<int> _restoreUserLevel(String uid) async {
    try {
      final docRef =
          FirebaseFirestore.instance.collection('users').doc(uid);
      final snap = await docRef.get();
      if (!snap.exists) return 1;

      final data = snap.data() ?? {};
      final int existingLevel =
          (data['level'] as num?)?.toInt() ?? 0;

      // Agar level field set hi nahi hui kabhi, to initialize karo (1 se).
      // Existing user ka level NEVER overwrite hota — sirf missing fields fill.
      final Map<String, dynamic> initData = {};
      if (data['level'] == null) initData['level'] = 1;
      if (data['levelXP'] == null) initData['levelXP'] = 0;
      if (data['levelXPRequired'] == null) {
        initData['levelXPRequired'] = 10000;
      }
      if (data['totalXPEarned'] == null) initData['totalXPEarned'] = 0;
      if (data['rewards'] == null) {
        initData['rewards'] = <String, dynamic>{};
      }
      if (initData.isNotEmpty) {
        await docRef.set(initData, SetOptions(merge: true));
      }

      final int restored = existingLevel > 0 ? existingLevel : 1;
      debugPrint('🎯 User level restored: Lv $restored');
      return restored;
    } catch (e) {
      debugPrint('restoreUserLevel error: $e');
      return 1;
    }
  }

  // ─── Email/Password Login ────────────────────────────────────────────────────
  Future<void> _handleLogin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('location_asked');
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    final emailError = _validateEmail(email);
    if (emailError != null) {
      setState(() => _emailError = emailError);
      return;
    }

    final passwordError = _validatePassword(password);
    if (passwordError != null) {
      setState(() => _passwordError = passwordError);
      return;
    }

    setState(() => _isLoading = true);
    _showLoadingDialog();

    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _updateLastLogin(userCredential.user!.uid);

      // 🔄 Purana level Firebase se restore karo (kabhi reset nahi hota)
      await _restoreUserLevel(userCredential.user!.uid);

      // 🎁 Daily Login XP
      await XPService.addXP(userCredential.user!.uid, XPAction.dailyLogin);

      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login successful!'),
          backgroundColor: Colors.green,
        ),
      );
      _goToHome();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isLoading = false);

      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'No account found with this email.';
          break;
        case 'wrong-password':
          msg = 'Incorrect password.';
          break;
        case 'invalid-email':
          msg = 'Invalid email address.';
          break;
        case 'user-disabled':
          msg = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          msg = 'Too many failed attempts. Try again later.';
          break;
        case 'invalid-credential':
          msg = 'Email or password is incorrect.';
          break;
        default:
          msg = 'Login failed: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ─── Google Sign-In ──────────────────────────────────────────────────────────
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    _showLoadingDialog();

    try {
      // ✅ Pehle sign out karo taake fresh account picker aaye
      await _googleSignIn.signOut();
      await _auth.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User ne cancel kiya
        if (!mounted) return;
        Navigator.pop(context);
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      // ✅ Token check
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        if (!mounted) return;
        Navigator.pop(context);
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google tokens not received. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
      await _auth.signInWithCredential(credential);
      final user = userCredential.user!;

      // ✅ Firestore mein account check
      final bool exists = await _checkUserExistsInFirestore(user.uid);

      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isLoading = false);

      if (!exists) {
        await _auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No account found. Please sign up first.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      await _updateLastLogin(user.uid);

      // 🔄 Purana level Firebase se restore karo (kabhi reset nahi hota)
      await _restoreUserLevel(user.uid);

      // 🎁 Daily Login XP (Google) — service khud din mein ek baar de gi
      await XPService.addXP(user.uid, XPAction.dailyLogin);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome ${user.displayName ?? 'User'}!'),
          backgroundColor: Colors.green,
        ),
      );
      _goToHome();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google login error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google Sign-In failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Facebook Sign-In ────────────────────────────────────────────────────────
  Future<void> _handleFacebookSignIn() async {
    setState(() => _isLoading = true);
    _showLoadingDialog();

    try {
      await FacebookAuth.instance.logOut();

      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.cancelled) {
        if (!mounted) return;
        Navigator.pop(context);
        setState(() => _isLoading = false);
        return;
      }

      if (result.status != LoginStatus.success) {
        if (!mounted) return;
        Navigator.pop(context);
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Facebook login failed: ${result.message}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (result.accessToken == null) {
        if (!mounted) return;
        Navigator.pop(context);
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Facebook access token not received.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final OAuthCredential facebookCredential =
      FacebookAuthProvider.credential(result.accessToken!.tokenString);

      final UserCredential userCredential =
      await _auth.signInWithCredential(facebookCredential);
      final user = userCredential.user!;

      final bool exists = await _checkUserExistsInFirestore(user.uid);

      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isLoading = false);

      if (!exists) {
        await _auth.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No account found. Please sign up first.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      await _updateLastLogin(user.uid);

      // 🔄 Purana level Firebase se restore karo (kabhi reset nahi hota)
      await _restoreUserLevel(user.uid);

      // 🎁 Daily Login XP (Facebook) — service khud din mein ek baar de gi
      await XPService.addXP(user.uid, XPAction.dailyLogin);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Welcome ${user.displayName ?? 'User'}!'),
          backgroundColor: Colors.green,
        ),
      );
      _goToHome();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Facebook error: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Facebook Sign-In failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Biometric Authentication ────────────────────────────────────────────────
  Future<void> _handleBiometricAuth() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text('Biometric authentication not available on this device.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final List<BiometricType> availableBiometrics =
      await _localAuth.getAvailableBiometrics();

      if (availableBiometrics.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No biometrics enrolled. Please set up fingerprint in device settings.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Scan your fingerprint to log in',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;

      if (authenticated) {
        final User? currentUser = _auth.currentUser;

        if (currentUser != null) {
          final bool exists =
          await _checkUserExistsInFirestore(currentUser.uid);
          if (!exists) {
            await _auth.signOut();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No account found. Please sign up first.'),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          await _updateLastLogin(currentUser.uid);

          // 🔄 Purana level Firebase se restore karo
          await _restoreUserLevel(currentUser.uid);

          // 🎁 Daily Login XP (Biometric)
          await XPService.addXP(currentUser.uid, XPAction.dailyLogin);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Welcome back ${currentUser.displayName ?? currentUser.email}!'),
              backgroundColor: Colors.green,
            ),
          );
          _goToHome();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Please login with email or social account first to enable biometric login.'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
            Text('Biometric authentication failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Biometric error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ─── Validators ──────────────────────────────────────────────────────────────
  String? _validateEmail(String email) {
    if (email.isEmpty) return 'Please enter your email';
    if (!email.contains('@')) return 'Email must contain @ symbol';
    if (email.toLowerCase().contains('.con')) return 'Did you mean .com?';
    final generalEmailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!generalEmailRegex.hasMatch(email))
      return 'Please enter a valid email address';
    if (email.contains(' ')) return 'Email cannot contain spaces';
    if (email.contains('..')) return 'Email cannot contain consecutive dots';
    return null;
  }

  String? _validatePassword(String password) {
    if (password.isEmpty) return 'Please enter your password';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  // ─── UI Build ────────────────────────────────────────────────────────────────
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
                    icon:
                    Icon(Icons.arrow_back_ios, color: textColor, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const Expanded(
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
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const NbrScreen()),
                    );
                  },
                  child: const Text(
                    'Forget Password',
                    style: TextStyle(color: lightBlue, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
                    onTap: _isLoading ? () {} : _handleGoogleSignIn,
                  ),
                  const SizedBox(width: 20),
                  _buildSocialButton(
                    context: context,
                    icon: Icons.facebook_rounded,
                    iconSize: 24,
                    onTap: _isLoading ? () {} : _handleFacebookSignIn,
                  ),
                  const SizedBox(width: 20),
                  _buildSocialButton(
                    context: context,
                    icon: Icons.fingerprint,
                    iconSize: 24,
                    onTap: _isLoading ? () {} : _handleBiometricAuth,
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
                          builder: (context) => const CreateAccountScreen()),
                    );
                  },
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      children: [
                        TextSpan(text: "Don't have an account? "),
                        TextSpan(
                          text: 'Sign Up',
                          style: TextStyle(
                            color: lightBlue,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
                  : (isDark
                  ? const Color(0xFF2A2A4A)
                  : Colors.grey[300]!),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[600], fontSize: 15),
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
              style: const TextStyle(color: Colors.red, fontSize: 12),
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
          color: const Color(0xFF6B7FD4),
          size: iconSize,
        ),
      ),
    );
  }
}