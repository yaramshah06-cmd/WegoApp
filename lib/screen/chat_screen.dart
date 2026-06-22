import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wego_marriage/providers/chat_provider.dart';
import 'package:wego_marriage/services/local_storage_service.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:async';

// ── Colors ────────────────────────────────────────────────────
const Color kPurple = Color(0xFF7A1730);
const Color kTeal = Color(0xFF2EC4B6);

// ── Message Status ─────────────────────────────────────────────
enum MsgStatus { sent, delivered, seen }

// ── Message Model ─────────────────────────────────────────────
enum MsgType { text, image, sticker, voice, document, video, gif, linkPreview }

class ChatMessage {
  final String? text;
  final bool isMine;
  final MsgType type;
  final String? imageUrl;
  final String? avatarUrl;
  final MsgStatus status;
  final String time;
  final Duration? duration;
  final String? fileName;
  final int? fileSize;
  final bool isFavorite;
  final Map<String, List<String>> reactions;
  final bool isStarred;
  final bool isPinned;
  final bool isViewOnce;
  final bool isDeleted;
  final bool isUnsent;
  final String? replyToText;
  final String? replyToType;
  final String id;
  final DateTime? dateTime;

  ChatMessage({
    this.text,
    required this.isMine,
    this.type = MsgType.text,
    this.imageUrl,
    this.avatarUrl,
    this.status = MsgStatus.sent,
    this.time = '10:00 AM',
    this.duration,
    this.fileName,
    this.fileSize,
    this.isFavorite = false,
    this.reactions = const {},
    this.isStarred = false,
    this.isPinned = false,
    this.isViewOnce = false,
    this.isDeleted = false,
    this.isUnsent = false,
    this.replyToText,
    this.replyToType,
    String? id,
    this.dateTime,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  ChatMessage copyWith({
    Map<String, List<String>>? reactions,
    bool? isStarred,
    bool? isPinned,
    bool? isDeleted,
    bool? isUnsent,
    MsgStatus? status,
    String? replyToText,
    String? replyToType,
  }) {
    return ChatMessage(
      text: text,
      isMine: isMine,
      type: type,
      imageUrl: imageUrl,
      avatarUrl: avatarUrl,
      status: status ?? this.status,
      time: time,
      duration: duration,
      fileName: fileName,
      fileSize: fileSize,
      isFavorite: isFavorite,
      reactions: reactions ?? this.reactions,
      isStarred: isStarred ?? this.isStarred,
      isPinned: isPinned ?? this.isPinned,
      isViewOnce: isViewOnce,
      isDeleted: isDeleted ?? this.isDeleted,
      isUnsent: isUnsent ?? this.isUnsent,
      replyToText: replyToText ?? this.replyToText,
      replyToType: replyToType ?? this.replyToType,
      id: id,
      dateTime: dateTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'isMine': isMine,
      'type': type.index,
      'imageUrl': imageUrl,
      'avatarUrl': avatarUrl,
      'status': status.index,
      'time': time,
      'duration': duration?.inSeconds,
      'fileName': fileName,
      'fileSize': fileSize,
      'isFavorite': isFavorite,
      'reactions': reactions.map((k, v) => MapEntry(k, v)),
      'isStarred': isStarred,
      'isPinned': isPinned,
      'isViewOnce': isViewOnce,
      'isDeleted': isDeleted,
      'isUnsent': isUnsent,
      'replyToText': replyToText,
      'replyToType': replyToType,
      'dateTime': dateTime?.millisecondsSinceEpoch,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    Map<String, List<String>> reactionsMap = {};
    if (map['reactions'] != null) {
      (map['reactions'] as Map).forEach((k, v) {
        reactionsMap[k.toString()] = List<String>.from(v);
      });
    }
    return ChatMessage(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: map['text'],
      isMine: map['isMine'],
      type: MsgType.values[map['type']],
      imageUrl: map['imageUrl'],
      avatarUrl: map['avatarUrl'],
      status: MsgStatus.values[map['status']],
      time: map['time'],
      duration: map['duration'] != null ? Duration(seconds: map['duration']) : null,
      fileName: map['fileName'],
      fileSize: map['fileSize'],
      isFavorite: map['isFavorite'] ?? false,
      reactions: reactionsMap,
      isStarred: map['isStarred'] ?? false,
      isPinned: map['isPinned'] ?? false,
      isViewOnce: map['isViewOnce'] ?? false,
      isDeleted: map['isDeleted'] ?? false,
      isUnsent: map['isUnsent'] ?? false,
      replyToText: map['replyToText'],
      replyToType: map['replyToType'],
      dateTime: map['dateTime'] != null ? DateTime.fromMillisecondsSinceEpoch(map['dateTime']) : null,
    );
  }
}

// ── Chat Screen ───────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  final String username;
  final String avatarUrl;
  final String? lastMessage;
  final bool isFollowedBack;

  const ChatScreen({
    super.key,
    required this.username,
    required this.avatarUrl,
    this.lastMessage,
    this.isFollowedBack = true,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final LocalStorageService _storage = LocalStorageService();
  final TextEditingController _searchCtrl = TextEditingController();
  List<ChatMessage> _messages = [];

  bool _isRecording = false;
  bool _showPanel = false;
  int _activeMainTab = 0;
  int _emojiCategoryIndex = 1;
  int _stickerCategoryIndex = 0;
  String _emojiSearchQuery = "";
  String _stickerSearchQuery = "";
  String _gifSearchQuery = "";

  // Reply state
  ChatMessage? _replyingTo;

  // Voice recording
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  bool _voiceLocked = false;
  bool _voicePaused = false;

  // Online/typing state
  bool _isUserOnline = true;
  bool _isTyping = false;
  Timer? _typingTimer;

  // Pinned message
  ChatMessage? _pinnedMessage;

  // Blocked state
  bool _isBlocked = false;

  // VIP features
  bool _autoTranslateEnabled = false;
  bool _followEnabled = false;
  bool _pinOnTopEnabled = false;
  String _nickname = '';
  String _selectedBubbleStyle = 'default';
  bool _isVIP = false;

  final List<String> _quickReactions = ['❤️', '😂', '😮', '😢', '🙏', '👍'];

  final List<Map<String, dynamic>> _stickerCategories = [
    {
      'name': 'Favorites',
      'icon': Icons.star,
      'stickers': <String>[],
    },
    {
      'name': 'Love',
      'icon': Icons.favorite,
      'stickers': <String>[
        'https://cdn-icons-png.flaticon.com/512/833/833472.png',
        'https://cdn-icons-png.flaticon.com/512/833/833473.png',
        'https://cdn-icons-png.flaticon.com/512/833/833474.png',
        'https://cdn-icons-png.flaticon.com/512/833/833475.png',
        'https://cdn-icons-png.flaticon.com/512/833/833476.png',
      ],
    },
    {
      'name': 'Funny',
      'icon': Icons.sentiment_very_satisfied,
      'stickers': <String>[
        'https://cdn-icons-png.flaticon.com/512/742/742756.png',
        'https://cdn-icons-png.flaticon.com/512/742/742757.png',
        'https://cdn-icons-png.flaticon.com/512/742/742758.png',
        'https://cdn-icons-png.flaticon.com/512/742/742759.png',
        'https://cdn-icons-png.flaticon.com/512/742/742760.png',
      ],
    },
    {
      'name': 'Cute',
      'icon': Icons.pets,
      'stickers': <String>[
        'https://cdn-icons-png.flaticon.com/512/616/616408.png',
        'https://cdn-icons-png.flaticon.com/512/616/616430.png',
        'https://cdn-icons-png.flaticon.com/512/616/616496.png',
        'https://cdn-icons-png.flaticon.com/512/616/616498.png',
        'https://cdn-icons-png.flaticon.com/512/616/616490.png',
      ],
    },
  ];

  final List<String> _gifUrls = [
    'https://media.giphy.com/media/l0HlHFRbmaZtBRhXO/giphy.gif',
    'https://media.giphy.com/media/3o7TKSjRrfIPjeiVyM/giphy.gif',
    'https://media.giphy.com/media/l0MYt5jPR6QX5pnqM/giphy.gif',
    'https://media.giphy.com/media/l0HlBO7eyXzSZkJri/giphy.gif',
    'https://media.giphy.com/media/3o7abAHdYvZdBNnGZq/giphy.gif',
    'https://media.giphy.com/media/3o7TKMGVpE71y5f6eY/giphy.gif',
    'https://media.giphy.com/media/26BROrSHlmyzzHf3i/giphy.gif',
    'https://media.giphy.com/media/xT9IgusfDstF2k8uHC/giphy.gif',
    'https://media.giphy.com/media/l0MYGb1LuZ3n7dRnO/giphy.gif',
  ];

  final List<Map<String, dynamic>> _emojiCategories = [
    {
      'icon': Icons.access_time_rounded,
      'name': 'Recent',
      'emojis': ['😀', '😍', '😂', '🔥', '❤️', '👍', '🙏', '🙌', '✨', '🎉']
    },
    {
      'icon': Icons.emoji_emotions_outlined,
      'name': 'Smileys',
      'emojis': [
        '😀','😃','😄','😁','😆','😅','🤣','😂','🙂','🙃','😉','😊','😇',
        '🥰','😍','🤩','😘','😗','😚','😙','😋','😛','😜','🤪','😝','🤑',
        '🤗','🤭','🤫','🤔','🤐','🤨','😐','😑','😶','😏','😒','🙄','😬',
        '🤥','😌','😔','😪','🤤','😴','😷','🤒','🤕','🤢','🤮','🤧','🥵',
        '🥶','🥴','😵','🤯','🤠','🥳','😎','🤓','🧐','😕','😟','🙁','☹️',
        '😮','😯','😲','😳','🥺','😦','😧','😨','😰','😥','😢','😭','😱',
        '😖','😣','😞','😓','😩','😫','🥱','😤','😡','😠','🤬','😈','👿',
        '💀','☠️','💩','🤡','👹','👺','👻','👽','👾','🤖'
      ]
    },
    {
      'icon': Icons.pets_outlined,
      'name': 'Animals',
      'emojis': [
        '🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯','🦁','🐮','🐷',
        '🐸','🐵','🐔','🐧','🐦','🐤','🦆','🦅','🦉','🦇','🐺','🐗','🐴',
        '🦄','🐝','🐛','🦋','🐌','🐞','🐜','🦟','🦗','🕷️','🕸️','🦂','🐢',
        '🐍','🦎'
      ]
    },
    {
      'icon': Icons.fastfood_outlined,
      'name': 'Food',
      'emojis': [
        '🍎','🍐','🍊','🍋','🍌','🍉','🍇','🍓','🍈','🍒','🍑','🥭','🍍',
        '🥥','🥝','🍅','🍆','🥑','🥦','🌽','🍔','🍟','🍕','🌮','🌯','🍝',
        '🍜','🍛','🍣','🍱','🥟','🍤','🍦','🧁','🍰','🎂','🍭','🍬','🍫',
        '🍿','🍩','🍪','☕','🍵','🥤','🍺','🍻','🥂','🍷'
      ]
    },
    {
      'icon': Icons.sports_soccer_rounded,
      'name': 'Activities',
      'emojis': [
        '⚽','🏀','🏈','⚾','🥎','🎾','🏐','🏉','🎱','🏓','🏸','🥊','🥋',
        '🎽','🛹','⛷️','🏂','🏋️','🤸','⛹️','🏄','🏊','🤽','🚴','🚵'
      ]
    },
    {
      'icon': Icons.directions_car_filled_outlined,
      'name': 'Travel',
      'emojis': [
        '🚗','🚕','🚙','🚌','🚎','🏎️','🚓','🚑','🚒','🚐','🚚','🚛','🚜',
        '🛵','🏍️','🚲','✈️','🚀','⛵','⚓'
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _loadFavoriteStickers();
    _loadUserSettings();
    _markChatAsSeen();
    _nickname = widget.username;
    // Simulate online status
    _simulateOnlineStatus();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _simulateOnlineStatus() {
    // Simulate typing after a delay
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _isTyping = true);
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _isTyping = false);
        });
      }
    });
  }

  void _markChatAsSeen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().markChatAsSeen(widget.username);
      _storage.markChatAsSeen(widget.username);
    });
  }

  // ── Load favorite stickers from persistent storage ──────────
  void _loadFavoriteStickers() {
    final favs = _storage.getFavoriteStickers(widget.username);
    if (favs.isNotEmpty) {
      setState(() {
        _stickerCategories[0]['stickers'] = List<String>.from(favs);
      });
    }
  }

  void _loadUserSettings() {
    final settings = _storage.getUserChatSettings(widget.username);
    if (settings != null) {
      setState(() {
        _autoTranslateEnabled = settings['autoTranslate'] ?? false;
        _followEnabled = settings['follow'] ?? false;
        _pinOnTopEnabled = settings['pinOnTop'] ?? false;
        _nickname = settings['nickname'] ?? widget.username;
        _isBlocked = settings['blocked'] ?? false;
        _selectedBubbleStyle = settings['bubbleStyle'] ?? 'default';
      });
    }
  }

  void _saveUserSettings() {
    _storage.saveUserChatSettings(widget.username, {
      'autoTranslate': _autoTranslateEnabled,
      'follow': _followEnabled,
      'pinOnTop': _pinOnTopEnabled,
      'nickname': _nickname,
      'blocked': _isBlocked,
      'bubbleStyle': _selectedBubbleStyle,
    });
  }

  void _loadMessages() {
    final savedMsgs = _storage.getChatMessages(widget.username);
    if (savedMsgs.isEmpty) {
      _initializeDefaultMessages();
    } else {
      setState(() {
        _messages = savedMsgs.map((m) => ChatMessage.fromMap(m)).toList();
        _pinnedMessage = _messages.where((m) => m.isPinned).lastOrNull;
      });
    }
    _scrollToBottom(delay: 200);
  }

  void _initializeDefaultMessages() {
    _messages = [
      ChatMessage(
          text: "Hi, I'm ${widget.username}. How are you?",
          isMine: false,
          avatarUrl: widget.avatarUrl,
          time: '9:40 AM',
          dateTime: DateTime.now().subtract(const Duration(hours: 2))),
      ChatMessage(
          isMine: false,
          type: MsgType.image,
          imageUrl: 'https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=600',
          avatarUrl: widget.avatarUrl,
          time: '9:42 AM',
          dateTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 58))),
      ChatMessage(
          text: "Sticker 😍",
          isMine: false,
          type: MsgType.sticker,
          imageUrl: 'https://media.giphy.com/media/l0MYGb1LuZ3n7dRnO/giphy.gif',
          avatarUrl: widget.avatarUrl,
          time: '9:45 AM',
          dateTime: DateTime.now().subtract(const Duration(hours: 1, minutes: 55))),
    ];
    _saveToStorage();
  }

  Future<void> _saveToStorage() async {
    final maps = _messages.map((m) => m.toMap()).toList();
    await _storage.saveChatMessages(widget.username, maps);
    // Save favorite stickers separately
    await _storage.saveFavoriteStickers(
        widget.username,
        List<String>.from(_stickerCategories[0]['stickers'] as List));

    if (_messages.isNotEmpty) {
      final lastMsg = _messages.last;
      String displayMsg = "";
      if (lastMsg.isUnsent || lastMsg.isDeleted) {
        displayMsg = "This message was deleted";
      } else if (lastMsg.type == MsgType.text) {
        displayMsg = lastMsg.isMine ? "You: ${lastMsg.text}" : lastMsg.text!;
      } else if (lastMsg.type == MsgType.sticker) {
        displayMsg = "Sticker 😍";
      } else if (lastMsg.type == MsgType.voice) {
        displayMsg = "Voice Message 🎤";
      } else if (lastMsg.type == MsgType.image) {
        displayMsg = "Photo 📷";
      } else if (lastMsg.type == MsgType.gif) {
        displayMsg = "GIF";
      }

      await _storage.updateLastMessage(
          widget.username, displayMsg, lastMsg.time,
          avatarUrl: widget.avatarUrl);
    }
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    return "$hour:${now.minute.toString().padLeft(2, '0')} $amPm";
  }

  void _sendMessage({MsgType type = MsgType.text, String? text, String? imageUrl, bool isViewOnce = false}) {
    final msgText = text ?? _msgCtrl.text.trim();
    if (msgText.isEmpty && type == MsgType.text) return;

    final timeStr = _getCurrentTime();

    final newMsg = ChatMessage(
      text: type == MsgType.text ? msgText : text,
      isMine: true,
      type: type,
      status: MsgStatus.sent,
      time: timeStr,
      imageUrl: imageUrl,
      isViewOnce: isViewOnce,
      replyToText: _replyingTo?.text ?? (_replyingTo != null ? '[${_replyingTo!.type.name}]' : null),
      replyToType: _replyingTo?.type.name,
      dateTime: DateTime.now(),
    );

    setState(() {
      _messages.add(newMsg);
      if (type == MsgType.text) _msgCtrl.clear();
      _replyingTo = null;
    });

    _saveToStorage();
    _scrollToBottom();
    _simulateStatusUpdates(_messages.length - 1);
  }

  void _simulateStatusUpdates(int index) {
    // Single tick = sent (no net / offline)
    // Double tick = delivered (app open or closed but net on)
    // Blue ticks = seen
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && index < _messages.length) {
        setState(() {
          final m = _messages[index];
          _messages[index] = m.copyWith(status: MsgStatus.delivered);
        });
        _saveToStorage();
      }
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && index < _messages.length) {
        setState(() {
          final m = _messages[index];
          _messages[index] = m.copyWith(status: MsgStatus.seen);
        });
        _saveToStorage();
      }
    });
  }

  void _scrollToBottom({int delay = 100}) {
    Future.delayed(Duration(milliseconds: delay), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ── Long Press → Message Options Popup ──────────────────────
  void _showMessageOptions(BuildContext context, int messageIndex) {
    HapticFeedback.mediumImpact();
    final msg = _messages[messageIndex];
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim, secAnim) => Container(),
      transitionBuilder: (ctx, anim, secAnim, child) {
        return FadeTransition(
          opacity: anim,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Emoji reaction bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: ScaleTransition(
                  scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 16, offset: const Offset(0, 4))],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ..._quickReactions.map((emoji) => GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _toggleReaction(messageIndex, emoji);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Text(emoji, style: const TextStyle(fontSize: 26)),
                            ),
                          )),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showFullEmojiReactionPicker(context, messageIndex);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                              child: const Icon(Icons.add, size: 22, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Action menu
              SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 0),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(margin: const EdgeInsets.only(top: 8, bottom: 4), width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
                          // Reply
                          _ActionTile(icon: Icons.reply, label: 'Reply', onTap: () {
                            Navigator.pop(ctx);
                            setState(() => _replyingTo = msg);
                          }),
                          // Forward
                          _ActionTile(icon: Icons.forward, label: 'Forward', onTap: () {
                            Navigator.pop(ctx);
                            _openForwardScreen(context, msg);
                          }),
                          // Copy (only for text)
                          if (msg.type == MsgType.text && !msg.isDeleted && !msg.isUnsent)
                            _ActionTile(icon: Icons.copy, label: 'Copy', onTap: () {
                              Navigator.pop(ctx);
                              Clipboard.setData(ClipboardData(text: msg.text ?? ''));
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message copied')));
                            }),
                          // Info
                          _ActionTile(icon: Icons.info_outline, label: 'Info', onTap: () {
                            Navigator.pop(ctx);
                            _showMessageInfo(context, msg);
                          }),
                          // Star
                          _ActionTile(
                            icon: msg.isStarred ? Icons.star : Icons.star_border,
                            label: msg.isStarred ? 'Unstar' : 'Star',
                            iconColor: msg.isStarred ? Colors.amber : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                _messages[messageIndex] = msg.copyWith(isStarred: !msg.isStarred);
                              });
                              _saveToStorage();
                            },
                          ),
                          // Pin
                          _ActionTile(
                            icon: msg.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                            label: msg.isPinned ? 'Unpin' : 'Pin',
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() {
                                // Unpin old
                                for (int i = 0; i < _messages.length; i++) {
                                  if (_messages[i].isPinned) {
                                    _messages[i] = _messages[i].copyWith(isPinned: false);
                                  }
                                }
                                if (!msg.isPinned) {
                                  _messages[messageIndex] = msg.copyWith(isPinned: true);
                                  _pinnedMessage = _messages[messageIndex];
                                } else {
                                  _pinnedMessage = null;
                                }
                              });
                              _saveToStorage();
                            },
                          ),
                          // Delete / Unsend
                          _ActionTile(
                            icon: Icons.delete_outline,
                            label: 'Delete',
                            iconColor: Colors.red,
                            labelColor: Colors.red,
                            onTap: () {
                              Navigator.pop(ctx);
                              _showDeleteOptions(context, messageIndex, msg);
                            },
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Delete / Unsend dialog ───────────────────────────────────
  void _showDeleteOptions(BuildContext context, int index, ChatMessage msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Message?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (msg.isMine) ...[
              ListTile(
                title: const Text('Unsend', style: TextStyle(color: Colors.redAccent)),
                subtitle: const Text('Remove for everyone', style: TextStyle(color: Colors.grey, fontSize: 12)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showUnsendConfirm(context, index, msg);
                },
              ),
              const Divider(color: Colors.grey),
            ],
            ListTile(
              title: const Text('Delete for me', style: TextStyle(color: Colors.white)),
              subtitle: const Text('Only remove from your side', style: TextStyle(color: Colors.grey, fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirm(context, index);
              },
            ),
            const Divider(color: Colors.grey),
            ListTile(
              title: const Text('Cancel', style: TextStyle(color: Colors.blue)),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Do you want to delete this message?', style: TextStyle(color: Colors.white, fontSize: 16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No', style: TextStyle(color: Colors.blue))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _messages[index] = _messages[index].copyWith(isDeleted: true));
              _saveToStorage();
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showUnsendConfirm(BuildContext context, int index, ChatMessage msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Do you want to unsend this message?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const Text('This will remove the message for everyone.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No', style: TextStyle(color: Colors.blue))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _messages[index] = _messages[index].copyWith(isUnsent: true));
              _saveToStorage();
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Message Info Screen ──────────────────────────────────────
  void _showMessageInfo(BuildContext context, ChatMessage msg) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => MessageInfoScreen(message: msg, peerName: widget.username, peerAvatar: widget.avatarUrl)));
  }

  // ── Forward Screen ───────────────────────────────────────────
  void _openForwardScreen(BuildContext context, ChatMessage msg) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ForwardMessageScreen(message: msg)));
  }

  // ── Full Emoji Reaction Picker ───────────────────────────────
  void _showFullEmojiReactionPicker(BuildContext context, int messageIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: 380,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const Padding(padding: EdgeInsets.all(12), child: Text('Choose a Reaction', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
                itemCount: (_emojiCategories[1]['emojis'] as List<String>).length,
                itemBuilder: (context, i) {
                  final emoji = (_emojiCategories[1]['emojis'] as List<String>)[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleReaction(messageIndex, emoji);
                    },
                    child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleReaction(int messageIndex, String emoji) {
    setState(() {
      final msg = _messages[messageIndex];
      final Map<String, List<String>> newReactions = Map.from(msg.reactions.map((k, v) => MapEntry(k, List<String>.from(v))));
      if (newReactions[emoji] == null) {
        newReactions[emoji] = ['me'];
      } else if (newReactions[emoji]!.contains('me')) {
        newReactions[emoji]!.remove('me');
        if (newReactions[emoji]!.isEmpty) newReactions.remove(emoji);
      } else {
        newReactions[emoji]!.add('me');
      }
      _messages[messageIndex] = msg.copyWith(reactions: newReactions);
    });
    _saveToStorage();
  }

  // ── Save Image/Video to Gallery ──────────────────────────────
  Future<void> _saveMediaToGallery(String url, bool isVideo) async {
    try {
      PermissionStatus status;
      if (Theme.of(context).platform == TargetPlatform.android) {
        status = await Permission.storage.request();
      } else {
        status = await Permission.photos.request();
      }
      if (!status.isGranted) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Storage permission required to save media.')));
        return;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isVideo ? 'Saving video...' : 'Saving image...')));
      final response = await http.get(Uri.parse(url));
      final result = await ImageGallerySaverPlus.saveImage(response.bodyBytes, quality: 100, name: 'wego_${DateTime.now().millisecondsSinceEpoch}');
      if (mounted) {
        final bool success = result['isSuccess'] ?? false;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(success ? (isVideo ? 'Video saved to gallery! 🎬' : 'Image saved to gallery! 📸') : 'Failed to save. Try again.'),
          backgroundColor: success ? Colors.green : Colors.red,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    }
  }

  // ── Sticker Long Press Popup (received) ─────────────────────
  void _showReceivedStickerPopup(BuildContext context, String stickerUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Image.network(stickerUrl, width: 100, height: 100, fit: BoxFit.contain)),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StickerActionButton(
                      icon: _isStickerFavorite(stickerUrl) ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFFFC107),
                      label: _isStickerFavorite(stickerUrl) ? 'Remove\nSticker' : 'Add to\nFavorite',
                      onTap: () {
                        Navigator.pop(ctx);
                        _toggleStickerFavorite(stickerUrl);
                      },
                    ),
                    _StickerActionButton(
                      icon: Icons.edit_rounded,
                      color: kTeal,
                      label: 'Edit\nSticker',
                      onTap: () {
                        Navigator.pop(ctx);
                        _openStickerEditor(context, stickerUrl);
                      },
                    ),
                    _StickerActionButton(
                      icon: Icons.send_rounded,
                      color: kPurple,
                      label: 'Send\nSticker',
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendMessage(type: MsgType.sticker, imageUrl: stickerUrl);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isStickerFavorite(String url) {
    return (_stickerCategories[0]['stickers'] as List).contains(url);
  }

  void _toggleStickerFavorite(String stickerUrl) {
    final List<String> favorites = List<String>.from(_stickerCategories[0]['stickers'] as List);
    if (favorites.contains(stickerUrl)) {
      setState(() {
        (_stickerCategories[0]['stickers'] as List).remove(stickerUrl);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sticker removed from Favorites'), duration: Duration(seconds: 2)));
    } else {
      setState(() {
        (_stickerCategories[0]['stickers'] as List).add(stickerUrl);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⭐ Sticker added to Favorites!'), backgroundColor: Color(0xFFFFC107), duration: Duration(seconds: 2)));
    }
    _saveToStorage();
  }

  void _openStickerEditor(BuildContext context, String stickerUrl) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => StickerEditorScreen(stickerUrl: stickerUrl)));
  }

  // ── 3-Dot Menu ───────────────────────────────────────────────
  void _show3DotMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.only(top: 8, bottom: 4), width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
              // Edit Nickname
              _SettingsTile(
                icon: Icons.edit,
                label: 'Edit Nickname',
                onTap: () { Navigator.pop(ctx); _showEditNicknameDialog(context); },
              ),
              // Follow
              SwitchListTile(
                secondary: const Icon(Icons.person_add_outlined, color: kPurple),
                title: const Text('Follow'),
                value: _followEnabled,
                activeColor: kPurple,
                onChanged: (v) { setState(() => _followEnabled = v); _saveUserSettings(); },
              ),
              // Pin on Top
              SwitchListTile(
                secondary: const Icon(Icons.push_pin_outlined, color: kPurple),
                title: const Text('Put on "Top of Talk List"'),
                value: _pinOnTopEnabled,
                activeColor: kPurple,
                onChanged: (v) { setState(() => _pinOnTopEnabled = v); _saveUserSettings(); },
              ),
              // Message Bubble (VIP)
              _SettingsTile(
                icon: Icons.chat_bubble_outline,
                label: 'Message Bubble',
                trailing: const _VIPBadge(),
                onTap: () { Navigator.pop(ctx); _showBubbleStylePicker(context); },
              ),
              // Auto Translation (VIP)
              Row(
                children: [
                  const Padding(padding: EdgeInsets.only(left: 16), child: Icon(Icons.translate, color: kPurple)),
                  const SizedBox(width: 16),
                  const Expanded(child: Text('Auto Translation')),
                  const _VIPBadge(),
                  Switch(
                    value: _autoTranslateEnabled,
                    activeColor: kPurple,
                    onChanged: (v) {
                      if (!_isVIP) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This is a VIP feature. Upgrade to unlock!')));
                        return;
                      }
                      setState(() => _autoTranslateEnabled = v);
                      _saveUserSettings();
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              const Divider(),
              // Block
              ListTile(
                leading: Icon(Icons.block, color: _isBlocked ? Colors.red : Colors.grey),
                title: Text(_isBlocked ? 'Unblock' : 'Block', style: TextStyle(color: _isBlocked ? Colors.red : null)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBlockDialog(context);
                },
              ),
              // Report
              _SettingsTile(
                icon: Icons.flag_outlined,
                label: 'Report',
                iconColor: Colors.orange,
                onTap: () { Navigator.pop(ctx); _showReportDialog(context); },
              ),
              // Clear Chat History
              ListTile(
                title: const Text('Clear Chat History', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showClearChatDialog(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditNicknameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: _nickname);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Nickname'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Enter nickname')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() => _nickname = ctrl.text.isEmpty ? widget.username : ctrl.text);
              _saveUserSettings();
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBubbleStylePicker(BuildContext context) {
    if (!_isVIP) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This is a VIP feature. Upgrade to unlock!')));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['default', 'rounded', 'sharp', 'cloud'].map((style) => ListTile(
            title: Text(style.toUpperCase()),
            leading: Radio<String>(value: style, groupValue: _selectedBubbleStyle, onChanged: (v) {
              setState(() => _selectedBubbleStyle = v!);
              _saveUserSettings();
              Navigator.pop(ctx);
            }),
          )).toList(),
        ),
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_isBlocked ? 'Unblock User?' : 'Block User?', style: const TextStyle(color: Colors.white)),
        content: Text(_isBlocked ? 'Do you want to unblock ${widget.username}?' : 'Do you want to block ${widget.username}?', style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No', style: TextStyle(color: Colors.blue))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isBlocked = !_isBlocked);
              _saveUserSettings();
              if (_isBlocked) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${widget.username} has been blocked')));
              }
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report User'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['Spam', 'Harassment', 'Inappropriate Content', 'Fake Profile'].map((reason) => ListTile(
            title: Text(reason),
            onTap: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reported for: $reason')));
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showClearChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Chat History?', style: TextStyle(color: Colors.white)),
        content: const Text('This will permanently delete all messages in this chat for you.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.blue))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() { _messages.clear(); _pinnedMessage = null; });
              _saveToStorage();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat cleared')));
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Voice Recording ──────────────────────────────────────────
  void _startRecording() {
    setState(() {
      _isRecording = true;
      _voiceLocked = false;
      _voicePaused = false;
      _recordingDuration = Duration.zero;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_voicePaused) {
        setState(() => _recordingDuration += const Duration(seconds: 1));
      }
    });
  }

  void _stopRecording({bool send = true}) {
    _recordingTimer?.cancel();
    if (send && _recordingDuration.inSeconds > 0) {
      final dur = _recordingDuration;
      _sendMessage(type: MsgType.voice, text: 'Voice Message (${_formatDuration(dur)})');
    }
    setState(() {
      _isRecording = false;
      _voiceLocked = false;
      _voicePaused = false;
      _recordingDuration = Duration.zero;
    });
  }

  void _pauseResumeRecording() {
    setState(() => _voicePaused = !_voicePaused);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ── Panel Builder ────────────────────────────────────────────
  Widget _buildWhatsAppPanel() {
    return Container(
      height: 320,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildPanelTab(0, Icons.emoji_emotions_outlined, "Emoji"),
                const SizedBox(width: 40),
                _buildPanelTab(1, Icons.gif_box_outlined, "GIF"),
                const SizedBox(width: 40),
                _buildPanelTab(2, Icons.sticky_note_2_outlined, "Sticker"),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Container(
              height: 36,
              decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(18)),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (value) {
                  setState(() {
                    _emojiSearchQuery = value;
                    _stickerSearchQuery = value;
                    _gifSearchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search Emojis, Stickers, GIFs...',
                  hintStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                  suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() { _emojiSearchQuery = ""; _stickerSearchQuery = ""; _gifSearchQuery = ""; });
                    },
                  ) : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                ),
              ),
            ),
          ),
          Expanded(
            child: _activeMainTab == 0 ? _buildEmojiSection() : (_activeMainTab == 1 ? _buildGifSection() : _buildStickerSection()),
          ),
          _buildBottomABCBar(),
        ],
      ),
    );
  }

  Widget _buildPanelTab(int index, IconData icon, String label) {
    bool isSelected = _activeMainTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeMainTab = index),
      child: Column(
        children: [
          Icon(icon, color: isSelected ? kPurple : Colors.grey, size: 24),
          if (isSelected) Container(margin: const EdgeInsets.only(top: 4), width: 20, height: 2, color: kPurple),
        ],
      ),
    );
  }

  Widget _buildEmojiSection() {
    List<String> emojisToShow = _emojiCategories[_emojiCategoryIndex]['emojis'];
    if (_emojiSearchQuery.isNotEmpty) {
      emojisToShow = emojisToShow.where((e) => e.contains(_emojiSearchQuery)).toList();
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
      itemCount: emojisToShow.length,
      itemBuilder: (context, i) => Center(
        child: GestureDetector(
          onTap: () => setState(() => _msgCtrl.text += emojisToShow[i]),
          child: Text(emojisToShow[i], style: const TextStyle(fontSize: 28)),
        ),
      ),
    );
  }

  Widget _buildGifSection() {
    List<String> gifsToShow = _gifUrls;
    if (_gifSearchQuery.isNotEmpty) {
      gifsToShow = _gifUrls.where((url) => url.toLowerCase().contains(_gifSearchQuery.toLowerCase())).toList();
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 1.6, crossAxisSpacing: 8, mainAxisSpacing: 8),
      itemCount: gifsToShow.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => _sendMessage(type: MsgType.gif, imageUrl: gifsToShow[i]),
        child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(gifsToShow[i], fit: BoxFit.cover)),
      ),
    );
  }

  Widget _buildStickerSection() {
    List<String> stickers = List<String>.from(_stickerCategories[_stickerCategoryIndex]['stickers'] as List);
    if (_stickerSearchQuery.isNotEmpty) {
      List<String> allStickers = [];
      for (var category in _stickerCategories) { allStickers.addAll(List<String>.from(category['stickers'] as List)); }
      stickers = allStickers.where((url) => url.toLowerCase().contains(_stickerSearchQuery.toLowerCase())).toList();
    }
    return Column(
      children: [
        if (_stickerSearchQuery.isEmpty)
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _stickerCategories.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _stickerCategoryIndex = i),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _stickerCategoryIndex == i ? kPurple.withOpacity(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_stickerCategories[i]['icon'], color: _stickerCategoryIndex == i ? kPurple : Colors.grey, size: 24),
                      ),
                      if (_stickerCategoryIndex == i) Container(margin: const EdgeInsets.only(top: 4), width: 4, height: 4, decoration: const BoxDecoration(color: kPurple, shape: BoxShape.circle)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: stickers.length,
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => _showStickerMenu(context, stickers[i]),
              child: Image.network(stickers[i], fit: BoxFit.contain),
            ),
          ),
        ),
      ],
    );
  }

  void _showStickerMenu(BuildContext context, String stickerUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(margin: const EdgeInsets.only(top: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StickerActionButton(
                      icon: _isStickerFavorite(stickerUrl) ? Icons.star_rounded : Icons.star_border_rounded,
                      color: const Color(0xFFFFC107),
                      label: _isStickerFavorite(stickerUrl) ? 'Remove\nSticker' : 'Add to\nFavorite',
                      onTap: () { Navigator.pop(context); _toggleStickerFavorite(stickerUrl); },
                    ),
                    _StickerActionButton(
                      icon: Icons.edit_rounded,
                      color: kTeal,
                      label: 'Edit\nSticker',
                      onTap: () { Navigator.pop(context); _openStickerEditor(context, stickerUrl); },
                    ),
                    _StickerActionButton(
                      icon: Icons.send_rounded,
                      color: kPurple,
                      label: 'Send\nSticker',
                      onTap: () { Navigator.pop(context); _sendMessage(type: MsgType.sticker, imageUrl: stickerUrl); },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomABCBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () { setState(() => _showPanel = false); FocusScope.of(context).requestFocus(FocusNode()); },
            child: const Text("ABC", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          ...List.generate(
            _emojiCategories.length,
                (i) => IconButton(
              icon: Icon(_emojiCategories[i]['icon'], size: 20, color: _emojiCategoryIndex == i ? kPurple : Colors.grey),
              onPressed: () => setState(() => _emojiCategoryIndex = i),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.backspace_outlined, size: 20, color: Colors.grey),
            onPressed: () {
              if (_msgCtrl.text.isNotEmpty) {
                _msgCtrl.text = _msgCtrl.text.substring(0, _msgCtrl.text.length - 1);
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            if (_pinnedMessage != null) _buildPinnedBanner(),
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  // Add date separator if this is the first message or date changed
                  bool showDateSeparator = false;
                  if (index == 0) {
                    showDateSeparator = true;
                  } else {
                    final currentMsg = _messages[index];
                    final previousMsg = _messages[index - 1];
                    if (currentMsg.dateTime != null && previousMsg.dateTime != null) {
                      final currentDate = DateTime(currentMsg.dateTime!.year, currentMsg.dateTime!.month, currentMsg.dateTime!.day);
                      final previousDate = DateTime(previousMsg.dateTime!.year, previousMsg.dateTime!.month, previousMsg.dateTime!.day);
                      showDateSeparator = currentDate.isAfter(previousDate);
                    }
                  }
                  
                  return Column(
                    children: [
                      if (showDateSeparator) _buildDateSeparator(_messages[index].dateTime),
                      _buildMessageItem(_messages[index], index, isDark),
                    ],
                  );
                },
              ),
            ),
            if (_isTyping) _buildTypingIndicator(),
            if (_replyingTo != null) _buildReplyPreview(),
            if (_showPanel) _buildWhatsAppPanel(),
            _isRecording ? _buildVoiceRecordingBar(isDark) : _buildInputBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSeparator(DateTime? dateTime) {
    if (dateTime == null) return const SizedBox.shrink();
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String dateText;
    if (messageDate.isAtSameMomentAs(today)) {
      dateText = 'Today';
    } else {
      final yesterday = today.subtract(const Duration(days: 1));
      if (messageDate.isAtSameMomentAs(yesterday)) {
        dateText = 'Yesterday';
      } else {
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        dateText = '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
      }
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateText,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          ClipOval(child: Image.network(widget.avatarUrl, width: 28, height: 28, fit: BoxFit.cover)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                _TypingDot(delay: 0),
                const SizedBox(width: 4),
                _TypingDot(delay: 150),
                const SizedBox(width: 4),
                _TypingDot(delay: 300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinnedBanner() {
    return GestureDetector(
      onTap: () {
        // Scroll to pinned message
        final idx = _messages.indexWhere((m) => m.isPinned);
        if (idx >= 0 && _scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            idx * 80.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      },
      child: Container(
        color: kPurple.withOpacity(0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.push_pin, size: 16, color: kPurple),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _pinnedMessage?.text ?? '[${_pinnedMessage?.type.name ?? 'message'}]',
                style: const TextStyle(fontSize: 13, color: kPurple),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  final idx = _messages.indexWhere((m) => m.isPinned);
                  if (idx >= 0) _messages[idx] = _messages[idx].copyWith(isPinned: false);
                  _pinnedMessage = null;
                });
                _saveToStorage();
              },
              child: const Icon(Icons.close, size: 16, color: kPurple),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      color: kPurple.withOpacity(0.06),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(width: 3, height: 36, color: kPurple, margin: const EdgeInsets.only(right: 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_replyingTo!.isMine ? 'You' : widget.username, style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold, fontSize: 12)),
                Text(
                  _replyingTo!.text ?? '[${_replyingTo!.type.name}]',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _replyingTo = null)),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      color: kPurple,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), onPressed: () => Navigator.pop(context)),
          GestureDetector(
            onTap: () {/* Open profile */},
            child: ClipOval(child: Image.network(widget.avatarUrl, width: 40, height: 40, fit: BoxFit.cover)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nickname, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                Text(
                  _isTyping ? 'typing...' : (_isUserOnline ? 'Online' : 'Last seen recently'),
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
          // Voice call (only if followed back)
          if (widget.isFollowedBack)
            IconButton(
              icon: const Icon(Icons.call_outlined, color: Colors.white),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceCallScreen(username: _nickname, avatarUrl: widget.avatarUrl))),
            ),
          // Video call (only if followed back)
          if (widget.isFollowedBack)
            IconButton(
              icon: const Icon(Icons.videocam_outlined, color: Colors.white),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VideoCallScreen(username: _nickname, avatarUrl: widget.avatarUrl))),
            ),
          // 3-dot menu
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _show3DotMenu(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage msg, int index, bool isDark) {
    // Unsent: show for everyone
    if (msg.isUnsent) {
      return _UnsentBubble(isMine: msg.isMine, time: msg.time);
    }
    // Deleted: hide completely
    if (msg.isDeleted) {
      return const SizedBox.shrink();
    }

    Widget bubble;
    if (msg.isMine) {
      bubble = _MyBubble(
        message: msg,
        onLongPress: () => _showMessageOptions(context, index),
        onSave: (msg.type == MsgType.image || msg.type == MsgType.gif || msg.type == MsgType.video) && msg.imageUrl != null
            ? () => _saveMediaToGallery(msg.imageUrl!, msg.type == MsgType.video)
            : null,
        bubbleStyle: _selectedBubbleStyle,
      );
    } else {
      switch (msg.type) {
        case MsgType.image:
          bubble = _TheirImageMessage(message: msg, onLongPress: () => _showMessageOptions(context, index), onSave: () => _saveMediaToGallery(msg.imageUrl!, false));
          break;
        case MsgType.sticker:
        case MsgType.gif:
          bubble = _TheirStickerMessage(
            message: msg,
            onTap: () => _showReceivedStickerPopup(context, msg.imageUrl!),
            onLongPress: () => _showMessageOptions(context, index),
          );
          break;
        default:
          bubble = _TheirTextBubble(message: msg, isDark: isDark, onLongPress: () => _showMessageOptions(context, index));
      }
    }

    return Column(
      crossAxisAlignment: msg.isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        // Reply header
        if (msg.replyToText != null)
          Padding(
            padding: EdgeInsets.only(left: msg.isMine ? 0 : 44, right: msg.isMine ? 8 : 0, bottom: 2),
            child: _ReplyHeader(text: msg.replyToText!, isMine: msg.isMine, senderName: msg.isMine ? 'You' : widget.username),
          ),
        bubble,
        if (msg.reactions.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 8, left: msg.isMine ? 0 : 44, right: msg.isMine ? 8 : 0),
            child: _ReactionRow(reactions: msg.reactions, isMine: msg.isMine),
          ),
      ],
    );
  }

  Widget _buildInputBar(bool isDark) {
    if (_isBlocked) {
      return Container(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[200],
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(child: ElevatedButton(onPressed: () => _showBlockDialog(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: const Text('Unblock', style: TextStyle(color: Colors.white)))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () => _showClearChatDialog(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))), child: const Text('Delete Chat', style: TextStyle(color: Colors.white)))),
          ],
        ),
      );
    }
    return Container(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.emoji_emotions_outlined, color: _showPanel ? kPurple : Colors.grey),
            onPressed: () {
              setState(() => _showPanel = !_showPanel);
              if (_showPanel) SystemChannels.textInput.invokeMethod('TextInput.hide');
            },
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.white, borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _msgCtrl,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: const InputDecoration(hintText: 'Message...', border: InputBorder.none),
                onTap: () => setState(() => _showPanel = false),
                onSubmitted: (_) => _sendMessage(),
                onChanged: (v) {
                  setState(() {});
                  // Simulate typing indicator to other user
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          _msgCtrl.text.isEmpty
              ? GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecording(),
            onVerticalDragUpdate: (details) {
              if (details.delta.dy < -5 && _isRecording) {
                setState(() => _voiceLocked = true);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: kPurple, shape: BoxShape.circle),
              child: const Icon(Icons.mic, color: Colors.white, size: 22),
            ),
          )
              : IconButton(icon: const Icon(Icons.send, color: kPurple), onPressed: () => _sendMessage()),
        ],
      ),
    );
  }

  Widget _buildVoiceRecordingBar(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          // Delete
          GestureDetector(
            onTap: () => _stopRecording(send: false),
            child: const Icon(Icons.delete_outline, color: Colors.red, size: 28),
          ),
          const SizedBox(width: 8),
          // Waveform + timer
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.white, borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(_formatDuration(_recordingDuration), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(child: _WaveformWidget()),
                  if (_voiceLocked)
                    GestureDetector(
                      onTap: _pauseResumeRecording,
                      child: Icon(_voicePaused ? Icons.play_arrow : Icons.pause, color: kPurple, size: 22),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Lock icon (swipe up to lock)
          if (!_voiceLocked)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                Icon(Icons.keyboard_arrow_up, color: Colors.grey, size: 16),
              ],
            ),
          // Send
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _stopRecording(send: true),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: kPurple, shape: BoxShape.circle),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reply Header Widget ───────────────────────────────────────
class _ReplyHeader extends StatelessWidget {
  final String text;
  final bool isMine;
  final String senderName;
  const _ReplyHeader({required this.text, required this.isMine, required this.senderName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kPurple.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: const Border(left: BorderSide(color: kPurple, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(senderName, style: const TextStyle(color: kPurple, fontWeight: FontWeight.bold, fontSize: 11)),
          Text(text, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

// ── Reaction Row Widget ───────────────────────────────────────
class _ReactionRow extends StatelessWidget {
  final Map<String, List<String>> reactions;
  final bool isMine;
  const _ReactionRow({required this.reactions, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
      spacing: 4,
      children: reactions.entries.map((entry) {
        final emoji = entry.key;
        final count = entry.value.length;
        final iReacted = entry.value.contains('me');
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: iReacted ? kPurple.withOpacity(0.15) : Colors.grey.withOpacity(0.15),
            border: Border.all(color: iReacted ? kPurple.withOpacity(0.4) : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              if (count > 1) ...[
                const SizedBox(width: 3),
                Text('$count', style: TextStyle(fontSize: 12, color: iReacted ? kPurple : Colors.grey[600])),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Sticker Action Button ─────────────────────────────────────
class _StickerActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _StickerActionButton({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Action Tile ───────────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  const _ActionTile({required this.icon, required this.label, required this.onTap, this.iconColor, this.labelColor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.white70, size: 22),
      title: Text(label, style: TextStyle(color: labelColor ?? Colors.white, fontSize: 15)),
      onTap: onTap,
      dense: true,
    );
  }
}

// ── Settings Tile ─────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Widget? trailing;
  const _SettingsTile({required this.icon, required this.label, required this.onTap, this.iconColor, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? kPurple),
      title: Text(label),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

// ── VIP Badge ─────────────────────────────────────────────────
class _VIPBadge extends StatelessWidget {
  const _VIPBadge();
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6)),
      child: const Text('VIP', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ── Deleted / Unsent Bubble ───────────────────────────────────
class _DeletedBubble extends StatelessWidget {
  final bool isMine;
  final String time;
  const _DeletedBubble({required this.isMine, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(left: isMine ? 0 : 44, right: isMine ? 8 : 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.not_interested, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              const Text('This message was deleted', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnsentBubble extends StatelessWidget {
  final bool isMine;
  final String time;
  const _UnsentBubble({required this.isMine, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(left: isMine ? 0 : 44, right: isMine ? 8 : 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.not_interested, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(isMine ? 'You unsent a message' : 'This message was unsent', style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── My Bubble ─────────────────────────────────────────────────
class _MyBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onLongPress;
  final VoidCallback? onSave;
  final String bubbleStyle;
  const _MyBubble({required this.message, required this.onLongPress, this.onSave, this.bubbleStyle = 'default'});

  BorderRadius get _borderRadius {
    switch (bubbleStyle) {
      case 'rounded': return BorderRadius.circular(24);
      case 'sharp': return BorderRadius.circular(4);
      case 'cloud': return const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20), bottomLeft: Radius.circular(20), bottomRight: Radius.circular(2));
      default: return const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(2));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (message.isStarred) const Padding(padding: EdgeInsets.only(right: 4), child: Icon(Icons.star, size: 14, color: Colors.amber)),
                if (message.type == MsgType.sticker || message.type == MsgType.gif)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Image.network(message.imageUrl!, width: 150, height: 150, fit: BoxFit.contain),
                      if (onSave != null) _SaveButton(onSave: onSave!),
                    ],
                  )
                else if (message.type == MsgType.image)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(message.imageUrl!, height: 180, width: 200, fit: BoxFit.cover)),
                      if (onSave != null) _SaveButton(onSave: onSave!),
                    ],
                  )
                else if (message.type == MsgType.voice)
                    _VoiceBubble(message: message, isMine: true)
                  else
                    Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: kTeal, borderRadius: _borderRadius),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(message.text ?? '', style: const TextStyle(color: Colors.white, fontSize: 15)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(message.time, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                              const SizedBox(width: 4),
                              _buildStatus(),
                            ],
                          ),
                        ],
                      ),
                    ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(message.time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                const SizedBox(width: 4),
                _buildStatus(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus() {
    if (message.status == MsgStatus.sent) return const Icon(Icons.check, size: 14, color: Colors.grey);
    if (message.status == MsgStatus.delivered) return const Icon(Icons.done_all, size: 14, color: Colors.grey);
    return const Icon(Icons.done_all, size: 14, color: Colors.blue);
  }
}

// ── Voice Bubble ──────────────────────────────────────────────
class _VoiceBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  const _VoiceBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMine ? kTeal : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow, color: isMine ? Colors.white : kPurple, size: 28),
          const SizedBox(width: 8),
          Flexible(child: _WaveformWidget(isMini: true)),
          const SizedBox(width: 8),
          Text(message.text?.replaceAll('Voice Message ', '') ?? '0:00', style: TextStyle(color: isMine ? Colors.white70 : Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Their Text Bubble ─────────────────────────────────────────
class _TheirTextBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final VoidCallback onLongPress;
  const _TheirTextBubble({required this.message, required this.isDark, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipOval(child: Image.network(message.avatarUrl ?? 'https://i.pravatar.cc/150', width: 32, height: 32, fit: BoxFit.cover)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey.shade100,
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomRight: Radius.circular(18), bottomLeft: Radius.circular(4)),
                  ),
                  child: message.type == MsgType.voice
                      ? _VoiceBubble(message: message, isMine: false)
                      : Text(message.text ?? '', style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                ),
                const SizedBox(height: 4),
                Text(message.time, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TheirStickerMessage extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  const _TheirStickerMessage({required this.message, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipOval(child: Image.network(message.avatarUrl ?? 'https://i.pravatar.cc/150', width: 32, height: 32, fit: BoxFit.cover)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(message.imageUrl!, width: 120, height: 120),
                const SizedBox(height: 4),
                Text(message.time, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TheirImageMessage extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onLongPress;
  final VoidCallback onSave;
  const _TheirImageMessage({required this.message, required this.onLongPress, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipOval(child: Image.network(message.avatarUrl ?? 'https://i.pravatar.cc/150', width: 32, height: 32, fit: BoxFit.cover)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(message.imageUrl!, height: 180, width: 200, fit: BoxFit.cover)),
                _SaveButton(onSave: onSave),
                const SizedBox(height: 4),
                Text(message.time, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Save Button ───────────────────────────────────────────────
class _SaveButton extends StatelessWidget {
  final VoidCallback onSave;
  const _SaveButton({required this.onSave});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSave,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: kPurple.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kPurple.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.download_rounded, size: 14, color: kPurple),
            SizedBox(width: 4),
            Text('Save', style: TextStyle(fontSize: 12, color: kPurple, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Waveform Widget ───────────────────────────────────────────
class _WaveformWidget extends StatefulWidget {
  final bool isMini;
  const _WaveformWidget({this.isMini = false});

  @override
  State<_WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<_WaveformWidget> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.isMini ? 8 : 20, (i) {
          final h = (10 + (i % 4 + 1) * 6 * (_ctrl.value + 0.3)).clamp(4.0, 28.0);
          return Container(
            width: widget.isMini ? 2 : 3,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(color: kPurple.withOpacity(0.7), borderRadius: BorderRadius.circular(2)),
          );
        }),
      ),
    );
  }
}

// ── Typing Dot ────────────────────────────────────────────────
class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});
  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: -6).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () { if (mounted) _ctrl.repeat(reverse: true); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.grey[500], shape: BoxShape.circle)),
      ),
    );
  }
}

// ── Message Info Screen ───────────────────────────────────────
class MessageInfoScreen extends StatelessWidget {
  final ChatMessage message;
  final String peerName;
  final String peerAvatar;
  const MessageInfoScreen({super.key, required this.message, required this.peerName, required this.peerAvatar});

  @override
  Widget build(BuildContext context) {
    final dt = message.dateTime ?? DateTime.now();
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final dateStr = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    final timeStr = message.time;

    return Scaffold(
      appBar: AppBar(backgroundColor: kPurple, title: const Text('Message Info', style: TextStyle(color: Colors.white)), leading: const BackButton(color: Colors.white)),
      body: Column(
        children: [
          const SizedBox(height: 24),
          // Preview of the message
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: message.isMine ? kTeal.withOpacity(0.15) : Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.type == MsgType.image && message.imageUrl != null)
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(message.imageUrl!, height: 140, fit: BoxFit.cover)),
                  if (message.type == MsgType.sticker && message.imageUrl != null)
                    Image.network(message.imageUrl!, height: 100),
                  if (message.text != null && message.text!.isNotEmpty)
                    Text(message.text!, style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 8),
                  Text(
                    '${_msgTypeLabel(message.type)} • ${message.isMine ? "Sent" : "Received"}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Details
          _InfoRow(icon: Icons.access_time, label: 'Time', value: timeStr),
          _InfoRow(icon: Icons.calendar_today, label: 'Date', value: dateStr),
          _InfoRow(icon: Icons.category_outlined, label: 'Type', value: _msgTypeLabel(message.type)),
          if (message.isMine) _InfoRow(icon: Icons.done_all, label: 'Status', value: _statusLabel(message.status), valueColor: message.status == MsgStatus.seen ? Colors.blue : Colors.grey),
          if (message.isStarred) _InfoRow(icon: Icons.star, label: 'Starred', value: 'Yes', iconColor: Colors.amber),
        ],
      ),
    );
  }

  String _msgTypeLabel(MsgType t) {
    switch (t) {
      case MsgType.text: return 'Text';
      case MsgType.image: return 'Image';
      case MsgType.sticker: return 'Sticker';
      case MsgType.voice: return 'Voice Message';
      case MsgType.video: return 'Video';
      case MsgType.gif: return 'GIF';
      default: return 'Message';
    }
  }

  String _statusLabel(MsgStatus s) {
    switch (s) {
      case MsgStatus.sent: return 'Sent ✓';
      case MsgStatus.delivered: return 'Delivered ✓✓';
      case MsgStatus.seen: return 'Seen ✓✓';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color? iconColor;
  const _InfoRow({required this.icon, required this.label, required this.value, this.valueColor, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor ?? kPurple),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
          const Spacer(),
          Text(value, style: TextStyle(color: valueColor ?? Colors.grey, fontSize: 15)),
        ],
      ),
    );
  }
}

// ── Forward Message Screen ────────────────────────────────────
class ForwardMessageScreen extends StatefulWidget {
  final ChatMessage message;
  const ForwardMessageScreen({super.key, required this.message});

  @override
  State<ForwardMessageScreen> createState() => _ForwardMessageScreenState();
}

class _ForwardMessageScreenState extends State<ForwardMessageScreen> {
  final List<Map<String, String>> _contacts = [
    {'name': 'Ayesha', 'avatar': 'https://i.pravatar.cc/150?img=1'},
    {'name': 'Noori', 'avatar': 'https://i.pravatar.cc/150?img=2'},
    {'name': 'Hashim', 'avatar': 'https://i.pravatar.cc/150?img=3'},
    {'name': 'Sonia', 'avatar': 'https://i.pravatar.cc/150?img=4'},
    {'name': 'Zara', 'avatar': 'https://i.pravatar.cc/150?img=5'},
  ];
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPurple,
        leading: const BackButton(color: Colors.white),
        title: const Text('Forward to', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          // Message preview
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.forward, color: kPurple, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.message.text ?? '[${widget.message.type.name}]',
                    style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Align(alignment: Alignment.centerLeft, child: Text('Recent chats', style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(
            child: ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (context, i) {
                final c = _contacts[i];
                return CheckboxListTile(
                  value: _selected.contains(i),
                  onChanged: (v) { setState(() { if (v == true) _selected.add(i); else _selected.remove(i); }); },
                  secondary: ClipOval(child: Image.network(c['avatar']!, width: 44, height: 44, fit: BoxFit.cover)),
                  title: Text(c['name']!),
                  activeColor: kPurple,
                );
              },
            ),
          ),
          if (_selected.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: Text('Send to ${_selected.length} contact${_selected.length > 1 ? 's' : ''}'),
                    style: ElevatedButton.styleFrom(backgroundColor: kPurple, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Message forwarded to ${_selected.length} contact(s)')));
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Sticker Editor Screen ─────────────────────────────────────
class StickerEditorScreen extends StatefulWidget {
  final String stickerUrl;
  const StickerEditorScreen({super.key, required this.stickerUrl});

  @override
  State<StickerEditorScreen> createState() => _StickerEditorScreenState();
}

class _StickerEditorScreenState extends State<StickerEditorScreen> {
  double _scale = 1.0, _rotation = 0.0, _brightness = 1.0;
  String _overlayText = '';
  Color _borderColor = Colors.transparent;
  final TextEditingController _textCtrl = TextEditingController();
  final List<Color> _borderColors = [Colors.transparent, Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.purple, Colors.orange, Colors.pink];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: const Text('Edit Sticker', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sticker saved!'), backgroundColor: Colors.green)); },
            child: const Text('DONE', style: TextStyle(color: kPurple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(width: 280, height: 280, decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.white10)),
                  Transform.scale(scale: _scale, child: Transform.rotate(angle: _rotation, child: Container(
                    decoration: BoxDecoration(border: Border.all(color: _borderColor, width: 4), borderRadius: BorderRadius.circular(12)),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix([_brightness,0,0,0,0,0,_brightness,0,0,0,0,0,_brightness,0,0,0,0,0,1,0]),
                      child: Image.network(widget.stickerUrl, width: 180, height: 180, fit: BoxFit.contain),
                    ),
                  ))),
                  if (_overlayText.isNotEmpty) Positioned(bottom: 40, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                    child: Text(_overlayText, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  )),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(color: Color(0xFF0F0F23), borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24))),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSliderRow(Icons.zoom_in, 'Size', _scale, 0.5, 2.0, (v) => setState(() => _scale = v)),
                const SizedBox(height: 12),
                _buildSliderRow(Icons.rotate_right, 'Rotate', _rotation, -3.14, 3.14, (v) => setState(() => _rotation = v)),
                const SizedBox(height: 12),
                _buildSliderRow(Icons.brightness_6, 'Brightness', _brightness, 0.2, 2.0, (v) => setState(() => _brightness = v)),
                const SizedBox(height: 16),
                const Text('Border Color', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: _borderColors.map((c) {
                  final bool selected = _borderColor == c;
                  return GestureDetector(
                    onTap: () => setState(() => _borderColor = c),
                    child: Container(width: 32, height: 32, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: c == Colors.transparent ? Colors.white24 : c, shape: BoxShape.circle, border: selected ? Border.all(color: Colors.white, width: 2.5) : null), child: c == Colors.transparent ? const Icon(Icons.block, size: 16, color: Colors.white54) : null),
                  );
                }).toList())),
                const SizedBox(height: 16),
                const Text('Add Text', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  height: 40, padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                  child: TextField(controller: _textCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Enter text on sticker...', hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none), onChanged: (v) => setState(() => _overlayText = v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow(IconData icon, String label, double value, double min, double max, ValueChanged<double> onChanged) {
    return Row(children: [
      Icon(icon, color: Colors.white54, size: 18),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      Expanded(child: SliderTheme(
        data: SliderTheme.of(context).copyWith(activeTrackColor: kPurple, inactiveTrackColor: Colors.white12, thumbColor: kPurple, overlayColor: kPurple.withOpacity(0.2)),
        child: Slider(value: value, min: min, max: max, onChanged: onChanged),
      )),
    ]);
  }
}

// ── Voice Call Screen ─────────────────────────────────────────
class VoiceCallScreen extends StatefulWidget {
  final String username;
  final String avatarUrl;
  const VoiceCallScreen({super.key, required this.username, required this.avatarUrl});

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isConnected = false;
  Duration _callDuration = Duration.zero;
  Timer? _callTimer;

  @override
  void initState() {
    super.initState();
    // Simulate connecting after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isConnected = true);
        _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _callDuration += const Duration(seconds: 1));
        });
      }
    });
  }

  @override
  void dispose() { _callTimer?.cancel(); super.dispose(); }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Stack(
        children: [
          // Background pattern
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(colors: [Color(0xFF1A1A3E), Color(0xFF0A0A1A)], radius: 1.5),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Top row: minimize + add participant
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Minimize
                      _CallIconButton(icon: Icons.open_in_new, onTap: () => Navigator.pop(context), tooltip: 'Minimize'),
                      // Add participant
                      _CallIconButton(icon: Icons.person_add_outlined, onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add participant'))), tooltip: 'Add'),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Avatar
                ClipOval(child: Image.network(widget.avatarUrl, width: 120, height: 120, fit: BoxFit.cover)),
                const SizedBox(height: 20),
                Text(widget.username, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  _isConnected ? _formatDuration(_callDuration) : 'Calling...',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                ),
                const Spacer(),
                // Controls row (same order as screenshot)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.08), borderRadius: BorderRadius.circular(40)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 3 dot
                        _CallButton(
                          icon: Icons.more_horiz,
                          onTap: () => _show3DotCallMenu(context),
                          bg: Colors.white.withOpacity(0.15),
                        ),
                        // Video (switch to video)
                        _CallButton(
                          icon: Icons.videocam_outlined,
                          onTap: () => _requestVideoSwitch(context),
                          bg: Colors.white.withOpacity(0.15),
                        ),
                        // Speaker
                        _CallButton(
                          icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_up_outlined,
                          onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                          bg: _isSpeakerOn ? kPurple : Colors.white.withOpacity(0.15),
                        ),
                        // Mute
                        _CallButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic_off_outlined,
                          onTap: () => setState(() => _isMuted = !_isMuted),
                          bg: _isMuted ? Colors.red.shade700 : Colors.white.withOpacity(0.15),
                        ),
                        // End call
                        _CallButton(icon: Icons.call_end, onTap: () => Navigator.pop(context), bg: Colors.red, size: 52),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _show3DotCallMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 8, bottom: 8), width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.message_outlined, color: Colors.white),
              title: const Text('Send Message', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.screen_share_outlined, color: Colors.white),
              title: const Text('Share Screen', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                if (!_isConnected) {
                  showDialog(context: context, builder: (c) => AlertDialog(
                    backgroundColor: const Color(0xFF2C2C2E),
                    content: const Text("You can't share your screen until another person joins the call.", style: TextStyle(color: Colors.white)),
                    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK', style: TextStyle(color: Colors.green)))],
                  ));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Screen sharing started')));
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _requestVideoSwitch(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('Switch to Video Call?', style: TextStyle(color: Colors.white)),
        content: const Text('This will ask the other person to allow video.', style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Requesting video call switch...')));
            },
            child: const Text('Request', style: TextStyle(color: kPurple)),
          ),
        ],
      ),
    );
  }
}

// ── Video Call Screen ─────────────────────────────────────────
class VideoCallScreen extends StatefulWidget {
  final String username;
  final String avatarUrl;
  const VideoCallScreen({super.key, required this.username, required this.avatarUrl});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isFrontCamera = true;
  bool _isConnected = false;
  Duration _callDuration = Duration.zero;
  Timer? _callTimer;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isConnected = true);
        _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _callDuration += const Duration(seconds: 1));
        });
      }
    });
  }

  @override
  void dispose() { _callTimer?.cancel(); super.dispose(); }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (peer) background - show avatar if not connected
          _isConnected
              ? Container(color: const Color(0xFF1A1A2E), child: Center(child: ClipOval(child: Image.network(widget.avatarUrl, width: 120, height: 120, fit: BoxFit.cover))))
              : Container(
            decoration: BoxDecoration(
              image: DecorationImage(image: NetworkImage(widget.avatarUrl), fit: BoxFit.cover),
            ),
            child: Container(color: Colors.black54),
          ),
          // Local video preview (bottom right)
          if (_isConnected)
            Positioned(
              bottom: 120,
              right: 16,
              child: Container(
                width: 90,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(color: Colors.grey[700], child: const Icon(Icons.person, color: Colors.white54, size: 40)),
                ),
              ),
            ),
          SafeArea(
            child: Column(
              children: [
                // Top row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CallIconButton(icon: Icons.open_in_new, onTap: () => Navigator.pop(context), tooltip: 'Minimize'),
                      Column(
                        children: [
                          Text(widget.username, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(_isConnected ? _formatDuration(_callDuration) : 'Calling...', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                        ],
                      ),
                      _CallIconButton(icon: Icons.person_add_outlined, onTap: () {}, tooltip: 'Add'),
                    ],
                  ),
                ),
                const Spacer(),
                // Controls
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(40)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // 3 dot
                        _CallButton(icon: Icons.more_horiz, onTap: () => _show3DotMenu(context), bg: Colors.white.withOpacity(0.2)),
                        // Flip camera
                        _CallButton(
                          icon: Icons.flip_camera_ios_outlined,
                          onTap: () => setState(() => _isFrontCamera = !_isFrontCamera),
                          bg: Colors.white.withOpacity(0.2),
                        ),
                        // Speaker
                        _CallButton(
                          icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                          onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                          bg: _isSpeakerOn ? kPurple : Colors.white.withOpacity(0.2),
                        ),
                        // Mute
                        _CallButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic_off_outlined,
                          onTap: () => setState(() => _isMuted = !_isMuted),
                          bg: _isMuted ? Colors.red.shade700 : Colors.white.withOpacity(0.2),
                        ),
                        // End call
                        _CallButton(icon: Icons.call_end, onTap: () => Navigator.pop(context), bg: Colors.red, size: 52),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _show3DotMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C2E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 8, bottom: 8), width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey[600], borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.message_outlined, color: Colors.white),
              title: const Text('Send Message', style: TextStyle(color: Colors.white)),
              onTap: () { Navigator.pop(ctx); Navigator.pop(context); },
            ),
            ListTile(
              leading: const Icon(Icons.screen_share_outlined, color: Colors.white),
              title: const Text('Share Screen', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                if (!_isConnected) {
                  showDialog(context: context, builder: (c) => AlertDialog(
                    backgroundColor: const Color(0xFF2C2C2E),
                    content: const Text("You can't share your screen until another person joins the call.", style: TextStyle(color: Colors.white)),
                    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK', style: TextStyle(color: Colors.green)))],
                  ));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Screen sharing started')));
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Call Button Widgets ───────────────────────────────────────
class _CallButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color bg;
  final double size;
  const _CallButton({required this.icon, required this.onTap, required this.bg, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }
}

class _CallIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  const _CallIconButton({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
