import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wego_marriage/widgets/level_badge.dart';
import 'app_localizations.dart';
import 'app_translations.dart';
import 'chat_screen.dart';
import 'post_detail_view.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String username;
  final String avatarUrl;

  const UserProfileScreen({
    super.key,
    required this.userId,
    required this.username,
    required this.avatarUrl,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _isFollowing = false;
  bool _isFollowLoading = false;

  Map<String, dynamic> _userData = {};
  List<Map<String, dynamic>> _userPosts = [];
  int _followersCount = 0;
  int _followingCount = 0;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  String get _targetUserId =>
      widget.userId.isNotEmpty ? widget.userId : widget.username;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _fetchUserData(),
        _fetchUserPosts(),
        _checkFollowStatus(),
      ]);
    } catch (e) {
      debugPrint('Error loading data: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchUserData() async {
    try {
      DocumentSnapshot doc;

      if (widget.userId.isNotEmpty) {
        doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();

        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>;

          final followersSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('followers')
              .get();
          final followingSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .collection('following')
              .get();

          if (mounted) {
            setState(() {
              _userData = {...data, 'id': doc.id};
              _followersCount = followersSnap.docs.length;
              _followingCount = followingSnap.docs.length;
            });
          }
          return;
        }
      }

      // Fallback: search by username
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: widget.username)
          .limit(1)
          .get();

      if (snap.docs.isNotEmpty) {
        final d = snap.docs.first;
        final data = d.data();

        final followersSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(d.id)
            .collection('followers')
            .get();
        final followingSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(d.id)
            .collection('following')
            .get();

        if (mounted) {
          setState(() {
            _userData = {...data, 'id': d.id};
            _followersCount = followersSnap.docs.length;
            _followingCount = followingSnap.docs.length;
          });
        }
      }
    } catch (e) {
      debugPrint('Fetch user data error: $e');
    }
  }

  Future<void> _fetchUserPosts() async {
    try {
      final targetId =
      widget.userId.isNotEmpty ? widget.userId : widget.username;

      final snap = await FirebaseFirestore.instance
          .collection('post')
          .where('userId', isEqualTo: targetId)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .get();

      if (!mounted) return;

      if (snap.docs.isEmpty) {
        // Fallback: search by username
        final snap2 = await FirebaseFirestore.instance
            .collection('post')
            .where('username', isEqualTo: widget.username)
            .limit(30)
            .get();

        setState(() {
          _userPosts = snap2.docs
              .map((d) => {...d.data(), 'id': d.id})
              .toList();
        });
      } else {
        setState(() {
          _userPosts =
              snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
        });
      }
    } catch (e) {
      debugPrint('Fetch posts error: $e');
      // Retry without orderBy if index missing
      try {
        final snap = await FirebaseFirestore.instance
            .collection('post')
            .where('userId', isEqualTo: _targetUserId)
            .limit(30)
            .get();
        if (mounted) {
          setState(() {
            _userPosts =
                snap.docs.map((d) => {...d.data(), 'id': d.id}).toList();
          });
        }
      } catch (e2) {
        debugPrint('Fallback posts error: $e2');
      }
    }
  }

  Future<void> _checkFollowStatus() async {
    final currentUid = _currentUid;
    if (currentUid == null || _targetUserId.isEmpty) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_targetUserId)
          .collection('followers')
          .doc(currentUid)
          .get();

      if (mounted) setState(() => _isFollowing = doc.exists);
    } catch (e) {
      debugPrint('Follow status error: $e');
    }
  }

  Future<void> _toggleFollow() async {
    final currentUid = _currentUid;
    if (currentUid == null || _targetUserId.isEmpty) return;

    setState(() => _isFollowLoading = true);

    try {
      final targetFollowersRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_targetUserId)
          .collection('followers')
          .doc(currentUid);

      final myFollowingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('following')
          .doc(_targetUserId);

      if (_isFollowing) {
        await targetFollowersRef.delete();
        await myFollowingRef.delete();
        setState(() {
          _isFollowing = false;
          _followersCount = (_followersCount - 1).clamp(0, 999999);
        });
      } else {
        await targetFollowersRef.set({
          'uid': currentUid,
          'followedAt': FieldValue.serverTimestamp(),
        });
        await myFollowingRef.set({
          'uid': _targetUserId,
          'followedAt': FieldValue.serverTimestamp(),
        });
        setState(() {
          _isFollowing = true;
          _followersCount += 1;
        });
      }
    } catch (e) {
      debugPrint('Toggle follow error: $e');
    }

    if (mounted) setState(() => _isFollowLoading = false);
  }

  void _navigateToChat() {
    final photoUrl = (_userData['photoUrl'] as String? ?? '').isNotEmpty
        ? _userData['photoUrl'] as String
        : widget.avatarUrl;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          username: widget.username,
          avatarUrl: photoUrl,
        ),
      ),
    );
  }

  void _navigateToPostDetail(int index) {
    final imageUrls =
    _userPosts.map((p) => p['imageUrl'] as String? ?? '').toList();
    final photoUrl = (_userData['photoUrl'] as String? ?? '').isNotEmpty
        ? _userData['photoUrl'] as String
        : widget.avatarUrl;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostDetailView(
          imageUrls: imageUrls,
          initialIndex: index,
          username: widget.username,
          avatarUrl: photoUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF4A6CF7);
    final accentPink = const Color(0xFFDD2A7B);
    final textColor = isDark ? Colors.white : Colors.black87;

    final displayName = (_userData['name'] as String? ??
        _userData['displayName'] as String? ??
        _userData['fullName'] as String? ??
        widget.username)
        .trim();
    final displayUsername =
    (_userData['username'] as String? ?? widget.username).trim();
    final photoUrl = (_userData['photoUrl'] as String? ?? '').isNotEmpty
        ? _userData['photoUrl'] as String
        : widget.avatarUrl;
    final bio = _userData['bio'] as String? ?? '';
    final postsCount = _userPosts.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: primaryColor, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          displayUsername,
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: textColor, size: 28),
            onPressed: () {},
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF4A6CF7)))
          : RefreshIndicator(
        onRefresh: _loadAllData,
        color: primaryColor,
        child: ListView(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          children: [
            const SizedBox(height: 20),

            // Profile avatar
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 125,
                    height: 125,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [primaryColor, accentPink],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? theme.scaffoldBackgroundColor
                            : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: photoUrl.isNotEmpty
                            ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              color: Colors.grey[300],
                              child: const Center(
                                  child:
                                  CircularProgressIndicator(
                                      strokeWidth: 2)),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: Icon(Icons.person,
                                color: primaryColor, size: 60),
                          ),
                        )
                            : Container(
                          color: Colors.grey[300],
                          child: Icon(Icons.person,
                              color: primaryColor, size: 60),
                        ),
                      ),
                    ),
                  ),
                  // Online indicator
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3DDC84),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 3),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 🏅 Realtime Level Badge — profile pic ke neeche
            const SizedBox(height: 10),
            Center(
              child: LevelBadge(
                uid: widget.userId.isNotEmpty
                    ? widget.userId
                    : widget.username,
                size: LevelBadgeSize.large,
              ),
            ),

            const SizedBox(height: 12),

            // Name
            Center(
              child: Text(
                displayName,
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                '@${displayUsername.toLowerCase().replaceAll(' ', '_')}',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            // Bio
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  bio,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor.withOpacity(0.7),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Follow / Message buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                      _isFollowLoading ? null : _toggleFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isFollowing
                            ? (isDark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.black.withOpacity(0.05))
                            : primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isFollowLoading
                          ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white))
                          : Text(
                        // ✅ Translated
                        _isFollowing
                            ? context.tr('unfollow')
                            : context.tr('follow'),
                        style: TextStyle(
                          color: _isFollowing
                              ? textColor
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _navigateToChat,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                            color: primaryColor.withOpacity(0.5),
                            width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        context.tr('message'), // ✅ Translated
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Stats section
            _buildStatsSection(context, postsCount),

            const SizedBox(height: 32),

            // Posts grid
            _buildPostsSection(isDark, textColor),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context, int postsCount) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    String formatCount(int n) {
      if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
      if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
      return n.toString();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.05)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12, width: 0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
              context,
              context.tr('posts'),       // ✅ Translated
              formatCount(postsCount),
              textColor,
              subTextColor),
          _buildStatItem(
              context,
              context.tr('followers'),   // ✅ Translated
              formatCount(_followersCount),
              textColor,
              subTextColor),
          _buildStatItem(
              context,
              context.tr('following'),   // ✅ Translated
              formatCount(_followingCount),
              textColor,
              subTextColor),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value,
      Color textColor, Color subTextColor) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: subTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildPostsSection(bool isDark, Color textColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.tr('posts'), // ✅ Translated
                style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              Icon(Icons.grid_view_rounded,
                  color: textColor.withOpacity(0.5), size: 20),
            ],
          ),
          const SizedBox(height: 16),
          if (_userPosts.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Text(
                  context.tr('no_posts_yet'), // ✅ Translated
                  style: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[600],
                      fontSize: 14),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _userPosts.length,
              itemBuilder: (context, index) {
                final post = _userPosts[index];
                final imageUrl = post['imageUrl'] as String? ?? '';
                return GestureDetector(
                  onTap: () => _navigateToPostDetail(index),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: imageUrl.isNotEmpty
                          ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: Colors.grey[200],
                            child: const Center(
                                child: CircularProgressIndicator(
                                    strokeWidth: 2)),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image,
                              color: Colors.grey),
                        ),
                      )
                          : Container(
                        color: isDark
                            ? Colors.grey[800]
                            : Colors.grey[200],
                        child: Center(
                          child: Text(
                            post['caption'] as String? ?? '',
                            maxLines: 3,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? Colors.white70
                                    : Colors.black54),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}