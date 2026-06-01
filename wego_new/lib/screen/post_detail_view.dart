import 'package:flutter/material.dart';

import 'home_feed_screen.dart' show InstagramStylePostCard, Post;

/// Full-feature post detail / reels-style vertical scroller used from the
/// user profile (and reposts) grid. Each page renders the **same**
/// `InstagramStylePostCard` that the home feed uses — so likes, comments,
/// repost, save, share, follow, poll vote, hashtags etc. all work against
/// real Firestore data instead of the old hardcoded placeholder UI.
///
/// `postDocs` are the raw Firestore maps (with an `id` key already merged
/// in) — the same shape `_userPosts` / `_userReposts` already use in
/// `user_profile_screen.dart`.
class PostDetailView extends StatefulWidget {
  final List<Map<String, dynamic>> postDocs;
  final int initialIndex;
  // Header title — usually the profile owner's username. Just for the
  // AppBar; per-post username/avatar comes from each doc itself.
  final String headerTitle;

  const PostDetailView({
    super.key,
    required this.postDocs,
    required this.initialIndex,
    required this.headerTitle,
  });

  @override
  State<PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<PostDetailView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.headerTitle,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: widget.postDocs.isEmpty
          ? Center(
              child: Text(
                'No posts',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            )
          : PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: widget.postDocs.length,
              itemBuilder: (context, index) {
                final raw = widget.postDocs[index];
                final id = (raw['id'] as String?) ?? '';
                final post = Post.fromFirestore(id, raw);
                // Each page is scrollable on its own — caption + comments
                // preview etc. can overflow on small screens.
                return SingleChildScrollView(
                  child: InstagramStylePostCard(post: post),
                );
              },
            ),
    );
  }
}
