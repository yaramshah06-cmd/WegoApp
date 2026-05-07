import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wego_marriage/screen/video_call_screen.dart';
import 'package:wego_marriage/screen/match_screen.dart';
import 'package:wego_marriage/screen/smart_matching_manager.dart';
import 'app_translations.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL
// ─────────────────────────────────────────────────────────────────────────────
class MatchRequest {
  final String fromUid;
  final String fromName;
  final int fromAge;
  final String fromCity;
  final String fromImage;
  final DateTime timestamp;
  final String status;

  MatchRequest({
    required this.fromUid,
    required this.fromName,
    required this.fromAge,
    required this.fromCity,
    required this.fromImage,
    required this.timestamp,
    required this.status,
  });

  factory MatchRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return MatchRequest(
      fromUid: d['fromUid'] ?? doc.id,
      fromName: d['fromName'] ?? '',
      fromAge: (d['fromAge'] ?? 0) is int
          ? d['fromAge']
          : int.tryParse(d['fromAge'].toString()) ?? 0,
      fromCity: d['fromCity'] ?? '',
      fromImage: d['fromImage'] ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: d['status'] ?? 'pending',
    );
  }

  // timeAgo ab lang lega
  String timeAgo(String lang) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return AppTranslations.translate('just_now', lang);
    if (diff.inMinutes < 60) return '${diff.inMinutes} ${AppTranslations.translate('min_ago', lang)}';
    if (diff.inHours < 24) return '${diff.inHours} ${AppTranslations.translate('hours_ago_short', lang)}';
    return '${diff.inDays} ${AppTranslations.translate('days_ago', lang)}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MATCH REQUESTS SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class MatchRequestsScreen extends StatelessWidget {
  const MatchRequestsScreen({super.key});

  static const Color kPurple = Color(0xFF6C3FEB);

  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  Stream<List<MatchRequest>> _requestsStream() {
    if (_myUid == null) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_myUid)
        .collection('match_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => MatchRequest.fromFirestore(d)).toList());
  }

  Future<void> _accept(BuildContext context, MatchRequest req) async {
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .collection('match_requests')
        .doc(req.fromUid)
        .update({'status': 'accepted'});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .update({'request_count': FieldValue.increment(-1)});

    await FirebaseFirestore.instance
        .collection('pings')
        .doc('${req.fromUid}_$myUid')
        .update({'responded': true}).catchError((_) {});

    await SmartMatchingManager.createMatchFromRequest(req.fromUid);

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            remoteUserId: req.fromUid,
            remoteUserName: req.fromName,
            remoteUserImage: req.fromImage,
          ),
        ),
      );
    }
  }

  Future<void> _decline(BuildContext context, MatchRequest req) async {
    final String? myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    final lang = Localizations.localeOf(context).languageCode;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .collection('match_requests')
        .doc(req.fromUid)
        .update({'status': 'declined'});

    await FirebaseFirestore.instance
        .collection('users')
        .doc(myUid)
        .update({'request_count': FieldValue.increment(-1)});

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${req.fromName} ${AppTranslations.translate('request_declined', lang)}',
          ),
          backgroundColor: Colors.grey[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FB),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 20,
              left: 16,
              right: 16,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kPurple, Color(0xFF5A3AD1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28),
                bottomRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: kPurple.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppTranslations.translate('match_requests', lang),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AppTranslations.translate('accept_decline_msg', lang),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        AppTranslations.translate('live', lang),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Request List ─────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<MatchRequest>>(
              stream: _requestsStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: kPurple));
                }

                final requests = snap.data ?? [];

                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.notifications_none,
                            size: 64, color: kPurple.withOpacity(0.25)),
                        const SizedBox(height: 16),
                        Text(
                          AppTranslations.translate('no_requests_yet', lang),
                          style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF7A6FB0),
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          AppTranslations.translate('no_requests_desc', lang),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFB0A8D0)),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, i) => _RequestCard(
                    request: requests[i],
                    lang: lang,
                    onAccept: () => _accept(context, requests[i]),
                    onDecline: () => _decline(context, requests[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  REQUEST CARD
// ─────────────────────────────────────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final MatchRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final String lang;

  const _RequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
    required this.lang,
  });

  static const Color kPurple = Color(0xFF6C3FEB);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE8FC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: kPurple.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE0D8FF), width: 2),
            ),
            child: ClipOval(
              child: request.fromImage.isNotEmpty
                  ? Image.network(request.fromImage,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _avatarFallback())
                  : _avatarFallback(),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${request.fromName}, ${request.fromAge}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2D1F6E)),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: Color(0xFF9B8EC4)),
                    const SizedBox(width: 3),
                    Text(request.fromCity,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9B8EC4))),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 12, color: Color(0xFFB0A8D0)),
                    const SizedBox(width: 3),
                    Text(
                      request.timeAgo(lang),
                      style: const TextStyle(
                          fontSize: 11, color: Color(0xFFB0A8D0)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Buttons
          Column(
            children: [
              // ✅ Accept
              GestureDetector(
                onTap: onAccept,
                child: Container(
                  width: 42,
                  height: 42,
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 1.5),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.green, size: 20),
                ),
              ),
              // ❌ Decline
              GestureDetector(
                onTap: onDecline,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.red, width: 1.5),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.red, size: 20),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: const Color(0xFFF0EBFF),
      child: Center(
        child: Text(
          request.fromName.isNotEmpty
              ? request.fromName[0].toUpperCase()
              : '?',
          style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6C3FEB)),
        ),
      ),
    );
  }
}