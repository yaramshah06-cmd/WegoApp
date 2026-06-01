import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:provider/provider.dart';
import 'package:wego_marriage/providers/story_provider.dart';
import 'package:wego_marriage/screen/chat_screen.dart';
import 'package:wego_marriage/screen/user_profile_screen.dart';
import 'package:wego_marriage/services/notification_service.dart';
import 'package:wego_marriage/widgets/latest_badge_chip.dart';
import 'app_localizations.dart';

class StoryScreen extends StatefulWidget {
  final int initialUserIndex;

  const StoryScreen({super.key, required this.initialUserIndex});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;
  bool _isLongPressing = false;

  final TextEditingController _replyCtrl = TextEditingController();
  final FocusNode _replyFocus = FocusNode();
  // RTDB ki direct instance ki ab zarurat nahi — reply
  // FirebaseChatService (chat_screen.dart) ke through bhejte hain, jisme
  // sendMessage + lastMessage update + message list refresh sab handled hai.
  bool _isSending = false;

  // Current story ka mera viewer-doc (stories/{id}/viewers/{me}). Heart UI iss
  // se sync hota hai. Story change pe re-subscribe karte hain.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _mySub;
  String? _subscribedStoryId;
  bool _liked = false;
  bool _likeBusy = false;

  // ─── Video playback state ───────────────────────────────────────
  // Story `isVideo == true` ho to image ke jagah VideoPlayer chalata hai.
  // Progress animation ki duration video ki actual length se sync hoti hai
  // (warna 5 sec ke baad next story pe chala jata video poori dekhe bina).
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  String? _videoForStoryId; // Track kis story ka video init hua hai.
  // In-flight init guard. `addPostFrameCallback` har build pe fire hota hai
  // (animation tick = build), aur `_videoForStoryId` init complete hone se
  // pehle null hota hai — isi liye pehle `_videoController` nullify karke
  // dispose karte hi doosri call usi story ke liye dobara init shuru kar
  // deti thi. Loader hamesha ke liye chalta rehta. Yeh field track karta
  // hai kis story ki init *abhi chal rahi hai* — usi ko skip karte hain.
  String? _videoInitInFlightForStoryId;

  // chat_screen.dart ke saath consistent rakhne ke liye: dono UIDs sorted
  String _chatRoomIdFor(String a, String b) {
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  static const List<String> _quickEmojis = [
    '❤️', '🙌', '🔥', '😂', '😮', '😢', '👏', '😍'
  ];

  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.initialUserIndex;
    _pageController = PageController(initialPage: 0);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goToNextStory();
      }
    });

    // Reply focus change → pause/resume + rebuild
    _replyFocus.addListener(() {
      if (!mounted) return;
      if (_replyFocus.hasFocus) {
        _animationController.stop();
        _videoController?.pause();
      } else if (!_isSending && !_isLongPressing) {
        _animationController.forward();
        _videoController?.play();
      }
      setState(() {});
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _mySub?.cancel();
    _pageController.dispose();
    _animationController.dispose();
    _replyCtrl.dispose();
    _replyFocus.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // ─── Video lifecycle ──────────────────────────────────────────────
  // Active story badle to:
  //   • agar naya isVideo hai → controller (re-)create, animation duration
  //     ko video length ke saath align karo.
  //   • agar naya image hai → pichla controller dispose karo, animation
  //     duration default 5s par reset karo.
  Future<void> _onActiveMediaChanged(StoryItem story) async {
    final isVideo = story.isVideo;
    final url = story.videoUrl ?? story.imageUrl;

    // Same story id aur same controller — kuch karne ki zaroorat nahi.
    if (_videoForStoryId == story.id && _videoController != null) return;
    // Pehle se isi story ki init chal rahi hai — duplicate skip karo.
    // (postFrameCallback animation tick par dobara fire hota hai, isi liye
    // bina is guard ke ek hi story ke liye 3-4 parallel inits ban jaate
    // they aur loader kabhi rukta nahi tha.)
    if (_videoInitInFlightForStoryId == story.id) return;

    // Pichla controller cleanup
    final old = _videoController;
    _videoController = null;
    _videoReady = false;
    _videoForStoryId = null;
    old?.dispose();

    if (!isVideo || url.isEmpty) {
      // Image story — default 5s duration use karo (jaisa pehle tha).
      _videoInitInFlightForStoryId = null;
      if (mounted) {
        _animationController.duration = const Duration(seconds: 5);
        setState(() {});
      }
      return;
    }

    // Video story — controller init.
    _videoInitInFlightForStoryId = story.id;
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
    _videoController = ctrl;
    _videoForStoryId = story.id;
    try {
      await ctrl.initialize();
      if (!mounted || _videoController != ctrl) {
        ctrl.dispose();
        if (_videoInitInFlightForStoryId == story.id) {
          _videoInitInFlightForStoryId = null;
        }
        return;
      }
      final vidDur = ctrl.value.duration;
      // Cap video story at 30s max (Instagram pattern). Min 3s safety.
      final clamped = Duration(
        milliseconds: vidDur.inMilliseconds
            .clamp(3000, 30000),
      );
      _animationController.duration = clamped;
      _animationController.reset();
      await ctrl.setLooping(false);
      await ctrl.play();
      _videoInitInFlightForStoryId = null;
      setState(() => _videoReady = true);
      if (_shouldPlay) _animationController.forward();
    } catch (e) {
      debugPrint('Story video init failed: $e');
      if (mounted && _videoController == ctrl) {
        _videoController = null;
        _videoForStoryId = null;
        _videoInitInFlightForStoryId = null;
        ctrl.dispose();
        // Image fallback: short hold then move on.
        _animationController.duration = const Duration(seconds: 5);
        setState(() {});
      }
    }
  }

  // Jab bhi visible story badle, do kaam karo:
  //  1. viewers/{me} doc create/merge — author ki Activity list me dikhne ke liye.
  //  2. usi doc pe stream attach — heart ki current state UI me sync rakhne ke liye.
  // Apni story par kuch nahi karte (author khud ka viewer nahi banta).
  void _onActiveStoryChanged({
    required String storyId,
    required String authorId,
  }) {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null || me == authorId) {
      _mySub?.cancel();
      _mySub = null;
      _subscribedStoryId = null;
      if (_liked) {
        setState(() => _liked = false);
      }
      return;
    }
    if (_subscribedStoryId == storyId) return;
    _subscribedStoryId = storyId;

    // View record (idempotent — viewedAt sirf first write pe set hota hai
    // server side se, but client-side merge se overwrite na ho isliye
    // viewedAt sirf tab likhte hain jab doc maujood na ho).
    _recordView(storyId: storyId, viewerId: me);

    // Story ring grey karne ke liye provider me bhi mark karo — pehle yeh
    // sirf `_goToNextStory` me last story end hone par hota tha, isi liye
    // back press se nikal jaane par seen state save nahi hoti thi. Ab jaise
    // hi koi story actually open hui (viewer doc bana), us user ko watched
    // mark kar do.
    if (mounted) {
      context.read<StoryProvider>().markAsWatched(authorId);
    }

    // Heart state stream
    _mySub?.cancel();
    _mySub = FirebaseFirestore.instance
        .collection('stories')
        .doc(storyId)
        .collection('viewers')
        .doc(me)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final data = snap.data();
      final liked = (data?['liked'] as bool?) ?? false;
      if (liked != _liked) setState(() => _liked = liked);
    }, onError: (e) => debugPrint('Viewer doc stream error: $e'));
  }

  Future<void> _recordView({
    required String storyId,
    required String viewerId,
  }) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .collection('viewers')
          .doc(viewerId);

      // Pehle `ref.get()` se check karte the — par viewers subcollection ke
      // rules sirf author ko read deti hain, isi liye viewer ka khud ka get()
      // permission-denied ho ke pura record skip ho jata tha. Ab seedha set
      // with merge: idempotent hai (repeat opens overwrite safe), aur write
      // rule "create own viewer doc" se pass ho jaata hai. viewedAt sirf
      // pehli baar likhna ho to server-side rules me handle karein — yahan
      // dobara likh dena ok hai (Activity sort wahi rahega).
      await ref.set({
        'uid': viewerId,
        'viewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Permission denied (rules) ya offline — UI break na ho lekin
      // debug me dikhe taake pata chale crash kaha hua.
      debugPrint('Record view failed for story=$storyId viewer=$viewerId: $e');
    }
  }

  Future<void> _toggleLike({
    required String storyId,
    required String authorId,
    required String storyThumbUrl,
  }) async {
    if (_likeBusy) return;
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) return;

    final newVal = !_liked;
    setState(() {
      _liked = newVal;
      _likeBusy = true;
    });

    try {
      final ref = FirebaseFirestore.instance
          .collection('stories')
          .doc(storyId)
          .collection('viewers')
          .doc(me);
      await ref.set({
        'uid': me,
        'liked': newVal,
        if (newVal) 'likedAt': FieldValue.serverTimestamp(),
        // First-ever like bhi viewedAt seed kar de agar abhi tak nahi tha
        'viewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Notification: like par author ko bell ring, unlike par doc delete —
      // post-like wala same dedupe pattern (spam-safe).
      if (newVal) {
        // Fire-and-forget — UI ko block na kare.
        NotificationService.notifyStoryLike(
          storyOwnerUid: authorId,
          storyId: storyId,
          storyThumbUrl: storyThumbUrl,
        );
      } else {
        NotificationService.removeStoryLike(
          storyOwnerUid: authorId,
          storyId: storyId,
        );
      }
    } catch (e) {
      debugPrint('Toggle like failed: $e');
      if (mounted) {
        setState(() => _liked = !newVal); // revert
        // User ko visible feedback — silently fail mat ho.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Like failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _likeBusy = false);
    }
  }

  String _formatRelative(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  bool get _shouldPlay =>
      !_isSending && !_isLongPressing && !_replyFocus.hasFocus;

  void _restartTimer() {
    _animationController.reset();
    if (_shouldPlay) _animationController.forward();
  }

  Future<void> _sendReply({
    required String text,
    required String receiverId,
    required String username,
    required String storyThumbUrl,
  }) async {
    // Pura body ek bade try-catch me — taa ke koi bhi unexpected error
    // (null deref, provider missing, navigator failure) silently swallow
    // na ho. Pehle sirf RTDB write try me tha, isi liye dusri exceptions
    // par "kuch nahi hota" jaisa lagta tha.
    try {
      debugPrint('📤 _sendReply called: text="$text" receiver=$receiverId '
          '_isSending=$_isSending');

      final trimmed = text.trim();
      if (trimmed.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Type something first'),
            duration: Duration(seconds: 1),
          ),
        );
        return;
      }
      if (_isSending) {
        // Stuck state se nikalne ke liye reset.
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Send button reset — tap again'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      final me = user?.uid;
      if (me == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to reply')),
        );
        return;
      }
      if (receiverId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot reply — recipient unknown'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (me == receiverId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This is your own story")),
        );
        return;
      }

      // Pre-compute build-context things BEFORE async work.
      // tr() agar throw kare to default fallback rakho.
      String repliedToLabel;
      try {
        repliedToLabel = context.tr('replied_to_story');
      } catch (_) {
        repliedToLabel = 'Replied to your story';
      }
      String sentSnackText;
      try {
        sentSnackText = context
            .tr('reply_sent_to')
            .replaceFirst('{name}', username);
      } catch (_) {
        sentSnackText = 'Reply sent to $username';
      }
      final senderName = user?.displayName ?? 'Me';
      final senderAvatar = user?.photoURL ?? '';

      setState(() => _isSending = true);
      _animationController.stop();

      try {
        final chatRoomId = _chatRoomIdFor(me, receiverId);
        final now = DateTime.now();
        final h = now.hour > 12
            ? now.hour - 12
            : (now.hour == 0 ? 12 : now.hour);
        final amPm = now.hour >= 12 ? 'PM' : 'AM';
        final timeString =
            '$h:${now.minute.toString().padLeft(2, '0')} $amPm';

        // chat_screen ka same FirebaseChatService — proven path.
        final msgData = <String, dynamic>{
          'senderId': me,
          'senderName': senderName,
          'receiverId': receiverId,
          'text': trimmed,
          'type': MsgType.text.index,
          'imageUrl': null,
          'avatarUrl': senderAvatar,
          'status': MsgStatus.sent.index,
          'time': timeString,
          'dateTime': now.millisecondsSinceEpoch,
          'duration': null,
          'isViewOnce': false,
          'replyToText': repliedToLabel,
          'replyToType': 'story',
          'storyThumbUrl': storyThumbUrl,
          'isDeleted': false,
          'isUnsent': false,
          'isStarred': false,
          'isPinned': false,
          'isEdited': false,
          'reactions': {},
          'isRead': false,
        };

        await FirebaseChatService().sendMessage(
          chatRoomId: chatRoomId,
          messageData: msgData,
        );

        debugPrint('✅ Reply sent to RTDB chats/$chatRoomId');

        if (!mounted) return;
        _replyCtrl.clear();
        _replyFocus.unfocus();

        // User story screen pe hi rahe — chat screen me NA jaye. Sirf ek
        // chhota confirmation SnackBar dikha do taa ke sender ko pata
        // chale message gaya hai. Story timer wapas chalu ho jayega
        // finally me _shouldPlay check ke saath.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(sentSnackText),
            duration: const Duration(seconds: 2),
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isSending = false);
          if (_shouldPlay) _animationController.forward();
        }
      }
    } catch (e, st) {
      // Top-level catch — sab errors yahan aate hain (pehle silently lost
      // ho rahe the kuch jagah pe).
      debugPrint('❌ Send reply outer-catch: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reply failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
      if (mounted && _isSending) {
        setState(() => _isSending = false);
      }
    }
  }

  void _goToNextStory() {
    // Reply box khula ho to tap se progress nahi
    if (_replyFocus.hasFocus) {
      _replyFocus.unfocus();
      return;
    }
    final storyProvider = context.read<StoryProvider>();
    final allUserStories = storyProvider.userStories;
    if (allUserStories.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final currentUserStories = allUserStories[_currentUserIndex].stories;

    if (_currentStoryIndex < currentUserStories.length - 1) {
      setState(() => _currentStoryIndex++);
      _restartTimer();
    } else {
      storyProvider.markAsWatched(allUserStories[_currentUserIndex].userId);

      if (_currentUserIndex < allUserStories.length - 1) {
        setState(() {
          _currentUserIndex++;
          _currentStoryIndex = 0;
        });
        _restartTimer();
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  void _goToPreviousStory() {
    if (_replyFocus.hasFocus) {
      _replyFocus.unfocus();
      return;
    }
    final allUserStories = context.read<StoryProvider>().userStories;
    if (allUserStories.isEmpty) return;

    if (_currentStoryIndex > 0) {
      setState(() => _currentStoryIndex--);
      _restartTimer();
    } else if (_currentUserIndex > 0) {
      setState(() {
        _currentUserIndex--;
        _currentStoryIndex =
            allUserStories[_currentUserIndex].stories.length - 1;
      });
      _restartTimer();
    } else {
      _restartTimer();
    }
  }

  // Left-swipe: agle user par jao, agar nahi to back
  void _goToNextUser() {
    if (_replyFocus.hasFocus) {
      _replyFocus.unfocus();
      return;
    }
    final storyProvider = context.read<StoryProvider>();
    final allUserStories = storyProvider.userStories;
    if (allUserStories.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    storyProvider.markAsWatched(allUserStories[_currentUserIndex].userId);
    if (_currentUserIndex < allUserStories.length - 1) {
      setState(() {
        _currentUserIndex++;
        _currentStoryIndex = 0;
      });
      _restartTimer();
    } else {
      Navigator.of(context).pop();
    }
  }

  // Right-swipe: pichle user par jao
  void _goToPreviousUser() {
    if (_replyFocus.hasFocus) {
      _replyFocus.unfocus();
      return;
    }
    if (_currentUserIndex > 0) {
      setState(() {
        _currentUserIndex--;
        _currentStoryIndex = 0;
      });
      _restartTimer();
    }
  }

  void _navigateToProfile(String userId, String username, String avatarUrl) {
    _animationController.stop();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: userId,
          username: username,
          avatarUrl: avatarUrl,
        ),
      ),
    ).then((_) {
      if (mounted && _shouldPlay) _animationController.forward();
    });
  }

  // ── Apni story ka 3-dot menu (Delete) ───────────────────────────
  void _showOwnStoryMenu(BuildContext context, {required String storyId}) {
    _animationController.stop();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Delete Story',
                style: TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Story?'),
                        content: const Text(
                            'Ye story permanently delete ho jaayegi. Confirm?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                            style: TextButton.styleFrom(
                                foregroundColor: Colors.red),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
                if (!confirm) {
                  if (mounted && _shouldPlay) _animationController.forward();
                  return;
                }
                try {
                  await FirebaseFirestore.instance
                      .collection('stories')
                      .doc(storyId)
                      .delete();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Story deleted ✅'),
                        backgroundColor: Color(0xFF0095F6),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    // Story chali gayi — viewer band karo.
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Delete failed: $e'),
                      backgroundColor: Colors.red,
                    ));
                    if (_shouldPlay) _animationController.forward();
                  }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.grey),
              title: const Text('Cancel'),
              onTap: () {
                Navigator.pop(sheetCtx);
                if (mounted && _shouldPlay) _animationController.forward();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storyProvider = context.watch<StoryProvider>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    if (storyProvider.isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: textColor)),
      );
    }

    final allUserStories = storyProvider.userStories;

    // ✅ Translated — pehle 'Koi story nahi' / 'Wapas jao' tha
    if (allUserStories.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined, color: textColor, size: 64),
              const SizedBox(height: 16),
              Text(
                context.tr('no_stories'), // ✅
                style: TextStyle(color: textColor, fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  context.tr('go_back'), // ✅
                  style: TextStyle(color: textColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Index safety check
    if (_currentUserIndex >= allUserStories.length) {
      _currentUserIndex = allUserStories.length - 1;
    }
    if (_currentStoryIndex >=
        allUserStories[_currentUserIndex].stories.length) {
      _currentStoryIndex =
          allUserStories[_currentUserIndex].stories.length - 1;
    }

    final userStory = allUserStories[_currentUserIndex];
    final currentStory = userStory.stories[_currentStoryIndex];

    final me = FirebaseAuth.instance.currentUser?.uid;
    final bool isOwnStory = me == userStory.userId;

    // Visible story badli? View record + like-state stream re-subscribe.
    // Post-frame me run karte hain taa ke build ke beech setState avoid ho.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onActiveStoryChanged(
        storyId: currentStory.id,
        authorId: userStory.userId,
      );
      // Video/image lifecycle ko bhi sync karo — naya story open hua to
      // video controller (re-)create karo ya image mode pe reset karo.
      _onActiveMediaChanged(currentStory);
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Image full screen rahe — reply bar khud keyboard ke uper uthega
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Story media — image ya video
          Center(
            child: currentStory.isVideo
                ? (_videoReady &&
                        _videoController != null &&
                        _videoForStoryId == currentStory.id
                    ? AspectRatio(
                        aspectRatio:
                            _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      )
                    : Center(
                        child: CircularProgressIndicator(color: textColor),
                      ))
                : Image.network(
                    currentStory.imageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) {
                        if (_shouldPlay &&
                            !_animationController.isAnimating) {
                          _animationController.forward();
                        }
                        return child;
                      }
                      _animationController.stop();
                      return Center(
                        child: CircularProgressIndicator(color: textColor),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Icon(Icons.broken_image,
                          color: textColor, size: 64),
                    ),
                  ),
          ),

          // Tap + swipe + long-press areas (reply bar ke uper tak)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: isOwnStory ? 0 : 150,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              // WhatsApp-style: dabaye rakho to pause, chodho to resume
              onLongPressStart: (_) {
                setState(() => _isLongPressing = true);
                _animationController.stop();
                // Video stories ke liye actual video bhi pause karo, warna
                // animation ruke par video chalti rahegi → out of sync.
                _videoController?.pause();
              },
              onLongPressEnd: (_) {
                setState(() => _isLongPressing = false);
                if (_shouldPlay) {
                  _animationController.forward();
                  _videoController?.play();
                }
              },
              onHorizontalDragEnd: (details) {
                final v = details.primaryVelocity ?? 0;
                if (v < -200) {
                  _goToNextUser();
                } else if (v > 200) {
                  _goToPreviousUser();
                }
              },
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _goToPreviousStory,
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _goToNextStory,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Top overlay
          SafeArea(
            child: Column(
              children: [
                // Progress bars
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Row(
                        children: List.generate(
                          userStory.stories.length,
                          (index) => _buildProgressBar(index, isDark),
                        ),
                      );
                    },
                  ),
                ),

                // User info bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToProfile(
                          userStory.userId,
                          userStory.username,
                          userStory.avatarUrl,
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(userStory.avatarUrl),
                          backgroundColor: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _navigateToProfile(
                          userStory.userId,
                          userStory.username,
                          userStory.avatarUrl,
                        ),
                        child: Text(
                          userStory.username,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: isDark
                                ? [
                              const Shadow(
                                  color: Colors.black54, blurRadius: 4)
                            ]
                                : null,
                          ),
                        ),
                      ),
                      // Latest unlocked image badge — sirf doosre users ki
                      // story me dikhe. Agar koi image badge unlock nahi tou
                      // LatestBadgeChip khud Lv chip pe fallback karta hai.
                      if (!isOwnStory) ...[
                        const SizedBox(width: 6),
                        LatestBadgeChip(
                          uid: userStory.userId,
                          size: 24,
                        ),
                      ],
                      const Spacer(),
                      // Apni story par hi 3-dot menu dikhao → delete option.
                      if (isOwnStory)
                        IconButton(
                          icon: Icon(Icons.more_vert, color: textColor),
                          onPressed: () => _showOwnStoryMenu(
                            context,
                            storyId: currentStory.id,
                          ),
                        ),
                      IconButton(
                        icon: Icon(Icons.close, color: textColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Apni story par bottom-left "Activity" button — Instagram jasa
          // chevron-up + viewer count. Tap se viewers sheet khulta hai.
          if (isOwnStory)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
              child: _buildActivityButton(
                storyId: currentStory.id,
                isDark: isDark,
              ),
            ),

          // Bottom reply bar (Instagram-style) — keyboard ke saath uthe
          if (!isOwnStory)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).viewInsets.bottom,
              child: _buildReplyBar(
                receiverId: userStory.userId,
                username: userStory.username,
                isDark: isDark,
                storyId: currentStory.id,
                authorId: userStory.userId,
                storyThumbUrl: currentStory.imageUrl,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReplyBar({
    required String receiverId,
    required String username,
    required bool isDark,
    required String storyId,
    required String authorId,
    required String storyThumbUrl,
  }) {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final bottomPad =
        keyboardOpen ? 0.0 : MediaQuery.of(context).padding.bottom;
    final Color barColor = isDark ? Colors.black54 : Colors.white70;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color hintColor = isDark ? Colors.white70 : Colors.black54;
    final Color fieldBg = isDark ? Colors.white12 : Colors.black12;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Reply bar par taps story navigation trigger na karein
        onTap: () {},
        child: Container(
          padding: EdgeInsets.only(
            left: 10,
            right: 10,
            top: 8,
            // Keyboard band: safe-area dein. Khula: keyboard hi seal kar deta hai.
            bottom: 8 + bottomPad,
          ),
          decoration: BoxDecoration(
            color: barColor,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white24 : Colors.black12,
                width: 0.5,
              ),
            ),
          ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Emoji quick row
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickEmojis.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final emoji = _quickEmojis[i];
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _isSending
                        ? null
                        : () => _sendReply(
                              text: emoji,
                              receiverId: receiverId,
                              username: username,
                              storyThumbUrl: storyThumbUrl,
                            ),
                    child: Container(
                      width: 40,
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            // Text field + send
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyCtrl,
                    focusNode: _replyFocus,
                    style: TextStyle(color: textColor),
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (val) => _sendReply(
                      text: val,
                      receiverId: receiverId,
                      username: username,
                      storyThumbUrl: storyThumbUrl,
                    ),
                    decoration: InputDecoration(
                      hintText: context
                          .tr('reply_to_user')
                          .replaceFirst('{name}', username),
                      hintStyle: TextStyle(color: hintColor),
                      filled: true,
                      fillColor: fieldBg,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _liked ? Icons.favorite : Icons.favorite_border,
                    color: _liked ? Colors.red : textColor,
                  ),
                  onPressed: _likeBusy
                      ? null
                      : () => _toggleLike(
                            storyId: storyId,
                            authorId: authorId,
                            storyThumbUrl: storyThumbUrl,
                          ),
                ),
                IconButton(
                  icon: _isSending
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: textColor,
                          ),
                        )
                      : Icon(Icons.send, color: textColor),
                  onPressed: _isSending
                      ? null
                      : () => _sendReply(
                            text: _replyCtrl.text,
                            receiverId: receiverId,
                            username: username,
                            storyThumbUrl: storyThumbUrl,
                          ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildActivityButton({
    required String storyId,
    required bool isDark,
  }) {
    final Color fg = isDark ? Colors.white : Colors.black87;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showActivitySheet(storyId: storyId, isDark: isDark),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.black38 : Colors.white70,
          borderRadius: BorderRadius.circular(20),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('stories')
              .doc(storyId)
              .collection('viewers')
              .snapshots(),
          builder: (context, snap) {
            final count = snap.data?.docs.length ?? 0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.keyboard_arrow_up, color: fg, size: 20),
                const SizedBox(width: 6),
                Icon(Icons.visibility_outlined, color: fg, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('activity'),
                  style: TextStyle(color: fg, fontSize: 14),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showActivitySheet({
    required String storyId,
    required bool isDark,
  }) {
    _animationController.stop();
    final Color bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final Color fg = isDark ? Colors.white : Colors.black87;
    final Color subFg = isDark ? Colors.white70 : Colors.black54;

    // In-sheet user cache — story_provider.dart:151-166 jasa pattern.
    final Map<String, Map<String, dynamic>> userCache = {};

    showModalBottomSheet(
      context: context,
      backgroundColor: bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollCtrl) {
            return Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('stories')
                          .doc(storyId)
                          .collection('viewers')
                          .snapshots(),
                      builder: (context, snap) {
                        final docs = snap.data?.docs ?? const [];
                        final views = docs.length;
                        final likes = docs.where((d) {
                          final m = d.data() as Map<String, dynamic>?;
                          return (m?['liked'] as bool?) == true;
                        }).length;
                        return Text(
                          '${context.tr('views_count').replaceFirst('{count}', '$views')}  ·  ${context.tr('likes_count').replaceFirst('{count}', '$likes')}',
                          style: TextStyle(
                            color: fg,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('stories')
                        .doc(storyId)
                        .collection('viewers')
                        .orderBy('viewedAt', descending: true)
                        .limit(200)
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(color: fg),
                        );
                      }
                      final docs = snap.data?.docs ?? const [];
                      if (docs.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              context.tr('no_views_yet'),
                              style: TextStyle(color: subFg, fontSize: 14),
                            ),
                          ),
                        );
                      }
                      return ListView.builder(
                        controller: scrollCtrl,
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final d = docs[i];
                          final data = d.data() as Map<String, dynamic>;
                          final uid = (data['uid'] as String?) ?? d.id;
                          final liked = (data['liked'] as bool?) ?? false;
                          final ts = data['viewedAt'] as Timestamp?;

                          return FutureBuilder<Map<String, dynamic>>(
                            future: _getUser(uid, userCache),
                            builder: (_, userSnap) {
                              // Loading state — connection still waiting,
                              // skeleton-style placeholder dikha do (na ki
                              // "..." jo permanent lagta hai).
                              final loading = userSnap.connectionState ==
                                  ConnectionState.waiting;
                              final u = userSnap.data ?? const {};
                              // Field naam codebase me consistent nahi —
                              // `username` primary hai, par kuch jagah
                              // `fullName` / `displayName` / `name` bhi
                              // save hota hai. Sab try karo phir uid suffix.
                              String username = (u['username'] as String?) ??
                                  (u['fullName'] as String?) ??
                                  (u['displayName'] as String?) ??
                                  (u['name'] as String?) ??
                                  '';
                              if (username.trim().isEmpty) {
                                username = loading
                                    ? 'Loading…'
                                    : (uid.length >= 6
                                        ? 'user_${uid.substring(0, 6)}'
                                        : 'user');
                              }
                              final avatar =
                                  (u['photoUrl'] as String?) ??
                                      (u['photoURL'] as String?) ??
                                      (u['avatarUrl'] as String?) ??
                                      '';
                              return ListTile(
                                onTap: () {
                                  Navigator.pop(sheetCtx);
                                  _navigateToProfile(uid, username, avatar);
                                },
                                leading: CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.grey[300],
                                  backgroundImage: avatar.isNotEmpty
                                      ? NetworkImage(avatar)
                                      : null,
                                  child: avatar.isEmpty
                                      ? Icon(Icons.person,
                                          color: Colors.grey[600])
                                      : null,
                                ),
                                title: Text(
                                  username,
                                  style: TextStyle(
                                    color: fg,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                subtitle: Text(
                                  _formatRelative(ts),
                                  style:
                                      TextStyle(color: subFg, fontSize: 12),
                                ),
                                // Liked: red heart. Sirf view (no like):
                                // grey eye icon — taa ke "kis ne dekhi" aur
                                // "kis ne like ki" dono visually distinguish
                                // hon. Pehle view-only viewer ke saath kuch
                                // nahi tha.
                                trailing: liked
                                    ? const Icon(Icons.favorite,
                                        color: Colors.red, size: 20)
                                    : Icon(Icons.visibility_outlined,
                                        color: subFg, size: 20),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      if (mounted && _shouldPlay) _animationController.forward();
    });
  }

  Future<Map<String, dynamic>> _getUser(
    String uid,
    Map<String, Map<String, dynamic>> cache,
  ) async {
    final hit = cache[uid];
    if (hit != null) return hit;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!snap.exists) {
        debugPrint('User doc not found for uid=$uid (Activity sheet)');
      }
      final data = snap.data() ?? const <String, dynamic>{};
      // Cache sirf non-empty result — empty cache karenge to dobara fetch
      // bhi nahi hoga aur "Loading…" hamesha rahegi.
      if (data.isNotEmpty) cache[uid] = data;
      return data;
    } catch (e) {
      debugPrint('User fetch failed for $uid (Activity sheet): $e');
      return const {};
    }
  }

  Widget _buildProgressBar(int index, bool isDark) {
    double progress = 0.0;
    if (index < _currentStoryIndex) {
      progress = 1.0;
    } else if (index == _currentStoryIndex) {
      progress = _animationController.value;
    }

    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isDark ? Colors.white30 : Colors.black26,
          borderRadius: BorderRadius.circular(2),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black87,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}