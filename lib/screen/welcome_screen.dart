import 'package:flutter/material.dart';
import 'login_screen.dart';           // ✅ Login Screen import
import 'create_account.dart';         // ✅ Sign Up Screen import

// ─────────────────────────────────────────────────────────────
// WELCOME SCREEN  —  WeGo Dating
// ─────────────────────────────────────────────────────────────
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);

    _slide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Brand colours (maroon dating palette) ────────────────────
  static const Color kMaroon     = Color(0xFF7A1730); // deep maroon
  static const Color kMaroonDark = Color(0xFF4A0E1E); // darker maroon
  static const Color kRose       = Color(0xFFC2415E); // rose accent

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── Full-screen maroon gradient background ────────────────
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kRose, kMaroon, kMaroonDark],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SlideTransition(
              position: _slide,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Top spacer ──────────────────────────────
                    const Spacer(flex: 2),

                    // ── Heart logo mark ─────────────────────────
                    SizedBox(
                      width: 130,
                      height: 130,
                      child: CustomPaint(painter: _HeartLogoPainter()),
                    ),

                    const SizedBox(height: 22),

                    // ── App name ─────────────────────────────────
                    const Text(
                      'WeGo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 46,
                        fontWeight: FontWeight.w700,
                        height: 1.10,
                        letterSpacing: 1.0,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Tagline ─────────────────────────────────
                    const Text(
                      'Find your perfect match',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.6,
                      ),
                    ),

                    // ── Middle spacer ────────────────────────────
                    const Spacer(flex: 2),

                    // ── Description text ─────────────────────────
                    const Text(
                      'Meet new people, make real connections, '
                          'and find someone special — all in one place.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 13.5,
                        height: 1.6,
                      ),
                    ),

                    // ── Bottom spacer ────────────────────────────
                    const Spacer(flex: 1),

                    // ── Create Account button (primary) ──────────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CreateAccountScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: kMaroon,
                          elevation: 0,
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        child: const Text('Create Account'),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Log In button (secondary / outlined) ─────
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white70, width: 1.4),
                          shape: const StadiumBorder(),
                          textStyle: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                        child: const Text('I already have an account'),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Terms & Privacy ──────────────────────────
                    const Text(
                      'By continuing you agree to our Terms & Privacy Policy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HEART LOGO PAINTER  (rounded heart inside a soft circle)
// ─────────────────────────────────────────────────────────────
class _HeartLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // ── Soft translucent circle behind the heart ──────────────
    final circlePaint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.5, circlePaint);

    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.5 - 1, ringPaint);

    // ── Heart shape ───────────────────────────────────────────
    final heartPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Path heart = Path();
    final double cx = w / 2;
    final double top = h * 0.34;
    final double bottom = h * 0.72;
    final double half = w * 0.24;

    heart.moveTo(cx, bottom);
    // left side up to the left bump
    heart.cubicTo(
      cx - half * 1.4, h * 0.58,
      cx - half * 1.5, top,
      cx - half * 0.5, top,
    );
    // left bump to centre dip
    heart.cubicTo(
      cx - half * 0.1, top,
      cx, h * 0.40,
      cx, h * 0.44,
    );
    // centre dip to right bump
    heart.cubicTo(
      cx, h * 0.40,
      cx + half * 0.1, top,
      cx + half * 0.5, top,
    );
    // right bump down to bottom tip
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
