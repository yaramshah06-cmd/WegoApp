import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wego_marriage/screen/follow_list_screen.dart';
import 'package:wego_marriage/screen/profile_edit.dart';
import 'package:wego_marriage/screen/notification_screen.dart';
import 'package:wego_marriage/screen/policy_privacy.dart';
import 'package:wego_marriage/screen/setting_screeen.dart';
import 'package:wego_marriage/screen/help_center_screen.dart';
import 'package:wego_marriage/providers/user_provider.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _postsKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _changeProfilePicture() async {
    // Step 1: Pehle hamara custom permission dialog dikhao
    final bool allowed = await _showPermissionDialog();
    
    if (!allowed) {
      return; // User ne deny kiya
    }

    // Step 2: Ab actual system permission maango
    // Android 13+ ke liye photos permission, purane versions ke liye storage
    PermissionStatus status;
    if (Platform.isAndroid) {
      // Check if it's Android 13 or higher
      // Note: In a real app, you'd check SDK version. 
      // For now, we try photos first as it's the modern way.
      status = await Permission.photos.request();
      if (status.isDenied) {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    // Step 3: Check karo permission mili ya nahi
    if (!status.isGranted && !status.isLimited) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Permission denied. Please allow access from settings.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
      if (status.isPermanentlyDenied) {
        if (mounted) _showSettingsDialog();
      }
      return;
    }

    // Step 4: Permission granted - ab gallery open karo
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );

    if (image != null) {
      if (mounted) {
        context.read<UserProvider>().updateAvatar(image.path);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Profile picture updated!'),
            backgroundColor: const Color(0xFF3DDC84),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  Future<bool> _showPermissionDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF7A1730),
          title: const Text(
            '🔒 Gallery Permission',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Please allow access to your gallery to change profile picture.\n\n'
            'This is our security filter.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false); // Deny
              },
              child: const Text(
                'Deny',
                style: TextStyle(color: Colors.red),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true); // Allow
              },
              child: const Text(
                'Allow',
                style: TextStyle(
                  color: Color(0xFF3DDC84),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    ) ?? false;
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF7A1730),
        title: const Text(
          'Open Settings',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Please enable photo access in app settings.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('Open', style: TextStyle(color: Color(0xFF3DDC84))),
          ),
        ],
      ),
    );
  }

  void _showMenu(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              body: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.75,
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                      border: Theme.of(context).brightness == Brightness.dark 
                          ? const Border(left: BorderSide(color: Colors.white10)) 
                          : null,
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          const SizedBox(height: 24),
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton(
                              icon: Icon(Icons.close, 
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87, 
                                size: 28),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          Text(
                            'Menu',
                            style: TextStyle(
                              color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.person_outline,
                            title: 'Edit Profile',
                            color: Colors.blue,
                            onTap: () {
                              Navigator.pop(context);
                              _showEditProfile(context);
                            },
                          ),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.notifications_outlined,
                            title: 'Notifications',
                            color: Colors.orange,
                            onTap: () {
                              Navigator.pop(context);
                              _showNotifications(context);
                            },
                          ),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy',
                            color: Colors.green,
                            onTap: () {
                              Navigator.pop(context);
                              _showPrivacy(context);
                            },
                          ),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.settings_outlined,
                            title: 'Settings',
                            color: Colors.purple,
                            onTap: () {
                              Navigator.pop(context);
                              _showSettings(context);
                            },
                          ),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.help_outline,
                            title: 'Help & Support',
                            color: Colors.teal,
                            onTap: () {
                              Navigator.pop(context);
                              _showHelpSupport(context);
                            },
                          ),
                          const Spacer(),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.logout,
                            title: 'Logout',
                            color: Colors.red,
                            onTap: () {
                              Navigator.pop(context);
                              _showLogoutDialog(context);
                            },
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1, 0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            )),
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: isDark ? Colors.white54 : Colors.black26,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileEditScreen(),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationSettingScreen(),
      ),
    );
  }

  void _showPrivacy(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrivacyPolicyScreen(),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  void _showHelpSupport(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HelpCenterScreen(),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF7A1730),
        title: const Text(
          'Logout',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to logout?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Add logout logic here
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF7A1730);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'My Profile',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.menu, color: textColor, size: 28),
            onPressed: () => _showMenu(context),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        children: [
            const SizedBox(height: 20),
            // Profile Avatar (Circle - NO tap on whole circle)
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: user.avatarUrl.startsWith('http')
                          ? Image.network(
                              user.avatarUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                              errorBuilder: (_, _, _) => Container(
                                color: Colors.grey[300],
                                child: Icon(Icons.person,
                                    color: primaryColor, size: 60),
                              ),
                            )
                          : Image.file(
                              File(user.avatarUrl),
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: Colors.grey[300],
                                child: Icon(Icons.person,
                                    color: primaryColor, size: 60),
                              ),
                            ),
                    ),
                  ),
                  // Camera icon overlay (ONLY this button is tappable)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _changeProfilePicture,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child:
                            const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Username
            Center(
              child: Text(
                user.name,
                style: TextStyle(
                  color: textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                user.username,
                style: TextStyle(
                  color: subTextColor,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 30),
            // Stats
            _buildStatsSection(context),
            const SizedBox(height: 30),
            // Posts Section
            Container(
              key: _postsKey,
              child: _buildPostsSection(),
            ),
            const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          GestureDetector(
            onTap: () {
              // Scroll to posts section
              _scrollToPosts(context);
            },
            child: _buildStatItem(context, 'Posts', '128'),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FollowListScreen(
                    title: 'Followers',
                    users: _getFollowersData(),
                    isFollowing: false,
                  ),
                ),
              );
            },
            child: _buildStatItem(context, 'Followers', '12.5k'),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FollowListScreen(
                    title: 'Following',
                    users: _getFollowingData(),
                    isFollowing: true,
                  ),
                ),
              );
            },
            child: _buildStatItem(context, 'Following', '892'),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFollowersData() {
    return [
      {
        'name': 'Sarah Johnson',
        'username': '@sarah_j',
        'avatar': 'https://randomuser.me/api/portraits/women/44.jpg',
        'isFollowing': false,
      },
      {
        'name': 'John Smith',
        'username': '@john_s',
        'avatar': 'https://randomuser.me/api/portraits/men/32.jpg',
        'isFollowing': true,
      },
      {
        'name': 'Emma Watson',
        'username': '@emma_w',
        'avatar': 'https://randomuser.me/api/portraits/women/68.jpg',
        'isFollowing': false,
      },
      {
        'name': 'Mike Brown',
        'username': '@mike_b',
        'avatar': 'https://randomuser.me/api/portraits/men/45.jpg',
        'isFollowing': true,
      },
      {
        'name': 'Lisa Davis',
        'username': '@lisa_d',
        'avatar': 'https://randomuser.me/api/portraits/women/55.jpg',
        'isFollowing': false,
      },
      {
        'name': 'David Wilson',
        'username': '@david_w',
        'avatar': 'https://randomuser.me/api/portraits/men/22.jpg',
        'isFollowing': true,
      },
      {
        'name': 'Anna Lee',
        'username': '@anna_l',
        'avatar': 'https://randomuser.me/api/portraits/women/33.jpg',
        'isFollowing': false,
      },
    ];
  }

  List<Map<String, dynamic>> _getFollowingData() {
    return [
      {
        'name': 'Alex Turner',
        'username': '@alex_t',
        'avatar': 'https://randomuser.me/api/portraits/men/11.jpg',
        'isFollowing': true,
      },
      {
        'name': 'Maria Garcia',
        'username': '@maria_g',
        'avatar': 'https://randomuser.me/api/portraits/women/23.jpg',
        'isFollowing': true,
      },
      {
        'name': 'James Chen',
        'username': '@james_c',
        'avatar': 'https://randomuser.me/api/portraits/men/33.jpg',
        'isFollowing': true,
      },
      {
        'name': 'Sophia Kim',
        'username': '@sophia_k',
        'avatar': 'https://randomuser.me/api/portraits/women/12.jpg',
        'isFollowing': true,
      },
      {
        'name': 'Daniel Park',
        'username': '@daniel_p',
        'avatar': 'https://randomuser.me/api/portraits/men/44.jpg',
        'isFollowing': true,
      },
    ];
  }

  void _scrollToPosts(BuildContext context) {
    // Scroll to posts section smoothly
    Scrollable.ensureVisible(
      _postsKey.currentContext!,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildPostsSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Posts',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 128,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _showPostDetail(
                  context,
                  'https://picsum.photos/seed/post${index + 1}/400/400',
                  index + 1,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      'https://picsum.photos/seed/post${index + 1}/400/400',
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, _, _) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showPostDetail(BuildContext context, String imageUrl, int postNumber) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF7A1730);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: isDark ? Border.all(color: Colors.white12) : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Post image
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 300,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.grey[300],
                    height: 300,
                    child: const Center(
                      child: Icon(Icons.image, color: Colors.grey, size: 64),
                    ),
                  ),
                ),
              ),
              // Post info
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Post #$postNumber',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Beautiful moment captured! 📸',
                      style: TextStyle(color: subTextColor, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    // Like and comment buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.favorite_border, color: textColor, size: 20),
                            const SizedBox(width: 4),
                            Text('245', style: TextStyle(color: textColor)),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.chat_bubble_outline, color: textColor, size: 20),
                            const SizedBox(width: 4),
                            Text('18', style: TextStyle(color: textColor)),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.bookmark_border, color: textColor),
                          onPressed: () {},
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: subTextColor,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
