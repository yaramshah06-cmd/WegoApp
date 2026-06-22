import 'package:flutter/material.dart';
import 'dart:math' as math;

// ── Colors ────────────────────────────────────────────────────
const Color kPrimaryBlue = Color(0xFF7A1730);

// ── Match Screen ──────────────────────────────────────────────
class MatchPopupScreen extends StatefulWidget {
  const MatchPopupScreen({super.key});

  @override
  State<MatchPopupScreen> createState() => _MatchPopupScreenState();
}

class _MatchPopupScreenState extends State<MatchPopupScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );

    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color secondaryTextColor = isDark ? Colors.white70 : Colors.black45;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Status bar
          Container(
            color: kPrimaryBlue,
            height: MediaQuery.of(context).padding.top,
          ),

          Expanded(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Column(
                  children: [
                    // ── Photo Cards section ──
                    Expanded(
                      flex: 6,
                      child: _buildPhotoCards(size),
                    ),

                    // ── Text section ──
                    Expanded(
                      flex: 4,
                      child: _buildBottomSection(textColor, secondaryTextColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Photo Cards ───────────────────────────────────────────────
  Widget _buildPhotoCards(Size size) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // ── Right card (Jake - man) — tilted right, behind ──
        Positioned(
          top: 30,
          right: size.width * 0.04,
          child: Transform.rotate(
            angle: 8 * math.pi / 180,
            child: _PhotoCard(
              imageUrl:
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400',
              width: size.width * 0.52,
              height: size.height * 0.42,
            ),
          ),
        ),

        // ── Left card (Girl) — tilted left, in front ──
        Positioned(
          top: 55,
          left: size.width * 0.04,
          child: Transform.rotate(
            angle: -6 * math.pi / 180,
            child: _PhotoCard(
              imageUrl:
              'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400',
              width: size.width * 0.50,
              height: size.height * 0.40,
            ),
          ),
        ),

        // ── Top center heart badge ──
        Positioned(
          top: 10,
          child: const _HeartBadge(size: 52),
        ),

        // ── Bottom left heart badge ──
        Positioned(
          bottom: 10,
          left: size.width * 0.06,
          child: const _HeartBadge(size: 52),
        ),
      ],
    );
  }

  // ── Bottom Section ────────────────────────────────────────────
  Widget _buildBottomSection(Color textColor, Color secondaryTextColor) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: _slideAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnim.value),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Match text
            const Text(
              "It's a match, Jake!",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: kPrimaryBlue,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Start a conversation now with each other',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
              ),
            ),

            const SizedBox(height: 32),

            // ── Say Hello button ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryBlue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Say hello',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Keep Swiping button ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white10 : kPrimaryBlue.withValues(alpha: 0.1),
                  foregroundColor: kPrimaryBlue,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Keep swiping',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo Card Widget ─────────────────────────────────────────
class _PhotoCard extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;

  const _PhotoCard({
    required this.imageUrl,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              color: isDark ? Colors.white10 : Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            color: isDark ? Colors.white10 : Colors.grey[300],
            child: Icon(Icons.person, size: 60, color: isDark ? Colors.white38 : Colors.grey),
          ),
        ),
      ),
    );
  }
}

// ── Heart Badge Widget ────────────────────────────────────────
class _HeartBadge extends StatelessWidget {
  final double size;
  const _HeartBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: kPrimaryBlue.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        Icons.favorite,
        color: kPrimaryBlue,
        size: size * 0.50,
      ),
    );
  }
}
