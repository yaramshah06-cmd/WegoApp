// ============================================================
// xp_service.dart — Fixed XP & Level System
// ============================================================
// BUG FIXES:
//   1. Level-up loop: ab NEXT level ka XP requirement check hoga
//   2. Topup: max 50 level boost per topup (2500 USD = 50 levels)
//   3. XP overflow: large XP gains se zyada level jump nahi hoga
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

// ─── XP Actions ──────────────────────────────────────────────
enum XPAction {
  dailyLogin,       // +50  XP
  postBanana,       // +100 XP
  commentKarna,     // +30  XP
  likeKarna,        // +10  XP
  messageBhejna,    // +20  XP
  profileComplete,  // +200 XP (sirf ek baar)
  topup,            // Amount pe depend karta hai
}

// ─── XP Per Action ───────────────────────────────────────────
const Map<XPAction, int> xpRewards = {
  XPAction.dailyLogin:      50,
  XPAction.postBanana:      100,
  XPAction.commentKarna:    30,
  XPAction.likeKarna:       10,
  XPAction.messageBhejna:   20,
  XPAction.profileComplete: 200,
  XPAction.topup:           0,
};

// ─── Level XP Requirements ───────────────────────────────────
// Yeh XP hai jo us level ko COMPLETE karne ke liye chahiye
// Matlab: Level 1 complete karne ke liye 10,000 XP chahiye → Level 2 milega
const Map<int, int> levelXPRequired = {
  1:   10000,
  2:   10000,
  3:   10000,
  4:   10000,
  5:   10000,
  6:   10000,
  7:   10000,
  8:   10000,
  9:   10000,
  10:  10000,   // 🎁 Reward: Voice Changer
  11:  20000,
  12:  20000,
  13:  20000,
  14:  20000,
  15:  20000,
  16:  20000,
  17:  20000,
  18:  20000,
  19:  20000,
  20:  20000,   // 🎁 Reward: Emoji Bomb
  21:  30000,
  22:  30000,
  23:  30000,
  24:  30000,
  25:  30000,
  26:  30000,
  27:  30000,
  28:  30000,
  29:  30000,
  30:  30000,   // 🎁 Reward: Flash Message
  31:  40000,
  32:  40000,
  33:  40000,
  34:  40000,
  35:  40000,
  36:  40000,
  37:  40000,
  38:  40000,
  39:  40000,
  40:  40000,   // 🎁 Reward: Stealth Mode
  41:  100000,
  42:  100000,
  43:  100000,
  44:  100000,
  45:  100000,
  46:  100000,
  47:  100000,
  48:  100000,
  49:  100000,
  50:  100000,  // 🎁 Reward: Level Booster Gift
  51:  150000,
  52:  150000,
  53:  150000,
  54:  150000,
  55:  150000,
  56:  150000,
  57:  150000,
  58:  150000,
  59:  150000,
  60:  150000,  // 🎁 Reward: Gold Badge
  61:  400000,
  62:  400000,
  63:  400000,
  64:  400000,
  65:  400000,
  66:  400000,
  67:  400000,
  68:  400000,
  69:  400000,
  70:  400000,  // 🎁 Reward: Silver Badge
  71:  500000,
  72:  500000,
  73:  500000,
  74:  500000,
  75:  500000,
  76:  500000,
  77:  500000,
  78:  500000,
  79:  500000,
  80:  500000,  // 🎁 Reward: Platinum Badge
  81:  700000,
  82:  700000,
  83:  700000,
  84:  700000,
  85:  700000,
  86:  700000,
  87:  700000,
  88:  700000,
  89:  700000,
  90:  700000,  // 🎁 Reward: Diamond Badge
  91:  1000000,
  92:  1000000,
  93:  1000000,
  94:  1000000,
  95:  1000000,
  96:  1000000,
  97:  1000000,
  98:  1000000,
  99:  1000000,
  100: 1000000, // 🎁 Reward: Legendary Badge — SUPREME KING
};

// ─── Reward Milestone Levels ─────────────────────────────────
const List<int> rewardMilestoneLevels = [
  10, 20, 30, 40, 50, 60, 70, 80, 90, 100
];

// ─── Rewards at each milestone ───────────────────────────────
const Map<int, String> rewardAtLevel = {
  10:  'voice_changer',
  20:  'emoji_bomb',
  30:  'flash_message',
  40:  'stealth_mode',
  50:  'level_booster_gift',
  60:  'gold_badge',
  70:  'silver_badge',
  80:  'platinum_badge',
  90:  'diamond_badge',
  100: 'legendary_badge',
};

// ─── Safety Constants ─────────────────────────────────────────
// Ek topup se max kitne levels boost honge
// 2500 USD = 50 levels (50 USD per level)
const int _maxTopupLevelBoostPerTransaction = 50;

// ─── Topup Level Boost ───────────────────────────────────────
// 50 USD   → +1 level  (2500 USD = 50 levels MAX)
// 5,000 PKR → +1 level
// MAX: 50 levels per topup (safety cap)
int _topupLevelBoost(double amountUSD, double amountPKR) {
  final usdBoost = (amountUSD / 50).floor();   // 50 USD per level
  final pkrBoost = (amountPKR / 5000).floor(); // 5,000 PKR per level
  final total = usdBoost + pkrBoost;
  // Safety cap — ek baar mein max 50 levels
  return total.clamp(0, _maxTopupLevelBoostPerTransaction);
}

// ════════════════════════════════════════════════════════════
//  XPService — Main Service Class
// ════════════════════════════════════════════════════════════
class XPService {
  static final _db = FirebaseFirestore.instance;

  // ──────────────────────────────────────────────────────────
  // MAIN FUNCTION: XP add karo aur level check karo
  // ──────────────────────────────────────────────────────────
  static Future<XPResult> addXP(
      String uid,
      XPAction action, {
        double topupAmountPKR = 0,
        double topupAmountUSD = 0,
      }) async {
    try {
      final docRef = _db.collection('users').doc(uid);

      return await _db.runTransaction<XPResult>((transaction) async {
        final snap = await transaction.get(docRef);
        if (!snap.exists) {
          return XPResult(success: false, message: 'User not found');
        }

        final data = snap.data()!;
        int currentLevel = (data['level'] as num?)?.toInt() ?? 1;
        int currentXP    = (data['levelXP'] as num?)?.toInt() ?? 0;

        // Sanity check: level valid range mein hona chahiye
        currentLevel = currentLevel.clamp(1, 100);
        currentXP    = currentXP.clamp(0, 10000000);

        // ── Max level check ──
        if (currentLevel >= 100) {
          return XPResult(
            success: true,
            level: 100,
            xp: currentXP,
            message: 'Max level reached!',
            leveledUp: false,
          );
        }

        // ── Topup: Direct level boost ──
        if (action == XPAction.topup) {
          final boost = _topupLevelBoost(topupAmountUSD, topupAmountPKR);
          if (boost <= 0) {
            return XPResult(
              success: false,
              message: 'Topup amount too low. Min: PKR 10,000 or USD 100',
            );
          }

          final newLevel = (currentLevel + boost).clamp(1, 100);
          final List<int> unlockedRewards = [];

          for (int lvl = currentLevel + 1; lvl <= newLevel; lvl++) {
            if (rewardMilestoneLevels.contains(lvl)) {
              unlockedRewards.add(lvl);
            }
          }

          final Map<String, dynamic> updateData = {
            'level': newLevel,
            'levelUpdatedAt': FieldValue.serverTimestamp(),
          };

          for (final lvl in unlockedRewards) {
            final rewardKey = rewardAtLevel[lvl];
            if (rewardKey != null) {
              updateData['rewards.$rewardKey'] = true;
              updateData['rewards.${rewardKey}_unlockedAt'] =
                  FieldValue.serverTimestamp();
            }
          }

          transaction.update(docRef, updateData);

          return XPResult(
            success: true,
            level: newLevel,
            xp: currentXP,
            leveledUp: newLevel > currentLevel,
            levelsGained: newLevel - currentLevel,
            unlockedRewards: unlockedRewards,
            message: 'Topup se ${newLevel - currentLevel} level(s) boost!',
          );
        }

        // ── Daily Login: Sirf ek baar per din ──
        if (action == XPAction.dailyLogin) {
          final lastLogin = data['lastDailyXP'] as Timestamp?;
          if (lastLogin != null) {
            final lastDate = lastLogin.toDate();
            final now = DateTime.now();
            if (lastDate.year == now.year &&
                lastDate.month == now.month &&
                lastDate.day == now.day) {
              return XPResult(
                success: true,
                level: currentLevel,
                xp: currentXP,
                message: 'Daily XP already claimed today',
                leveledUp: false,
              );
            }
          }
        }

        // ── Profile Complete: Sirf ek baar ──
        if (action == XPAction.profileComplete) {
          final alreadyClaimed = data['profileXPClaimed'] as bool? ?? false;
          if (alreadyClaimed) {
            return XPResult(
              success: true,
              level: currentLevel,
              xp: currentXP,
              message: 'Profile XP already claimed',
              leveledUp: false,
            );
          }
        }

        // ── XP calculate karo ──
        final gainedXP = xpRewards[action] ?? 0;
        int newXP = currentXP + gainedXP;
        int newLevel = currentLevel;
        final List<int> unlockedRewards = [];

        // ✅ FIX: Level-up loop
        // Pehle: levelXPRequired[newLevel] — CURRENT level ka XP check hota tha
        //        iska matlab Level 1 pe bhi Level 75 ka XP apply ho sakta tha
        // Ab:    levelXPRequired[newLevel] — CURRENT level complete karne ka XP
        //        yahi sahi hai: "mujhe level 1 se level 2 jaana hai toh 10,000 XP chahiye"
        while (newLevel < 100) {
          // Current level complete karne ke liye kitna XP chahiye
          final requiredToLevelUp = levelXPRequired[newLevel] ?? 1000000;

          if (newXP >= requiredToLevelUp) {
            newXP -= requiredToLevelUp;
            newLevel++;
            if (rewardMilestoneLevels.contains(newLevel)) {
              unlockedRewards.add(newLevel);
            }
          } else {
            // XP kam hai — level up nahi hoga
            break;
          }
        }

        // Extra safety: agar kisi wajah se level 100 se zyada ho gaya
        newLevel = newLevel.clamp(1, 100);
        if (newLevel >= 100) newXP = 0;

        // ── Firestore update ──
        final Map<String, dynamic> updateData = {
          'levelXP': newXP,
          'level': newLevel,
          'levelXPRequired': levelXPRequired[newLevel] ?? 1000000,
          'levelUpdatedAt': FieldValue.serverTimestamp(),
          'totalXPEarned': FieldValue.increment(gainedXP),
        };

        if (action == XPAction.dailyLogin) {
          updateData['lastDailyXP'] = FieldValue.serverTimestamp();
        }

        if (action == XPAction.profileComplete) {
          updateData['profileXPClaimed'] = true;
        }

        for (final lvl in unlockedRewards) {
          final rewardKey = rewardAtLevel[lvl];
          if (rewardKey != null) {
            updateData['rewards.$rewardKey'] = true;
            updateData['rewards.${rewardKey}_unlockedAt'] =
                FieldValue.serverTimestamp();
          }
        }

        transaction.update(docRef, updateData);

        return XPResult(
          success: true,
          level: newLevel,
          xp: newXP,
          xpGained: gainedXP,
          leveledUp: newLevel > currentLevel,
          levelsGained: newLevel - currentLevel,
          unlockedRewards: unlockedRewards,
          message: newLevel > currentLevel
              ? '🎉 Level Up! Level $newLevel!'
              : '+$gainedXP XP mili!',
        );
      });
    } catch (e) {
      return XPResult(success: false, message: 'XP error: $e');
    }
  }

  static bool leveledUp(int newLevel, int oldLevel) => newLevel > oldLevel;

  // ──────────────────────────────────────────────────────────
  // User ka current level aur XP fetch karo
  // ──────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getUserLevelData(String uid) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      if (!snap.exists) return {};
      final data = snap.data()!;
      return {
        'level':           (data['level']           as num?)?.toInt() ?? 1,
        'levelXP':         (data['levelXP']         as num?)?.toInt() ?? 0,
        'levelXPRequired': (data['levelXPRequired'] as num?)?.toInt() ?? 10000,
        'totalXPEarned':   (data['totalXPEarned']   as num?)?.toInt() ?? 0,
        'rewards':          data['rewards'] as Map<String, dynamic>? ?? {},
      };
    } catch (e) {
      return {};
    }
  }

  // ──────────────────────────────────────────────────────────
  // Check karo koi reward unlock hai ya nahi
  // ──────────────────────────────────────────────────────────
  static Future<bool> isRewardUnlocked(String uid, String rewardKey) async {
    try {
      final snap = await _db.collection('users').doc(uid).get();
      if (!snap.exists) return false;
      final rewards = snap.data()?['rewards'] as Map<String, dynamic>? ?? {};
      return rewards[rewardKey] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────
  // XP progress percentage (0.0 to 1.0) — progress bar ke liye
  // ──────────────────────────────────────────────────────────
  static double getXPProgress(int currentXP, int level) {
    final required = levelXPRequired[level] ?? 10000;
    return (currentXP / required).clamp(0.0, 1.0);
  }

  // ──────────────────────────────────────────────────────────
  // Next milestone level batao
  // ──────────────────────────────────────────────────────────
  static int nextMilestone(int currentLevel) {
    for (final milestone in rewardMilestoneLevels) {
      if (milestone > currentLevel) return milestone;
    }
    return 100;
  }

  // ──────────────────────────────────────────────────────────
  // ✅ NEW: Firestore mein galat level reset karne ka tool
  // Sirf admin use kare ya debug ke liye
  // Agar kisi user ka level wrongly 75 ho gaya hai toh:
  //   await XPService.resetUserLevel(uid, correctLevel: 1);
  // ──────────────────────────────────────────────────────────
  static Future<void> resetUserLevel(String uid, {int correctLevel = 1}) async {
    try {
      await _db.collection('users').doc(uid).update({
        'level':    correctLevel.clamp(1, 100),
        'levelXP':  0,
        'levelXPRequired': levelXPRequired[correctLevel] ?? 10000,
        'levelUpdatedAt':  FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // ignore
    }
  }
}

// ─── XP Result Model ─────────────────────────────────────────
class XPResult {
  final bool success;
  final int level;
  final int xp;
  final int xpGained;
  final bool leveledUp;
  final int levelsGained;
  final List<int> unlockedRewards;
  final String message;

  const XPResult({
    required this.success,
    this.level = 1,
    this.xp = 0,
    this.xpGained = 0,
    this.leveledUp = false,
    this.levelsGained = 0,
    this.unlockedRewards = const [],
    this.message = '',
  });
}