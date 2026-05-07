import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wego_marriage/screen/user_profile_screen.dart';
import 'package:wego_marriage/screen/chat_screen.dart';
import 'app_localizations.dart';
import 'app_translations.dart';

class FollowListScreen extends StatefulWidget {
  final String title;
  final String targetUserId;

  const FollowListScreen({
    super.key,
    required this.title,
    required this.targetUserId,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final String? _currentUid = FirebaseAuth.instance.currentUser?.uid;

  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final isFollowers = widget.title.toLowerCase().contains('follower');
      final subCollection = isFollowers ? 'followers' : 'following';

      final subSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.targetUserId)
          .collection(subCollection)
          .get();

      if (subSnap.docs.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final List<Map<String, dynamic>> users = [];

      for (final doc in subSnap.docs) {
        final uid = doc.id;
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

          if (userDoc.exists) {
            final data = userDoc.data()!;

            bool isFollowing = false;
            if (_currentUid != null) {
              final followCheck = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('followers')
                  .doc(_currentUid)
                  .get();
              isFollowing = followCheck.exists;
            }

            users.add({
              'userId': uid,
              'name': data['name'] ??
                  data['displayName'] ??
                  data['fullName'] ??
                  data['username'] ??
                  '',
              'username': data['username'] ?? '',
              'avatar': data['photoUrl'] ?? '',
              'bio': data['bio'] ?? '',
              'isFollowing': isFollowing,
            });
          }
        } catch (e) {
          debugPrint('❌ User fetch error ($uid): $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _allUsers = users;
        _filteredUsers = List.from(users);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Follow list fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleFollow(Map<String, dynamic> user) async {
    final targetUid = user['userId'] as String? ?? '';
    if (targetUid.isEmpty || _currentUid == null) return;

    final isFollowing = user['isFollowing'] as bool? ?? false;
    setState(() => user['isFollowing'] = !isFollowing);

    try {
      final targetFollowersRef = FirebaseFirestore.instance
          .collection('users')
          .doc(targetUid)
          .collection('followers')
          .doc(_currentUid);

      final myFollowingRef = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUid)
          .collection('following')
          .doc(targetUid);

      if (isFollowing) {
        await targetFollowersRef.delete();
        await myFollowingRef.delete();
      } else {
        await targetFollowersRef.set({
          'uid': _currentUid,
          'followedAt': FieldValue.serverTimestamp(),
        });
        await myFollowingRef.set({
          'uid': targetUid,
          'followedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('❌ Toggle follow error: $e');
      if (mounted) setState(() => user['isFollowing'] = isFollowing);
    }
  }

  void _search(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(_allUsers);
      } else {
        final lower = query.toLowerCase();
        _filteredUsers = _allUsers.where((user) {
          return (user['name'] as String).toLowerCase().contains(lower) ||
              (user['username'] as String).toLowerCase().contains(lower);
        }).toList();
      }
    });
  }

  void _navigateToProfile(Map<String, dynamic> user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: user['userId'] as String? ?? '',
          username:
          user['username'] as String? ?? user['name'] as String? ?? '',
          avatarUrl: user['avatar'] as String? ?? '',
        ),
      ),
    );
  }

  void _navigateToChat(Map<String, dynamic> user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          username:
          user['username'] as String? ?? user['name'] as String? ?? '',
          avatarUrl: user['avatar'] as String? ?? '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : const Color(0xFF5B2BE8),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF5B2BE8)))
          : Column(
        children: [
          // ── Search bar ✅ TRANSLATED ──────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _search,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: context.tr('search_users'), // ✅
                  hintStyle: TextStyle(color: secondaryTextColor),
                  prefixIcon:
                  Icon(Icons.search, color: secondaryTextColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ),

          // ── User list ─────────────────────────────────
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline,
                      size: 60,
                      color: isDark
                          ? Colors.grey[700]
                          : Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text(
                    // ✅ TRANSLATED
                    _searchController.text.isNotEmpty
                        ? context.tr('no_users_found')
                        : context.tr('no_list_yet'),
                    style: TextStyle(
                        color: secondaryTextColor, fontSize: 16),
                  ),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: _fetchUsers,
              color: const Color(0xFF5B2BE8),
              child: ListView.builder(
                padding:
                const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  return _buildUserTile(
                      user, isDark, textColor, secondaryTextColor);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, bool isDark,
      Color textColor, Color secondaryTextColor) {
    final primaryColor = const Color(0xFF5B2BE8);
    final isOwnAccount = user['userId'] == _currentUid;

    return GestureDetector(
      onTap: () => _navigateToProfile(user),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withOpacity(0.05)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // ── Avatar ────────────────────────────────────────
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isDark
                        ? Colors.white24
                        : const Color(0xFF5B2BE8),
                    width: 2),
              ),
              child: ClipOval(
                child: (user['avatar'] as String).isNotEmpty
                    ? Image.network(
                  user['avatar'],
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: const Color(0xFF7B4EDB),
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF7B4EDB),
                    child:
                    const Icon(Icons.person, color: Colors.white),
                  ),
                )
                    : Container(
                  color: const Color(0xFF7B4EDB),
                  child: Center(
                    child: Text(
                      (user['name'] as String).isNotEmpty
                          ? (user['name'] as String)[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ── User info ─────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (user['name'] as String).isNotEmpty
                        ? user['name']
                        : user['username'],
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if ((user['username'] as String).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${user['username']}',
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  if ((user['bio'] as String).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user['bio'],
                      style:
                      TextStyle(color: secondaryTextColor, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            // ── Buttons — apna account nahi ──────────────────
            if (!isOwnAccount) ...[
              IconButton(
                onPressed: () => _navigateToChat(user),
                icon: Icon(Icons.message_outlined,
                    color: primaryColor, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),

              // Follow / Unfollow ✅ TRANSLATED
              GestureDetector(
                onTap: () => _toggleFollow(user),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: user['isFollowing'] == true
                        ? (isDark
                        ? Colors.white.withOpacity(0.2)
                        : Colors.grey[300])
                        : const Color(0xFF3DDC84),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    user['isFollowing'] == true
                        ? context.tr('following') // ✅
                        : context.tr('follow'),   // ✅
                    style: TextStyle(
                      color: user['isFollowing'] == true
                          ? textColor
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}