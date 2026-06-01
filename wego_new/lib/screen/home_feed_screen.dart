import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:badges/badges.dart' as badges;
import 'package:wego_marriage/main.dart' show appRouteObserver;
import 'package:wego_marriage/providers/story_provider.dart';
import 'package:wego_marriage/providers/chat_provider.dart';
import 'package:wego_marriage/providers/user_provider.dart';
import 'package:wego_marriage/providers/privacy_provider.dart';
import 'package:wego_marriage/screen/story_screen.dart';
import 'package:wego_marriage/screen/my_profile.dart';
import 'package:wego_marriage/screen/notifications_screen.dart';
import 'package:wego_marriage/services/notification_service.dart';
import 'package:wego_marriage/screen/massage_list_screen.dart';
import 'package:wego_marriage/screen/comments_screen.dart';
import 'package:wego_marriage/screen/user_profile_screen.dart';
import 'package:wego_marriage/screen/create_content_screen.dart';
import 'package:wego_marriage/screen/fullscreen_video_viewer.dart';
import 'package:wego_marriage/screen/connection_secreen.dart';
import 'package:wego_marriage/screen/search_screen.dart';
import 'package:wego_marriage/screen/report_post_screen.dart';
import 'package:wego_marriage/screen/xp_service.dart';
import 'package:wego_marriage/services/local_storage_service.dart';
import 'package:wego_marriage/services/follow_controller.dart';
import 'package:wego_marriage/widgets/latest_badge_chip.dart';
import 'package:wego_marriage/widgets/post_shared_sheet.dart';
import 'package:wego_marriage/services/message_badge_service.dart';
import 'package:wego_marriage/services/legendary_announcement_service.dart';
import 'package:wego_marriage/services/cloudinary_service.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'app_localizations.dart';

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

class InstagramStylePostCardState extends State<InstagramStylePostCard>
    with RouteAware, WidgetsBindingObserver {
  bool _isLiked = false;
  bool _isSaved = false;
  // ─── Cross-screen follow-state ───────────────────────────────────────────
  // App-wide singleton: home feed, user profile, comments, notifications sab
  // ek hi notifier per-target share karte hain. Ek jagah follow karne pe sab
  // jagah pill foran flip ho jata hai.
  ValueNotifier<bool>? _followNotifier;

  bool get _isFollowing => _followNotifier?.value ?? false;

  void _onBusChange() {
    if (mounted) setState(() {});
  }
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  // Background music for photo posts. We loop the 30-sec Deezer preview while
  // the user keeps the post on screen. Video posts don't use this — the song
  // is already muxed into the video file by ffmpeg at upload time.
  AudioPlayer? _songPlayer;
  bool _songPlaying = false;
  final LocalStorageService _storage = LocalStorageService();

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ─── Playback gating ────────────────────────────────────────────────────
  // Card "playable" tab hai jab teeno true hon:
  //   1. `_routeIsTop` — koi screen iske upar push nahi hui (route on top)
  //   2. `_appResumed`  — app foreground me hai
  //   3. `_visibleEnough` — card ka >=50% area viewport ke andar hai
  // Kisi bhi ek false hote hi video aur background music foran pause.
  bool _routeIsTop = true;
  bool _appResumed = true;
  bool _visibleEnough = false;
  // Scrollable position jisko listen kar rahe hain — visibility re-compute
  // har scroll tick par hota hai.
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Shared follow-state via app-wide FollowController — har screen same
    // notifier listen karega, follow karte hi sab jagah pill foran flip.
    _followNotifier = FollowController.instance.notifier(widget.post.userId);
    _followNotifier!.addListener(_onBusChange);
    FollowController.instance.watch(widget.post.userId);
    _loadPersistedState();
    if (widget.post.isVideo) _initializeVideo();
    _maybeStartSong();
    // Pehle frame ke baad visibility check — initial state set ho jaye.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recomputeVisibility();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Parent route subscribe karo — push/pop par notify hone ke liye.
    final route = ModalRoute.of(context);
    if (route is ModalRoute) {
      appRouteObserver.subscribe(this, route);
    }
    // Enclosing Scrollable ka position pick up karo (feed ka ListView).
    // Card list me andar hai to yeh ListView ki position return karega.
    final newPos = Scrollable.maybeOf(context)?.position;
    if (newPos != _scrollPosition) {
      _scrollPosition?.removeListener(_onScrollTick);
      _scrollPosition = newPos;
      _scrollPosition?.addListener(_onScrollTick);
    }
  }

  void _onScrollTick() {
    // Har scroll frame pe visibility re-compute. Cheap operation —
    // RenderBox global offset + viewport bounds intersection.
    if (mounted) _recomputeVisibility();
  }

  /// Card ka >= 50% area screen-viewport me visible hai ya nahi.
  /// Jab status flip ho to playback apply karo.
  void _recomputeVisibility() {
    final renderObj = context.findRenderObject();
    if (renderObj is! RenderBox || !renderObj.attached) return;

    final size = renderObj.size;
    if (size.height <= 0) return;

    final offset = renderObj.localToGlobal(Offset.zero);
    final screenSize = MediaQuery.of(context).size;

    // Card ka viewport ke saath vertical intersection nikalo. Horizontal
    // ko ignore karte hain (feed full-width hota hai).
    final cardTop = offset.dy;
    final cardBottom = offset.dy + size.height;
    final visibleTop = cardTop.clamp(0.0, screenSize.height);
    final visibleBottom = cardBottom.clamp(0.0, screenSize.height);
    final visibleHeight = (visibleBottom - visibleTop).clamp(0.0, size.height);
    final fraction = visibleHeight / size.height;

    final shouldPlay = fraction >= 0.5;
    if (shouldPlay != _visibleEnough) {
      _visibleEnough = shouldPlay;
      _applyPlaybackState();
    }
  }

  /// Three-input AND: video aur song dono ko playable state apply karo.
  void _applyPlaybackState() {
    final playable = _routeIsTop && _appResumed && _visibleEnough;
    final vc = _videoController;
    if (vc != null && _isVideoInitialized) {
      if (playable) {
        if (!vc.value.isPlaying) vc.play();
      } else {
        if (vc.value.isPlaying) vc.pause();
      }
    }
    final sp = _songPlayer;
    if (sp != null) {
      if (playable) {
        if (!_songPlaying) {
          sp.resume();
          _songPlaying = true;
        }
      } else {
        if (_songPlaying) {
          sp.pause();
          _songPlaying = false;
        }
      }
    }
  }

  // ── RouteAware — koi screen upar push hui ya wapas aaye ──
  @override
  void didPushNext() {
    _routeIsTop = false;
    _applyPlaybackState();
  }

  @override
  void didPopNext() {
    _routeIsTop = true;
    _applyPlaybackState();
  }

  // ── App lifecycle ──
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasResumed = _appResumed;
    _appResumed = state == AppLifecycleState.resumed;
    if (wasResumed != _appResumed) _applyPlaybackState();
  }

  // Photo post + song chuna gaya tha → trim window par loop chalao.
  // (Video posts mein song already file mein muxed hai, yahan kuch nahi.)
  Future<void> _maybeStartSong() async {
    if (widget.post.isVideo) return;
    final url = widget.post.songPreviewUrl;
    if (url == null || url.isEmpty) return;
    try {
      _songPlayer = AudioPlayer();
      // Loop ko manually handle karte hain — endMs cross ho to startMs par seek.
      await _songPlayer!.setReleaseMode(ReleaseMode.stop);
      _songPlayer!.onPositionChanged.listen((d) {
        if (!mounted || !_songPlaying) return;
        if (d.inMilliseconds >= widget.post.songEndMs) {
          _songPlayer!
              .seek(Duration(milliseconds: widget.post.songStartMs));
        }
      });
      _songPlayer!.onPlayerComplete.listen((_) async {
        if (!mounted) return;
        await _songPlayer!
            .seek(Duration(milliseconds: widget.post.songStartMs));
        await _songPlayer!.resume();
      });
      await _songPlayer!.play(UrlSource(url));
      if (widget.post.songStartMs > 0) {
        await _songPlayer!
            .seek(Duration(milliseconds: widget.post.songStartMs));
      }
      // ✅ Player ready hai — songPlaying ko tentative true rakho, lekin
      //    foran gating apply karo. Agar card visible nahi to pause hote
      //    hi `_songPlaying = false` ho jayega.
      _songPlaying = true;
      _applyPlaybackState();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Post song play error: $e');
    }
  }

  Future<void> _toggleSong() async {
    final p = _songPlayer;
    if (p == null) return;
    try {
      if (_songPlaying) {
        await p.pause();
      } else {
        await p.resume();
      }
      if (mounted) setState(() => _songPlaying = !_songPlaying);
    } catch (_) {}
  }

  void _loadPersistedState() async {
    // Optimistic: local cache se turant set karo (offline-safe).
    // Follow state ka seed + Firestore reconcile ab FollowController.watch
    // handle karta hai — yahaan sirf like/save.
    _isLiked = _storage.isPostLiked(widget.post.id);
    _isSaved = _storage.isPostSaved(widget.post.id);
    if (mounted) setState(() {});

    // Authoritative like reconcile from Firestore (source of truth = likedBy).
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap =
          await _firestore.collection('posts').doc(widget.post.id).get();
      if (!snap.exists || !mounted) return;
      final data = snap.data() ?? {};
      final likedBy = List<String>.from(data['likedBy'] ?? const []);
      final firestoreLiked = likedBy.contains(uid);
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
    _scrollPosition?.removeListener(_onScrollTick);
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _followNotifier?.removeListener(_onBusChange);
    _videoController?.dispose();
    _songPlayer?.dispose();
    super.dispose();
  }

  void _initializeVideo() {
    // ✅ Pehle URL validate karo — empty/null pe controller mat banao warna
    //    `.initialize()` silently throw karta hai, _isVideoInitialized false
    //    reh jata hai aur UI fallback Image.network(mp4Url) try karke crash
    //    karta hai. Wahi tha "video load nahi ho raha" wala bug.
    final url = widget.post.videoUrl;
    if (url == null || url.isEmpty) {
      debugPrint('Video post has no videoUrl — skipping init');
      return;
    }
    _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController!.initialize().then((_) {
      if (mounted) {
        setState(() => _isVideoInitialized = true);
        _videoController?.setLooping(true);
        // ✅ Auto-play yahaan unconditional NAHI hai — playback gating
        //    (_routeIsTop && _appResumed && _visibleEnough) decide karega.
        //    Scroll par feed pe nazar na ho to video silently band rahe.
        _applyPlaybackState();
      }
    }).catchError((e) {
      debugPrint('Video init failed: $e');
      // Mounted check — agar widget dispose ho gaya to no-op.
      // _isVideoInitialized false hi rakhte hain, UI black placeholder dikhayega.
      if (mounted) setState(() {});
    });
  }

  void _toggleLike() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    // ─ Optimistic flip ─ UI turant chamke, lekin Firestore likhne ke liye
    //   sirf local `_isLiked` par bharosa NA karein — `likedBy` array hi
    //   single source of truth hai. Pehle blind `FieldValue.increment(-1)`
    //   hota tha jo user already-unliked tha to count -1 le jata tha. Ab
    //   transaction ke andar actual array check karke delta nikalte hain.
    final newVal = !_isLiked;
    setState(() => _isLiked = newVal);
    await _storage.toggleLike(widget.post.id, newVal);

    final postRef = _firestore.collection('posts').doc(widget.post.id);
    bool serverAddedLike = false;
    bool serverRemovedLike = false;
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(postRef);
        if (!snap.exists) return;
        final data = snap.data() ?? {};
        final likedBy = List<String>.from(data['likedBy'] ?? const []);
        final rawCount = (data['likesCount'] ?? 0);
        final currentCount =
            rawCount is int ? rawCount : (rawCount as num).toInt();
        final alreadyLiked = likedBy.contains(currentUserId);

        if (newVal && !alreadyLiked) {
          // Pehli baar like — count +1, array me add.
          tx.update(postRef, {
            'likesCount': currentCount + 1,
            'likedBy': FieldValue.arrayUnion([currentUserId]),
          });
          serverAddedLike = true;
        } else if (!newVal && alreadyLiked) {
          // Genuine unlike — count -1 (par 0 se neeche kabhi nahi).
          tx.update(postRef, {
            'likesCount': currentCount > 0 ? currentCount - 1 : 0,
            'likedBy': FieldValue.arrayRemove([currentUserId]),
          });
          serverRemovedLike = true;
        }
        // Baqi cases (already-liked + tap-to-like, ya already-unliked +
        // tap-to-unlike) idempotent no-op — count safe rahe.
      });
    } catch (e) {
      debugPrint('Like toggle transaction failed: $e');
      // Revert optimistic state on failure.
      if (mounted) setState(() => _isLiked = !newVal);
      await _storage.toggleLike(widget.post.id, !newVal);
      return;
    }

    if (serverAddedLike) {
      await XPService.addXP(currentUserId, XPAction.likeKarna);
      unawaited(NotificationService.notifyLike(
        postOwnerUid: widget.post.userId,
        postId: widget.post.id,
        postThumbUrl: widget.post.thumbnailUrl,
      ));
    } else if (serverRemovedLike) {
      unawaited(NotificationService.removeLike(
        postOwnerUid: widget.post.userId,
        postId: widget.post.id,
      ));
    }
  }

  // ─── Favorite (save) toggle — posts/{id}.savedBy array + count maintain.
  //  Optimistic UI + Firestore array write + local cache mirror. Save par
  //  post owner ko 'favorite' notification jata hai (dedupe deterministic
  //  doc id ke through, taake 100 bar toggle pe bhi sirf 1 notification).
  Future<void> _toggleSave() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final newVal = !_isSaved;
    setState(() => _isSaved = newVal);
    await _storage.toggleSaved(widget.post.id, newVal);

    final postRef = _firestore.collection('posts').doc(widget.post.id);
    // Transaction — array check kar ke delta apply karte hain, taa ke
    // savedCount kabhi negative na ho aur duplicate save count nahi le.
    bool serverAdded = false;
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(postRef);
        if (!snap.exists) return;
        final data = snap.data() ?? {};
        final savedBy = List<String>.from(data['savedBy'] ?? const []);
        final rawCount = (data['savedCount'] ?? 0);
        final currentCount =
            rawCount is int ? rawCount : (rawCount as num).toInt();
        final alreadySaved = savedBy.contains(uid);

        if (newVal && !alreadySaved) {
          tx.update(postRef, {
            'savedCount': currentCount + 1,
            'savedBy': FieldValue.arrayUnion([uid]),
          });
          serverAdded = true;
        } else if (!newVal && alreadySaved) {
          tx.update(postRef, {
            'savedCount': currentCount > 0 ? currentCount - 1 : 0,
            'savedBy': FieldValue.arrayRemove([uid]),
          });
        }
      });
    } catch (e) {
      debugPrint('Save toggle transaction failed: $e');
      if (mounted) setState(() => _isSaved = !newVal);
      await _storage.toggleSaved(widget.post.id, !newVal);
      return;
    }

    if (serverAdded) {
      unawaited(NotificationService.notifyFavorite(
        postOwnerUid: widget.post.userId,
        postId: widget.post.id,
        postThumbUrl: widget.post.thumbnailUrl,
      ));
    } else if (!newVal) {
      unawaited(NotificationService.removeFavorite(
        postOwnerUid: widget.post.userId,
        postId: widget.post.id,
      ));
    }
  }

  // ─── Repost toggle — posts/{id}.repostedBy array maintain karte hain ───
  //  Repost author ko notification jata hai (sirf add ke time).
  Future<void> _toggleRepost(bool currentlyReposted) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _firestore.collection('posts').doc(widget.post.id);
    // Transaction — repostsCount ka negative jaane se bachne ke liye aur
    // duplicate repost taps ko idempotent rakhne ke liye.
    bool serverAdded = false;
    bool serverRemoved = false;
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() ?? {};
        final repostedBy = List<String>.from(data['repostedBy'] ?? const []);
        final rawCount = (data['repostsCount'] ?? 0);
        final currentCount =
            rawCount is int ? rawCount : (rawCount as num).toInt();
        final alreadyReposted = repostedBy.contains(uid);

        // `currentlyReposted` UI ka guess hai; truth `alreadyReposted` hi
        // hai. Dono mil bhi sakte hain, lekin priority truth ko.
        if (!alreadyReposted) {
          tx.update(ref, {
            'repostsCount': currentCount + 1,
            'repostedBy': FieldValue.arrayUnion([uid]),
          });
          serverAdded = true;
        } else {
          tx.update(ref, {
            'repostsCount': currentCount > 0 ? currentCount - 1 : 0,
            'repostedBy': FieldValue.arrayRemove([uid]),
          });
          serverRemoved = true;
        }
      });
    } catch (e) {
      debugPrint('Repost toggle transaction failed: $e');
      return;
    }

    if (serverAdded) {
      unawaited(NotificationService.notifyRepost(
        postOwnerUid: widget.post.userId,
        postId: widget.post.id,
        postThumbUrl: widget.post.thumbnailUrl,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reposted'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else if (serverRemoved) {
      unawaited(NotificationService.removeRepost(
        postOwnerUid: widget.post.userId,
        postId: widget.post.id,
      ));
    }
  }

  void _toggleFollow() async {
    final wasFollowing = _isFollowing;
    final newState =
        await FollowController.instance.toggle(widget.post.userId);
    if (!mounted) return;
    // Snackbar sirf agar user ka intent successful raha.
    if (newState != wasFollowing) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          newState
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
        // Favorite (save) state — savedBy array, same pattern.
        final savedBy = List<String>.from(data['savedBy'] ?? const []);
        final liveIsSaved = currentUid != null && savedBy.contains(currentUid);

        // Counts: pichli buggy `FieldValue.increment(-1)` writes ki wajah se
        // kuch posts ka likesCount/savedCount/repostsCount negative ho gaya
        // tha. Ab array length ko authoritative manate hain (max with stored
        // count, never negative). Yeh display-side self-heal hai — agle write
        // par stored count bhi sahi ho jata hai.
        int safeCount(dynamic stored, List arr) {
          final s = stored is num ? stored.toInt() : 0;
          return s < 0 ? arr.length : (s > arr.length ? s : arr.length);
        }
        final likesCount = hideLikes
            ? 0
            : safeCount(data['likesCount'] ?? widget.post.likesCount, likedBy);
        final repostsCount = safeCount(data['repostsCount'], repostedBy);
        final savedCount = safeCount(data['savedCount'], savedBy);
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
        // Same reconcile for favorite (save) — Firestore source of truth.
        if (hasRealData && liveIsSaved != _isSaved) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && liveIsSaved != _isSaved) {
              setState(() => _isSaved = liveIsSaved);
              _storage.toggleSaved(widget.post.id, liveIsSaved);
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
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── Avatar (+ privacy-gated online dot) ──
                    GestureDetector(
                      onTap: _navigateToProfile,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
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
                          Positioned(
                            right: -1,
                            bottom: -1,
                            child: StreamBuilder<bool>(
                              stream: context
                                  .read<PrivacyProvider>()
                                  .watchShouldShowOnline(
                                    widget.post.userId,
                                    _auth.currentUser?.uid ?? '',
                                  ),
                              builder: (_, snap) {
                                if (snap.data != true) {
                                  return const SizedBox.shrink();
                                }
                                return Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF44D362),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // ── Name pehle, phir follow pill ──
                    // Order: avatar → name (+badge) → follow/following pill.
                    // User request: pill name ke "agy" nahi "pichy" aaye.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: GestureDetector(
                                  onTap: _navigateToProfile,
                                  child: widget.post.username.isNotEmpty
                                      ? Text(
                                          widget.post.username,
                                          style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: isDark
                                                  ? Colors.white
                                                  : Colors.black),
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      : FutureBuilder<DocumentSnapshot>(
                                          future: FirebaseFirestore.instance
                                              .collection('users')
                                              .doc(widget.post.userId)
                                              .get(),
                                          builder: (_, snap) {
                                            String name = '';
                                            if (snap.hasData &&
                                                snap.data!.exists) {
                                              final d = snap.data!.data()
                                                  as Map<String, dynamic>?;
                                              name = ((d?['username'] ??
                                                          d?['fullName'] ??
                                                          d?['name'] ??
                                                          d?['displayName'] ??
                                                          '')
                                                      .toString())
                                                  .trim();
                                            }
                                            return Text(
                                              name.isEmpty ? 'User' : name,
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black),
                                              overflow: TextOverflow.ellipsis,
                                            );
                                          },
                                        ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              LatestBadgeChip(
                                uid: widget.post.userId,
                                size: 22,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // ── Follow / Following pill (ab name ke baad) ──
                    if (_auth.currentUser?.uid != widget.post.userId) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _toggleFollow,
                        child: _isFollowing
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : const Color(0xFFF0F0F0),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white24
                                        : const Color(0xFFD0D0D0),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check,
                                        size: 13,
                                        color: isDark
                                            ? Colors.white70
                                            : Colors.grey[700]),
                                    const SizedBox(width: 4),
                                    Text(
                                      context.tr('following'),
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white70
                                              : Colors.grey[700],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0095F6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  context.tr('follow'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                      ),
                    ],
                    IconButton(
                        icon: Icon(Icons.more_vert,
                            color: isDark ? Colors.white : Colors.black),
                        onPressed: () => _showMoreOptions(context)),
                  ],
                ),
              ),

              GestureDetector(
                onDoubleTap: _toggleLike,
                // Insta-style: video post pe single tap → fullscreen viewer
                // khulta hai. Photo posts ke liye onTap rakha hi nahi (warna
                // double-tap-like ko gesture arbitration thoda delay karta).
                onTap: widget.post.isVideo
                    ? () {
                        // Inline player pause kar do — wapas aane par chalega.
                        _videoController?.pause();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FullscreenVideoViewer(
                              postId: widget.post.id,
                              initialPost: widget.post,
                            ),
                          ),
                        ).then((_) {
                          if (mounted && _isVideoInitialized) {
                            _videoController?.play();
                          }
                        });
                      }
                    : null,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 400),
                      // ✅ Video posts ke liye Image.network fallback HATA diya
                      //    hai — `postImageUrl` me mp4 URL hota tha aur Image
                      //    decoder usko render nahi kar pata tha. Ab video
                      //    initialize hone tak black + spinner placeholder
                      //    dikhate hain. Photo posts ka behavior same.
                      child: widget.post.isVideo
                          ? (_isVideoInitialized
                              ? AspectRatio(
                                  aspectRatio:
                                      _videoController!.value.aspectRatio,
                                  child: VideoPlayer(_videoController!))
                              : Container(
                                  height: 400,
                                  color: Colors.black,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                              Colors.white),
                                    ),
                                  ),
                                ))
                          : Image.network(widget.post.postImageUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                    height: 400,
                                    color: Colors.grey[300],
                                    child: const Center(
                                        child:
                                            CircularProgressIndicator()));
                              },
                              errorBuilder: (_, __, ___) => Container(
                                  height: 400,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.error))),
                    ),
                    if ((widget.post.songTitle ?? '').isNotEmpty)
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: GestureDetector(
                          onTap: _toggleSong,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _songPlaying
                                      ? Icons.music_note
                                      : Icons.music_off,
                                  color: Colors.white,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                      maxWidth: 180),
                                  child: Text(
                                    '${widget.post.songTitle}'
                                    '${widget.post.songArtist != null && widget.post.songArtist!.isNotEmpty ? ' • ${widget.post.songArtist}' : ''}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
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
                      // Shared bottom sheet — followers/messaged + external
                      // (WA/FB/Copy/More) + author-gated download. Saari
                      // localization PostSharedSheet ke andar resolve hoti.
                      return GestureDetector(
                        onTap: () => PostSharedSheet.show(
                          btnCtx,
                          post: widget.post,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isSaved ? Icons.bookmark : Icons.bookmark_border,
                            color: _isSaved
                                ? const Color(0xFF0095F6)
                                : (isDark ? Colors.white : Colors.black),
                            size: 28,
                          ),
                          if (savedCount > 0) ...[
                            const SizedBox(width: 5),
                            Text(
                              '$savedCount',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ],
                        ],
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
  // ✅ Server-side video poster + author opt-in download flag. Both nullable /
  // defaulted so legacy posts (created before these fields existed) keep working.
  final String? thumbnailUrlRaw;
  final bool allowDownloads;
  // Song metadata — TikTok-style background music. For video posts the song
  // is already muxed into the file; we still keep these for the "Sound by …"
  // chip. For photo posts, the feed plays the previewUrl while the photo
  // is on-screen.
  final String? songTitle;
  final String? songArtist;
  final String? songPreviewUrl;
  final String? songAlbumArt;
  final int songStartMs;
  final int songEndMs;

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
    this.thumbnailUrlRaw,
    this.allowDownloads = false,
    this.songTitle,
    this.songArtist,
    this.songPreviewUrl,
    this.songAlbumArt,
    this.songStartMs = 0,
    this.songEndMs = 30000,
  });

  /// Resolved poster URL — what notifications, shared-chat cards, and the
  /// share-sheet thumbnail download all consume.
  ///
  /// Priority:
  ///   1. The `thumbnailUrl` field saved at upload (new posts).
  ///   2. For video posts on Cloudinary without that field (legacy), derive
  ///      a poster URL on the fly via `so_0/` transform.
  ///   3. For image posts, the original `postImageUrl`.
  ///   4. Empty string — caller's `errorBuilder` shows the existing placeholder.
  ///
  /// This is read-only; we don't mutate Firestore here.
  String get thumbnailUrl {
    if (thumbnailUrlRaw != null && thumbnailUrlRaw!.isNotEmpty) {
      return thumbnailUrlRaw!;
    }
    if (isVideo) {
      return CloudinaryService.videoThumbnailUrl(postImageUrl) ?? '';
    }
    return postImageUrl;
  }

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

    // Username: try common variants. Purane posts mein sirf `username` set
    // hota tha; kabhi `fullName` / `name` / `displayName` ho sakta hai.
    final rawName = (data['username'] ??
            data['fullName'] ??
            data['name'] ??
            data['displayName'] ??
            '')
        .toString()
        .trim();
    return Post(
      id: docId,
      userId: data['authorid'] ?? '',
      username: rawName.isEmpty ? '' : rawName,
      avatarUrl: data['photoUrl'] ?? '',
      postImageUrl: data['imageUrl'] ?? '',
      caption: data['text'] ?? '',
      likesCount: (data['likesCount'] ?? 0) as int,
      commentsCount: (data['commentsCount'] ?? 0) as int,
      isVideo: data['isVideo'] ?? false,
      // ✅ Backward compat: purane video posts ke documents me sirf `imageUrl`
      //    set tha (Cloudinary mp4 URL). Agar `videoUrl` missing hai aur post
      //    video hai, to `imageUrl` se fall back kar lo — VideoPlayer chal jaye.
      videoUrl: (data['videoUrl'] as String?) ??
          ((data['isVideo'] == true) ? (data['imageUrl'] as String?) : null),
      time: timeStr,
      isLarge: true,
      hideLikes: data['hideLikeCount'] ?? false,
      commentsDisabled: data['turnOffCommenting'] ?? false,
      hideShareCount: data['hideShareCount'] ?? false,
      thumbnailUrlRaw: data['thumbnailUrl'] as String?,
      allowDownloads: data['allowDownloads'] ?? false,
      songTitle: data['songTitle'] as String?,
      songArtist: data['songArtist'] as String?,
      songPreviewUrl: data['songPreviewUrl'] as String?,
      songAlbumArt: data['songAlbumArt'] as String?,
      songStartMs: (data['songStartMs'] as num?)?.toInt() ?? 0,
      songEndMs: (data['songEndMs'] as num?)?.toInt() ?? 30000,
    );
  }
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
    final rawVotes = poll['votes'];
    final votes = rawVotes is List
        ? rawVotes.map((e) => (e is int) ? e : int.tryParse(e.toString()) ?? 0).toList()
        : rawVotes is Map
        ? (poll['options'] as List? ?? [])
        .map((opt) => (rawVotes[opt.toString()] ?? 0) as int)
        .toList()
        : <int>[];
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
