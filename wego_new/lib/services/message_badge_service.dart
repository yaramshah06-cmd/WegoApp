import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// ══════════════════════════════════════════════════════════════
//  MessageBadgeService
//  - App ke kisi bhi screen par ho, badge globally update hoga
//  - Aapke Firebase structure ke saath exact match:
//    chats/{chatRoomId}/messages/{msgId}/isRead
//    chats/{chatRoomId}/messages/{msgId}/senderId
// ══════════════════════════════════════════════════════════════

class MessageBadgeService {
  // ── Singleton ─────────────────────────────────────────────
  MessageBadgeService._internal();
  static final MessageBadgeService _instance =
  MessageBadgeService._internal();
  factory MessageBadgeService() => _instance;

  // ── Global unread count — koi bhi screen sun sakti hai ────
  static final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  static StreamSubscription? _subscription;

  // ══════════════════════════════════════════════════════════
  //  startListening()
  //  Call karo: main.dart ya AuthWrapper mein jab user login ho
  // ══════════════════════════════════════════════════════════
  static void startListening() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    // Pehla purana listener cancel karo (agar tha)
    _subscription?.cancel();

    final ref = FirebaseDatabase.instance.ref('chats');

    _subscription = ref.onValue.listen((event) {
      if (!event.snapshot.exists) {
        unreadCount.value = 0;
        return;
      }

      int count = 0;

      try {
        final chatsData =
        Map<String, dynamic>.from(event.snapshot.value as Map);

        chatsData.forEach((chatRoomId, chatRoomValue) {
          // Sirf woh chatRoom check karo jisme current user hai
          // ChatRoomId format: uid1_uid2 (alphabetical order)
          if (!chatRoomId.contains(currentUserId)) return;

          if (chatRoomValue == null) return;

          final chatRoom =
          Map<String, dynamic>.from(chatRoomValue as Map);

          if (chatRoom['messages'] == null) return;

          final messages =
          Map<String, dynamic>.from(chatRoom['messages'] as Map);

          messages.forEach((msgId, msgValue) {
            if (msgValue == null) return;

            final msg = Map<String, dynamic>.from(msgValue as Map);

            // ── Unread message conditions ──────────────────
            // 1. senderId current user ka nahi hona chahiye (received msg)
            // 2. isRead false hona chahiye
            // 3. isDeleted aur isUnsent false hona chahiye
            final String senderId = (msg['senderId'] as String?) ?? '';
            final bool isRead = (msg['isRead'] as bool?) ?? false;
            final bool isDeleted = (msg['isDeleted'] as bool?) ?? false;
            final bool isUnsent = (msg['isUnsent'] as bool?) ?? false;

            if (senderId != currentUserId &&
                !isRead &&
                !isDeleted &&
                !isUnsent) {
              count++;
            }
          });
        });
      } catch (e) {
        debugPrint('MessageBadgeService error: $e');
      }

      // ── ValueNotifier update — UI automatically refresh hoga ──
      unreadCount.value = count;
    });
  }

  // ══════════════════════════════════════════════════════════
  //  stopListening()
  //  Call karo: logout par ya app close par
  // ══════════════════════════════════════════════════════════
  static void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    unreadCount.value = 0;
  }

  // ══════════════════════════════════════════════════════════
  //  resetBadge()
  //  Call karo: jab user Messages list screen open kare
  //  (Badge 0 ho jaye screen open hone par)
  // ══════════════════════════════════════════════════════════
  static void resetBadge() {
    unreadCount.value = 0;
  }
}

// ══════════════════════════════════════════════════════════════
//
//  INTEGRATION GUIDE — In files mein changes karo:
//
// ══════════════════════════════════════════════════════════════
//
//  ── 1. main.dart ─────────────────────────────────────────────
//
//  class _MyAppState extends State<MyApp> {
//    @override
//    void initState() {
//      super.initState();
//      FirebaseAuth.instance.authStateChanges().listen((user) {
//        if (user != null) {
//          MessageBadgeService.startListening(); // login hone par
//        } else {
//          MessageBadgeService.stopListening();  // logout hone par
//        }
//      });
//    }
//  }
//
// ══════════════════════════════════════════════════════════════
//
//  ── 2. Bottom Navigation Bar (jahan bhi hai aapka) ───────────
//
//  BottomNavigationBarItem(
//    icon: ValueListenableBuilder<int>(
//      valueListenable: MessageBadgeService.unreadCount,
//      builder: (context, count, child) {
//        return Badge(
//          isLabelVisible: count > 0,
//          label: Text(
//            count > 99 ? '99+' : '$count',
//            style: TextStyle(color: Colors.white, fontSize: 10),
//          ),
//          child: Icon(Icons.message),
//        );
//      },
//    ),
//    label: 'Messages',
//  ),
//
// ══════════════════════════════════════════════════════════════
//
//  ── 3. Message List Screen (jab open ho) ─────────────────────
//
//  @override
//  void initState() {
//    super.initState();
//    MessageBadgeService.resetBadge(); // screen open hone par reset
//  }
//
// ══════════════════════════════════════════════════════════════
//
//  ── 4. ChatScreen — pehle se sahi hai, sirf confirm karo ─────
//
//  _sendMessage() mein 'isRead': false already add hai ✅
//  markMessagesSeen() mein 'isRead': true already add hai ✅
//  Koi change nahi chahiye ChatScreen mein!
//
// ══════════════════════════════════════════════════════════════