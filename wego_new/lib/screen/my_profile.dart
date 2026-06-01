import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
// achievement_badge.dart mein BadgeData duplicate hai — hide karo
import 'package:wego_marriage/widgets/achievement_badge.dart' hide BadgeData;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wego_marriage/screen/follow_list_screen.dart';
import 'package:wego_marriage/screen/setting_screeen.dart';
import 'package:wego_marriage/providers/user_provider.dart';
import 'package:wego_marriage/services/post_service.dart';
import 'package:wego_marriage/services/local_storage_service.dart';
import 'package:wego_marriage/screen/create_content_screen.dart';
import 'package:wego_marriage/screen/payment_screen.dart';
import 'package:wego_marriage/screen/wego_plan.dart';
import 'package:wego_marriage/screen/rewards_screen.dart';
// epic_badges_screen exports BadgeData, kBadgeList, safeBase64Decode — yahi use karein
import 'package:wego_marriage/screen/epic_badges_screen.dart';
// badge_helper mein safeBase64Decode duplicate hai — hide karo
import 'package:wego_marriage/screen/badge_helper.dart' hide safeBase64Decode;
import 'package:wego_marriage/screen/comments_screen.dart';
import 'package:wego_marriage/screen/user_posts_feed_screen.dart';
import 'package:wego_marriage/widgets/level_badge.dart';
import 'app_localizations.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _postsKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();
  final PostService _postService = PostService();

  List<UserPost> _userPosts = [];
  List<UserPost> _userReposts = [];
  bool _isLoadingPosts = true;
  bool _isLoadingReposts = true;

  int _followersCount = 0;
  int _followingCount = 0;
  bool _isLoadingStats = true;
  // Live count subscriptions — follow/unfollow turant reflect karne ke liye.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _followersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _followingSub;
  // Live reposts subscription — jab user kisi ki post repost kare (aur woh
  // post ki `repostedBy` array mein humara uid add ho jaye), grid foran
  // refresh ho jaye. Pehle yeh ek-shot get tha jo sirf initState pe chalta
  // tha, isliye repost karne ke baad MyProfile tab pe wapas aane par bhi
  // grid empty rehti thi.
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _userRepostsSub;

  // ── Firebase User ──
  String _firebaseName = '';
  String _firebaseUsername = '';
  String _firebasePhotoUrl = '';
  bool _isEmailVerified = false;

  // ── Credit ──
  double _creditLimit = 50000;
  double _creditUsed = 0;
  bool _isLoadingCredit = true;
  bool _isSavingCredit = false;

  // ── Level ──
  int _userLevel = 1;
  bool _isLoadingLevel = true;
  final List<int> _levelSteps = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _levelStreamSub;

  late AnimationController _gaugeAnimController;
  late Animation<double> _gaugeAnim;
  double _prevGaugePct = 0;

  late AnimationController _levelAnimController;
  late Animation<double> _levelBarAnim;
  double _prevLevelPct = 0.1;

  // ── Profile Level Bar Animation ──
  late AnimationController _profileLevelAnimController;
  late Animation<double> _profileLevelAnim;

  static const double _minLimit = 10000;
  static const double _maxLimit = 500000;

  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  static const _levelFeatures = [
    _LevelFeature(10,  'Voice Changer',           'Chat mein apni awaz badlo — 8 styles',     Icons.mic,                Color(0xFFF5C842), Color(0xFF8B0000)),
    _LevelFeature(20,  'Emoji Bomb',              'Poori screen par colorful emoji blast',     Icons.auto_awesome,       Color(0xFFE91E8C), Color(0xFFFFFFFF)),
    _LevelFeature(30,  'Flash Message',           'Chat list mein message chamke ga',          Icons.flash_on,           Color(0xFF4CAF50), Color(0xFFFFFFFF)),
    _LevelFeature(40,  'Stealth Mode',            "Parh lo — 'Seen' kabhi na jaye",           Icons.visibility_off,     Color(0xFF2196F3), Color(0xFFFFFFFF)),
    _LevelFeature(50,  'Level Booster Gift',      'Gift bhej kar dusron ka level barha do',    Icons.card_giftcard,      Color(0xFF9C27B0), Color(0xFFFFFFFF)),
    _LevelFeature(60,  'Platinum Badge',          'Gold wings + red gem badge unlocked',       Icons.military_tech,      Color(0xFFF5C842), Color(0xFF8B0000)),
    _LevelFeature(70,  'Diamond Badge',           'Winged gold star + blue gem badge',         Icons.diamond,            Color(0xFF1565C0), Color(0xFFFFFFFF)),
    _LevelFeature(80,  'Titanium + Grand Entry',  'Silver badge + dramatic entry effect',      Icons.shield,             Color(0xFF546E7A), Color(0xFFFFFFFF)),
    _LevelFeature(90,  'Black Hole + Rainbow',    'Dark badge + animated rainbow name',        Icons.blur_circular,      Color(0xFF1A0030), Color(0xFFE040FB)),
    _LevelFeature(100, 'Supreme King',            'Purple shield + Global Announcement!',      Icons.workspace_premium,  Color(0xFF6A0DAD), Color(0xFFF06292)),
  ];

  @override
  void initState() {
    super.initState();
    _gaugeAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _gaugeAnim = Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(parent: _gaugeAnimController, curve: Curves.easeInOut));

    _levelAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _levelBarAnim = Tween<double>(begin: 0.1, end: 0.1).animate(CurvedAnimation(parent: _levelAnimController, curve: Curves.easeInOut));

    // ── Profile level bar animation ──
    _profileLevelAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _profileLevelAnim = Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(parent: _profileLevelAnimController, curve: Curves.easeOut));

    _loadFirebaseUser();
    _loadUserPosts();
    _loadUserReposts();
    _loadStats();
    _loadCreditData();
    _loadUserLevel();
  }

  @override
  void dispose() {
    _levelStreamSub?.cancel();
    _followersSub?.cancel();
    _followingSub?.cancel();
    _userRepostsSub?.cancel();
    _scrollController.dispose();
    _gaugeAnimController.dispose();
    _levelAnimController.dispose();
    _profileLevelAnimController.dispose();
    super.dispose();
  }

  // ── Firebase User ─────────────────────────────
  Future<void> _loadFirebaseUser() async {
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) return;
    await fbUser.reload();
    final refreshed = FirebaseAuth.instance.currentUser!;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(refreshed.uid).get();
      final data = doc.data() ?? {};
      if (mounted) setState(() {
        _firebaseName     = data['name']     as String? ?? refreshed.displayName ?? '';
        _firebaseUsername = data['username'] as String? ?? refreshed.email       ?? '';
        _firebasePhotoUrl = data['photoUrl'] as String? ?? refreshed.photoURL    ?? '';
        _isEmailVerified  = refreshed.emailVerified;
      });
    } catch (_) {
      if (mounted) setState(() {
        _firebaseName     = refreshed.displayName ?? '';
        _firebaseUsername = refreshed.email       ?? '';
        _firebasePhotoUrl = refreshed.photoURL    ?? '';
        _isEmailVerified  = refreshed.emailVerified;
      });
    }
  }

  // ── Level ─────────────────────────────────────
  Future<void> _loadUserLevel() async {
    final uid = _currentUid;
    if (uid == null) {
      if (mounted) setState(() => _isLoadingLevel = false);
      return;
    }
    _levelStreamSub?.cancel();
    _levelStreamSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final lvl = (snap.data()?['level'] as num?)?.toInt() ?? 1;
      final clamped = lvl.clamp(1, 100);
      setState(() {
        _userLevel = clamped;
        _isLoadingLevel = false;
      });
      _animateLevel(clamped);
      _animateProfileLevel(clamped);
    }, onError: (e) {
      debugPrint('Level stream error: $e');
      if (mounted) setState(() => _isLoadingLevel = false);
    });
  }

  void _animateLevel(int level) {
    final toPct = level / 100.0;
    _levelBarAnim = Tween<double>(begin: _prevLevelPct, end: toPct).animate(CurvedAnimation(parent: _levelAnimController, curve: Curves.easeInOut));
    _prevLevelPct = toPct;
    _levelAnimController.forward(from: 0);
  }

  void _animateProfileLevel(int level) {
    final toPct = level / 100.0;
    _profileLevelAnim = Tween<double>(begin: 0, end: toPct).animate(CurvedAnimation(parent: _profileLevelAnimController, curve: Curves.easeOut));
    _profileLevelAnimController.forward(from: 0);
  }

  Future<void> _saveLevel(int level) async {
    final uid = _currentUid; if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'level': level, 'levelUpdatedAt': FieldValue.serverTimestamp()});
    } catch (e) { debugPrint('Level save: $e'); }
  }

  Color _getLevelColor(double pct) {
    if (pct <= 0.5) return Color.lerp(const Color(0xFF1D9E75), const Color(0xFFBA7517), pct / 0.5)!;
    return Color.lerp(const Color(0xFFBA7517), const Color(0xFFE24B4A), (pct - 0.5) / 0.5)!;
  }

  String _getLevelStatus(int l) => l <= 30 ? 'Beginner' : l <= 70 ? 'Rising' : 'Elite';
  Color  _getLevelStatusBg(int l)   => l <= 30 ? const Color(0xFFE1F5EE) : l <= 70 ? const Color(0xFFFAEEDA) : const Color(0xFFFCEBEB);
  Color  _getLevelStatusText(int l) => l <= 30 ? const Color(0xFF0F6E56) : l <= 70 ? const Color(0xFF854F0B) : const Color(0xFFA32D2D);

  // ── Credit ────────────────────────────────────
  Future<void> _loadCreditData() async {
    final uid = _currentUid;
    if (uid == null) { setState(() => _isLoadingCredit = false); return; }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final d = doc.data()!;
        final limit = (d['creditLimit'] as num?)?.toDouble() ?? 50000;
        final used  = (d['creditUsed']  as num?)?.toDouble() ?? 0;
        if (mounted) { setState(() { _creditLimit = limit.clamp(_minLimit, _maxLimit); _creditUsed = used; _isLoadingCredit = false; }); _animateGauge(_creditPct(_creditLimit)); }
      } else {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({'creditLimit': 50000, 'creditUsed': 0, 'creditTier': 'BASIC'}, SetOptions(merge: true));
        if (mounted) { setState(() => _isLoadingCredit = false); _animateGauge(_creditPct(_creditLimit)); }
      }
    } catch (e) { debugPrint('Credit: $e'); if (mounted) setState(() => _isLoadingCredit = false); }
  }

  double _creditPct(double val) => ((val - _minLimit) / (_maxLimit - _minLimit)).clamp(0.0, 1.0);
  void _animateGauge(double toPct) {
    _gaugeAnim = Tween<double>(begin: _prevGaugePct, end: toPct).animate(CurvedAnimation(parent: _gaugeAnimController, curve: Curves.easeInOut));
    _prevGaugePct = toPct;
    _gaugeAnimController.forward(from: 0);
  }

  String _creditTierName(double l)    => l < 100000 ? 'BASIC' : l < 250000 ? 'AVERAGE' : l < 400000 ? 'GOOD' : 'PREMIUM';
  Color  _creditTierColor(double l)   => l < 100000 ? const Color(0xFFE24B4A) : l < 250000 ? const Color(0xFFEF9F27) : l < 400000 ? const Color(0xFF378ADD) : const Color(0xFF1D9E75);
  Color  _creditTierBgColor(double l) => l < 100000 ? const Color(0xFFFCEBEB) : l < 250000 ? const Color(0xFFFAEEDA) : l < 400000 ? const Color(0xFFE6F1FB)  : const Color(0xFFE1F5EE);
  String _formatCreditAmount(double v) => v >= 100000 ? '₹${(v/100000).toStringAsFixed(1)}L' : v >= 1000 ? '₹${(v/1000).toStringAsFixed(0)}K' : '₹${v.toStringAsFixed(0)}';
  String _formatWithComma(double v) => '₹${v.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

  // ── Stats ─────────────────────────────────────
  // Live listener: jaise hi koi user follow/unfollow karega, counts foran
  // update ho jayenge — page refresh ki zaroorat nahi.
  void _loadStats() {
    final uid = _currentUid;
    if (uid == null) {
      if (mounted) setState(() => _isLoadingStats = false);
      return;
    }
    _followersSub?.cancel();
    _followingSub?.cancel();

    _followersSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('followers')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _followersCount = snap.docs.length;
        _isLoadingStats = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    });

    _followingSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('following')
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      setState(() {
        _followingCount = snap.docs.length;
        _isLoadingStats = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _isLoadingStats = false);
    });
  }

  Future<void> _loadUserPosts() async {
    setState(() => _isLoadingPosts = true);
    try {
      final localPosts = _postService.getUserPosts();
      final uid = _currentUid;
      List<UserPost> firestorePosts = [];
      if (uid != null) {
        final snap = await FirebaseFirestore.instance
            .collection('posts')
            .where('authorid', isEqualTo: uid)
            .get();

        firestorePosts = snap.docs.map((d) {
          final data = d.data();
          final ts = data['timestamp'];
          DateTime when = DateTime.now();
          if (ts is Timestamp) when = ts.toDate();

          final visStr = (data['visibility'] ?? 'everyone').toString();
          final visibility = PostVisibility.values.firstWhere(
                (v) => v.name == visStr,
            orElse: () => PostVisibility.everyone,
          );

          return UserPost(
            id: d.id,
            mediaPath: (data['imageUrl'] ?? '').toString(),
            caption: (data['text'] ?? '').toString(),
            contentType: ContentMode.post,
            timestamp: when,
            location: (data['location'] ?? '').toString(),
            hashtags: List<String>.from(data['hashtags'] ?? const []),
            visibility: visibility,
            isVideo: data['isVideo'] == true,
            likes: (data['likesCount'] ?? 0) is int ? data['likesCount'] as int : 0,
            comments: (data['commentsCount'] ?? 0) is int ? data['commentsCount'] as int : 0,
          );
        }).toList();
      }

      final firestoreIds = firestorePosts.map((p) => p.id).toSet();
      final merged = <UserPost>[
        ...firestorePosts,
        ...localPosts.where((p) => !firestoreIds.contains(p.id)),
      ];
      merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      if (!mounted) return;
      setState(() { _userPosts = merged; _isLoadingPosts = false; });
    } catch (e) {
      debugPrint('Error loading user posts: $e');
      final posts = _postService.getUserPosts();
      if (!mounted) return;
      setState(() { _userPosts = posts; _isLoadingPosts = false; });
    }
  }

  // ── Reposts ───────────────────────────────────
  // Live subscription on `posts where repostedBy arrayContains <me>` — har
  // repost / un-repost tab instantly grid mein reflect ho jata hai (chahay
  // current user kahin se bhi action kare: home feed, post detail, etc.).
  void _loadUserReposts() {
    _userRepostsSub?.cancel();
    final uid = _currentUid;
    if (uid == null) {
      if (mounted) setState(() {
        _userReposts = [];
        _isLoadingReposts = false;
      });
      return;
    }
    if (mounted) setState(() => _isLoadingReposts = true);
    _userRepostsSub = FirebaseFirestore.instance
        .collection('posts')
        .where('repostedBy', arrayContains: uid)
        .limit(50)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final reposts = snap.docs.map((d) {
        final data = d.data();
        final ts = data['timestamp'];
        DateTime when = DateTime.now();
        if (ts is Timestamp) when = ts.toDate();
        final visStr = (data['visibility'] ?? 'everyone').toString();
        final visibility = PostVisibility.values.firstWhere(
              (v) => v.name == visStr,
          orElse: () => PostVisibility.everyone,
        );
        return UserPost(
          id: d.id,
          mediaPath: (data['imageUrl'] ?? '').toString(),
          caption: (data['text'] ?? '').toString(),
          contentType: ContentMode.post,
          timestamp: when,
          location: (data['location'] ?? '').toString(),
          hashtags: List<String>.from(data['hashtags'] ?? const []),
          visibility: visibility,
          isVideo: data['isVideo'] == true,
          likes: (data['likesCount'] ?? 0) is int ? data['likesCount'] as int : 0,
          comments: (data['commentsCount'] ?? 0) is int ? data['commentsCount'] as int : 0,
        );
      }).toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      setState(() {
        _userReposts = reposts;
        _isLoadingReposts = false;
      });
    }, onError: (e) {
      debugPrint('Error streaming user reposts: $e');
      if (!mounted) return;
      setState(() {
        _userReposts = [];
        _isLoadingReposts = false;
      });
    });
  }

  // ── Profile Pic ───────────────────────────────
  Future<void> _changeProfilePicture() async {
    if (!await _showPermissionDialog()) return;
    final status = await Permission.photos.request();
    if (!status.isGranted && !status.isLimited) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('permission_denied')), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      if (status.isPermanentlyDenied && mounted) _showSettingsDialog();
      return;
    }
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 800);
    if (image != null && mounted) {
      context.read<UserProvider>().updateAvatar(image.path);
      final uid = _currentUid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({'photoUrl': image.path});
        setState(() => _firebasePhotoUrl = image.path);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('profile_picture_updated')), backgroundColor: const Color(0xFF3DDC84), behavior: SnackBarBehavior.floating));
    }
  }

  Future<bool> _showPermissionDialog() async =>
      await showDialog<bool>(context: context, barrierDismissible: false,
          builder: (ctx) => PopScope(canPop: false, child: AlertDialog(
              backgroundColor: const Color(0xFF5B2BE8),
              title: Text(ctx.tr('gallery_permission'), style: const TextStyle(color: Colors.white)),
              content: Text(ctx.tr('gallery_permission_message'), style: const TextStyle(color: Colors.white70)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('deny'), style: const TextStyle(color: Colors.red))),
                TextButton(onPressed: () => Navigator.pop(ctx, true),  child: Text(ctx.tr('allow'), style: const TextStyle(color: Color(0xFF3DDC84), fontWeight: FontWeight.bold))),
              ]))) ?? false;

  void _showSettingsDialog() => showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF5B2BE8),
      title: Text(ctx.tr('open_settings'), style: const TextStyle(color: Colors.white)),
      content: Text(ctx.tr('enable_photo_access'), style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('cancel'), style: const TextStyle(color: Colors.white70))),
        TextButton(onPressed: () { Navigator.pop(ctx); openAppSettings(); }, child: Text(ctx.tr('open'), style: const TextStyle(color: Color(0xFF3DDC84)))),
      ]));

  // ── Menu ──────────────────────────────────────
  void _showMenu(BuildContext context) {
    Navigator.push(context, PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (ctx, anim, _) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: MediaQuery.of(ctx).size.width * 0.85,
                decoration: BoxDecoration(
                  color: Theme.of(ctx).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                  border: Theme.of(ctx).brightness == Brightness.dark
                      ? const Border(left: BorderSide(color: Colors.white10))
                      : null,
                ),
                child: SafeArea(child: Column(children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text(
                        context.tr('menu'),
                        style: TextStyle(
                          color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white : Colors.black87,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close,
                            color: Theme.of(ctx).brightness == Brightness.dark ? Colors.white : Colors.black87,
                            size: 28),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Column(children: [
                        if (!_isLoadingLevel)
                          _buildProfileLevelMeter(_firebaseName, _firebasePhotoUrl),
                        const SizedBox(height: 12),
                        _buildMenuGaugeCard(ctx),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: _buildMenuItem(
                      context: ctx,
                      icon: Icons.settings_outlined,
                      title: context.tr('settings_menu'),
                      color: Colors.purple,
                      onTap: () { Navigator.pop(ctx); _showSettings(ctx); },
                    ),
                  ),
                  const SizedBox(height: 24),
                ])),
              ),
            ),
          ),
        ),
      ),
      transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeInOut)),
          child: child),
    ));
  }

  // ── Profile Level Meter (Menu) ────────────────
  Widget _buildProfileLevelMeter(String displayName, String displayPhoto) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? Colors.white.withValues(alpha: 0.07) : const Color(0xFFF7F7FA);
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06);
    final subColor = isDark ? Colors.white54 : Colors.black45;

    const xpStart = Color(0xFFE51E8F);
    const xpEnd   = Color(0xFFB224A6);

    final nextLevel = _userLevel >= 100 ? 100 : _userLevel + 10;
    final remaining = (nextLevel - _userLevel).clamp(0, 100);

    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => const EpicBadgesScreen()));
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            width: 54, height: 54,
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [xpStart, xpEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
              boxShadow: [BoxShadow(color: xpStart.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? const Color(0xFF1B1B1B) : Colors.white, width: 2),
              ),
              child: ClipOval(child: _buildAvatarImage(displayPhoto, xpStart)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Flexible(child: Text(displayName.isNotEmpty ? displayName : 'User',
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                  overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [xpStart, xpEnd]), borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: xpStart.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 1))]),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt_rounded, color: Colors.white, size: 12),
                  SizedBox(width: 2),
                  Text('Level', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Text('$_userLevel', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.w800, height: 1)),
              Padding(padding: const EdgeInsets.only(left: 3, bottom: 1),
                  child: Text('/ 100', style: TextStyle(color: subColor, fontSize: 11, fontWeight: FontWeight.w500))),
              const Spacer(),
              Text(_getLevelStatus(_userLevel), style: TextStyle(color: _getLevelStatusText(_userLevel), fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            AnimatedBuilder(
              animation: _profileLevelAnim,
              builder: (_, __) => Stack(children: [
                Container(height: 9, width: double.infinity,
                    decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10))),
                FractionallySizedBox(widthFactor: _profileLevelAnim.value,
                    child: Container(height: 9,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [xpStart, xpEnd], begin: Alignment.centerLeft, end: Alignment.centerRight),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [BoxShadow(color: xpStart.withValues(alpha: 0.55), blurRadius: 8, offset: const Offset(0, 1))]))),
              ]),
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_userLevel >= 100 ? 'MAX LEVEL' : '$remaining XP to Lv $nextLevel',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 10, fontWeight: FontWeight.w600)),
              Text('Lv 100', style: TextStyle(color: subColor, fontSize: 10)),
            ]),
          ])),
        ]),
      ),
    );
  }

  // ── Gauge Card ────────────────────────────────
  Widget _buildMenuGaugeCard(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor  = isDark ? Colors.white60 : Colors.black54;
    final cardBg    = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.04);

    if (_isLoadingCredit) return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
        child: const Center(child: CircularProgressIndicator()));

    final tierColor = _creditTierColor(_creditLimit);
    final available = (_creditLimit - _creditUsed).clamp(0.0, _maxLimit);
    final nextUp    = (_creditLimit + 50000) <= _maxLimit ? '+${_formatCreditAmount(50000)}' : 'MAX';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(20)),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Credit Limit', style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w600)),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _creditTierBgColor(_creditLimit), borderRadius: BorderRadius.circular(20)),
              child: Text(_creditTierName(_creditLimit), style: TextStyle(color: tierColor, fontSize: 11, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 4),
        AnimatedBuilder(
            animation: _gaugeAnim,
            builder: (_, __) => SizedBox(
                width: double.infinity, height: 155,
                child: CustomPaint(
                    painter: _CreditGaugePainter(pct: _gaugeAnim.value, arcColor: tierColor, isDark: isDark),
                    child: Center(child: Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(_formatWithComma(_creditLimit), style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
                          Text('Your Credit Limit', style: TextStyle(color: subColor, fontSize: 10)),
                        ])))))),
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('₹10K', style: TextStyle(color: subColor, fontSize: 10)),
              Text('₹5,00,000', style: TextStyle(color: subColor, fontSize: 10)),
            ])),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
              activeTrackColor: tierColor,
              inactiveTrackColor: isDark ? Colors.white24 : Colors.black12,
              thumbColor: tierColor,
              overlayColor: tierColor.withValues(alpha: 0.15),
              trackHeight: 4),
          child: Slider(
              value: _creditLimit, min: _minLimit, max: _maxLimit, divisions: 98,
              onChanged: (v) { _animateGauge(_creditPct(v)); setState(() => _creditLimit = v); },
              onChangeEnd: (v) async {
                final uid = _currentUid; if (uid == null) return;
                await FirebaseFirestore.instance.collection('users').doc(uid).update({'creditLimit': v, 'creditTier': _creditTierName(v)});
              }),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _creditStatCard('Used',       _formatCreditAmount(_creditUsed),  textColor,               subColor, cardBg),
          const SizedBox(width: 6),
          _creditStatCard('Available',  _formatCreditAmount(available),    const Color(0xFF1D9E75), subColor, cardBg),
          const SizedBox(width: 6),
          _creditStatCard('Next Level', nextUp,                             const Color(0xFF185FA5), subColor, cardBg),
        ]),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isSavingCredit ? null : () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanScreen()));
              },
              icon: _isSavingCredit
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.rocket_launch_rounded, color: Colors.white, size: 16),
              label: Text(_isSavingCredit ? 'Upgrading...' : 'Upgrade Now',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF185FA5),
                  disabledBackgroundColor: const Color(0xFF185FA5).withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0),
            )),
      ]),
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
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 16),
              Expanded(child: Text(title, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16, fontWeight: FontWeight.w500))),
              Icon(Icons.arrow_forward_ios, color: isDark ? Colors.white54 : Colors.black26, size: 16),
            ])));
  }

  void _showSettings(BuildContext context) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));

  // ══════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final user         = context.watch<UserProvider>().user;
    final theme        = Theme.of(context);
    final isDark       = theme.brightness == Brightness.dark;
    final primaryColor = const Color(0xFF4A6CF7);
    final textColor    = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    final displayName  = _firebaseName.isNotEmpty     ? _firebaseName     : user.name;
    final displayUser  = _firebaseUsername.isNotEmpty  ? _firebaseUsername  : user.username;
    final displayPhoto = _firebasePhotoUrl.isNotEmpty  ? _firebasePhotoUrl  : user.avatarUrl;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(context.tr('my_profile'),
            style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          IconButton(
              icon: Icon(Icons.menu, color: textColor, size: 28),
              onPressed: () => _showMenu(context)),
        ],
      ),
      body: ListView(controller: _scrollController, padding: EdgeInsets.zero, children: [
        const SizedBox(height: 20),

        // ── Avatar + Badges professional layout ──
        Center(
          child: Column(
            children: [
              // Profile pic with level badge overlay
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: primaryColor, width: 3),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 5))]),
                    child: ClipOval(child: _buildAvatarImage(displayPhoto, primaryColor)),
                  ),
                  Positioned(
                      bottom: 0, right: 0,
                      child: GestureDetector(
                          onTap: _changeProfilePicture,
                          child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2)),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 16)))),
                ],
              ),

              // Level badge just below avatar
              const SizedBox(height: 8),
              if (_currentUid != null)
                LevelBadge(uid: _currentUid!, size: LevelBadgeSize.large),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── Name + Verified ──
        Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(displayName, style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
          if (_isEmailVerified) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFF1DA1F2).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.verified_rounded, color: Color(0xFF1DA1F2), size: 14),
                SizedBox(width: 3),
                Text('Verified', style: TextStyle(color: Color(0xFF1DA1F2), fontSize: 10, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ])),

        const SizedBox(height: 4),
        Center(child: Text(displayUser, style: TextStyle(color: subTextColor, fontSize: 13))),

        const SizedBox(height: 10),

        // ── Unlocked Badges — professional small row ──
        _buildUnlockedBadgesRow(),

        const SizedBox(height: 6),

        // ── Level Chip ──
        Center(child: _isLoadingLevel
            ? const SizedBox(height: 24)
            : GestureDetector(
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EpicBadgesScreen())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                _getLevelColor(_userLevel / 100),
                _getLevelColor(_userLevel / 100).withValues(alpha: 0.6),
              ]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.military_tech_rounded, color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text('Level $_userLevel — ${_getLevelStatus(_userLevel)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        )),

        const SizedBox(height: 24),
        _buildStatsSection(context),
        const SizedBox(height: 20),
        Container(key: _postsKey, child: _buildPostsSection()),
        const SizedBox(height: 20),
      ]),
    );
  }

  // ══════════════════════════════════════════════
  // 🏅 PROFESSIONAL BADGE ROW
  //    - Chote badges (36px), naam ke neeche
  //    - No floating animation, subtle glow only
  //    - Tap => EpicBadgesScreen
  // ══════════════════════════════════════════════
  Widget _buildUnlockedBadgesRow() {
    if (_isLoadingLevel) return const SizedBox(height: 4);

    final unlockedBadges = kBadgeList.where((b) => _userLevel >= b.level).toList();
    if (unlockedBadges.isEmpty) return const SizedBox(height: 4);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EpicBadgesScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(unlockedBadges.length, (i) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _TinyBadge(badge: unlockedBadges[i]),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildAvatarImage(String url, Color primaryColor) {
    final ph = Container(color: Colors.grey[300], child: Icon(Icons.person, color: primaryColor, size: 60));
    if (url.isEmpty) return ph;
    if (url.startsWith('http')) return Image.network(url,
        fit: BoxFit.cover, width: double.infinity, height: double.infinity,
        loadingBuilder: (_, c, p) => p == null ? c : Container(color: Colors.grey[300], child: const Center(child: CircularProgressIndicator())),
        errorBuilder: (_, __, ___) => ph);
    final f = File(url);
    if (f.existsSync()) return Image.file(f, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => ph);
    return ph;
  }

  Widget _creditStatCard(String label, String value, Color valueColor, Color subColor, Color bg) =>
      Expanded(child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.15), width: 0.5)),
          child: Column(children: [
            Text(label, style: TextStyle(color: subColor, fontSize: 10)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.w600)),
          ])));

  Widget _buildStatsSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = _currentUid ?? '';
    return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          GestureDetector(
              onTap: () => Scrollable.ensureVisible(_postsKey.currentContext!, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut),
              child: _buildStatItem(context, context.tr('posts'), '${_userPosts.length}')),
          GestureDetector(
              onTap: () {
                if (uid.isEmpty) return;
                Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(title: context.tr('followers'), targetUserId: uid)));
              },
              child: _buildStatItem(context, context.tr('followers'), _isLoadingStats ? '...' : '$_followersCount')),
          GestureDetector(
              onTap: () {
                if (uid.isEmpty) return;
                Navigator.push(context, MaterialPageRoute(builder: (_) => FollowListScreen(title: context.tr('following'), targetUserId: uid)));
              },
              child: _buildStatItem(context, context.tr('following'), _isLoadingStats ? '...' : '$_followingCount')),
        ]));
  }

  Widget _buildPostsSection() {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: _MyProfileTabsSection(
        isDark: isDark,
        textColor: textColor,
        postsLabel: context.tr('my_posts'),
        repostsLabel: context.tr('reposts'),
        isLoadingPosts: _isLoadingPosts,
        isLoadingReposts: _isLoadingReposts,
        posts: _userPosts,
        reposts: _userReposts,
        emptyPostsBuilder: (ctx) => Container(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            Icon(Icons.photo_library_outlined, size: 64, color: textColor.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(context.tr('no_posts_yet'), style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 16)),
            const SizedBox(height: 8),
            Text(context.tr('create_first_post'), style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 14)),
          ]),
        ),
        emptyRepostsBuilder: (ctx) => Container(
          padding: const EdgeInsets.all(32),
          child: Column(children: [
            Icon(Icons.repeat, size: 64, color: textColor.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(context.tr('no_reposts_yet'), style: TextStyle(color: textColor.withValues(alpha: 0.7), fontSize: 16)),
          ]),
        ),
        tileBuilder: (ctx, post) => GestureDetector(
          onTap: () => _openPostFullscreen(ctx, post),
          onLongPress: () => _showPostOptions(ctx, post),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(children: [
                Positioned.fill(child: _buildPostMedia(post)),
                if (post.isVideo)
                  Positioned(top: 8, right: 8,
                      child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.play_arrow, color: Colors.white, size: 16))),
                Positioned(left: 0, right: 0, bottom: 0, child: _buildTileStatsOverlay(post)),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailStatsRow(BuildContext dialogCtx, UserPost post) {
    final isFirestoreId = !post.id.contains('_');
    if (!isFirestoreId) {
      return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _buildStat(Icons.favorite_border, '${post.likes}'),
        _buildStat(Icons.chat_bubble_outline, '${post.comments}'),
        _buildStat(Icons.visibility, post.visibility.name),
      ]);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('posts').doc(post.id).snapshots(),
      builder: (context, snap) {
        final data = (snap.hasData && snap.data!.exists) ? (snap.data!.data() ?? {}) : <String, dynamic>{};
        final likes    = (data['likesCount']    ?? post.likes)    as int;
        final comments = (data['commentsCount'] ?? post.comments) as int;
        final shares   = (data['shareCount']    ?? 0)             as int;
        return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _buildStat(Icons.favorite_border, '$likes'),
          GestureDetector(
              onTap: () {
                Navigator.pop(dialogCtx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => CommentsScreen(
                    postId: post.id, postUsername: _firebaseName,
                    currentUserAvatar: _firebasePhotoUrl, currentUsername: _firebaseName)));
              },
              child: _buildStat(Icons.chat_bubble_outline, '$comments')),
          _buildStat(Icons.share, '$shares'),
        ]);
      },
    );
  }

  Widget _buildTileStatsOverlay(UserPost post) {
    final isFirestoreId = !post.id.contains('_');
    if (!isFirestoreId) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('posts').doc(post.id).snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) return const SizedBox.shrink();
        final data     = snap.data!.data() ?? {};
        final likes    = (data['likesCount']    ?? 0) as int;
        final comments = (data['commentsCount'] ?? 0) as int;
        final shares   = (data['shareCount']    ?? 0) as int;
        if (likes == 0 && comments == 0 && shares == 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xCC000000)])),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _tileStat(Icons.favorite, likes),
            _tileStat(Icons.chat_bubble, comments),
            if (shares > 0) _tileStat(Icons.share, shares),
          ]),
        );
      },
    );
  }

  Widget _tileStat(IconData icon, int n) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: Colors.white, size: 12),
    const SizedBox(width: 3),
    Text(_compactCount(n), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
  ]);

  String _compactCount(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }

  Widget _buildPostMedia(UserPost post) {
    final ph = Container(color: Colors.grey[300], child: Icon(post.isVideo ? Icons.videocam : Icons.image, color: Colors.grey));
    if (post.thumbnailBytes != null) return Image.memory(post.thumbnailBytes!, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => ph);
    // ✅ Video posts ke liye Image.network kaam nahi karta — mp4 URL ka
    //    poster server-side generate nahi hota. video_thumbnail se on-the-fly
    //    pehla frame nikal kar grid tile mein dikhate hain.
    if (post.isVideo && post.mediaPath.startsWith('http')) {
      return _VideoTileThumbnail(videoUrl: post.mediaPath, placeholder: ph);
    }
    if (post.mediaPath.startsWith('http')) return Image.network(post.mediaPath, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
        loadingBuilder: (_, c, p) => p == null ? c : Container(color: Colors.grey[300], child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
        errorBuilder: (_, __, ___) => ph);
    final f = File(post.mediaPath);
    if (f.existsSync()) return Image.file(f, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => ph);
    return ph;
  }

  // Instagram-style scrollable feed khole — saari user posts ek vertical
  // list mein, tapped post se shuru. Firestore-backed posts ke liye yahi
  // best UX hai (like / comment / share / repost sab inline). Local-only
  // posts (id mein `_`) ke liye purana dialog fallback rakha.
  void _openPostFullscreen(BuildContext context, UserPost post) {
    final isFirestoreId = !post.id.contains('_');
    if (!isFirestoreId) {
      _showUserPostDetail(context, post);
      return;
    }
    final uid = _currentUid;
    if (uid == null) {
      _showUserPostDetail(context, post);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserPostsFeedScreen(
          userId: uid,
          initialPostId: post.id,
          title: _firebaseName.isEmpty ? 'Posts' : '@$_firebaseName',
        ),
      ),
    );
  }

  void _showUserPostDetail(BuildContext context, UserPost post) {
    final isDark       = Theme.of(context).brightness == Brightness.dark;
    final textColor    = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    showDialog(context: context, builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
                color: Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: isDark ? Border.all(color: Colors.white12) : null),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(height: 300, child: _buildPostMedia(post))),
              Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                          color: post.contentType == ContentMode.post ? Colors.blue
                              : post.contentType == ContentMode.story ? Colors.orange : Colors.purple,
                          borderRadius: BorderRadius.circular(12)),
                      child: Text(post.contentType.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
                  const SizedBox(width: 8),
                  Text(_formatDate(post.timestamp), style: TextStyle(color: subTextColor, fontSize: 12)),
                ]),
                const SizedBox(height: 12),
                if (post.caption.isNotEmpty) Text(post.caption, style: TextStyle(color: textColor, fontSize: 14)),
                if (post.hashtags.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 8),
                      child: Wrap(spacing: 6, children: post.hashtags.map((t) => Chip(
                          label: Text(t, style: const TextStyle(fontSize: 11)),
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero)).toList())),
                const SizedBox(height: 16),
                _buildDetailStatsRow(ctx, post),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  TextButton.icon(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close), label: Text(context.tr('close'))),
                  TextButton.icon(onPressed: () { Navigator.pop(ctx); _showPostOptions(ctx, post); }, icon: const Icon(Icons.more_vert), label: Text(context.tr('options'))),
                ]),
              ])),
            ]))));
  }

  void _showPostOptions(BuildContext context, UserPost post) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(context: context,
        backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(color: isDark ? Colors.grey[600] : Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          _buildOptionTile(Icons.edit,   context.tr('edit_post'),   () => Navigator.pop(ctx)),
          _buildOptionTile(Icons.share,  context.tr('share'),       () => Navigator.pop(ctx)),
          _buildOptionTile(Icons.copy,   context.tr('copy_link'),   () => Navigator.pop(ctx)),
          _buildOptionTile(Icons.delete, context.tr('delete_post'), () async {
            Navigator.pop(ctx);
            if (await _showDeleteConfirmation(ctx)) {
              // 1) Firestore se permanent delete — warna stream wapas le aata hai.
              bool fsOk = true;
              try {
                await FirebaseFirestore.instance
                    .collection('posts')
                    .doc(post.id)
                    .delete();
              } catch (e) {
                fsOk = false;
                debugPrint('Firestore delete failed: $e');
              }
              // 2) Local cache bhi clean karo (drafts/locally-created posts).
              final localOk = await _postService.deletePost(post.id);
              // 3) Optimistic UI — list se turant hata do, phir refresh.
              if (mounted) {
                setState(() {
                  _userPosts.removeWhere((p) => p.id == post.id);
                });
              }
              _loadUserPosts();

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text((fsOk || localOk)
                      ? context.tr('post_deleted_success')
                      : context.tr('delete_post_failed')),
                  backgroundColor:
                      (fsOk || localOk) ? Colors.green : Colors.red,
                ));
              }
            }
          }, iconColor: Colors.red),
          const SizedBox(height: 16),
        ])));
  }

  Widget _buildOptionTile(IconData icon, String label, VoidCallback onTap, {Color? iconColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
        leading: Icon(icon, color: iconColor ?? (isDark ? Colors.white : Colors.black87)),
        title: Text(label, style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
        onTap: onTap);
  }

  Widget _buildStat(IconData icon, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = isDark ? Colors.white : Colors.black87;
    return Row(children: [Icon(icon, color: c, size: 20), const SizedBox(width: 4), Text(value, style: TextStyle(color: c))]);
  }

  String _formatDate(DateTime date) {
    final d = DateTime.now().difference(date);
    if (d.inDays > 0) return '${d.inDays}d ago';
    if (d.inHours > 0) return '${d.inHours}h ago';
    if (d.inMinutes > 0) return '${d.inMinutes}m ago';
    return 'Just now';
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async =>
      await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
          title: Text(context.tr('delete_post')),
          content: Text(context.tr('delete_post_confirm')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('cancel'))),
            TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(context.tr('delete'))),
          ])) ?? false;

  Widget _buildStatItem(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Text(value, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 13)),
    ]);
  }
}

// ══════════════════════════════════════════════
//  Level Feature Model
// ══════════════════════════════════════════════
class _LevelFeature {
  final int level;
  final String name;
  final String desc;
  final IconData icon;
  final Color badgeBg;
  final Color iconColor;
  const _LevelFeature(this.level, this.name, this.desc, this.icon, this.badgeBg, this.iconColor);
}

// ══════════════════════════════════════════════
//  🏅 TINY BADGE — profile row ke liye
//     Static (no animation), 38px, subtle glow
// ══════════════════════════════════════════════
class _TinyBadge extends StatefulWidget {
  final BadgeData badge;
  const _TinyBadge({required this.badge});

  @override
  State<_TinyBadge> createState() => _TinyBadgeState();
}

class _TinyBadgeState extends State<_TinyBadge> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _bytes = safeBase64Decode(widget.badge.badgeB64);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: widget.badge.glowColor.withValues(alpha: 0.45),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: _bytes != null
          ? Image.memory(_bytes!, fit: BoxFit.contain, gaplessPlayback: true)
          : Icon(Icons.emoji_events_rounded, color: widget.badge.glowColor, size: 22),
    );
  }
}

// ══════════════════════════════════════════════
//  Gauge Painter
// ══════════════════════════════════════════════
class _CreditGaugePainter extends CustomPainter {
  final double pct;
  final Color arcColor;
  final bool isDark;
  _CreditGaugePainter({required this.pct, required this.arcColor, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final cx     = size.width / 2;
    final cy     = size.height * 0.75;
    final radius = size.width * 0.42;
    const startAngle = pi;
    const sweepAngle = pi;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    canvas.drawArc(rect, startAngle, sweepAngle, false,
        Paint()..color = isDark ? Colors.white24 : Colors.black12 ..style = PaintingStyle.stroke ..strokeWidth = 18 ..strokeCap = StrokeCap.round);
    if (pct > 0) canvas.drawArc(rect, startAngle, sweepAngle * pct, false,
        Paint()..color = arcColor ..style = PaintingStyle.stroke ..strokeWidth = 18 ..strokeCap = StrokeCap.round);

    final needleAngle = pi + (sweepAngle * pct);
    final nx = cx + (radius - 16) * cos(needleAngle);
    final ny = cy + (radius - 16) * sin(needleAngle);
    canvas.drawLine(Offset(cx, cy), Offset(nx, ny),
        Paint()..color = arcColor ..strokeWidth = 4 ..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(cx, cy), 10, Paint()..color = arcColor);
    canvas.drawCircle(Offset(cx, cy), 5,  Paint()..color = isDark ? Colors.black : Colors.white);
  }

  @override
  bool shouldRepaint(_CreditGaugePainter old) => old.pct != pct || old.arcColor != arcColor;
}

// ══════════════════════════════════════════════
//  Two-tab section: My Posts + Reposts
// ══════════════════════════════════════════════
class _MyProfileTabsSection extends StatefulWidget {
  const _MyProfileTabsSection({
    required this.isDark,
    required this.textColor,
    required this.postsLabel,
    required this.repostsLabel,
    required this.isLoadingPosts,
    required this.isLoadingReposts,
    required this.posts,
    required this.reposts,
    required this.emptyPostsBuilder,
    required this.emptyRepostsBuilder,
    required this.tileBuilder,
  });

  final bool isDark;
  final Color textColor;
  final String postsLabel;
  final String repostsLabel;
  final bool isLoadingPosts;
  final bool isLoadingReposts;
  final List<UserPost> posts;
  final List<UserPost> reposts;
  final Widget Function(BuildContext) emptyPostsBuilder;
  final Widget Function(BuildContext) emptyRepostsBuilder;
  final Widget Function(BuildContext, UserPost) tileBuilder;

  @override
  State<_MyProfileTabsSection> createState() => _MyProfileTabsSectionState();
}

class _MyProfileTabsSectionState extends State<_MyProfileTabsSection>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() { if (mounted) setState(() {}); });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _grid(List<UserPost> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
      itemCount: items.length,
      itemBuilder: (ctx, i) => widget.tileBuilder(ctx, items[i]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = const Color(0xFF4A6CF7);
    final activeIndex = _tabController.index;

    Widget activeBody;
    if (activeIndex == 0) {
      activeBody = widget.isLoadingPosts
          ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          : widget.posts.isEmpty ? widget.emptyPostsBuilder(context) : _grid(widget.posts);
    } else {
      activeBody = widget.isLoadingReposts
          ? const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          : widget.reposts.isEmpty ? widget.emptyRepostsBuilder(context) : _grid(widget.reposts);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TabBar(
        controller: _tabController,
        labelColor: primaryColor,
        unselectedLabelColor: widget.isDark ? Colors.white70 : Colors.black54,
        indicatorColor: primaryColor,
        indicatorWeight: 2.5,
        tabs: [
          Tab(icon: const Icon(Icons.grid_view_rounded, size: 20), text: widget.postsLabel),
          Tab(icon: const Icon(Icons.repeat, size: 20), text: widget.repostsLabel),
        ],
      ),
      const SizedBox(height: 12),
      activeBody,
    ]);
  }
}

// ══════════════════════════════════════════════
//  Video tile thumbnail — pehla frame fetch karke dikhata hai.
//  Grid scroll back kare to dobara network hit na ho is liye memory cache.
//  Failure pe placeholder dikhata hai (warna ImageDecoder ka "rough" output
//  aata tha jo user ko broken laga).
// ══════════════════════════════════════════════
class _VideoTileThumbnail extends StatefulWidget {
  final String videoUrl;
  final Widget placeholder;
  const _VideoTileThumbnail({required this.videoUrl, required this.placeholder});

  // Process-lifetime cache. Different posts ki alag URL → alag entry.
  // Failed attempts ko bhi `null` cache karte hain taa ke har scroll par
  // dobara timeout na ho.
  static final Map<String, Uint8List?> _cache = {};

  @override
  State<_VideoTileThumbnail> createState() => _VideoTileThumbnailState();
}

class _VideoTileThumbnailState extends State<_VideoTileThumbnail> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = _VideoTileThumbnail._cache[widget.videoUrl];
    if (_VideoTileThumbnail._cache.containsKey(widget.videoUrl)) {
      // Cache hit (success OR previous failure).
      if (!mounted) return;
      setState(() {
        _bytes = cached;
        _loading = false;
        _failed = cached == null;
      });
      return;
    }
    try {
      final bytes = await vt.VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: vt.ImageFormat.JPEG,
        maxWidth: 240,
        quality: 65,
      );
      _VideoTileThumbnail._cache[widget.videoUrl] = bytes;
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _loading = false;
        _failed = bytes == null;
      });
    } catch (e) {
      _VideoTileThumbnail._cache[widget.videoUrl] = null;
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: Colors.black54,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white70),
          ),
        ),
      );
    }
    if (_failed || _bytes == null) return widget.placeholder;
    return Image.memory(
      _bytes!,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => widget.placeholder,
    );
  }
}