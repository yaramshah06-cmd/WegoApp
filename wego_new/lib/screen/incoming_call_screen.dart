import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'video_call_screen.dart';
import 'voice_call_screen.dart';
import 'app_localizations.dart';
import 'app_translations.dart';
class IncomingCallScreen extends StatefulWidget {
  final String callId;
  final String callerId;
  final String callerName;
  final String callerImage;
  final String callType;

  const IncomingCallScreen({
    super.key,
    required this.callId,
    required this.callerId,
    required this.callerName,
    required this.callerImage,
    required this.callType,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final AnimationController _rippleCtrl;
  late final Animation<double> _pulseAnim;
  StreamSubscription? _callSub;
  bool _isProcessing = false;

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

    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _listenForCallStatus();
  }

  void _listenForCallStatus() {
    _callSub = FirebaseFirestore.instance
        .collection('calls')
        .doc(widget.callId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;

      // ✅ Document delete ho gaya — dismiss karo
      if (!snap.exists) {
        print('📵 Call document delete ho gaya');
        _dismiss();
        return;
      }

      final status = snap.data()?['status'] as String?;
      print('📞 Incoming screen status update: $status');

      if (status == 'ended' ||
          status == 'cancelled' ||
          status == 'declined' ||
          status == 'timeout') {
        _dismiss();
      }
    }, onError: (e) {
      print('💥 Call listener error: $e');
    });
  }

  void _dismiss() {
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _acceptCall() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    _callSub?.cancel();
    _callSub = null;

    try {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.callId)
          .update({'status': 'accepted'});

      print('✅ Call accepted: ${widget.callId}');
    } catch (e) {
      print('❌ Accept error: $e');
      setState(() => _isProcessing = false);
      return;
    }

    if (!mounted) return;

    final isVideo = widget.callType.toLowerCase() == 'video';
    print('📹 Call type: ${widget.callType} | isVideo: $isVideo');

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => isVideo
            ? VideoCallScreen(
          remoteUserId: widget.callerId,
          remoteUserName: widget.callerName,
          remoteUserImage: widget.callerImage,
          roomId: widget.callId,
        )
            : VoiceCallScreen(
          remoteUserId: widget.callerId,
          remoteUserName: widget.callerName,
          remoteUserImage: widget.callerImage,
          roomId: widget.callId,
        ),
      ),
    );
  }

  // ✅ FIXED — Decline pe document delete karo
  Future<void> _declineCall() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    _callSub?.cancel();
    _callSub = null;

    try {
      final callRef = FirebaseFirestore.instance
          .collection('calls')
          .doc(widget.callId);

      // Pehle declined mark karo — caller ko pata chale
      await callRef.update({'status': 'declined'});
      print('📵 Call declined: ${widget.callId}');

      // ✅ Thodi delay ke baad delete karo — dobara call aa sake
      await Future.delayed(const Duration(seconds: 1));
      await callRef.delete();
      print('🗑️ Call document deleted after decline');
    } catch (e) {
      print('❌ Decline error: $e');
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _pulseCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background gradient ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF8B1A4A),
                  Color(0xFF3D0B1F),
                  Color(0xFF1A0510),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),

          // ── Decorative circles ──
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.pinkAccent.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF8B1A4A).withOpacity(0.15),
              ),
            ),
          ),

          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── Call type label ──
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.callType.toLowerCase() == 'video'
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        color: Colors.white70,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.callType.toLowerCase() == 'video'
                            ? 'Incoming Video Call'
                            : 'Incoming Voice Call',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ── Ripple + Avatar ──
                SizedBox(
                  width: 220,
                  height: 220,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ...List.generate(3, (i) {
                        return AnimatedBuilder(
                          animation: _rippleCtrl,
                          builder: (_, __) {
                            final delay = i / 3.0;
                            final progress =
                            (((_rippleCtrl.value - delay) % 1.0 + 1.0) %
                                1.0);
                            final size = 130.0 + progress * 90.0;
                            final opacity = (1.0 - progress) * 0.35;
                            return Opacity(
                              opacity: opacity.clamp(0.0, 1.0),
                              child: Container(
                                width: size,
                                height: size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color:
                                    Colors.pinkAccent.withOpacity(0.6),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                      ScaleTransition(
                        scale: _pulseAnim,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B1A4A)
                                    .withOpacity(0.5),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: widget.callerImage.isNotEmpty
                                ? Image.network(
                              widget.callerImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildInitialAvatar(),
                            )
                                : _buildInitialAvatar(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Caller name ──
                Text(
                  widget.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 10),

                _AnimatedStatus(
                  label: widget.callType.toLowerCase() == 'video'
                      ? 'Incoming video call'
                      : 'Incoming voice call',
                ),

                const Spacer(flex: 3),

                // ── Accept / Decline buttons ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 60),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CallButton(
                        icon: Icons.call_end_rounded,
                        color: const Color(0xFFE53935),
                        label: 'Decline',
                        onTap: _isProcessing ? () {} : _declineCall,
                      ),
                      _CallButton(
                        icon: widget.callType.toLowerCase() == 'video'
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        color: const Color(0xFF43A047),
                        label: 'Accept',
                        onTap: _isProcessing ? () {} : _acceptCall,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialAvatar() {
    return Container(
      color: const Color(0xFF8B1A4A),
      child: Center(
        child: Text(
          widget.callerName.isNotEmpty
              ? widget.callerName[0].toUpperCase()
              : '?',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ── Animated dots status ──
class _AnimatedStatus extends StatefulWidget {
  final String label;
  const _AnimatedStatus({required this.label});

  @override
  State<_AnimatedStatus> createState() => _AnimatedStatusState();
}

class _AnimatedStatusState extends State<_AnimatedStatus> {
  int _dotCount = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount % 3) + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.label}${'.' * _dotCount}',
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 15,
        letterSpacing: 0.3,
      ),
    );
  }
}

// ── Call Button ──
class _CallButton extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  State<_CallButton> createState() => _CallButtonState();
}

class _CallButtonState extends State<_CallButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.08,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeIn),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.45),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 34),
            ),
            const SizedBox(height: 10),
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}