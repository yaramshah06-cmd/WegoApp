import 'package:flutter/material.dart';
import 'package:wego_marriage/screen/user_profile_screen.dart';
import 'package:wego_marriage/screen/chat_screen.dart';

class FollowListScreen extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> users;
  final bool isFollowing;

  const FollowListScreen({
    super.key,
    required this.title,
    required this.users,
    this.isFollowing = true,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  late List<Map<String, dynamic>> _filteredUsers;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredUsers = List.from(widget.users);
  }

  void _search(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredUsers = List.from(widget.users);
      } else {
        _filteredUsers = widget.users.where((user) {
          return user['name'].toLowerCase().contains(query.toLowerCase()) ||
              user['username'].toLowerCase().contains(query.toLowerCase());
        }).toList();
      }
    });
  }

  void _navigateToProfile(String name, String avatar) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          username: name,
          avatarUrl: avatar,
        ),
      ),
    );
  }

  void _navigateToChat(String name, String avatar) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          username: name,
          avatarUrl: avatar,
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
        backgroundColor: isDark ? Colors.black : const Color(0xFF7A1730),
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
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _search,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  hintText: 'Search users...',
                  hintStyle: TextStyle(color: secondaryTextColor),
                  prefixIcon: Icon(Icons.search, color: secondaryTextColor),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ),
          // User list
          Expanded(
            child: _filteredUsers.isEmpty
                ? Center(
                    child: Text(
                      'No users found',
                      style: TextStyle(color: secondaryTextColor, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = _filteredUsers[index];
                      return _buildUserTile(user, isDark, textColor, secondaryTextColor);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, bool isDark, Color textColor, Color secondaryTextColor) {
    final primaryColor = const Color(0xFF7A1730);
    return GestureDetector(
      onTap: () => _navigateToProfile(user['name'], user['avatar']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? Colors.white24 : const Color(0xFF7A1730), width: 2),
              ),
              child: ClipOval(
                child: Image.network(
                  user['avatar'],
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: const Color(0xFF7A1730),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFF7A1730),
                    child: const Icon(Icons.person, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['name'],
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user['username'],
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Message icon
            IconButton(
              onPressed: () => _navigateToChat(user['name'], user['avatar']),
              icon: Icon(
                Icons.message_outlined,
                color: primaryColor,
                size: 22,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 8),
            // Follow/Unfollow button
            GestureDetector(
              onTap: () {
                setState(() {
                  user['isFollowing'] = !user['isFollowing'];
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: user['isFollowing']
                      ? (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey[300])
                      : const Color(0xFF3DDC84),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user['isFollowing'] ? 'Following' : 'Follow',
                  style: TextStyle(
                    color: user['isFollowing'] ? textColor : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
