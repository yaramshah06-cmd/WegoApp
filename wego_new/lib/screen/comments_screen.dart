import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:wego_marriage/providers/settings_provider.dart';
import 'package:wego_marriage/screen/user_profile_screen.dart';
import 'package:wego_marriage/screen/xp_service.dart';
import 'package:wego_marriage/services/notification_service.dart';
import 'package:wego_marriage/widgets/latest_badge_chip.dart';
import 'app_localizations.dart';
import 'app_translations.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  final String postUsername;
  final String currentUserAvatar;
  final String currentUsername;

  const CommentsScreen({
    super.key,
    required this.postId,
    required this.postUsername,
    required this.currentUserAvatar,
    required this.currentUsername,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Translation state
  final Map<String, String> _translations = {};
  final Set<String> _showOriginal = {};

  // ── FIX 1: Optimistic overrides — ONLY store pending state here.
  // Key: commentId → true means "user just liked", false means "user just unliked".
  // These are cleared as soon as Firestore stream confirms the change.
  final Map<String, bool> _likedOverride = {};
  final Map<String, bool> _dislikedOverride = {};

  // ── FIX 2: Cache the last known Firestore docs so StreamBuilder
  // does NOT cause a full list rebuild on every optimistic setState.
  // We pass this to itemBuilder and only update it inside the stream.
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cachedDocs = [];

  // Post author UID — initState mein ek baar fetch karte hain. Iski zaroorat
  // long-press delete check ke liye hai: post ka maalik kisi ka bhi comment
  // delete kar sakta hai, baaki sirf apne comment delete kar sakte hain.
  String? _postOwnerUid;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _commentsRef =>
      _db.collection('posts').doc(widget.postId).collection('comments');

  DocumentReference<Map<String, dynamic>> get _postRef =>
      _db.collection('posts').doc(widget.postId);

  @override
  void initState() {
    super.initState();
    _loadPostOwner();
  }

  Future<void> _loadPostOwner() async {
    try {
      final snap = await _postRef.get();
      final data = snap.data();
      if (data != null && mounted) {
        setState(() {
          _postOwnerUid = (data['authorid'] ?? '') as String;
        });
      }
    } catch (_) {/* silent */}
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    final uid = _uid;
    if (text.isEmpty || uid == null) return;

    _commentController.clear();
    FocusScope.of(context).unfocus();
    setState(() {});

    final data = {
      'authorUid': uid,
      'username': widget.currentUsername,
      'avatarUrl': widget.currentUserAvatar,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'likedBy': <String>[],
      'dislikedBy': <String>[],
      'parentId': null,
    };

    final newDoc = await _commentsRef.add(data);
    await _postRef.set(
      {'commentsCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
    await XPService.addXP(uid, XPAction.commentKarna);

    try {
      final postSnap = await _postRef.get();
      final postData = postSnap.data();
      if (postData != null) {
        final ownerUid = (postData['authorid'] ?? '') as String;
        // ✅ Prefer the dedicated poster URL — for video posts `imageUrl` is
        //    the raw .mp4 and won't render as an Image.network in the
        //    notifications list (used to show a camera placeholder).
        final thumb = ((postData['thumbnailUrl'] as String?)?.isNotEmpty == true
            ? postData['thumbnailUrl'] as String
            : (postData['imageUrl'] ?? '') as String);
        if (ownerUid.isNotEmpty) {
          NotificationService.notifyComment(
            postOwnerUid: ownerUid,
            postId: widget.postId,
            postThumbUrl: thumb,
            commentId: newDoc.id,
            commentText: text,
          );
        }
      }
    } catch (_) {}

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _postReply(String parentId, String text) async {
    final uid = _uid;
    if (text.trim().isEmpty || uid == null) return;

    final data = {
      'authorUid': uid,
      'username': widget.currentUsername,
      'avatarUrl': widget.currentUserAvatar,
      'text': text.trim(),
      'timestamp': FieldValue.serverTimestamp(),
      'likedBy': <String>[],
      'dislikedBy': <String>[],
      'parentId': parentId,
    };

    final newDoc = await _commentsRef.add(data);
    await _postRef.set(
      {'commentsCount': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
    await XPService.addXP(uid, XPAction.commentKarna);

    try {
      final parentSnap = await _commentsRef.doc(parentId).get();
      final parentData = parentSnap.data();
      if (parentData != null) {
        final parentAuthorUid = (parentData['authorUid'] ?? '') as String;
        if (parentAuthorUid.isNotEmpty) {
          String thumb = '';
          try {
            final postSnap = await _postRef.get();
            final pd = postSnap.data();
            thumb = ((pd?['thumbnailUrl'] as String?)?.isNotEmpty == true
                ? pd!['thumbnailUrl'] as String
                : (pd?['imageUrl'] ?? '') as String);
          } catch (_) {}
          NotificationService.notifyReply(
            commentOwnerUid: parentAuthorUid,
            postId: widget.postId,
            postThumbUrl: thumb,
            commentId: newDoc.id,
            replyText: text.trim(),
          );
        }
      }
    } catch (_) {}
  }

  // ── FIX 3: Pass RAW Firestore lists here, NOT the optimistically-modified ones.
  // Previously the caller was passing the already-overridden lists, which caused
  // FieldValue.arrayRemove/arrayUnion to operate on wrong data.
  Future<void> _toggleLikeComment(
      String commentId,
      List<String> rawLikedBy,   // straight from Firestore doc
      List<String> rawDislikedBy, // straight from Firestore doc
      ) async {
    final uid = _uid;
    if (uid == null) return;

    final isLiked = rawLikedBy.contains(uid);
    final isDisliked = rawDislikedBy.contains(uid);
    final willBeLiked = !isLiked;

    // Optimistic UI update
    setState(() {
      _likedOverride[commentId] = willBeLiked;
      // If user is liking and was previously disliking, remove dislike visually
      if (willBeLiked && isDisliked) _dislikedOverride[commentId] = false;
    });

    final updates = <String, dynamic>{};
    updates['likedBy'] = isLiked
        ? FieldValue.arrayRemove([uid])
        : FieldValue.arrayUnion([uid]);
    if (!isLiked && isDisliked) {
      updates['dislikedBy'] = FieldValue.arrayRemove([uid]);
    }

    try {
      await _commentsRef.doc(commentId).update(updates);
      if (willBeLiked) {
        unawaited(_notifyCommentAuthor(commentId, isLike: true));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _likedOverride.remove(commentId);
          _dislikedOverride.remove(commentId);
        });
      }
      debugPrint('comment like toggle failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Like error: $e')));
    }
  }

  Future<void> _toggleDislikeComment(
      String commentId,
      List<String> rawLikedBy,   // straight from Firestore doc
      List<String> rawDislikedBy, // straight from Firestore doc
      ) async {
    final uid = _uid;
    if (uid == null) return;

    final isLiked = rawLikedBy.contains(uid);
    final isDisliked = rawDislikedBy.contains(uid);
    final willBeDisliked = !isDisliked;

    setState(() {
      _dislikedOverride[commentId] = willBeDisliked;
      if (willBeDisliked && isLiked) _likedOverride[commentId] = false;
    });

    final updates = <String, dynamic>{};
    updates['dislikedBy'] = isDisliked
        ? FieldValue.arrayRemove([uid])
        : FieldValue.arrayUnion([uid]);
    if (!isDisliked && isLiked) {
      updates['likedBy'] = FieldValue.arrayRemove([uid]);
    }

    try {
      await _commentsRef.doc(commentId).update(updates);
      if (willBeDisliked) {
        unawaited(_notifyCommentAuthor(commentId, isLike: false));
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _likedOverride.remove(commentId);
          _dislikedOverride.remove(commentId);
        });
      }
      debugPrint('comment dislike toggle failed: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dislike error: $e')));
    }
  }

  Future<void> _notifyCommentAuthor(String commentId,
      {required bool isLike}) async {
    try {
      final snap = await _commentsRef.doc(commentId).get();
      final data = snap.data();
      if (data == null) return;
      final authorUid = (data['authorUid'] ?? '') as String;
      if (authorUid.isEmpty) return;
      // Apne comment par like/dislike ka notification nahi bhejna
      if (authorUid == _uid) return;
      final commentText = (data['text'] ?? '') as String;
      String thumb = '';
      try {
        final postSnap = await _postRef.get();
        final pd = postSnap.data();
        thumb = ((pd?['thumbnailUrl'] as String?)?.isNotEmpty == true
            ? pd!['thumbnailUrl'] as String
            : (pd?['imageUrl'] ?? '') as String);
      } catch (_) {}

      if (isLike) {
        NotificationService.notifyCommentLike(
          commentOwnerUid: authorUid,
          postId: widget.postId,
          postThumbUrl: thumb,
          commentId: commentId,
          commentText: commentText,
        );
      } else {
        NotificationService.notifyCommentDislike(
          commentOwnerUid: authorUid,
          postId: widget.postId,
          postThumbUrl: thumb,
          commentId: commentId,
          commentText: commentText,
        );
      }
    } catch (e) {
      debugPrint('notify comment author failed: $e');
    }
  }

  Future<void> _deleteComment(String commentId, {bool isReply = false}) async {
    // Children ke commentIds bhi collect kar lo — notifications cleanup mein
    // kaam aayenge (post owner ko gayi har "ne comment kiya" notif hatani hai).
    final childIds = <String>[];
    if (!isReply) {
      final children =
      await _commentsRef.where('parentId', isEqualTo: commentId).get();
      for (final c in children.docs) {
        childIds.add(c.id);
        await c.reference.delete();
      }
      await _postRef.set(
        {'commentsCount': FieldValue.increment(-(children.docs.length + 1))},
        SetOptions(merge: true),
      );
    } else {
      await _postRef.set(
        {'commentsCount': FieldValue.increment(-1)},
        SetOptions(merge: true),
      );
    }
    await _commentsRef.doc(commentId).delete();

    // Notifications cleanup — jo "comment" / "reply" / "comment_like" /
    // "comment_dislike" notifications post owner ke paas gayi thi unhe hata
    // do. Recipient hamesha post owner hai (parent reply ka notif comment
    // owner ko gaya tha, par usse abhi skip — production mein chaiye to alag
    // pass karein).
    final ownerUid = _postOwnerUid;
    if (ownerUid != null && ownerUid.isNotEmpty) {
      unawaited(NotificationService.removeCommentNotifications(
        recipientUid: ownerUid,
        commentId: commentId,
      ));
      for (final cid in childIds) {
        unawaited(NotificationService.removeCommentNotifications(
          recipientUid: ownerUid,
          commentId: cid,
        ));
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('comment_deleted'))),
    );
  }

  // Long-press par "Do you want to delete this comment?" popup. Post owner
  // har comment delete kar sakta hai, baaki sirf apna. Caller ko `canDelete`
  // pehle check karna chahiye — yeh function sirf confirmation sambhalta hai.
  Future<void> _confirmAndDeleteComment(
    String commentId, {
    bool isReply = false,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment'),
        content: const Text('Do you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _deleteComment(commentId, isReply: isReply);
  }

  // Helper — caller ek comment doc ke authorUid ke saath bulata hai.
  // Returns true agar current user is comment ko delete kar sakta hai:
  // (apna comment) OR (current user = post owner).
  bool _canDeleteComment(String commentAuthorUid) {
    final me = _uid;
    if (me == null) return false;
    if (commentAuthorUid == me) return true;
    if (_postOwnerUid != null && _postOwnerUid == me) return true;
    return false;
  }

  void _navigateToProfile(String userId, String username, String avatarUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: userId,
          username: username,
          avatarUrl: avatarUrl,
        ),
      ),
    );
  }

  void _showReplyDialog(String parentId, String parentUsername) {
    final replyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr('replying_to')} $parentUsername',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: replyController,
                  decoration: InputDecoration(
                    hintText: context.tr('write_reply'),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 3,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final text = replyController.text.trim();
                      if (text.isNotEmpty) {
                        // Pehle sheet band karo — await karne se sheet
                        // Firestore write complete hone tak ruki rehti thi.
                        FocusScope.of(context).unfocus();
                        Navigator.pop(context);
                        // Sheet close hone ke baad background mein reply post karo.
                        unawaited(_postReply(parentId, text));
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0095F6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(context.tr('reply')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _translateComment(String id, String original) {
    final settings = context.read<SettingsProvider>();
    final targetLanguage = settings.preferredLanguage;
    final langCode = _getLanguageCode(targetLanguage);
    final translated = AppTranslations.translate(original, langCode);

    setState(() {
      if (_showOriginal.contains(id)) {
        _showOriginal.remove(id);
      } else if (_translations.containsKey(id)) {
        _showOriginal.add(id);
      } else {
        _translations[id] = translated;
      }
    });

    if (!_showOriginal.contains(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('translated_to')} $targetLanguage'),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('showing_original'))),
      );
    }
  }

  bool _isTranslatedShown(String id) =>
      _translations.containsKey(id) && !_showOriginal.contains(id);

  String _getLanguageCode(String languageName) {
    const Map<String, String> codes = {
      'English': 'en',
      'Urdu': 'ur',
      'Hindi': 'hi',
      'Arabic': 'ar',
      'Korean': 'ko',
      'Chinese': 'zh',
      'Japanese': 'ja',
      'French': 'fr',
      'Spanish': 'es',
      'Turkish': 'tr',
      'German': 'de',
    };
    return codes[languageName] ?? 'en';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('comments'),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _commentsRef
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    _cachedDocs.isEmpty) {
                  // ── FIX 4: Only show loader on FIRST load.
                  // Subsequent stream updates (e.g. after like) must NOT
                  // show a spinner — that's what caused the list to vanish.
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasData) {
                  // Update cache — but do NOT call setState here.
                  // StreamBuilder already calls build when new data arrives.
                  _cachedDocs = snap.data!.docs;
                }

                if (_cachedDocs.isEmpty) {
                  return _buildEmptyState(isDark);
                }

                final tops = _cachedDocs
                    .where((d) => (d.data()['parentId']) == null)
                    .toList();

                final repliesByParent =
                <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
                for (final d in _cachedDocs) {
                  final p = d.data()['parentId'];
                  if (p is String && p.isNotEmpty) {
                    repliesByParent.putIfAbsent(p, () => []).add(d);
                  }
                }
                for (final list in repliesByParent.values) {
                  list.sort((a, b) {
                    final ta = a.data()['timestamp'];
                    final tb = b.data()['timestamp'];
                    final da =
                    ta is Timestamp ? ta.toDate() : DateTime.now();
                    final db =
                    tb is Timestamp ? tb.toDate() : DateTime.now();
                    return da.compareTo(db);
                  });
                }

                return ListView.builder(
                  controller: _scrollController,
                  // ── FIX 5: Keep alive so scroll position is preserved
                  // across optimistic setState calls.
                  key: const PageStorageKey('comments_list'),
                  itemCount: tops.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final doc = tops[index];
                    final replies = repliesByParent[doc.id] ?? const [];
                    return _buildCommentItem(doc, replies, isDark);
                  },
                );
              },
            ),
          ),
          _buildCommentInput(isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('no_comments_yet'),
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('be_first_comment'),
            style: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> replies,
      bool isDark,
      ) {
    final data = doc.data();
    final id = doc.id;
    final username = (data['username'] ?? '').toString();
    final avatarUrl = (data['avatarUrl'] ?? '').toString();
    final text = (data['text'] ?? '').toString();
    final authorUid = (data['authorUid'] ?? '').toString();
    final ts = data['timestamp'];
    final time = ts is Timestamp ? ts.toDate() : DateTime.now();

    // ── FIX 6: Always keep RAW Firestore lists separate.
    // These are passed to toggle functions so Firestore writes are correct.
    final rawLikedBy = List<String>.from(data['likedBy'] ?? const []);
    final rawDislikedBy = List<String>.from(data['dislikedBy'] ?? const []);

    // Apply optimistic overrides only for UI display
    final uidNow = _uid;
    final List<String> displayLikedBy = List<String>.from(rawLikedBy);
    final List<String> displayDislikedBy = List<String>.from(rawDislikedBy);

    if (uidNow != null) {
      final likeOv = _likedOverride[id];
      if (likeOv == true && !displayLikedBy.contains(uidNow)) {
        displayLikedBy.add(uidNow);
      }
      if (likeOv == false) displayLikedBy.remove(uidNow);

      final dislikeOv = _dislikedOverride[id];
      if (dislikeOv == true && !displayDislikedBy.contains(uidNow)) {
        displayDislikedBy.add(uidNow);
      }
      if (dislikeOv == false) displayDislikedBy.remove(uidNow);

      // Clear override once Firestore truth matches — next frame to avoid
      // calling setState during build.
      if (likeOv != null && likeOv == rawLikedBy.contains(uidNow)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _likedOverride.remove(id));
        });
      }
      if (dislikeOv != null &&
          dislikeOv == rawDislikedBy.contains(uidNow)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _dislikedOverride.remove(id));
        });
      }
    }

    final isLiked = uidNow != null && displayLikedBy.contains(uidNow);
    final isDisliked = uidNow != null && displayDislikedBy.contains(uidNow);

    final showTranslated = _isTranslatedShown(id);
    final shownText = showTranslated ? (_translations[id] ?? text) : text;

    final canDelete = _canDeleteComment(authorUid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          // Long-press par delete confirmation popup. Sirf authorize users
          // (apna comment ya post owner) ke liye trigger karte hain.
          onLongPress: canDelete
              ? () => _confirmAndDeleteComment(id)
              : null,
          behavior: HitTestBehavior.opaque,
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () =>
                    _navigateToProfile(authorUid, username, avatarUrl),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: avatarUrl.startsWith('http')
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl.startsWith('http')
                      ? null
                      : const Icon(Icons.person, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () => _navigateToProfile(
                                  authorUid, username, avatarUrl),
                              child: Text(
                                username,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                  isDark ? Colors.white : Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          if (authorUid.isNotEmpty &&
                              authorUid != _uid)
                            WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding:
                                    const EdgeInsets.only(left: 6),
                                child: LatestBadgeChip(
                                  uid: authorUid,
                                  size: 20,
                                ),
                              ),
                            ),
                          TextSpan(
                            text: ' $shownText',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      children: [
                        Text(
                          timeago.format(time),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        // ── FIX 7: Pass RAW lists to toggle functions
                        _buildActionButton(
                          icon: isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          count: displayLikedBy.length,
                          onTap: () => _toggleLikeComment(
                              id, rawLikedBy, rawDislikedBy),
                          isActive: isLiked,
                          activeColor: Colors.red,
                        ),
                        _buildActionButton(
                          icon: isDisliked
                              ? Icons.thumb_down
                              : Icons.thumb_down_alt_outlined,
                          count: displayDislikedBy.length,
                          onTap: () => _toggleDislikeComment(
                              id, rawLikedBy, rawDislikedBy),
                          isActive: isDisliked,
                          activeColor: Colors.blue,
                        ),
                        GestureDetector(
                          onTap: () => _showReplyDialog(id, username),
                          child: Text(
                            context.tr('reply'),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (text.length > 10)
                          GestureDetector(
                            onTap: () => _translateComment(id, text),
                            child: Text(
                              showTranslated
                                  ? context.tr('see_original')
                                  : context.tr('translate'),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        // 3-dot menu hata diya — ab long-press par delete
                        // popup aata hai (_confirmAndDeleteComment).
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        ),

        if (replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Column(
              children:
              replies.map((r) => _buildReplyItem(r, isDark)).toList(),
            ),
          ),

        const Divider(height: 1),
      ],
    );
  }

  Widget _buildReplyItem(
      QueryDocumentSnapshot<Map<String, dynamic>> doc, bool isDark) {
    final data = doc.data();
    final id = doc.id;
    final username = (data['username'] ?? '').toString();
    final avatarUrl = (data['avatarUrl'] ?? '').toString();
    final text = (data['text'] ?? '').toString();
    final authorUid = (data['authorUid'] ?? '').toString();
    final ts = data['timestamp'];
    final time = ts is Timestamp ? ts.toDate() : DateTime.now();

    // RAW lists for Firestore writes
    final rawLikedBy = List<String>.from(data['likedBy'] ?? const []);
    final rawDislikedBy = List<String>.from(data['dislikedBy'] ?? const []);

    // Display lists with optimistic override
    final uidNow = _uid;
    final List<String> displayLikedBy = List<String>.from(rawLikedBy);
    if (uidNow != null) {
      final likeOv = _likedOverride[id];
      if (likeOv == true && !displayLikedBy.contains(uidNow)) {
        displayLikedBy.add(uidNow);
      }
      if (likeOv == false) displayLikedBy.remove(uidNow);
      if (likeOv != null && likeOv == rawLikedBy.contains(uidNow)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _likedOverride.remove(id));
        });
      }
    }

    final isLiked = uidNow != null && displayLikedBy.contains(uidNow);
    final canDelete = _canDeleteComment(authorUid);

    return GestureDetector(
      // Reply par bhi long-press → delete confirm popup.
      onLongPress:
          canDelete ? () => _confirmAndDeleteComment(id, isReply: true) : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _navigateToProfile(authorUid, username, avatarUrl),
            child: CircleAvatar(
              radius: 14,
              backgroundImage: avatarUrl.startsWith('http')
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.startsWith('http')
                  ? null
                  : const Icon(Icons.person, size: 14),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => _navigateToProfile(
                              authorUid, username, avatarUrl),
                          child: Text(
                            username,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      if (authorUid.isNotEmpty && authorUid != _uid)
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: LatestBadgeChip(
                              uid: authorUid,
                              size: 18,
                            ),
                          ),
                        ),
                      TextSpan(
                        text: ' $text',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  children: [
                    Text(
                      timeago.format(time),
                      style: TextStyle(
                          color: Colors.grey[500], fontSize: 11),
                    ),
                    // Pass RAW lists to toggle
                    _buildActionButton(
                      icon:
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      count: displayLikedBy.length,
                      onTap: () => _toggleLikeComment(
                          id, rawLikedBy, rawDislikedBy),
                      isActive: isLiked,
                      activeColor: Colors.red,
                      isSmall: true,
                    ),
                    // Inline "delete" hata diya — ab long-press par
                    // delete confirmation popup aata hai.
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

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
    bool isSmall = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: isSmall ? 14 : 16,
            color: isActive ? activeColor : Colors.grey[600],
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isSmall ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.currentUserAvatar.startsWith('http')
                  ? NetworkImage(widget.currentUserAvatar)
                  : null,
              child: widget.currentUserAvatar.startsWith('http')
                  ? null
                  : const Icon(Icons.person, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: context.tr('add_comment'),
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _postComment(),
              ),
            ),
            GestureDetector(
              onTap: _postComment,
              child: Text(
                context.tr('post_comment'),
                style: TextStyle(
                  color: _commentController.text.trim().isNotEmpty
                      ? const Color(0xFF0095F6)
                      : Colors.grey[400],
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}