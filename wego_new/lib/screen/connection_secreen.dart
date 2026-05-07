import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wego_marriage/screen/chat_screen.dart';
import 'package:wego_marriage/screen/video_call_screen.dart';
import 'package:wego_marriage/screen/voice_call_screen.dart';
import 'package:wego_marriage/screen/Advanced _filterscreen.dart';
import 'package:wego_marriage/screen/match_requests_screen.dart';
import 'package:wego_marriage/screen/match_screen.dart';
import 'package:wego_marriage/screen/search_screen.dart';
import 'app_localizations.dart';
import 'app_translations.dart';
const Color kPurple = Color(0xFF6C3FEB);

// ─────────────────────────────────────────────────────────────────────────────
//  DATA MODEL
// ─────────────────────────────────────────────────────────────────────────────
class MatchUser {
  final String uid;
  final String name;
  final int age;
  final String imageUrl;
  final bool hasLiked;
  bool isFollowing;
  bool isPermanentlyFollowed;
  final String privacyLevel;
  final DateTime? lastHeartbeat;
  final bool isReadyToMatch;
  final int intentionScore;
  final String bio;
  final String city;

  MatchUser({
    required this.uid,
    required this.name,
    required this.age,
    required this.imageUrl,
    this.hasLiked = false,
    this.isFollowing = false,
    this.isPermanentlyFollowed = false,
    this.privacyLevel = 'open',
    this.lastHeartbeat,
    this.isReadyToMatch = false,
    this.intentionScore = 0,
    this.bio = '',
    this.city = '',
  });

  factory MatchUser.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MatchUser(
      uid: doc.id,
      name: d['name'] ?? d['fullName'] ?? '',
      age: (d['age'] ?? 0) is int
          ? d['age']
          : int.tryParse(d['age'].toString()) ?? 0,
      imageUrl: d['photoUrl'] ?? d['profileImage'] ?? '',
      hasLiked: d['hasLikedMe'] ?? false,
      isFollowing: d['isFollowing'] ?? false,
      isPermanentlyFollowed: d['isPermanentlyFollowed'] ?? false,
      privacyLevel: d['privacy_level'] ?? 'open',
      lastHeartbeat: (d['last_heartbeat'] as Timestamp?)?.toDate(),
      isReadyToMatch: d['is_ready_to_match'] ?? false,
      intentionScore: d['intention_score'] ?? 0,
      // FIX: bio aur city properly load ho rahe hain
      bio: d['bio'] ?? d['about'] ?? '',
      city: d['city'] ?? d['location'] ?? '',
    );
  }

  String get activeStatus {
    if (lastHeartbeat == null) return 'offline';
    final diff = DateTime.now().difference(lastHeartbeat!);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 3) return 'recent';
    return 'offline';
  }

  // FIX: copyWith mein ab bio aur city bhi included hain
  MatchUser copyWith({
    bool? isFollowing,
    bool? isPermanentlyFollowed,
    bool? hasLiked,
    String? bio,
    String? city,
  }) {
    return MatchUser(
      uid: uid,
      name: name,
      age: age,
      imageUrl: imageUrl,
      hasLiked: hasLiked ?? this.hasLiked,
      isFollowing: isFollowing ?? this.isFollowing,
      isPermanentlyFollowed:
      isPermanentlyFollowed ?? this.isPermanentlyFollowed,
      privacyLevel: privacyLevel,
      lastHeartbeat: lastHeartbeat,
      isReadyToMatch: isReadyToMatch,
      intentionScore: intentionScore,
      bio: bio ?? this.bio,
      city: city ?? this.city,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SMART MATCHING MANAGER
// ─────────────────────────────────────────────────────────────────────────────
class SmartMatchingManager {
  static final _db = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static String? get _myUid => _auth.currentUser?.uid;

  static Future<void> updateField(Map<String, dynamic> data) async {
    if (_myUid == null) return;
    await _db.collection('users').doc(_myUid).update(data);
  }

  static Future<void> sendHeartbeat() async {
    await updateField({'last_heartbeat': FieldValue.serverTimestamp()});
  }

  static Future<void> addIntentionScore(int points) async {
    await updateField({'intention_score': FieldValue.increment(points)});
  }

  static Future<void> evaluateReadiness() async {
    if (_myUid == null) return;
    final doc = await _db.collection('users').doc(_myUid).get();
    final score = (doc.data()?['intention_score'] ?? 0) as int;
    await updateField({'is_ready_to_match': score >= 10});
  }

  static Future<void> enterMatchingGroup() async {
    await updateField({'matching_screen_group': true});
    await sendHeartbeat();
    await evaluateReadiness();
  }

  static Future<void> exitMatchingGroup() async {
    await updateField({
      'matching_screen_group': false,
      'is_ready_to_match': false,
      'intention_score': 0,
    });
  }

  static Future<void> setPrivacy(String level) async {
    await updateField({'privacy_level': level});
  }

  static Future<void> sendConnectRequest(String targetUid) async {
    if (_myUid == null) return;
    final myDoc = await _db.collection('users').doc(_myUid).get();
    final myData = myDoc.data() ?? {};

    await _db
        .collection('users')
        .doc(targetUid)
        .collection('match_requests')
        .doc(_myUid)
        .set({
      'fromUid': _myUid,
      'fromName': myData['name'] ?? myData['fullName'] ?? '',
      'fromAge': myData['age'] ?? 0,
      'fromCity': myData['city'] ?? myData['location'] ?? '',
      'fromImage': myData['photoUrl'] ?? myData['profileImage'] ?? '',
      'timestamp': FieldValue.serverTimestamp(),
      'status': 'pending',
    });

    await _db.collection('users').doc(targetUid).update({
      'request_count': FieldValue.increment(1),
    });
  }

  static Stream<int> requestCountStream() {
    if (_myUid == null) return Stream.value(0);
    return _db
        .collection('users')
        .doc(_myUid)
        .collection('match_requests')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.length);
  }

  static Stream<List<MatchUser>> matchesStream() {
    if (_myUid == null) return Stream.value([]);
    return _db
        .collection('users')
        .where('is_ready_to_match', isEqualTo: true)
        .where('privacy_level', whereIn: ['open', 'semi'])
        .snapshots()
        .map((snap) => snap.docs
        .where((d) => d.id != _myUid)
        .map((d) => MatchUser.fromFirestore(d))
        .where((u) {
      final hb = u.lastHeartbeat;
      if (hb == null) return false;
      return DateTime.now().difference(hb).inMinutes < 5;
    })
        .toList());
  }

  static Future<void> createDirectMatch(String targetUid) async {
    if (_myUid == null) return;
    final matchId = ([_myUid!, targetUid]..sort()).join('_');
    final existing =
    await _db.collection('active_matches').doc(matchId).get();
    if (!existing.exists) {
      await _db.collection('active_matches').doc(matchId).set({
        'users': [_myUid, targetUid],
        'initiator': _myUid,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'popupShown': {_myUid!: false, targetUid: false},
      });
    }
  }

  static Future<void> cancelMatch(String targetUid) async {
    if (_myUid == null) return;
    final matchId = ([_myUid!, targetUid]..sort()).join('_');
    await _db
        .collection('active_matches')
        .doc(matchId)
        .update({'status': 'cancelled'});
  }

  static Future<void> confirmMatch(String targetUid) async {
    if (_myUid == null) return;
    final matchId = ([_myUid!, targetUid]..sort()).join('_');
    await _db
        .collection('active_matches')
        .doc(matchId)
        .update({'status': 'matched'});
  }

  static Stream<QuerySnapshot> incomingMatchStream() {
    if (_myUid == null) return const Stream.empty();
    return _db
        .collection('active_matches')
        .where('users', arrayContains: _myUid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  static Future<void> toggleFollow(String targetUid, bool follow) async {
    if (_myUid == null) return;
    final myRef = _db.collection('users').doc(_myUid);
    final targetRef = _db.collection('users').doc(targetUid);
    if (follow) {
      await myRef.collection('following').doc(targetUid).set({
        'timestamp': FieldValue.serverTimestamp(),
      });
      await targetRef.collection('followers').doc(_myUid).set({
        'timestamp': FieldValue.serverTimestamp(),
      });
      await targetRef.update({'follower_count': FieldValue.increment(1)});
    } else {
      await myRef.collection('following').doc(targetUid).delete();
      await targetRef.collection('followers').doc(_myUid).delete();
      await targetRef.update({'follower_count': FieldValue.increment(-1)});
    }
  }

  static Future<bool> isFollowing(String targetUid) async {
    if (_myUid == null) return false;
    final doc = await _db
        .collection('users')
        .doc(_myUid)
        .collection('following')
        .doc(targetUid)
        .get();
    return doc.exists;
  }

  static Future<void> skipUser(String targetUid) async {
    if (_myUid == null) return;
    await _db
        .collection('users')
        .doc(_myUid)
        .collection('skipped')
        .doc(targetUid)
        .set({'timestamp': FieldValue.serverTimestamp()});
  }

  static Stream<Set<String>> skippedStream() {
    if (_myUid == null) return Stream.value(<String>{});
    return _db
        .collection('users')
        .doc(_myUid)
        .collection('skipped')
        .snapshots()
        .map((s) => s.docs.map((d) => d.id).toSet());
  }

  static Future<void> blockUser(String targetUid) async {
    if (_myUid == null) return;
    await _db
        .collection('users')
        .doc(_myUid)
        .collection('blocked')
        .doc(targetUid)
        .set({'timestamp': FieldValue.serverTimestamp()});
  }

  static Future<void> reportUser(String targetUid, String reason) async {
    if (_myUid == null) return;
    await _db.collection('reports').add({
      'fromUid': _myUid,
      'targetUid': targetUid,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> createMatchFromRequest(String fromUid) async {
    if (_myUid == null) return;
    final matchId = ([_myUid!, fromUid]..sort()).join('_');
    final existing =
    await _db.collection('active_matches').doc(matchId).get();
    if (!existing.exists) {
      await _db.collection('active_matches').doc(matchId).set({
        'users': [_myUid, fromUid],
        'initiator': fromUid,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'popupShown': {_myUid!: false, fromUid: false},
      });
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MATCHES SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  Timer? _heartbeatTimer;
  Timer? _gracePeriodTimer;
  bool _graceCompleted = false;
  String _privacyLevel = 'open';
  int _requestCount = 0;
  StreamSubscription? _requestSub;
  StreamSubscription? _matchSub;

  // FIX: popup guard ko Set banaya — ek saath multiple popups na aayen
  final Set<String> _handledMatchIds = {};
  bool _popupActive = false;

  // FIX: Search aur filter ab actual UI se connected hain
  String _searchQuery = '';
  String _quickFilter = 'all'; // all | now | recent
  Set<String> _skippedUids = {};
  StreamSubscription? _skippedSub;
  final TextEditingController _searchCtrl = TextEditingController();

  // FIX: Local follow state track karne ke liye map
  final Map<String, bool> _followingMap = {};

  @override
  void initState() {
    super.initState();
    _initSmartMatching();
  }

  Future<void> _initSmartMatching() async {
    _gracePeriodTimer = Timer(const Duration(seconds: 10), () async {
      if (!mounted) return;
      setState(() => _graceCompleted = true);
      await SmartMatchingManager.addIntentionScore(1);
      await SmartMatchingManager.enterMatchingGroup();
      _startHeartbeat();
    });

    _requestSub =
        SmartMatchingManager.requestCountStream().listen((count) {
          if (mounted) setState(() => _requestCount = count);
        });

    // FIX: Incoming match stream — duplicate guard ke saath
    _matchSub =
        SmartMatchingManager.incomingMatchStream().listen((snap) {
          for (final doc in snap.docs) {
            final matchId = doc.id;
            if (!_handledMatchIds.contains(matchId)) {
              _handledMatchIds.add(matchId);
              _handleMatchDoc(doc);
            }
          }
        });

    _skippedSub = SmartMatchingManager.skippedStream().listen((set) {
      if (mounted) setState(() => _skippedUids = set);
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (mounted) {
        setState(() {
          _privacyLevel = doc.data()?['privacy_level'] ?? 'open';
        });
      }
    }
  }

  Future<void> _handleMatchDoc(DocumentSnapshot doc) async {
    if (_popupActive) return;
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final data = doc.data() as Map<String, dynamic>;
    final popupShown = Map<String, dynamic>.from(data['popupShown'] ?? {});

    if (popupShown[myUid] == true) return;

    await doc.reference.update({'popupShown.$myUid': true});

    final users = List<String>.from(data['users']);
    final otherUid = users.firstWhere((u) => u != myUid);

    final otherDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(otherUid)
        .get();
    final otherData = otherDoc.data() ?? {};

    if (!mounted) return;

    setState(() => _popupActive = true);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MatchPopupScreen(
          matchedUserName:
          otherData['name'] ?? otherData['fullName'] ?? '',
          matchedUserImage:
          otherData['photoUrl'] ?? otherData['profileImage'] ?? '',
          matchedUserUid: otherUid,
          onSayHello: () async {
            await SmartMatchingManager.confirmMatch(otherUid);
            if (!mounted) return;
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  username: otherData['name'] ?? '',
                  avatarUrl: otherData['photoUrl'] ?? '',
                  lastMessage: 'Say Hello 👋',
                  receiverUid: otherUid, // ✅ yeh add karo
                ),
              ),
            );
          },
          onCancel: () async {
            await SmartMatchingManager.cancelMatch(otherUid);
            if (!mounted) return;
            Navigator.pop(context);
          },
        ),
      ),
    );

    if (mounted) setState(() => _popupActive = false);
  }

  void _startHeartbeat() {
    _heartbeatTimer =
        Timer.periodic(const Duration(seconds: 30), (_) async {
          await SmartMatchingManager.sendHeartbeat();
        });
    SmartMatchingManager.sendHeartbeat();
  }

  @override
  void dispose() {
    _gracePeriodTimer?.cancel();
    _heartbeatTimer?.cancel();
    _requestSub?.cancel();
    _matchSub?.cancel();
    _skippedSub?.cancel();
    _searchCtrl.dispose();
    SmartMatchingManager.exitMatchingGroup();
    super.dispose();
  }

  // FIX: Heart tap — open users ke liye direct match, semi ke liye request
  Future<void> _onHeartTap(MatchUser user) async {
    await SmartMatchingManager.addIntentionScore(10);
    await SmartMatchingManager.evaluateReadiness();

    if (user.privacyLevel == 'open') {
      await SmartMatchingManager.createDirectMatch(user.uid);
      // Apna popup local trigger — stream bhi aayega but guard hai
      final myUid = FirebaseAuth.instance.currentUser?.uid;
      if (myUid != null) {
        final matchId = ([myUid, user.uid]..sort()).join('_');
        // Thoda wait karo Firestore write complete ho
        await Future.delayed(const Duration(milliseconds: 500));
        final matchDoc = await FirebaseFirestore.instance
            .collection('active_matches')
            .doc(matchId)
            .get();
        if (matchDoc.exists && !_handledMatchIds.contains(matchId)) {
          _handledMatchIds.add(matchId);
          await _handleMatchDoc(matchDoc);
        }
      }
    } else if (user.privacyLevel == 'semi') {
      await SmartMatchingManager.sendConnectRequest(user.uid);
      _showSnack('📨 Request sent to ${user.name}');
    }
  }

  // FIX: Skip actually kaam karta hai ab
  Future<void> _onSkip(MatchUser user) async {
    await SmartMatchingManager.skipUser(user.uid);
    _showSnack('Skipped ${user.name}');
  }

  // FIX: Follow toggle properly kaam karta hai with local state update
  Future<void> _onFollowToggle(MatchUser user) async {
    final currentlyFollowing =
        _followingMap[user.uid] ?? await SmartMatchingManager.isFollowing(user.uid);
    await SmartMatchingManager.toggleFollow(user.uid, !currentlyFollowing);
    await SmartMatchingManager.addIntentionScore(2);
    await SmartMatchingManager.evaluateReadiness();

    if (mounted) {
      setState(() {
        _followingMap[user.uid] = !currentlyFollowing;
      });
      _showSnack(currentlyFollowing
          ? 'Unfollowed ${user.name}'
          : 'Following ${user.name} ✅');
    }
  }

  // FIX: Search filter properly apply hota hai
  List<MatchUser> _applyFilters(List<MatchUser> matches) {
    return matches.where((u) {
      // Skipped users hide karo
      if (_skippedUids.contains(u.uid)) return false;

      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatch = u.name.toLowerCase().contains(q);
        final cityMatch = u.city.toLowerCase().contains(q);
        if (!nameMatch && !cityMatch) return false;
      }

      // Quick filter: all | now | recent
      if (_quickFilter == 'now' && u.activeStatus != 'now') return false;
      if (_quickFilter == 'recent' &&
          u.activeStatus != 'now' &&
          u.activeStatus != 'recent') return false;

      return true;
    }).toList();
  }

  Future<void> _refresh() async {
    await SmartMatchingManager.sendHeartbeat();
    await Future.delayed(const Duration(milliseconds: 400));
  }

  void _showPrivacySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PrivacySheet(
        current: _privacyLevel,
        onSelected: (level) async {
          setState(() => _privacyLevel = level);
          await SmartMatchingManager.setPrivacy(level);
          Navigator.pop(context);
        },
      ),
    );
  }

  Color get _privacyColor {
    switch (_privacyLevel) {
      case 'open':
        return Colors.green;
      case 'semi':
        return Colors.amber;
      case 'private':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  IconData get _privacyIcon {
    switch (_privacyLevel) {
      case 'open':
        return Icons.lock_open_rounded;
      case 'semi':
        return Icons.lock_clock_outlined;
      case 'private':
        return Icons.lock_rounded;
      default:
        return Icons.lock_open_rounded;
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: kPurple,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // Status bar color
          Container(
              color: kPurple, height: MediaQuery.of(context).padding.top),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Matches',
                          style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : Colors.black)),
                      const SizedBox(height: 4),
                      Text(
                          'People who liked you & your matches.',
                          style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white70
                                  : Colors.black54,
                              height: 1.4)),
                    ],
                  ),
                ),
                // Privacy button
                GestureDetector(
                  onTap: _showPrivacySheet,
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _privacyColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                      border:
                      Border.all(color: _privacyColor, width: 2),
                    ),
                    child: Center(
                      child: Icon(_privacyIcon,
                          color: _privacyColor, size: 18),
                    ),
                  ),
                ),
                // Requests button
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MatchRequestsScreen()),
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border:
                          Border.all(color: kPurple, width: 2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Icon(
                              Icons.notifications_outlined,
                              color: kPurple,
                              size: 20),
                        ),
                      ),
                      if (_requestCount > 0)
                        Positioned(
                          top: -4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '$_requestCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Filter button
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const AdvancedFilterScreen()),
                  ),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        border: Border.all(color: kPurple, width: 2),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Center(
                        child: Text('1L',
                            style: TextStyle(
                                color: kPurple,
                                fontWeight: FontWeight.bold,
                                fontSize: 16))),
                  ),
                ),
              ],
            ),
          ),

          // ── FIX: Search Bar — ab actual kaam karta hai ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim()),
              style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name or city...',
                hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 14),
                prefixIcon:
                const Icon(Icons.search, color: kPurple, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? GestureDetector(
                  onTap: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: const Icon(Icons.close,
                      color: Colors.grey, size: 18),
                )
                    : null,
                filled: true,
                fillColor: isDark
                    ? Colors.white10
                    : kPurple.withOpacity(0.06),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide:
                    const BorderSide(color: kPurple, width: 1.5)),
              ),
            ),
          ),

          // ── FIX: Quick Filter Chips — ab actual filter karte hain ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: '🌐 All',
                    isSelected: _quickFilter == 'all',
                    onTap: () =>
                        setState(() => _quickFilter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '🟢 Online Now',
                    isSelected: _quickFilter == 'now',
                    onTap: () =>
                        setState(() => _quickFilter = 'now'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: '🕐 Recently Active',
                    isSelected: _quickFilter == 'recent',
                    onTap: () =>
                        setState(() => _quickFilter = 'recent'),
                  ),
                ],
              ),
            ),
          ),

          // ── Grace period banner ──
          if (!_graceCompleted)
            Container(
              margin:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: kPurple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kPurple),
                  ),
                  const SizedBox(width: 8),
                  const Text('Detecting your presence...',
                      style:
                      TextStyle(fontSize: 12, color: kPurple)),
                ],
              ),
            ),

          // ── Match Grid ──
          Expanded(
            child: RefreshIndicator(
              color: kPurple,
              onRefresh: _refresh,
              child: StreamBuilder<List<MatchUser>>(
                stream: SmartMatchingManager.matchesStream(),
                builder: (context, snap) {
                  if (snap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: kPurple));
                  }

                  final rawMatches = snap.data ?? [];
                  // FIX: Filters apply karo
                  final matches = _applyFilters(rawMatches);

                  if (matches.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_border,
                              size: 52,
                              color: kPurple.withOpacity(0.3)),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No results for "$_searchQuery"'
                                : 'Looking for matches...',
                            style: const TextStyle(
                                fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(8),
                    physics:
                    const AlwaysScrollableScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.78),
                    itemCount: matches.length,
                    itemBuilder: (context, index) {
                      final user = matches[index];
                      // Local follow state se override
                      final isFollowing =
                          _followingMap[user.uid] ?? user.isFollowing;
                      final displayUser =
                      user.copyWith(isFollowing: isFollowing);

                      return _MatchCard(
                        user: displayUser,
                        // FIX: Skip ab actually kaam karta hai
                        onRemove: () => _onSkip(user),
                        onHeartTap: () => _onHeartTap(user),
                        onProfileTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  ProfileScreen(user: user)),
                        ),
                        // FIX: Follow properly toggle hota hai
                        onFollow: () => _onFollowToggle(user),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  FILTER CHIP WIDGET  (NEW)
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? kPurple : kPurple.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? kPurple : kPurple.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight:
            isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : kPurple,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PRIVACY BOTTOM SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _PrivacySheet extends StatelessWidget {
  final String current;
  final void Function(String) onSelected;
  const _PrivacySheet({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final options = [
      {
        'level': 'open',
        'label': 'Open',
        'desc': 'Anyone can connect with you directly, no approval needed',
        'color': Colors.green,
        'icon': Icons.lock_open_rounded,
      },
      {
        'level': 'semi',
        'label': 'Semi',
        'desc': 'People send requests first, you choose who to accept',
        'color': Colors.amber,
        'icon': Icons.lock_clock_outlined,
      },
      {
        'level': 'private',
        'label': 'Private',
        'desc': 'You reach out to others, no one can contact you',
        'color': Colors.red,
        'icon': Icons.lock_rounded,
      },
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Privacy Level',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black)),
          const SizedBox(height: 16),
          ...options.map((o) {
            final isSelected = current == o['level'];
            final color = o['color'] as Color;
            final icon = o['icon'] as IconData;
            return GestureDetector(
              onTap: () => onSelected(o['level'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.08)
                      : Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey[200]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                          child: Icon(icon, color: color, size: 22)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(o['label'] as String,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isSelected
                                      ? color
                                      : Colors.black)),
                          const SizedBox(height: 3),
                          Text(o['desc'] as String,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle,
                          color: color, size: 22),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MATCH CARD
// ─────────────────────────────────────────────────────────────────────────────
class _MatchCard extends StatelessWidget {
  final MatchUser user;
  final VoidCallback onRemove;
  final VoidCallback onHeartTap;
  final VoidCallback onProfileTap;
  final VoidCallback? onFollow;

  const _MatchCard({
    required this.user,
    required this.onRemove,
    required this.onHeartTap,
    required this.onProfileTap,
    this.onFollow,
  });

  Color get _statusColor {
    switch (user.activeStatus) {
      case 'now':
        return Colors.green;
      case 'recent':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String get _statusLabel {
    switch (user.activeStatus) {
      case 'now':
        return 'Online';
      case 'recent':
        return '2 min ago';
      default:
        return 'Away';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onProfileTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Profile image
            user.imageUrl.isNotEmpty
                ? Image.network(
                user.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) =>
                progress == null
                    ? child
                    : Container(
                    color: Colors.grey[300],
                    child: const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2))),
                errorBuilder: (e, s, w) => Container(
                    color: Colors.grey[400],
                    child: const Icon(Icons.person,
                        size: 60, color: Colors.white)))
                : Container(
                color: Colors.grey[400],
                child: const Icon(Icons.person,
                    size: 60, color: Colors.white)),

            // Bottom gradient
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 110,
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.75)
                        ])),
              ),
            ),

            // Status badge
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle,
                        size: 6, color: Colors.white),
                    const SizedBox(width: 3),
                    Text(_statusLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

            // Name & age
            Positioned(
              left: 10,
              bottom: 48,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${user.name}, ${user.age}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          shadows: [
                            Shadow(
                                blurRadius: 4,
                                color: Colors.black45)
                          ])),
                  // FIX: city ab show hoti hai agar available ho
                  if (user.city.isNotEmpty)
                    Text(
                      '📍 ${user.city}',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          shadows: [
                            Shadow(
                                blurRadius: 3,
                                color: Colors.black38)
                          ]),
                    ),
                ],
              ),
            ),

            // Liked badge
            if (user.hasLiked)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2))
                        ]),
                    child: const Icon(Icons.favorite,
                        color: Colors.redAccent, size: 20)),
              ),

            // Action buttons row
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: Colors.black.withOpacity(0.35),
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // FIX: Skip kaam karta hai ab
                    GestureDetector(
                      onTap: onRemove,
                      child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 18)),
                    ),
                    Container(
                        width: 1,
                        height: 24,
                        color: Colors.white24),
                    // Heart / connect
                    GestureDetector(
                      onTap: onHeartTap,
                      child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle),
                          child: Icon(
                              user.privacyLevel == 'semi'
                                  ? Icons.person_add_alt_1
                                  : Icons.favorite_border,
                              color: Colors.white,
                              size: 18)),
                    ),
                    Container(
                        width: 1,
                        height: 24,
                        color: Colors.white24),
                    // FIX: Follow toggle properly reflected
                    GestureDetector(
                      onTap: onFollow,
                      child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: user.isFollowing
                                  ? kPurple.withOpacity(0.6)
                                  : Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle),
                          child: Icon(
                              user.isFollowing
                                  ? Icons.person_add
                                  : Icons.person_add,
                              color: Colors.white,
                              size: 18)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  PROFILE SCREEN  — FIX: bio/city real data se aata hai ab
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  final MatchUser user;
  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color primaryPurple = Color(0xFF6C3FEB);
  bool _isFollowing = false;
  bool _loadingFollow = false;

  @override
  void initState() {
    super.initState();
    _checkFollowing();
  }

  Future<void> _checkFollowing() async {
    final following =
    await SmartMatchingManager.isFollowing(widget.user.uid);
    if (mounted) setState(() => _isFollowing = following);
  }

  Future<void> _toggleFollow() async {
    if (_loadingFollow) return;
    setState(() => _loadingFollow = true);
    await SmartMatchingManager.toggleFollow(
        widget.user.uid, !_isFollowing);
    await SmartMatchingManager.addIntentionScore(2);
    if (mounted) {
      setState(() {
        _isFollowing = !_isFollowing;
        _loadingFollow = false;
      });
    }
  }

  // Report sheet
  void _showReportSheet() {
    final reasons = [
      'Fake profile',
      'Inappropriate content',
      'Harassment',
      'Spam',
      'Other',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Report User',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            const SizedBox(height: 16),
            ...reasons.map((r) => ListTile(
              title: Text(r),
              onTap: () async {
                await SmartMatchingManager.reportUser(
                    widget.user.uid, r);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Report submitted. Thank you.'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
            )),
          ],
        ),
      ),
    );
  }

  // Block confirm dialog
  void _showBlockDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Block User'),
        content: Text(
            'Are you sure you want to block ${widget.user.name}? They won\'t be able to contact you.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await SmartMatchingManager.blockUser(widget.user.uid);
              if (!mounted) return;
              Navigator.pop(context);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${widget.user.name} blocked.'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Block',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            pinned: true,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back_ios,
                  color: Colors.black),
            ),
            title: Text(user.name,
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18)),
            centerTitle: true,
            // FIX: More menu ab kaam karta hai (report/block)
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.black),
                onSelected: (val) {
                  if (val == 'report') _showReportSheet();
                  if (val == 'block') _showBlockDialog();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'report', child: Text('Report')),
                  const PopupMenuItem(
                      value: 'block',
                      child: Text('Block',
                          style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Avatar
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                        width: 110,
                        height: 110,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [
                              Color(0xFF6C3FEB),
                              Color(0xFFFF6B9D)
                            ]))),
                    Container(
                        width: 104,
                        height: 104,
                        decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white)),
                    ClipOval(
                        child: user.imageUrl.isNotEmpty
                            ? Image.network(user.imageUrl,
                            width: 98,
                            height: 98,
                            fit: BoxFit.cover)
                            : Container(
                            width: 98,
                            height: 98,
                            color: Colors.grey[300],
                            child: const Icon(Icons.person,
                                size: 50))),
                    Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                                color: user.activeStatus == 'now'
                                    ? Colors.green
                                    : user.activeStatus == 'recent'
                                    ? Colors.amber
                                    : Colors.grey,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: Colors.white, width: 2)))),
                  ],
                ),
                const SizedBox(height: 16),
                Text(user.name,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black)),
                const SizedBox(height: 4),
                // FIX: city real data se
                if (user.city.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '📍 ${user.city}',
                      style: const TextStyle(
                          fontSize: 13, color: Colors.grey),
                    ),
                  ),
                Text(
                    '@${user.name.toLowerCase().replaceAll(' ', '_')}',
                    style: const TextStyle(
                        fontSize: 14, color: primaryPurple)),
                const SizedBox(height: 12),
                // FIX: Bio real data se — hardcoded nahi
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                      user.bio.isNotEmpty
                          ? user.bio
                          : 'No bio yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5)),
                ),
                const SizedBox(height: 20),
                // Follow + Message buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                            onPressed:
                            _loadingFollow ? null : _toggleFollow,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing
                                    ? Colors.grey[300]
                                    : primaryPurple,
                                foregroundColor: _isFollowing
                                    ? Colors.black
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(30)),
                                elevation: 0),
                            child: _loadingFollow
                                ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                                : Text(
                                _isFollowing
                                    ? 'Following ✓'
                                    : 'Follow',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                    FontWeight.w600))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                            onPressed: () {
                              SmartMatchingManager.addIntentionScore(2);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatScreen(
                                    username: user.name,
                                    avatarUrl: user.imageUrl,
                                    lastMessage: 'Start a conversation...',
                                    receiverUid: user.uid, // ✅
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                                foregroundColor: primaryPurple,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14),
                                side: const BorderSide(
                                    color: primaryPurple),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(30))),
                            child: const Text('Message',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                    FontWeight.w600))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Video + Voice call buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VideoCallScreen(
                                remoteUserId: user.uid,
                                remoteUserName: user.name,
                                remoteUserImage: user.imageUrl,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.video_call),
                          label: const Text('Video'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: primaryPurple,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(30))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => VoiceCallScreen(
                                remoteUserId: user.uid,
                                remoteUserName: user.name,
                                remoteUserImage: user.imageUrl,
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.call),
                          label: const Text('Voice'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(30))),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}