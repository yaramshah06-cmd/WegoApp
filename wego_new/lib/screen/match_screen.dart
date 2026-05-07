import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'app_translations.dart';

const Color kPrimaryBlue = Color(0xFF4A6CF7);

class MatchPopupScreen extends StatefulWidget {
  final String matchedUserName;
  final String matchedUserImage;
  final String matchedUserUid;
  final VoidCallback? onSayHello;
  final VoidCallback? onCancel;

  const MatchPopupScreen({
    super.key,
    required this.matchedUserName,
    required this.matchedUserImage,
    required this.matchedUserUid,
    this.onSayHello,
    this.onCancel,
  });

  @override
  State<MatchPopupScreen> createState() => _MatchPopupScreenState();
}

class _MatchPopupScreenState extends State<MatchPopupScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;

  int _countdown = 3;
  Timer? _countdownTimer;

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
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        t.cancel();
        if (widget.onSayHello != null) {
          widget.onSayHello!();
        } else {
          Navigator.pop(context);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondaryTextColor = isDark ? Colors.white70 : Colors.black45;
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
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
                    Expanded(
                      flex: 6,
                      child: _buildPhotoCards(size),
                    ),
                    Expanded(
                      flex: 4,
                      child: _buildBottomSection(secondaryTextColor, isDark, lang),
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

  Widget _buildPhotoCards(Size size) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Positioned(
          top: 30,
          right: size.width * 0.04,
          child: Transform.rotate(
            angle: 8 * math.pi / 180,
            child: _PhotoCard(
              imageUrl: widget.matchedUserImage,
              width: size.width * 0.52,
              height: size.height * 0.42,
            ),
          ),
        ),
        Positioned(
          top: 55,
          left: size.width * 0.04,
          child: Transform.rotate(
            angle: -6 * math.pi / 180,
            child: _PhotoCard(
              imageUrl: 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400',
              width: size.width * 0.50,
              height: size.height * 0.40,
            ),
          ),
        ),
        const Positioned(
          top: 10,
          child: _HeartBadge(size: 52),
        ),
        Positioned(
          bottom: 10,
          left: size.width * 0.06,
          child: const _HeartBadge(size: 52),
        ),
      ],
    );
  }

  Widget _buildBottomSection(Color secondaryTextColor, bool isDark, String lang) {
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
            // ── Match Title ──
            Text(
              "${AppTranslations.translate('its_a_match', lang)}, ${widget.matchedUserName}!",
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: kPrimaryBlue,
              ),
            ),
            const SizedBox(height: 10),

            // ── Subtitle ──
            Text(
              AppTranslations.translate('start_conversation', lang),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: secondaryTextColor),
            ),

            const SizedBox(height: 32),

            // ── Timer Button ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  color: kPrimaryBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: _countdown / 3,
                            color: Colors.white,
                            backgroundColor: Colors.white30,
                            strokeWidth: 3,
                          ),
                          Text(
                            '$_countdown',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      AppTranslations.translate('connecting', lang),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // ── Cancel Button ──
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {
                  _countdownTimer?.cancel();
                  if (widget.onCancel != null) {
                    widget.onCancel!();
                  } else {
                    Navigator.pop(context);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white10 : Colors.red.withOpacity(0.08),
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  AppTranslations.translate('cancel', lang),
                  style: const TextStyle(
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

// ─────────────────────────────────────────
//  PHOTO CARD
// ─────────────────────────────────────────
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
            color: Colors.black.withOpacity(0.18),
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
            child: Icon(Icons.person,
                size: 60, color: isDark ? Colors.white38 : Colors.grey),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
//  HEART BADGE
// ─────────────────────────────────────────
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
            color: kPrimaryBlue.withOpacity(0.25),
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