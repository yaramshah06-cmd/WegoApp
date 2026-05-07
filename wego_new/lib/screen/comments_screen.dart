import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:wego_marriage/services/local_storage_service.dart';
import 'package:wego_marriage/providers/settings_provider.dart';
import 'package:wego_marriage/screen/user_profile_screen.dart';
import 'package:wego_marriage/screen/chat_screen.dart';
import 'app_localizations.dart';
import 'app_translations.dart';

class CommentsScreen extends StatefulWidget {
  final String postId;
  final String postUsername;
  final String currentUserAvatar;
  final String currentUsername;

  const CommentsScreen({
    super.key,
    required this.postId,
    required this.postUsername,
    required this.currentUserAvatar,
    required this.currentUsername,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final LocalStorageService _storage = LocalStorageService();
  final ScrollController _scrollController = ScrollController();
  List<Comment> _comments = [];

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadComments() {
    setState(() {
      _comments = _storage.getComments(widget.postId);
      if (_comments.isEmpty) {
        _comments = _getDummyComments();
        for (var comment in _comments) {
          _storage.addComment(widget.postId, comment);
        }
      }
    });
  }

  List<Comment> _getDummyComments() {
    return [
      Comment(
        id: 'comment_1',
        username: 'sarah_smith',
        avatarUrl: 'https://i.pravatar.cc/150?img=1',
        text: 'This is absolutely amazing! 😍 Love the vibes',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        likes: 24,
        dislikes: 0,
      ),
      Comment(
        id: 'comment_2',
        username: 'mike_brown',
        avatarUrl: 'https://i.pravatar.cc/150?img=3',
        text: 'Beautiful shot! Where was this taken?',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        likes: 12,
        dislikes: 0,
        replies: [
          Comment(
            id: 'reply_1',
            username: widget.postUsername,
            avatarUrl: widget.currentUserAvatar,
            text: 'Thank you! This was taken in Bali 🌴',
            timestamp: DateTime.now().subtract(const Duration(minutes: 45)),
            likes: 8,
            dislikes: 0,
          ),
        ],
      ),
      Comment(
        id: 'comment_3',
        username: 'emma_wilson',
        avatarUrl: 'https://i.pravatar.cc/150?img=5',
        text: 'Wow, stunning! ✨',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        likes: 6,
        dislikes: 0,
      ),
    ];
  }

  void _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final newComment = Comment(
      id: 'comment_${DateTime.now().millisecondsSinceEpoch}',
      username: widget.currentUsername,
      avatarUrl: widget.currentUserAvatar,
      text: text,
      timestamp: DateTime.now(),
      likes: 0,
      dislikes: 0,
    );

    await _storage.addComment(widget.postId, newComment);

    setState(() {
      _comments.insert(0, newComment);
      _commentController.clear();
    });

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _toggleLikeComment(Comment comment) async {
    final isLiked = _storage.isCommentLiked(comment.id);
    final isDisliked = _storage.isCommentDisliked(comment.id);

    await _storage.toggleCommentLike(comment.id, !isLiked);

    setState(() {
      if (!isLiked) {
        comment.likes++;
        if (isDisliked) comment.dislikes--;
      } else {
        comment.likes--;
      }
    });

    await _storage.addComment(widget.postId, comment);
  }

  void _toggleDislikeComment(Comment comment) async {
    final isLiked = _storage.isCommentLiked(comment.id);
    final isDisliked = _storage.isCommentDisliked(comment.id);

    await _storage.toggleCommentDislike(comment.id, !isDisliked);

    setState(() {
      if (!isDisliked) {
        comment.dislikes++;
        if (isLiked) comment.likes--;
      } else {
        comment.dislikes--;
      }
    });

    await _storage.addComment(widget.postId, comment);
  }

  void _navigateToProfile(String username, String avatarUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: '',
          username: username,
          avatarUrl: avatarUrl,
        ),
      ),
    );
  }

  void _navigateToChat(String username, String avatarUrl) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          username: username,
          avatarUrl: avatarUrl,
        ),
      ),
    );
  }

  void _showReplyDialog(Comment parentComment) {
    final replyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${context.tr('replying_to')} ${parentComment.username}', // ✅
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: replyController,
                  decoration: InputDecoration(
                    hintText: context.tr('write_reply'), // ✅
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  maxLines: 3,
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final text = replyController.text.trim();
                      if (text.isNotEmpty) {
                        final reply = Comment(
                          id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
                          username: widget.currentUsername,
                          avatarUrl: widget.currentUserAvatar,
                          text: text,
                          timestamp: DateTime.now(),
                          likes: 0,
                          dislikes: 0,
                        );

                        parentComment.replies.add(reply);
                        await _storage.addComment(widget.postId, parentComment);

                        if (!context.mounted) return;
                        Navigator.pop(context);
                        setState(() {});
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0095F6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(context.tr('reply')), // ✅
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ✅ AppTranslations.translate() use karo — koi hardcoded map nahi
  void _translateComment(Comment comment) {
    final settings = context.read<SettingsProvider>();
    final targetLanguage = settings.preferredLanguage;

    if (comment.isTranslated) {
      setState(() {
        comment.isTranslated = false;
        comment.translatedText = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('showing_original'))), // ✅
      );
    } else {
      final langCode = _getLanguageCode(targetLanguage);
      // ✅ AppTranslations.translate() — same system jo poori app use karti hai
      final translated = AppTranslations.translate(comment.text, langCode);

      setState(() {
        comment.isTranslated = true;
        comment.translatedText = translated;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('translated_to')} $targetLanguage'), // ✅
        ),
      );
    }
  }

  String _getLanguageCode(String languageName) {
    const Map<String, String> codes = {
      'English': 'en',
      'Urdu': 'ur',
      'Hindi': 'hi',
      'Arabic': 'ar',
      'Korean': 'ko',
      'Chinese': 'zh',
      'Japanese': 'ja',
      'French': 'fr',
      'Spanish': 'es',
      'Turkish': 'tr',
      'German': 'de',
    };
    return codes[languageName] ?? 'en';
  }

  void _deleteComment(Comment comment) async {
    await _storage.deleteComment(widget.postId, comment.id);
    if (!mounted) return;

    setState(() {
      _comments.removeWhere((c) => c.id == comment.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('comment_deleted'))), // ✅
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF121212) : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.tr('comments'), // ✅
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _comments.isEmpty
                ? _buildEmptyState(isDark)
                : ListView.builder(
              controller: _scrollController,
              itemCount: _comments.length,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, index) {
                return _buildCommentItem(_comments[index], isDark);
              },
            ),
          ),
          _buildCommentInput(isDark),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('no_comments_yet'), // ✅
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr('be_first_comment'), // ✅
            style: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(Comment comment, bool isDark) {
    final isLiked = _storage.isCommentLiked(comment.id);
    final isDisliked = _storage.isCommentDisliked(comment.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () =>
                    _navigateToProfile(comment.username, comment.avatarUrl),
                child: CircleAvatar(
                  radius: 18,
                  backgroundImage: NetworkImage(comment.avatarUrl),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        children: [
                          WidgetSpan(
                            child: GestureDetector(
                              onTap: () => _navigateToProfile(
                                  comment.username, comment.avatarUrl),
                              child: Text(
                                comment.username,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                  isDark ? Colors.white : Colors.black,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          TextSpan(
                            text: ' ',
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          TextSpan(
                            text: comment.isTranslated &&
                                comment.translatedText != null
                                ? comment.translatedText
                                : comment.text,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          timeago.format(comment.timestamp),
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => _navigateToChat(
                              comment.username, comment.avatarUrl),
                          child: Icon(
                            Icons.message_outlined,
                            size: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          icon: isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          count: comment.likes,
                          onTap: () => _toggleLikeComment(comment),
                          isActive: isLiked,
                          activeColor: Colors.red,
                        ),
                        const SizedBox(width: 12),
                        _buildActionButton(
                          icon: isDisliked
                              ? Icons.thumb_down
                              : Icons.thumb_down_alt_outlined,
                          count: comment.dislikes,
                          onTap: () => _toggleDislikeComment(comment),
                          isActive: isDisliked,
                          activeColor: Colors.blue,
                        ),
                        const SizedBox(width: 16),
                        GestureDetector(
                          onTap: () => _showReplyDialog(comment),
                          child: Text(
                            context.tr('reply'), // ✅
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (comment.text.length > 10)
                          GestureDetector(
                            onTap: () => _translateComment(comment),
                            child: Text(
                              comment.isTranslated
                                  ? context.tr('see_original')  // ✅
                                  : context.tr('translate'),    // ✅
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        if (comment.username == widget.currentUsername)
                          PopupMenuButton<String>(
                            icon: Icon(Icons.more_horiz,
                                size: 16, color: Colors.grey[600]),
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(context.tr('delete')), // ✅
                              ),
                            ],
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteComment(comment);
                              }
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (comment.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Column(
              children: comment.replies
                  .map((reply) => _buildReplyItem(reply, isDark))
                  .toList(),
            ),
          ),

        const Divider(height: 1),
      ],
    );
  }

  Widget _buildReplyItem(Comment reply, bool isDark) {
    final isLiked = _storage.isCommentLiked(reply.id);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () =>
                _navigateToProfile(reply.username, reply.avatarUrl),
            child: CircleAvatar(
              radius: 14,
              backgroundImage: NetworkImage(reply.avatarUrl),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: () => _navigateToProfile(
                              reply.username, reply.avatarUrl),
                          child: Text(
                            reply.username,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                      TextSpan(
                        text: ' ${reply.text}',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      timeago.format(reply.timestamp),
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      icon: isLiked ? Icons.favorite : Icons.favorite_border,
                      count: reply.likes,
                      onTap: () => _toggleLikeComment(reply),
                      isActive: isLiked,
                      activeColor: Colors.red,
                      isSmall: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required int count,
    required VoidCallback onTap,
    bool isActive = false,
    Color? activeColor,
    bool isSmall = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: isSmall ? 14 : 16,
            color: isActive ? activeColor : Colors.grey[600],
          ),
          if (count > 0) ...[
            const SizedBox(width: 4),
            Text(
              count.toString(),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isSmall ? 11 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentInput(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(widget.currentUserAvatar),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: context.tr('add_comment'), // ✅
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                  ),
                  border: InputBorder.none,
                  contentPadding:
                  const EdgeInsets.symmetric(vertical: 8),
                ),
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _postComment(),
              ),
            ),
            GestureDetector(
              onTap: _postComment,
              child: Text(
                context.tr('post_comment'), // ✅
                style: TextStyle(
                  color: _commentController.text.isNotEmpty
                      ? const Color(0xFF0095F6)
                      : Colors.grey[400],
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}