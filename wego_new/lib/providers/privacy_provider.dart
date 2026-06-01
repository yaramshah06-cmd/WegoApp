import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class PrivacyProvider extends ChangeNotifier {
  // ── Local state (mirror of Firestore settings doc) ──────────────────────
  String lastSeenOpt = 'everyone';
  DateTime? customLastSeen;
  bool hideOnline = false;
  bool hideLastSeen = false;
  bool blueTick = false;
  String groupOpt = 'everyone';
  String bioOpt = 'everyone';
  List<String> visibleToUsers = [];

  // ⚠️ RTDB ka URL `firebase_options.dart` mein set nahi hai, isliye yahan
  // explicit `instanceFor(...)` use karte hain. Wahi URL har file mein use
  // hona chahiye warna presence read/write alag-alag instances pe ho jayega.
  static const String _rtdbUrl =
      'https://wego-talk-default-rtdb.firebaseio.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: _rtdbUrl,
  );

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSub;
  StreamSubscription<User?>? _authSub;

  PrivacyProvider() {
    _authSub = _auth.authStateChanges().listen((user) {
      _settingsSub?.cancel();
      _settingsSub = null;
      if (user != null) {
        // ✅ Sirf login par listener attach karo
        _attachSettingsListener(user.uid);
        // ✅ Auth ready ho gaya — presence ko abhi online mark karo.
        //    Yeh `main.dart` ke postFrameCallback race condition fix karta
        //    hai (us waqt currentUser abhi null hota tha).
        setOnlinePresence(true);
      }
      // ❌ Logout par KUCH NAHI karo — reset removed
      // Firestore mein data safe rahega, agli baar login par wapas aayega
    });
  }

  // ── Firestore real-time listener ────────────────────────────────────────
  void listenToPrivacySettings() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    _attachSettingsListener(uid);
  }

  void _attachSettingsListener(String uid) {
    _settingsSub?.cancel();
    _settingsSub = _firestore
        .collection('users')
        .doc(uid)
        .collection('privacy')
        .doc('settings')
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return; // Document nahi → defaults rahein, kuch change nahi
      final data = snap.data()!;
      lastSeenOpt = (data['lastSeenOpt'] as String?) ?? 'everyone';
      hideOnline = (data['hideOnline'] as bool?) ?? false;
      hideLastSeen = (data['hideLastSeen'] as bool?) ?? false;
      blueTick = (data['blueTick'] as bool?) ?? false;
      groupOpt = (data['groupOpt'] as String?) ?? 'everyone';
      bioOpt = (data['bioOpt'] as String?) ?? 'everyone';
      visibleToUsers = List<String>.from(data['visibleToUsers'] ?? const []);
      final ts = data['customLastSeen'];
      customLastSeen = ts is Timestamp ? ts.toDate() : null;
      notifyListeners();
    }, onError: (e) {
      debugPrint('PrivacyProvider settings listener error: $e');
    });
  }

  // ── Save to Firestore (merge) ───────────────────────────────────────────
  Future<void> saveSettings({
    required String lastSeenOpt,
    required DateTime? customLastSeen,
    required bool hideOnline,
    required bool hideLastSeen,
    required bool blueTick,
    required String groupOpt,
    required String bioOpt,
    required List<String> visibleToUsers,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('privacy')
        .doc('settings')
        .set({
      'lastSeenOpt': lastSeenOpt,
      'customLastSeen':
      customLastSeen != null ? Timestamp.fromDate(customLastSeen) : null,
      'hideOnline': hideOnline,
      'hideLastSeen': hideLastSeen,
      'blueTick': blueTick,
      'groupOpt': groupOpt,
      'bioOpt': bioOpt,
      'visibleToUsers': visibleToUsers,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Optimistic local sync
    this.lastSeenOpt = lastSeenOpt;
    this.customLastSeen = customLastSeen;
    this.hideOnline = hideOnline;
    this.hideLastSeen = hideLastSeen;
    this.blueTick = blueTick;
    this.groupOpt = groupOpt;
    this.bioOpt = bioOpt;
    this.visibleToUsers = visibleToUsers;
    notifyListeners();

    setOnlinePresence(true);
  }

  // ── RTDB presence write ─────────────────────────────────────────────────
  void setOnlinePresence(bool isOnline) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final ref = _rtdb.ref('presence/$uid');

    if (hideOnline || hideLastSeen) {
      ref.set({
        'online': false,
        'lastSeen': ServerValue.timestamp,
      });
      return;
    }

    ref.set({
      'online': isOnline,
      'lastSeen': ServerValue.timestamp,
    });
    if (isOnline) {
      ref.onDisconnect().set({
        'online': false,
        'lastSeen': ServerValue.timestamp,
      });
    }
  }

  // ── Live online status of another user ──────────────────────────────────
  // Sirf RTDB ka raw `online` flag — privacy check yahan NAHI hota.
  Stream<bool> watchOnlineStatus(String otherUserId, String viewerUserId) {
    if (otherUserId.isEmpty) return Stream.value(false);
    return _rtdb.ref('presence/$otherUserId').onValue.map((event) {
      final data = event.snapshot.value;
      if (data is! Map) return false;
      return data['online'] == true;
    });
  }

  // ── Privacy-gated LIVE online watcher ───────────────────────────────────
  // Yeh dono streams ko combine karta hai:
  //   1. Target user ki Firestore privacy doc (lastSeenOpt/hideOnline/etc.)
  //   2. RTDB presence/{uid}/online flag
  // Jaise hi user app close/logout/delete kare → RTDB onDisconnect fire hota
  // hai, online=false ho jata hai, aur ye stream turant `false` emit karta
  // hai — chat list / home feed ke dots usi sec gayab.
  Stream<bool> watchShouldShowOnline(
      String otherUserId, String viewerUserId) async* {
    if (otherUserId.isEmpty) {
      yield false;
      return;
    }

    // Privacy doc ka live stream.
    final privacyStream = _firestore
        .collection('users')
        .doc(otherUserId)
        .collection('privacy')
        .doc('settings')
        .snapshots();

    // Presence ka live stream.
    final presenceStream = _rtdb.ref('presence/$otherUserId').onValue;

    // Latest values cache karo aur jab bhi koi update aaye recompute karo.
    Map<String, dynamic>? privacyData;
    bool isOnline = false;
    bool? isContactCache;

    final controller = StreamController<bool>();

    Future<void> recompute() async {
      try {
        final hideLs = (privacyData?['hideLastSeen'] as bool?) ?? false;
        final hideOn = (privacyData?['hideOnline'] as bool?) ?? false;
        final opt = (privacyData?['lastSeenOpt'] as String?) ?? 'everyone';
        final visible =
            (privacyData?['visibleToUsers'] as List?) ?? const [];

        if (hideLs || hideOn) {
          controller.add(false);
          return;
        }
        if (opt == 'nobody' || opt == 'custom') {
          controller.add(false);
          return;
        }
        if (opt == 'contacts') {
          isContactCache ??= await _isContact(otherUserId, viewerUserId);
          if (isContactCache != true) {
            controller.add(false);
            return;
          }
        }
        if (visible.isNotEmpty && !visible.contains(viewerUserId)) {
          controller.add(false);
          return;
        }
        controller.add(isOnline);
      } catch (e) {
        controller.add(false);
      }
    }

    final privacySub = privacyStream.listen((snap) {
      privacyData = snap.exists ? snap.data() : null;
      recompute();
    }, onError: (_) {
      privacyData = null;
      recompute();
    });

    final presenceSub = presenceStream.listen((event) {
      final data = event.snapshot.value;
      isOnline = data is Map && data['online'] == true;
      recompute();
    }, onError: (_) {
      isOnline = false;
      recompute();
    });

    controller.onCancel = () async {
      await privacySub.cancel();
      await presenceSub.cancel();
    };

    yield* controller.stream;
  }

  // ── One-shot last seen text ─────────────────────────────────────────────
  Future<String> getLastSeenText(
      String otherUserId, String viewerUserId) async {
    if (otherUserId.isEmpty) return '';
    try {
      final snap = await _firestore
          .collection('users')
          .doc(otherUserId)
          .collection('privacy')
          .doc('settings')
          .get();

      String opt = 'everyone';
      bool hideLs = false;
      List<dynamic> visible = const [];
      Timestamp? custTs;
      if (snap.exists) {
        final data = snap.data()!;
        opt = (data['lastSeenOpt'] as String?) ?? 'everyone';
        hideLs = (data['hideLastSeen'] as bool?) ?? false;
        visible = (data['visibleToUsers'] as List?) ?? const [];
        custTs = data['customLastSeen'] is Timestamp
            ? data['customLastSeen'] as Timestamp
            : null;
      }

      if (hideLs) return '';
      if (opt == 'nobody') return '';
      if (opt == 'custom') {
        if (custTs == null) return '';
        return 'last seen ${_fmt(custTs.toDate())}';
      }
      if (opt == 'contacts') {
        final allowed = await _isContact(otherUserId, viewerUserId);
        if (!allowed) return '';
      }
      if (visible.isNotEmpty && !visible.contains(viewerUserId)) return '';

      final presSnap = await _rtdb.ref('presence/$otherUserId').get();
      final presData = presSnap.value;
      if (presData is! Map) return '';
      final lastSeenRaw = presData['lastSeen'];
      final ms = lastSeenRaw is int ? lastSeenRaw : null;
      if (ms == null) return '';
      return 'last seen ${_fmt(DateTime.fromMillisecondsSinceEpoch(ms))}';
    } catch (e) {
      debugPrint('getLastSeenText error: $e');
      return '';
    }
  }

  // ── One-shot: should green online dot be shown? ─────────────────────────
  Future<bool> shouldShowOnline(
      String otherUserId, String viewerUserId) async {
    if (otherUserId.isEmpty) return false;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(otherUserId)
          .collection('privacy')
          .doc('settings')
          .get();

      bool hideLs = false;
      bool hideOn = false;
      String opt = 'everyone';
      List<dynamic> visible = const [];
      if (snap.exists) {
        final data = snap.data()!;
        hideLs = (data['hideLastSeen'] as bool?) ?? false;
        hideOn = (data['hideOnline'] as bool?) ?? false;
        opt = (data['lastSeenOpt'] as String?) ?? 'everyone';
        visible = (data['visibleToUsers'] as List?) ?? const [];
      }

      if (hideLs || hideOn) return false;
      if (opt == 'nobody' || opt == 'custom') return false;
      if (opt == 'contacts') {
        final allowed = await _isContact(otherUserId, viewerUserId);
        if (!allowed) return false;
      }
      if (visible.isNotEmpty && !visible.contains(viewerUserId)) return false;

      final presSnap = await _rtdb.ref('presence/$otherUserId').get();
      final presData = presSnap.value;
      if (presData is! Map) return false;
      return presData['online'] == true;
    } catch (e) {
      debugPrint('shouldShowOnline error: $e');
      return false;
    }
  }

  // ── Group invite gate ───────────────────────────────────────────────────
  Future<bool> canInviteToGroup(
      String inviterUserId, String targetUserId) async {
    if (targetUserId.isEmpty) return false;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(targetUserId)
          .collection('privacy')
          .doc('settings')
          .get();
      String opt = 'everyone';
      if (snap.exists) {
        opt = (snap.data()!['groupOpt'] as String?) ?? 'everyone';
      }
      if (opt == 'nobody') return false;
      if (opt == 'contacts') {
        return _isContact(targetUserId, inviterUserId);
      }
      return true;
    } catch (e) {
      debugPrint('canInviteToGroup error: $e');
      return false;
    }
  }

  // ── Blue tick ───────────────────────────────────────────────────────────
  Future<bool> showBlueTickFor(String otherUserId) async {
    if (otherUserId.isEmpty) return true;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(otherUserId)
          .collection('privacy')
          .doc('settings')
          .get();
      if (!snap.exists) return true;
      final disabled = (snap.data()!['blueTick'] as bool?) ?? false;
      return !disabled;
    } catch (_) {
      return true;
    }
  }

  // ── Bio visibility check ────────────────────────────────────────────────
  Future<bool> canShowBio(String otherUserId, String viewerUserId) async {
    if (otherUserId.isEmpty) return false;
    if (otherUserId == viewerUserId) return true;
    try {
      final snap = await _firestore
          .collection('users')
          .doc(otherUserId)
          .collection('privacy')
          .doc('settings')
          .get();
      String opt = 'everyone';
      if (snap.exists) {
        opt = (snap.data()!['bioOpt'] as String?) ?? 'everyone';
      }
      if (opt == 'nobody') return false;
      if (opt == 'contacts') {
        return _isContact(otherUserId, viewerUserId);
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  // ── Helper: is viewer a contact of target? ──────────────────────────────
  Future<bool> _isContact(String targetUid, String viewerUid) async {
    if (viewerUid.isEmpty || targetUid.isEmpty) return false;
    try {
      final doc = await _firestore
          .collection('users')
          .doc(targetUid)
          .collection('followers')
          .doc(viewerUid)
          .get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // ── Pretty date format ──────────────────────────────────────────────────
  String _fmt(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day}, $h:$m $ampm';
  }

  @override
  void dispose() {
    _settingsSub?.cancel();
    _authSub?.cancel();
    super.dispose();
  }
}