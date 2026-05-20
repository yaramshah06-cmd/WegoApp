// ═══════════════════════════════════════════════════════════════════════════
//  NotificationsScreen — In-app notifications feed.
//
//  Live stream from users/{me}/notifications ordered by createdAt desc.
//  Avatar tap → UserProfileScreen. Thumb tap → PostViewerScreen.
//  Auto mark-read after 1s on open.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:wego_marriage/screen/post_viewer_screen.dart';
import 'package:wego_marriage/screen/user_profile_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  Timer? _markReadTimer;

  String? get _uid => _auth.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    // 1s delay — user pehle unread state dekh le, phir auto-clear.
    _markReadTimer = Timer(const Duration(seconds: 1), _markAllRead);
  }

  @override
  void dispose() {
    _markReadTimer?.cancel();
    super.dispose();
  }

  Future<void> _markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      final snap = await _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .limit(200)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.update(d.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {
      // silent
    }
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${diff.inDays ~/ 7}w';
  }

  String _actionText(String type, String commentText) {
    switch (type) {
      case 'like':
        return 'ne aap ki post like ki';
      case 'comment':
        return 'ne comment kiya: "$commentText"';
      case 'reply':
        return 'ne aap ki comment ka reply diya: "$commentText"';
      case 'follow':
        return 'ne aap ko follow kiya';
      case 'repost':
        return 'ne aap ki post repost ki';
      case 'comment_like':
        return 'ne aap ki comment like ki: "$commentText"';
      case 'comment_dislike':
        return 'ne aap ki comment dislike ki: "$commentText"';
      default:
        return 'ne kuch kiya';
    }
  }

  void _openProfile(String uid, String username, String avatar) {
    if (uid.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: uid,
          username: username,
          avatarUrl: avatar,
        ),
      ),
    );
  }

  void _openPost(String postId,
      {String? thumb, String? author, String? avatar, bool isVideo = false}) {
    if (postId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostViewerScreen(
          postId: postId,
          fallbackThumbUrl: thumb,
          fallbackAuthorUsername: author,
          fallbackAuthorAvatar: avatar,
          fallbackIsVideo: isVideo,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (uid != null)
            IconButton(
              tooltip: 'Mark all read',
              icon: const Icon(Icons.done_all),
              onPressed: _markAllRead,
            ),
        ],
      ),
      body: uid == null
          ? const _SignedOutView()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db
                  .collection('users')
                  .doc(uid)
                  .collection('notifications')
                  .orderBy('createdAt', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Error loading notifications:\n${snap.error}',
                          textAlign: TextAlign.center),
                    ),
                  );
                }
                final docs = snap.data?.docs ?? const [];
                if (docs.isEmpty) return const _EmptyView();
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 70),
                  itemBuilder: (context, i) {
                    final d = docs[i].data();
                    final type = (d['type'] ?? '') as String;
                    final fromUid = (d['fromUid'] ?? '') as String;
                    final fromUsername =
                        (d['fromUsername'] ?? 'Someone') as String;
                    final fromAvatar = (d['fromAvatar'] ?? '') as String;
                    final postId = (d['postId'] ?? '') as String;
                    final postThumb = (d['postThumbUrl'] ?? '') as String;
                    final commentText = (d['commentText'] ?? '') as String;
                    final ts = d['createdAt'] as Timestamp?;
                    final isRead = (d['read'] as bool?) ?? false;

                    return Container(
                      color: isRead
                          ? null
                          : Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.06),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        leading: GestureDetector(
                          onTap: () =>
                              _openProfile(fromUid, fromUsername, fromAvatar),
                          child: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey.shade300,
                            backgroundImage: fromAvatar.isNotEmpty
                                ? NetworkImage(fromAvatar)
                                : null,
                            child: fromAvatar.isEmpty
                                ? const Icon(Icons.person,
                                    color: Colors.white70)
                                : null,
                          ),
                        ),
                        title: RichText(
                          text: TextSpan(
                            style: DefaultTextStyle.of(context).style.copyWith(
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                            children: [
                              TextSpan(
                                text: '@$fromUsername  ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
                              ),
                              TextSpan(
                                  text: _actionText(type, commentText),
                                  style:
                                      const TextStyle(color: Colors.black87)),
                            ],
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              Icon(_iconFor(type),
                                  size: 12, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(_timeAgo(ts),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600)),
                            ],
                          ),
                        ),
                        trailing: (type == 'follow' || postId.isEmpty)
                            ? null
                            : GestureDetector(
                                onTap: () => _openPost(
                                  postId,
                                  thumb: postThumb,
                                  author: fromUsername,
                                  avatar: fromAvatar,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: postThumb.isNotEmpty
                                        ? Image.network(postThumb,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Container(
                                                    color: Colors
                                                        .grey.shade200))
                                        : Container(
                                            color: Colors.grey.shade200,
                                            child: const Icon(
                                                Icons.image_outlined,
                                                color: Colors.black26,
                                                size: 20),
                                          ),
                                  ),
                                ),
                              ),
                        onTap: type == 'follow'
                            ? () => _openProfile(
                                fromUid, fromUsername, fromAvatar)
                            : (postId.isEmpty
                                ? null
                                : () => _openPost(
                                      postId,
                                      thumb: postThumb,
                                      author: fromUsername,
                                      avatar: fromAvatar,
                                    )),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'like':
        return Icons.favorite;
      case 'comment':
        return Icons.mode_comment_outlined;
      case 'reply':
        return Icons.reply;
      case 'follow':
        return Icons.person_add_alt_1;
      case 'repost':
        return Icons.repeat;
      case 'comment_like':
        return Icons.favorite;
      case 'comment_dislike':
        return Icons.thumb_down;
      default:
        return Icons.notifications;
    }
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('Koi notification nahi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Jab koi aap ki post like / comment kare, yahan dikhega.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _SignedOutView extends StatelessWidget {
  const _SignedOutView();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('Sign in to see notifications.'),
      ),
    );
  }
}
