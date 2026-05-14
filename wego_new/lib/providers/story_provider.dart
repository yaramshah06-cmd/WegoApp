import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class StoryItem {
  final String id;
  final String imageUrl;
  final String username;
  final String avatarUrl;
  final bool isVideo;

  StoryItem({
    required this.id,
    required this.imageUrl,
    required this.username,
    required this.avatarUrl,
    this.isVideo = false,
  });
}

class UserStory {
  final String userId;
  final String username;
  final String avatarUrl;
  final List<StoryItem> stories;
  bool isWatched;

  UserStory({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.stories,
    this.isWatched = false,
  });
}

// ─── Provider ─────────────────────────────────────────────────────────────────

class StoryProvider with ChangeNotifier {
  List<UserStory> _userStories = [];
  bool isLoading = false;

  StreamSubscription<QuerySnapshot>? _storiesSub;
  StreamSubscription<User?>? _authSub;

  StoryProvider() {
    // Auth state ke saath stream attach/reattach karo
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _stopListening();
        _userStories = [];
        notifyListeners();
      } else {
        _startListening(user.uid);
      }
    });

    final cur = FirebaseAuth.instance.currentUser;
    if (cur != null) _startListening(cur.uid);
  }

  /// Unwatched pehle, phir watched
  List<UserStory> get userStories {
    final unwatched = _userStories.where((u) => !u.isWatched).toList();
    final watched = _userStories.where((u) => u.isWatched).toList();
    return [...unwatched, ...watched];
  }

  void _stopListening() {
    _storiesSub?.cancel();
    _storiesSub = null;
  }

  void _startListening(String currentUid) {
    _stopListening();
    isLoading = true;
    notifyListeners();

    final since = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(hours: 24)),
    );

    _storiesSub = FirebaseFirestore.instance
        .collection('stories')
        .where('createdAt', isGreaterThan: since)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .listen(
      (snapshot) async {
        try {
          // Group by userId + apply visibility filter
          final Map<String, List<StoryItem>> grouped = {};
          final Map<String, Map<String, dynamic>> userCache = {};

          for (final doc in snapshot.docs) {
            final data = doc.data();
            final String uid = (data['userId'] as String?) ?? '';
            if (uid.isEmpty) continue;

            final visibility =
                (data['visibility'] as String?) ?? 'everyone';
            final allowedUids =
                List<String>.from(data['allowedUids'] ?? const []);

            // ── Privacy filter ──
            // only_me: sirf author dekh sake
            if (visibility == 'only_me' && uid != currentUid) continue;
            // close_friends: sirf allowedUids (jisme author bhi shaamil hai)
            if (visibility == 'close_friends' &&
                !allowedUids.contains(currentUid) &&
                uid != currentUid) {
              continue;
            }
            // everyone: sab dekh sakte hain
            // (Author khud apni har story dekh sake — uid == currentUid case above cover karta hai)

            // Author info cache (avoid duplicate fetch)
            if (!userCache.containsKey(uid)) {
              final cachedUsername = data['username'] as String?;
              final cachedAvatar = data['avatarUrl'] as String?;
              if (cachedUsername != null && cachedAvatar != null) {
                userCache[uid] = {
                  'username': cachedUsername,
                  'photoUrl': cachedAvatar,
                };
              } else {
                final userDoc = await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .get();
                userCache[uid] = userDoc.data() ?? {};
              }
            }

            final userData = userCache[uid]!;
            final item = StoryItem(
              id: doc.id,
              imageUrl: (data['imageUrl'] as String?) ?? '',
              username: (userData['username'] as String?) ?? 'Unknown',
              avatarUrl: (userData['photoUrl'] as String?) ?? '',
              isVideo: (data['isVideo'] as bool?) ?? false,
            );

            grouped.putIfAbsent(uid, () => []);
            grouped[uid]!.add(item);
          }

          final List<UserStory> fetched = [];
          for (final entry in grouped.entries) {
            final uid = entry.key;
            final userData = userCache[uid] ?? {};
            fetched.add(UserStory(
              userId: uid,
              username: (userData['username'] as String?) ?? 'Unknown',
              avatarUrl: (userData['photoUrl'] as String?) ?? '',
              stories: entry.value,
              isWatched: false,
            ));
          }

          // Apni story sab se pehle
          fetched.sort((a, b) {
            if (a.userId == currentUid) return -1;
            if (b.userId == currentUid) return 1;
            return 0;
          });

          // Preserve watched state across rebuilds
          final prevWatched = {
            for (final u in _userStories)
              if (u.isWatched) u.userId,
          };
          for (final u in fetched) {
            if (prevWatched.contains(u.userId)) u.isWatched = true;
          }

          _userStories = fetched;
        } catch (e) {
          debugPrint('Story stream process error: $e');
        } finally {
          isLoading = false;
          notifyListeners();
        }
      },
      onError: (e) {
        debugPrint('Story stream error: $e');
        isLoading = false;
        notifyListeners();
      },
    );
  }

  void markAsWatched(String userId) {
    final index = _userStories.indexWhere((u) => u.userId == userId);
    if (index != -1 && !_userStories[index].isWatched) {
      _userStories[index].isWatched = true;
      notifyListeners();
    }
  }

  /// Pull-to-refresh — stream already real-time, sirf re-attach
  Future<void> refresh() async {
    final cur = FirebaseAuth.instance.currentUser;
    if (cur != null) _startListening(cur.uid);
  }

  /// Backwards-compat — purane callers ke liye
  Future<void> fetchStories() => refresh();

  @override
  void dispose() {
    _storiesSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}
