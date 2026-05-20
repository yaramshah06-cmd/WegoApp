import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:badges/badges.dart' as badges;
import 'package:wego_marriage/providers/story_provider.dart';
import 'package:wego_marriage/providers/chat_provider.dart';
import 'package:wego_marriage/providers/user_provider.dart';
import 'package:wego_marriage/screen/story_screen.dart';
import 'package:wego_marriage/screen/my_profile.dart';
import 'package:wego_marriage/screen/notifications_screen.dart';
import 'package:wego_marriage/services/notification_service.dart';
import 'package:wego_marriage/screen/massage_list_screen.dart';
import 'package:wego_marriage/screen/comments_screen.dart';
import 'package:wego_marriage/screen/chat_screen.dart';
import 'package:wego_marriage/screen/user_profile_screen.dart';
import 'package:wego_marriage/screen/create_content_screen.dart';
import 'package:wego_marriage/screen/connection_secreen.dart';
import 'package:wego_marriage/screen/search_screen.dart';
import 'package:wego_marriage/screen/report_post_screen.dart';
import 'package:wego_marriage/screen/xp_service.dart';
import 'package:wego_marriage/services/local_storage_service.dart';
import 'package:wego_marriage/services/message_badge_service.dart';
import 'package:wego_marriage/services/legendary_announcement_service.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_localizations.dart';
import 'app_translations.dart';

class HomeFeedScreen extends StatefulWidget {
  const HomeFeedScreen({super.key});

  @override
  State<HomeFeedScreen> createState() => _HomeFeedScreenState();
}

class _HomeFeedScreenState extends State<HomeFeedScreen> {
  int _selectedIndex = 0;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        context.read<UserProvider>().loadUserFromFirebase();
        context.read<ChatProvider>().loadChats();
      }
    });
  }

  final List<Widget> _tabs = [
    const _HomeTab(),
    MatchesScreen(),
    const SizedBox.shrink(),
    const MessageListScreen(),
    const MyProfileScreen(),
  ];

  Future<bool> _onWillPop() async {
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('press_back_exit')),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return false;
    }
    SystemNavigator.pop();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: IndexedStack(
          index: _selectedIndex,
          children: _tabs,
        ),
        bottomNavigationBar: _buildBottomNav(context),
        floatingActionButton: _buildFab(context),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CreateContentScreen(
              initialMode: ContentMode.post,
            ),
          ),
        );
      },
      child: Container(
        width: 56,
        height: 56,
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
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF4A6CF7);

    final List<Map<String, dynamic>> items = [
      {'icon': Icons.home_rounded,        'label': context.tr('nav_home')},
      {'icon': Icons.bookmark_border,     'label': context.tr('nav_favorite')},
      {'icon': null,                      'label': ''},
      {'icon': Icons.chat_bubble_outline, 'label': context.tr('nav_chats')},
      {'icon': Icons.person_outline,      'label': context.tr('nav_profile')},
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
      child: ValueListenableBuilder<int>(
        valueListenable: MessageBadgeService.unreadCount,
        builder: (context, unreadCount, child) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              if (i == 2) return const SizedBox(width: 60);
              final bool selected = _selectedIndex == i;
              final color = selected
                  ? primaryColor
                  : (isDark ? Colors.white54 : Colors.black38);

              Widget iconWidget;
              if (i == 3) {
                iconWidget = badges.Badge(
                  showBadge: unreadCount > 0,
                  badgeContent: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  badgeStyle: const badges.BadgeStyle(
                    badgeColor: Colors.red,
                    padding: EdgeInsets.all(4),
                  ),
                  position: badges.BadgePosition.topEnd(top: -6, end: -6),
                  child: Icon(
                    items[i]['icon'] as IconData,
                    color: color,
                    size: 24,
                  ),
                );
              } else {
                iconWidget = Icon(
                  items[i]['icon'] as IconData,
                  color: color,
                  size: 24,
                );
              }

              return GestureDetector(
                onTap: () {
                  if (i == 3) {
                    context.read<ChatProvider>().loadChats();
                  }
                  setState(() => _selectedIndex = i);
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    iconWidget,
                    const SizedBox(height: 3),
                    Text(
                      items[i]['label'] as String,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// LEGENDARY STRIP WIDGET
// ─────────────────────────────────────────────────────────────
class _LegendaryAnnouncementStrip extends StatefulWidget {
  final String displayName;
  const _LegendaryAnnouncementStrip({required this.displayName});

  @override
  State<_LegendaryAnnouncementStrip> createState() =>
      _LegendaryAnnouncementStripState();
}

class _LegendaryAnnouncementStripState
    extends State<_LegendaryAnnouncementStrip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  bool _visible = false;

  @override
  void initState() {
    super.initState();

    // Slide animation: starts off-screen right, moves to left
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 6500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.5, 0),
      end: const Offset(-1.5, 0),
    ).animate(CurvedAnimation(
      parent: _controller,
      // Ease in at start, linear in middle, ease out at end
      curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
    ));

    // Small delay then play once
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() => _visible = true);
        _controller.forward().then((_) {
          if (mounted) setState(() => _visible = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        height: 26,
        decoration: BoxDecoration(
          // Very subtle — barely visible, non-intrusive
          color: Colors.black.withValues(alpha: 0.35),
          border: Border(
            top: BorderSide(
              color: const Color(0xFFC8A84B).withValues(alpha: 0.18),
              width: 0.5,
            ),
            bottom: BorderSide(
              color: const Color(0xFFC8A84B).withValues(alpha: 0.18),
              width: 0.5,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          '👑 ${widget.displayName} is Alive',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: Color(0x8DE6C364), // soft gold, 55% opacity
            letterSpacing: 0.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  const _HomeTab();
  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final ScrollController _scrollController = ScrollController();
  final List<Post> _posts = [];
  final List<Post> _olderPosts = [];
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  StreamSubscription<QuerySnapshot>? _liveSub;
  String? _currentUid;

  // Legendary announcement
  String? _legendaryDisplayName;
  bool _announcementChecked = false;

  final _firestore = FirebaseFirestore.instance;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _initLiveFeed();
    _scrollController.addListener(_onScroll);
    _checkLegendaryAnnouncement();
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initLiveFeed() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    _currentUid = currentUser.uid;
    _attachLiveListener();
  }

  void _attachLiveListener() {
    _liveSub?.cancel();
    _liveSub = _firestore
        .collection('posts')
        .orderBy('timestamp', descending: true)
        .limit(_pageSize)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        _lastDocument = snapshot.docs.last;
      }
      final filtered = _applyVisibilityFilter(snapshot.docs);
      final livePosts = filtered.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Post.fromFirestore(doc.id, data);
      }).toList();

      if (!mounted) return;
      setState(() {
        _posts
          ..clear()
          ..addAll(livePosts)
          ..addAll(_olderPosts);
      });
    }, onError: (e) {
      debugPrint('Live feed error: $e');
    });
  }

  List<QueryDocumentSnapshot> _applyVisibilityFilter(
      List<QueryDocumentSnapshot> docs) {
    final uid = _currentUid;
    if (uid == null) return docs;
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final visibility = (data['visibility'] as String?) ?? 'everyone';
      final authorId = (data['authorid'] as String?) ?? '';
      final allowedUids =
          List<String>.from(data['allowedUids'] ?? const []);

      // only_me: home feed mein bilkul nahi dikhana — sirf "My Profile"
      // par dikhega (woh apni alag query use karta hai).
      if (visibility == 'only_me') return false;
      // close_friends: allowedUids me hona chahiye, ya author khud
      if (visibility == 'close_friends') {
        return allowedUids.contains(uid) || authorId == uid;
      }
      // everyone
      return true;
    }).toList();
  }

  // ── Check Firebase if legendary badge & cooldown passed ──
  Future<void> _checkLegendaryAnnouncement() async {
    final name = await LegendaryAnnouncementService.checkAndGetLegendaryUser();
    if (mounted) {
      setState(() {
        _legendaryDisplayName = name;
        _announcementChecked = true;
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoading || !_hasMore || _lastDocument == null) return;
    setState(() => _isLoading = true);

    try {
      final snapshot = await _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      _lastDocument = snapshot.docs.last;

      final filteredDocs = _applyVisibilityFilter(snapshot.docs);
      final newPosts = filteredDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Post.fromFirestore(doc.id, data);
      }).toList();

      setState(() {
        _olderPosts.addAll(newPosts);
        _posts.addAll(newPosts);
        _isLoading = false;
        if (snapshot.docs.length < _pageSize) _hasMore = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('posts_load_error')}: $e')),
        );
      }
    }
  }

  Future<void> _onRefresh() async {
    _olderPosts.clear();
    _lastDocument = null;
    _hasMore = true;
    await _initLiveFeed();
    if (context.mounted) {
      await context.read<StoryProvider>().refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final storyProvider = context.watch<StoryProvider>();
    final userStories = storyProvider.userStories;
    final theme = Theme.of(context);

    return SafeArea(
      child: Stack(
        children: [
          // ── Main feed column ──
          Column(
            children: [
              Container(
                color: theme.scaffoldBackgroundColor,
                child: Column(
                  children: [
                    _buildNotificationsBellRow(context),
                    _buildStoryRow(context, userStories),
                    const SizedBox(height: 10),
                    _buildSearchBar(context),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: const Color(0xFF4A6CF7),
                  child: _posts.isEmpty && !_isLoading
                      ? _buildEmptyState()
                      : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount: _posts.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _posts.length) {
                        if (_isLoading) {
                          return const Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF4A6CF7),
                              ),
                            ),
                          );
                        }
                        return const SizedBox(height: 80);
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: InstagramStylePostCard(post: _posts[index]),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          // ── Legendary strip overlay — floats over feed ──
          // Positioned in the middle-ish of screen, non-intrusive
          if (_announcementChecked && _legendaryDisplayName != null)
            Positioned(
              top: 160, // thoda neeche — story row ke baad
              left: 0,
              right: 0,
              child: _LegendaryAnnouncementStrip(
                displayName: _legendaryDisplayName!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            context.tr('no_posts_found'),
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('create_first_post'),
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ─── Top row above story bar — right-aligned bell with unread badge ───
  Widget _buildNotificationsBellRow(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final stream = (uid == null)
        ? const Stream<QuerySnapshot<Map<String, dynamic>>>.empty()
        : _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .where('read', isEqualTo: false)
            .limit(99)
            .snapshots();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 0),
      child: Row(
        children: [
          const Spacer(),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return InkResponse(
                radius: 24,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.notifications_outlined, size: 26),
                    ),
                    if (count > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: Theme.of(context)
                                    .scaffoldBackgroundColor,
                                width: 1.5),
                          ),
                          constraints: const BoxConstraints(
                              minWidth: 16, minHeight: 16),
                          child: Text(
                            count > 9 ? '9+' : '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStoryRow(BuildContext context, List<UserStory> userStories) {
    final me = FirebaseAuth.instance.currentUser;
    final myUid = me?.uid;
    final myPhoto = me?.photoURL ?? '';

    // Self ki story alag karo, baqi users alag
    final int selfIdx = userStories.indexWhere((u) => u.userId == myUid);
    final UserStory? myStory = selfIdx >= 0 ? userStories[selfIdx] : null;
    final List<UserStory> others = [
      for (int i = 0; i < userStories.length; i++)
        if (i != selfIdx) userStories[i],
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 68,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          // Pehla item hamesha self (story+plus ya sirf plus); baqi sab others
          itemCount: others.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            if (i == 0) {
              return _MyStoryItem(
                myStory: myStory,
                fallbackAvatar: myPhoto,
                onTapStory: () {
                  // Apni story dekhne — provider me wo first index par hi hoti hai
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StoryScreen(
                        initialUserIndex: selfIdx >= 0 ? selfIdx : 0,
                      ),
                    ),
                  );
                },
                onTapPlus: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateContentScreen(
                        initialMode: ContentMode.story,
                      ),
                    ),
                  );
                },
              );
            }
            final userStory = others[i - 1];
            // StoryScreen ka initialUserIndex original list me find karo
            final originalIndex =
                userStories.indexWhere((u) => u.userId == userStory.userId);
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryScreen(
                      initialUserIndex:
                          originalIndex >= 0 ? originalIndex : 0,
                    ),
                  ),
                );
              },
              child: _StoryFaceCircle(
                imageUrl: userStory.avatarUrl,
                isWatched: userStory.isWatched,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const SearchScreen(),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 200),
            ),
          );
        },
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? Colors.white10 : const Color(0xFFE0E0E0),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Icon(
                Icons.search,
                color: isDark ? Colors.white54 : const Color(0xFFAAAAAA),
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                context.tr('search_hint'),
                style: TextStyle(
                  color: isDark ? Colors.white54 : const Color(0xFFAAAAAA),
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Insta-style "Your story" item — avatar circle + chhota plus badge
class _MyStoryItem extends StatelessWidget {
  final UserStory? myStory;
  final String fallbackAvatar;
  final VoidCallback onTapStory;
  final VoidCallback onTapPlus;

  const _MyStoryItem({
    required this.myStory,
    required this.fallbackAvatar,
    required this.onTapStory,
    required this.onTapPlus,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasStory = myStory != null;
    final String avatarUrl = myStory?.avatarUrl.isNotEmpty == true
        ? myStory!.avatarUrl
        : fallbackAvatar;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor =
        isDark ? Colors.black : Theme.of(context).scaffoldBackgroundColor;

    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatar / ring circle (whole circle tap = story dekhne)
          GestureDetector(
            onTap: hasStory ? onTapStory : onTapPlus,
            child: hasStory
                ? _StoryFaceCircle(
                    imageUrl: avatarUrl,
                    isWatched: myStory!.isWatched,
                  )
                : Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                      border: Border.all(
                        color: isDark ? Colors.white24 : Colors.black12,
                        width: 1.5,
                      ),
                      image: avatarUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(avatarUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: avatarUrl.isEmpty
                        ? Icon(
                            Icons.person,
                            color: isDark ? Colors.white54 : Colors.black38,
                            size: 28,
                          )
                        : null,
                  ),
          ),
          // Chhota plus badge bottom-right par
          Positioned(
            right: -2,
            bottom: -2,
            child: GestureDetector(
              onTap: onTapPlus,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFB21A1A),
                  border: Border.all(color: bgColor, width: 2),
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
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
          'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            color: const Color(0xFF7B4EDB),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white38),
              ),
            ),
          );
        },
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFF9B6EDB),
          child: const Icon(Icons.person, color: Colors.white, size: 32),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
class InstagramStylePostCard extends StatefulWidget {
  final Post post;
  const InstagramStylePostCard({required this.post});

  @override
  State<InstagramStylePostCard> createState() =>
      InstagramStylePostCardState();
}

class InstagramStylePostCardState extends State<InstagramStylePostCard> {
  bool _isLiked = false;
  bool _isFollowing = false;
  bool _isSaved = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  final LocalStorageService _storage = LocalStorageService();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _loadPersistedState();
    if (widget.post.isVideo) _initializeVideo();
  }

  void _loadPersistedState() async {
    // Optimistic: local cache se turant set karo (offline-safe)
    _isLiked = _storage.isPostLiked(widget.post.id);
    _isSaved = _storage.isPostSaved(widget.post.id);
    _isFollowing = _storage.isUserFollowed(widget.post.userId);
    if (mounted) setState(() {});

    // Authoritative: Firestore se confirm karo — logout/re-login ke baad
    // bhi like-state preserve rahega kyunki source of truth `likedBy` hai.
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap =
          await _firestore.collection('posts').doc(widget.post.id).get();
      if (!snap.exists || !mounted) return;
      final data = snap.data() ?? {};
      final likedBy = List<String>.from(data['likedBy'] ?? const []);
      final firestoreLiked = likedBy.contains(uid);

      // Firestore say agar like hai par local mein nahi — restore karo
      if (firestoreLiked != _isLiked) {
        setState(() => _isLiked = firestoreLiked);
        await _storage.toggleLike(widget.post.id, firestoreLiked);
      }
    } catch (_) {
      // network nahi — local cache kaafi hai
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _initializeVideo() {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.post.videoUrl ?? ''),
    )..initialize().then((_) {
      if (mounted) {
        setState(() => _isVideoInitialized = true);
        _videoController?.setLooping(true);
        _videoController?.play();
      }
    });
  }

  void _toggleLike() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    final newVal = !_isLiked;
    setState(() => _isLiked = newVal);
    await _storage.toggleLike(widget.post.id, newVal);

    final postRef = _firestore.collection('posts').doc(widget.post.id);
    if (newVal) {
      await postRef.update({
        'likesCount': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([currentUserId]),
      });
      await XPService.addXP(currentUserId, XPAction.likeKarna);
      // Notify post author (fire-and-forget; self-action skip inside service)
      unawaited(NotificationService.notifyLike(
        postOwnerUid: widget.post.userId,
        postId: widget.post.id,
        postThumbUrl: widget.post.postImageUrl,
      ));
    } else {
      await postRef.update({
        'likesCount': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([currentUserId]),
      });
    }
  }

  void _toggleSave() async {
    setState(() => _isSaved = !_isSaved);
    await _storage.toggleSaved(widget.post.id, _isSaved);
  }

  // ─── Repost toggle — posts/{id}.repostedBy array maintain karte hain ───
  //  Repost author ko notification jata hai (sirf add ke time).
  Future<void> _toggleRepost(bool currentlyReposted) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _firestore.collection('posts').doc(widget.post.id);
    if (currentlyReposted) {
      await ref.update({
        'repostsCount': FieldValue.increment(-1),
        'repostedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      await ref.update({
        'repostsCount': FieldValue.increment(1),
        'repostedBy': FieldValue.arrayUnion([uid]),
      });
      unawaited(NotificationService.notifyRepost(
        postOwnerUid: widget.post.userId,
        postId: widget.post.id,
        postThumbUrl: widget.post.postImageUrl,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reposted'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  void _toggleFollow() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    final targetUid = widget.post.userId;

    setState(() => _isFollowing = !_isFollowing);
    await _storage.toggleFollow(targetUid, _isFollowing);

    if (_isFollowing) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(targetUid)
          .set({'followedAt': FieldValue.serverTimestamp()});
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('followers')
          .doc(currentUid)
          .set({'followedAt': FieldValue.serverTimestamp()});
      unawaited(NotificationService.notifyFollow(targetUid: targetUid));
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(targetUid)
          .delete();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('followers')
          .doc(currentUid)
          .delete();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          _isFollowing
              ? '${context.tr('following')} ${widget.post.username}'
              : '${context.tr('unfollowed')} ${widget.post.username}',
        ),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _navigateToProfile() {
    final currentUid = _auth.currentUser?.uid;
    // Apni hi post ka avatar/username tap kiya → MyProfile khole, na ki
    // "stranger user" wala screen (jahan follow/message buttons dikhte hain).
    if (currentUid != null && currentUid == widget.post.userId) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const MyProfileScreen()),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: widget.post.userId,
          username: widget.post.username,
          avatarUrl: widget.post.avatarUrl,
        ),
      ),
    );
  }

  // ─── Share bottom sheet — followers + messaged users + external apps ───
  Future<List<_ShareTarget>> _loadShareTargets() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final Map<String, _ShareTarget> byUid = {};

    // 1. Followed users (Firestore subcollection)
    try {
      final followingSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();

      for (final doc in followingSnap.docs) {
        final fUid = doc.id;
        if (fUid == uid) continue;
        final userDoc =
            await _firestore.collection('users').doc(fUid).get();
        final data = userDoc.data() ?? {};
        byUid[fUid] = _ShareTarget(
          userId: fUid,
          username: (data['username'] ??
                  data['fullName'] ??
                  data['name'] ??
                  'User')
              .toString(),
          avatarUrl: (data['photoUrl'] ?? '').toString(),
          source: 'following',
        );
      }
    } catch (e) {
      debugPrint('share: following load error $e');
    }

    // 2. Messaged users — fallback for anyone we chat with but don't follow
    try {
      final chatProvider = context.read<ChatProvider>();
      for (final c in chatProvider.chats) {
        if (c.userId.isEmpty || c.userId == uid) continue;
        byUid.putIfAbsent(
          c.userId,
          () => _ShareTarget(
            userId: c.userId,
            username: c.name,
            avatarUrl: c.imageUrl,
            source: 'message',
          ),
        );
      }
    } catch (_) {}

    return byUid.values.toList();
  }

  String _buildPostLink() =>
      'https://wegomarriage.app/post/${widget.post.id}';

  Future<void> _incrementShareCount() async {
    try {
      await _firestore
          .collection('posts')
          .doc(widget.post.id)
          .update({'shareCount': FieldValue.increment(1)});
    } catch (_) {}
  }

  // ⚠️ NOTE: `caption` parameter is required — caller MUST pre-build it using
  // context.tr() BEFORE popping the bottom sheet. We cannot call context.tr()
  // inside this async method because Provider lookups fail after the sheet's
  // context leaves the widget tree.
  Future<void> _sendPostInChat(
      _ShareTarget target, String caption) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not signed in')),
        );
      }
      return;
    }
    if (target.userId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid recipient')),
        );
      }
      return;
    }

    // ✅ Chat room ID — same formula jo FirebaseChatService use karta hai
    final svc = FirebaseChatService();
    final chatRoomId = svc.getChatRoomId(uid, target.userId);
    debugPrint('Sharing post ${widget.post.id} to chat $chatRoomId');

    final now = DateTime.now();
    final h = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final timeString =
        '$h:${now.minute.toString().padLeft(2, '0')} $amPm';

    final isVideo = widget.post.isVideo;
    // Thumbnail — feed already postImageUrl ko thumb ke roop mein dikhata hai
    // (video posts mein bhi yeh server-side generated thumbnail hota hai).
    final thumbUrl = widget.post.postImageUrl;
    // `caption` param ab in-app share mein use nahi hota (external share ke
    // liye banaya gaya tha). Reference rakhte hain warna `unused_parameter`.
    debugPrint('Internal share: card bhej rahe hain (auto-caption skipped, '
        'len=${caption.length}).');

    // ✅ Instagram-style shared post card: poora media NAHI bhejte — sirf
    // post reference (id + author + thumbnail). Receiver chat bubble par tap
    // karke PostViewerScreen mein full post dekh sakta hai.
    // NOTE: `text` ke andar user ka optional note ja sakta hai. Auto-generated
    // "Check out this post by ..." caption ko skip kar rahe hain taaki card
    // saaf rahe aur attribution sirf author row se aaye.
    final msgData = <String, dynamic>{
      'senderId': uid,
      'senderName': _auth.currentUser?.displayName ?? '',
      'receiverId': target.userId,
      // ✅ `caption` parameter is the auto-generated external-share text
      // ("Check out this post by @user <link>") — yeh chat card mein NA aaye.
      // Card khud hi attribution + thumbnail dikhata hai. Future mein agar
      // user-typed note input add ho to wahi yahan jana chahiye.
      'text': '',
      'type': MsgType.sharedPost.index,
      // imageUrl rakha hai backward-compat / quick preview ke liye
      'imageUrl': thumbUrl,
      'avatarUrl': _auth.currentUser?.photoURL ?? '',
      'status': MsgStatus.sent.index,
      'time': timeString,
      'dateTime': now.millisecondsSinceEpoch,
      'duration': null,
      'isViewOnce': false,
      'replyToText': null,
      'replyToType': null,
      'isDeleted': false,
      'isUnsent': false,
      'isStarred': false,
      'isPinned': false,
      'isEdited': false,
      'reactions': <String, dynamic>{},
      'isRead': false,
      // Shared post metadata — _SharedPostCardBubble in chat_screen.dart isi
      // se card render karta hai aur PostViewerScreen ko id pass karta hai.
      'sharedPostId': widget.post.id,
      'sharedPostAuthor': widget.post.username,
      'sharedPostAuthorAvatar': widget.post.avatarUrl,
      'sharedPostThumbUrl': thumbUrl,
      'sharedPostIsVideo': isVideo,
    };

    try {
      await svc.sendMessage(
        chatRoomId: chatRoomId,
        messageData: msgData,
      );
      await _incrementShareCount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sent to ${target.username}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    }
  }

  // ─── Thumbnail-only download (FB/WA share ke liye) ───
  // External share par sirf chhoti preview image + link jaata hai — pura
  // media (full video / hi-res image) kabhi attach nahi karte. Receiver ko
  // wego link click karke app/web par hi full post dikhega.
  Future<XFile?> _downloadThumbToTemp() async {
    // Image posts ke liye postImageUrl, video posts ke liye bhi postImageUrl
    // (Firestore generally video ka server-side thumbnail isi field mein save
    // karta hai — feed bhi yahi use karta hai preview ke liye).
    final url = widget.post.postImageUrl;
    if (url.isEmpty) return null;

    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;

      // 1MB se bada hua to bhi rakh lete hain — most CDN thumbs chhote hote
      // hain; skip karne se share-without-image situation banegi.
      final dir = await getTemporaryDirectory();
      final filename =
          'wego_thumb_${widget.post.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(resp.bodyBytes);

      return XFile(
        file.path,
        mimeType: 'image/jpeg',
        name: filename,
      );
    } catch (e) {
      debugPrint('thumb download failed: $e');
      return null;
    }
  }

  // ⚠️ `toastMsg` MUST be pre-built by caller (context.tr can't be called
  // from async event handlers — it does listen:true Provider.of which fails)
  Future<void> _copyPostLink({String toastMsg = 'Link copied'}) async {
    await Clipboard.setData(ClipboardData(text: _buildPostLink()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(toastMsg)),
    );
  }

  // ─── Loading dialog show karo media download ke dauran ───
  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4A6CF7)),
      ),
    );
  }

  void _hideLoading() {
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
  }

  // ⚠️ `caption` MUST be pre-built by caller (see _sendPostInChat note)
  Future<void> _shareToWhatsApp(String caption) async {
    _showLoading();
    final xfile = await _downloadThumbToTemp();
    _hideLoading();

    if (xfile == null) {
      // Media download fail — fallback text-only link
      final text = Uri.encodeComponent(caption);
      final uri = Uri.parse('whatsapp://send?text=$text');
      final fallback = Uri.parse('https://wa.me/?text=$text');
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          await launchUrl(fallback, mode: LaunchMode.externalApplication);
        }
        await _incrementShareCount();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WhatsApp not available')),
          );
        }
      }
      return;
    }

    // ✅ Actual photo/video file + caption — WhatsApp pick karta hai
    // sharePlus pe WhatsApp specifically target karne ka direct API nahi hai,
    // par xfile share karne par WhatsApp default media handler ke saath show hota hai
    try {
      await Share.shareXFiles(
        [xfile],
        text: caption,
        subject: 'Wego Post',
      );
      await _incrementShareCount();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  // ⚠️ `caption` MUST be pre-built by caller (see _sendPostInChat note)
  Future<void> _shareToFacebook(String caption) async {
    _showLoading();
    final xfile = await _downloadThumbToTemp();
    _hideLoading();

    if (xfile == null) {
      // Fallback: FB sharer URL (sirf link, media nahi)
      final link = Uri.encodeComponent(_buildPostLink());
      final uri = Uri.parse(
          'https://www.facebook.com/sharer/sharer.php?u=$link');
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await _incrementShareCount();
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Facebook open failed')),
          );
        }
      }
      return;
    }

    // ✅ Native share with media file — user FB pick karega aur woh photo/video
    // ke saath compose screen open karega (caption mein wego link)
    try {
      await Share.shareXFiles(
        [xfile],
        text: caption,
        subject: 'Wego Post',
      );
      await _incrementShareCount();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  // ⚠️ Caller (build method) MUST pre-build all strings via context.tr()
  // and pass them in. We can't call context.tr() inside event handlers
  // because it does listen:true Provider.of which only works in build().
  void _showShareSheet(
    BuildContext context, {
    required String sharedCaption,
    required String copyLinkLabel,
    required String linkCopiedMsg,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, scrollController) {
            return SafeArea(
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 10, bottom: 12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[600] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Send to',
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: FutureBuilder<List<_ShareTarget>>(
                      future: _loadShareTargets(),
                      builder: (context, snap) {
                        if (snap.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF4A6CF7)));
                        }
                        final targets = snap.data ?? [];
                        if (targets.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'No followed or messaged users yet',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: targets.length,
                          itemBuilder: (_, i) {
                            final t = targets[i];
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 22,
                                backgroundImage: t.avatarUrl.startsWith('http')
                                    ? NetworkImage(t.avatarUrl)
                                    : null,
                                child: t.avatarUrl.startsWith('http')
                                    ? null
                                    : const Icon(Icons.person, size: 20),
                              ),
                              title: Text(
                                t.username,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                t.source == 'following'
                                    ? 'Following'
                                    : 'From messages',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0095F6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 6),
                                  minimumSize: const Size(0, 32),
                                ),
                                onPressed: () async {
                                  Navigator.pop(sheetCtx);
                                  await _sendPostInChat(t, sharedCaption);
                                },
                                child: const Text(
                                  'Send',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _shareExternalIcon(
                          label: copyLinkLabel,
                          icon: Icons.link,
                          bgColor: Colors.grey,
                          onTap: () async {
                            Navigator.pop(sheetCtx);
                            await _copyPostLink(toastMsg: linkCopiedMsg);
                          },
                          textColor: textColor,
                        ),
                        _shareExternalIcon(
                          label: 'WhatsApp',
                          icon: Icons.chat,
                          bgColor: const Color(0xFF25D366),
                          onTap: () async {
                            Navigator.pop(sheetCtx);
                            await _shareToWhatsApp(sharedCaption);
                          },
                          textColor: textColor,
                        ),
                        _shareExternalIcon(
                          label: 'Facebook',
                          icon: Icons.facebook,
                          bgColor: const Color(0xFF1877F2),
                          onTap: () async {
                            Navigator.pop(sheetCtx);
                            await _shareToFacebook(sharedCaption);
                          },
                          textColor: textColor,
                        ),
                        _shareExternalIcon(
                          label: 'More',
                          icon: Icons.more_horiz,
                          bgColor: Colors.blueGrey,
                          onTap: () async {
                            Navigator.pop(sheetCtx);
                            _showLoading();
                            final xfile = await _downloadThumbToTemp();
                            _hideLoading();
                            if (xfile != null) {
                              await Share.shareXFiles([xfile],
                                  text: sharedCaption, subject: 'Wego Post');
                            } else {
                              await Share.share(sharedCaption);
                            }
                            await _incrementShareCount();
                          },
                          textColor: textColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _shareExternalIcon({
    required String label,
    required IconData icon,
    required Color bgColor,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = _auth.currentUser?.uid;
    final isOwner = currentUserId == widget.post.userId;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('posts')
                  .doc(widget.post.id)
                  .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.hasData && snapshot.data!.exists
                    ? snapshot.data!.data() as Map<String, dynamic>
                    : <String, dynamic>{};

                final hideLikes = data['hideLikeCount'] ?? false;
                final commentsDisabled = data['turnOffCommenting'] ?? false;
                final hideShareCount = data['hideShareCount'] ?? false;

                return SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(top: 8, bottom: 16),
                        decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey[600]
                                : Colors.grey[300],
                            borderRadius: BorderRadius.circular(2)),
                      ),

                      if (isOwner) ...[
                        ListTile(
                          leading: Icon(
                            hideLikes ? Icons.favorite : Icons.favorite_border,
                            color: hideLikes
                                ? Colors.red
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                          title: Text(
                            hideLikes
                                ? context.tr('show_like_count')
                                : context.tr('hide_like_count'),
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87),
                          ),
                          trailing: Switch(
                            value: hideLikes,
                            activeColor: const Color(0xFF0095F6),
                            onChanged: (_) async {
                              await _firestore
                                  .collection('posts')
                                  .doc(widget.post.id)
                                  .update({'hideLikeCount': !hideLikes});
                            },
                          ),
                        ),
                        ListTile(
                          leading: Icon(
                            commentsDisabled
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            color: commentsDisabled
                                ? Colors.orange
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                          title: Text(
                            commentsDisabled
                                ? context.tr('turn_on_comments')
                                : context.tr('turn_off_comments'),
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87),
                          ),
                          trailing: Switch(
                            value: commentsDisabled,
                            activeColor: Colors.orange,
                            onChanged: (_) async {
                              await _firestore
                                  .collection('posts')
                                  .doc(widget.post.id)
                                  .update(
                                  {'turnOffCommenting': !commentsDisabled});
                            },
                          ),
                        ),
                        ListTile(
                          leading: Icon(
                            hideShareCount
                                ? Icons.share
                                : Icons.share_outlined,
                            color: hideShareCount
                                ? Colors.blue
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                          title: Text(
                            hideShareCount
                                ? context.tr('show_share_count')
                                : context.tr('hide_share_count'),
                            style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87),
                          ),
                          trailing: Switch(
                            value: hideShareCount,
                            activeColor: Colors.blue,
                            onChanged: (_) async {
                              await _firestore
                                  .collection('posts')
                                  .doc(widget.post.id)
                                  .update(
                                  {'hideShareCount': !hideShareCount});
                            },
                          ),
                        ),
                        Divider(
                            color: isDark
                                ? Colors.grey[700]
                                : Colors.grey[300]),
                      ],

                      // Non-owners ko sirf Report ka option dikhana hai.
                      // Owner par apni hi post Report karna meaningful nahi —
                      // unke liye toggles aur Cancel kaafi hain.
                      if (!isOwner)
                        _buildOptionTile(
                          Icons.flag,
                          context.tr('report'),
                          () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReportPostScreen(
                                  postId: widget.post.id,
                                  postOwnerId: widget.post.userId,
                                  postOwnerUsername: widget.post.username,
                                  postImageUrl: widget.post.postImageUrl,
                                ),
                              ),
                            );
                          },
                          iconColor: Colors.red,
                          textColor: Colors.red,
                        ),
                      _buildOptionTile(Icons.cancel, context.tr('cancel'),
                          () => Navigator.pop(context)),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildOptionTile(IconData icon, String label, VoidCallback onTap,
      {Color? iconColor, Color? textColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon,
          color: iconColor ?? (isDark ? Colors.white : Colors.black87)),
      title: Text(label,
          style: TextStyle(
              color: textColor ?? (isDark ? Colors.white : Colors.black87))),
      onTap: onTap,
    );
  }

  List<TextSpan> _buildCaptionWithHashtags(String caption) {
    return caption.split(' ').map((word) {
      if (word.startsWith('#')) {
        return TextSpan(
            text: '$word ',
            style: const TextStyle(color: Color(0xFF003569), fontSize: 14));
      }
      return TextSpan(
          text: '$word ',
          style: const TextStyle(color: Colors.black, fontSize: 14));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('posts').doc(widget.post.id).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>
            : <String, dynamic>{};

        final hideLikes = data['hideLikeCount'] ?? widget.post.hideLikes;
        final commentsDisabled =
            data['turnOffCommenting'] ?? widget.post.commentsDisabled;
        final hideShareCount =
            data['hideShareCount'] ?? widget.post.hideShareCount;
        final likesCount = data['likesCount'] ?? widget.post.likesCount;
        final shareCount = data['shareCount'] ?? 0;

        // ✅ Live like-state — Firestore likedBy array se aata hai, source of truth.
        // Logout/login/dusra device — sab par same dikhega. Sirf user khud
        // _toggleLike kare to hi remove ho — warna permanent.
        final currentUid = _auth.currentUser?.uid;
        final likedBy = List<String>.from(data['likedBy'] ?? const []);
        final liveIsLiked = currentUid != null && likedBy.contains(currentUid);
        // Repost state — same array pattern jaisa likedBy.
        final repostedBy = List<String>.from(data['repostedBy'] ?? const []);
        final isReposted =
            currentUid != null && repostedBy.contains(currentUid);
        final repostsCount = (data['repostsCount'] ?? 0) as int;
        // Local state ko stream ke saath sync rakho (UI consistency).
        // ⚠️ Guard: agar snapshot empty/cache-only hai (offline ya pehli load
        // se pehle), to local cache ko overwrite mat karo — warna flicker se
        // user ko lagta hai "like khud sy hat gyi".
        final hasRealData = snapshot.hasData &&
            snapshot.data!.exists &&
            data.isNotEmpty;
        if (hasRealData && liveIsLiked != _isLiked) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && liveIsLiked != _isLiked) {
              setState(() => _isLiked = liveIsLiked);
              _storage.toggleLike(widget.post.id, liveIsLiked);
            }
          });
        }

        return Container(
          color: isDark ? const Color(0xFF121212) : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _navigateToProfile,
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFFDD2A7B), width: 2),
                        ),
                        child: ClipOval(
                          child: Image.network(widget.post.avatarUrl,
                              fit: BoxFit.cover,
                              headers: const {
                                'User-Agent':
                                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
                              },
                              errorBuilder: (_, __, ___) =>
                              const Icon(Icons.person)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _navigateToProfile,
                            child: Text(widget.post.username,
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black)),
                          ),
                          const SizedBox(width: 8),
                          if (!_isFollowing)
                            GestureDetector(
                              onTap: _toggleFollow,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                    color: const Color(0xFF0095F6),
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text(
                                  context.tr('follow'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: _toggleFollow,
                              child: Row(children: [
                                const Icon(Icons.check,
                                    size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  context.tr('following'),
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                              ]),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                        icon: Icon(Icons.more_vert,
                            color: isDark ? Colors.white : Colors.black),
                        onPressed: () => _showMoreOptions(context)),
                  ],
                ),
              ),

              GestureDetector(
                onDoubleTap: _toggleLike,
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: widget.post.isVideo && _isVideoInitialized
                      ? AspectRatio(
                      aspectRatio: _videoController!.value.aspectRatio,
                      child: VideoPlayer(_videoController!))
                      : Image.network(widget.post.postImageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                            height: 400,
                            color: Colors.grey[300],
                            child: const Center(
                                child: CircularProgressIndicator()));
                      },
                      errorBuilder: (_, __, ___) => Container(
                          height: 400,
                          color: Colors.grey[300],
                          child: const Icon(Icons.error))),
                ),
              ),

              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _toggleLike,
                      child: AnimatedScale(
                        scale: _isLiked ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          color: _isLiked
                              ? Colors.red
                              : (isDark ? Colors.white : Colors.black),
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: commentsDisabled
                          ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                context.tr('comments_turned_off_post')),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                          : () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => CommentsScreen(
                                    postId: widget.post.id,
                                    postUsername: widget.post.username,
                                    currentUserAvatar:
                                    _auth.currentUser?.photoURL ?? '',
                                    currentUsername:
                                    _auth.currentUser?.displayName ??
                                        context.tr('you'))));
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            commentsDisabled
                                ? Icons.chat_bubble
                                : Icons.chat_bubble_outline,
                            color: commentsDisabled
                                ? Colors.grey
                                : (isDark ? Colors.white : Colors.black),
                            size: 26,
                          ),
                          if (!commentsDisabled &&
                              (data['commentsCount'] ??
                                      widget.post.commentsCount) >
                                  0) ...[
                            const SizedBox(width: 5),
                            Text(
                              '${data['commentsCount'] ?? widget.post.commentsCount}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Builder(builder: (btnCtx) {
                      // ✅ Pre-build translated strings HERE (build context).
                      // Cannot do this inside the onTap event handler — it
                      // would call listen:true Provider.of from outside
                      // build() and silently crash the share sheet.
                      final sharedCaption =
                          '${btnCtx.tr('check_out_post')} ${widget.post.username}\n${_buildPostLink()}';
                      final copyLinkLabel = btnCtx.tr('copy_link');
                      final linkCopiedMsg = btnCtx.tr('link_copied');
                      return GestureDetector(
                        onTap: () => _showShareSheet(
                          btnCtx,
                          sharedCaption: sharedCaption,
                          copyLinkLabel: copyLinkLabel,
                          linkCopiedMsg: linkCopiedMsg,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send,
                                color: isDark ? Colors.white : Colors.black,
                                size: 26),
                            if (!hideShareCount && shareCount > 0) ...[
                              const SizedBox(width: 5),
                              Text(
                                '$shareCount',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                    const SizedBox(width: 16),
                    // ─── Repost button ────────────────────────────────
                    GestureDetector(
                      onTap: () => _toggleRepost(isReposted),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.repeat,
                            color: isReposted
                                ? Colors.green
                                : (isDark ? Colors.white : Colors.black),
                            size: 26,
                          ),
                          if (repostsCount > 0) ...[
                            const SizedBox(width: 5),
                            Text(
                              '$repostsCount',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color:
                                    isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
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

              if (!hideLikes)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '$likesCount ${context.tr('likes')}',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isDark ? Colors.white : Colors.black),
                  ),
                ),

              const SizedBox(height: 6),

              // ── Location row (city/place) ─────────────────────
              if ((data['location'] as String? ?? '').trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Color(0xFF0095F6)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          (data['location'] as String?) ?? '',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.black54),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: RichText(
                  text: TextSpan(children: [
                    TextSpan(
                        text: '${widget.post.username} ',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black)),
                    ..._buildCaptionWithHashtags(widget.post.caption),
                  ]),
                ),
              ),
              const SizedBox(height: 6),

              // ── Sticker emojis row ────────────────────────────
              if (((data['stickerEmojis'] as String?) ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 2),
                  child: Text(
                    (data['stickerEmojis'] as String?) ?? '',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),

              // ── Tagged users chips ────────────────────────────
              if ((data['taggedUsers'] is List) &&
                  (data['taggedUsers'] as List).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: ((data['taggedUsers'] as List)
                            .whereType<Map>())
                        .map((u) {
                      final uname = (u['username'] ?? '').toString();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F3FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '@$uname',
                          style: const TextStyle(
                              color: Color(0xFF0095F6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      );
                    }).toList(),
                  ),
                ),

              // ── Poll widget ───────────────────────────────────
              if (data['hasPoll'] == true && data['poll'] is Map)
                _PostPollWidget(
                  postId: widget.post.id,
                  poll: Map<String, dynamic>.from(data['poll'] as Map),
                ),

              // ── Linked reel preview ───────────────────────────
              if (data['linkedReel'] is Map)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF0095F6), width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.play_circle_fill,
                            color: Color(0xFF0095F6), size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Linked Reel',
                                style: TextStyle(
                                    color: Color(0xFF0095F6),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ((data['linkedReel']
                                            as Map?)?['text'] ??
                                        '')
                                    .toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.black87),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              if (commentsDisabled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    context.tr('comments_turned_off'),
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                )
              else if ((data['commentsCount'] ??
                      widget.post.commentsCount) >
                  0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CommentsScreen(
                                postId: widget.post.id,
                                postUsername: widget.post.username,
                                currentUserAvatar:
                                    _auth.currentUser?.photoURL ?? '',
                                currentUsername:
                                    _auth.currentUser?.displayName ??
                                        context.tr('you')))),
                    child: Text(
                      '${context.tr('view_all_comments_count')} ${data['commentsCount'] ?? widget.post.commentsCount} ${context.tr('comments')}',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ),
                ),
              const SizedBox(height: 6),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(widget.post.time.toUpperCase(),
                    style:
                    TextStyle(color: Colors.grey[500], fontSize: 10)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
class Post {
  final String id;
  final String userId;
  final String avatarUrl;
  final String username;
  final String time;
  final String postImageUrl;
  final int likesCount;
  final int commentsCount;
  final bool isVideo;
  final String? videoUrl;
  final String caption;
  final bool isLarge;
  final bool hideLikes;
  final bool commentsDisabled;
  final bool hideShareCount;

  Post({
    required this.id,
    required this.userId,
    required this.avatarUrl,
    required this.username,
    required this.time,
    required this.postImageUrl,
    required this.likesCount,
    required this.commentsCount,
    this.isVideo = false,
    this.videoUrl,
    this.caption = '',
    this.isLarge = true,
    this.hideLikes = false,
    this.commentsDisabled = false,
    this.hideShareCount = false,
  });

  factory Post.fromFirestore(String docId, Map<String, dynamic> data) {
    final timestamp = data['timestamp'];
    String timeStr = '';
    if (timestamp != null && timestamp is Timestamp) {
      final diff = DateTime.now().difference(timestamp.toDate());
      if (diff.inDays > 0) {
        timeStr = '${diff.inDays}d';
      } else if (diff.inHours > 0) {
        timeStr = '${diff.inHours}h';
      } else {
        timeStr = '${diff.inMinutes}m';
      }
    }

    return Post(
      id: docId,
      userId: data['authorid'] ?? '',
      username: data['username'] ?? 'Unknown',
      avatarUrl: data['photoUrl'] ?? '',
      postImageUrl: data['imageUrl'] ?? '',
      caption: data['text'] ?? '',
      likesCount: (data['likesCount'] ?? 0) as int,
      commentsCount: (data['commentsCount'] ?? 0) as int,
      isVideo: data['isVideo'] ?? false,
      videoUrl: data['videoUrl'],
      time: timeStr,
      isLarge: true,
      hideLikes: data['hideLikeCount'] ?? false,
      commentsDisabled: data['turnOffCommenting'] ?? false,
      hideShareCount: data['hideShareCount'] ?? false,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Share sheet model — followed users + messaged users
// ─────────────────────────────────────────────────────────────
class _ShareTarget {
  final String userId;
  final String username;
  final String avatarUrl;
  final String source; // 'following' | 'message'

  _ShareTarget({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.source,
  });
}

// ─────────────────────────────────────────────────────────────
// Poll widget — shows question + options, lets user vote once.
// Vote count is stored in `poll.votes[optionIndex]` and the user's
// vote in `poll.voters[uid]` so we can render results & block
// double-voting on next render.
// ─────────────────────────────────────────────────────────────
class _PostPollWidget extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> poll;
  const _PostPollWidget({required this.postId, required this.poll});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final question = (poll['question'] ?? '').toString();
    final options = ((poll['options'] as List?) ?? const [])
        .map((e) => e.toString())
        .toList();
    final votes = ((poll['votes'] as List?) ?? const [])
        .map((e) => (e is int) ? e : int.tryParse(e.toString()) ?? 0)
        .toList();
    // pad votes to options length
    while (votes.length < options.length) {
      votes.add(0);
    }
    final voters =
        (poll['voters'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{};
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final myVote = voters[uid] is int
        ? voters[uid] as int
        : int.tryParse('${voters[uid] ?? ''}');
    final totalVotes = votes.fold<int>(0, (a, b) => a + b);
    final hasVoted = myVote != null;

    Future<void> castVote(int idx) async {
      if (uid.isEmpty || hasVoted) return;
      final ref = FirebaseFirestore.instance.collection('posts').doc(postId);
      // Build new votes list with idx incremented.
      final newVotes = List<int>.from(votes);
      if (idx >= 0 && idx < newVotes.length) newVotes[idx] += 1;
      await ref.update({
        'poll.votes': newVotes,
        'poll.voters.$uid': idx,
      });
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F3FF), Color(0xFFF0F8FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF0095F6), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.poll, size: 18, color: Color(0xFF0095F6)),
                SizedBox(width: 6),
                Text('Poll',
                    style: TextStyle(
                        color: Color(0xFF0095F6),
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            if (question.isNotEmpty)
              Text(question,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 8),
            ...List.generate(options.length, (i) {
              final v = votes[i];
              final pct = totalVotes == 0 ? 0.0 : v / totalVotes;
              final isMine = myVote == i;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GestureDetector(
                  onTap: hasVoted ? null : () => castVote(i),
                  child: Stack(
                    children: [
                      Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: isMine
                                  ? const Color(0xFF0095F6)
                                  : Colors.grey.shade300,
                              width: isMine ? 2 : 1),
                        ),
                      ),
                      if (hasVoted)
                        FractionallySizedBox(
                          widthFactor: pct.clamp(0.0, 1.0),
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: isMine
                                  ? const Color(0xFF0095F6).withOpacity(0.25)
                                  : const Color(0xFFE8F3FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  options[i],
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontWeight: isMine
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (hasVoted)
                                Text(
                                  '${(pct * 100).round()}% · $v',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF0095F6),
                                      fontWeight: FontWeight.w600),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 4),
            Text(
              '$totalVotes vote${totalVotes == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}