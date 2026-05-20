// ═══════════════════════════════════════════════════════════════════════════
//  UserPostsFeedScreen — Instagram-style scrollable feed of a single user's
//  posts. Opens from "My Profile" (or another user's profile) when a grid
//  tile is tapped; auto-scrolls to the tapped post.
//
//  Visual parity with home feed: same `InstagramStylePostCard` widget is
//  reused so like/comment/share/repost/poll/etc. all behave identically.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:wego_marriage/screen/home_feed_screen.dart'
    show InstagramStylePostCard, Post;
import 'app_localizations.dart';

class UserPostsFeedScreen extends StatefulWidget {
  /// Whose posts to show. Use `FirebaseAuth.instance.currentUser!.uid` for
  /// "my own" feed, or another user's uid for a profile-visit case.
  final String userId;

  /// Document id of the post the user tapped — feed auto-scrolls to it.
  /// If null or not found, starts from the top.
  final String? initialPostId;

  /// Title shown in the app bar (e.g. "Posts" / "@username").
  final String title;

  const UserPostsFeedScreen({
    super.key,
    required this.userId,
    this.initialPostId,
    this.title = 'Posts',
  });

  @override
  State<UserPostsFeedScreen> createState() => _UserPostsFeedScreenState();
}

class _UserPostsFeedScreenState extends State<UserPostsFeedScreen> {
  final _firestore = FirebaseFirestore.instance;
  // Roughly one full Insta-style card height. Used for jumpTo offset before
  // we have real laid-out heights. Cards are variable but ~520-620px on a
  // typical phone — 560 is a reasonable approximation that lands within the
  // target post's vertical bounds.
  static const double _approxCardHeight = 560.0;

  late final ScrollController _scrollController;
  List<Post> _posts = [];
  bool _isLoading = true;
  String? _error;
  bool _didJumpToInitial = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      // Note: no `orderBy` server-side — `where('authorid', ==)` + `orderBy`
      // needs a composite index. Hum client-side sort kar lete hain (user ke
      // posts limited honge, isliye sasti operation hai).
      final snap = await _firestore
          .collection('posts')
          .where('authorid', isEqualTo: widget.userId)
          .get();

      final posts = snap.docs.map((d) {
        final data = d.data();
        return Post.fromFirestore(d.id, data);
      }).toList();

      // Newest first.
      posts.sort((a, b) {
        // `time` is a "5m / 3h / 2d" formatted string in Post — sort by
        // raw timestamp from the doc instead.
        final aTs = snap.docs.firstWhere((x) => x.id == a.id).data()['timestamp'];
        final bTs = snap.docs.firstWhere((x) => x.id == b.id).data()['timestamp'];
        final aDt = (aTs is Timestamp) ? aTs.toDate() : DateTime(1970);
        final bDt = (bTs is Timestamp) ? bTs.toDate() : DateTime(1970);
        return bDt.compareTo(aDt);
      });

      if (!mounted) return;
      setState(() {
        _posts = posts;
        _isLoading = false;
      });
      _scheduleInitialJump();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _scheduleInitialJump() {
    if (_didJumpToInitial) return;
    final id = widget.initialPostId;
    if (id == null) return;
    final idx = _posts.indexWhere((p) => p.id == id);
    if (idx <= 0) return; // already at top, or not found
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = idx * _approxCardHeight;
      _scrollController.jumpTo(
        target.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
      _didJumpToInitial = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF121212) : Colors.white;
    final fg = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0.5,
        iconTheme: IconThemeData(color: fg),
        title: Text(
          widget.title,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      body: _buildBody(fg),
    );
  }

  Widget _buildBody(Color fg) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error: $_error',
              style: TextStyle(color: fg), textAlign: TextAlign.center),
        ),
      );
    }
    if (_posts.isEmpty) {
      return Center(
        child: Text(context.tr('no_posts_yet'),
            style: TextStyle(color: fg.withValues(alpha: 0.7), fontSize: 15)),
      );
    }
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => InstagramStylePostCard(post: _posts[i]),
    );
  }
}
