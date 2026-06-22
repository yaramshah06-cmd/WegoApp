import 'package:flutter/material.dart';
import 'package:wego_marriage/screen/chat_screen.dart';

class PostDetailView extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String username;
  final String avatarUrl;

  const PostDetailView({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
    required this.username,
    required this.avatarUrl,
  });

  @override
  State<PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<PostDetailView> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToChat() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          username: widget.username,
          avatarUrl: widget.avatarUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF7A1730);

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? Colors.black : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              widget.username.toUpperCase(),
              style: TextStyle(
                color: isDark ? Colors.grey : Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Posts',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.imageUrls.length,
        itemBuilder: (context, index) {
          return _buildPostItem(widget.imageUrls[index], isDark, primaryColor);
        },
      ),
    );
  }

  Widget _buildPostItem(String imageUrl, bool isDark, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Post Header
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(widget.avatarUrl),
              ),
              const SizedBox(width: 10),
              Text(
                widget.username,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 12),
              // Message button
              GestureDetector(
                onTap: () => _navigateToChat(),
                child: Icon(
                  Icons.message_outlined,
                  color: primaryColor,
                  size: 22,
                ),
              ),
              const Spacer(),
              Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black),
            ],
          ),
        ),
        
        // Post Image
        AspectRatio(
          aspectRatio: 1,
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: isDark ? Colors.grey[900] : Colors.grey[200],
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
          ),
        ),
        
        // Post Actions
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(Icons.favorite_border, color: isDark ? Colors.white : Colors.black, size: 28),
              const SizedBox(width: 16),
              Icon(Icons.chat_bubble_outline, color: isDark ? Colors.white : Colors.black, size: 26),
              const SizedBox(width: 16),
              Icon(Icons.send_outlined, color: isDark ? Colors.white : Colors.black, size: 26),
              const Spacer(),
              Icon(Icons.bookmark_border, color: isDark ? Colors.white : Colors.black, size: 28),
            ],
          ),
        ),
        
        // Likes & Caption
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1,234 likes',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${widget.username} ',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: 'Beautiful day! #matchmaking #love',
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'View all 12 comments',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                '2 HOURS AGO',
                style: TextStyle(color: Colors.grey, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
