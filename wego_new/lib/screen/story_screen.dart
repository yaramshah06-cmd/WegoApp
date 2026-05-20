import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wego_marriage/providers/story_provider.dart';
import 'package:wego_marriage/screen/massage_list_screen.dart';
import 'package:wego_marriage/screen/user_profile_screen.dart';
import 'app_localizations.dart';
import 'app_translations.dart';

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
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  bool _isSending = false;

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
      } else if (!_isSending && !_isLongPressing) {
        _animationController.forward();
      }
      setState(() {});
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _replyCtrl.dispose();
    _replyFocus.dispose();
    super.dispose();
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
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isSending) return;

    final user = FirebaseAuth.instance.currentUser;
    final me = user?.uid;
    if (me == null || me == receiverId) return;

    setState(() => _isSending = true);
    _animationController.stop();

    try {
      // ✅ Realtime DB ka same schema jo chat_screen.dart use karta hai,
      // warna message Firestore mein chala jata aur chat screen pe nazar nahi aata tha.
      final chatRoomId = _chatRoomIdFor(me, receiverId);
      final now = DateTime.now();
      final h = now.hour > 12
          ? now.hour - 12
          : (now.hour == 0 ? 12 : now.hour);
      final amPm = now.hour >= 12 ? 'PM' : 'AM';
      final timeString =
          '$h:${now.minute.toString().padLeft(2, '0')} $amPm';

      final msgData = <String, dynamic>{
        'senderId': me,
        'senderName': user?.displayName ?? 'Me',
        'receiverId': receiverId,
        'text': trimmed,
        'type': 0, // MsgType.text
        'imageUrl': null,
        'avatarUrl': user?.photoURL ?? '',
        'status': 0, // MsgStatus.sent
        'time': timeString,
        'dateTime': now.millisecondsSinceEpoch,
        'duration': null,
        'isViewOnce': false,
        'replyToText': context.tr('replied_to_story'),
        'replyToType': 'story',
        'isDeleted': false,
        'isUnsent': false,
        'isStarred': false,
        'isPinned': false,
        'isEdited': false,
        'reactions': {},
        'isRead': false,
      };

      final ref = _db.ref('chats/$chatRoomId/messages').push();
      await ref.set({
        ...msgData,
        'id': ref.key,
        'firebaseKey': ref.key,
      });

      // Last message bhi update karo (chat list preview ke liye)
      await _db.ref('chats/$chatRoomId/lastMessage').set({
        'text': trimmed,
        'time': timeString,
        'senderId': me,
        'timestamp': ServerValue.timestamp,
      });

      if (!mounted) return;
      _replyCtrl.clear();
      _replyFocus.unfocus();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('reply_sent_to').replaceFirst('{name}', username)),
          duration: const Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MessageListScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
        // page replace ho jata hai to ye no-op ho ga, warna timer resume
        if (_shouldPlay) _animationController.forward();
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

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      // Image full screen rahe — reply bar khud keyboard ke uper uthega
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Story image
          Center(
            child: Image.network(
              currentStory.imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, progress) {
                if (progress == null) {
                  if (_shouldPlay && !_animationController.isAnimating) {
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
                child: Icon(Icons.broken_image, color: textColor, size: 64),
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
              },
              onLongPressEnd: (_) {
                setState(() => _isLongPressing = false);
                if (_shouldPlay) _animationController.forward();
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
                const SizedBox(width: 6),
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