import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:wego_marriage/screen/epic_badges_screen.dart';
import 'package:wego_marriage/widgets/level_badge.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LatestBadgeChip — Ek hi inline slot mein:
//    • Agar user ka koi image badge unlocked hai → highest tier PNG dikhega
//      (gold/diamond/legendary etc) ek chhota circle mein glow ke saath.
//    • Agar koi image badge unlock nahi (level < 20) → Lv X chip dikhega
//      (LevelBadge), taake low-level users ka level bhi visible rahe.
//
//  Pro-app style — username/follow button ke saath inline use karein.
// ════════════════════════════════════════════════════════════════════════════

class LatestBadgeChip extends StatelessWidget {
  final String uid;
  final double size;
  final LevelBadgeSize fallbackChipSize;

  const LatestBadgeChip({
    super.key,
    required this.uid,
    this.size = 22,
    this.fallbackChipSize = LevelBadgeSize.small,
  });

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data?.data() ?? {};
        final int level = (data['level'] as num?)?.toInt() ?? 0;

        final unlocked =
            kBadgeList.where((b) => level >= b.level).toList();

        // Koi image badge unlock nahi → Lv chip dikhao
        if (unlocked.isEmpty) {
          return LevelBadge(uid: uid, size: fallbackChipSize);
        }

        // Highest tier unlocked image badge
        final BadgeData highest = unlocked.last;
        final Uint8List? bytes = safeBase64Decode(highest.badgeB64);

        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: highest.glowColor.withValues(alpha: 0.45),
                blurRadius: 8,
                spreadRadius: 0,
              ),
            ],
          ),
          child: bytes != null
              ? Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true)
              : Icon(
                  Icons.emoji_events_rounded,
                  color: highest.glowColor,
                  size: size * 0.85,
                ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  UnlockedBadgesRow — Saare unlocked image badges ek line mein, jaisa
//  my_profile mein dikhta hai. Use this in OTHER users' profile screens
//  taake unke saare unlocked badges visible ho.
// ════════════════════════════════════════════════════════════════════════════

class UnlockedBadgesRow extends StatelessWidget {
  final String uid;
  final double badgeSize;
  final VoidCallback? onTap;

  const UnlockedBadgesRow({
    super.key,
    required this.uid,
    this.badgeSize = 38,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final data = snapshot.data?.data() ?? {};
        final int level = (data['level'] as num?)?.toInt() ?? 0;

        final unlocked =
            kBadgeList.where((b) => level >= b.level).toList();
        if (unlocked.isEmpty) return const SizedBox.shrink();

        final row = Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(unlocked.length, (i) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _TinyBadgeView(
                  badge: unlocked[i],
                  size: badgeSize,
                ),
              );
            }),
          ),
        );

        if (onTap == null) return row;
        return GestureDetector(onTap: onTap, child: row);
      },
    );
  }
}

class _TinyBadgeView extends StatelessWidget {
  final BadgeData badge;
  final double size;
  const _TinyBadgeView({required this.badge, required this.size});

  @override
  Widget build(BuildContext context) {
    final bytes = safeBase64Decode(badge.badgeB64);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: badge.glowColor.withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: bytes != null
          ? Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true)
          : Icon(
              Icons.emoji_events_rounded,
              color: badge.glowColor,
              size: size * 0.6,
            ),
    );
  }
}
