import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  static Stream<List<dynamic>> matchesStream() {
    if (_myUid == null) return Stream.value([]);
    return _db
        .collection('users')
        .where('is_ready_to_match', isEqualTo: true)
        .where('privacy_level', whereIn: ['open', 'semi'])
        .snapshots()
        .map((snap) => snap.docs
        .where((d) => d.id != _myUid)
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