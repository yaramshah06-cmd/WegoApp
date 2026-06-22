import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wego_marriage/providers/chat_provider.dart';
import 'package:wego_marriage/screen/user_profile_screen.dart';
import 'package:wego_marriage/screen/chat_screen.dart';

// ── Colors ────────────────────────────────────────────────────
const Color kPrimaryBlue = Color(0xFF7A1730);
const Color kTeal = Color(0xFF2EC4B6);
const Color kOnline = Color(0xFF44D362);
const Color kUnreadRed = Color(0xFFFF3B30);

// ── Models ────────────────────────────────────────────────────
class ActivityUser {
  final String name;
  final String imageUrl;
  final bool isOnline;
  final bool isYou;

  const ActivityUser({
    required this.name,
    required this.imageUrl,
    this.isOnline = false,
    this.isYou = false,
  });
}

// ── Main Screen ───────────────────────────────────────────────
class MessageListScreen extends StatefulWidget {
  const MessageListScreen({super.key});

  @override
  State<MessageListScreen> createState() => _MessageListScreenState();
}

class _MessageListScreenState extends State<MessageListScreen> {
  final List<String> _archivedChats = [];
  final List<String> _blockedUsers = [];
  bool _showArchivedChats = false;

  @override
  void initState() {
    super.initState();
    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadChats();
    });
  }

  final List<ActivityUser> _activities = [
    const ActivityUser(
      name: 'You',
      imageUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200',
      isOnline: true,
      isYou: true,
    ),
    const ActivityUser(
      name: 'Emma',
      imageUrl: 'https://images.unsplash.com/photo-1529626455594-4ff0802cfb7e?w=200',
      isOnline: true,
    ),
  ];

  void _onChatOpened(ChatUser chat) async {
    // Check if user is blocked
    if (_blockedUsers.contains(chat.name)) {
      final bool isDark = Theme.of(context).brightness == Brightness.dark;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          title: const Text('Blocked user'),
          content: Text('${chat.name} is blocked. What do you want to do?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _unblockUser(chat);
              },
              child: const Text('Unblock'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _deleteChat(chat);
              },
              child: const Text('Delete chat', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      return;
    }

    final chatProvider = context.read<ChatProvider>();

    // Mark as read (WhatsApp-style: blue ticks when seen)
    await chatProvider.markChatAsSeen(chat.name);

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          username: chat.name,
          avatarUrl: chat.imageUrl,
          lastMessage: chat.lastMessage,
        ),
      ),
    );

    if (!mounted) return;
    // Reload chats when returning (for any new messages)
    chatProvider.loadChats();
  }

  void _showChatOptions(ChatUser chat) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Options
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Block'),
                onTap: () {
                  Navigator.pop(context);
                  _showBlockConfirmation(chat);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(chat);
                },
              ),
              ListTile(
                leading: const Icon(Icons.archive, color: kPrimaryBlue),
                title: const Text('Archive chat'),
                onTap: () {
                  Navigator.pop(context);
                  _archiveChat(chat);
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(ChatUser chat) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        title: const Text('Delete chat'),
        content: const Text('Do you want to delete this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChat(chat);
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showBlockConfirmation(ChatUser chat) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E2E) : Colors.white,
        title: const Text('Block user'),
        content: Text('Do you want to block ${chat.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _blockUser(chat);
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _deleteChat(ChatUser chat) {
    final chatProvider = context.read<ChatProvider>();
    // Remove chat from provider
    chatProvider.deleteChat(chat.name);
    setState(() {
      // Also remove from archived if it was archived
      _archivedChats.remove(chat.name);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat deleted')),
    );
  }

  void _blockUser(ChatUser chat) {
    setState(() {
      _blockedUsers.add(chat.name);
      // Also remove from archived if it was archived
      _archivedChats.remove(chat.name);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${chat.name} blocked')),
    );
  }

  void _unblockUser(ChatUser chat) {
    setState(() {
      _blockedUsers.remove(chat.name);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${chat.name} unblocked')),
    );
  }

  void _archiveChat(ChatUser chat) {
    setState(() {
      if (!_archivedChats.contains(chat.name)) {
        _archivedChats.add(chat.name);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chat archived')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            height: MediaQuery.of(context).padding.top,
          ),
          Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                'category',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(textColor)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                    child: Text(
                      'Activities',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _buildActivities(textColor)),
                // Archive box at top
                if (_archivedChats.isNotEmpty)
                  SliverToBoxAdapter(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showArchivedChats = !_showArchivedChats;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E2E) : const Color(0xFFF0F0F0),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _showArchivedChats ? Icons.expand_less : Icons.expand_more,
                              color: textColor,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Archive',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: kPrimaryBlue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_archivedChats.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: kPrimaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Archived chats list (expandable)
                if (_showArchivedChats && _archivedChats.isNotEmpty)
                  Consumer<ChatProvider>(
                    builder: (context, chatProvider, child) {
                      final archivedChatList = chatProvider.chats.where((chat) => _archivedChats.contains(chat.name)).toList();
                      return SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final chat = archivedChatList[index];
                            return _MessageTile(
                              chat: chat,
                              textColor: textColor,
                              secondaryTextColor: secondaryTextColor,
                              onTap: () => _onChatOpened(chat),
                              onLongPress: () => _showChatOptions(chat),
                            );
                          },
                          childCount: archivedChatList.length,
                        ),
                      );
                    },
                  ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                    child: Text(
                      'Messages',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
                // WhatsApp-style: Realtime chat list with Consumer
                Consumer<ChatProvider>(
                  builder: (context, chatProvider, child) {
                    // Filter out archived and blocked users
                    final visibleChats = chatProvider.chats.where((chat) =>
                      !_archivedChats.contains(chat.name) &&
                      !_blockedUsers.contains(chat.name)
                    ).toList();

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final chat = visibleChats[index];
                          return _MessageTile(
                            chat: chat,
                            textColor: textColor,
                            secondaryTextColor: secondaryTextColor,
                            onTap: () => _onChatOpened(chat),
                            onLongPress: () => _showChatOptions(chat),
                          );
                        },
                        childCount: visibleChats.length,
                      ),
                    );
                  },
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Messages',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              border: Border.all(color: textColor.withValues(alpha: 0.1), width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '1L',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.pink.shade400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivities(Color textColor) {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _activities.length,
        itemBuilder: (context, index) {
          final user = _activities[index];
          return _ActivityAvatar(user: user, textColor: textColor);
        },
      ),
    );
  }
}

class _ActivityAvatar extends StatelessWidget {
  final ActivityUser user;
  final Color textColor;
  const _ActivityAvatar({required this.user, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => UserProfileScreen(
              username: user.name,
              avatarUrl: user.imageUrl,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: user.isYou
                        ? null
                        : const LinearGradient(
                      colors: [Color(0xFFFF6B6B), kPrimaryBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: user.isYou
                        ? Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 2)
                        : null,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: ClipOval(
                    child: Image.network(
                      user.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                if (user.isOnline)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: kOnline,
                        shape: BoxShape.circle,
                        border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(user.name, style: TextStyle(fontSize: 12, color: textColor)),
          ],
        ),
      ),
    );
  }
}

class _MessageTile extends StatelessWidget {
  final ChatUser chat;
  final Color textColor;
  final Color secondaryTextColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _MessageTile({
    required this.chat,
    required this.textColor,
    required this.secondaryTextColor,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserProfileScreen(
                          username: chat.name,
                          avatarUrl: chat.imageUrl,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFF6B6B), kPrimaryBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: Image.network(
                        chat.imageUrl,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chat.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        chat.isTyping ? 'Typing...' : chat.formattedLastMessage,
                        style: TextStyle(
                          fontSize: 13,
                          color: chat.isTyping
                              ? kTeal
                              : (chat.unreadCount > 0 ? (isDark ? Colors.white : Colors.black) : secondaryTextColor),
                          fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      chat.time,
                      style: TextStyle(
                        fontSize: 12,
                        color: chat.unreadCount > 0 ? kPrimaryBlue : secondaryTextColor.withValues(alpha: 0.5),
                        fontWeight: chat.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (chat.unreadCount > 0)
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          color: kPrimaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${chat.unreadCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 22),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 86),
            child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
        ],
      ),
    );
  }
}
