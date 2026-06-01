// ============================================================
// fullscreen_video_viewer.dart
//   Instagram Reels-style fullscreen video viewer.
//   • Video poori screen bhar leti hai.
//   • Single tap = play/pause toggle. Paused state pe play icon overlay.
//   • Right side overlay buttons: like, comment, share, repost, save —
//     sab Firestore transactions ke through real-time count update.
//   • Bottom: username + caption + Follow pill (FollowController shared).
//   • Share sheet: followers + messaged users live list (home feed wala
//     same `_loadShareTargets` pattern), tap par chat me Insta-style
//     shared post card jaata hai.
//   • Comment screen wahi CommentsScreen — sab like/dislike/reply
//     buttons us screen me already wired hain.
// ============================================================
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import 'package:wego_marriage/providers/chat_provider.dart';
import 'package:wego_marriage/services/follow_controller.dart';
import 'package:wego_marriage/services/local_storage_service.dart';
import 'package:wego_marriage/services/notification_service.dart';

import 'chat_screen.dart' show FirebaseChatService, MsgStatus, MsgType;
import 'comments_screen.dart';
import 'home_feed_screen.dart' show Post;
import 'xp_service.dart';

class FullscreenVideoViewer extends StatefulWidget {
  final String postId;
  final Post initialPost;

  const FullscreenVideoViewer({
    super.key,
    required this.postId,
    required this.initialPost,
  });

  @override
  State<FullscreenVideoViewer> createState() => _FullscreenVideoViewerState();
}

class _FullscreenVideoViewerState extends State<FullscreenVideoViewer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _initError = false;
  bool _showPauseOverlay = false;

  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final LocalStorageService _storage = LocalStorageService();

  // Shared follow notifier — home feed jasa pattern, follow karte hi
  // sab jagah pill foran flip ho jata hai.
  ValueNotifier<bool>? _followNotifier;

  @override
  void initState() {
    super.initState();
    _initVideo();
    _followNotifier =
        FollowController.instance.notifier(widget.initialPost.userId);
    _followNotifier!.addListener(_onFollowChange);
    FollowController.instance.watch(widget.initialPost.userId);
  }

  void _onFollowChange() {
    if (mounted) setState(() {});
  }

  Future<void> _initVideo() async {
    final url = widget.initialPost.videoUrl ?? '';
    if (url.isEmpty) {
      setState(() => _initError = true);
      return;
    }
    final c = VideoPlayerController.networkUrl(Uri.parse(url));
    _controller = c;
    try {
      await c.initialize();
      if (!mounted) {
        c.dispose();
        return;
      }
      await c.setLooping(true);
      await c.play();
      setState(() => _ready = true);
    } catch (e) {
      debugPrint('Fullscreen video init failed: $e');
      if (mounted) setState(() => _initError = true);
    }
  }

  @override
  void dispose() {
    _followNotifier?.removeListener(_onFollowChange);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final c = _controller;
    if (c == null || !_ready) return;
    setState(() {
      if (c.value.isPlaying) {
        c.pause();
        _showPauseOverlay = true;
      } else {
        c.play();
        _showPauseOverlay = false;
      }
    });
  }

  bool get _isFollowing => _followNotifier?.value ?? false;
  bool get _isOwnPost => _auth.currentUser?.uid == widget.initialPost.userId;

  Future<void> _toggleFollow() async {
    final wasFollowing = _isFollowing;
    final newState =
        await FollowController.instance.toggle(widget.initialPost.userId);
    if (!mounted) return;
    if (newState != wasFollowing) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newState
                ? 'Following @${widget.initialPost.username}'
                : 'Unfollowed @${widget.initialPost.username}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Action handlers (transactions — race-safe, never negative) ───

  Future<void> _toggleLike(bool currentlyLiked) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _storage.toggleLike(widget.postId, !currentlyLiked);
    final ref = _firestore.collection('posts').doc(widget.postId);
    bool added = false;
    bool removed = false;
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() ?? {};
        final arr = List<String>.from(data['likedBy'] ?? const []);
        final cur = (data['likesCount'] is num)
            ? (data['likesCount'] as num).toInt()
            : 0;
        final has = arr.contains(uid);
        if (!currentlyLiked && !has) {
          tx.update(ref, {
            'likesCount': cur + 1,
            'likedBy': FieldValue.arrayUnion([uid]),
          });
          added = true;
        } else if (currentlyLiked && has) {
          tx.update(ref, {
            'likesCount': cur > 0 ? cur - 1 : 0,
            'likedBy': FieldValue.arrayRemove([uid]),
          });
          removed = true;
        }
      });
    } catch (e) {
      debugPrint('Fullscreen like failed: $e');
      return;
    }
    if (added) {
      await XPService.addXP(uid, XPAction.likeKarna);
      unawaited(NotificationService.notifyLike(
        postOwnerUid: widget.initialPost.userId,
        postId: widget.postId,
        postThumbUrl: widget.initialPost.thumbnailUrl,
      ));
    } else if (removed) {
      unawaited(NotificationService.removeLike(
        postOwnerUid: widget.initialPost.userId,
        postId: widget.postId,
      ));
    }
  }

  Future<void> _toggleSave(bool currentlySaved) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _storage.toggleSaved(widget.postId, !currentlySaved);
    final ref = _firestore.collection('posts').doc(widget.postId);
    bool added = false;
    bool removed = false;
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() ?? {};
        final arr = List<String>.from(data['savedBy'] ?? const []);
        final cur = (data['savedCount'] is num)
            ? (data['savedCount'] as num).toInt()
            : 0;
        final has = arr.contains(uid);
        if (!currentlySaved && !has) {
          tx.update(ref, {
            'savedCount': cur + 1,
            'savedBy': FieldValue.arrayUnion([uid]),
          });
          added = true;
        } else if (currentlySaved && has) {
          tx.update(ref, {
            'savedCount': cur > 0 ? cur - 1 : 0,
            'savedBy': FieldValue.arrayRemove([uid]),
          });
          removed = true;
        }
      });
    } catch (e) {
      debugPrint('Fullscreen save failed: $e');
      return;
    }
    if (added) {
      unawaited(NotificationService.notifyFavorite(
        postOwnerUid: widget.initialPost.userId,
        postId: widget.postId,
        postThumbUrl: widget.initialPost.thumbnailUrl,
      ));
    } else if (removed) {
      unawaited(NotificationService.removeFavorite(
        postOwnerUid: widget.initialPost.userId,
        postId: widget.postId,
      ));
    }
  }

  Future<void> _toggleRepost(bool currentlyReposted) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _firestore.collection('posts').doc(widget.postId);
    bool added = false;
    bool removed = false;
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        if (!snap.exists) return;
        final data = snap.data() ?? {};
        final arr = List<String>.from(data['repostedBy'] ?? const []);
        final cur = (data['repostsCount'] is num)
            ? (data['repostsCount'] as num).toInt()
            : 0;
        final has = arr.contains(uid);
        if (!has) {
          tx.update(ref, {
            'repostsCount': cur + 1,
            'repostedBy': FieldValue.arrayUnion([uid]),
          });
          added = true;
        } else {
          tx.update(ref, {
            'repostsCount': cur > 0 ? cur - 1 : 0,
            'repostedBy': FieldValue.arrayRemove([uid]),
          });
          removed = true;
        }
      });
    } catch (e) {
      debugPrint('Fullscreen repost failed: $e');
      return;
    }
    if (added) {
      unawaited(NotificationService.notifyRepost(
        postOwnerUid: widget.initialPost.userId,
        postId: widget.postId,
        postThumbUrl: widget.initialPost.thumbnailUrl,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reposted'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } else if (removed) {
      unawaited(NotificationService.removeRepost(
        postOwnerUid: widget.initialPost.userId,
        postId: widget.postId,
      ));
    }
  }

  Future<void> _incrementShareCount() async {
    try {
      await _firestore
          .collection('posts')
          .doc(widget.postId)
          .update({'shareCount': FieldValue.increment(1)});
    } catch (_) {}
  }

  void _openComments() {
    // Video pause kar ke phir push — taa ke comments screen ke peeche
    // background me video chal kar bandwidth na khaye.
    _controller?.pause();
    setState(() => _showPauseOverlay = true);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CommentsScreen(
          postId: widget.postId,
          postUsername: widget.initialPost.username,
          currentUserAvatar: _auth.currentUser?.photoURL ?? '',
          currentUsername: _auth.currentUser?.displayName ??
              widget.initialPost.username,
        ),
      ),
    ).then((_) {
      if (!mounted) return;
      _controller?.play();
      setState(() => _showPauseOverlay = false);
    });
  }

  // ── Share targets — followers + messaged users (parallel fetch) ──
  Future<List<_ShareTarget>> _loadShareTargets() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    // Provider lookup pehle kar lo, await ke baad context use karne se
    // analyzer warn karta hai aur theoretically widget unmount ho sakta hai.
    final chatProvider = context.read<ChatProvider>();

    final Map<String, _ShareTarget> byUid = {};

    // Followed users — parallel fan-out.
    try {
      final followingSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();
      final docsToFetch =
          followingSnap.docs.where((d) => d.id != uid).toList();
      final userDocs = await Future.wait(
        docsToFetch
            .map((d) => _firestore.collection('users').doc(d.id).get()),
      );
      for (final userDoc in userDocs) {
        if (!userDoc.exists) continue;
        final data = userDoc.data() ?? {};
        byUid[userDoc.id] = _ShareTarget(
          userId: userDoc.id,
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
      debugPrint('Fullscreen share: following load error $e');
    }

    // Messaged users — anyone we chat with but don't follow.
    try {
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

  Future<void> _sendPostInChat(_ShareTarget target) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not signed in')),
        );
      }
      return;
    }
    if (target.userId.isEmpty) return;

    final svc = FirebaseChatService();
    final chatRoomId = svc.getChatRoomId(uid, target.userId);

    final now = DateTime.now();
    final h = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final timeString =
        '$h:${now.minute.toString().padLeft(2, '0')} $amPm';

    final thumbUrl = widget.initialPost.postImageUrl;
    final msgData = <String, dynamic>{
      'senderId': uid,
      'senderName': _auth.currentUser?.displayName ?? '',
      'receiverId': target.userId,
      'text': '',
      'type': MsgType.sharedPost.index,
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
      // Shared-post card metadata — receiver chat me Insta-style card
      // dekhega, tap par PostViewerScreen me full post open hoga (chat
      // screen ka existing _SharedPostCardBubble flow).
      'sharedPostId': widget.postId,
      'sharedPostAuthor': widget.initialPost.username,
      'sharedPostAuthorAvatar': widget.initialPost.avatarUrl,
      'sharedPostThumbUrl': thumbUrl,
      'sharedPostIsVideo': widget.initialPost.isVideo,
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

  void _openShareSheet() {
    _controller?.pause();
    setState(() => _showPauseOverlay = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
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
                      color: Colors.grey[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Text(
                          'Send to',
                          style: TextStyle(
                            color: Colors.white,
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
                              color: Color(0xFF4A6CF7),
                            ),
                          );
                        }
                        final targets = snap.data ?? [];
                        if (targets.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                'No followed or messaged users yet',
                                style: TextStyle(
                                  color: Colors.grey[400],
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
                                backgroundColor: Colors.grey[700],
                                backgroundImage: t.avatarUrl.startsWith('http')
                                    ? NetworkImage(t.avatarUrl)
                                    : null,
                                child: t.avatarUrl.startsWith('http')
                                    ? null
                                    : const Icon(Icons.person,
                                        size: 20, color: Colors.white),
                              ),
                              title: Text(
                                t.username,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                t.source == 'following'
                                    ? 'Following'
                                    : 'From messages',
                                style: TextStyle(
                                  color: Colors.grey[400],
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
                                  await _sendPostInChat(t);
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
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      if (!mounted) return;
      _controller?.play();
      setState(() => _showPauseOverlay = false);
    });
  }

  // ── Helpers ───────────────────────────────────────────────────
  int _safeCount(dynamic stored, List arr) {
    final s = stored is num ? stored.toInt() : 0;
    return s < 0 ? arr.length : (s > arr.length ? s : arr.length);
  }

  String _formatCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            _firestore.collection('posts').doc(widget.postId).snapshots(),
        builder: (context, snap) {
          final data = (snap.hasData && snap.data!.exists)
              ? (snap.data!.data() ?? const <String, dynamic>{})
              : const <String, dynamic>{};

          final uid = _auth.currentUser?.uid;
          final likedBy = List<String>.from(data['likedBy'] ?? const []);
          final savedBy = List<String>.from(data['savedBy'] ?? const []);
          final repostedBy =
              List<String>.from(data['repostedBy'] ?? const []);

          final isLiked = uid != null && likedBy.contains(uid);
          final isSaved = uid != null && savedBy.contains(uid);
          final isReposted = uid != null && repostedBy.contains(uid);

          final hideLikes = (data['hideLikeCount'] as bool?) ?? false;
          final hideShareCount =
              (data['hideShareCount'] as bool?) ?? false;
          final commentsDisabled =
              (data['turnOffCommenting'] as bool?) ?? false;

          final likesCount =
              hideLikes ? 0 : _safeCount(data['likesCount'], likedBy);
          final commentsCount = (data['commentsCount'] is num)
              ? (data['commentsCount'] as num).toInt()
              : 0;
          final shareCount = (data['shareCount'] is num)
              ? (data['shareCount'] as num).toInt()
              : 0;
          final repostsCount = _safeCount(data['repostsCount'], repostedBy);
          final savedCount = _safeCount(data['savedCount'], savedBy);

          final username = (data['username'] as String?) ??
              widget.initialPost.username;
          final caption = (data['caption'] as String?) ??
              (data['text'] as String?) ??
              widget.initialPost.caption;
          final avatarUrl =
              (data['photoUrl'] as String?) ?? widget.initialPost.avatarUrl;

          return SafeArea(
            child: Stack(
              children: [
                // ─ Video ─
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _togglePlayPause,
                    child: Center(child: _buildVideoBody()),
                  ),
                ),

                // Pause-state play icon
                if (_showPauseOverlay && _ready)
                  const IgnorePointer(
                    child: Center(
                      child: Icon(Icons.play_arrow,
                          color: Colors.white70, size: 80),
                    ),
                  ),

                // ─ Top close ─
                Positioned(
                  top: 4,
                  left: 4,
                  right: 4,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),

                // ─ Right action rail ─
                Positioned(
                  right: 8,
                  bottom: 110,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionButton(
                        icon: isLiked
                            ? Icons.favorite
                            : Icons.favorite_border,
                        color: isLiked ? Colors.red : Colors.white,
                        label: hideLikes ? '' : _formatCount(likesCount),
                        onTap: () => _toggleLike(isLiked),
                      ),
                      const SizedBox(height: 18),
                      _actionButton(
                        icon: commentsDisabled
                            ? Icons.chat_bubble
                            : Icons.chat_bubble_outline,
                        color: Colors.white,
                        label: _formatCount(commentsCount),
                        onTap: commentsDisabled
                            ? () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Comments turned off'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            : _openComments,
                      ),
                      const SizedBox(height: 18),
                      _actionButton(
                        icon: Icons.send,
                        color: Colors.white,
                        label: hideShareCount
                            ? ''
                            : _formatCount(shareCount),
                        onTap: _openShareSheet,
                      ),
                      const SizedBox(height: 18),
                      _actionButton(
                        icon: Icons.repeat,
                        color: isReposted
                            ? Colors.greenAccent
                            : Colors.white,
                        label: _formatCount(repostsCount),
                        onTap: () => _toggleRepost(isReposted),
                      ),
                      const SizedBox(height: 18),
                      _actionButton(
                        icon: isSaved
                            ? Icons.bookmark
                            : Icons.bookmark_border,
                        color: isSaved
                            ? const Color(0xFF0095F6)
                            : Colors.white,
                        label: _formatCount(savedCount),
                        onTap: () => _toggleSave(isSaved),
                      ),
                    ],
                  ),
                ),

                // ─ Bottom — avatar + username + Follow pill + caption ─
                Positioned(
                  left: 12,
                  right: 80,
                  bottom: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.grey[800],
                            backgroundImage: avatarUrl.startsWith('http')
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl.startsWith('http')
                                ? null
                                : const Icon(Icons.person,
                                    color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '@$username',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                shadows: [
                                  Shadow(
                                      color: Colors.black87, blurRadius: 6),
                                ],
                              ),
                            ),
                          ),
                          // Follow pill — apni post pe hide.
                          if (!_isOwnPost) ...[
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _toggleFollow,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _isFollowing
                                      ? Colors.white24
                                      : const Color(0xFF0095F6),
                                  borderRadius: BorderRadius.circular(6),
                                  border: _isFollowing
                                      ? Border.all(
                                          color: Colors.white54, width: 1)
                                      : null,
                                ),
                                child: Text(
                                  _isFollowing ? 'Following' : 'Follow',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (caption.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          caption,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            shadows: [
                              Shadow(color: Colors.black87, blurRadius: 6),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoBody() {
    if (_initError) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white54, size: 56),
            SizedBox(height: 10),
            Text('Video load nahi ho saki',
                style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }
    if (!_ready || _controller == null) {
      return const CircularProgressIndicator(color: Colors.white);
    }
    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio == 0
          ? 9 / 16
          : _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 28,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            if (label.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Colors.black87, blurRadius: 4),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Share sheet model — mirrors home_feed_screen._ShareTarget ───
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
