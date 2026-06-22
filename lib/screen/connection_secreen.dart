import 'package:flutter/material.dart';

// ─── Data Model ──────────────────────────────────────────────────────────────
class MatchUser {
  final String name;
  final int age;
  final String imageUrl;
  final bool hasLiked; // shows red heart badge

  const MatchUser({
    required this.name,
    required this.age,
    required this.imageUrl,
    this.hasLiked = false,
  });
}

// ─── Sample Data ─────────────────────────────────────────────────────────────
final List<MatchUser> matches = [
  MatchUser(
    name: 'Leilani',
    age: 19,
    imageUrl: 'https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=400',
  ),
  MatchUser(
    name: 'Annabelle',
    age: 20,
    imageUrl: 'https://images.unsplash.com/photo-1488716820095-cbe80883c496?w=400',
  ),
  MatchUser(
    name: 'Reagan',
    age: 24,
    imageUrl: 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=400',
  ),
  MatchUser(
    name: 'Hadley',
    age: 25,
    imageUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=400',
  ),
  MatchUser(
    name: 'Kyle',
    age: 24,
    imageUrl: 'https://images.unsplash.com/photo-1508214751196-bcfd4ca60f91?w=400',
  ),
  MatchUser(
    name: 'Kyle',
    age: 24,
    imageUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=400',
    hasLiked: true,
  ),
];

// ─── Main Screen ─────────────────────────────────────────────────────────────
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  int _currentIndex = 0;

  static const Color primaryPurple = Color(0xFF7A1730);
  static const Color tealGreen = Color(0xFF2DBD9B);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ─── Status Bar Spacer ──────────────────────────────
          Container(
            color: primaryPurple,
            height: MediaQuery.of(context).padding.top,
          ),

          // ─── Header ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Matches',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'This is a list of people who have liked you\nand your matches.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black54,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                // Profile icon top right
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(color: primaryPurple, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      '1L',
                      style: TextStyle(
                        color: primaryPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Grid ──────────────────────────────────────────
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.78,
              ),
              itemCount: matches.length,
              itemBuilder: (context, index) {
                return _MatchCard(user: matches[index]);
              },
            ),
          ),
        ],
      ),

      // ─── FAB ───────────────────────────────────────────────
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: tealGreen,
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // ─── Bottom Nav ────────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      color: primaryPurple,
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            _NavItem(
              icon: Icons.home,
              label: 'Home',
              selected: _currentIndex == 0,
              onTap: () => setState(() => _currentIndex = 0),
            ),
            _NavItem(
              icon: Icons.favorite_border,
              label: 'Match',
              selected: _currentIndex == 1,
              onTap: () => setState(() => _currentIndex = 1),
            ),
            const SizedBox(width: 60), // FAB notch space
            _NavItem(
              icon: Icons.chat_bubble_outline,
              label: 'chats',
              selected: _currentIndex == 2,
              onTap: () => setState(() => _currentIndex = 2),
            ),
            _NavItem(
              icon: Icons.person_outline,
              label: '',
              selected: _currentIndex == 3,
              onTap: () => setState(() => _currentIndex = 3),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Nav Item ────────────────────────────────────────────────────────────────
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : Colors.white60,
              size: 24,
            ),
            if (label.isNotEmpty)
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white60,
                  fontSize: 11,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Match Card ──────────────────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final MatchUser user;

  const _MatchCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background Image ──────────────────────────────
          Image.network(
            user.imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                color: Colors.grey[300],
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (error, stackTrace, widget) => Container(
              color: Colors.grey[400],
              child: const Icon(Icons.person, size: 60, color: Colors.white),
            ),
          ),

          // ── Gradient overlay (bottom) ─────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.75),
                  ],
                ),
              ),
            ),
          ),

          // ── Name & Age ────────────────────────────────────
          Positioned(
            left: 10,
            bottom: 48,
            child: Text(
              '${user.name}, ${user.age}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                shadows: [
                  Shadow(blurRadius: 4, color: Colors.black45),
                ],
              ),
            ),
          ),

          // ── Action Buttons (X and Heart) ──────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // X button
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                  // Divider
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.white24,
                  ),
                  // Heart button
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Red Heart Badge (top right, if liked) ─────────
          if (user.hasLiked)
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
