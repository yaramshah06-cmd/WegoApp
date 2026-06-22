import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wego_marriage/providers/story_provider.dart';
import 'package:wego_marriage/providers/chat_provider.dart';
import 'package:wego_marriage/screen/story_screen.dart';
import 'package:wego_marriage/screen/my_profile.dart';
import 'package:wego_marriage/screen/massage_list_screen.dart';
import 'package:wego_marriage/screen/comments_screen.dart';
import 'package:wego_marriage/screen/user_profile_screen.dart';
import 'package:wego_marriage/screen/match_screen.dart';
import 'package:wego_marriage/screen/Create_content_screen.dart';
import 'package:wego_marriage/services/local_storage_service.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  int _selectedIndex = 0;

  final List<Widget> _tabs = [
    const _HomeTab(),
    const MatchPopupScreen(),
    const SizedBox.shrink(), // Space for FAB
    const MessageListScreen(),
    const MyProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: _buildBottomNav(context),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildFab() {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: const BoxDecoration(
          color: Color(0xFF3DDC84),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x553DDC84),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CreateContentScreen(),
              ),
            );
          },
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.add, color: Colors.white, size: 30),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF7A1730);

    final List<Map<String, dynamic>> items = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.favorite_border, 'label': 'Match'},
      {'icon': null, 'label': ''},
      {'icon': Icons.chat_bubble_outline, 'label': 'Chats'},
      {'icon': Icons.person_outline, 'label': 'Profile'},
    ];

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121212) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          if (i == 2) return const SizedBox(width: 60);
          final bool selected = _selectedIndex == i;
          final color = selected
              ? primaryColor
              : (isDark ? Colors.white54 : Colors.black38);

          return GestureDetector(
            onTap: () {
              if (i == 3) {
                // Refresh chats when clicking the chat tab
                context.read<ChatProvider>().loadChats();
              }
              setState(() => _selectedIndex = i);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  items[i]['icon'] as IconData,
                  color: color,
                  size: 24,
                ),
                const SizedBox(height: 3),
                Text(
                  items[i]['label'] as String,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PROFILE MODEL  (matrimonial card data — easy to map from Firebase later)
// ─────────────────────────────────────────────────────────────
class MatchProfile {
  final String name;
  final int age;
  final String city;
  final String avatarUrl;
  final bool online;

  const MatchProfile({
    required this.name,
    required this.age,
    required this.city,
    required this.avatarUrl,
    this.online = false,
  });
}

// Success story (married/engaged couple) shown on the home page.
class SuccessStory {
  final String couple;
  final String city;
  final String imageUrl;
  const SuccessStory({required this.couple, required this.city, required this.imageUrl});
}

// Upcoming event / meetup item.
class EventItem {
  final String title;
  final String city;
  final String date;
  final String emoji;
  const EventItem({required this.title, required this.city, required this.date, required this.emoji});
}

class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  // Brand colours
  static const Color kMaroon = Color(0xFF7A1730);
  static const Color kRose = Color(0xFFC2415E);

  // Liked profile names (local for now — wire to backend later)
  final Set<String> _liked = {};

  // ── How many items are visible in each "See More" section. ──
  static const int _gridStep = 8;          // grid grows by this each tap
  static const int _recoStep = 6;          // carousel grows by this each tap
  int _gridVisible = _gridStep;            // grid items currently shown
  int _recoVisible = _recoStep;            // carousel items currently shown

  // Selected quick-filter chip index (-1 = none)
  int _selectedFilter = 0;

  // ── Demo profiles. Replace this list with Firebase data later. ──
  final List<MatchProfile> _profiles = const [
    MatchProfile(name: 'Ayesha',  age: 24, city: 'Lahore',     avatarUrl: 'https://randomuser.me/api/portraits/women/65.jpg', online: true),
    MatchProfile(name: 'Fatima',  age: 26, city: 'Karachi',    avatarUrl: 'https://randomuser.me/api/portraits/women/68.jpg'),
    MatchProfile(name: 'Zainab',  age: 23, city: 'Islamabad',  avatarUrl: 'https://randomuser.me/api/portraits/women/90.jpg', online: true),
    MatchProfile(name: 'Maryam',  age: 27, city: 'Faisalabad', avatarUrl: 'https://randomuser.me/api/portraits/women/72.jpg'),
    MatchProfile(name: 'Hira',    age: 25, city: 'Rawalpindi', avatarUrl: 'https://randomuser.me/api/portraits/women/45.jpg'),
    MatchProfile(name: 'Sana',    age: 28, city: 'Multan',     avatarUrl: 'https://randomuser.me/api/portraits/women/12.jpg', online: true),
    MatchProfile(name: 'Iqra',    age: 22, city: 'Lahore',     avatarUrl: 'https://randomuser.me/api/portraits/women/33.jpg'),
    MatchProfile(name: 'Noor',    age: 24, city: 'Peshawar',   avatarUrl: 'https://randomuser.me/api/portraits/women/52.jpg'),
    MatchProfile(name: 'Amna',    age: 26, city: 'Karachi',    avatarUrl: 'https://randomuser.me/api/portraits/women/24.jpg'),
    MatchProfile(name: 'Komal',   age: 23, city: 'Sialkot',    avatarUrl: 'https://randomuser.me/api/portraits/women/19.jpg', online: true),
    MatchProfile(name: 'Mahnoor', age: 25, city: 'Quetta',     avatarUrl: 'https://randomuser.me/api/portraits/women/56.jpg'),
    MatchProfile(name: 'Areeba',  age: 27, city: 'Hyderabad',  avatarUrl: 'https://randomuser.me/api/portraits/women/8.jpg'),
    MatchProfile(name: 'Hina',    age: 24, city: 'Lahore',     avatarUrl: 'https://randomuser.me/api/portraits/women/30.jpg', online: true),
    MatchProfile(name: 'Sadia',   age: 29, city: 'Karachi',    avatarUrl: 'https://randomuser.me/api/portraits/women/31.jpg'),
    MatchProfile(name: 'Mehwish', age: 26, city: 'Islamabad',  avatarUrl: 'https://randomuser.me/api/portraits/women/32.jpg'),
    MatchProfile(name: 'Sumbal',  age: 23, city: 'Sialkot',    avatarUrl: 'https://randomuser.me/api/portraits/women/35.jpg', online: true),
    MatchProfile(name: 'Nimra',   age: 25, city: 'Multan',     avatarUrl: 'https://randomuser.me/api/portraits/women/36.jpg'),
    MatchProfile(name: 'Javeria', age: 27, city: 'Faisalabad', avatarUrl: 'https://randomuser.me/api/portraits/women/37.jpg'),
    MatchProfile(name: 'Aqsa',    age: 22, city: 'Peshawar',   avatarUrl: 'https://randomuser.me/api/portraits/women/38.jpg', online: true),
    MatchProfile(name: 'Rida',    age: 24, city: 'Quetta',     avatarUrl: 'https://randomuser.me/api/portraits/women/39.jpg'),
  ];

  // ── Recommended profiles (shown in horizontal carousel below the grid). ──
  final List<MatchProfile> _recommended = const [
    MatchProfile(name: 'Rabia',   age: 25, city: 'Lahore',     avatarUrl: 'https://randomuser.me/api/portraits/women/79.jpg', online: true),
    MatchProfile(name: 'Saba',    age: 28, city: 'Karachi',    avatarUrl: 'https://randomuser.me/api/portraits/women/85.jpg'),
    MatchProfile(name: 'Eman',    age: 23, city: 'Islamabad',  avatarUrl: 'https://randomuser.me/api/portraits/women/91.jpg', online: true),
    MatchProfile(name: 'Laiba',   age: 26, city: 'Faisalabad', avatarUrl: 'https://randomuser.me/api/portraits/women/63.jpg'),
    MatchProfile(name: 'Tooba',   age: 24, city: 'Gujranwala', avatarUrl: 'https://randomuser.me/api/portraits/women/76.jpg'),
    MatchProfile(name: 'Aiman',   age: 27, city: 'Multan',     avatarUrl: 'https://randomuser.me/api/portraits/women/26.jpg', online: true),
    MatchProfile(name: 'Bisma',   age: 22, city: 'Sargodha',   avatarUrl: 'https://randomuser.me/api/portraits/women/41.jpg'),
    MatchProfile(name: 'Dua',     age: 25, city: 'Bahawalpur', avatarUrl: 'https://randomuser.me/api/portraits/women/57.jpg'),
    MatchProfile(name: 'Warda',   age: 24, city: 'Lahore',     avatarUrl: 'https://randomuser.me/api/portraits/women/44.jpg', online: true),
    MatchProfile(name: 'Anam',    age: 26, city: 'Karachi',    avatarUrl: 'https://randomuser.me/api/portraits/women/47.jpg'),
    MatchProfile(name: 'Kinza',   age: 23, city: 'Islamabad',  avatarUrl: 'https://randomuser.me/api/portraits/women/48.jpg'),
    MatchProfile(name: 'Maha',    age: 25, city: 'Faisalabad', avatarUrl: 'https://randomuser.me/api/portraits/women/49.jpg', online: true),
  ];

  // ── Profiles near you (location-based section). ──
  final List<MatchProfile> _nearYou = const [
    MatchProfile(name: 'Zoya',    age: 24, city: '2 km away',  avatarUrl: 'https://randomuser.me/api/portraits/women/50.jpg', online: true),
    MatchProfile(name: 'Manahil', age: 26, city: '4 km away',  avatarUrl: 'https://randomuser.me/api/portraits/women/51.jpg'),
    MatchProfile(name: 'Faiza',   age: 23, city: '5 km away',  avatarUrl: 'https://randomuser.me/api/portraits/women/53.jpg', online: true),
    MatchProfile(name: 'Hania',   age: 27, city: '7 km away',  avatarUrl: 'https://randomuser.me/api/portraits/women/54.jpg'),
    MatchProfile(name: 'Mishal',  age: 25, city: '9 km away',  avatarUrl: 'https://randomuser.me/api/portraits/women/55.jpg', online: true),
    MatchProfile(name: 'Aleena',  age: 22, city: '12 km away', avatarUrl: 'https://randomuser.me/api/portraits/women/58.jpg'),
  ];

  // ── Quick filter chip labels. ──
  static const List<String> _filters = [
    'All', 'Same City', 'Recently Joined', 'Verified Only', 'Online Now', '23–27 yrs',
  ];

  // ── "Who liked you" (blurred preview — premium upsell). ──
  final List<String> _likedYouAvatars = const [
    'https://randomuser.me/api/portraits/women/60.jpg',
    'https://randomuser.me/api/portraits/women/61.jpg',
    'https://randomuser.me/api/portraits/women/62.jpg',
    'https://randomuser.me/api/portraits/women/64.jpg',
  ];

  // ── Success stories. ──
  final List<SuccessStory> _stories = const [
    SuccessStory(couple: 'Ayesha & Ali', city: 'Lahore', imageUrl: 'https://images.unsplash.com/photo-1606800052052-a08af7148866?w=400'),
    SuccessStory(couple: 'Sana & Bilal', city: 'Karachi', imageUrl: 'https://images.unsplash.com/photo-1519741497674-611481863552?w=400'),
    SuccessStory(couple: 'Hira & Usman', city: 'Islamabad', imageUrl: 'https://images.unsplash.com/photo-1583939003579-730e3918a45a?w=400'),
  ];

  // ── Upcoming events / meetups. ──
  final List<EventItem> _events = const [
    EventItem(title: 'Singles Mixer', city: 'Lahore', date: 'Jul 15', emoji: '🎉'),
    EventItem(title: 'Coffee Meetup', city: 'Karachi', date: 'Jul 20', emoji: '☕'),
    EventItem(title: 'Family Intro Event', city: 'Islamabad', date: 'Aug 02', emoji: '💐'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header: app name + location + notifications ──
            SliverToBoxAdapter(child: _buildHeader(context)),

            // ── Search bar ──
            SliverToBoxAdapter(child: _buildSearchBar(context)),

            // (6) ── Quick filter chips ──
            SliverToBoxAdapter(child: _buildFilterChips(context)),

            // (7) ── Complete your profile banner ──
            SliverToBoxAdapter(child: _buildCompleteProfileBanner(context)),

            // (4) ── Activity / stats strip ──
            SliverToBoxAdapter(child: _buildStatsStrip(context)),

            // ── New matches (horizontal faces) ──
            SliverToBoxAdapter(child: _buildNewMatchesRow(context)),

            // (2) ── Match of the Day ──
            SliverToBoxAdapter(child: _buildSectionTitle(context, title: 'Match of the Day 💘')),
            SliverToBoxAdapter(child: _buildMatchOfTheDay(context)),

            // (3) ── Who liked you (blurred premium preview) ──
            SliverToBoxAdapter(child: _buildWhoLikedYou(context)),

            // ── Section title ──
            SliverToBoxAdapter(child: _buildSectionTitle(context)),

            // ── Profile grid ──
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildProfileCard(context, _profiles[index]),
                  childCount: _gridVisible.clamp(0, _profiles.length),
                ),
              ),
            ),

            // ── See more (for grid section) ──
            SliverToBoxAdapter(
              child: _buildSeeMoreButton(
                context,
                label: _gridVisible < _profiles.length
                    ? 'See More Profiles'
                    : 'That\'s all for now',
                enabled: _gridVisible < _profiles.length,
                onTap: _showMoreGrid,
              ),
            ),

            // ── Section title (recommended) ──
            SliverToBoxAdapter(
              child: _buildSectionTitle(context, title: 'Recommended for You ✨'),
            ),

            // ── Recommended (horizontal carousel) ──
            SliverToBoxAdapter(child: _buildRecommendedCarousel(context)),

            // ── See more (for recommended section) ──
            SliverToBoxAdapter(
              child: _buildSeeMoreButton(
                context,
                label: _recoVisible < _recommended.length
                    ? 'See More Recommendations'
                    : 'That\'s all for now',
                enabled: _recoVisible < _recommended.length,
                onTap: _showMoreReco,
              ),
            ),

            // (1) ── Profiles near you ──
            SliverToBoxAdapter(child: _buildSectionTitle(context, title: 'Profiles Near You 📍')),
            SliverToBoxAdapter(child: _buildNearYouCarousel(context)),

            // (8) ── Get verified promo ──
            SliverToBoxAdapter(child: _buildVerifiedPromo(context)),

            // (10) ── Daily tip / icebreaker ──
            SliverToBoxAdapter(child: _buildDailyTip(context)),

            // (5) ── Success stories ──
            SliverToBoxAdapter(child: _buildSectionTitle(context, title: 'Success Stories 💍')),
            SliverToBoxAdapter(child: _buildSuccessStories(context)),

            // (9) ── Upcoming events ──
            SliverToBoxAdapter(child: _buildSectionTitle(context, title: 'Events & Meetups 🎊')),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 90),
              sliver: SliverToBoxAdapter(child: _buildEventsList(context)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          // App name
          const Text(
            'WeGo',
            style: TextStyle(
              color: kMaroon,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 6),
          Icon(Icons.favorite, color: kRose, size: 18),
          const Spacer(),
          // Location pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kMaroon.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: kMaroon, size: 16),
                const SizedBox(width: 4),
                Text(
                  'Pakistan',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: kMaroon, size: 18),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Notifications
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kMaroon.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none, color: kMaroon, size: 22),
          ),
        ],
      ),
    );
  }

  // ── Search bar ───────────────────────────────────────────────
  Widget _buildSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark ? Colors.white10 : const Color(0xFFE0E0E0),
                  width: 1.4,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Icons.search, color: isDark ? Colors.white54 : const Color(0xFFAAAAAA), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Search by name or city',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : const Color(0xFFAAAAAA),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Filter button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kRose, kMaroon],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(26),
            ),
            child: const Icon(Icons.tune, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  // ── New matches horizontal row ───────────────────────────────
  Widget _buildNewMatchesRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final newOnes = _profiles.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'New Matches 💖',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: newOnes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final p = newOnes[i];
              return GestureDetector(
                onTap: () => _openProfile(context, p),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [kRose, kMaroon],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 30,
                            backgroundColor: Colors.white,
                            backgroundImage: NetworkImage(p.avatarUrl),
                          ),
                        ),
                        if (p.online)
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3DDC84),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      p.name,
                      style: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Section title ────────────────────────────────────────────
  Widget _buildSectionTitle(BuildContext context, {String title = 'Discover People'}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ── Recommended horizontal carousel ──────────────────────────
  Widget _buildRecommendedCarousel(BuildContext context) {
    final count = _recoVisible.clamp(0, _recommended.length);
    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          return SizedBox(
            width: 160,
            child: _buildProfileCard(context, _recommended[i]),
          );
        },
      ),
    );
  }

  // Reveal more grid profiles on "See More Profiles" tap.
  void _showMoreGrid() {
    setState(() {
      _gridVisible = (_gridVisible + _gridStep).clamp(0, _profiles.length);
    });
  }

  // Reveal more recommended profiles on "See More Recommendations" tap.
  void _showMoreReco() {
    setState(() {
      _recoVisible = (_recoVisible + _recoStep).clamp(0, _recommended.length);
    });
  }

  // ── See more / view all button ───────────────────────────────
  Widget _buildSeeMoreButton(
    BuildContext context, {
    required String label,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    final Color color = enabled ? kMaroon : Colors.grey;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: enabled ? onTap : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color, width: 1.4),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (enabled) ...[
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // (6) ── Quick filter chips ──────────────────────────────────
  Widget _buildFilterChips(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final selected = _selectedFilter == i;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = i),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                gradient: selected
                    ? const LinearGradient(colors: [kRose, kMaroon])
                    : null,
                color: selected
                    ? null
                    : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF2F2F2)),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? Colors.transparent : (isDark ? Colors.white12 : const Color(0xFFE0E0E0)),
                ),
              ),
              child: Text(
                _filters[i],
                style: TextStyle(
                  color: selected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // (7) ── Complete your profile banner ────────────────────────
  Widget _buildCompleteProfileBanner(BuildContext context) {
    const double progress = 0.6;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kMaroon.withValues(alpha: 0.10), kRose.withValues(alpha: 0.10)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kRose.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const SizedBox(
                    width: 46,
                    height: 46,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      backgroundColor: Color(0x33C2415E),
                      valueColor: AlwaysStoppedAnimation(kMaroon),
                    ),
                  ),
                  const Text('60%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kMaroon)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Complete your profile', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Add photos to get 3x more matches', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kMaroon),
          ],
        ),
      ),
    );
  }

  // (4) ── Activity / stats strip ──────────────────────────────
  Widget _buildStatsStrip(BuildContext context) {
    final stats = [
      {'icon': Icons.visibility, 'value': '124', 'label': 'Views'},
      {'icon': Icons.favorite, 'value': '38', 'label': 'Likes'},
      {'icon': Icons.people, 'value': '12', 'label': 'Matches'},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: stats.map((s) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: kMaroon.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Icon(s['icon'] as IconData, color: kMaroon, size: 22),
                  const SizedBox(height: 4),
                  Text(s['value'] as String, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kMaroon)),
                  Text(s['label'] as String, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // (2) ── Match of the Day ────────────────────────────────────
  Widget _buildMatchOfTheDay(BuildContext context) {
    final p = _profiles.isNotEmpty ? _profiles[2] : null;
    if (p == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: GestureDetector(
        onTap: () => _openProfile(context, p),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 200,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(p.avatarUrl, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(color: const Color(0xFFEFEFEF), child: const Icon(Icons.person, size: 60, color: Colors.grey)),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC4A0E1E)],
                      stops: [0.45, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kRose, kMaroon]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('💘 Today\'s Pick', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${p.name}, ${p.age}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.white70, size: 14),
                                const SizedBox(width: 2),
                                Text(p.city, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.favorite, color: kRose, size: 24),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // (3) ── Who liked you (blurred preview, premium upsell) ──────
  Widget _buildWhoLikedYou(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kRose.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 48,
              child: Stack(
                children: List.generate(_likedYouAvatars.length, (i) {
                  return Positioned(
                    left: i * 22.0,
                    child: ClipOval(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: Image.network(
                          _likedYouAvatars[i],
                          width: 44, height: 44, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(width: 44, height: 44, color: kRose),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('8 people liked you 💗', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('Upgrade to see who they are', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kRose, kMaroon]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Upgrade', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // (1) ── Profiles near you carousel ──────────────────────────
  Widget _buildNearYouCarousel(BuildContext context) {
    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        itemCount: _nearYou.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          return SizedBox(
            width: 160,
            child: _buildProfileCard(context, _nearYou[i]),
          );
        },
      ),
    );
  }

  // (8) ── Get verified promo ──────────────────────────────────
  Widget _buildVerifiedPromo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF42A5F5)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified, color: Colors.white, size: 34),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Get Verified ✓', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  SizedBox(height: 2),
                  Text('Verified profiles get 5x more trust', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: const Text('Verify', style: TextStyle(color: Color(0xFF1565C0), fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // (10) ── Daily tip / icebreaker ─────────────────────────────
  Widget _buildDailyTip(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3CD).withValues(alpha: isDark ? 0.12 : 1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE08A)),
        ),
        child: Row(
          children: [
            const Text('💡', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tip: Profiles with a complete bio get 2x more replies. Add yours today!',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : const Color(0xFF7A5C00), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // (5) ── Success stories carousel ────────────────────────────
  Widget _buildSuccessStories(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        itemCount: _stories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final s = _stories[i];
          return ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox(
              width: 230,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(s.imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(color: kRose.withValues(alpha: 0.3), child: const Icon(Icons.favorite, color: kMaroon, size: 50)),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xDD4A0E1E)],
                        stops: [0.4, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('💍 Married on WeGo', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(s.couple, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        Text(s.city, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // (9) ── Upcoming events list ────────────────────────────────
  Widget _buildEventsList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: _events.map((e) {
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFEAEAEA)),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kMaroon.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(e.emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 13, color: Colors.grey),
                        Text(' ${e.city}  •  ${e.date}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  border: Border.all(color: kMaroon, width: 1.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Join', style: TextStyle(color: kMaroon, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Profile card ─────────────────────────────────────────────
  Widget _buildProfileCard(BuildContext context, MatchProfile p) {
    final isLiked = _liked.contains(p.name);

    return GestureDetector(
      onTap: () => _openProfile(context, p),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo
            Image.network(
              p.avatarUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: const Color(0xFFEFEFEF),
                  child: const Center(
                    child: CircularProgressIndicator(color: kMaroon, strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (_, _, _) => Container(
                color: const Color(0xFFEFEFEF),
                child: const Icon(Icons.person, size: 60, color: Colors.grey),
              ),
            ),

            // Gradient overlay for text readability
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.transparent, Color(0xCC4A0E1E)],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
            ),

            // Online badge
            if (p.online)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      CircleAvatar(radius: 4, backgroundColor: Color(0xFF3DDC84)),
                      SizedBox(width: 4),
                      Text('Online', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),

            // Like heart (top right)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    if (isLiked) {
                      _liked.remove(p.name);
                    } else {
                      _liked.add(p.name);
                    }
                  });
                },
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? kRose : Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),

            // Name + age + city (bottom)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.name}, ${p.age}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.white70, size: 13),
                      const SizedBox(width: 2),
                      Text(
                        p.city,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openProfile(BuildContext context, MatchProfile p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          username: p.name,
          avatarUrl: p.avatarUrl,
        ),
      ),
    );
  }
}

class _AddStoryButton extends StatelessWidget {
  const _AddStoryButton();

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {},
    child: Container(
      width: 62,
      height: 62,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFB21A1A), width: 1.8),
      ),
      child: const Icon(Icons.add, color: Color(0xFFB21A1A), size: 28),
    ),
  );
}

class _StoryFaceCircle extends StatelessWidget {
  final String imageUrl;
  final bool isWatched;
  const _StoryFaceCircle({required this.imageUrl, this.isWatched = false});

  @override
  Widget build(BuildContext context) => Container(
    width: 62,
    height: 62,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: isWatched ? Colors.grey.shade400 : const Color(0xFFFF7B51),
        width: 2.5,
      ),
    ),
    child: ClipOval(
      child: Image.network(
        imageUrl,
        fit: BoxFit.cover,
        headers: const {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFF7A1730),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white38,
                ),
              ),
            ),
          );
        },
        errorBuilder: (_, _, _) => Container(
          color: const Color(0xFFC2415E),
          child: const Icon(Icons.person, color: Colors.white, size: 32),
        ),
      ),
    ),
  );
}

// Instagram Style Post Card with Video Support
class _InstagramStylePostCard extends StatefulWidget {
  final Post post;

  const _InstagramStylePostCard({required this.post});

  @override
  State<_InstagramStylePostCard> createState() => _InstagramStylePostCardState();
}

class _InstagramStylePostCardState extends State<_InstagramStylePostCard> {
  bool _isLiked = false;
  bool _isFollowing = false;
  bool _isSaved = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  final LocalStorageService _storage = LocalStorageService();

  @override
  void initState() {
    super.initState();
    _loadPersistedState();
    if (widget.post.isVideo) {
      _initializeVideo();
    }
  }

  void _loadPersistedState() {
    // Load like status from local storage
    _isLiked = _storage.isPostLiked(widget.post.id);
    // Load saved status from local storage
    _isSaved = _storage.isPostSaved(widget.post.id);
    // Load follow status from local storage (using username as userId)
    _isFollowing = _storage.isUserFollowed(widget.post.username);
    setState(() {});
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _initializeVideo() {
    // For demo purposes, using a sample video URL
    // In production, this would be the actual video URL from the post
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse('https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'),
    )..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
          _videoController?.setLooping(true);
          _videoController?.play();
        }
      });
  }

  void _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
    });
    // Save to local storage
    await _storage.toggleLike(widget.post.id, _isLiked);
  }

  void _toggleSave() async {
    setState(() {
      _isSaved = !_isSaved;
    });
    // Save to local storage
    await _storage.toggleSaved(widget.post.id, _isSaved);
  }

  void _toggleFollow() async {
    setState(() {
      _isFollowing = !_isFollowing;
    });
    // Save to local storage
    await _storage.toggleFollow(widget.post.username, _isFollowing);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFollowing ? 'Following ${widget.post.username}' : 'Unfollowed ${widget.post.username}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          username: widget.post.username,
          avatarUrl: widget.post.avatarUrl,
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _buildOptionTile(
              icon: Icons.save_alt,
              label: 'Save',
              onTap: () {
                Navigator.pop(context);
                _toggleSave();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_isSaved ? 'Saved to collection' : 'Removed from saved')),
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.copy,
              label: 'Copy Link',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.share,
              label: 'Share to...',
              onTap: () {
                Navigator.pop(context);
                Share.share('Check out this amazing post!');
              },
            ),
            _buildOptionTile(
              icon: Icons.notifications_off,
              label: "Turn off notifications for ${widget.post.username}",
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Notifications turned off for ${widget.post.username}')),
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.hide_image,
              label: 'Hide',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Post hidden')),
                );
              },
            ),
            _buildOptionTile(
              icon: Icons.flag,
              label: 'Report',
              iconColor: Colors.red,
              textColor: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(context);
              },
            ),
            _buildOptionTile(
              icon: Icons.cancel,
              label: 'Cancel',
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        title: const Text('Report Post'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildReportOption('Nudity or sexual activity'),
            _buildReportOption('Harassment or bullying'),
            _buildReportOption('Hate speech or symbols'),
            _buildReportOption('False information'),
            _buildReportOption('Spam'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildReportOption(String reason) {
    return ListTile(
      title: Text(reason),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reported for: $reason')),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, color: iconColor ?? (isDark ? Colors.white : Colors.black87)),
      title: Text(
        label,
        style: TextStyle(color: textColor ?? (isDark ? Colors.white : Colors.black87)),
      ),
      onTap: onTap,
    );
  }

  List<TextSpan> _buildCaptionWithHashtags(String caption) {
    final List<TextSpan> spans = [];
    final words = caption.split(' ');

    for (String word in words) {
      if (word.startsWith('#')) {
        spans.add(TextSpan(
          text: '$word ',
          style: const TextStyle(
            color: Color(0xFF7A1730),
            fontSize: 14,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: '$word ',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 14,
          ),
        ));
      }
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF121212) : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Avatar, Username, Follow Button, and More Options
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Avatar
                GestureDetector(
                  onTap: _navigateToProfile,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFDD2A7B),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: Image.network(
                        widget.post.avatarUrl,
                        fit: BoxFit.cover,
                        headers: const {
                          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                        },
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.person),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Username and Follow Button
                Expanded(
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _navigateToProfile,
                        child: Text(
                          widget.post.username,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Follow Button
                      if (!_isFollowing)
                        GestureDetector(
                          onTap: _toggleFollow,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0095F6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Follow',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _toggleFollow,
                          child: Row(
                            children: [
                              const Icon(Icons.check, size: 16, color: Colors.grey),
                              const SizedBox(width: 4),
                              Text(
                                'Following',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),

                // 3 Dots Menu
                IconButton(
                  icon: Icon(
                    Icons.more_vert,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: () => _showMoreOptions(context),
                ),
              ],
            ),
          ),

          // Post Image/Video
          GestureDetector(
            onDoubleTap: _toggleLike,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 400),
              child: widget.post.isVideo && _isVideoInitialized
                  ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!),
                    )
                  : Image.network(
                      widget.post.postImageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          height: 400,
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 400,
                        color: Colors.grey[300],
                        child: const Icon(Icons.error),
                      ),
                    ),
            ),
          ),

          // Action Buttons Row (Like, Comment, Share, Save)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                // Like Button
                GestureDetector(
                  onTap: _toggleLike,
                  child: AnimatedScale(
                    scale: _isLiked ? 1.2 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _isLiked ? Icons.favorite : Icons.favorite_border,
                      color: _isLiked ? Colors.red : (isDark ? Colors.white : Colors.black),
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Comment Button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CommentsScreen(
                          postId: widget.post.id,
                          postUsername: widget.post.username,
                          currentUserAvatar: 'https://i.pravatar.cc/150?img=10',
                          currentUsername: 'You',
                        ),
                      ),
                    );
                  },
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: isDark ? Colors.white : Colors.black,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),

                // Share Button
                GestureDetector(
                  onTap: () {
                    Share.share('Check out this amazing post by ${widget.post.username}!');
                  },
                  child: Icon(
                    Icons.send,
                    color: isDark ? Colors.white : Colors.black,
                    size: 26,
                  ),
                ),

                const Spacer(),

                // Save Button
                GestureDetector(
                  onTap: _toggleSave,
                  child: Icon(
                    _isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isDark ? Colors.white : Colors.black,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),

          // Likes Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${widget.post.likes} likes',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Caption with Hashtags
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${widget.post.username} ',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  ..._buildCaptionWithHashtags(widget.post.caption),
                ],
              ),
            ),
          ),

          const SizedBox(height: 6),

          // View Comments
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () {
                // Navigate to comments
              },
              child: Text(
                'View all ${widget.post.comments} comments',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Time
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.post.time.toUpperCase(),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 10,
              ),
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class Post {
  final String id;
  final String avatarUrl;
  final String username;
  final String time;
  final String postImageUrl;
  final String likes;
  final String comments;
  final bool isVideo;
  final String caption;
  final List<String> hashtags;
  final bool isLarge;

  Post({
    required this.id,
    required this.avatarUrl,
    required this.username,
    required this.time,
    required this.postImageUrl,
    required this.likes,
    required this.comments,
    this.isVideo = false,
    this.caption = '',
    this.hashtags = const [],
    required this.isLarge,
  });
}
