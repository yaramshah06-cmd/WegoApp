import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum BadgeTier { bronze, silver, gold, platinum, diamond, legendary }

class BadgeData {
  final BadgeTier tier;
  final String label;
  final String imagePath;
  final Color glowColor;
  final String description;
  final int requiredLevel;

  const BadgeData({
    required this.tier,
    required this.label,
    required this.imagePath,
    required this.glowColor,
    required this.description,
    required this.requiredLevel,
  });
}

final List<BadgeData> allBadges = [
  BadgeData(
    tier: BadgeTier.gold,
    label: 'Gold',
    imagePath: 'assets/badges/gold.png',       // ✅ .png
    glowColor: Color(0xFFFFD700),
    description: 'Level 60 pe unlock',
    requiredLevel: 60,
  ),
  BadgeData(
    tier: BadgeTier.silver,
    label: 'Silver',
    imagePath: 'assets/badges/silver.png',     // ✅ .png
    glowColor: Color(0xFFC0C0C0),
    description: 'Level 70 pe unlock',
    requiredLevel: 70,
  ),
  BadgeData(
    tier: BadgeTier.platinum,
    label: 'Platinum',
    imagePath: 'assets/badges/platinum.png',   // ✅ .png
    glowColor: Color(0xFF87CEEB),
    description: 'Level 80 pe unlock',
    requiredLevel: 80,
  ),
  BadgeData(
    tier: BadgeTier.diamond,
    label: 'Diamond',
    imagePath: 'assets/badges/diamond.png',    // ✅ .png
    glowColor: Color(0xFF00FFFF),
    description: 'Level 90 pe unlock',
    requiredLevel: 90,
  ),
  BadgeData(
    tier: BadgeTier.legendary,
    label: 'Legendary',
    imagePath: 'assets/badges/legendary.png',  // ✅ .png
    glowColor: Color(0xFF9B59B6),
    description: 'Level 100 pe unlock',
    requiredLevel: 100,
  ),
];

// =============================================
// SINGLE BADGE WIDGET
// =============================================
class AchievementBadgeWidget extends StatelessWidget {
  final BadgeData badge;
  final double size;
  final bool isUnlocked;
  final bool showLabel;

  const AchievementBadgeWidget({
    Key? key,
    required this.badge,
    this.size = 100,
    this.isUnlocked = false,
    this.showLabel = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            // Glow ring — sirf unlocked ke liye
            if (isUnlocked)
              Container(
                width: size + 16,
                height: size + 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: badge.glowColor.withOpacity(0.65),
                      blurRadius: 24,
                      spreadRadius: 6,
                    ),
                  ],
                ),
              ),

            // Unlocked — PNG transparent bg, seedha dikhao (no ColorFiltered, no ClipOval)
            if (isUnlocked)
              Image.asset(
                badge.imagePath,
                width: size,
                height: size,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.emoji_events,
                    color: badge.glowColor,
                    size: size * 0.7,
                  );
                },
              ),

            // Locked — greyscale filter
            if (!isUnlocked)
              ColorFiltered(
                colorFilter: const ColorFilter.matrix([
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0,      0,      0,      1, 0,
                ]),
                child: Image.asset(
                  badge.imagePath,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.emoji_events,
                      color: Colors.grey,
                      size: size * 0.7,
                    );
                  },
                ),
              ),

            // Lock icon overlay — sirf locked ke liye
            if (!isUnlocked)
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.45),
                ),
                child: Icon(
                  Icons.lock,
                  color: Colors.white54,
                  size: size * 0.35,
                ),
              ),
          ],
        ),

        if (showLabel) ...[
          const SizedBox(height: 10),
          Text(
            badge.label,
            style: TextStyle(
              color: isUnlocked ? badge.glowColor : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: size * 0.14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            isUnlocked ? '✅ Unlocked!' : 'Level ${badge.requiredLevel} chahiye',
            style: TextStyle(
              color: isUnlocked ? Colors.greenAccent : Colors.white38,
              fontSize: size * 0.10,
            ),
          ),
        ],
      ],
    );
  }
}

// =============================================
// BADGES PAGE — Firestore se level fetch karta hai
// =============================================
class BadgesGridPage extends StatelessWidget {
  const BadgesGridPage({Key? key}) : super(key: key);

  Future<int> _getUserLevel() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return 0;

      final doc = await FirebaseFirestore.instance
          .collection('users')       // 👈 apna collection name
          .doc(uid)
          .get();

      return (doc.data()?['level'] ?? 0) as int; // 👈 apna field name
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        title: const Text(
          'Achievements',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<int>(
        future: _getUserLevel(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.amber),
            );
          }

          final userLevel = snapshot.data ?? 0;

          return Column(
            children: [
              // User ka current level
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Tumhara Level: $userLevel',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              // Badges Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 30,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: allBadges.length,
                  itemBuilder: (context, index) {
                    final badge = allBadges[index];
                    final isUnlocked = userLevel >= badge.requiredLevel;
                    return AchievementBadgeWidget(
                      badge: badge,
                      size: 110,
                      isUnlocked: isUnlocked,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}