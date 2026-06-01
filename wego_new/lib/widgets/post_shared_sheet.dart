// ═══════════════════════════════════════════════════════════════════════════
//  post_shared_sheet.dart
//
//  Shared bottom sheet jo home feed, fullscreen video viewer, aur
//  post viewer — teeno jagah se kholi jati hai. Pehle teen alag-alag
//  copies thi (har screen me apna _showShareSheet/_openShareSheet) —
//  ab single source of truth.
//
//  Features:
//    • In-app "Send to" — followers + jin se chat kiya hai (parallel
//      fetch). Tap pe MsgType.sharedPost card us user ke chat me jata
//      hai (chat_screen ka _SharedPostCardBubble isko render karta hai).
//    • Copy link — `https://wegomarriage.app/post/{id}` clipboard pe.
//    • WhatsApp — thumbnail + caption.
//    • Facebook — thumbnail + caption.
//    • More — system share sheet (share_plus).
//    • Download — author ne `allowDownloads=true` set kiya ho to gallery
//      me save (Gal.putImage / Gal.putVideo). Warna disabled snackbar.
//
//  Usage:
//      PostSharedSheet.show(context, post: post);
//
//  Caller ko apni screen ke video controller pause/resume khud handle
//  karna hota hai (`.whenComplete` ka shortcut nahi rakha taaki callers
//  apne states cleanly manage karein).
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:wego_marriage/providers/chat_provider.dart';
import 'package:wego_marriage/screen/app_localizations.dart';
import 'package:wego_marriage/screen/chat_screen.dart'
    show FirebaseChatService, MsgStatus, MsgType;
import 'package:wego_marriage/screen/home_feed_screen.dart' show Post;

class PostSharedSheet extends StatefulWidget {
  final Post post;

  const PostSharedSheet({super.key, required this.post});

  /// Convenience entry — har caller bas yeh static call kare.
  static Future<void> show(BuildContext context, {required Post post}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => PostSharedSheet(post: post),
    );
  }

  @override
  State<PostSharedSheet> createState() => _PostSharedSheetState();
}

class _PostSharedSheetState extends State<PostSharedSheet> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Targets future cache — sheet open hone par ek hi baar fetch ho.
  late final Future<List<_ShareTarget>> _targetsFuture;

  // Loading dialog handle — download ke dauran show/hide karne ke liye.
  bool _loadingDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _targetsFuture = _loadShareTargets();
  }

  // ─── Followers + messaged users (parallel) ──────────────────────────────
  Future<List<_ShareTarget>> _loadShareTargets() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final Map<String, _ShareTarget> byUid = {};

    // 1. Followed users — parallel fan-out
    try {
      final followingSnap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();

      final docsToFetch =
          followingSnap.docs.where((d) => d.id != uid).toList();
      final userDocs = await Future.wait(
        docsToFetch.map((d) => _firestore.collection('users').doc(d.id).get()),
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
      debugPrint('PostSharedSheet: following load error $e');
    }

    // 2. Messaged users — fallback for chats without follow
    if (!mounted) return byUid.values.toList();
    try {
      final chatProvider = context.read<ChatProvider>();
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

  // ─── Helpers ────────────────────────────────────────────────────────────
  String _buildPostLink() =>
      'https://wegomarriage.app/post/${widget.post.id}';

  String _autoCaption() {
    // Auto-generated external-share text. context.tr() async event handlers
    // se safely call hota hai jab tak `mounted` true ho — but yahan hum
    // sheet build pe ek baar bana lete hain.
    return '${context.tr('check_out_post')} @${widget.post.username}\n${_buildPostLink()}';
  }

  Future<void> _incrementShareCount() async {
    try {
      await _firestore
          .collection('posts')
          .doc(widget.post.id)
          .update({'shareCount': FieldValue.increment(1)});
    } catch (_) {}
  }

  void _showLoadingDialog() {
    if (_loadingDialogOpen || !mounted) return;
    _loadingDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF4A6CF7)),
      ),
    );
  }

  void _hideLoadingDialog() {
    if (!_loadingDialogOpen) return;
    _loadingDialogOpen = false;
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  // ─── In-app share (chat card) ───────────────────────────────────────────
  Future<void> _sendPostInChat(_ShareTarget target) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _toast('Not signed in');
      return;
    }
    if (target.userId.isEmpty) {
      _toast('Invalid recipient');
      return;
    }

    final svc = FirebaseChatService();
    final chatRoomId = svc.getChatRoomId(uid, target.userId);

    final now = DateTime.now();
    final h = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final timeString =
        '$h:${now.minute.toString().padLeft(2, '0')} $amPm';

    final isVideo = widget.post.isVideo;
    final thumbUrl = widget.post.postImageUrl;

    // Instagram-style shared-post card — media reference bhejte hain,
    // poora video/hi-res image nahi. Receiver tap pe PostViewerScreen
    // me jata hai. Chat_screen ka _SharedPostCardBubble ye fields padhta hai.
    final msgData = <String, dynamic>{
      'senderId': uid,
      'senderName': _auth.currentUser?.displayName ?? '',
      'receiverId': target.userId,
      'text': '',
      'type': MsgType.sharedPost.index,
      'imageUrl': thumbUrl, // backward-compat quick preview
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
      'sharedPostId': widget.post.id,
      'sharedPostAuthor': widget.post.username,
      'sharedPostAuthorAvatar': widget.post.avatarUrl,
      'sharedPostThumbUrl': thumbUrl,
      'sharedPostIsVideo': isVideo,
    };

    try {
      await svc.sendMessage(chatRoomId: chatRoomId, messageData: msgData);
      await _incrementShareCount();
      _toast('Sent to ${target.username}');
    } catch (e) {
      _toast('Send failed: $e');
    }
  }

  // ─── External share helpers ─────────────────────────────────────────────
  Future<void> _copyLink(String linkCopiedMsg) async {
    await Clipboard.setData(ClipboardData(text: _buildPostLink()));
    _toast(linkCopiedMsg);
  }

  Future<void> _shareToWhatsApp(String caption) async {
    // Fast path — no thumbnail pre-download. Direct WhatsApp scheme text +
    // link ke saath foran open. Agar WhatsApp installed nahi to system
    // share sheet ko fallback de do, dono hi 0ms me khulte hain.
    try {
      final waUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(caption)}');
      if (await canLaunchUrl(waUri)) {
        final ok = await launchUrl(waUri, mode: LaunchMode.externalApplication);
        if (ok) {
          unawaited(_incrementShareCount());
          return;
        }
      }
      await Share.share(caption);
      unawaited(_incrementShareCount());
    } catch (e) {
      _toast('Share failed: $e');
    }
  }

  Future<void> _shareToFacebook(String caption) async {
    // Fast path — Facebook native scheme Android par rarely text accept
    // karta hai, isliye system share sheet hi de do, thumbnail attach
    // karne ka wait nahi karte (perceived lag se bachne ke liye).
    try {
      await Share.share(caption, subject: 'Wego Post');
      unawaited(_incrementShareCount());
    } catch (e) {
      _toast('Share failed: $e');
    }
  }

  Future<void> _shareViaMore(String caption) async {
    // Fast path — system share sheet text + link ke saath foran khol do.
    // Thumbnail attach karne ke liye pehle download wait NA karein (slow
    // network par yeh 2-5 sec lag jata tha). User ke perspective me sheet
    // ab 0ms me khulta hai. Share count fire-and-forget chalega.
    try {
      await Share.share(caption, subject: 'Wego Post');
      unawaited(_incrementShareCount());
    } catch (e) {
      _toast('Share failed: $e');
    }
  }

  // ─── Download — author opt-in (allowDownloads) ──────────────────────────
  Future<void> _downloadToGallery() async {
    // Pre-resolve localized strings — context.tr() listen:true Provider.of
    // hai jo async gap ke baad fail kar sakta hai. Sab kuch ek baar yahan
    // capture kar lo.
    final disabledMsg = context.tr('share_download_disabled');
    final failedMsg = context.tr('share_download_failed');
    final savedMsg = context.tr('share_download_saved');

    // Author ne explicit allow nahi kiya — toast aur exit.
    if (!widget.post.allowDownloads) {
      _toast(disabledMsg);
      return;
    }

    // Android <13 par photos permission needed; gal khud bhi prompt karta hai
    // but defensive request kar lete hain (Android 11/12 me visible warning
    // se bachne ke liye).
    if (Platform.isAndroid) {
      final status = await Permission.photos.request();
      if (!status.isGranted) {
        final storage = await Permission.storage.request();
        if (!storage.isGranted) {
          _toast(failedMsg);
          return;
        }
      }
    }

    _showLoadingDialog();
    try {
      // Full media — image ke liye postImageUrl, video ke liye videoUrl
      // (warna fallback me postImageUrl, jisme purane posts ka mp4 URL ho
      // sakta hai).
      final isVideo = widget.post.isVideo;
      final mediaUrl = isVideo
          ? (widget.post.videoUrl ?? widget.post.postImageUrl)
          : widget.post.postImageUrl;

      if (mediaUrl.isEmpty) {
        _hideLoadingDialog();
        _toast(failedMsg);
        return;
      }

      final resp = await http
          .get(Uri.parse(mediaUrl))
          .timeout(const Duration(seconds: 60));
      if (resp.statusCode != 200) {
        _hideLoadingDialog();
        _toast(failedMsg);
        return;
      }

      final dir = await getTemporaryDirectory();
      final ext = isVideo ? '.mp4' : '.jpg';
      final filePath =
          '${dir.path}/wego_post_${widget.post.id}_${DateTime.now().millisecondsSinceEpoch}$ext';
      final file = File(filePath);
      await file.writeAsBytes(resp.bodyBytes);

      if (isVideo) {
        await Gal.putVideo(filePath);
      } else {
        await Gal.putImage(filePath);
      }

      _hideLoadingDialog();
      _toast(savedMsg);
    } catch (e) {
      _hideLoadingDialog();
      debugPrint('PostSharedSheet download failed: $e');
      _toast(failedMsg);
    }
  }

  // ─── UI ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final dividerColor = isDark ? Colors.grey[800] : Colors.grey[200];

    final caption = _autoCaption();
    final copyLinkLabel = context.tr('copy_link');
    final linkCopiedMsg = context.tr('link_copied');

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) {
        return SafeArea(
          child: Column(
            children: [
              // Grab handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 10, bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Send to',
                      style: TextStyle(
                        color: textColor,
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
                  future: _targetsFuture,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
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
                            style:
                                TextStyle(color: subColor, fontSize: 14),
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
                            backgroundColor:
                                isDark ? Colors.grey[700] : Colors.grey[300],
                            backgroundImage: t.avatarUrl.startsWith('http')
                                ? NetworkImage(t.avatarUrl)
                                : null,
                            child: t.avatarUrl.startsWith('http')
                                ? null
                                : Icon(Icons.person,
                                    size: 20,
                                    color:
                                        isDark ? Colors.white : Colors.grey),
                          ),
                          title: Text(
                            t.username,
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            t.source == 'following'
                                ? 'Following'
                                : 'From messages',
                            style: TextStyle(color: subColor, fontSize: 12),
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
                              Navigator.pop(context); // close sheet
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
              Divider(height: 1, color: dividerColor),
              // External row
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _ExternalIcon(
                      label: copyLinkLabel,
                      icon: Icons.link,
                      bgColor: Colors.grey,
                      textColor: textColor,
                      onTap: () async {
                        Navigator.pop(context);
                        await _copyLink(linkCopiedMsg);
                      },
                    ),
                    _ExternalIcon(
                      label: 'WhatsApp',
                      icon: Icons.chat,
                      bgColor: const Color(0xFF25D366),
                      textColor: textColor,
                      onTap: () async {
                        Navigator.pop(context);
                        await _shareToWhatsApp(caption);
                      },
                    ),
                    _ExternalIcon(
                      label: 'Facebook',
                      icon: Icons.facebook,
                      bgColor: const Color(0xFF1877F2),
                      textColor: textColor,
                      onTap: () async {
                        Navigator.pop(context);
                        await _shareToFacebook(caption);
                      },
                    ),
                    _ExternalIcon(
                      label: 'More',
                      icon: Icons.more_horiz,
                      bgColor: Colors.blueGrey,
                      textColor: textColor,
                      onTap: () async {
                        Navigator.pop(context);
                        await _shareViaMore(caption);
                      },
                    ),
                  ],
                ),
              ),
              // Download row — author opt-in
              Divider(height: 1, color: dividerColor),
              ListTile(
                leading: Icon(
                  widget.post.allowDownloads
                      ? Icons.download_rounded
                      : Icons.download_for_offline_outlined,
                  color: widget.post.allowDownloads
                      ? textColor
                      : subColor,
                ),
                title: Text(
                  context.tr('share_download'),
                  style: TextStyle(
                    color: widget.post.allowDownloads
                        ? textColor
                        : subColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: widget.post.allowDownloads
                    ? null
                    : Text(
                        context.tr('share_download_disabled'),
                        style: TextStyle(color: subColor, fontSize: 12),
                      ),
                onTap: () async {
                  Navigator.pop(context);
                  await _downloadToGallery();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ExternalIcon extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color textColor;
  final VoidCallback onTap;

  const _ExternalIcon({
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(color: textColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

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
