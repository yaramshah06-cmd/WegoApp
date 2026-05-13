import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:badges/badges.dart' as badges;
import 'package:wego_marriage/providers/story_provider.dart';
import 'package:wego_marriage/providers/chat_provider.dart';
import 'package:wego_marriage/providers/user_provider.dart';
import 'package:wego_marriage/screen/story_screen.dart';
import 'package:wego_marriage/screen/my_profile.dart';
import 'package:wego_marriage/screen/massage_list_screen.dart';
import 'package:wego_marriage/screen/comments_screen.dart';
import 'package:wego_marriage/screen/user_profile_screen.dart';
import 'package:wego_marriage/screen/create_content_screen.dart';
import 'package:wego_marriage/screen/connection_secreen.dart';
import 'package:wego_marriage/screen/search_screen.dart';
import 'package:wego_marriage/screen/xp_service.dart';
import 'package:wego_marriage/services/local_storage_service.dart';
import 'package:wego_marriage/services/message_badge_service.dart';
import 'package:wego_marriage/services/legendary_announcement_service.dart';
import 'package:video_player/video_player.dart';
import 'package:share_plus/share_plus.dart';
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
  bool _isLoading = false;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;

  // Legendary announcement
  String? _legendaryDisplayName;
  bool _announcementChecked = false;

  final _firestore = FirebaseFirestore.instance;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _loadMorePosts();
    _scrollController.addListener(_onScroll);
    _checkLegendaryAnnouncement();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final currentUid = currentUser.uid;

      Query query = _firestore
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      _lastDocument = snapshot.docs.last;

      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final visibility = data['visibility'] as String? ?? 'everyone';
        final authorId = data['authorid'] as String? ?? '';
        final allowedUids = List<String>.from(data['allowedUids'] ?? []);

        if (visibility == 'only_me') return authorId == currentUid;
        if (visibility == 'close_friends') return allowedUids.contains(currentUid);
        return true;
      }).toList();

      final newPosts = filteredDocs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return Post.fromFirestore(doc.id, data);
      }).toList();

      setState(() {
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
    _posts.clear();
    _lastDocument = null;
    _hasMore = true;
    await _loadMorePosts();
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
                        child: _InstagramStylePostCard(post: _posts[index]),
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

  Widget _buildStoryRow(BuildContext context, List<UserStory> userStories) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: SizedBox(
        height: 68,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: userStories.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, i) {
            if (i == 0) {
              return _AddStoryButton(
                onTap: () {
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
            final userStory = userStories[i - 1];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => StoryScreen(initialUserIndex: i - 1),
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
class _AddStoryButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddStoryButton({required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
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
class _InstagramStylePostCard extends StatefulWidget {
  final Post post;
  const _InstagramStylePostCard({required this.post});

  @override
  State<_InstagramStylePostCard> createState() =>
      _InstagramStylePostCardState();
}

class _InstagramStylePostCardState extends State<_InstagramStylePostCard> {
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

  void _loadPersistedState() {
    _isLiked = _storage.isPostLiked(widget.post.id);
    _isSaved = _storage.isPostSaved(widget.post.id);
    _isFollowing = _storage.isUserFollowed(widget.post.userId);
    setState(() {});
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

                      _buildOptionTile(Icons.save_alt, context.tr('save'), () {
                        Navigator.pop(context);
                        _toggleSave();
                      }),
                      _buildOptionTile(Icons.copy, context.tr('copy_link'), () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(context.tr('link_copied'))));
                      }),
                      _buildOptionTile(Icons.share, context.tr('share_to'), () {
                        Navigator.pop(context);
                        Share.share(
                            '${context.tr('check_out_post')} ${widget.post.username}!');
                      }),
                      _buildOptionTile(
                          Icons.notifications_off,
                          '${context.tr('turn_off_notifications')} ${widget.post.username}',
                              () => Navigator.pop(context)),
                      _buildOptionTile(Icons.hide_image, context.tr('hide_post'),
                              () => Navigator.pop(context)),
                      _buildOptionTile(Icons.flag, context.tr('report'),
                              () => Navigator.pop(context),
                          iconColor: Colors.red, textColor: Colors.red),
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
                      child: Icon(
                        commentsDisabled
                            ? Icons.chat_bubble
                            : Icons.chat_bubble_outline,
                        color: commentsDisabled
                            ? Colors.grey
                            : (isDark ? Colors.white : Colors.black),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () async {
                        await Share.share(
                            '${context.tr('check_out_post')} ${widget.post.username}!');
                        await _firestore
                            .collection('posts')
                            .doc(widget.post.id)
                            .update({'shareCount': FieldValue.increment(1)});
                      },
                      child: Icon(Icons.send,
                          color: isDark ? Colors.white : Colors.black,
                          size: 26),
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

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: commentsDisabled
                    ? Text(
                  context.tr('comments_turned_off'),
                  style:
                  TextStyle(color: Colors.grey[500], fontSize: 14),
                )
                    : GestureDetector(
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

              if (!hideShareCount && shareCount > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '$shareCount ${context.tr('shares')}',
                    style:
                    TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),

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