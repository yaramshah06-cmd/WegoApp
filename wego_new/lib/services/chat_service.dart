import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ── Do users ke beech unique chatId banao ──
  // Dono UIDs ko sort karke join karo taake same chatId mile
  String getChatId(String userId1, String userId2) {
    final sorted = [userId1, userId2]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }

  // ── Current logged in user ka UID ──
  String get currentUserId => _auth.currentUser?.uid ?? '';

  // ── Message bhejo Firestore mein ──
  Future<void> sendMessage({
    required String receiverId,
    required String text,
    String type = 'text',
    String? imageUrl,
    String? fileName,
    int? fileSize,
    String? replyToText,
    String? replyToType,
    Duration? duration,
  }) async {
    final senderId = currentUserId;
    if (senderId.isEmpty) return;

    final chatId = getChatId(senderId, receiverId);
    final now = DateTime.now();

    // Time format karo
    final hour = now.hour > 12
        ? now.hour - 12
        : (now.hour == 0 ? 12 : now.hour);
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:${now.minute.toString().padLeft(2, '0')} $amPm';

    final messageData = {
      'senderId': senderId,
      'receiverId': receiverId,
      'text': text,
      'type': type,
      'imageUrl': imageUrl,
      'fileName': fileName,
      'fileSize': fileSize,
      'replyToText': replyToText,
      'replyToType': replyToType,
      'duration': duration?.inSeconds,
      'timestamp': FieldValue.serverTimestamp(),
      'time': timeStr,
      'isDeleted': false,
      'isUnsent': false,
      'isEdited': false,
      'isStarred': false,
      'isPinned': false,
      'reactions': {},
      'status': 0, // 0=sent, 1=delivered, 2=seen
    };

    // Messages subcollection mein add karo
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    // Chat document update karo (last message ke liye)
    await _firestore.collection('chats').doc(chatId).set({
      'participants': [senderId, receiverId],
      'lastMessage': text.isNotEmpty ? text : '[$type]',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': senderId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Real-time messages stream ──
  Stream<QuerySnapshot> getMessagesStream(String otherUserId) {
    final chatId = getChatId(currentUserId, otherUserId);
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)
        .snapshots();
  }

  // ── Message delete karo (sirf apne liye) ──
  Future<void> deleteMessage({
    required String otherUserId,
    required String messageDocId,
  }) async {
    final chatId = getChatId(currentUserId, otherUserId);
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageDocId)
        .update({'isDeleted': true});
  }

  // ── Message unsend karo (sab ke liye) ──
  Future<void> unsendMessage({
    required String otherUserId,
    required String messageDocId,
  }) async {
    final chatId = getChatId(currentUserId, otherUserId);
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageDocId)
        .update({'isUnsent': true, 'text': ''});
  }

  // ── Message edit karo ──
  Future<void> editMessage({
    required String otherUserId,
    required String messageDocId,
    required String newText,
  }) async {
    final chatId = getChatId(currentUserId, otherUserId);
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageDocId)
        .update({'text': newText, 'isEdited': true});
  }

  // ── Message star karo ──
  Future<void> starMessage({
    required String otherUserId,
    required String messageDocId,
    required bool isStarred,
  }) async {
    final chatId = getChatId(currentUserId, otherUserId);
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageDocId)
        .update({'isStarred': isStarred});
  }

  // ── Message pin karo ──
  Future<void> pinMessage({
    required String otherUserId,
    required String messageDocId,
    required bool isPinned,
  }) async {
    final chatId = getChatId(currentUserId, otherUserId);
    // Pehle sab unpin karo
    if (isPinned) {
      final batch = _firestore.batch();
      final msgs = await _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('isPinned', isEqualTo: true)
          .get();
      for (final doc in msgs.docs) {
        batch.update(doc.reference, {'isPinned': false});
      }
      await batch.commit();
    }
    // Ab is message ko pin/unpin karo
    await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageDocId)
        .update({'isPinned': isPinned});
  }

  // ── Reaction add/remove karo ──
  Future<void> toggleReaction({
    required String otherUserId,
    required String messageDocId,
    required String emoji,
    required String myUid,
  }) async {
    final chatId = getChatId(currentUserId, otherUserId);
    final docRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageDocId);

    final doc = await docRef.get();
    final data = doc.data() as Map<String, dynamic>;
    final reactions = Map<String, List<dynamic>>.from(
      (data['reactions'] as Map<String, dynamic>? ?? {}).map(
            (k, v) => MapEntry(k, List<dynamic>.from(v as List)),
      ),
    );

    if (reactions[emoji] == null) {
      reactions[emoji] = [myUid];
    } else if (reactions[emoji]!.contains(myUid)) {
      reactions[emoji]!.remove(myUid);
      if (reactions[emoji]!.isEmpty) reactions.remove(emoji);
    } else {
      reactions[emoji]!.add(myUid);
    }

    await docRef.update({'reactions': reactions});
  }

  // ── Messages seen mark karo ──
  Future<void> markMessagesAsSeen(String otherUserId) async {
    final chatId = getChatId(currentUserId, otherUserId);
    final batch = _firestore.batch();

    final unseenMsgs = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('receiverId', isEqualTo: currentUserId)
        .where('status', isLessThan: 2)
        .get();

    for (final doc in unseenMsgs.docs) {
      batch.update(doc.reference, {'status': 2});
    }
    await batch.commit();
  }

  // ── User ka receiverId Firestore users se fetch karo ──
  Future<String?> getUserIdByUsername(String username) async {
    final query = await _firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.id;
    }
    return null;
  }
}