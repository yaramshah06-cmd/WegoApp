import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:wego_marriage/services/local_storage_service.dart';
import 'package:wego_marriage/services/notification_service.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FollowController — App-wide singleton jo "kya main targetUid ko follow
//  karta hoon" state ko process-wide share karta hai.
//
//  Pehle home_feed_screen mein local static _followBus tha — har screen
//  apna alag bus banata. Result: home feed pe follow karne ke baad user
//  profile, comments, notifications screens stale rehte the. Yeh service
//  ek hi notifier per-uid expose karti hai jise sab screens listen karein
//  taake follow/unfollow ek hi click se sab jagah reflect ho.
//
//  Source of truth: users/{me}/following/{targetUid} (existence = following).
//  Mirror: users/{targetUid}/followers/{me} — dono parallel writes.
//
//  Usage:
//    final ctrl = FollowController.instance;
//    ctrl.watch(targetUid);                  // ensure live status loaded
//    ValueListenableBuilder<bool>(
//      valueListenable: ctrl.notifier(targetUid),
//      builder: (_, isFollowing, __) => ...,
//    );
//    await ctrl.toggle(targetUid);           // optimistic + Firestore
// ════════════════════════════════════════════════════════════════════════════

class FollowController {
  FollowController._();
  static final FollowController instance = FollowController._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalStorageService _storage = LocalStorageService();

  // Per-uid notifier. Sab screens isi notifier pe rebuild hote hain.
  final Map<String, ValueNotifier<bool>> _bus = {};
  // "Pehla Firestore snapshot aa gaya kya?" — UI ko batane ke liye taake
  // "Follow back" jaisa label tab tak na dikhe jab tak truth confirm na ho.
  // Warna A jab B ka notification kholega tou ek instant ke liye "Follow back"
  // flicker ho sakta hai (kyunki _followsMe pehle fetch ho jata hai).
  final Map<String, ValueNotifier<bool>> _loadedBus = {};
  // Firestore live subs — ek hi sub per target uid, multiple listeners.
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _subs = {};
  // Rapid tap guard per-uid (sirf latest toggle ki catch-branch UI touch kare).
  final Map<String, int> _opSeq = {};

  // ── Public API ────────────────────────────────────────────────────────────

  /// Get or create the shared notifier for [targetUid]. Stable identity.
  ValueNotifier<bool> notifier(String targetUid) {
    return _bus.putIfAbsent(targetUid, () => ValueNotifier<bool>(false));
  }

  /// `true` jab is uid ka pehla Firestore snapshot UI tak pohch chuka ho.
  /// Buttons isko gate karte hain taake "Follow back" / "Following" label
  /// initial frame pe gala na lage.
  ValueNotifier<bool> loadedNotifier(String targetUid) {
    return _loadedBus.putIfAbsent(targetUid, () => ValueNotifier<bool>(false));
  }

  /// Current cached value (no network).
  bool isFollowing(String targetUid) => notifier(targetUid).value;

  /// Start watching `users/{me}/following/{targetUid}` so the notifier stays
  /// truthful even if another device/screen toggles. Safe to call repeatedly.
  void watch(String targetUid) {
    if (targetUid.isEmpty) return;
    final me = _auth.currentUser?.uid;
    if (me == null) return;

    // Seed from local cache so UI feels instant before stream connects.
    final n = notifier(targetUid);
    if (!n.value) {
      n.value = _storage.isUserFollowed(targetUid);
    }

    // Already subscribed? skip.
    if (_subs.containsKey(targetUid)) return;

    _subs[targetUid] = _db
        .collection('users')
        .doc(me)
        .collection('following')
        .doc(targetUid)
        .snapshots()
        .listen((snap) {
      final truth = snap.exists;
      final n = notifier(targetUid);
      if (n.value != truth) {
        n.value = truth;
        // Local cache reconcile — silent.
        // ignore: discarded_futures
        _storage.toggleFollow(targetUid, truth);
      }
      final l = loadedNotifier(targetUid);
      if (!l.value) l.value = true;
    }, onError: (_) {});
  }

  /// Optimistic toggle + parallel Firestore writes. Returns the new state.
  /// Errors are swallowed but reconciled from Firestore truth.
  Future<bool> toggle(String targetUid) async {
    final me = _auth.currentUser?.uid;
    if (me == null || targetUid.isEmpty) return false;
    if (me == targetUid) return false; // can't follow self

    final mySeq = (_opSeq[targetUid] ?? 0) + 1;
    _opSeq[targetUid] = mySeq;

    final n = notifier(targetUid);
    final wasFollowing = n.value;
    n.value = !wasFollowing;
    // ignore: discarded_futures
    _storage.toggleFollow(targetUid, !wasFollowing);

    final myFollowingRef = _db
        .collection('users')
        .doc(me)
        .collection('following')
        .doc(targetUid);
    final targetFollowersRef = _db
        .collection('users')
        .doc(targetUid)
        .collection('followers')
        .doc(me);

    try {
      if (wasFollowing) {
        await Future.wait([
          myFollowingRef.delete(),
          targetFollowersRef.delete(),
        ]);
      } else {
        await Future.wait([
          myFollowingRef.set({
            'uid': targetUid,
            'followedAt': FieldValue.serverTimestamp(),
          }),
          targetFollowersRef.set({
            'uid': me,
            'followedAt': FieldValue.serverTimestamp(),
          }),
        ]);
        unawaited(NotificationService.notifyFollow(targetUid: targetUid));
      }
      return n.value;
    } catch (_) {
      // Stale op? skip rollback — latest op handles itself.
      if (_opSeq[targetUid] != mySeq) return n.value;
      // Truth from Firestore — half-success safe.
      try {
        final snap = await myFollowingRef.get();
        if (_opSeq[targetUid] != mySeq) return n.value;
        final truth = snap.exists;
        n.value = truth;
        // ignore: discarded_futures
        _storage.toggleFollow(targetUid, truth);
      } catch (_) {
        if (_opSeq[targetUid] == mySeq) {
          n.value = wasFollowing;
          // ignore: discarded_futures
          _storage.toggleFollow(targetUid, wasFollowing);
        }
      }
      return n.value;
    }
  }

  /// Does [otherUid] follow ME? One-shot read. Used to decide
  /// "Follow back" vs plain "Follow" label.
  Future<bool> doesFollowMe(String otherUid) async {
    final me = _auth.currentUser?.uid;
    if (me == null || otherUid.isEmpty || otherUid == me) return false;
    try {
      final snap = await _db
          .collection('users')
          .doc(otherUid)
          .collection('following')
          .doc(me)
          .get();
      return snap.exists;
    } catch (_) {
      return false;
    }
  }

  /// Live stream of "does [otherUid] follow me". For screens that want the
  /// label ("Follow back" vs "Follow") to update without reload.
  Stream<bool> followsMeStream(String otherUid) {
    final me = _auth.currentUser?.uid;
    if (me == null || otherUid.isEmpty || otherUid == me) {
      return Stream<bool>.value(false);
    }
    return _db
        .collection('users')
        .doc(otherUid)
        .collection('following')
        .doc(me)
        .snapshots()
        .map((s) => s.exists);
  }
}
