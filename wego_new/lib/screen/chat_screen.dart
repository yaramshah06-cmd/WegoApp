import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wego_marriage/providers/chat_provider.dart';
import 'package:gal/gal.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:wego_marriage/screen/voice_call_screen.dart';
import 'package:wego_marriage/screen/video_call_screen.dart';
import 'package:wego_marriage/widgets/missed_call_notification.dart';
import 'package:wego_marriage/widgets/call_log_message.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wego_marriage/screen/camera_screen.dart';
import 'package:wego_marriage/screen/gallery_multi_select_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'app_localizations.dart';
import 'app_translations.dart';
// ── Colors ────────────────────────────────────────────────────
const Color kPurple = Color(0xFF6B4EFF);
const Color kTeal = Color(0xFF2EC4B6);

// ── Message Status ─────────────────────────────────────────────
enum MsgStatus { sent, delivered, seen }

// ── Message Type ──────────────────────────────────────────────
enum MsgType {
  text,
  image,
  sticker,
  voice,
  document,
  video,
  gif,
  linkPreview,
  callLog
}

// ── Message Model ─────────────────────────────────────────────
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
  final DateTime? dateTime;
  final String id;
  final String? senderId;
  // Call log fields
  final bool? isVideoCall;
  final bool? isMissedCall;
  final bool? isIncomingCall;
  // Edit support
  final bool isEdited;

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
    this.senderId,
    this.isVideoCall = false,
    this.isMissedCall = false,
    this.isIncomingCall = false,
    this.isEdited = false,
  }) : id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  ChatMessage copyWith({
    String? text,
    Map<String, List<String>>? reactions,
    bool? isStarred,
    bool? isPinned,
    bool? isDeleted,
    bool? isUnsent,
    MsgStatus? status,
    String? replyToText,
    String? replyToType,
    bool? isEdited,
  }) {
    return ChatMessage(
      text: text ?? this.text,
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
      senderId: senderId,
      isVideoCall: isVideoCall,
      isMissedCall: isMissedCall,
      isIncomingCall: isIncomingCall,
      isEdited: isEdited ?? this.isEdited,
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
      'senderId': senderId,
      'isVideoCall': isVideoCall,
      'isMissedCall': isMissedCall,
      'isIncomingCall': isIncomingCall,
      'isEdited': isEdited,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map, String currentUserId) {
    Map<String, List<String>> reactionsMap = {};
    if (map['reactions'] != null && map['reactions'] is Map) {
      (map['reactions'] as Map).forEach((k, v) {
        if (v is List) {
          reactionsMap[k.toString()] = List<String>.from(v);
        }
      });
    }
    final senderId = map['senderId'] as String? ?? '';
    return ChatMessage(
      id: (map['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      text: map['text'] as String?,
      // ✅ isMine: senderId se compare karo, hardcoded nahi
      isMine: senderId == currentUserId,
      type: map['type'] != null &&
          map['type'] is int &&
          map['type'] < MsgType.values.length
          ? MsgType.values[map['type'] as int]
          : MsgType.text,
      imageUrl: map['imageUrl'] as String?,
      avatarUrl: map['avatarUrl'] as String?,
      status: map['status'] != null &&
          map['status'] is int &&
          map['status'] < MsgStatus.values.length
          ? MsgStatus.values[map['status'] as int]
          : MsgStatus.sent,
      time: (map['time'] as String?) ?? '10:00 AM',
      duration: map['duration'] != null && map['duration'] is int
          ? Duration(seconds: map['duration'] as int)
          : null,
      fileName: map['fileName'] as String?,
      fileSize: map['fileSize'] as int?,
      isFavorite: (map['isFavorite'] as bool?) ?? false,
      reactions: reactionsMap,
      isStarred: (map['isStarred'] as bool?) ?? false,
      isPinned: (map['isPinned'] as bool?) ?? false,
      isViewOnce: (map['isViewOnce'] as bool?) ?? false,
      isDeleted: (map['isDeleted'] as bool?) ?? false,
      isUnsent: (map['isUnsent'] as bool?) ?? false,
      replyToText: map['replyToText'] as String?,
      replyToType: map['replyToType'] as String?,
      dateTime: map['dateTime'] != null && map['dateTime'] is int
          ? DateTime.fromMillisecondsSinceEpoch(map['dateTime'] as int)
          : null,
      senderId: senderId,
      isVideoCall: (map['isVideoCall'] as bool?) ?? false,
      isMissedCall: (map['isMissedCall'] as bool?) ?? false,
      isIncomingCall: (map['isIncomingCall'] as bool?) ?? false,
      isEdited: (map['isEdited'] as bool?) ?? false,
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  Firebase Chat Service — sabhi messages Firebase mein jayenge
// ══════════════════════════════════════════════════════════════
class FirebaseChatService {
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  /// Do users ke beech unique chat room ID banao
  /// (alphabetical order taaki dono taraf same ID rahe)
  String getChatRoomId(String uid1, String uid2) {
    final ids = [uid1, uid2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Message Firebase mein save karo
  Future<void> sendMessage({
    required String chatRoomId,
    required Map<String, dynamic> messageData,
  }) async {
    final ref = _db.ref('chats/$chatRoomId/messages').push();
    await ref.set({
      ...messageData,
      'id': ref.key,
      'firebaseKey': ref.key,
    });

    // Last message update karo (chat list ke liye)
    await _db.ref('chats/$chatRoomId/lastMessage').set({
      'text': messageData['text'] ?? '[${MsgType.values[messageData['type'] ?? 0].name}]',
      'time': messageData['time'],
      'senderId': messageData['senderId'],
      'timestamp': ServerValue.timestamp,
    });
  }

  /// Real-time messages stream
  Stream<List<Map<String, dynamic>>> getMessagesStream(String chatRoomId) {
    return _db
        .ref('chats/$chatRoomId/messages')
        .orderByChild('dateTime')
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return [];
      final data = Map<String, dynamic>.from(
          event.snapshot.value as Map);
      final list = data.values
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      list.sort((a, b) =>
          ((a['dateTime'] as int?) ?? 0)
              .compareTo((b['dateTime'] as int?) ?? 0));
      return list;
    });
  }

  /// Message update karo (delete/unsend/react/pin)
  Future<void> updateMessage({
    required String chatRoomId,
    required String firebaseKey,
    required Map<String, dynamic> updates,
  }) async {
    await _db
        .ref('chats/$chatRoomId/messages/$firebaseKey')
        .update(updates);
  }

  /// Dono users ka online/typing status set karo
  Future<void> setTypingStatus({
    required String chatRoomId,
    required String userId,
    required bool isTyping,
  }) async {
    await _db.ref('chats/$chatRoomId/typing/$userId').set(isTyping);
  }

  /// Dusre user ka typing status sun-o
  Stream<bool> getTypingStream(String chatRoomId, String otherUserId) {
    return _db
        .ref('chats/$chatRoomId/typing/$otherUserId')
        .onValue
        .map((e) => (e.snapshot.value as bool?) ?? false);
  }

  /// Messages seen mark karo
  Future<void> markMessagesSeen({
    required String chatRoomId,
    required String currentUserId,
  }) async {
    final snapshot = await _db
        .ref('chats/$chatRoomId/messages')
        .orderByChild('senderId')
        .get();
    if (snapshot.value == null) return;
    final data = Map<String, dynamic>.from(snapshot.value as Map);
    final updates = <String, dynamic>{};
    data.forEach((key, value) {
      final msg = Map<String, dynamic>.from(value as Map);
      if (msg['senderId'] != currentUserId &&
          (msg['status'] as int? ?? 0) < MsgStatus.seen.index) {
        updates['chats/$chatRoomId/messages/$key/status'] =
            MsgStatus.seen.index;
        updates['chats/$chatRoomId/messages/$key/isRead'] = true; // ✅ YEH ADD KARO
      }
    });
    if (updates.isNotEmpty) {
      await _db.ref().update(updates);
    }
  }

  /// Dusre user ka UID dhundo username se
  // Firestore se UID fetch karo
  Future<String?> getUidByUsername(String username) async {
    // Exact match
    var query = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.data()['uid'] as String?;
    }

    // Lowercase match
    query = await FirebaseFirestore.instance
        .collection('users')
        .where('username_lower', isEqualTo: username.toLowerCase())
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.data()['uid'] as String?;
    }

    return null;
  }

// Firestore mein online status update karo
  void setOnlineStatus(String userId, bool isOnline) {
    FirebaseFirestore.instance.collection('users').doc(userId).update({
      'online': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Stream<bool> getOnlineStream(String userId) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => (doc.data()?['online'] as bool?) ?? false);
  }
}

// ── Chat Screen ───────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  final String username;
  final String avatarUrl;
  final String? lastMessage;
  final bool isFollowedBack;
  // ✅ Naya: dusre user ka UID directly pass karo
  final String? receiverUid;

  const ChatScreen({
    super.key,
    required this.username,
    required this.avatarUrl,
    this.lastMessage,
    this.isFollowedBack = true,
    this.receiverUid,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  final FirebaseChatService _firebaseService = FirebaseChatService();

  List<ChatMessage> _messages = [];
  StreamSubscription? _messagesSubscription;
  StreamSubscription? _typingSubscription;
  StreamSubscription? _onlineSubscription;

  // ✅ Current user ki info
  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';
  String get _currentUserName =>
      FirebaseAuth.instance.currentUser?.displayName ?? 'Me';

  // ✅ Receiver UID (ya username se fetch hoga)
  String _receiverUid = '';
  String _chatRoomId = '';
  bool _isLoadingReceiver = true;

  bool _isRecording = false;
  bool _showPanel = false;
  int _activeMainTab = 0;
  int _emojiCategoryIndex = 1;
  int _stickerCategoryIndex = 0;
  String _emojiSearchQuery = "";
  String _stickerSearchQuery = "";
  String _gifSearchQuery = "";

  ChatMessage? _replyingTo;
  ChatMessage? _editingMessage;
  String? _editingFirebaseKey;

  bool _isMultiSelectMode = false;
  final Set<String> _selectedMessageIds = {};

  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  bool _voiceLocked = false;
  bool _voicePaused = false;
  String? _recordedVoicePath;
  bool _showVoicePreview = false;

  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isPreviewPlaying = false;
  Duration _previewPosition = Duration.zero;
  Duration _previewTotal = Duration.zero;
  StreamSubscription? _previewPositionSub;
  StreamSubscription? _previewDurationSub;
  StreamSubscription? _previewStateSub;

  bool _isUserOnline = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  ChatMessage? _pinnedMessage;
  bool _isBlocked = false;

  bool _hasMissedCall = false;
  bool _isVideoMissedCall = false;
  bool _isInCall = false;
  bool _isVideoCall = false;
  bool _isIncomingCall = false;
  String? _callStatus;
  bool _iInitiatedCall = false;

  bool _autoTranslateEnabled = false;
  bool _followEnabled = false;
  bool _pinOnTopEnabled = false;
  String _nickname = '';
  String _selectedBubbleStyle = 'default';
  bool _isVIP = false;

  final List<String> _quickReactions = ['❤️', '😂', '😮', '😢', '🙏', '👍'];

  final List<Map<String, dynamic>> _stickerCategories = [
    {'name': 'Favorites', 'icon': Icons.star, 'stickers': <String>[]},
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
        '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
        '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😙',
        '😋', '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔',
        '🤐', '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥',
        '😌', '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮',
        '🤧', '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '😎', '🤓',
        '🧐', '😕', '😟', '🙁', '☹️', '😮', '😯', '😲', '😳', '🥺',
        '😦', '😧', '😨', '😰', '😥', '😢', '😭', '😱', '😖', '😣',
        '😞', '😓', '😩', '😫', '🥱', '😤', '😡', '😠', '🤬', '😈',
        '👿', '💀', '☠️', '💩', '🤡', '👹', '👺', '👻', '👽', '👾', '🤖'
      ]
    },
    {
      'icon': Icons.pets_outlined,
      'name': 'Animals',
      'emojis': [
        '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
        '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🐦', '🐤', '🦆',
        '🦅', '🦉', '🦇', '🐺', '🐗', '🐴', '🦄', '🐝', '🐛', '🦋',
        '🐌', '🐞', '🐜', '🦟', '🦗', '🕷️', '🕸️', '🦂', '🐢', '🐍', '🦎'
      ]
    },
    {
      'icon': Icons.fastfood_outlined,
      'name': 'Food',
      'emojis': [
        '🍎', '🍐', '🍊', '🍋', '🍌', '🍉', '🍇', '🍓', '🍈', '🍒',
        '🍑', '🥭', '🍍', '🥥', '🥝', '🍅', '🍆', '🥑', '🥦', '🌽',
        '🍔', '🍟', '🍕', '🌮', '🌯', '🍝', '🍜', '🍛', '🍣', '🍱',
        '🥟', '🍤', '🍦', '🧁', '🍰', '🎂', '🍭', '🍬', '🍫', '🍿',
        '🍩', '🍪', '☕', '🍵', '🥤', '🍺', '🍻', '🥂', '🍷'
      ]
    },
    {
      'icon': Icons.sports_soccer_rounded,
      'name': 'Activities',
      'emojis': [
        '⚽', '🏀', '🏈', '⚾', '🥎', '🎾', '🏐', '🏉', '🎱', '🏓',
        '🏸', '🥊', '🥋', '🎽', '🛹', '⛷️', '🏂', '🏋️', '🤸', '⛹️',
        '🏄', '🏊', '🤽', '🚴', '🚵'
      ]
    },
    {
      'icon': Icons.directions_car_filled_outlined,
      'name': 'Travel',
      'emojis': [
        '🚗', '🚕', '🚙', '🚌', '🚎', '🏎️', '🚓', '🚑', '🚒', '🚐',
        '🚚', '🚛', '🚜', '🛵', '🏍️', '🚲', '✈️', '🚀', '⛵', '⚓'
      ]
    },
  ];

  @override
  void initState() {
    super.initState();
    _nickname = widget.username;
    _initializeChat();
    _initPreviewPlayerListeners();
  }

  // ══════════════════════════════════════════════════════════════
  //  MAIN INIT — receiver UID find karo, phir Firebase listen karo
  // ══════════════════════════════════════════════════════════════
  Future<void> _initializeChat() async {
    setState(() => _isLoadingReceiver = true);

    // ✅ Step 1: Receiver UID determine karo
    if (widget.receiverUid != null && widget.receiverUid!.isNotEmpty) {
      _receiverUid = widget.receiverUid!;
    } else {
      // Username se UID dhundo Firebase mein
      final uid = await _firebaseService.getUidByUsername(widget.username);
      if (uid != null) {
        _receiverUid = uid;
      } else {
        // Fallback: username ko UID ki jagah use karo (purani compatibility)
        _receiverUid = widget.receiverUid ?? widget.username;  // ✅


      }
    }

    // ✅ Step 2: Chat Room ID banao
    _chatRoomId = _firebaseService.getChatRoomId(_currentUserId, _receiverUid);

    // ✅ Step 3: Firebase se messages listen karo
    _listenToMessages();

    // ✅ Step 4: Typing status listen karo
    _listenToTyping();

    // ✅ Step 5: Online status listen karo
    _listenToOnlineStatus();

    // ✅ Step 6: Apna online status set karo
    _firebaseService.setOnlineStatus(_currentUserId, true);

    // ✅ Step 7: Messages seen mark karo
    _firebaseService.markMessagesSeen(
      chatRoomId: _chatRoomId,
      currentUserId: _currentUserId,
    );
// ✅ Step 8: ChatProvider ka badge bhi clear karo  ← YEH ADD KARO
    if (mounted) {
      context.read<ChatProvider>().markChatAsSeen(_chatRoomId);
    }
    setState(() => _isLoadingReceiver = false);
  }

  void _listenToMessages() {
    _messagesSubscription =
        _firebaseService.getMessagesStream(_chatRoomId).listen((msgList) {
          if (!mounted) return;
          setState(() {
            _messages = msgList
                .map((m) => ChatMessage.fromMap(m, _currentUserId))
                .toList();
            _pinnedMessage = _messages.where((m) => m.isPinned).lastOrNull;
          });
          _scrollToBottom(delay: 100);
        });
  }

  void _listenToTyping() {
    _typingSubscription = _firebaseService
        .getTypingStream(_chatRoomId, _receiverUid)
        .listen((isTyping) {
      if (mounted) setState(() => _isTyping = isTyping);
    });
  }

  void _listenToOnlineStatus() {
    _onlineSubscription = _firebaseService
        .getOnlineStream(_receiverUid)
        .listen((isOnline) {
      if (mounted) setState(() => _isUserOnline = isOnline);
    });
  }

  void _initPreviewPlayerListeners() {
    _previewPositionSub =
        _previewPlayer.onPositionChanged.listen((pos) {
          if (mounted) setState(() => _previewPosition = pos);
        });
    _previewDurationSub =
        _previewPlayer.onDurationChanged.listen((dur) {
          if (mounted) setState(() => _previewTotal = dur);
        });
    _previewStateSub =
        _previewPlayer.onPlayerStateChanged.listen((state) {
          if (mounted) {
            setState(() => _isPreviewPlaying = state == PlayerState.playing);
            if (state == PlayerState.completed) {
              setState(() {
                _isPreviewPlaying = false;
                _previewPosition = Duration.zero;
              });
            }
          }
        });
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _typingSubscription?.cancel();
    _onlineSubscription?.cancel();
    _recordingTimer?.cancel();
    _typingTimer?.cancel();
    _previewPositionSub?.cancel();
    _previewDurationSub?.cancel();
    _previewStateSub?.cancel();
    _previewPlayer.dispose();
    // Offline ho jao jab screen close ho
    _firebaseService.setOnlineStatus(_currentUserId, false);
    _firebaseService.setTypingStatus(
      chatRoomId: _chatRoomId,
      userId: _currentUserId,
      isTyping: false,
    );
    super.dispose();
  }

  // ── Multi-select helpers ────────────────────────────────────
  void _enterMultiSelect(String messageId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isMultiSelectMode = true;
      _selectedMessageIds.add(messageId);
    });
  }

  void _toggleSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) _isMultiSelectMode = false;
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedMessageIds.clear();
    });
  }

  bool get _canUnsendSelected {
    if (_selectedMessageIds.isEmpty) return false;
    return _messages
        .where((m) => _selectedMessageIds.contains(m.id))
        .every((m) => m.isMine);
  }

  void _deleteSelected() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete ${_selectedMessageIds.length} message(s)?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will remove them only for you.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              for (final msg in _messages) {
                if (_selectedMessageIds.contains(msg.id)) {
                  await _firebaseService.updateMessage(
                    chatRoomId: _chatRoomId,
                    firebaseKey: msg.id,
                    updates: {'isDeleted': true},
                  );
                }
              }
              _exitMultiSelect();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _unsendSelected() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Unsend ${_selectedMessageIds.length} message(s)?',
          style: const TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will remove them for everyone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              for (final msg in _messages) {
                if (_selectedMessageIds.contains(msg.id) && msg.isMine) {
                  await _firebaseService.updateMessage(
                    chatRoomId: _chatRoomId,
                    firebaseKey: msg.id,
                    updates: {'isUnsent': true},
                  );
                }
              }
              _exitMultiSelect();
            },
            child: const Text('Unsend', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Call log ────────────────────────────────────────────────
  Future<void> _addCallLogMessage({
    required bool isVideoCall,
    required bool isMissedCall,
    required bool isIncomingCall,
    Duration? duration,
  }) async {
    final now = DateTime.now();
    final h = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final timeString = '$h:${now.minute.toString().padLeft(2, '0')} $amPm';

    final msgData = {
      'senderId': _currentUserId,
      'isMine': true,
      'type': MsgType.callLog.index,
      'time': timeString,
      'dateTime': now.millisecondsSinceEpoch,
      'duration': duration?.inSeconds,
      'isVideoCall': isVideoCall,
      'isMissedCall': isMissedCall,
      'isIncomingCall': isIncomingCall,
      'isDeleted': false,
      'isUnsent': false,
    };

    await _firebaseService.sendMessage(
      chatRoomId: _chatRoomId,
      messageData: msgData,
    );
  }

  void _makeVoiceCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VoiceCallScreen(
          remoteUserId: _receiverUid,
          remoteUserName: widget.username,
          remoteUserImage: widget.avatarUrl,
        ),
      ),
    ).then((callAnswered) {
      final bool answered = callAnswered == true;
      _addCallLogMessage(
        isVideoCall: false,
        isMissedCall: !answered,
        isIncomingCall: false,
        duration: answered ? const Duration(seconds: 30) : null,
      );
    });
  }

  void _makeVideoCall() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          remoteUserId: _receiverUid,
          remoteUserName: widget.username,
          remoteUserImage: widget.avatarUrl,
        ),
      ),
    ).then((callAnswered) {
      final bool answered = callAnswered == true;
      _addCallLogMessage(
        isVideoCall: true,
        isMissedCall: !answered,
        isIncomingCall: false,
        duration: answered ? const Duration(seconds: 45) : null,
      );
    });
  }

  // ── Send / Edit message ──────────────────────────────────────
  Future<void> _sendMessage({
    MsgType type = MsgType.text,
    String? text,
    String? imageUrl,
    bool isViewOnce = false,
    Duration? duration,
  }) async {
    if (_isLoadingReceiver) return;

    // ✅ Edit mode
    if (_editingMessage != null && _editingFirebaseKey != null) {
      final newText = _msgCtrl.text.trim();
      if (newText.isEmpty) return;
      await _firebaseService.updateMessage(
        chatRoomId: _chatRoomId,
        firebaseKey: _editingFirebaseKey!,
        updates: {'text': newText, 'isEdited': true},
      );
      setState(() {
        _editingMessage = null;
        _editingFirebaseKey = null;
        _msgCtrl.clear();
      });
      return;
    }

    final msgText = text ?? _msgCtrl.text.trim();
    if (msgText.isEmpty && type == MsgType.text) return;

    final now = DateTime.now();
    final h = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final timeString = '$h:${now.minute.toString().padLeft(2, '0')} $amPm';

    // ✅ senderId hamesha current user ka UID
    final msgData = <String, dynamic>{
      'senderId': _currentUserId,
      'senderName': _currentUserName,
      'receiverId': _receiverUid,
      'text': type == MsgType.text ? msgText : text,
      'type': type.index,
      'imageUrl': imageUrl,
      'avatarUrl': FirebaseAuth.instance.currentUser?.photoURL ?? '',
      'status': MsgStatus.sent.index,
      'time': timeString,
      'dateTime': now.millisecondsSinceEpoch,
      'duration': duration?.inSeconds,
      'isViewOnce': isViewOnce,
      'replyToText': _replyingTo?.text ??
          (_replyingTo != null ? '[${_replyingTo!.type.name}]' : null),
      'replyToType': _replyingTo?.type.name,
      'isDeleted': false,
      'isUnsent': false,
      'isStarred': false,
      'isPinned': false,
      'isEdited': false,
      'reactions': {},
      'isRead': false,  // ✅ SIRF YEH EK LINE ADD KARO
    };

    // UI mein clear karo
    setState(() {
      if (type == MsgType.text) _msgCtrl.clear();
      _replyingTo = null;
    });

    // ✅ Firebase mein send karo
    await _firebaseService.sendMessage(
      chatRoomId: _chatRoomId,
      messageData: msgData,
    );

    // Typing stop karo
    _firebaseService.setTypingStatus(
      chatRoomId: _chatRoomId,
      userId: _currentUserId,
      isTyping: false,
    );
  }

  void _startEditing(ChatMessage msg) {
    setState(() {
      _editingMessage = msg;
      _editingFirebaseKey = msg.id;
      _msgCtrl.text = msg.text ?? '';
      _replyingTo = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingMessage = null;
      _editingFirebaseKey = null;
      _msgCtrl.clear();
    });
  }

  // ── Typing indicator ────────────────────────────────────────
  void _onTextChanged(String value) {
    setState(() {});
    // Typing status update karo
    _firebaseService.setTypingStatus(
      chatRoomId: _chatRoomId,
      userId: _currentUserId,
      isTyping: value.isNotEmpty,
    );
    // 3 second baad typing stop karo
    _typingTimer?.cancel();
    if (value.isNotEmpty) {
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _firebaseService.setTypingStatus(
          chatRoomId: _chatRoomId,
          userId: _currentUserId,
          isTyping: false,
        );
      });
    }
  }

  void _scrollToBottom({int delay = 100}) {
    Future.delayed(Duration(milliseconds: delay), () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Long Press → Message Options ─────────────────────────────
  void _onMessageLongPress(BuildContext context, int messageIndex) {
    if (_isMultiSelectMode) {
      _toggleSelection(_messages[messageIndex].id);
      return;
    }
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
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: ScaleTransition(
                  scale: CurvedAnimation(
                      parent: anim, curve: Curves.elasticOut),
                  child: Material(
                    color: Colors.transparent,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 16,
                              offset: const Offset(0, 4))
                        ],
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
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6),
                              child: Text(emoji,
                                  style: const TextStyle(fontSize: 26)),
                            ),
                          )),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              _showFullEmojiReactionPicker(
                                  context, messageIndex);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.add,
                                  size: 22, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SlideTransition(
                position: Tween<Offset>(
                    begin: const Offset(0, 1), end: Offset.zero)
                    .animate(CurvedAnimation(
                    parent: anim, curve: Curves.easeOutCubic)),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF1C1C1E),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20)),
                    ),
                    child: SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              margin:
                              const EdgeInsets.only(top: 8, bottom: 4),
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Colors.grey[600],
                                  borderRadius: BorderRadius.circular(2))),
                          _ActionTile(
                              icon: Icons.reply,
                              label: 'Reply',
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() => _replyingTo = msg);
                              }),
                          if (msg.type == MsgType.text &&
                              msg.isMine &&
                              !msg.isDeleted &&
                              !msg.isUnsent)
                            _ActionTile(
                                icon: Icons.edit_outlined,
                                label: 'Edit',
                                onTap: () {
                                  Navigator.pop(ctx);
                                  _startEditing(msg);
                                }),
                          _ActionTile(
                              icon: Icons.forward,
                              label: 'Forward',
                              onTap: () {
                                Navigator.pop(ctx);
                                _openForwardScreen(context, msg);
                              }),
                          if (msg.type == MsgType.text &&
                              !msg.isDeleted &&
                              !msg.isUnsent)
                            _ActionTile(
                                icon: Icons.copy,
                                label: 'Copy',
                                onTap: () {
                                  Navigator.pop(ctx);
                                  Clipboard.setData(
                                      ClipboardData(text: msg.text ?? ''));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Message copied')));
                                }),
                          _ActionTile(
                              icon: Icons.info_outline,
                              label: 'Info',
                              onTap: () {
                                Navigator.pop(ctx);
                                _showMessageInfo(context, msg);
                              }),
                          _ActionTile(
                            icon: msg.isStarred
                                ? Icons.star
                                : Icons.star_border,
                            label: msg.isStarred ? 'Unstar' : 'Star',
                            iconColor: msg.isStarred ? Colors.amber : null,
                            onTap: () async {
                              Navigator.pop(ctx);
                              await _firebaseService.updateMessage(
                                chatRoomId: _chatRoomId,
                                firebaseKey: msg.id,
                                updates: {'isStarred': !msg.isStarred},
                              );
                            },
                          ),
                          _ActionTile(
                            icon: msg.isPinned
                                ? Icons.push_pin
                                : Icons.push_pin_outlined,
                            label: msg.isPinned ? 'Unpin' : 'Pin',
                            onTap: () async {
                              Navigator.pop(ctx);
                              // Pehle sab unpin karo
                              for (final m in _messages) {
                                if (m.isPinned) {
                                  await _firebaseService.updateMessage(
                                    chatRoomId: _chatRoomId,
                                    firebaseKey: m.id,
                                    updates: {'isPinned': false},
                                  );
                                }
                              }
                              if (!msg.isPinned) {
                                await _firebaseService.updateMessage(
                                  chatRoomId: _chatRoomId,
                                  firebaseKey: msg.id,
                                  updates: {'isPinned': true},
                                );
                              }
                            },
                          ),
                          _ActionTile(
                            icon: Icons.delete_outline,
                            label: 'Delete',
                            iconColor: Colors.red,
                            labelColor: Colors.red,
                            onTap: () {
                              Navigator.pop(ctx);
                              _enterMultiSelect(msg.id);
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

  void _showMessageInfo(BuildContext context, ChatMessage msg) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => MessageInfoScreen(
                message: msg,
                peerName: widget.username,
                peerAvatar: widget.avatarUrl)));
  }

  void _openForwardScreen(BuildContext context, ChatMessage msg) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ForwardMessageScreen(message: msg)));
  }

  void _showFullEmojiReactionPicker(BuildContext context, int messageIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: 380,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
                margin: const EdgeInsets.only(top: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Choose a Reaction',
                    style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 8),
                itemCount:
                (_emojiCategories[1]['emojis'] as List<String>).length,
                itemBuilder: (context, i) {
                  final emoji =
                  (_emojiCategories[1]['emojis'] as List<String>)[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleReaction(messageIndex, emoji);
                    },
                    child: Center(
                        child: Text(emoji,
                            style: const TextStyle(fontSize: 26))),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleReaction(int messageIndex, String emoji) async {
    final msg = _messages[messageIndex];
    final Map<String, List<String>> newReactions = Map.from(
        msg.reactions.map((k, v) => MapEntry(k, List<String>.from(v))));
    if (newReactions[emoji] == null) {
      newReactions[emoji] = [_currentUserId];
    } else if (newReactions[emoji]!.contains(_currentUserId)) {
      newReactions[emoji]!.remove(_currentUserId);
      if (newReactions[emoji]!.isEmpty) newReactions.remove(emoji);
    } else {
      newReactions[emoji]!.add(_currentUserId);
    }
    await _firebaseService.updateMessage(
      chatRoomId: _chatRoomId,
      firebaseKey: msg.id,
      updates: {'reactions': newReactions},
    );
  }

  Future<void> _saveMediaToGallery(String url, bool isVideo) async {
    try {
      if (Theme.of(context).platform == TargetPlatform.android) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Storage permission required.')));
          return;
        }
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
            Text(isVideo ? 'Saving video...' : 'Saving image...')));
      final response = await http.get(Uri.parse(url));
      final dir = await getTemporaryDirectory();
      final ext = isVideo ? '.mp4' : '.jpg';
      final filePath =
          '${dir.path}/wego_${DateTime.now().millisecondsSinceEpoch}$ext';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      if (isVideo) {
        await Gal.putVideo(filePath);
      } else {
        await Gal.putImage(filePath);
      }
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isVideo ? 'Video saved! 🎬' : 'Image saved! 📸'),
          backgroundColor: Colors.green,
        ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _showReceivedStickerPopup(BuildContext context, String stickerUrl) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24), topRight: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  margin: const EdgeInsets.only(top: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Image.network(stickerUrl,
                      width: 100, height: 100, fit: BoxFit.contain)),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StickerActionButton(
                      icon: _isStickerFavorite(stickerUrl)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFFFC107),
                      label: _isStickerFavorite(stickerUrl)
                          ? 'Remove\nSticker'
                          : 'Add to\nFavorite',
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
                        _sendMessage(
                            type: MsgType.sticker, imageUrl: stickerUrl);
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
    final List<String> favorites =
    List<String>.from(_stickerCategories[0]['stickers'] as List);
    if (favorites.contains(stickerUrl)) {
      setState(() {
        (_stickerCategories[0]['stickers'] as List).remove(stickerUrl);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Sticker removed from Favorites'),
          duration: Duration(seconds: 2)));
    } else {
      setState(() {
        (_stickerCategories[0]['stickers'] as List).add(stickerUrl);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('⭐ Sticker added to Favorites!'),
          backgroundColor: Color(0xFFFFC107),
          duration: Duration(seconds: 2)));
    }
  }

  void _openStickerEditor(BuildContext context, String stickerUrl) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => StickerEditorScreen(stickerUrl: stickerUrl)));
  }

  // ── 3-Dot Menu ───────────────────────────────────────────────
  void _show3DotMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1C1C1E)
              : Colors.white,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  margin: const EdgeInsets.only(top: 8, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2))),
              _SettingsTile(
                icon: Icons.edit,
                label: 'Edit Nickname',
                onTap: () {
                  Navigator.pop(ctx);
                  _showEditNicknameDialog(context);
                },
              ),
              SwitchListTile(
                secondary:
                const Icon(Icons.person_add_outlined, color: kPurple),
                title: const Text('Follow'),
                value: _followEnabled,
                activeColor: kPurple,
                onChanged: (v) => setState(() => _followEnabled = v),
              ),
              SwitchListTile(
                secondary:
                const Icon(Icons.push_pin_outlined, color: kPurple),
                title: const Text('Put on "Top of Talk List"'),
                value: _pinOnTopEnabled,
                activeColor: kPurple,
                onChanged: (v) => setState(() => _pinOnTopEnabled = v),
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.block,
                    color: _isBlocked ? Colors.red : Colors.grey),
                title: Text(_isBlocked ? 'Unblock' : 'Block',
                    style:
                    TextStyle(color: _isBlocked ? Colors.red : null)),
                onTap: () {
                  Navigator.pop(ctx);
                  _showBlockDialog(context);
                },
              ),
              _SettingsTile(
                icon: Icons.flag_outlined,
                label: 'Report',
                iconColor: Colors.orange,
                onTap: () {
                  Navigator.pop(ctx);
                  _showReportDialog(context);
                },
              ),
              ListTile(
                title: const Text('Clear Chat History',
                    style: TextStyle(
                        color: Colors.pinkAccent,
                        fontWeight: FontWeight.w600)),
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
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Enter nickname')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              setState(() =>
              _nickname = ctrl.text.isEmpty ? widget.username : ctrl.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showBlockDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_isBlocked ? 'Unblock User?' : 'Block User?',
            style: const TextStyle(color: Colors.white)),
        content: Text(
            _isBlocked
                ? 'Do you want to unblock ${widget.username}?'
                : 'Do you want to block ${widget.username}?',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('No', style: TextStyle(color: Colors.blue))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isBlocked = !_isBlocked);
              if (_isBlocked)
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content:
                    Text('${widget.username} has been blocked')));
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
          children: ['Spam', 'Harassment', 'Inappropriate Content', 'Fake Profile']
              .map((reason) => ListTile(
            title: Text(reason),
            onTap: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Reported for: $reason')));
            },
          ))
              .toList(),
        ),
      ),
    );
  }

  void _showClearChatDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Clear Chat History?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'This will permanently delete all messages in this chat for you.',
            style: TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.blue))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Note: Firebase mein clear karna dangerous hai
              // Isliye sirf local state clear karte hain ya
              // apna specific implementation karo
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Chat cleared locally')));
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Camera & Gallery ─────────────────────────────────────────
  void _openCamera() async {
    try {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CameraScreen()),
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _openGalleryMultiSelect() async {
    try {
      final selected = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GalleryMultiSelectScreen()),
      );
      if (selected != null && selected is List<XFile>) {
        for (final media in selected) {
          await _sendMessage(
            type: media.path.toLowerCase().endsWith('.mp4') ||
                media.path.toLowerCase().endsWith('.mov')
                ? MsgType.video
                : MsgType.image,
            imageUrl: 'file://${media.path}',
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error selecting media: $e')));
    }
  }

  // ── Voice Recording ────────────────────────────────────────
  Future<void> _startRecording() async {
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    setState(() {
      _isRecording = true;
      _voiceLocked = false;
      _voicePaused = false;
      _recordingDuration = Duration.zero;
      _recordedVoicePath = path;
    });
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!_voicePaused && mounted) {
        setState(() => _recordingDuration += const Duration(seconds: 1));
      }
    });
  }

  Future<void> _stopRecording({bool send = true}) async {
    _recordingTimer?.cancel();
    setState(() {
      _isRecording = false;
      _voiceLocked = false;
      _voicePaused = false;
    });
    if (send && _recordingDuration.inSeconds > 0) {
      setState(() => _showVoicePreview = true);
    } else {
      setState(() {
        _recordedVoicePath = null;
        _recordingDuration = Duration.zero;
      });
    }
  }

  Future<void> _pauseResumeRecording() async {
    if (!_isRecording) return;
    setState(() => _voicePaused = !_voicePaused);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _toggleVoicePreview() async {
    if (_recordedVoicePath == null) return;
    try {
      if (_isPreviewPlaying) {
        await _previewPlayer.pause();
      } else {
        await _previewPlayer.play(DeviceFileSource(_recordedVoicePath!));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Playback error: $e')));
    }
  }

  void _sendVoiceMessage() {
    if (_recordedVoicePath != null && _recordingDuration.inSeconds > 0) {
      final dur = _recordingDuration;
      _sendMessage(
        type: MsgType.voice,
        text: _formatDuration(dur),
        imageUrl: _recordedVoicePath,
        duration: dur,
      );
    }
    _cancelVoicePreview();
  }

  void _cancelVoicePreview() {
    _previewPlayer.stop();
    setState(() {
      _showVoicePreview = false;
      _recordedVoicePath = null;
      _isPreviewPlaying = false;
      _recordingDuration = Duration.zero;
      _previewPosition = Duration.zero;
      _previewTotal = Duration.zero;
    });
  }

  // ── Panel Builder ─────────────────────────────────────────────
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
              decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18)),
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
                  prefixIcon:
                  const Icon(Icons.search, size: 18, color: Colors.grey),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear,
                        size: 18, color: Colors.grey),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {
                        _emojiSearchQuery = "";
                        _stickerSearchQuery = "";
                        _gifSearchQuery = "";
                      });
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 16),
                ),
              ),
            ),
          ),
          Expanded(
            child: _activeMainTab == 0
                ? _buildEmojiSection()
                : (_activeMainTab == 1
                ? _buildGifSection()
                : _buildStickerSection()),
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
          if (isSelected)
            Container(
                margin: const EdgeInsets.only(top: 4),
                width: 20,
                height: 2,
                color: kPurple),
        ],
      ),
    );
  }

  Widget _buildEmojiSection() {
    List<String> emojisToShow =
    _emojiCategories[_emojiCategoryIndex]['emojis'];
    if (_emojiSearchQuery.isNotEmpty) {
      emojisToShow =
          emojisToShow.where((e) => e.contains(_emojiSearchQuery)).toList();
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7),
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
      gifsToShow = _gifUrls
          .where((url) =>
          url.toLowerCase().contains(_gifSearchQuery.toLowerCase()))
          .toList();
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.6,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8),
      itemCount: gifsToShow.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => _sendMessage(type: MsgType.gif, imageUrl: gifsToShow[i]),
        child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(gifsToShow[i], fit: BoxFit.cover)),
      ),
    );
  }

  Widget _buildStickerSection() {
    List<String> stickers = List<String>.from(
        _stickerCategories[_stickerCategoryIndex]['stickers'] as List);
    if (_stickerSearchQuery.isNotEmpty) {
      List<String> allStickers = [];
      for (var category in _stickerCategories) {
        allStickers.addAll(List<String>.from(category['stickers'] as List));
      }
      stickers = allStickers
          .where((url) =>
          url.toLowerCase().contains(_stickerSearchQuery.toLowerCase()))
          .toList();
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
                          color: _stickerCategoryIndex == i
                              ? kPurple.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_stickerCategories[i]['icon'],
                            color: _stickerCategoryIndex == i
                                ? kPurple
                                : Colors.grey,
                            size: 24),
                      ),
                      if (_stickerCategoryIndex == i)
                        Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 4,
                            height: 4,
                            decoration: const BoxDecoration(
                                color: kPurple, shape: BoxShape.circle)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10),
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
      builder: (BuildContext ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20), topRight: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _StickerActionButton(
                      icon: _isStickerFavorite(stickerUrl)
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFFFC107),
                      label: _isStickerFavorite(stickerUrl)
                          ? 'Remove\nSticker'
                          : 'Add to\nFavorite',
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
                        _openStickerEditor(ctx, stickerUrl);
                      },
                    ),
                    _StickerActionButton(
                      icon: Icons.send_rounded,
                      color: kPurple,
                      label: 'Send\nSticker',
                      onTap: () {
                        Navigator.pop(ctx);
                        _sendMessage(
                            type: MsgType.sticker, imageUrl: stickerUrl);
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

  Widget _buildBottomABCBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
          border: Border(
              top: BorderSide(color: Colors.grey.withValues(alpha: 0.1)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () {
              setState(() => _showPanel = false);
              FocusScope.of(context).requestFocus(FocusNode());
            },
            child: const Text("ABC",
                style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          ...List.generate(
            _emojiCategories.length,
                (i) => IconButton(
              icon: Icon(_emojiCategories[i]['icon'],
                  size: 20,
                  color: _emojiCategoryIndex == i ? kPurple : Colors.grey),
              onPressed: () => setState(() => _emojiCategoryIndex = i),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.backspace_outlined,
                size: 20, color: Colors.grey),
            onPressed: () {
              if (_msgCtrl.text.isNotEmpty) {
                _msgCtrl.text =
                    _msgCtrl.text.substring(0, _msgCtrl.text.length - 1);
                setState(() {});
              }
            },
          ),
        ],
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    // ✅ Loading state jab receiver UID fetch ho raha ho
    if (_isLoadingReceiver) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: kPurple,
          leading: const BackButton(color: Colors.white),
          title: Text(widget.username,
              style: const TextStyle(color: Colors.white)),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: kPurple),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _isMultiSelectMode ? _buildMultiSelectAppBar() : _buildAppBar(),
            if (_pinnedMessage != null && !_isMultiSelectMode)
              _buildPinnedBanner(),
            if (_hasMissedCall && !_isMultiSelectMode)
              MissedCallBanner(
                username: widget.username,
                avatarUrl: widget.avatarUrl,
                receiverId: _receiverUid,
                isVideoCall: _isVideoMissedCall,
                onCallback: () {
                  setState(() => _hasMissedCall = false);
                  if (_isVideoMissedCall) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => VideoCallScreen(
                                remoteUserId: _receiverUid,
                                remoteUserName: widget.username,
                                remoteUserImage: widget.avatarUrl)));
                  } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => VoiceCallScreen(
                                remoteUserId: _receiverUid,
                                remoteUserName: widget.username,
                                remoteUserImage: widget.avatarUrl)));
                  }
                },
              ),
            Expanded(
              child: _messages.isEmpty
                  ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 64,
                        color: Colors.grey.withValues(alpha: 0.4)),
                    const SizedBox(height: 16),
                    Text('No messages yet',
                        style: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.6),
                            fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Say hello to ${widget.username}!',
                        style: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.4),
                            fontSize: 13)),
                  ],
                ),
              )
                  : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  bool showDateSeparator = false;
                  if (index == 0) {
                    showDateSeparator = true;
                  } else {
                    final cur = _messages[index];
                    final prev = _messages[index - 1];
                    if (cur.dateTime != null &&
                        prev.dateTime != null) {
                      final cd = DateTime(cur.dateTime!.year,
                          cur.dateTime!.month, cur.dateTime!.day);
                      final pd = DateTime(prev.dateTime!.year,
                          prev.dateTime!.month, prev.dateTime!.day);
                      showDateSeparator = cd.isAfter(pd);
                    }
                  }
                  return Column(
                    children: [
                      if (showDateSeparator)
                        _buildDateSeparator(
                            _messages[index].dateTime),
                      _buildMessageItem(
                          _messages[index], index, isDark),
                    ],
                  );
                },
              ),
            ),
            if (_isTyping && !_isMultiSelectMode) _buildTypingIndicator(),
            if (_replyingTo != null && !_isMultiSelectMode)
              _buildReplyPreview(),
            if (_editingMessage != null && !_isMultiSelectMode)
              _buildEditPreview(),
            if (_showPanel && !_isMultiSelectMode) _buildWhatsAppPanel(),
            _isMultiSelectMode
                ? _buildMultiSelectBottomBar()
                : (_showVoicePreview
                ? _buildVoicePreviewBar(isDark)
                : (_isRecording
                ? _buildVoiceRecordingBar(isDark)
                : _buildInputBar(isDark))),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectAppBar() {
    return Container(
      color: kPurple,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _exitMultiSelect,
          ),
          Expanded(
            child: Text(
              '${_selectedMessageIds.length} selected',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                for (final m in _messages) {
                  if (!m.isDeleted) _selectedMessageIds.add(m.id);
                }
              });
            },
            child: const Text('All', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectBottomBar() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _MultiSelectActionBtn(
            icon: Icons.delete_outline,
            label: 'Delete',
            color: Colors.red,
            onTap: _selectedMessageIds.isEmpty ? null : _deleteSelected,
          ),
          if (_canUnsendSelected)
            _MultiSelectActionBtn(
              icon: Icons.remove_circle_outline,
              label: 'Unsend',
              color: Colors.orange,
              onTap: _unsendSelected,
            ),
        ],
      ),
    );
  }

  Widget _buildEditPreview() {
    return Container(
      color: kPurple.withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.edit_outlined, color: kPurple, size: 18),
          const SizedBox(width: 10),
          Container(
              width: 3,
              height: 36,
              color: kPurple,
              margin: const EdgeInsets.only(right: 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Edit message',
                    style: TextStyle(
                        color: kPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                Text(
                  _editingMessage?.text ?? '',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: _cancelEditing),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime? dateTime) {
    if (dateTime == null) return const SizedBox.shrink();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    String dateText;
    if (msgDate.isAtSameMomentAs(today)) {
      dateText = 'Today';
    } else {
      final yesterday = today.subtract(const Duration(days: 1));
      if (msgDate.isAtSameMomentAs(yesterday)) {
        dateText = 'Yesterday';
      } else {
        final months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        dateText =
        '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
      }
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12)),
          child: Text(dateText,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          ClipOval(
              child: Image.network(widget.avatarUrl,
                  width: 28, height: 28, fit: BoxFit.cover)),
          const SizedBox(width: 8),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16)),
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
        final idx = _messages.indexWhere((m) => m.isPinned);
        if (idx >= 0 && _scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(idx * 80.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut);
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
                _pinnedMessage?.text ??
                    '[${_pinnedMessage?.type.name ?? 'message'}]',
                style: const TextStyle(fontSize: 13, color: kPurple),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () async {
                if (_pinnedMessage != null) {
                  await _firebaseService.updateMessage(
                    chatRoomId: _chatRoomId,
                    firebaseKey: _pinnedMessage!.id,
                    updates: {'isPinned': false},
                  );
                }
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
          Container(
              width: 3,
              height: 36,
              color: kPurple,
              margin: const EdgeInsets.only(right: 10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_replyingTo!.isMine ? 'You' : widget.username,
                    style: const TextStyle(
                        color: kPurple,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                Text(
                  _replyingTo!.text ?? '[${_replyingTo!.type.name}]',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => setState(() => _replyingTo = null)),
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
          IconButton(
              icon: const Icon(Icons.arrow_back_ios,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context)),
          GestureDetector(
            onTap: () {},
            child: Stack(
              children: [
                ClipOval(
                    child: Image.network(widget.avatarUrl,
                        width: 40, height: 40, fit: BoxFit.cover)),
                if (_isUserOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: kPurple, width: 2)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_nickname,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold)),
                Text(
                  _isTyping
                      ? 'typing...'
                      : (_isUserOnline ? 'Online' : 'Last seen recently'),
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 12),
                ),
              ],
            ),
          ),
          if (widget.isFollowedBack)
            IconButton(
              icon: const Icon(Icons.call_outlined, color: Colors.white),
              onPressed: _makeVoiceCall,
            ),
          if (widget.isFollowedBack)
            IconButton(
              icon: const Icon(Icons.videocam_outlined, color: Colors.white),
              onPressed: _makeVideoCall,
            ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () => _show3DotMenu(context),
          ),
        ],
      ),
    );
  }

  // ── Message item builder ─────────────────────────────────────
  Widget _buildMessageItem(ChatMessage msg, int index, bool isDark) {
    if (msg.isUnsent) {
      return _UnsentBubble(isMine: msg.isMine, time: msg.time);
    }
    if (msg.isDeleted) return const SizedBox.shrink();

    final bool isSelected =
        _isMultiSelectMode && _selectedMessageIds.contains(msg.id);

    Widget bubble;

    if (msg.type == MsgType.callLog) {
      final Widget callWidget = CallLogMessage(
        isVideoCall: msg.isVideoCall ?? false,
        isMissedCall: msg.isMissedCall ?? false,
        isIncomingCall: msg.isIncomingCall ?? false,
        isMine: msg.isMine,
        username: widget.username,
        avatarUrl: widget.avatarUrl,
        time: msg.time,
        duration: msg.duration,
        receiverId: _receiverUid,
        onCallback: () {
          if (msg.isVideoCall ?? false) {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => VideoCallScreen(
                        remoteUserId: _receiverUid,
                        remoteUserName: widget.username,
                        remoteUserImage: widget.avatarUrl)));
          } else {
            Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => VoiceCallScreen(
                        remoteUserId: _receiverUid,
                        remoteUserName: widget.username,
                        remoteUserImage: widget.avatarUrl)));
          }
        },
      );
      return GestureDetector(
        onTap: _isMultiSelectMode ? () => _toggleSelection(msg.id) : null,
        onLongPress: () => _onMessageLongPress(context, index),
        child: Container(
          color: isSelected ? kPurple.withOpacity(0.15) : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment:
            msg.isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (isSelected && !msg.isMine)
                const Padding(
                    padding: EdgeInsets.only(left: 8, right: 4),
                    child:
                    Icon(Icons.check_circle, color: kPurple, size: 20)),
              Flexible(child: callWidget),
              if (isSelected && msg.isMine)
                const Padding(
                    padding: EdgeInsets.only(left: 4, right: 8),
                    child:
                    Icon(Icons.check_circle, color: kPurple, size: 20)),
            ],
          ),
        ),
      );
    }

    if (msg.isMine) {
      bubble = _MyBubble(
        message: msg,
        onLongPress: () => _onMessageLongPress(context, index),
        onSave: (msg.type == MsgType.image ||
            msg.type == MsgType.gif ||
            msg.type == MsgType.video) &&
            msg.imageUrl != null
            ? () =>
            _saveMediaToGallery(msg.imageUrl!, msg.type == MsgType.video)
            : null,
        bubbleStyle: _selectedBubbleStyle,
      );
    } else {
      switch (msg.type) {
        case MsgType.image:
          bubble = _TheirImageMessage(
              message: msg,
              onLongPress: () => _onMessageLongPress(context, index),
              onSave: () => _saveMediaToGallery(msg.imageUrl!, false));
          break;
        case MsgType.sticker:
        case MsgType.gif:
          bubble = _TheirStickerMessage(
            message: msg,
            onTap: () => _showReceivedStickerPopup(context, msg.imageUrl!),
            onLongPress: () => _onMessageLongPress(context, index),
          );
          break;
        default:
          bubble = _TheirTextBubble(
              message: msg,
              isDark: isDark,
              onLongPress: () => _onMessageLongPress(context, index));
      }
    }

    return GestureDetector(
      onTap: _isMultiSelectMode ? () => _toggleSelection(msg.id) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected ? kPurple.withOpacity(0.15) : Colors.transparent,
        child: Column(
          crossAxisAlignment: msg.isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (msg.replyToText != null)
              Padding(
                padding: EdgeInsets.only(
                    left: msg.isMine ? 0 : 44,
                    right: msg.isMine ? 8 : 0,
                    bottom: 2),
                child: _ReplyHeader(
                    text: msg.replyToText!,
                    isMine: msg.isMine,
                    senderName: msg.isMine ? 'You' : widget.username),
              ),
            Row(
              mainAxisAlignment: msg.isMine
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (isSelected && !msg.isMine)
                  const Padding(
                      padding: EdgeInsets.only(left: 8, right: 4),
                      child: Icon(Icons.check_circle,
                          color: kPurple, size: 20)),
                Flexible(child: bubble),
                if (isSelected && msg.isMine)
                  const Padding(
                      padding: EdgeInsets.only(left: 4, right: 8),
                      child: Icon(Icons.check_circle,
                          color: kPurple, size: 20)),
              ],
            ),
            if (msg.reactions.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                    bottom: 8,
                    left: msg.isMine ? 0 : 44,
                    right: msg.isMine ? 8 : 0),
                child: _ReactionRow(
                    reactions: msg.reactions, isMine: msg.isMine),
              ),
          ],
        ),
      ),
    );
  }
// ── Image helper ──────────────────────────────────────────────
  Widget _buildImageWidget(String? url, {double? width, double? height, BoxFit fit = BoxFit.cover}) {
    if (url == null) return const SizedBox();
    if (url.startsWith('file://') || url.startsWith('/data/')) {
      return Image.file(
        File(url.replaceFirst('file://', '')),
        width: width,
        height: height,
        fit: fit,
      );
    }
    return Image.network(url, width: width, height: height, fit: fit);
  }
  // ── Input bar ─────────────────────────────────────────────────
  Widget _buildInputBar(bool isDark) {
    if (_isBlocked) {
      return Container(
        color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[200],
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
                child: ElevatedButton(
                    onPressed: () => _showBlockDialog(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24))),
                    child: const Text('Unblock',
                        style: TextStyle(color: Colors.white)))),
            const SizedBox(width: 12),
            Expanded(
                child: ElevatedButton(
                    onPressed: () => _showClearChatDialog(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24))),
                    child: const Text('Delete Chat',
                        style: TextStyle(color: Colors.white)))),
          ],
        ),
      );
    }

    final bool isEditing = _editingMessage != null;

    return Container(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.emoji_emotions_outlined,
                color: _showPanel ? kPurple : Colors.grey),
            onPressed: () {
              setState(() => _showPanel = !_showPanel);
              if (_showPanel)
                SystemChannels.textInput.invokeMethod('TextInput.hide');
            },
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.white,
                  borderRadius: BorderRadius.circular(24)),
              child: TextField(
                controller: _msgCtrl,
                style:
                TextStyle(color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: isEditing ? 'Edit message...' : 'Message...',
                  border: InputBorder.none,
                ),
                onTap: () => setState(() => _showPanel = false),
                onSubmitted: (_) => _sendMessage(),
                // ✅ Typing status update hoga
                onChanged: _onTextChanged,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.camera_alt, color: Colors.grey),
            onPressed: _openCamera,
          ),
          const SizedBox(width: 8),
          _msgCtrl.text.isEmpty && !isEditing
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
              decoration: const BoxDecoration(
                  color: kPurple, shape: BoxShape.circle),
              child: const Icon(Icons.mic, color: Colors.white, size: 22),
            ),
          )
              : IconButton(
            icon: Icon(isEditing ? Icons.check : Icons.send,
                color: kPurple),
            onPressed: _sendMessage,
          ),
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
          GestureDetector(
            onTap: () => _stopRecording(send: false),
            child:
            const Icon(Icons.delete_outline, color: Colors.red, size: 28),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.white,
                  borderRadius: BorderRadius.circular(24)),
              child: Row(
                children: [
                  Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text(_formatDuration(_recordingDuration),
                      style: const TextStyle(
                          color: Colors.red, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Expanded(child: _WaveformWidget()),
                  if (_voiceLocked)
                    GestureDetector(
                      onTap: _pauseResumeRecording,
                      child: Icon(
                          _voicePaused ? Icons.play_arrow : Icons.pause,
                          color: kPurple,
                          size: 22),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (!_voiceLocked)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.lock_outline, color: Colors.grey, size: 18),
                Icon(Icons.keyboard_arrow_up, color: Colors.grey, size: 16),
              ],
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _stopRecording(send: true),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration:
              const BoxDecoration(color: kPurple, shape: BoxShape.circle),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVoicePreviewBar(bool isDark) {
    final double progress = _previewTotal.inMilliseconds > 0
        ? (_previewPosition.inMilliseconds / _previewTotal.inMilliseconds)
        .clamp(0.0, 1.0)
        : 0.0;
    return Container(
      color: isDark ? const Color(0xFF1E1E2E) : Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: _cancelVoicePreview,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12), shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline,
                  color: Colors.red, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _toggleVoicePreview,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration:
              const BoxDecoration(color: kPurple, shape: BoxShape.circle),
              child: Icon(
                _isPreviewPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor:
                    isDark ? Colors.grey[700] : Colors.grey[300],
                    valueColor:
                    const AlwaysStoppedAnimation<Color>(kPurple),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_previewPosition),
                        style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
                    Text(_formatDuration(_previewTotal),
                        style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _sendVoiceMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration:
              const BoxDecoration(color: kTeal, shape: BoxShape.circle),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  HELPER WIDGETS (same as before, no changes needed)
// ══════════════════════════════════════════════════════════════

class _MultiSelectActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _MultiSelectActionBtn(
      {required this.icon,
        required this.label,
        required this.color,
        this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ReplyHeader extends StatelessWidget {
  final String text;
  final bool isMine;
  final String senderName;
  const _ReplyHeader(
      {required this.text, required this.isMine, required this.senderName});

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
          Text(senderName,
              style: const TextStyle(
                  color: kPurple, fontWeight: FontWeight.bold, fontSize: 11)),
          Text(text,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

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
        final iReacted = entry.value.isNotEmpty;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: iReacted
                ? kPurple.withOpacity(0.15)
                : Colors.grey.withOpacity(0.15),
            border: Border.all(
                color: iReacted
                    ? kPurple.withOpacity(0.4)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 14)),
              if (count > 1) ...[
                const SizedBox(width: 3),
                Text('$count',
                    style: TextStyle(
                        fontSize: 12,
                        color: iReacted ? kPurple : Colors.grey[600])),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _StickerActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _StickerActionButton(
      {required this.icon,
        required this.color,
        required this.label,
        required this.onTap});

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
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  const _ActionTile(
      {required this.icon,
        required this.label,
        required this.onTap,
        this.iconColor,
        this.labelColor});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? Colors.white70, size: 22),
      title: Text(label,
          style: TextStyle(color: labelColor ?? Colors.white, fontSize: 15)),
      onTap: onTap,
      dense: true,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Widget? trailing;
  const _SettingsTile(
      {required this.icon,
        required this.label,
        required this.onTap,
        this.iconColor,
        this.trailing});

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
          margin:
          EdgeInsets.only(left: isMine ? 0 : 44, right: isMine ? 8 : 0),
          padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
              Text(
                  isMine ? 'You unsent a message' : 'This message was unsent',
                  style: const TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MyBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onLongPress;
  final VoidCallback? onSave;
  final String bubbleStyle;
  const _MyBubble(
      {required this.message,
        required this.onLongPress,
        this.onSave,
        this.bubbleStyle = 'default'});

  BorderRadius get _borderRadius {
    switch (bubbleStyle) {
      case 'rounded':
        return BorderRadius.circular(24);
      case 'sharp':
        return BorderRadius.circular(4);
      case 'cloud':
        return const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(2));
      default:
        return const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(2));
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
                if (message.isStarred)
                  const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(Icons.star, size: 14, color: Colors.amber)),
                if (message.type == MsgType.sticker ||
                    message.type == MsgType.gif)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Stack(
                        children: [
                          Image.network(message.imageUrl!,
                              width: 150, height: 150, fit: BoxFit.contain),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(message.time,
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.white)),
                                  const SizedBox(width: 4),
                                  _buildStatus(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (onSave != null) _SaveButton(onSave: onSave!),
                    ],
                  )
                else if (message.type == MsgType.image)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Stack(
                        children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(message.imageUrl!,
                                  height: 180, width: 200, fit: BoxFit.cover)),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(message.time,
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.white)),
                                  const SizedBox(width: 4),
                                  _buildStatus(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (onSave != null) _SaveButton(onSave: onSave!),
                    ],
                  )
                else if (message.type == MsgType.voice)
                    _VoiceBubble(message: message, isMine: true)
                  else
                    Container(
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                          color: kTeal, borderRadius: _borderRadius),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(message.text ?? '',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 15)),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (message.isEdited)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Text('edited',
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white60,
                                          fontStyle: FontStyle.italic)),
                                ),
                              Text(message.time,
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.white70)),
                              const SizedBox(width: 4),
                              _buildStatus(),
                            ],
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatus() {
    if (message.status == MsgStatus.sent)
      return const Icon(Icons.check, size: 14, color: Colors.grey);
    if (message.status == MsgStatus.delivered)
      return const Icon(Icons.done_all, size: 14, color: Colors.grey);
    return const Icon(Icons.done_all, size: 14, color: Colors.blue);
  }
}

class _VoiceBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isMine;
  const _VoiceBubble({required this.message, required this.isMine});

  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    if (widget.message.duration != null) {
      _total = widget.message.duration!;
    }
    _posSub = _player.onPositionChanged.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durSub = _player.onDurationChanged.listen((dur) {
      if (mounted) setState(() => _total = dur);
    });
    _stateSub = _player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
        if (state == PlayerState.completed) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _togglePlay() async {
    final path = widget.message.imageUrl;
    if (path == null) return;
    try {
      if (_isPlaying) {
        await _player.pause();
        setState(() => _isPlaying = false);
      } else {
        final file = File(path);
        if (await file.exists()) {
          await _player.play(DeviceFileSource(path));
        } else {
          await _player.play(UrlSource(path));
        }
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint('Voice play error: $e');
      if (mounted) setState(() => _isPlaying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _total.inMilliseconds > 0
        ? (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final Color bubbleColor = widget.isMine ? kTeal : Colors.grey.shade200;
    final Color subColor =
    widget.isMine ? Colors.white70 : Colors.grey.shade600;

    return Container(
      constraints:
      BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          color: bubbleColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: widget.isMine
                      ? Colors.white.withOpacity(0.25)
                      : kPurple.withOpacity(0.15),
                  shape: BoxShape.circle),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: widget.isMine ? Colors.white : kPurple,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: widget.isMine
                        ? Colors.white.withOpacity(0.3)
                        : Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isMine ? Colors.white : kPurple),
                    minHeight: 3,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_fmt(_isPlaying ? _position : _total),
                        style: TextStyle(fontSize: 11, color: subColor)),
                    if (widget.isMine)
                      Text(widget.message.time,
                          style: TextStyle(fontSize: 10, color: subColor)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TheirTextBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isDark;
  final VoidCallback onLongPress;
  const _TheirTextBubble(
      {required this.message,
        required this.isDark,
        required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipOval(
                child: Image.network(
                    message.avatarUrl ?? 'https://i.pravatar.cc/150',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover)),
            const SizedBox(width: 8),
            Container(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.type == MsgType.voice)
                    _VoiceBubble(message: message, isMine: false)
                  else
                    Text(message.text ?? '',
                        style: TextStyle(
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(message.time,
                      style: TextStyle(
                          fontSize: 10,
                          color:
                          isDark ? Colors.grey[400] : Colors.grey[500])),
                ],
              ),
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
  const _TheirStickerMessage(
      {required this.message,
        required this.onTap,
        required this.onLongPress});

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
            ClipOval(
                child: Image.network(
                    message.avatarUrl ?? 'https://i.pravatar.cc/150',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover)),
            const SizedBox(width: 8),
            Stack(
              children: [
                Image.network(message.imageUrl!, width: 120, height: 120),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8)),
                    child: Text(message.time,
                        style: const TextStyle(
                            fontSize: 10, color: Colors.white)),
                  ),
                ),
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
  const _TheirImageMessage(
      {required this.message,
        required this.onLongPress,
        required this.onSave});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipOval(
                child: Image.network(
                    message.avatarUrl ?? 'https://i.pravatar.cc/150',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(message.imageUrl!,
                            height: 180, width: 200, fit: BoxFit.cover)),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(message.time,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                _SaveButton(onSave: onSave),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
            Text('Save',
                style: TextStyle(
                    fontSize: 12,
                    color: kPurple,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _WaveformWidget extends StatefulWidget {
  final bool isMini;
  const _WaveformWidget({this.isMini = false});

  @override
  State<_WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<_WaveformWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.isMini ? 8 : 20, (i) {
          final h =
          (10 + (i % 4 + 1) * 6 * (_ctrl.value + 0.3)).clamp(4.0, 28.0);
          return Container(
            width: widget.isMini ? 2 : 3,
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
                color: kPurple.withOpacity(0.7),
                borderRadius: BorderRadius.circular(2)),
          );
        }),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;
  const _TypingDot({required this.delay});
  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _anim = Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: Colors.grey[500], shape: BoxShape.circle)),
      ),
    );
  }
}

// ── Message Info Screen ───────────────────────────────────────
class MessageInfoScreen extends StatelessWidget {
  final ChatMessage message;
  final String peerName;
  final String peerAvatar;
  const MessageInfoScreen(
      {super.key,
        required this.message,
        required this.peerName,
        required this.peerAvatar});

  @override
  Widget build(BuildContext context) {
    final dt = message.dateTime ?? DateTime.now();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final dateStr = '${dt.day} ${months[dt.month - 1]} ${dt.year}';

    return Scaffold(
      appBar: AppBar(
          backgroundColor: kPurple,
          title: const Text('Message Info',
              style: TextStyle(color: Colors.white)),
          leading: const BackButton(color: Colors.white)),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: message.isMine
                      ? kTeal.withOpacity(0.15)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.type == MsgType.image && message.imageUrl != null)
                    ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(message.imageUrl!,
                            height: 140, fit: BoxFit.cover)),
                  if (message.type == MsgType.sticker &&
                      message.imageUrl != null)
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
          _InfoRow(icon: Icons.access_time, label: 'Time', value: message.time),
          _InfoRow(icon: Icons.calendar_today, label: 'Date', value: dateStr),
          _InfoRow(
              icon: Icons.category_outlined,
              label: 'Type',
              value: _msgTypeLabel(message.type)),
          if (message.isMine)
            _InfoRow(
                icon: Icons.done_all,
                label: 'Status',
                value: _statusLabel(message.status),
                valueColor:
                message.status == MsgStatus.seen ? Colors.blue : Colors.grey),
          if (message.isStarred)
            _InfoRow(
                icon: Icons.star,
                label: 'Starred',
                value: 'Yes',
                iconColor: Colors.amber),
          if (message.isEdited)
            _InfoRow(
                icon: Icons.edit_outlined,
                label: 'Edited',
                value: 'Yes',
                iconColor: kPurple),
        ],
      ),
    );
  }

  String _msgTypeLabel(MsgType t) {
    switch (t) {
      case MsgType.text:
        return 'Text';
      case MsgType.image:
        return 'Image';
      case MsgType.sticker:
        return 'Sticker';
      case MsgType.voice:
        return 'Voice Message';
      case MsgType.video:
        return 'Video';
      case MsgType.gif:
        return 'GIF';
      case MsgType.callLog:
        return 'Call';
      default:
        return 'Message';
    }
  }

  String _statusLabel(MsgStatus s) {
    switch (s) {
      case MsgStatus.sent:
        return 'Sent ✓';
      case MsgStatus.delivered:
        return 'Delivered ✓✓';
      case MsgStatus.seen:
        return 'Seen ✓✓';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color? iconColor;
  const _InfoRow(
      {required this.icon,
        required this.label,
        required this.value,
        this.valueColor,
        this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor ?? kPurple),
          const SizedBox(width: 16),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w500, fontSize: 15)),
          const Spacer(),
          Text(value,
              style: TextStyle(
                  color: valueColor ?? Colors.grey, fontSize: 15)),
        ],
      ),
    );
  }
}

// ── Forward Screen ────────────────────────────────────────────
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
        title:
        const Text('Forward to', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.forward, color: kPurple, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.message.text ??
                        '[${widget.message.type.name}]',
                    style: const TextStyle(
                        color: Colors.grey, fontStyle: FontStyle.italic),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Recent chats',
                      style: TextStyle(fontWeight: FontWeight.bold)))),
          Expanded(
            child: ListView.builder(
              itemCount: _contacts.length,
              itemBuilder: (context, i) {
                final c = _contacts[i];
                return CheckboxListTile(
                  value: _selected.contains(i),
                  onChanged: (v) {
                    setState(() {
                      if (v == true)
                        _selected.add(i);
                      else
                        _selected.remove(i);
                    });
                  },
                  secondary: ClipOval(
                      child: Image.network(c['avatar']!,
                          width: 44, height: 44, fit: BoxFit.cover)),
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
                    label: Text(
                        'Send to ${_selected.length} contact${_selected.length > 1 ? 's' : ''}'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: kPurple,
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24))),
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(
                              'Message forwarded to ${_selected.length} contact(s)')));
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
  final List<Color> _borderColors = [
    Colors.transparent, Colors.red, Colors.blue,
    Colors.green, Colors.yellow, Colors.purple,
    Colors.orange, Colors.pink
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: const Text('Edit Sticker',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Sticker saved!'),
                  backgroundColor: Colors.green));
            },
            child: const Text('DONE',
                style: TextStyle(
                    color: kPurple, fontWeight: FontWeight.bold)),
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
                  Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.white10)),
                  Transform.scale(
                      scale: _scale,
                      child: Transform.rotate(
                          angle: _rotation,
                          child: Container(
                            decoration: BoxDecoration(
                                border:
                                Border.all(color: _borderColor, width: 4),
                                borderRadius: BorderRadius.circular(12)),
                            child: ColorFiltered(
                              colorFilter: ColorFilter.matrix([
                                _brightness, 0, 0, 0, 0,
                                0, _brightness, 0, 0, 0,
                                0, 0, _brightness, 0, 0,
                                0, 0, 0, 1, 0
                              ]),
                              child: Image.network(widget.stickerUrl,
                                  width: 180,
                                  height: 180,
                                  fit: BoxFit.contain),
                            ),
                          ))),
                  if (_overlayText.isNotEmpty)
                    Positioned(
                        bottom: 40,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(8)),
                          child: Text(_overlayText,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        )),
                ],
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
                color: Color(0xFF0F0F23),
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24))),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSliderRow(Icons.zoom_in, 'Size', _scale, 0.5, 2.0,
                        (v) => setState(() => _scale = v)),
                const SizedBox(height: 12),
                _buildSliderRow(Icons.rotate_right, 'Rotate', _rotation,
                    -3.14, 3.14, (v) => setState(() => _rotation = v)),
                const SizedBox(height: 12),
                _buildSliderRow(
                    Icons.brightness_6,
                    'Brightness',
                    _brightness,
                    0.2,
                    2.0,
                        (v) => setState(() => _brightness = v)),
                const SizedBox(height: 16),
                const Text('Border Color',
                    style:
                    TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                SizedBox(
                    height: 36,
                    child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: _borderColors.map((c) {
                          final bool selected = _borderColor == c;
                          return GestureDetector(
                            onTap: () => setState(() => _borderColor = c),
                            child: Container(
                                width: 32,
                                height: 32,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                    color: c == Colors.transparent
                                        ? Colors.white24
                                        : c,
                                    shape: BoxShape.circle,
                                    border: selected
                                        ? Border.all(
                                        color: Colors.white, width: 2.5)
                                        : null),
                                child: c == Colors.transparent
                                    ? const Icon(Icons.block,
                                    size: 16, color: Colors.white54)
                                    : null),
                          );
                        }).toList())),
                const SizedBox(height: 16),
                const Text('Add Text',
                    style:
                    TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12)),
                  child: TextField(
                      controller: _textCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                          hintText: 'Enter text on sticker...',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none),
                      onChanged: (v) => setState(() => _overlayText = v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow(IconData icon, String label, double value,
      double min, double max, ValueChanged<double> onChanged) {
    return Row(children: [
      Icon(icon, color: Colors.white54, size: 18),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(color: Colors.white70, fontSize: 12)),
      Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
                activeTrackColor: kPurple,
                inactiveTrackColor: Colors.white12,
                thumbColor: kPurple,
                overlayColor: kPurple.withOpacity(0.2)),
            child: Slider(
                value: value, min: min, max: max, onChanged: onChanged),
          )),
    ]);
  }
}