import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wego_marriage/screen/welcome_screen.dart';
import 'package:wego_marriage/screen/home_feed_screen.dart';
import 'package:wego_marriage/screen/xp_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    _fadeController.forward();
    _scaleController.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _checkAuthAndNavigate();
    });
  }

  // ✅ Auth + Firestore check karke navigate karo
  Future<void> _checkAuthAndNavigate() async {
    final User? user = FirebaseAuth.instance.currentUser;

    Widget nextScreen;

    if (user != null) {
      // Firebase Auth mein logged in hai — Firestore mein bhi check karo
      try {
        final docSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (docSnap.exists) {
          // ✅ Proper account bana hua hai — Home bhejo
          // 🎁 Daily Login XP (sirf ek baar per din service handle karti hai)
          await XPService.addXP(user.uid, XPAction.dailyLogin);
          nextScreen = const HomeFeedScreen();
        } else {
          // Firebase Auth mein hai lekin Firestore mein nahi
          // Matlab incomplete signup — Welcome Screen par bhejo
          await FirebaseAuth.instance.signOut();
          nextScreen = const WelcomeScreen();
        }
      } catch (e) {
        // Firestore error — safe side par Welcome Screen
        nextScreen = const WelcomeScreen();
      }
    } else {
      // Logged in nahi — Welcome Screen
      nextScreen = const WelcomeScreen();
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2E5FF6),
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_fadeAnimation, _scaleAnimation]),
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: WeGoLogoPainter(),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'WeGo\nMarriage',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                'Matrimonial App',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WeGoLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final double w = size.width;
    final double h = size.height;

    final double armW = w * 0.30;
    final double cx = w / 2;
    final double cy = h * 0.45;
    final double crossH = h * 0.60;
    final double crossW = w * 0.90;
    final double r = armW / 2;

    RRect vertBar = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: armW, height: crossH),
      Radius.circular(r),
    );
    RRect horizBar = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(cx, cy - h * 0.05), width: crossW, height: armW),
      Radius.circular(r),
    );

    canvas.drawRRect(vertBar, paint);
    canvas.drawRRect(horizBar, paint);

    final leafPaint = Paint()
      ..color = const Color(0xFF2E5FF6)
      ..style = PaintingStyle.fill;

    final Path leafPath = Path();
    final double lx = cx - w * 0.04;
    final double ly = cy - h * 0.02;

    leafPath.moveTo(lx, ly + h * 0.12);
    leafPath.quadraticBezierTo(
        lx + w * 0.20, ly - h * 0.10, lx + w * 0.22, ly + h * 0.10);
    leafPath.quadraticBezierTo(
        lx + w * 0.10, ly + h * 0.18, lx, ly + h * 0.12);
    leafPath.close();
    canvas.drawPath(leafPath, leafPaint);

    final wavePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final Path wavePath = Path();
    final double waveY = h * 0.82;
    final double waveStartX = w * 0.12;
    final double waveEndX = w * 0.88;

    wavePath.moveTo(waveStartX, waveY);
    wavePath.cubicTo(
      waveStartX + (waveEndX - waveStartX) * 0.25, waveY - h * 0.06,
      waveStartX + (waveEndX - waveStartX) * 0.40, waveY + h * 0.06,
      waveStartX + (waveEndX - waveStartX) * 0.55, waveY,
    );
    wavePath.cubicTo(
      waveStartX + (waveEndX - waveStartX) * 0.70, waveY - h * 0.06,
      waveStartX + (waveEndX - waveStartX) * 0.85, waveY + h * 0.04,
      waveEndX, waveY,
    );

    canvas.drawPath(wavePath, wavePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}