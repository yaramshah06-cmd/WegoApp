import 'package:flutter/material.dart';

// ─── PUBLIC HELPERS ───────────────────────────────────────────────────────────
const String kRomanticStickerScheme = 'romantic_sticker://';

const List<Widget> kRomanticStickerWidgets = <Widget>[
  Sticker1StarCouple(),
  Sticker2MoonGarden(),
  Sticker3CampfireCouple(),
  Sticker4RedRose(),
  Sticker5Daisies(),
  Sticker6ButterflyJar(),
  Sticker7SunsetCouple(),
  Sticker8GlowGirl(),
  Sticker9SwingCouple(),
  Sticker10MoonRooftop(),
];

int? romanticStickerIndexFromUrl(String? url) {
  if (url == null || !url.startsWith(kRomanticStickerScheme)) return null;
  final raw = url.substring(kRomanticStickerScheme.length);
  final n = int.tryParse(raw);
  if (n == null || n < 1 || n > kRomanticStickerWidgets.length) return null;
  return n - 1;
}

Widget? romanticStickerWidgetForUrl(String? url) {
  final idx = romanticStickerIndexFromUrl(url);
  if (idx == null) return null;
  return kRomanticStickerWidgets[idx];
}

// Unframed version of a romantic sticker — just the GIF itself with no
// rounded-corner ClipRRect wrapper. Used by the full-screen overlay so the
// animation plays without any visible frame around it.
Widget romanticStickerRawByIndex(int index) {
  return Image.asset(
    'assets/stickers/sticker${index + 1}.gif',
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
  );
}

// ─── STICKER 1: STAR COUPLE ───────────────────────────────────────────────────
class Sticker1StarCouple extends StatelessWidget {
  const Sticker1StarCouple({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/stickers/sticker1.gif',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholder(
          '⭐ Star Couple',
          const Color(0xFF0D1B3E),
        ),
      ),
    );
  }
}

// ─── STICKER 2: MOON GARDEN ───────────────────────────────────────────────────
class Sticker2MoonGarden extends StatelessWidget {
  const Sticker2MoonGarden({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/stickers/sticker2.gif',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholder(
          '🌙 Moon Garden',
          const Color(0xFF050D2A),
        ),
      ),
    );
  }
}

// ─── STICKER 3: CAMPFIRE COUPLE ───────────────────────────────────────────────
class Sticker3CampfireCouple extends StatelessWidget {
  const Sticker3CampfireCouple({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/stickers/sticker3.gif',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholder(
          '🔥 Campfire',
          const Color(0xFF030A20),
        ),
      ),
    );
  }
}

// ─── STICKER 4: RED ROSE ─────────────────────────────────────────────────────
class Sticker4RedRose extends StatelessWidget {
  const Sticker4RedRose({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/stickers/sticker4.gif',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholder(
          '🌹 Red Rose',
          const Color(0xFF2A4A10),
        ),
      ),
    );
  }
}

// ─── STICKER 5: DAISIES ───────────────────────────────────────────────────────
class Sticker5Daisies extends StatelessWidget {
  const Sticker5Daisies({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/stickers/sticker5.gif',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholder(
          '🌼 Daisies',
          const Color(0xFF4A8A20),
        ),
      ),
    );
  }
}

// ─── STICKER 6: BUTTERFLY JAR ─────────────────────────────────────────────────
class Sticker6ButterflyJar extends StatelessWidget {
  const Sticker6ButterflyJar({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/stickers/sticker6.gif',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholder(
          '🦋 Butterfly Jar',
          const Color(0xFF050D25),
        ),
      ),
    );
  }
}

// ─── STICKER 7: SUNSET COUPLE ─────────────────────────────────────────────────
class Sticker7SunsetCouple extends StatelessWidget {
  const Sticker7SunsetCouple({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/stickers/sticker7.gif',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholder(
          '🌅 Sunset',
          const Color(0xFF1A0A2A),
        ),
      ),
    );
  }
}

// ─── STICKER 8: GLOW GIRL ─────────────────────────────────────────────────────
class Sticker8GlowGirl extends StatelessWidget {
  const Sticker8GlowGirl({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/stickers/sticker8.gif',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholder(
          '✨ Glow Girl',
          const Color(0xFF020A15),
        ),
      ),
    );
  }
}

// ─── STICKER 9: SWING COUPLE ──────────────────────────────────────────────────
class Sticker9SwingCouple extends StatelessWidget {
  const Sticker9SwingCouple({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/stickers/sticker9.gif',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholder(
          '🌳 Swing',
          const Color(0xFF87CEEB),
        ),
      ),
    );
  }
}

// ─── STICKER 10: MOON ROOFTOP ─────────────────────────────────────────────────
class Sticker10MoonRooftop extends StatelessWidget {
  const Sticker10MoonRooftop({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/stickers/sticker10.gif',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (context, error, stackTrace) => _placeholder(
          '🌕 Moon Rooftop',
          const Color(0xFF020810),
        ),
      ),
    );
  }
}

// ─── FULL-SCREEN OVERLAY ──────────────────────────────────────────────────────
// Gift-style transparent overlay: scales the sticker up to full screen,
// holds, then shrinks back. Pops itself off the Overlay when finished.
class RomanticStickerOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback onFinished;
  const RomanticStickerOverlay({
    super.key,
    required this.child,
    required this.onFinished,
  });

  @override
  State<RomanticStickerOverlay> createState() => _RomanticStickerOverlayState();
}

class _RomanticStickerOverlayState extends State<RomanticStickerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    // Stays full-screen for the whole animation, just a gentle grow-in then
    // hold then fade out. No shrink-to-bubble — sticker disappears when
    // overlay finishes.
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 25,
      ),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 75),
    ]).animate(_ctrl);

    // Keep the sticker semi-transparent (50%) so the chat UI behind it —
    // profile, messages, call buttons — stays visible through the animation.
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 0.5),
        weight: 10,
      ),
      TweenSequenceItem(tween: ConstantTween(0.5), weight: 75),
      TweenSequenceItem(
        tween: Tween(begin: 0.5, end: 0.0),
        weight: 15,
      ),
    ]).animate(_ctrl);


    _ctrl.forward().whenComplete(() {
      if (mounted) widget.onFinished();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    // Pinned to the vertical middle of the screen: full width, exactly half
    // the screen height. BoxFit.cover on the GIF fills the whole rectangle so
    // there is no square box / no empty letterbox edges — just the animation
    // running across the middle band of the chat. IgnorePointer lets every
    // tap pass through to the chat below.
    final h = media.size.height * 0.5;
    final top = (media.size.height - h) / 2;
    return IgnorePointer(
      ignoring: true,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: top,
                height: h,
                child: Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(
                    scale: _scale.value,
                    child: widget.child,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── HELPER: Placeholder jab GIF na mile ──────────────────────────────────────
Widget _placeholder(String label, Color bgColor) {
  return Container(
    color: bgColor,
    child: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label.split(' ').first, // emoji only
            style: const TextStyle(fontSize: 32),
          ),
          const SizedBox(height: 6),
          Text(
            label.split(' ').skip(1).join(' '),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}