// ═══════════════════════════════════════════════════════════════════════════
//  PostViewerScreen — Instagram Reels-style single-post viewer
//  Khulta hai jab user chat mein shared-post card par tap kare.
//
//  - Firestore se post fetch karke full-screen render karta hai
//  - Right side mein vertical action column (like / comment / share)
//  - Top bar mein author avatar + @username + timestamp
//  - Video posts auto-play (looped, mute by default — tap to unmute)
//  - Like state Firestore `posts/{id}.likedBy` array se sync hota hai
// ═══════════════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:wego_marriage/screen/comments_screen.dart';
import 'package:wego_marriage/screen/home_feed_screen.dart' show Post;
import 'package:wego_marriage/screen/user_profile_screen.dart';
import 'package:wego_marriage/services/notification_service.dart';
import 'package:wego_marriage/widgets/post_shared_sheet.dart';

class PostViewerScreen extends StatefulWidget {
  final String postId;

  /// Optional fallback metadata (jab Firestore se fetch hone tak preview dikha sakein)
  final String? fallbackAuthorUsername;
  final String? fallbackAuthorAvatar;
  final String? fallbackThumbUrl;
  final bool fallbackIsVideo;

  const PostViewerScreen({
    super.key,
    required this.postId,
    this.fallbackAuthorUsername,
    this.fallbackAuthorAvatar,
    this.fallbackThumbUrl,
    this.fallbackIsVideo = false,
  });

  @override
  State<PostViewerScreen> createState() => _PostViewerScreenState();
}

class _PostViewerScreenState extends State<PostViewerScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _muted = true;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _ensureVideo(Post post) {
    if (!post.isVideo) return;
    final url = post.videoUrl;
    if (url == null || url.isEmpty) return;
    if (_videoController != null) return;

    _videoController = VideoPlayerController.networkUrl(Uri.parse(url))
      ..setLooping(true)
      ..setVolume(0)
      ..initialize().then((_) {
        if (!mounted) return;
        setState(() => _videoReady = true);
        _videoController?.play();
      }).catchError((_) {});
  }

  Future<void> _toggleLike(Post post, bool currentlyLiked) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _firestore.collection('posts').doc(post.id);
    if (currentlyLiked) {
      await ref.update({
        'likesCount': FieldValue.increment(-1),
        'likedBy': FieldValue.arrayRemove([uid]),
      });
    } else {
      await ref.update({
        'likesCount': FieldValue.increment(1),
        'likedBy': FieldValue.arrayUnion([uid]),
      });
      // Notify post author (self-action skip inside service)
      NotificationService.notifyLike(
        postOwnerUid: post.userId,
        postId: post.id,
        postThumbUrl: post.thumbnailUrl,
      );
    }
  }

  void _openComments(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommentsScreen(
          postId: post.id,
          postUsername: post.username,
          currentUserAvatar: _auth.currentUser?.photoURL ?? '',
          currentUsername: _auth.currentUser?.displayName ?? 'You',
        ),
      ),
    );
  }

  Future<void> _toggleFollow(String targetUid, bool currentlyFollowing) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid == targetUid) return;
    final myFollowing = _firestore
        .collection('users')
        .doc(uid)
        .collection('following')
        .doc(targetUid);
    final theirFollowers = _firestore
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(uid);
    if (currentlyFollowing) {
      await myFollowing.delete();
      await theirFollowers.delete();
    } else {
      await myFollowing.set({'followedAt': FieldValue.serverTimestamp()});
      await theirFollowers.set({'followedAt': FieldValue.serverTimestamp()});
      NotificationService.notifyFollow(targetUid: targetUid);
    }
  }

  void _openAuthorProfile(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: post.userId,
          username: post.username,
          avatarUrl: post.avatarUrl,
        ),
      ),
    );
  }

  Future<void> _toggleRepost(Post post, bool currentlyReposted) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _firestore.collection('posts').doc(post.id);
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
      NotificationService.notifyRepost(
        postOwnerUid: post.userId,
        postId: post.id,
        postThumbUrl: post.thumbnailUrl,
      );
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

  void _openShareSheet(Post post) {
    // Shared bottom sheet — feed/fullscreen jaisa hi. Followers, copy link,
    // WA/FB/More, author-gated download — sab ek hi widget mein.
    PostSharedSheet.show(context, post: post);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore.collection('posts').doc(widget.postId).snapshots(),
        builder: (context, snap) {
          // Loading state — fallback thumbnail dikhao agar di gayi ho
          if (!snap.hasData) {
            return _LoadingState(
              fallbackThumb: widget.fallbackThumbUrl,
              fallbackAuthor: widget.fallbackAuthorUsername,
              fallbackAvatar: widget.fallbackAuthorAvatar,
            );
          }
          final doc = snap.data!;
          if (!doc.exists || doc.data() == null) {
            return const _UnavailableState();
          }

          final post = Post.fromFirestore(doc.id, doc.data()!);
          final data = doc.data()!;
          final likedBy = List<String>.from(data['likedBy'] ?? const []);
          final uid = _auth.currentUser?.uid;
          final isLiked = uid != null && likedBy.contains(uid);
          final likesCount = (data['likesCount'] ?? 0) as int;
          final commentsCount = (data['commentsCount'] ?? 0) as int;
          final repostedBy = List<String>.from(data['repostedBy'] ?? const []);
          final isReposted = uid != null && repostedBy.contains(uid);
          final repostsCount = (data['repostsCount'] ?? 0) as int;

          _ensureVideo(post);

          return SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── Media (background) ──────────────────────────────────
                Positioned.fill(
                  child: _MediaView(
                    post: post,
                    videoController: _videoController,
                    videoReady: _videoReady,
                    muted: _muted,
                    onToggleMute: () {
                      setState(() => _muted = !_muted);
                      _videoController?.setVolume(_muted ? 0 : 1);
                    },
                  ),
                ),

                // ── Top bar ─────────────────────────────────────────────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _TopBar(
                    post: post,
                    currentUid: uid,
                    onAuthorTap: () => _openAuthorProfile(post),
                    onToggleFollow: (following) =>
                        _toggleFollow(post.userId, following),
                  ),
                ),

                // ── Right vertical action column ────────────────────────
                Positioned(
                  right: 8,
                  bottom: 90,
                  child: _ActionColumn(
                    isLiked: isLiked,
                    likesCount: likesCount,
                    commentsCount: commentsCount,
                    hideLikes: post.hideLikes,
                    commentsDisabled: post.commentsDisabled,
                    isReposted: isReposted,
                    repostsCount: repostsCount,
                    onLike: () => _toggleLike(post, isLiked),
                    onComment: post.commentsDisabled
                        ? null
                        : () => _openComments(post),
                    onRepost: () => _toggleRepost(post, isReposted),
                    onShare: () => _openShareSheet(post),
                  ),
                ),

                // ── Bottom caption overlay ──────────────────────────────
                if (post.caption.isNotEmpty)
                  Positioned(
                    left: 12,
                    right: 80,
                    bottom: 16,
                    child: _CaptionOverlay(
                        username: post.username, caption: post.caption),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Media (image or video) ──────────────────────────────────────────────
class _MediaView extends StatelessWidget {
  final Post post;
  final VideoPlayerController? videoController;
  final bool videoReady;
  final bool muted;
  final VoidCallback onToggleMute;

  const _MediaView({
    required this.post,
    required this.videoController,
    required this.videoReady,
    required this.muted,
    required this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    if (post.isVideo) {
      if (!videoReady || videoController == null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            if (post.postImageUrl.isNotEmpty)
              Image.network(post.postImageUrl, fit: BoxFit.contain),
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ],
        );
      }
      return GestureDetector(
        onTap: onToggleMute,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: videoController!.value.aspectRatio,
                child: VideoPlayer(videoController!),
              ),
            ),
            // Mute icon (small, top-right of video area)
            Positioned(
              bottom: 100,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      );
    }
    // Image post
    if (post.postImageUrl.isEmpty) {
      return const Center(
        child: Text('No media', style: TextStyle(color: Colors.white70)),
      );
    }
    return Image.network(
      post.postImageUrl,
      fit: BoxFit.contain,
      loadingBuilder: (c, child, p) => p == null
          ? child
          : const Center(child: CircularProgressIndicator(color: Colors.white)),
      errorBuilder: (_, __, ___) => const Center(
        child: Icon(Icons.broken_image, color: Colors.white54, size: 40),
      ),
    );
  }
}

// ─── Top bar (back + author info + follow) ───────────────────────────────
class _TopBar extends StatelessWidget {
  final Post post;
  final String? currentUid;
  final VoidCallback onAuthorTap;
  // following = "abhi follow kar raha hu" — toggle karne ke baad ka new state
  final void Function(bool currentlyFollowing) onToggleFollow;

  const _TopBar({
    required this.post,
    required this.currentUid,
    required this.onAuthorTap,
    required this.onToggleFollow,
  });

  @override
  Widget build(BuildContext context) {
    final isSelf = currentUid != null && currentUid == post.userId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.55), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          // Author row — tap to open UserProfileScreen
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onAuthorTap,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey.shade800,
                    backgroundImage: post.avatarUrl.isNotEmpty
                        ? NetworkImage(post.avatarUrl)
                        : null,
                    child: post.avatarUrl.isEmpty
                        ? const Icon(Icons.person,
                            size: 16, color: Colors.white70)
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '@${post.username}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (post.time.isNotEmpty)
                          Text(
                            post.time,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Follow button (apni post par nahi dikhayega)
          if (!isSelf && currentUid != null)
            _FollowButton(
              currentUid: currentUid!,
              targetUid: post.userId,
              onToggle: onToggleFollow,
            ),
        ],
      ),
    );
  }
}

// ─── Live Follow button — Firestore stream se state aata hai ─────────────
class _FollowButton extends StatelessWidget {
  final String currentUid;
  final String targetUid;
  final void Function(bool currentlyFollowing) onToggle;

  const _FollowButton({
    required this.currentUid,
    required this.targetUid,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUid)
        .collection('following')
        .doc(targetUid);

    return StreamBuilder<DocumentSnapshot>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        final isFollowing = snap.hasData && snap.data!.exists;
        return Padding(
          padding: const EdgeInsets.only(left: 8, right: 4),
          child: ElevatedButton(
            onPressed: () => onToggle(isFollowing),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isFollowing ? Colors.white24 : Colors.white,
              foregroundColor:
                  isFollowing ? Colors.white : Colors.black,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 0),
              minimumSize: const Size(0, 32),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: isFollowing ? Colors.white54 : Colors.transparent,
                  width: 1,
                ),
              ),
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Right-side vertical action column (Reels-style) ─────────────────────
class _ActionColumn extends StatelessWidget {
  final bool isLiked;
  final int likesCount;
  final int commentsCount;
  final bool hideLikes;
  final bool commentsDisabled;
  final bool isReposted;
  final int repostsCount;
  final VoidCallback onLike;
  final VoidCallback? onComment;
  final VoidCallback onRepost;
  final VoidCallback onShare;

  const _ActionColumn({
    required this.isLiked,
    required this.likesCount,
    required this.commentsCount,
    required this.hideLikes,
    required this.commentsDisabled,
    required this.isReposted,
    required this.repostsCount,
    required this.onLike,
    required this.onComment,
    required this.onRepost,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_border,
          color: isLiked ? Colors.redAccent : Colors.white,
          label: hideLikes ? '' : '$likesCount',
          onTap: onLike,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: commentsDisabled
              ? Icons.chat_bubble_outline
              : Icons.mode_comment_outlined,
          color: Colors.white,
          label: commentsDisabled ? '' : '$commentsCount',
          onTap: onComment,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.repeat,
          color: isReposted ? Colors.greenAccent : Colors.white,
          label: repostsCount > 0 ? '$repostsCount' : '',
          onTap: onRepost,
        ),
        const SizedBox(height: 18),
        _ActionButton(
          icon: Icons.send_outlined,
          color: Colors.white,
          label: '',
          onTap: onShare,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback? onTap;
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkResponse(
          onTap: onTap,
          radius: 26,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(blurRadius: 4, color: Colors.black)],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Caption overlay (bottom-left) ───────────────────────────────────────
class _CaptionOverlay extends StatefulWidget {
  final String username;
  final String caption;
  const _CaptionOverlay({required this.username, required this.caption});

  @override
  State<_CaptionOverlay> createState() => _CaptionOverlayState();
}

class _CaptionOverlayState extends State<_CaptionOverlay> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.bottomLeft,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(12),
          ),
          child: RichText(
            maxLines: _expanded ? 20 : 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style:
                  const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
              children: [
                TextSpan(
                  text: '@${widget.username}  ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: widget.caption),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Loading state (with optional fallback thumb) ────────────────────────
class _LoadingState extends StatelessWidget {
  final String? fallbackThumb;
  final String? fallbackAuthor;
  final String? fallbackAvatar;
  const _LoadingState({
    required this.fallbackThumb,
    required this.fallbackAuthor,
    required this.fallbackAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (fallbackThumb != null && fallbackThumb!.isNotEmpty)
          Image.network(fallbackThumb!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox()),
        const Center(child: CircularProgressIndicator(color: Colors.white)),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  if (fallbackAuthor != null) ...[
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey.shade800,
                      backgroundImage: (fallbackAvatar ?? '').isNotEmpty
                          ? NetworkImage(fallbackAvatar!)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Text('@${fallbackAuthor!}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Post not available (deleted / missing) ──────────────────────────────
class _UnavailableState extends StatelessWidget {
  const _UnavailableState();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.info_outline, color: Colors.white54, size: 48),
                SizedBox(height: 12),
                Text('Post unavailable',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
                SizedBox(height: 4),
                Text('Yeh post delete ya unavailable hai.',
                    style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
