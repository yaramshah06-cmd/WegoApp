import 'package:firebase_auth/firebase_auth.dart';
import 'package:wego_marriage/screen/video_call_screen.dart';
import 'package:wego_marriage/screen/voice_call_screen.dart';
import 'webrtc_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/settings_provider.dart';
import 'app_localizations.dart';
import 'app_translations.dart';
const Color kPurple = Color(0xFF6B4EFF);
const Color kRed = Color(0xFFE8405A);

class CallingScreen extends StatefulWidget {
  final String callId;
  final String receiverId;
  final String receiverName;
  final String receiverImage;
  final String callType;

  const CallingScreen({
    super.key,
    required this.callId,
    required this.receiverId,
    required this.receiverName,
    required this.receiverImage,
    required this.callType,
  });

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen>
    with TickerProviderStateMixin {

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late Timer _dotsTimer;
  int _dotCount = 0;
  bool _isMuted = false;
  bool _isVideoOff = false;
  Timer? _vibrationTimer;
  Timer? _callTimeoutTimer;
  bool _callAccepted = false;
  bool _isNavigating = false;
  StreamSubscription? _callStatusSubscription;

  String get _myUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? '';

  // ✅ callType ke hisaab se sahi roomId banao
  String get _roomId {
    final ids = [_myUserId, widget.receiverId]..sort();
    if (widget.callType == 'video') {
      return '${ids[0]}_${ids[1]}_video';
    } else {
      return '${ids[0]}_${ids[1]}_voice';
    }
  }

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _dotsTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (mounted) {
        setState(() => _dotCount = (_dotCount + 1) % 9);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsProvider>();
      if (settings.vibrate) {
        _vibrationTimer = Timer.periodic(const Duration(seconds: 2), (_) {
          HapticFeedback.heavyImpact();
        });
      }
    });

    _createCallInFirestore();
    _listenForCallStatus();
    _startCallTimeout();
  }

  Future<void> _createCallInFirestore() async {
    try {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.callId)
          .set({
        'callId': widget.callId,
        'callerId': _myUserId,
        'receiverId': widget.receiverId,
        'receiverName': widget.receiverName,
        'receiverImage': widget.receiverImage,
        'status': 'ringing',
        'callType': widget.callType,
        'type': widget.callType,
        'roomId': _roomId, // ✅ Sahi roomId bhi save karo
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ Call created: ${widget.callId} | roomId: $_roomId');
    } catch (e) {
      print('❌ Call create error: $e');
    }
  }

  void _listenForCallStatus() {
    _callStatusSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((snapshot) async {

      if (!mounted) return;

      if (!snapshot.exists) {
        print('📵 Call document delete ho gaya');
        if (!_callAccepted) _endCallCleanup();
        return;
      }

      final data = snapshot.data()!;
      final status = data['status'] as String? ?? '';

      print('📞 Call status: $status');

      if (status == 'accepted' && !_callAccepted && !_isNavigating) {
        setState(() {
          _callAccepted = true;
          _isNavigating = true;
        });
        _callTimeoutTimer?.cancel();
        _navigateToCallScreen();

      } else if (status == 'declined') {
        print('📵 Call decline ho gayi');
        try {
          await FirebaseFirestore.instance
              .collection('calls')
              .doc(widget.callId)
              .delete();
          print('🗑️ Declined call deleted');
        } catch (e) {
          print('❌ Delete error: $e');
        }
        _endCallCleanup();

      } else if (status == 'ended') {
        print('📵 Call khatam');
        try {
          await FirebaseFirestore.instance
              .collection('calls')
              .doc(widget.callId)
              .delete();
          print('🗑️ Ended call deleted');
        } catch (e) {
          print('❌ Delete error: $e');
        }
        _endCallCleanup();
      }
    });
  }

  void _navigateToCallScreen() {
    if (!mounted) return;

    _callStatusSubscription?.cancel();
    _vibrationTimer?.cancel();

    print('🚀 Navigate to ${widget.callType} call | roomId: $_roomId');

    // ✅ _roomId mein ab sahi _voice ya _video suffix hai
    final route = MaterialPageRoute(
      builder: (_) => widget.callType == 'video'
          ? VideoCallScreen(
        remoteUserId: widget.receiverId,
        remoteUserName: widget.receiverName,
        remoteUserImage: widget.receiverImage,
        roomId: _roomId, // ✅ _video wala roomId
      )
          : VoiceCallScreen(
        remoteUserId: widget.receiverId,
        remoteUserName: widget.receiverName,
        remoteUserImage: widget.receiverImage,
        roomId: _roomId, // ✅ _voice wala roomId
      ),
    );

    Navigator.of(context).pushReplacement(route);
  }

  void _startCallTimeout() {
    _callTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (!_callAccepted && mounted) {
        print('⏰ Call timeout');
        _endCall();
      }
    });
  }

  Future<void> _endCall() async {
    if (!mounted) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.callId)
          .get();

      if (doc.exists) {
        await FirebaseFirestore.instance
            .collection('calls')
            .doc(widget.callId)
            .update({'status': 'cancelled'});

        await Future.delayed(const Duration(seconds: 1));

        await FirebaseFirestore.instance
            .collection('calls')
            .doc(widget.callId)
            .delete();
      }

      print('🗑️ Call document deleted');
    } catch (e) {
      print('❌ Delete error: $e');
    }

    _endCallCleanup();
  }

  void _endCallCleanup() {
    _callStatusSubscription?.cancel();
    _callTimeoutTimer?.cancel();
    _vibrationTimer?.cancel();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _dotsTimer.cancel();
    _vibrationTimer?.cancel();
    _callStatusSubscription?.cancel();
    _callTimeoutTimer?.cancel();
    super.dispose();
  }

  String get _dotsText => '.' * (_dotCount + 1);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: kPurple,
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            Container(
              color: kPurple,
              height: MediaQuery.of(context).padding.top,
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  _buildPulsingAvatar(),
                  const SizedBox(height: 20),
                  Text(
                    widget.receiverName,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'CALLING$_dotsText',
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 3,
                    ),
                  ),
                  const Spacer(flex: 3),
                  _buildActionBar(isDark),
                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingAvatar() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Transform.scale(scale: _pulseAnim.value, child: child);
      },
      child: Container(
        width: 150,
        height: 150,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B6B), kPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: kPurple.withValues(alpha: 0.4),
              blurRadius: 24,
              spreadRadius: 4,
            ),
          ],
        ),
        padding: const EdgeInsets.all(4),
        child: ClipOval(
          child: widget.receiverImage.isNotEmpty
              ? Image.network(
            widget.receiverImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[800],
              child: const Icon(Icons.person,
                  color: Colors.white54, size: 60),
            ),
          )
              : Container(
            color: Colors.grey[800],
            child: const Icon(Icons.person,
                color: Colors.white54, size: 60),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => setState(() => _isMuted = !_isMuted),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _isMuted
                      ? (isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.1))
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMuted ? Icons.mic_off : Icons.mic,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 26,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _isVideoOff = !_isVideoOff),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _isVideoOff
                      ? (isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.1))
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isVideoOff
                      ? Icons.videocam_off_outlined
                      : Icons.videocam_outlined,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 26,
                ),
              ),
            ),
            GestureDetector(
              onTap: _endCall,
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: kRed,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x55E8405A),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.call_end,
                    color: Colors.white, size: 26),
              ),
            ),
          ],
        ),
      ),
    );
  }
}