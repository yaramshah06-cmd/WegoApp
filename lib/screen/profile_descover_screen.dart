import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Colors ───────────────────────────────────────────────────
const Color kPurple = Color(0xFF7A1730);
const Color kPurpleLight = Color(0xFFC2415E);
const Color kTeal = Color(0xFF2EC4B6);
const Color kCardBg = Color(0xFFFBEAEE);

// ── Profile Model ─────────────────────────────────────────────
class ProfileData {
  final String name;
  final int age;
  final String city;
  final String distance;
  final String imageUrl;
  final String bio;
  final List<String> interests;

  const ProfileData({
    required this.name,
    required this.age,
    required this.city,
    required this.distance,
    required this.imageUrl,
    required this.bio,
    required this.interests,
  });
}

// ── Sample Profile ────────────────────────────────────────────
const ProfileData sampleProfile = ProfileData(
  name: 'Tanisha Agrawal',
  age: 24,
  city: 'Delhi',
  distance: '11km',
  imageUrl:
  'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=600&q=80',
  bio:
  'Lover of cold coffee, deep convos, and spontaneous weekend trips. If you can beat me at Uno, you win my heart',
  interests: ['coffee', 'cats', 'R&B'],
);

// ── Main Screen ───────────────────────────────────────────────
class ProfileDiscoveryScreen extends StatefulWidget {
  final ProfileData? profile;
  const ProfileDiscoveryScreen({super.key, this.profile});

  @override
  State<ProfileDiscoveryScreen> createState() => _ProfileDiscoveryScreenState();
}

class _ProfileDiscoveryScreenState extends State<ProfileDiscoveryScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: kPurple,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final displayProfile = widget.profile ?? sampleProfile;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Status bar colour
          Container(
            color: kPurple,
            height: MediaQuery.of(context).padding.top,
          ),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // ── Profile Card ──
                  _ProfileCard(profile: displayProfile),
                  const SizedBox(height: 12),
                  // ── Bio Card ──
                  _BioCard(profile: displayProfile, textColor: textColor, isDark: isDark),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── FAB ──
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: kTeal,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ── Bottom Nav ──
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Profile Card with image + action buttons ──────────────────
class _ProfileCard extends StatelessWidget {
  final ProfileData profile;
  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // ── Photo ──
            SizedBox(
              width: screenW,
              height: screenW * 1.15,
              child: Image.network(
                profile.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: Colors.grey[200],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Icon(Icons.person, size: 80, color: Colors.grey),
                ),
              ),
            ),

            // ── Gradient overlay ──
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.70),
                    ],
                    stops: const [0.45, 1.0],
                  ),
                ),
              ),
            ),

            // ── "Bio" badge ──
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5), width: 1),
                ),
                child: const Text(
                  'Bio',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // ── Name / Age / City ──
            Positioned(
              left: 18,
              bottom: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${profile.age},',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    profile.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${profile.city}, ${profile.distance}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // ── Action Buttons ──
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      icon: Icons.close,
                      bgColor: Colors.white,
                      iconColor: Colors.black87,
                      size: 52,
                      iconSize: 24,
                      onTap: () {},
                    ),
                    _ActionButton(
                      icon: Icons.remove,
                      bgColor: kPurple,
                      iconColor: Colors.white,
                      size: 52,
                      iconSize: 28,
                      onTap: () {},
                    ),
                    _ActionButton(
                      icon: Icons.star,
                      bgColor: kPurple,
                      iconColor: Colors.white,
                      size: 52,
                      iconSize: 26,
                      onTap: () {},
                    ),
                    _ActionButton(
                      icon: Icons.favorite,
                      bgColor: Colors.white,
                      iconColor: Colors.pink,
                      size: 52,
                      iconSize: 24,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bio Card ─────────────────────────────────────────────────
class _BioCard extends StatelessWidget {
  final ProfileData profile;
  final Color textColor;
  final bool isDark;
  const _BioCard({required this.profile, required this.textColor, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : kCardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bio text
            Text(
              profile.bio,
              style: TextStyle(
                fontSize: 14,
                color: textColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            // Interest chips
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.interests
                  .map((tag) => _InterestChip(label: tag, isDark: isDark, textColor: textColor))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Interest Chip ─────────────────────────────────────────────
class _InterestChip extends StatelessWidget {
  final String label;
  final bool isDark;
  final Color textColor;
  const _InterestChip({required this.label, required this.isDark, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade200),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: textColor,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Round Action Button ───────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final double size;
  final double iconSize;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.size,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor, size: iconSize),
      ),
    );
  }
}

// ── Bottom Navigation Bar ─────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: kPurple,
      elevation: 10,
      notchMargin: 8,
      shape: const CircularNotchedRectangle(),
      child: SizedBox(
        height: 62,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home,
              label: 'Home',
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.favorite_border,
              label: 'Match',
              selected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
            const SizedBox(width: 48), // FAB space
            _NavItem(
              icon: Icons.chat_bubble_outline,
              label: 'chats',
              selected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
            _NavItem(
              icon: Icons.person,
              label: 'Profile',
              selected: currentIndex == 3,
              onTap: () => onTap(3),
              showCircle: currentIndex == 3,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showCircle;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.showCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          showCircle
              ? Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          )
              : Icon(
            icon,
            color:
            selected ? Colors.white : Colors.white.withValues(alpha: 0.6),
            size: 26,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: selected ? Colors.white : Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}