import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LegendaryAnnouncementService {
  // Har user ka alag cooldown key
  static String _prefKey(String uid) => 'legendary_announced_$uid';
  static const Duration _cooldown = Duration(hours: 5);

  /// Current logged-in user ka level check karta hai.
  /// Agar level >= 100 ho aur 1 ghanta guzar gaya ho —
  /// fullName return karta hai, warna null.
  static Future<String?> checkAndGetLegendaryUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return null;

    final uid = currentUser.uid;

    try {
      // 1. Firestore se user document fetch karo
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) return null;

      final data = userDoc.data() as Map<String, dynamic>;

      // level field — int64 Firestore se int aata hai
      final rawLevel = data['level'];
      final int level = rawLevel is int
          ? rawLevel
          : rawLevel is double
          ? rawLevel.toInt()
          : int.tryParse(rawLevel?.toString() ?? '0') ?? 0;

      // Legendary = level 100 ya usse zyada
      if (level < 100) return null;

      // 2. Per-user 1 ghante ka cooldown
      final prefs = await SharedPreferences.getInstance();
      final key = _prefKey(uid);
      final lastAnnouncedMs = prefs.getInt(key);

      if (lastAnnouncedMs != null) {
        final lastAnnounced =
        DateTime.fromMillisecondsSinceEpoch(lastAnnouncedMs);
        final elapsed = DateTime.now().difference(lastAnnounced);
        if (elapsed < _cooldown) return null;
      }

      // 3. Timestamp save karo
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);

      // 4. fullName field se naam lo — yahi tumhari app use karti hai
      final fullName = data['fullName'] as String?;
      if (fullName == null || fullName.trim().isEmpty) return null;

      return fullName.trim();
    } catch (_) {
      return null; // silently fail — feed crash na ho
    }
  }
}