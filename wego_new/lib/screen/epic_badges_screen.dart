// ignore_for_file: lines_longer_than_80_chars
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'badge_assets.dart';
import 'rewards_screen.dart';

// ─── Safe Base64 Decode Helper ──────────────────────────────
Uint8List? safeBase64Decode(String b64) {
  if (b64.isEmpty) return null;
  try {
    String padded = b64;
    final rem = b64.length % 4;
    if (rem != 0) padded += '=' * (4 - rem);
    return base64Decode(padded);
  } catch (_) {
    return null;
  }
}

// ─── Badge Model ───────────────────────────────────────────
class BadgeData {
  final String id;
  final String name;
  final String desc;
  final String rarity;
  final Color glowColor;
  final Color tagBg;
  final Color tagFg;
  final int level;
  final String badgeB64;

  const BadgeData({
    required this.id,
    required this.name,
    required this.desc,
    required this.rarity,
    required this.glowColor,
    required this.tagBg,
    required this.tagFg,
    required this.level,
    required this.badgeB64,
  });
}

// ─── Lion B64 ──────────────────────────────────────────────
const String kLionB64 = '';

// ─── Badge List (5 unique badges) ──────────────────────────
final List<BadgeData> kBadgeList = [
  BadgeData(
    id: 'bronze',
    name: 'Bronze',
    desc: 'Your first step in the journey!',
    rarity: 'Common',
    glowColor: const Color(0xFFE87C3E),
    tagBg: const Color(0x2FE87C3E),
    tagFg: const Color(0xFFE87C3E),
    level: 20,
    badgeB64: kBadgeBronzeB64,
  ),
  BadgeData(
    id: 'gold',
    name: 'Gold',
    desc: 'Welcome to the Elite Club!',
    rarity: 'Epic',
    glowColor: const Color(0xFFFFD700),
    tagBg: const Color(0x2FFFD700),
    tagFg: const Color(0xFFFFD700),
    level: 40,
    badgeB64: kBadgeGoldB64,
  ),
  BadgeData(
    id: 'platinum',
    name: 'Platinum',
    desc: 'Grand Entry Effect unlocked!',
    rarity: 'Legend',
    glowColor: const Color(0xFF87CEEB),
    tagBg: const Color(0x2F87CEEB),
    tagFg: const Color(0xFF87CEEB),
    level: 60,
    badgeB64: kBadgePlatinumB64,
  ),
  BadgeData(
    id: 'diamond',
    name: 'Diamond',
    desc: 'Rainbow Name Effect unlocked!',
    rarity: 'Legend',
    glowColor: const Color(0xFF00FFFF),
    tagBg: const Color(0x2300FFFF),
    tagFg: const Color(0xFF00FFFF),
    level: 80,
    badgeB64: kBadgeDiamondB64,
  ),
  BadgeData(
    id: 'legendary',
    name: 'Legendary',
    desc: 'Supreme King! Global Announcement!',
    rarity: 'GOD',
    glowColor: const Color(0xFFB87FFF),
    tagBg: const Color(0x2FB87FFF),
    tagFg: const Color(0xFFB87FFF),
    level: 100,
    badgeB64: kBadgeLegendaryB64,
  ),
];

// ─── Level Reward Model ─────────────────────────────────────
class LevelReward {
  final int level;
  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  const LevelReward({
    required this.level,
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
  });
}

const List<LevelReward> kLevelRewards = [
  LevelReward(level: 10,  title: 'Voice Changer',          desc: 'Change your voice in chat — 8 styles',       icon: Icons.mic,               color: Color(0xFFF5C842)),
  LevelReward(level: 20,  title: 'Emoji Bomb',             desc: 'Colorful emoji blast across the screen',     icon: Icons.auto_awesome,      color: Color(0xFFE91E8C)),
  LevelReward(level: 30,  title: 'Flash Message',          desc: 'Your message glows in the chat list',        icon: Icons.flash_on,          color: Color(0xFF4CAF50)),
  LevelReward(level: 40,  title: 'Stealth Mode',           desc: 'Read messages — "Seen" never shows',         icon: Icons.visibility_off,    color: Color(0xFF2196F3)),
  LevelReward(level: 50,  title: 'Level Booster Gift',     desc: 'Send gifts to boost others\' levels',        icon: Icons.card_giftcard,     color: Color(0xFF9C27B0)),
  LevelReward(level: 60,  title: 'Platinum Badge',         desc: 'Gold wings + red gem badge unlocked',        icon: Icons.military_tech,     color: Color(0xFFF5C842)),
  LevelReward(level: 70,  title: 'Diamond Badge',          desc: 'Winged gold star + blue gem badge',          icon: Icons.diamond,           color: Color(0xFF1565C0)),
  LevelReward(level: 80,  title: 'Titanium + Grand Entry', desc: 'Silver badge + dramatic entry effect',       icon: Icons.shield,            color: Color(0xFF546E7A)),
  LevelReward(level: 90,  title: 'Black Hole + Rainbow',   desc: 'Dark badge + animated rainbow name',         icon: Icons.blur_circular,     color: Color(0xFFE040FB)),
  LevelReward(level: 100, title: 'Supreme King',           desc: 'Purple shield + Global Announcement!',       icon: Icons.workspace_premium, color: Color(0xFF6A0DAD)),
];

// ══════════════════════════════════════════════
//  MAIN SCREEN
// ══════════════════════════════════════════════
class EpicBadgesScreen extends StatefulWidget {
  const EpicBadgesScreen({super.key});

  @override
  State<EpicBadgesScreen> createState() => _EpicBadgesScreenState();
}

class _EpicBadgesScreenState extends State<EpicBadgesScreen> {
  int _userLevel = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserLevel();
  }

  Future<void> _fetchUserLevel() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        if (mounted) setState(() { _userLevel = 0; _isLoading = false; });
        return;
      }
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final lvl = (doc.data()?['level'] as num?)?.toInt() ?? 0;
      if (mounted) setState(() { _userLevel = lvl; _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _userLevel = 0; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080818),
      body: SafeArea(
        child: _isLoading
            ? const Center(
            child: CircularProgressIndicator(color: Color(0xFFB87FFF)))
            : Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 16),
                    ),
                  ),
                  Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            const LinearGradient(colors: [
                              Color(0xFFE51E8F),
                              Color(0xFFB87FFF),
                              Color(0xFF00FFFF),
                            ]).createShader(bounds),
                        child: const Text(
                          'WeGo Royal',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const Text(
                        'A C H I E V E M E N T',
                        style: TextStyle(
                          fontSize: 9,
                          color: Color(0xFFB87FFF),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFFD700)
                              .withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'Lv $_userLevel',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFFFFD700),
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Tap any badge to explore',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.3)),
                ),
              ),
              const SizedBox(height: 16),

              // ── Badge Grid ──
              Expanded(
                child: GridView.builder(
                  itemCount: kBadgeList.length,
                  gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (ctx, i) => BadgeCard(
                    badge: kBadgeList[i],
                    userLevel: _userLevel,
                    floatDelay: i * 0.4,
                    onTap: () => showGeneralDialog(
                      context: ctx,
                      barrierDismissible: false,
                      barrierColor: Colors.transparent,
                      transitionDuration: Duration.zero,
                      pageBuilder: (c, _, __) => EpicOverlay(
                        badge: kBadgeList[i],
                        userLevel: _userLevel,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── All Level Rewards Button ──
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RewardsScreen(userLevel: _userLevel),
                  ),
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE51E8F), Color(0xFFFF6B35)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE51E8F)
                            .withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emoji_events_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'All Level Rewards  →',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllRewardsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AllRewardsSheet(userLevel: _userLevel),
    );
  }
}

// ══════════════════════════════════════════════
//  ALL REWARDS BOTTOM SHEET
// ══════════════════════════════════════════════
class _AllRewardsSheet extends StatelessWidget {
  final int userLevel;
  const _AllRewardsSheet({required this.userLevel});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D0D20),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'All Level Rewards',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: kLevelRewards.length,
                itemBuilder: (_, i) {
                  final r = kLevelRewards[i];
                  final unlocked = userLevel >= r.level;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: unlocked
                          ? r.color.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: unlocked
                            ? r.color.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.07),
                      ),
                    ),
                    child: Row(children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: unlocked
                              ? r.color.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          unlocked ? r.icon : Icons.lock_rounded,
                          color: unlocked
                              ? r.color
                              : Colors.white.withValues(alpha: 0.25),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.title,
                                style: TextStyle(
                                  color: unlocked
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.4),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                r.desc,
                                style: TextStyle(
                                  color: unlocked
                                      ? Colors.white.withValues(alpha: 0.55)
                                      : Colors.white.withValues(alpha: 0.25),
                                  fontSize: 11,
                                ),
                              ),
                            ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: unlocked
                              ? r.color.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Lv ${r.level}',
                          style: TextStyle(
                            color: unlocked
                                ? r.color
                                : Colors.white.withValues(alpha: 0.3),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  BADGE CARD
// ══════════════════════════════════════════════
class BadgeCard extends StatefulWidget {
  final BadgeData badge;
  final int userLevel;
  final double floatDelay;
  final VoidCallback onTap;

  const BadgeCard({
    super.key,
    required this.badge,
    required this.userLevel,
    required this.floatDelay,
    required this.onTap,
  });

  @override
  State<BadgeCard> createState() => _BadgeCardState();
}

class _BadgeCardState extends State<BadgeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;
  bool _pressed = false;
  Uint8List? _badgeBytes;

  @override
  void initState() {
    super.initState();
    _badgeBytes = safeBase64Decode(widget.badge.badgeB64);
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000));
    _anim = Tween(begin: 0.0, end: 1.0).animate(_ctrl);
    Future.delayed(
        Duration(milliseconds: (widget.floatDelay * 1000).toInt()), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.badge;
    final unlocked = widget.userLevel >= b.level;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 180),
        child: AnimatedBuilder(
          animation: _anim,
          builder: (ctx, child) => Transform.translate(
            offset: Offset(0, unlocked ? -8.0 * sin(_anim.value * pi) : 0),
            child: child,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: unlocked
                    ? b.glowColor.withValues(alpha: 0.25)
                    : Colors.white.withValues(alpha: 0.06),
              ),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  unlocked
                      ? b.glowColor.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.02),
                  Colors.transparent,
                ],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: Opacity(
                        opacity: unlocked ? 1.0 : 0.22,
                        child: _badgeBytes != null
                            ? Image.memory(_badgeBytes!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true)
                            : _BadgePlaceholder(
                            color: b.glowColor, unlocked: unlocked),
                      ),
                    ),
                    // ── Lock icon صرف grid card میں دکھاؤ ──
                    if (!unlocked)
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: const Icon(Icons.lock_rounded,
                            color: Colors.white38, size: 18),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  b.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: unlocked
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Level ${b.level}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.35)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 3),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? b.tagBg
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    b.rarity,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: unlocked
                          ? b.tagFg
                          : Colors.white.withValues(alpha: 0.22),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Badge Placeholder ───────────────────────
class _BadgePlaceholder extends StatelessWidget {
  final Color color;
  final bool unlocked;
  const _BadgePlaceholder({required this.color, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: unlocked
              ? color.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: 2,
        ),
        color: unlocked
            ? color.withValues(alpha: 0.1)
            : Colors.white.withValues(alpha: 0.03),
      ),
      child: Icon(
        Icons.emoji_events_rounded,
        color: unlocked
            ? color.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.12),
        size: 48,
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  LION FLASH
// ══════════════════════════════════════════════
class _LionFlash extends StatefulWidget {
  const _LionFlash();
  @override
  State<_LionFlash> createState() => _LionFlashState();
}

class _LionFlashState extends State<_LionFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  Uint8List? _lionBytes;

  @override
  void initState() {
    super.initState();
    _lionBytes = safeBase64Decode(kLionB64);
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_ctrl);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lionBytes == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Container(
          color: Colors.black,
          child: Center(
            child: Image.memory(_lionBytes!,
                fit: BoxFit.contain, gaplessPlayback: true),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════
//  EPIC OVERLAY — tap پر lock نہیں دکھائے گا
// ══════════════════════════════════════════════
class EpicOverlay extends StatefulWidget {
  final BadgeData badge;
  final int userLevel;
  const EpicOverlay(
      {super.key, required this.badge, required this.userLevel});
  @override
  State<EpicOverlay> createState() => _EpicOverlayState();
}

class _EpicOverlayState extends State<EpicOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _spinCtrl;
  late final AnimationController _glowCtrl;
  late final AnimationController _floatCtrl;
  late final Animation<double> _float;
  late final AnimationController _textCtrl;
  late final Animation<double> _textOpacity, _textSlide;
  late final AnimationController _closeCtrl;
  Uint8List? _badgeBytes;
  bool _showLion = false;

  @override
  void initState() {
    super.initState();
    _badgeBytes = safeBase64Decode(widget.badge.badgeB64);

    if (widget.badge.id == 'legendary' && kLionB64.isNotEmpty) {
      _showLion = true;
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _showLion = false);
      });
    }

    _spinCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();
    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat(reverse: true);
    _float = Tween(begin: 0.0, end: 1.0).animate(_floatCtrl);

    _textCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _textOpacity = Tween(begin: 0.0, end: 1.0).animate(_textCtrl);
    _textSlide = Tween(begin: 35.0, end: 0.0).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.elasticOut));
    _closeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));

    Future.delayed(const Duration(milliseconds: 400),
            () { if (mounted) _textCtrl.forward(); });
    Future.delayed(const Duration(milliseconds: 600),
            () { if (mounted) _closeCtrl.forward(); });
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _glowCtrl.dispose();
    _floatCtrl.dispose();
    _textCtrl.dispose();
    _closeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.badge;
    final sz = MediaQuery.of(context).size;
    final cy = sz.height * 0.4;
    // ── Overlay میں ہمیشہ unlocked style ──
    const bool overlayUnlocked = true;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Background
          Container(color: Colors.black),

          // 1. Spinning glow ring
          Positioned(
            left: 0, right: 0, top: cy - 140,
            child: AnimatedBuilder(
              animation: Listenable.merge([_spinCtrl, _glowCtrl]),
              builder: (_, __) {
                final gBlur = 30.0 + 30.0 * _glowCtrl.value;
                return Center(
                  child: Transform.rotate(
                    angle: _spinCtrl.value * 2 * pi,
                    child: Container(
                      width: 280, height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(colors: [
                          b.glowColor.withValues(alpha: 0.0),
                          b.glowColor.withValues(alpha: 0.9),
                          b.glowColor.withValues(alpha: 0.0),
                        ]),
                        boxShadow: [
                          BoxShadow(
                            color: b.glowColor.withValues(alpha: 0.5),
                            blurRadius: gBlur,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // 2. Badge image — lock icon نہیں
          Positioned(
            left: 0, right: 0, top: cy - 130,
            child: AnimatedBuilder(
              animation: Listenable.merge([_floatCtrl, _glowCtrl]),
              builder: (_, __) {
                final floatDy = -14.0 * sin(_float.value * pi);
                final gBlur = 40.0 + 40.0 * _glowCtrl.value;
                return Transform.translate(
                  offset: Offset(0, floatDy),
                  child: Center(
                    child: Stack(alignment: Alignment.center, children: [
                      Container(
                        width: 260, height: 260,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: b.glowColor.withValues(alpha: 0.8),
                                blurRadius: gBlur,
                                spreadRadius: 8),
                            BoxShadow(
                                color: b.glowColor.withValues(alpha: 0.4),
                                blurRadius: gBlur * 2,
                                spreadRadius: 4),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 240, height: 240,
                        child: _badgeBytes != null
                            ? Image.memory(_badgeBytes!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true)
                            : _BadgePlaceholder(
                            color: b.glowColor,
                            unlocked: overlayUnlocked),
                      ),
                      // ── lock icon ہٹا دیا ──
                    ]),
                  ),
                );
              },
            ),
          ),

          // 3. Text panel
          Positioned(
            left: 0, right: 0, top: cy + 148,
            child: AnimatedBuilder(
              animation: _textCtrl,
              builder: (_, __) => Opacity(
                opacity: _textOpacity.value,
                child: Transform.translate(
                  offset: Offset(0, _textSlide.value),
                  child: Column(children: [
                    Text(
                      b.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(color: b.glowColor, blurRadius: 30),
                          Shadow(color: b.glowColor, blurRadius: 60),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        b.desc,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.55),
                            height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // ── Unlock status: user ka real level check ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 26, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: widget.userLevel >= b.level
                              ? b.glowColor
                              : Colors.white.withValues(alpha: 0.25),
                          width: 2,
                        ),
                        color: Colors.black.withValues(alpha: 0.4),
                      ),
                      child: Text(
                        widget.userLevel >= b.level
                            ? '✅  Unlocked!'
                            : '🔒  Reach Level ${b.level} to unlock',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: widget.userLevel >= b.level
                              ? b.glowColor
                              : Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),

          // 4. Close button
          Positioned(
            top: 16 + MediaQuery.of(context).padding.top,
            right: 16,
            child: AnimatedBuilder(
              animation: _closeCtrl,
              builder: (_, __) => Opacity(
                opacity: _closeCtrl.value,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white, size: 20),
                  ),
                ),
              ),
            ),
          ),

          // 5. Lion Flash
          if (_showLion) const _LionFlash(),
        ],
      ),
    );
  }
}