import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:local_auth/local_auth.dart';
import 'package:geolocator/geolocator.dart'; // ✅ Real GPS location
import 'otp_screen.dart';
import 'package:wego_marriage/screen/user_gendar.dart';
import 'package:wego_marriage/screen/home_feed_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _mobileController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  final LocalAuthentication _localAuth = LocalAuthentication();

  // ─── Suggested / Search State ────────────────────────────────
  List<Map<String, dynamic>> _suggestedUsers = [];
  List<Map<String, dynamic>> _liveSuggestions = [];
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void dispose() {
    _fullNameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _mobileController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _navigateToGenderScreen() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const GenderScreen()),
    );
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeFeedScreen()),
          (route) => false,
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ✅ Real GPS Location fetch karna
  // ══════════════════════════════════════════════════════════════
  Future<Map<String, double>> _getRealLocation() async {
    // Default fallback — sirf tab use hoga jab permission deny ho
    const double fallbackLat = 0.0;
    const double fallbackLng = 0.0;

    try {
      // 1. Location service check
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('⚠️ Location services are disabled.');
        return {'latitude': fallbackLat, 'longitude': fallbackLng};
      }

      // 2. Permission check
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('⚠️ Location permission denied.');
          return {'latitude': fallbackLat, 'longitude': fallbackLng};
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ Location permission permanently denied.');
        // User ko settings mein jaana hoga
        if (mounted) {
          _showError(
            'Location permission permanently denied. Please enable it from app settings.',
          );
        }
        return {'latitude': fallbackLat, 'longitude': fallbackLng};
      }

      // 3. Real location fetch
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      debugPrint(
        '✅ Real location: lat=${position.latitude}, lng=${position.longitude}',
      );

      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
      };
    } catch (e) {
      debugPrint('Location error: $e');
      return {'latitude': fallbackLat, 'longitude': fallbackLng};
    }
  }

  // ══════════════════════════════════════════════════════════════
  // ✅ Migrate user from old 'user' collection to 'users'
  // ══════════════════════════════════════════════════════════════
  Future<void> _migrateUserIfNeeded(String uid) async {
    try {
      final newDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!newDoc.exists) {
        final oldDoc = await FirebaseFirestore.instance
            .collection('user')
            .doc(uid)
            .get();

        if (oldDoc.exists) {
          final data = oldDoc.data()!;
          final fullName = data['fullName'] ?? '';

          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            ...data,
            'username': fullName,
            'username_lower': fullName.toString().toLowerCase(),
            'uid': uid,
          }, SetOptions(merge: true));

          debugPrint('✅ User migrated: $uid');
        } else {
          debugPrint('ℹ️ No old data found for uid: $uid');
        }
      } else {
        debugPrint('ℹ️ User already in new collection: $uid');
      }
    } catch (e) {
      debugPrint('Migration error: $e');
    }
  }

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

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  // ─── Save User to Firestore ──────────────────────────────────
  Future<bool> _saveUserToFirestore({
    required String uid,
    required String fullName,
    required String email,
    required String mobileNumber,
    required int age,
    required String provider,
    String photoUrl = '',
  }) async {
    try {
      final username = fullName.trim();
      final usernameLower = username.toLowerCase();

      // ✅ Real GPS location fetch karo
      final location = await _getRealLocation();

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fullName': fullName,
        'username': username,
        'username_lower': usernameLower,
        'email': email,
        'mobileNumber': mobileNumber,
        'age': age,
        'photoUrl': photoUrl,
        'bio': '',
        'uid': uid,
        'provider': provider,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        // ✅ Real location — har user ki apni actual GPS location
        'latitude': location['latitude'],
        'longitude': location['longitude'],
      }, SetOptions(merge: true));

      return true;
    } catch (e) {
      _showError('Failed to save data: ${e.toString()}');
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Suggested Users
  // ══════════════════════════════════════════════════════════════
  Future<void> _fetchSuggestedUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      if (!mounted) return;
      setState(() {
        _suggestedUsers = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      debugPrint('fetchSuggestedUsers error: $e');
    }
  }

  Future<void> _fetchLiveSuggestions(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _liveSuggestions = []);
      return;
    }

    try {
      final lowerQuery = query.trim().toLowerCase();

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username_lower', isGreaterThanOrEqualTo: lowerQuery)
          .where('username_lower', isLessThan: '${lowerQuery}z')
          .limit(5)
          .get();

      if (!mounted) return;
      setState(() {
        _liveSuggestions = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
    } catch (e) {
      debugPrint('fetchLiveSuggestions error: $e');
    }
  }

  Future<void> _performFullSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final lowerQuery = query.trim().toLowerCase();

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('username_lower', isGreaterThanOrEqualTo: lowerQuery)
          .where('username_lower', isLessThan: '${lowerQuery}z')
          .orderBy('username_lower')
          .limit(20)
          .get();

      if (!mounted) return;
      setState(() {
        _searchResults = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('performFullSearch error: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // ─── Google Sign In ──────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // NAYA — sahi
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      await googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
      await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        setState(() => _isLoading = false);
        _showError('Google authentication tokens not received.');
        return;
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user!;

      await _migrateUserIfNeeded(user.uid);

      setState(() => _isLoading = false);

      final bool alreadyExists = await _checkUserExistsInFirestore(user.uid);

      if (alreadyExists) {
        // ✅ Real location se lastLogin aur location update karo
        final location = await _getRealLocation();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'lastLogin': FieldValue.serverTimestamp(),
          'latitude': location['latitude'],
          'longitude': location['longitude'],
        });

        _showSuccess('Welcome back ${user.displayName ?? 'User'}!');
        _navigateToHome();
        return;
      }

      final bool? confirmed = await _showSocialConfirmDialog(
        name: user.displayName ?? 'Unknown',
        email: user.email ?? '',
        provider: 'Google',
        photoUrl: user.photoURL,
      );

      if (confirmed != true) {
        await FirebaseAuth.instance.signOut();
        return;
      }

      setState(() => _isLoading = true);
      final bool saved = await _saveUserToFirestore(
        uid: user.uid,
        fullName: user.displayName ?? '',
        email: user.email ?? '',
        mobileNumber: user.phoneNumber ?? '',
        age: 0,
        provider: 'google',
        photoUrl: user.photoURL ?? '',
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (saved) {
        _showSuccess('Account created with Google!');
        _navigateToGenderScreen();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Google login error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Google login failed: ${e.toString()}');
    }
  }

  // ─── Facebook Sign In ────────────────────────────────────────
  Future<void> _signInWithFacebook() async {
    setState(() => _isLoading = true);
    try {
      await FacebookAuth.instance.logOut();

      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['email', 'public_profile'],
      );

      if (result.status == LoginStatus.cancelled) {
        setState(() => _isLoading = false);
        return;
      }

      if (result.status != LoginStatus.success) {
        setState(() => _isLoading = false);
        _showError('Facebook login failed: ${result.message}');
        return;
      }

      if (result.accessToken == null) {
        setState(() => _isLoading = false);
        _showError('Facebook access token not received.');
        return;
      }

      final OAuthCredential facebookCredential =
      FacebookAuthProvider.credential(result.accessToken!.tokenString);

      final UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(facebookCredential);
      final user = userCredential.user!;

      final userData = await FacebookAuth.instance.getUserData(
        fields: 'name,email,picture.width(200)',
      );

      final String fbName = userData['name'] ?? user.displayName ?? '';
      final String fbEmail = userData['email'] ?? user.email ?? '';
      final String fbPhoto =
          userData['picture']?['data']?['url'] ?? user.photoURL ?? '';

      await _migrateUserIfNeeded(user.uid);

      setState(() => _isLoading = false);

      final bool alreadyExists = await _checkUserExistsInFirestore(user.uid);

      if (alreadyExists) {
        // ✅ Real location se update karo
        final location = await _getRealLocation();
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'lastLogin': FieldValue.serverTimestamp(),
          'latitude': location['latitude'],
          'longitude': location['longitude'],
        });

        _showSuccess(
            'Welcome back ${fbName.isNotEmpty ? fbName : 'User'}!');
        _navigateToHome();
        return;
      }

      final bool? confirmed = await _showSocialConfirmDialog(
        name: fbName,
        email: fbEmail,
        provider: 'Facebook',
        photoUrl: fbPhoto,
      );

      if (confirmed != true) {
        await FirebaseAuth.instance.signOut();
        return;
      }

      setState(() => _isLoading = true);
      final bool saved = await _saveUserToFirestore(
        uid: user.uid,
        fullName: fbName,
        email: fbEmail,
        mobileNumber: user.phoneNumber ?? '',
        age: 0,
        provider: 'facebook',
        photoUrl: fbPhoto,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (saved) {
        _showSuccess('Account created with Facebook!');
        _navigateToGenderScreen();
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Facebook error: ${e.message}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Facebook login failed: ${e.toString()}');
    }
  }

  // ─── Phone OTP Sign Up ───────────────────────────────────────
  Future<void> _onSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String rawPhone = _mobileController.text.trim();
    String phoneNumber;

    if (rawPhone.startsWith('+')) {
      phoneNumber = rawPhone;
    } else if (rawPhone.startsWith('0')) {
      phoneNumber = '+92${rawPhone.substring(1)}';
    } else {
      phoneNumber = '+92$rawPhone';
    }

    final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length < 11 || digitsOnly.length > 12) {
      setState(() => _isLoading = false);
      _showError('Invalid mobile number. Example: 03001234567');
      return;
    }

    final String fullName = _fullNameController.text.trim();
    final int age = int.tryParse(_ageController.text.trim()) ?? 0;

    // ✅ Real location fetch karo OTP se pehle
    final location = await _getRealLocation();

    final Map<String, dynamic> userInfo = {
      'fullName': fullName,
      'username': fullName,
      'username_lower': fullName.toLowerCase(),
      'email': _emailController.text.trim(),
      'mobileNumber': phoneNumber,
      'age': age,
      'password': _passwordController.text.trim(),
      'bio': '',
      // ✅ Real location — hardcoded Rawalpindi nahi
      'latitude': location['latitude'],
      'longitude': location['longitude'],
    };

    bool otpSent = false;

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!mounted || otpSent) return;
          otpSent = true;
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(
                verificationId: '',
                phoneNumber: phoneNumber,
                userInfo: userInfo,
                autoCredential: credential,
              ),
            ),
          );
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          String errorMsg;
          switch (e.code) {
            case 'invalid-phone-number':
              errorMsg = 'Invalid phone number format.';
              break;
            case 'too-many-requests':
              errorMsg = 'Too many requests. Please try again later.';
              break;
            case 'app-not-authorized':
              errorMsg = 'App not authorized. Check SHA-1 fingerprint.';
              break;
            case 'quota-exceeded':
              errorMsg = 'SMS quota exceeded. Please try again tomorrow.';
              break;
            case 'network-request-failed':
              errorMsg = 'No internet connection.';
              break;
            case 'billing-not-enabled':
              errorMsg =
              'Firebase billing not enabled. Please upgrade to Blaze plan.';
              break;
            default:
              errorMsg = e.message ?? 'Verification failed. (${e.code})';
          }
          _showError(errorMsg);
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted || otpSent) return;
          otpSent = true;
          setState(() => _isLoading = false);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => OtpScreen(
                verificationId: verificationId,
                phoneNumber: phoneNumber,
                userInfo: userInfo,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('An error occurred: ${e.toString()}');
    }
  }

  // ─── Fingerprint Auth ────────────────────────────────────────
  Future<void> _signInWithFingerprint() async {
    setState(() => _isLoading = true);
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        setState(() => _isLoading = false);
        _showError('This device does not support biometric authentication.');
        return;
      }

      final List<BiometricType> availableBiometrics =
      await _localAuth.getAvailableBiometrics();

      if (availableBiometrics.isEmpty) {
        setState(() => _isLoading = false);
        _showError(
            'No biometrics enrolled. Please add a fingerprint in device settings.');
        return;
      }

      final bool authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to confirm sign up',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!authenticated) {
        _showError('Fingerprint did not match. Please try again.');
        return;
      }

      if (!_formKey.currentState!.validate()) {
        _showError(
            'Fingerprint verified! Please complete the form to continue.');
        return;
      }

      _showSuccess('Fingerprint verified! Sending OTP...');
      await _onSignUp();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Fingerprint error: $e');
    }
  }

  // ─── Social Confirm Dialog ───────────────────────────────────
  Future<bool?> _showSocialConfirmDialog({
    required String name,
    required String email,
    required String provider,
    String? photoUrl,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirm $provider Account',
          style: const TextStyle(
            color: Color(0xFF4040FF),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 36,
              backgroundColor: const Color(0xFFEAEAFF),
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                  ? NetworkImage(photoUrl)
                  : null,
              child: (photoUrl == null || photoUrl.isEmpty)
                  ? const Icon(Icons.person, size: 36, color: Color(0xFF4040FF))
                  : null,
            ),
            const SizedBox(height: 12),
            Text(name,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(email,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            const Text(
              'Do you want to sign up with this account?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4040FF),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child:
            const Text('Confirm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ─── UI Build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF4040FF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'New Account',
          style: TextStyle(
            color: Color(0xFF4040FF),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Full Name'),
              _buildTextField(
                controller: _fullNameController,
                hint: 'Enter your full name',
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Full name is required'
                    : null,
              ),
              const SizedBox(height: 16),
              _buildLabel('Password'),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: _inputDecoration('••••••••••••').copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty)
                    return 'Password is required';
                  if (val.length < 6)
                    return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildLabel('Email (Optional)'),
              _buildTextField(
                controller: _emailController,
                hint: 'example@example.com',
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val != null && val.isNotEmpty) {
                    final emailRegex =
                    RegExp(r'^[\w-.]+@([\w-]+\.)+[\w]{2,4}$');
                    if (!emailRegex.hasMatch(val))
                      return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildLabel('Mobile Number'),
              _buildTextField(
                controller: _mobileController,
                hint: '03XXXXXXXXX',
                keyboardType: TextInputType.phone,
                validator: (val) {
                  if (val == null || val.trim().isEmpty)
                    return 'Mobile number is required';
                  final cleaned = val.trim().replaceAll(RegExp(r'\s+'), '');
                  if (cleaned.length < 10 || cleaned.length > 11) {
                    return 'Please enter a valid mobile number (e.g. 03001234567)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _buildLabel('Age'),
              _buildTextField(
                controller: _ageController,
                hint: 'Enter your age (e.g. 25)',
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty)
                    return 'Age is required';
                  final age = int.tryParse(val.trim());
                  if (age == null || age < 18 || age > 100)
                    return 'Please enter a valid age (18–100)';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: const TextSpan(
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    children: [
                      TextSpan(text: 'By continuing, you agree to our\n'),
                      TextSpan(
                        text: 'Terms of Use',
                        style: TextStyle(color: Color(0xFF4040FF)),
                      ),
                      TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: TextStyle(color: Color(0xFF4040FF)),
                      ),
                      TextSpan(text: '.'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _onSignUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4040FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    'Sign Up',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text('or sign up with',
                    style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _isLoading ? null : _signInWithGoogle,
                    child: _googleButton(),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _isLoading ? null : _signInWithFacebook,
                    child: _facebookButton(),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _isLoading ? null : _signInWithFingerprint,
                    child: _socialIconButton(Icons.fingerprint),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      children: [
                        TextSpan(text: 'Already have an account? '),
                        TextSpan(
                          text: 'Log In',
                          style: TextStyle(
                            color: Color(0xFF4040FF),
                            fontWeight: FontWeight.bold,
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

  Widget _buildLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text,
        style:
        const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: _inputDecoration(hint),
        validator: validator,
      );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Colors.grey),
    filled: true,
    fillColor: const Color(0xFFF0F0FF),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );

  Widget _googleButton() => CircleAvatar(
    radius: 24,
    backgroundColor: const Color(0xFFEAEAFF),
    child: const Text(
      'G',
      style: TextStyle(
        color: Color(0xFF4040FF),
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    ),
  );

  Widget _facebookButton() => CircleAvatar(
    radius: 24,
    backgroundColor: const Color(0xFF1877F2),
    child: const FaIcon(
      FontAwesomeIcons.facebookF,
      color: Colors.white,
      size: 20,
    ),
  );

  Widget _socialIconButton(IconData icon) => CircleAvatar(
    radius: 24,
    backgroundColor: const Color(0xFFEAEAFF),
    child: Icon(icon, color: const Color(0xFF4040FF), size: 26),
  );
}