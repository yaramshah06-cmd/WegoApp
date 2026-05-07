import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class StoryItem {
  final String id;
  final String imageUrl;
  final String username;
  final String avatarUrl;

  StoryItem({
    required this.id,
    required this.imageUrl,
    required this.username,
    required this.avatarUrl,
  });
}

class UserStory {
  final String userId;      // ✅ required field — error fix
  final String username;
  final String avatarUrl;
  final List<StoryItem> stories;
  bool isWatched;

  UserStory({
    required this.userId,   // ✅ required
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

  StoryProvider() {
    fetchStories();
  }

  /// Unwatched pehle, phir watched
  List<UserStory> get userStories {
    final unwatched = _userStories.where((u) => !u.isWatched).toList();
    final watched   = _userStories.where((u) =>  u.isWatched).toList();
    return [...unwatched, ...watched];
  }

  /// Firebase se real stories fetch karo — koi dummy data nahi
  Future<void> fetchStories() async {
    isLoading = true;
    notifyListeners();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        isLoading = false;
        notifyListeners();
        return;
      }

      // Sirf last 24 ghante ki stories
      final since = Timestamp.fromDate(
        DateTime.now().subtract(const Duration(hours: 24)),
      );

      final snapshot = await FirebaseFirestore.instance
          .collection('stories')
          .where('createdAt', isGreaterThan: since)
          .orderBy('createdAt', descending: false)
          .get();

      // userId ke hisaab se group karo
      final Map<String, List<StoryItem>> grouped = {};
      final Map<String, Map<String, dynamic>> userCache = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final String uid = data['userId'] ?? '';
        if (uid.isEmpty) continue;

        // Us user ki info ek baar fetch karo
        if (!userCache.containsKey(uid)) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();
          userCache[uid] = userDoc.data() ?? {};
        }

        final userData = userCache[uid]!;
        final item = StoryItem(
          id: doc.id,
          imageUrl: data['imageUrl'] ?? '',
          username: userData['username'] ?? 'Unknown',
          avatarUrl: userData['photoUrl'] ?? '',
        );

        grouped.putIfAbsent(uid, () => []);
        grouped[uid]!.add(item);
      }

      // UserStory list banao
      final List<UserStory> fetched = [];
      for (final entry in grouped.entries) {
        final uid      = entry.key;
        final userData = userCache[uid] ?? {};

        fetched.add(UserStory(
          userId:    uid,                               // ✅ userId pass — error fix
          username:  userData['username'] ?? 'Unknown',
          avatarUrl: userData['photoUrl'] ?? '',
          stories:   entry.value,
          isWatched: false,
        ));
      }

      // Apni story sab se pehle
      fetched.sort((a, b) {
        if (a.userId == currentUser.uid) return -1;
        if (b.userId == currentUser.uid) return 1;
        return 0;
      });

      _userStories = fetched;
    } catch (e) {
      debugPrint('Story fetch error: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void markAsWatched(String userId) {
    final index = _userStories.indexWhere((u) => u.userId == userId);
    if (index != -1 && !_userStories[index].isWatched) {
      _userStories[index].isWatched = true;
      notifyListeners();
    }
  }

  /// Bahar se refresh karne ke liye (pull-to-refresh etc.)
  Future<void> refresh() => fetchStories();
}