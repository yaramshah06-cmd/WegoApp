import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// ════════════════════════════════════════════════════════════════════════════
//  LevelBadge — Reusable level chip jo kisi bhi user ki profile pic ke
//  neeche show hota hai. Realtime Firebase se level fetch karta hai aur
//  level ke hisaab se tier color deta hai (Bronze → Legendary).
//
//  Usage:
//    LevelBadge(uid: someUserUid)
//    LevelBadge(uid: someUserUid, size: LevelBadgeSize.small)
// ════════════════════════════════════════════════════════════════════════════

enum LevelBadgeSize { small, medium, large }

class LevelBadge extends StatelessWidget {
  final String uid;
  final LevelBadgeSize size;

  const LevelBadge({
    super.key,
    required this.uid,
    this.size = LevelBadgeSize.medium,
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
        // Loading state — kuch nahi dikhao (chhoti placeholder)
        if (!snapshot.hasData) {
          return _buildShell(level: 0, isLoading: true);
        }

        final data = snapshot.data?.data() ?? {};
        final int level = (data['level'] as num?)?.toInt() ?? 1;
        return _buildShell(level: level, isLoading: false);
      },
    );
  }

  Widget _buildShell({required int level, required bool isLoading}) {
    final tier = _LevelTier.forLevel(level);

    // Sizes per variant
    final double fontSize;
    final double iconSize;
    final EdgeInsets padding;
    switch (size) {
      case LevelBadgeSize.small:
        fontSize = 10;
        iconSize = 11;
        padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2);
        break;
      case LevelBadgeSize.large:
        fontSize = 14;
        iconSize = 16;
        padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 5);
        break;
      case LevelBadgeSize.medium:
        fontSize = 12;
        iconSize = 13;
        padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4);
        break;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [tier.start, tier.end],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: tier.end.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(tier.icon, color: Colors.white, size: iconSize),
          const SizedBox(width: 4),
          Text(
            isLoading ? 'Lv —' : 'Lv $level',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Level → Tier color/icon mapping ────────────────────────────────────────
class _LevelTier {
  final Color start;
  final Color end;
  final IconData icon;
  const _LevelTier(this.start, this.end, this.icon);

  static _LevelTier forLevel(int lvl) {
    if (lvl >= 100) {
      // Legendary — purple/violet
      return const _LevelTier(
          Color(0xFF9B59B6), Color(0xFF6A0DAD), Icons.workspace_premium);
    }
    if (lvl >= 90) {
      // Diamond — cyan
      return const _LevelTier(
          Color(0xFF00E5FF), Color(0xFF00BCD4), Icons.diamond);
    }
    if (lvl >= 80) {
      // Platinum — sky blue
      return const _LevelTier(
          Color(0xFF87CEEB), Color(0xFF1565C0), Icons.shield);
    }
    if (lvl >= 70) {
      // Silver — grey/blue
      return const _LevelTier(
          Color(0xFFC0C0C0), Color(0xFF607D8B), Icons.military_tech);
    }
    if (lvl >= 60) {
      // Gold — yellow/orange
      return const _LevelTier(
          Color(0xFFFFD700), Color(0xFFFFA000), Icons.emoji_events);
    }
    if (lvl >= 40) {
      // Pro — pink/magenta
      return const _LevelTier(
          Color(0xFFE91E8C), Color(0xFFAD1457), Icons.star);
    }
    if (lvl >= 20) {
      // Rising — green
      return const _LevelTier(
          Color(0xFF4CAF50), Color(0xFF1B5E20), Icons.trending_up);
    }
    // Bronze / Starter — orange/brown
    return const _LevelTier(
        Color(0xFFE87C3E), Color(0xFF8D5524), Icons.bolt);
  }
}
