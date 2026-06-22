import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wego_marriage/screen/welcome_screen.dart';

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

    // Status bar transparent
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    // Fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Scale animation
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    // Animations start karo
    _fadeController.forward();
    _scaleController.forward();

    // ✅ 3 seconds baad WelcomeScreen pe navigate karo
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
            const WelcomeScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    });
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFC2415E), // rose
              Color(0xFF7A1730), // maroon
              Color(0xFF4A0E1E), // dark maroon
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ===== HEART LOGO =====
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CustomPaint(
                      painter: _SplashHeartPainter(),
                    ),
                  ),

                  const SizedBox(height: 26),

                  // ===== APP NAME =====
                  const Text(
                    'WeGo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 46,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      letterSpacing: 1.0,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ===== TAGLINE =====
                  const Text(
                    'Find your perfect match',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// SPLASH HEART LOGO PAINTER
// ─────────────────────────────────────────────────────────────
class _SplashHeartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Soft translucent circle
    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.5, circlePaint);

    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.5 - 1, ringPaint);

    // Heart shape
    final heartPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Path heart = Path();
    final double cx = w / 2;
    final double top = h * 0.34;
    final double bottom = h * 0.72;
    final double half = w * 0.24;

    heart.moveTo(cx, bottom);
    heart.cubicTo(
      cx - half * 1.4, h * 0.58,
      cx - half * 1.5, top,
      cx - half * 0.5, top,
    );
    heart.cubicTo(
      cx - half * 0.1, top,
      cx, h * 0.40,
      cx, h * 0.44,
    );
    heart.cubicTo(
      cx, h * 0.40,
      cx + half * 0.1, top,
      cx + half * 0.5, top,
    );
    heart.cubicTo(
      cx + half * 1.5, top,
      cx + half * 1.4, h * 0.58,
      cx, bottom,
    );
    heart.close();
    canvas.drawPath(heart, heartPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WeGoLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final double w = size.width;
    final double h = size.height;

    // ----- CROSS / PLUS shape -----
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

    // ----- LEAF -----
    final leafPaint = Paint()
      ..color = const Color(0xFF7A1730)
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

    // ----- WAVE underline -----
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