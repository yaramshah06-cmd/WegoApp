import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wego_marriage/providers/story_provider.dart';
import 'package:wego_marriage/screen/user_profile_screen.dart';
import 'app_localizations.dart';
import 'app_translations.dart';

class StoryScreen extends StatefulWidget {
  final int initialUserIndex;

  const StoryScreen({super.key, required this.initialUserIndex});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  int _currentUserIndex = 0;
  int _currentStoryIndex = 0;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _currentUserIndex = widget.initialUserIndex;
    _pageController = PageController(initialPage: 0);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goToNextStory();
      }
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _goToNextStory() {
    final storyProvider = context.read<StoryProvider>();
    final allUserStories = storyProvider.userStories;
    if (allUserStories.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    final currentUserStories = allUserStories[_currentUserIndex].stories;

    if (_currentStoryIndex < currentUserStories.length - 1) {
      setState(() => _currentStoryIndex++);
      _animationController.reset();
      _animationController.forward();
    } else {
      storyProvider.markAsWatched(allUserStories[_currentUserIndex].userId);

      if (_currentUserIndex < allUserStories.length - 1) {
        setState(() {
          _currentUserIndex++;
          _currentStoryIndex = 0;
        });
        _animationController.reset();
        _animationController.forward();
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  void _goToPreviousStory() {
    final allUserStories = context.read<StoryProvider>().userStories;
    if (allUserStories.isEmpty) return;

    if (_currentStoryIndex > 0) {
      setState(() => _currentStoryIndex--);
      _animationController.reset();
      _animationController.forward();
    } else if (_currentUserIndex > 0) {
      setState(() {
        _currentUserIndex--;
        _currentStoryIndex =
            allUserStories[_currentUserIndex].stories.length - 1;
      });
      _animationController.reset();
      _animationController.forward();
    } else {
      _animationController.reset();
      _animationController.forward();
    }
  }

  void _navigateToProfile(String userId, String username, String avatarUrl) {
    _animationController.stop();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: userId,
          username: username,
          avatarUrl: avatarUrl,
        ),
      ),
    ).then((_) {
      if (mounted) _animationController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final storyProvider = context.watch<StoryProvider>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark ? Colors.white : Colors.black87;

    if (storyProvider.isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: textColor)),
      );
    }

    final allUserStories = storyProvider.userStories;

    // ✅ Translated — pehle 'Koi story nahi' / 'Wapas jao' tha
    if (allUserStories.isEmpty) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.photo_library_outlined, color: textColor, size: 64),
              const SizedBox(height: 16),
              Text(
                context.tr('no_stories'), // ✅
                style: TextStyle(color: textColor, fontSize: 18),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  context.tr('go_back'), // ✅
                  style: TextStyle(color: textColor),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Index safety check
    if (_currentUserIndex >= allUserStories.length) {
      _currentUserIndex = allUserStories.length - 1;
    }
    if (_currentStoryIndex >=
        allUserStories[_currentUserIndex].stories.length) {
      _currentStoryIndex =
          allUserStories[_currentUserIndex].stories.length - 1;
    }

    final userStory = allUserStories[_currentUserIndex];
    final currentStory = userStory.stories[_currentStoryIndex];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Story image
          Center(
            child: GestureDetector(
              onLongPress: () {
                setState(() => _isPaused = true);
                _animationController.stop();
              },
              onLongPressUp: () {
                setState(() => _isPaused = false);
                _animationController.forward();
              },
              child: Image.network(
                currentStory.imageUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    if (!_isPaused && !_animationController.isAnimating) {
                      _animationController.forward();
                    }
                    return child;
                  }
                  _animationController.stop();
                  return Center(
                      child: CircularProgressIndicator(color: textColor));
                },
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(Icons.broken_image, color: textColor, size: 64),
                ),
              ),
            ),
          ),

          // Tap areas
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _goToPreviousStory,
                    child: Container(color: Colors.transparent),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _goToNextStory,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ],
            ),
          ),

          // Top overlay
          SafeArea(
            child: Column(
              children: [
                // Progress bars
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8),
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Row(
                        children: List.generate(
                          userStory.stories.length,
                              (index) => _buildProgressBar(index, isDark),
                        ),
                      );
                    },
                  ),
                ),

                // User info bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _navigateToProfile(
                          userStory.userId,
                          userStory.username,
                          userStory.avatarUrl,
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: NetworkImage(userStory.avatarUrl),
                          backgroundColor: Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _navigateToProfile(
                          userStory.userId,
                          userStory.username,
                          userStory.avatarUrl,
                        ),
                        child: Text(
                          userStory.username,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            shadows: isDark
                                ? [
                              const Shadow(
                                  color: Colors.black54, blurRadius: 4)
                            ]
                                : null,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.close, color: textColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(int index, bool isDark) {
    double progress = 0.0;
    if (index < _currentStoryIndex) {
      progress = 1.0;
    } else if (index == _currentStoryIndex) {
      progress = _animationController.value;
    }

    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isDark ? Colors.white30 : Colors.black26,
          borderRadius: BorderRadius.circular(2),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black87,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}