// ═══════════════════════════════════════════════════════════════════════════
//  NotificationService — In-app notifications writer.
//
//  Firestore schema (per-recipient subcollection):
//    users/{recipientUid}/notifications/{autoId}
//      - type: "like" | "comment" | "reply" | "follow" | "repost"
//      - fromUid, fromUsername, fromAvatar
//      - postId?, postThumbUrl?
//      - commentId?, commentText?
//      - createdAt: serverTimestamp
//      - read: bool
//
//  Har method:
//    1. currentUid resolve karta hai
//    2. Self-action skip (recipient == sender)
//    3. Sender ka username+avatar `users/{me}` se ya passed-in args se le
//    4. users/{recipient}/notifications mein doc add karta hai
//
//  Sab methods async hain par caller `await` karne ki pabandi nahi —
//  background mein fire-and-forget chal sakte hain.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  /// Resolve current user's display name + photo. Cached per process call.
  /// Returns (username, avatarUrl) — empty strings if not signed in.
  static Future<(String uid, String username, String avatar)?>
      _resolveSender() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    final uid = user.uid;

    // Auth user object pe display name / photoURL pehle dekho — yeh sabse fast hai.
    String username = user.displayName ?? '';
    String avatar = user.photoURL ?? '';

    // Agar Auth pe empty hai to Firestore users/{uid} se le aao.
    if (username.isEmpty || avatar.isEmpty) {
      try {
        final snap = await _db.collection('users').doc(uid).get();
        final data = snap.data();
        if (data != null) {
          if (username.isEmpty) {
            username =
                (data['username'] ?? data['displayName'] ?? '') as String;
          }
          if (avatar.isEmpty) {
            avatar = (data['photoUrl'] ?? data['photoURL'] ?? '') as String;
          }
        }
      } catch (e) {
        debugPrint('NotificationService: sender lookup failed: $e');
      }
    }
    return (uid, username, avatar);
  }

  /// Internal — recipient ki notifications subcollection mein doc add karo.
  /// Self-action (recipient == sender) skip.
  static Future<void> _add(
    String recipientUid,
    String fromUid,
    Map<String, dynamic> payload,
  ) async {
    if (recipientUid.isEmpty || fromUid.isEmpty) return;
    if (recipientUid == fromUid) return; // self-action skip
    try {
      await _db
          .collection('users')
          .doc(recipientUid)
          .collection('notifications')
          .add({
        ...payload,
        'fromUid': fromUid,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
    } catch (e) {
      debugPrint('NotificationService: write failed: $e');
    }
  }

  // ─── Public API ────────────────────────────────────────────────────────

  // Insta-style dedupe: per (sender, post, action) ek hi notification doc
  // rahega — like/unlike/like 100 bar karne pe spam nahi hota. Deterministic
  // doc id: `{type}_{fromUid}_{postId}`. Set+merge har baar createdAt refresh
  // karta hai taake list mein top par jaye aur `read=false` set ho jaye.
  static Future<void> _addDedupedPostAction({
    required String recipientUid,
    required String fromUid,
    required String type,
    required String postId,
    required String fromUsername,
    required String fromAvatar,
    String postThumbUrl = '',
  }) async {
    if (recipientUid.isEmpty || fromUid.isEmpty || postId.isEmpty) return;
    if (recipientUid == fromUid) return;
    try {
      await _db
          .collection('users')
          .doc(recipientUid)
          .collection('notifications')
          .doc('${type}_${fromUid}_$postId')
          .set({
        'type': type,
        'fromUid': fromUid,
        'fromUsername': fromUsername,
        'fromAvatar': fromAvatar,
        'postId': postId,
        'postThumbUrl': postThumbUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('NotificationService: $type write failed: $e');
    }
  }

  static Future<void> notifyLike({
    required String postOwnerUid,
    required String postId,
    String postThumbUrl = '',
  }) async {
    final sender = await _resolveSender();
    if (sender == null) return;
    await _addDedupedPostAction(
      recipientUid: postOwnerUid,
      fromUid: sender.$1,
      type: 'like',
      postId: postId,
      fromUsername: sender.$2,
      fromAvatar: sender.$3,
      postThumbUrl: postThumbUrl,
    );
  }

  // Favorite (save / bookmark) — same dedupe pattern.
  static Future<void> notifyFavorite({
    required String postOwnerUid,
    required String postId,
    String postThumbUrl = '',
  }) async {
    final sender = await _resolveSender();
    if (sender == null) return;
    await _addDedupedPostAction(
      recipientUid: postOwnerUid,
      fromUid: sender.$1,
      type: 'favorite',
      postId: postId,
      fromUsername: sender.$2,
      fromAvatar: sender.$3,
      postThumbUrl: postThumbUrl,
    );
  }

  static Future<void> notifyComment({
    required String postOwnerUid,
    required String postId,
    String postThumbUrl = '',
    required String commentId,
    required String commentText,
  }) async {
    final sender = await _resolveSender();
    if (sender == null) return;
    final preview = commentText.length > 80
        ? '${commentText.substring(0, 80)}…'
        : commentText;
    await _add(postOwnerUid, sender.$1, {
      'type': 'comment',
      'fromUsername': sender.$2,
      'fromAvatar': sender.$3,
      'postId': postId,
      'postThumbUrl': postThumbUrl,
      'commentId': commentId,
      'commentText': preview,
    });
  }

  static Future<void> notifyReply({
    required String commentOwnerUid,
    required String postId,
    String postThumbUrl = '',
    required String commentId,
    required String replyText,
  }) async {
    final sender = await _resolveSender();
    if (sender == null) return;
    final preview =
        replyText.length > 80 ? '${replyText.substring(0, 80)}…' : replyText;
    await _add(commentOwnerUid, sender.$1, {
      'type': 'reply',
      'fromUsername': sender.$2,
      'fromAvatar': sender.$3,
      'postId': postId,
      'postThumbUrl': postThumbUrl,
      'commentId': commentId,
      'commentText': preview,
    });
  }

  // Comment ko like karne par comment ke author ko bell-icon notification.
  // Sirf like add hone par bhejo — unlike par nahi (warna spam ho jayega).
  static Future<void> notifyCommentLike({
    required String commentOwnerUid,
    required String postId,
    String postThumbUrl = '',
    required String commentId,
    required String commentText,
  }) async {
    final sender = await _resolveSender();
    if (sender == null) return;
    final preview = commentText.length > 80
        ? '${commentText.substring(0, 80)}…'
        : commentText;
    await _add(commentOwnerUid, sender.$1, {
      'type': 'comment_like',
      'fromUsername': sender.$2,
      'fromAvatar': sender.$3,
      'postId': postId,
      'postThumbUrl': postThumbUrl,
      'commentId': commentId,
      'commentText': preview,
    });
  }

  // Dislike notification — same pattern, alag type.
  static Future<void> notifyCommentDislike({
    required String commentOwnerUid,
    required String postId,
    String postThumbUrl = '',
    required String commentId,
    required String commentText,
  }) async {
    final sender = await _resolveSender();
    if (sender == null) return;
    final preview = commentText.length > 80
        ? '${commentText.substring(0, 80)}…'
        : commentText;
    await _add(commentOwnerUid, sender.$1, {
      'type': 'comment_dislike',
      'fromUsername': sender.$2,
      'fromAvatar': sender.$3,
      'postId': postId,
      'postThumbUrl': postThumbUrl,
      'commentId': commentId,
      'commentText': preview,
    });
  }

  // Follow notifications instagram-style dedupe karte hain: ek sender ka
  // sirf ek doc rahega recipient ki subcollection mein (deterministic id
  // `follow_{fromUid}`). Bar bar follow/unfollow karne par naya row spam
  // nahi hota — bas `createdAt` refresh hota hai taake list mein top par
  // aa jaye aur `read=false` set ho jaye.
  static Future<void> notifyFollow({
    required String targetUid,
  }) async {
    final sender = await _resolveSender();
    if (sender == null) return;
    final fromUid = sender.$1;
    if (targetUid.isEmpty || fromUid.isEmpty) return;
    if (targetUid == fromUid) return;
    try {
      await _db
          .collection('users')
          .doc(targetUid)
          .collection('notifications')
          .doc('follow_$fromUid')
          .set({
        'type': 'follow',
        'fromUid': fromUid,
        'fromUsername': sender.$2,
        'fromAvatar': sender.$3,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('NotificationService: follow write failed: $e');
    }
  }

  // Story like notification — Insta-style dedupe per (sender, story).
  // Doc id: `story_like_{fromUid}_{storyId}` — ek sender ka ek story par ek
  // hi doc, like/unlike spam se bachata hai. removeStoryLike unlike par doc
  // delete kar deta hai.
  static Future<void> notifyStoryLike({
    required String storyOwnerUid,
    required String storyId,
    String storyThumbUrl = '',
  }) async {
    final sender = await _resolveSender();
    if (sender == null) return;
    final fromUid = sender.$1;
    if (storyOwnerUid.isEmpty || fromUid.isEmpty || storyId.isEmpty) return;
    if (storyOwnerUid == fromUid) return;
    try {
      await _db
          .collection('users')
          .doc(storyOwnerUid)
          .collection('notifications')
          .doc('story_like_${fromUid}_$storyId')
          .set({
        'type': 'story_like',
        'fromUid': fromUid,
        'fromUsername': sender.$2,
        'fromAvatar': sender.$3,
        'storyId': storyId,
        'storyThumbUrl': storyThumbUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('NotificationService: story_like write failed: $e');
    }
  }

  static Future<void> removeStoryLike({
    required String storyOwnerUid,
    required String storyId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final fromUid = user.uid;
    if (storyOwnerUid.isEmpty || storyId.isEmpty) return;
    if (storyOwnerUid == fromUid) return;
    try {
      await _db
          .collection('users')
          .doc(storyOwnerUid)
          .collection('notifications')
          .doc('story_like_${fromUid}_$storyId')
          .delete();
    } catch (e) {
      debugPrint('NotificationService: story_like remove failed: $e');
    }
  }

  static Future<void> notifyRepost({
    required String postOwnerUid,
    required String postId,
    String postThumbUrl = '',
  }) async {
    final sender = await _resolveSender();
    if (sender == null) return;
    await _addDedupedPostAction(
      recipientUid: postOwnerUid,
      fromUid: sender.$1,
      type: 'repost',
      postId: postId,
      fromUsername: sender.$2,
      fromAvatar: sender.$3,
      postThumbUrl: postThumbUrl,
    );
  }

  // ─── Un-toggle removers ───────────────────────────────────────────────
  // Jab user like/repost/favorite ko UNDO kare, hum notification doc bhi
  // hata dete hain. Dedupe ke saath milke is se ye guarantee milti hai:
  //   - User ne 100 bar like/unlike kiya → final state ke hisaab se
  //     EXACTLY 1 ya 0 notification banegi.
  //   - Badge count bhi same logic follow karega (1 ya 0).
  static Future<void> _removePostAction({
    required String recipientUid,
    required String type,
    required String postId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final fromUid = user.uid;
    if (recipientUid.isEmpty || postId.isEmpty) return;
    if (recipientUid == fromUid) return;
    try {
      await _db
          .collection('users')
          .doc(recipientUid)
          .collection('notifications')
          .doc('${type}_${fromUid}_$postId')
          .delete();
    } catch (e) {
      debugPrint('NotificationService: $type remove failed: $e');
    }
  }

  static Future<void> removeLike({
    required String postOwnerUid,
    required String postId,
  }) =>
      _removePostAction(
          recipientUid: postOwnerUid, type: 'like', postId: postId);

  static Future<void> removeFavorite({
    required String postOwnerUid,
    required String postId,
  }) =>
      _removePostAction(
          recipientUid: postOwnerUid, type: 'favorite', postId: postId);

  static Future<void> removeRepost({
    required String postOwnerUid,
    required String postId,
  }) =>
      _removePostAction(
          recipientUid: postOwnerUid, type: 'repost', postId: postId);

  // ─── Comment notification remover ─────────────────────────────────────
  // Jab user apna comment delete kare (ya post owner kisi ka comment delete
  // kare), recipient ki notifications subcollection se us commentId waali
  // notifications hata do — taake "ne comment kiya" wali pranali bhi saaf
  // ho jaye.
  static Future<void> removeCommentNotifications({
    required String recipientUid,
    required String commentId,
  }) async {
    if (recipientUid.isEmpty || commentId.isEmpty) return;
    try {
      final snap = await _db
          .collection('users')
          .doc(recipientUid)
          .collection('notifications')
          .where('commentId', isEqualTo: commentId)
          .limit(50)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('NotificationService: comment notif cleanup failed: $e');
    }
  }
}
