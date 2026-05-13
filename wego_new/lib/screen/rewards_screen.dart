import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'badge_assets.dart';
import 'badge_helper.dart';
import 'xp_service.dart';

class RewardsScreen extends StatelessWidget {
  // Optional: caller initial level pass kar sakta hai (loading ke time ya
  // jab pehle se pata ho). Stream ki real-time value isko override karti hai.
  final int? userLevel;
  const RewardsScreen({Key? key, this.userLevel}) : super(key: key);

  static final _levels = [
    _LevelData(10,  'Voice Changer',      'Change your voice in chat — 8 styles available',             '🎙️', null,               'Common', Color(0xFFFFF3E0), Color(0xFFE65100), Color(0xFFFF9800)),
    _LevelData(20,  'Emoji Bomb',         'Full screen colorful emoji animation blast',                  '💥', null,               'Common', Color(0xFFFCE4EC), Color(0xFF880E4F), Color(0xFFE91E8C)),
    _LevelData(30,  'Flash Message',      'Your message glows in the chat list — stand out',             '⚡', null,               'Rare',   Color(0xFFE8F5E9), Color(0xFF1B5E20), Color(0xFF4CAF50)),
    _LevelData(40,  'Stealth Mode',       'Read messages without sending a "Seen" receipt',              '🕵️', null,              'Rare',   Color(0xFFE3F2FD), Color(0xFF0D47A1), Color(0xFF2196F3)),
    _LevelData(50,  'Level Booster Gift', 'Send gifts to instantly boost others\' levels',               '🎁', null,               'Epic',   Color(0xFFF3E5F5), Color(0xFF4A148C), Color(0xFF9C27B0)),
    _LevelData(60,  'Gold Badge',         'Gold Badge — exclusive shine on your profile',                '🏅', kBadgeGoldB64,      'Epic',   Color(0xFFE8EAF6), Color(0xFF1A237E), Color(0xFFFFD700)),
    _LevelData(70,  'Silver Badge',       'Silver Badge — welcome to the elite members club',            '💎', kBadgeBronzeB64,    'Epic',   Color(0xFFE0F7FA), Color(0xFF006064), Color(0xFFC0C0C0)),
    _LevelData(80,  'Platinum Badge',     'Badge + dramatic entry effect when someone opens your chat',  '⚔️', kBadgePlatinumB64,  'Legend', Color(0xFFFAFAFA), Color(0xFF212121), Color(0xFF87CEEB)),
    _LevelData(90,  'Diamond Badge',      'Rare badge + your name shines in rainbow colors',             '🌀', kBadgeDiamondB64,   'Legend', Color(0xFF1A1A2E), Color(0xFFE040FB), Color(0xFF00FFFF)),
    _LevelData(100, 'Legendary Badge',    'Supreme King — Global Announcement across the entire app!',   '👑', kBadgeLegendaryB64, 'GOD',    Color(0xFFFF9800), Color(0xFFFFFFFF), Color(0xFF9B59B6)),
  ];

  static const _details = [
    'Voice Changer gives you 8 different voice styles — Robot, Deep Voice, Girl Voice, Baby Voice and more. Applied in real-time during chat.',
    'Send an Emoji Bomb — both screens get a 3-second full-screen animated emoji blast. Your partner will love it!',
    'Flash Message makes your chat preview glow with a golden shimmer in the chat list. Your partner\'s eyes go straight to your message.',
    'Turn on Stealth Mode and secretly read any message. No seen receipt will ever be sent. Only you will know.',
    'Send a Level Booster Gift to any user and their level instantly goes up by +5. One gift = one boost. 3 gifts available daily.',
    'Gold Badge displays on your profile. You get priority in matching and profile visits increase by 1.5x.',
    'Silver Badge is only for those who cross Level 70. Profile visits automatically double to 2x.',
    'Platinum Badge comes with Grand Entry Effect — a special animation plays whenever someone opens your profile or chat.',
    'Diamond Badge is an ultra-rare dark badge. Comes with Rainbow Name Effect — your name appears in animated rainbow colors in chat.',
    'Supreme King — the app\'s highest honor. The moment you reach Level 100, a Global Announcement is sent to all users in the app!',
  ];

  static const _progressSteps = [
    'Lv 10', 'Lv 20', 'Lv 30', 'Lv 40', 'Lv 50',
    'Lv 60', 'Lv 70', 'Lv 80', 'Lv 90', 'Lv 100'
  ];

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('Login karein')),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.white60 : Colors.black54;

    // ✅ StreamBuilder — Firestore se real-time level aur XP fetch
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        // ── Loading ──
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ── Data ──
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        // Agar Firestore se level mile to woh use ho, warna constructor wala
        // userLevel fallback (jo caller ne pass kiya), warna 1.
        final int userLevel       =
            (data['level'] as num?)?.toInt() ?? this.userLevel ?? 1;
        final int userXP          = (data['levelXP']         as num?)?.toInt() ?? 0;
        final int xpRequired      = (data['levelXPRequired'] as num?)?.toInt() ?? 10000;
        final Map<String, dynamic> rewards =
            data['rewards'] as Map<String, dynamic>? ?? {};

        // XP progress (0.0 to 1.0) current level ke andar
        final double xpProgress =
        XPService.getXPProgress(userXP, userLevel);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Level Rewards',
                style: TextStyle(
                    color: textColor, fontWeight: FontWeight.bold)),
            centerTitle: true,
          ),
          body: ListView(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              // ── XP + Level Progress Card ──
              _buildProgressCard(
                isDark, textColor, subColor,
                userLevel, userXP, xpRequired, xpProgress,
              ),
              const SizedBox(height: 16),
              Text('ALL LEVELS & REWARDS',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: subColor,
                      letterSpacing: 0.8)),
              const SizedBox(height: 10),
              ..._levels.asMap().entries.map((e) => _buildLevelCard(
                context, e.value, e.key,
                isDark, textColor, subColor,
                userLevel, rewards,
              )),
            ],
          ),
        );
      },
    );
  }

  // ── Progress Card (XP bar + level) ──────────────────────────
  Widget _buildProgressCard(
      bool isDark,
      Color textColor,
      Color subColor,
      int userLevel,
      int userXP,
      int xpRequired,
      double xpProgress,
      ) {
    final nextMilestone = XPService.nextMilestone(userLevel);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.06)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.white12 : Colors.black12, width: 0.5),
      ),
      child: Column(children: [
        // ── Level info row ──
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Overall Progress',
              style: TextStyle(fontSize: 13, color: subColor)),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE91E8C), Color(0xFF9C27B0)],
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Level $userLevel',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ]),

        const SizedBox(height: 12),

        // ── Level progress bar (level / 100) ──
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Level Progress',
                  style: TextStyle(fontSize: 11, color: subColor)),
              Text('$userLevel / 100',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: userLevel / 100,
              backgroundColor: isDark ? Colors.white24 : Colors.black12,
              valueColor:
              const AlwaysStoppedAnimation(Color(0xFFE91E8C)),
              minHeight: 8,
            ),
          ),
        ]),

        const SizedBox(height: 10),

        // ── XP progress bar (current level XP) ──
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('XP Progress',
                  style: TextStyle(fontSize: 11, color: subColor)),
              Text(
                '${_formatXP(userXP)} / ${_formatXP(xpRequired)} XP',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: xpProgress,
              backgroundColor: isDark ? Colors.white24 : Colors.black12,
              valueColor:
              const AlwaysStoppedAnimation(Color(0xFFFF9800)),
              minHeight: 8,
            ),
          ),
        ]),

        const SizedBox(height: 10),

        // ── Next milestone ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              userLevel >= 100
                  ? '👑 Supreme King — Max Level!'
                  : '🎯 Next reward at Level $nextMilestone',
              style: TextStyle(fontSize: 12, color: subColor),
            ),
            Text(
              userLevel >= 100 ? '🔥 GOD' : '${100 - userLevel} levels to go',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // ── Milestone steps ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _progressSteps
              .map((s) => Text(s,
              style: TextStyle(fontSize: 9, color: subColor)))
              .toList(),
        ),
      ]),
    );
  }

  // ── Level Card ───────────────────────────────────────────────
  Widget _buildLevelCard(
      BuildContext context,
      _LevelData l,
      int index,
      bool isDark,
      Color textColor,
      Color subColor,
      int userLevel,
      Map<String, dynamic> rewards,
      ) {
    // ✅ Unlock check: level poora ho ya reward map mein true ho
    final bool unlocked = userLevel >= l.level ||
        (rewards[_rewardKey(l.level)] as bool? ?? false);
    final is100 = l.level == 100;

    return GestureDetector(
      onTap: () => _showDetail(context, l, index, unlocked, isDark),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: is100 && unlocked
              ? null
              : isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.white,
          gradient: is100 && unlocked
              ? const LinearGradient(colors: [
            Color(0xFFFF9800),
            Color(0xFFF44336),
            Color(0xFF9C27B0),
          ])
              : null,
          borderRadius: BorderRadius.circular(14),
          border: Border(
            left: unlocked
                ? BorderSide(color: l.accentColor, width: 3)
                : BorderSide.none,
            top: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 0.5),
            right: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 0.5),
            bottom: BorderSide(
                color: isDark ? Colors.white12 : Colors.black12,
                width: 0.5),
          ),
        ),
        child: Row(children: [
          _buildBadgeIcon(l, unlocked, isDark),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.name,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: is100 && unlocked
                                ? Colors.white
                                : textColor)),
                    const SizedBox(height: 3),
                    Text(l.desc,
                        style: TextStyle(
                            fontSize: 11,
                            color: is100 && unlocked
                                ? Colors.white70
                                : subColor)),
                  ])),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: is100 && unlocked
                    ? Colors.white24
                    : l.tagBg.withOpacity(isDark ? 0.3 : 1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(l.tag,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: is100 && unlocked
                          ? Colors.white
                          : l.tagText)),
            ),
            const SizedBox(height: 6),
            // ✅ Unlock icon — real-time
            Text(unlocked ? '✅' : '🔒',
                style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text('Details',
                style: TextStyle(
                    fontSize: 11,
                    color: is100 && unlocked
                        ? Colors.white70
                        : subColor)),
          ]),
        ]),
      ),
    );
  }

  // ── Reward key helper (XPService ke saath match) ─────────────
  String _rewardKey(int level) {
    switch (level) {
      case 10:  return 'voice_changer';
      case 20:  return 'emoji_bomb';
      case 30:  return 'flash_message';
      case 40:  return 'stealth_mode';
      case 50:  return 'level_booster_gift';
      case 60:  return 'gold_badge';
      case 70:  return 'silver_badge';
      case 80:  return 'platinum_badge';
      case 90:  return 'diamond_badge';
      case 100: return 'legendary_badge';
      default:  return '';
    }
  }

  // ── XP number format (1000 → 1K, 1000000 → 1M) ──────────────
  String _formatXP(int xp) {
    if (xp >= 1000000) return '${(xp / 1000000).toStringAsFixed(1)}M';
    if (xp >= 1000)    return '${(xp / 1000).toStringAsFixed(1)}K';
    return '$xp';
  }

  Widget _buildBadgeIcon(_LevelData l, bool unlocked, bool isDark) {
    if (l.badgeB64 != null && l.badgeB64!.isNotEmpty) {
      final Uint8List? bytes = safeBase64Decode(l.badgeB64!);
      if (bytes != null) {
        if (unlocked) {
          return Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: l.accentColor.withOpacity(0.55),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Image.memory(bytes,
                width: 52,
                height: 52,
                fit: BoxFit.contain,
                gaplessPlayback: true),
          );
        } else {
          return Stack(alignment: Alignment.center, children: [
            Opacity(
              opacity: 0.30,
              child: Image.memory(bytes,
                  width: 52,
                  height: 52,
                  fit: BoxFit.contain,
                  gaplessPlayback: true),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.40),
              ),
              child:
              const Icon(Icons.lock, color: Colors.white60, size: 22),
            ),
          ]);
        }
      }
    }
    return _emojiBox(l, isDark);
  }

  Widget _emojiBox(_LevelData l, bool isDark) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: isDark ? l.tagBg.withOpacity(0.3) : l.tagBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(l.emoji, style: const TextStyle(fontSize: 22)),
        Text('Lv ${l.level}',
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : l.tagText)),
      ]),
    );
  }

  void _showDetail(BuildContext context, _LevelData l, int index,
      bool unlocked, bool isDark) {
    final Uint8List? bytes =
    (l.badgeB64 != null && l.badgeB64!.isNotEmpty)
        ? safeBase64Decode(l.badgeB64!)
        : null;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2))),

          if (bytes != null)
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                      color: l.accentColor.withOpacity(0.65),
                      blurRadius: 24,
                      spreadRadius: 5)
                ],
              ),
              child: Image.memory(bytes,
                  fit: BoxFit.contain, gaplessPlayback: true),
            )
          else
            Text(l.emoji, style: const TextStyle(fontSize: 60)),

          const SizedBox(height: 12),
          Text('Level ${l.level} — ${l.name}',
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_details[index],
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontSize: 13,
                  height: 1.5)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: unlocked
                  ? Colors.green.withOpacity(0.15)
                  : Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              unlocked
                  ? '🎉 Congratulations! This feature is now unlocked!'
                  : '🔒 Reach Level ${l.level} to unlock this reward!',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: unlocked ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close',
                  style: TextStyle(
                      color:
                      isDark ? Colors.white70 : Colors.black54)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Level Data Model ─────────────────────────────────────────
class _LevelData {
  final int level;
  final String name;
  final String desc;
  final String emoji;
  final String? badgeB64;
  final String tag;
  final Color tagBg;
  final Color tagText;
  final Color accentColor;

  const _LevelData(this.level, this.name, this.desc, this.emoji,
      this.badgeB64, this.tag, this.tagBg, this.tagText, this.accentColor);
}