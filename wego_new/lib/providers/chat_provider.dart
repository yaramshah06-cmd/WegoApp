import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:wego_marriage/services/local_storage_service.dart';

class ChatUser {
  final String id;
  final String userId;
  final String name;
  String lastMessage;
  String time;
  final String imageUrl;
  int timestamp;
  int unreadCount;
  bool isTyping;
  String messageType;
  bool isFromMe;
  bool isSeen;
  bool isOnline;

  ChatUser({
    required this.id,
    required this.userId,
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.imageUrl,
    required this.timestamp,
    this.unreadCount = 0,
    this.isTyping = false,
    this.messageType = 'text',
    this.isFromMe = false,
    this.isSeen = false,
    this.isOnline = false,
  });

  String get formattedLastMessage {
    if (isFromMe) {
      switch (messageType) {
        case 'image':
          return 'You: 📷 Photo';
        case 'sticker':
          return 'You: 😍 Sticker';
        case 'voice':
          return 'You: 🎤 Voice message';
        case 'gif':
          return 'You: 🎬 GIF';
        case 'text':
        default:
          if (lastMessage.startsWith('You: ')) {
            return lastMessage;
          }
          return 'You: $lastMessage';
      }
    } else {
      switch (messageType) {
        case 'image':
          return '📷 Photo';
        case 'sticker':
          return '😍 Sticker';
        case 'voice':
          return '🎤 Voice message';
        case 'gif':
          return '🎬 GIF';
        case 'text':
        default:
          return lastMessage;
      }
    }
  }
}

class ChatProvider extends ChangeNotifier {
  final LocalStorageService _storage = LocalStorageService();
  List<ChatUser> _chats = [];

  // ✅ Realtime listener subscription
  StreamSubscription? _realtimeSubscription;

  // ✅ Jin chats ko user ne dekh liya — listener inhe 0 pe rakhe
  final Set<String> _seenChatIds = {};

  List<ChatUser> get chats => _chats;

  // ✅ Total unread count — bottom nav badge ke liye
  int get totalUnreadCount =>
      _chats.fold(0, (sum, chat) => sum + chat.unreadCount);

  // ✅ Constructor — auth listener automatically shuru
  ChatProvider() {
    _startAuthListener();
  }

  // ══════════════════════════════════════════════════════════
  //  Auth Listener — login/logout pe listener start/stop
  // ══════════════════════════════════════════════════════════
  void _startAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _startRealtimeListener();
      } else {
        _stopRealtimeListener();
        _chats = [];
        _seenChatIds.clear();
        notifyListeners();
      }
    });
  }

  // ══════════════════════════════════════════════════════════
  //  Realtime Listener — badge real-time update karta hai
  //  Kisi bhi screen pe ho — badge update hoga
  // ══════════════════════════════════════════════════════════
  void _startRealtimeListener() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _realtimeSubscription?.cancel();

    FirebaseDatabase.instance.ref('chats').onValue.listen((event) {
      if (!event.snapshot.exists) {
        for (var chat in _chats) {
          chat.unreadCount = 0;
        }
        notifyListeners();
        return;
      }

      try {
        final allChats =
        Map<String, dynamic>.from(event.snapshot.value as Map);

        for (var chat in _chats) {
          // ✅ Seen chat ko 0 pe rakho — Firebase se restore mat karo
          if (_seenChatIds.contains(chat.id)) {
            chat.unreadCount = 0;
            continue;
          }

          if (!allChats.containsKey(chat.id)) continue;

          final chatData =
          Map<String, dynamic>.from(allChats[chat.id] as Map);

          if (chatData['messages'] == null) {
            chat.unreadCount = 0;
            continue;
          }

          int count = 0;
          final messages =
          Map<String, dynamic>.from(chatData['messages'] as Map);

          for (final msg in messages.values) {
            final m = Map<String, dynamic>.from(msg as Map);
            final senderId = m['senderId'] as String? ?? '';
            final status = m['status'] as int? ?? 0;
            final isDeleted = m['isDeleted'] as bool? ?? false;
            final isUnsent = m['isUnsent'] as bool? ?? false;

            if (senderId != currentUser.uid &&
                status < 2 &&
                !isDeleted &&
                !isUnsent) {
              count++;
            }
          }

          chat.unreadCount = count;
        }

        notifyListeners();
      } catch (e) {
        debugPrint('Badge listener error: $e');
      }
    });
  }

  void _stopRealtimeListener() {
    _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }

  // ══════════════════════════════════════════════════════════
  //  loadChats() — pehli baar chats load karo
  // ══════════════════════════════════════════════════════════
  Future<void> loadChats() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final db = FirebaseDatabase.instance;
      final snapshot = await db.ref('chats').get();

      final List<ChatUser> loaded = [];

      if (snapshot.value != null) {
        final allChats = Map<String, dynamic>.from(snapshot.value as Map);

        for (final entry in allChats.entries) {
          final chatRoomId = entry.key;

          if (!chatRoomId.contains(currentUser.uid)) continue;

          final parts = chatRoomId.split('_');
          String otherUid = '';
          if (parts.length == 2) {
            otherUid = parts[0] == currentUser.uid ? parts[1] : parts[0];
          } else {
            otherUid = chatRoomId
                .replaceFirst('${currentUser.uid}_', '')
                .replaceFirst('_${currentUser.uid}', '');
          }

          if (otherUid.isEmpty || otherUid == currentUser.uid) continue;

          final chatData = Map<String, dynamic>.from(entry.value as Map);
          final lastMsgData = chatData['lastMessage'] != null
              ? Map<String, dynamic>.from(chatData['lastMessage'] as Map)
              : <String, dynamic>{};

          final lastMsgText = lastMsgData['text'] as String? ?? '';
          final lastMsgTime = lastMsgData['timestamp'];
          final lastMsgSender = lastMsgData['senderId'] as String? ?? '';

          // ✅ Unread count calculate karo
          int unreadCount = 0;
          if (chatData['messages'] != null) {
            final messages =
            Map<String, dynamic>.from(chatData['messages'] as Map);
            for (final msg in messages.values) {
              final msgMap = Map<String, dynamic>.from(msg as Map);
              final senderId = msgMap['senderId'] as String? ?? '';
              final status = msgMap['status'] as int? ?? 0;
              final isDeleted = msgMap['isDeleted'] as bool? ?? false;
              final isUnsent = msgMap['isUnsent'] as bool? ?? false;

              if (senderId != currentUser.uid &&
                  status < 2 &&
                  !isDeleted &&
                  !isUnsent) {
                unreadCount++;
              }
            }
          }

          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(otherUid)
              .get();
          final userData = userDoc.data() ?? {};

          loaded.add(ChatUser(
            id: chatRoomId,
            userId: otherUid,
            name: userData['username'] ??
                userData['fullName'] ??
                userData['name'] ??
                'Unknown',
            imageUrl: userData['photoUrl'] ?? '',
            lastMessage: lastMsgText,
            time: _formatTimestamp(lastMsgTime),
            timestamp: lastMsgTime is int ? lastMsgTime : 0,
            isOnline: userData['online'] ?? false,
            isFromMe: lastMsgSender == currentUser.uid,
            unreadCount: unreadCount,
          ));
        }
      }

      final Map<String, ChatUser> mergedMap = {};
      for (var chat in loaded) {
        mergedMap[chat.userId] = chat;
      }

      _chats = mergedMap.values.toList();
      _chats.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();

      debugPrint('Chats loaded: ${_chats.length}');
    } catch (e) {
      debugPrint('Chat load error: $e');
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    int ms = 0;
    if (timestamp is int) {
      ms = timestamp;
    } else {
      return '';
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void updateChatPosition(
      String username,
      String lastMessage,
      String time,
      String avatarUrl,
      String receiverUid, {
        String messageType = 'text',
      }) {
    final now = DateTime.now().millisecondsSinceEpoch;

    // ✅ Naya message aaya — seen list se hata do taake badge dobara show ho
    final existingChat = _chats.firstWhere(
          (c) => c.userId == receiverUid,
      orElse: () => ChatUser(
          id: '', userId: '', name: '', lastMessage: '',
          time: '', imageUrl: '', timestamp: 0),
    );
    if (existingChat.id.isNotEmpty) {
      _seenChatIds.remove(existingChat.id);
    }

    int existingIndex = _chats.indexWhere((c) => c.userId == receiverUid);
    if (existingIndex < 0) {
      existingIndex = _chats.indexWhere((c) => c.name == username);
    }

    if (existingIndex >= 0) {
      final chat = _chats[existingIndex];
      chat.lastMessage = lastMessage;
      chat.time = time;
      chat.timestamp = now;
      chat.messageType = messageType;
      chat.isFromMe = false;
      chat.isSeen = false;
      chat.unreadCount++;

      _chats.removeAt(existingIndex);
      _chats.insert(0, chat);
    } else {
      _chats.insert(
        0,
        ChatUser(
          id: 'dyn_$receiverUid',
          userId: receiverUid,
          name: username,
          lastMessage: lastMessage,
          time: time,
          imageUrl: avatarUrl,
          timestamp: now,
          unreadCount: 1,
          messageType: messageType,
          isFromMe: false,
          isSeen: false,
        ),
      );
    }

    notifyListeners();
  }

  void addSentMessage(
      String username,
      String messagePreview,
      String time,
      String avatarUrl,
      String receiverUid, {
        String messageType = 'text',
      }) {
    final now = DateTime.now().millisecondsSinceEpoch;

    int existingIndex = _chats.indexWhere((c) => c.userId == receiverUid);
    if (existingIndex < 0) {
      existingIndex = _chats.indexWhere((c) => c.name == username);
    }

    if (existingIndex >= 0) {
      final chat = _chats[existingIndex];
      chat.lastMessage = messagePreview;
      chat.time = time;
      chat.timestamp = now;
      chat.messageType = messageType;
      chat.isFromMe = true;
      chat.isSeen = false;

      _chats.removeAt(existingIndex);
      _chats.insert(0, chat);
    } else {
      _chats.insert(
        0,
        ChatUser(
          id: 'dyn_$receiverUid',
          userId: receiverUid,
          name: username,
          lastMessage: messagePreview,
          time: time,
          imageUrl: avatarUrl,
          timestamp: now,
          messageType: messageType,
          isFromMe: true,
          isSeen: false,
        ),
      );
    }

    notifyListeners();
  }

  // ══════════════════════════════════════════════════════════
  //  markChatAsSeen() — chat open hone par:
  //  1. Local badge turant 0
  //  2. Listener ko rokna — dobara restore na kare
  //  3. Firebase mein status=2 set karna
  // ══════════════════════════════════════════════════════════
  Future<void> markChatAsSeen(String chatRoomId) async {
    // ✅ Step 1: Local — turant badge 0
    final chatIndex = _chats.indexWhere((c) => c.id == chatRoomId);
    if (chatIndex >= 0) {
      _chats[chatIndex].isSeen = true;
      _chats[chatIndex].unreadCount = 0;
    }

    // ✅ Step 2: Seen set mein add — listener dobara count restore na kare
    _seenChatIds.add(chatRoomId);
    notifyListeners();

    // ✅ Step 3: Firebase mein status=2 aur isRead=true set karo
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref('chats/$chatRoomId/messages')
          .get();

      if (snapshot.value == null) return;

      final messages = Map<String, dynamic>.from(snapshot.value as Map);
      final updates = <String, dynamic>{};

      messages.forEach((key, value) {
        final msg = Map<String, dynamic>.from(value as Map);
        final senderId = msg['senderId'] as String? ?? '';
        final status = msg['status'] as int? ?? 0;

        if (senderId != currentUser.uid && status < 2) {
          updates['chats/$chatRoomId/messages/$key/status'] = 2;
          updates['chats/$chatRoomId/messages/$key/isRead'] = true;
        }
      });

      if (updates.isNotEmpty) {
        await FirebaseDatabase.instance.ref().update(updates);
      }

      // ✅ Step 4: Firebase update ke baad seen set se hata do
      // (ab Firebase mein bhi status=2 hai, listener bhi sahi count dega)
      _seenChatIds.remove(chatRoomId);
    } catch (e) {
      debugPrint('markChatAsSeen error: $e');
      // Error pe bhi seen set mein rakho taake badge 0 rahe
    }
  }

  void deleteChat(String username) {
    _chats.removeWhere((chat) => chat.name == username);
    notifyListeners();
  }

  @override
  void dispose() {
    _stopRealtimeListener();
    super.dispose();
  }
}