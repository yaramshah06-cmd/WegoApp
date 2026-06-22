import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

// ── Colors ────────────────────────────────────────────────────
const Color kPurple = Color(0xFF7A1730);
const Color kRed = Color(0xFFE8405A);

// ── Calling Screen ────────────────────────────────────────────
class CallingScreen extends StatefulWidget {
  const CallingScreen({super.key});

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen>
    with TickerProviderStateMixin {
  // Pulsing ring animation
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  // Dots animation for "CALLING........"
  late Timer _dotsTimer;
  int _dotCount = 0;

  // Mute state
  bool _isMuted = false;
  bool _isVideoOff = false;

  // Vibration timer
  Timer? _vibrationTimer;

  @override
  void initState() {
    super.initState();

    // Pulse animation
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    // Dots timer
    _dotsTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      setState(() {
        _dotCount = (_dotCount + 1) % 9;
      });
    });

    // Vibration logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      if (settings.vibrate) {
        _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
          HapticFeedback.heavyImpact();
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _dotsTimer.cancel();
    _vibrationTimer?.cancel();
    super.dispose();
  }

  String get _dotsText => '.' * (_dotCount + 1);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: kPurple,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            // Status bar
            Container(
              color: kPurple,
              height: MediaQuery.of(context).padding.top,
            ),

            // ── Main content ──
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // ── Avatar with pulsing gradient ring ──
                  _buildPulsingAvatar(),

                  const SizedBox(height: 40),

                  // ── CALLING......... ──
                  Text(
                    'CALLING$_dotsText',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 3,
                    ),
                  ),

                  const Spacer(flex: 3),

                  // ── Action Buttons ──
                  _buildActionBar(isDark),

                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Pulsing Avatar ────────────────────────────────────────────
  Widget _buildPulsingAvatar() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnim.value,
          child: child,
        );
      },
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), kPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: kPurple.withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: 4,
            ),
            BoxShadow(
              color: kRed.withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: ClipOval(
          child: Image.network(
            'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400',
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                color: Colors.grey[800],
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white54,
                    strokeWidth: 2,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[800],
              child: const Icon(Icons.person, color: Colors.white54, size: 60),
            ),
          ),
        ),
      ),
    );
  }

  // ── Action Bar ────────────────────────────────────────────────
  Widget _buildActionBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // ── Mute / Audio ──
            GestureDetector(
              onTap: () => setState(() => _isMuted = !_isMuted),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _isMuted
                      ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1))
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMuted ? Icons.mic_off : Icons.phone_outlined,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 26,
                ),
              ),
            ),

            // ── Video ──
            GestureDetector(
              onTap: () => setState(() => _isVideoOff = !_isVideoOff),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _isVideoOff
                      ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1))
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isVideoOff
                      ? Icons.videocam_off_outlined
                      : Icons.videocam_outlined,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 26,
                ),
              ),
            ),

            // ── End Call (Red) ──
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: kRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x55E8405A),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.call_end,
                  color: Colors.white,
                  size: 26,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}