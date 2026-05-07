import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wego_marriage/screen/welcome_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wego_marriage/screen/follow_list_screen.dart';
import 'package:wego_marriage/screen/profile_edit.dart';
import 'package:wego_marriage/screen/notification_screen.dart';
import 'package:wego_marriage/screen/policy_privacy.dart';
import 'package:wego_marriage/screen/setting_screeen.dart';
import 'package:wego_marriage/screen/help_center_screen.dart';
import 'package:wego_marriage/providers/user_provider.dart';
import 'package:wego_marriage/services/post_service.dart';
import 'package:wego_marriage/services/local_storage_service.dart'; // ✅ UserPost class yahan hai
import 'package:wego_marriage/screen/create_content_screen.dart';
import 'package:wego_marriage/screen/connection_secreen.dart';
import 'app_localizations.dart';
class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _postsKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  final PostService _postService = PostService();

  List<UserPost> _userPosts = [];
  bool _isLoadingPosts = true;

  // ── Firebase real stats ──
  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoadingStats = true;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadUserPosts();
    _loadStats(); // ✅ Firebase se real counts
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Firebase se followers/following counts fetch karo ──────
  Future<void> _loadStats() async {
    final uid = _currentUid;
    if (uid == null) return;

    try {
      final followersSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('followers')
          .get();

      final followingSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('following')
          .get();

      if (mounted) {
        setState(() {
          _followersCount = followersSnap.docs.length;
          _followingCount = followingSnap.docs.length;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      debugPrint('Stats load error: $e');
      if (mounted) setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadUserPosts() async {
    setState(() => _isLoadingPosts = true);
    try {
      final posts = _postService.getUserPosts();
      setState(() {
        _userPosts = posts;
        _isLoadingPosts = false;
      });
    } catch (e) {
      debugPrint('Error loading user posts: $e');
      setState(() => _isLoadingPosts = false);
    }
  }

  Future<void> _changeProfilePicture() async {
    final bool allowed = await _showPermissionDialog();
    if (!allowed) return;

    PermissionStatus status;
    if (Platform.isAndroid) {
      status = await Permission.photos.request();
      if (status.isDenied) {
        status = await Permission.storage.request();
      }
    } else {
      status = await Permission.photos.request();
    }

    if (!status.isGranted && !status.isLimited) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                context.tr('permission_denied')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      if (status.isPermanentlyDenied && mounted) _showSettingsDialog();
      return;
    }

    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );

    if (image != null && mounted) {
      context.read<UserProvider>().updateAvatar(image.path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('profile_picture_updated')),
          backgroundColor: const Color(0xFF3DDC84),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<bool> _showPermissionDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF5B2BE8),
          title: Text(context.tr('gallery_permission'),
              style: const TextStyle(color: Colors.white)),
          content: Text(
            context.tr('gallery_permission_message'),
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('deny'),
                  style: const TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('allow'),
                  style: const TextStyle(
                      color: Color(0xFF3DDC84),
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ) ??
        false;
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF5B2BE8),
        title: Text(context.tr('open_settings'),
            style: const TextStyle(color: Colors.white)),
        content: Text(context.tr('enable_photo_access'),
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('cancel'),
                style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: Text(context.tr('open'),
                style: const TextStyle(color: Color(0xFF3DDC84))),
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
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(24)),
                      border: Theme.of(context).brightness == Brightness.dark
                          ? const Border(
                          left: BorderSide(color: Colors.white10))
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
                                  color: Theme.of(context).brightness ==
                                      Brightness.dark
                                      ? Colors.white
                                      : Colors.black87,
                                  size: 28),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                          Text(
                            context.tr('menu'),
                            style: TextStyle(
                              color: Theme.of(context).brightness ==
                                  Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.person_outline,
                            title: context.tr('edit_profile'),
                            color: Colors.blue,
                            onTap: () {
                              Navigator.pop(context);
                              _showEditProfile(context);
                            },
                          ),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.notifications_outlined,
                            title: context.tr('notifications'),
                            color: Colors.orange,
                            onTap: () {
                              Navigator.pop(context);
                              _showNotifications(context);
                            },
                          ),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.privacy_tip_outlined,
                            title: context.tr('privacy'),
                            color: Colors.green,
                            onTap: () {
                              Navigator.pop(context);
                              _showPrivacy(context);
                            },
                          ),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.settings_outlined,
                            title: context.tr('settings_menu'),
                            color: Colors.purple,
                            onTap: () {
                              Navigator.pop(context);
                              _showSettings(context);
                            },
                          ),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.favorite_border,
                            title: context.tr('favorites'),
                            color: Colors.red,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => MatchesScreen()),
                              );
                            },
                          ),
                          _buildMenuItem(
                            context: context,
                            icon: Icons.help_outline,
                            title: context.tr('help_support'),
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
                            title: context.tr('logout_menu'),
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
            ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
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
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w500)),
            ),
            Icon(Icons.arrow_forward_ios,
                color: isDark ? Colors.white54 : Colors.black26, size: 16),
          ],
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const ProfileEditScreen()));

  void _showNotifications(BuildContext context) => Navigator.push(context,
      MaterialPageRoute(builder: (_) => const NotificationSettingScreen()));

  void _showPrivacy(BuildContext context) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));

  void _showSettings(BuildContext context) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const SettingsScreen()));

  void _showHelpSupport(BuildContext context) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const HelpCenterScreen()));

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF5B2BE8),
        title: Text(context.tr('logout_menu'), style: const TextStyle(color: Colors.white)),
        content: Text(context.tr('logout_msg'),
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.tr('cancel'),
                style: const TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();

              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .update({
                  'online': false,
                  'lastSeen': FieldValue.serverTimestamp(),
                });
              }

              await FirebaseAuth.instance.signOut();

              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (route) => false,
                );
              }
            },
            child: Text(context.tr('logout_menu'), style: const TextStyle(color: Colors.red)),
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
    final primaryColor = const Color(0xFF4A6CF7);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(context.tr('my_profile'),
            style: TextStyle(
                color: textColor,
                fontSize: 20,
                fontWeight: FontWeight.bold)),
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

          // ── Profile Avatar ───────────────────────────────────
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
                        ? Image.network(user.avatarUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                              color: Colors.grey[300],
                              child: const Center(
                                  child: CircularProgressIndicator()));
                        },
                        errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: Icon(Icons.person,
                                color: primaryColor, size: 60)))
                        : Image.file(File(user.avatarUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: Icon(Icons.person,
                                color: primaryColor, size: 60))),
                  ),
                ),
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
                      child: const Icon(Icons.camera_alt,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Name ────────────────────────────────────────────
          Center(
            child: Text(user.name,
                style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(user.username,
                style: TextStyle(color: subTextColor, fontSize: 14)),
          ),
          const SizedBox(height: 30),

          // ── Stats ────────────────────────────────────────────
          _buildStatsSection(context),
          const SizedBox(height: 30),

          // ── Posts ────────────────────────────────────────────
          Container(key: _postsKey, child: _buildPostsSection()),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = _currentUid ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Posts count
          GestureDetector(
            onTap: () => Scrollable.ensureVisible(_postsKey.currentContext!,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut),
            child: _buildStatItem(context, context.tr('posts'), '${_userPosts.length}'),
          ),

          // ✅ Followers — Firebase se real count, targetUserId pass
          GestureDetector(
            onTap: () {
              if (uid.isEmpty) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FollowListScreen(
                    title: context.tr('followers'),
                    targetUserId: uid, // ✅ correct parameter
                  ),
                ),
              );
            },
            child: _buildStatItem(
              context,
              context.tr('followers'),
              _isLoadingStats ? '...' : '$_followersCount',
            ),
          ),

          // ✅ Following — Firebase se real count, targetUserId pass
          GestureDetector(
            onTap: () {
              if (uid.isEmpty) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FollowListScreen(
                    title: context.tr('following'),
                    targetUserId: uid, // ✅ correct parameter
                  ),
                ),
              );
            },
            child: _buildStatItem(
              context,
              context.tr('following'),
              _isLoadingStats ? '...' : '$_followingCount',
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToPosts(BuildContext context) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.tr('my_posts'),
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              if (_userPosts.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _showPostsOptions(context),
                  icon: Icon(Icons.more_vert, color: textColor, size: 16),
                  label: Text(context.tr('options'),
                      style: TextStyle(color: textColor, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingPosts)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator()))
          else if (_userPosts.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 64,
                      color: textColor.withValues(alpha: 0.5)),
                  const SizedBox(height: 16),
                  Text(context.tr('no_posts_yet'),
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.7),
                          fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(context.tr('create_first_post'),
                      style: TextStyle(
                          color: textColor.withValues(alpha: 0.5),
                          fontSize: 14)),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _userPosts.length,
              itemBuilder: (context, index) {
                final post = _userPosts[index];
                return GestureDetector(
                  onTap: () => _showUserPostDetail(context, post),
                  onLongPress: () => _showPostOptions(context, post),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2))
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          _buildPostMedia(post),
                          if (post.isVideo)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.play_arrow,
                                    color: Colors.white, size: 16),
                              ),
                            ),
                        ],
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

  Widget _buildPostMedia(UserPost post) {
    if (post.thumbnailBytes != null) {
      return Image.memory(post.thumbnailBytes!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) =>
              Container(color: Colors.grey[300], child: const Icon(Icons.image, color: Colors.grey)));
    }
    if (post.mediaPath.startsWith('http')) {
      return Image.network(post.mediaPath,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));
          },
          errorBuilder: (_, __, ___) =>
              Container(color: Colors.grey[300], child: const Icon(Icons.image, color: Colors.grey)));
    }
    final file = File(post.mediaPath);
    if (file.existsSync()) {
      return Image.file(file,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) =>
              Container(color: Colors.grey[300], child: const Icon(Icons.image, color: Colors.grey)));
    }
    return Container(
        color: Colors.grey[300],
        child: Icon(post.isVideo ? Icons.videocam : Icons.image, color: Colors.grey));
  }

  void _showUserPostDetail(BuildContext context, UserPost post) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
              ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(height: 300, child: _buildPostMedia(post)),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: post.contentType == ContentMode.post
                                ? Colors.blue
                                : post.contentType == ContentMode.story
                                ? Colors.orange
                                : Colors.purple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            post.contentType.name.toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_formatDate(post.timestamp),
                            style:
                            TextStyle(color: subTextColor, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (post.caption.isNotEmpty)
                      Text(post.caption,
                          style: TextStyle(color: textColor, fontSize: 14)),
                    if (post.hashtags.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          children: post.hashtags
                              .map((tag) => Chip(
                            label: Text(tag,
                                style: const TextStyle(fontSize: 11)),
                            backgroundColor:
                            Colors.blue.withValues(alpha: 0.1),
                            materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                          ))
                              .toList(),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat(Icons.favorite_border, '${post.likes}'),
                        _buildStat(
                            Icons.chat_bubble_outline, '${post.comments}'),
                        _buildStat(Icons.visibility, post.visibility.name),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          label: Text(context.tr('close')),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            _showPostOptions(context, post);
                          },
                          icon: const Icon(Icons.more_vert),
                          label: Text(context.tr('options')),
                        ),
                      ],
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

  void _showPostOptions(BuildContext context, UserPost post) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                  color: isDark ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            _buildOptionTile(Icons.edit, context.tr('edit_post'), () {
              Navigator.pop(context);
            }),
            _buildOptionTile(Icons.share, context.tr('share'), () {
              Navigator.pop(context);
            }),
            _buildOptionTile(Icons.copy, context.tr('copy_link'), () {
              Navigator.pop(context);
            }),
            _buildOptionTile(Icons.delete, context.tr('delete_post'), () async {
              Navigator.pop(context);
              final confirmed = await _showDeleteConfirmation(context);
              if (confirmed) {
                final success = await _postService.deletePost(post.id);
                if (success) {
                  _loadUserPosts();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(context.tr('post_deleted_success')),
                        backgroundColor: Colors.green));
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(context.tr('delete_post_failed')),
                        backgroundColor: Colors.red));
                  }
                }
              }
            }, iconColor: Colors.red),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPostsOptions(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                  color: isDark ? Colors.grey[600] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            _buildOptionTile(Icons.backup, context.tr('backup_posts'), () async {
              Navigator.pop(context);
              final path = await _postService.exportPostsToBackup();
              if (path != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Posts backed up to: $path'),
                    backgroundColor: Colors.green));
              }
            }),
            _buildOptionTile(Icons.restore, context.tr('restore_backup'), () async {
              Navigator.pop(context);
              final success = await _postService.importPostsFromBackup();
              if (success) {
                _loadUserPosts();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(context.tr('posts_restored_success')),
                      backgroundColor: Colors.green));
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(context.tr('backup_not_found')),
                      backgroundColor: Colors.orange));
                }
              }
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile(IconData icon, String label, VoidCallback onTap,
      {Color? iconColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon,
          color: iconColor ?? (isDark ? Colors.white : Colors.black87)),
      title: Text(label,
          style:
          TextStyle(color: isDark ? Colors.white : Colors.black87)),
      onTap: onTap,
    );
  }

  Widget _buildStat(IconData icon, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Row(
      children: [
        Icon(icon, color: textColor, size: 20),
        const SizedBox(width: 4),
        Text(value, style: TextStyle(color: textColor)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays > 0) return '${difference.inDays}d ago';
    if (difference.inHours > 0) return '${difference.inHours}h ago';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m ago';
    return 'Just now';
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('delete_post')),
        content: Text(
            context.tr('delete_post_confirm')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('cancel')),
          ),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(context.tr('delete'))
            ),
        ],
      ),
    ) ??
        false;
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: textColor,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(color: subTextColor, fontSize: 13)),
      ],
    );
  }
}