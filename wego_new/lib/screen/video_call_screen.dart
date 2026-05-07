import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:wego_marriage/services/webrtc_service.dart';
import 'app_localizations.dart';
import 'app_translations.dart';
class VideoCallScreen extends StatefulWidget {
  final String remoteUserId;
  final String remoteUserName;
  final String remoteUserImage;
  final String? roomId;

  const VideoCallScreen({
    super.key,
    required this.remoteUserId,
    required this.remoteUserName,
    required this.remoteUserImage,
    this.roomId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final WebRTCService _webrtc = WebRTCService();
  final String _localUserId = FirebaseAuth.instance.currentUser!.uid;

  bool _micOn = true;
  bool _cameraOn = true;
  bool _isConnecting = true;
  bool _remoteJoined = false;
  bool _isEndingCall = false; // ✅ Double end call rokne ke liye
  String _roomId = '';

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
    _startCall();
  }

  void _setupCallbacks() {
    _webrtc.onUserJoined = (userId) {
      if (mounted) setState(() => _remoteJoined = true);
    };

    _webrtc.onUserLeft = (userId) {
      if (mounted) {
        setState(() => _remoteJoined = false);
        _endCall();
      }
    };

    _webrtc.onRemoteStreamAdded = (userId, stream) {
      if (mounted) setState(() => _isConnecting = false);
    };
  }

  String _buildRoomId() {
    if (widget.roomId != null && widget.roomId!.isNotEmpty) {
      return widget.roomId!;
    }
    final ids = [_localUserId, widget.remoteUserId]..sort();
    return '${ids[0]}_${ids[1]}_video';
  }

  Future<void> _startCall() async {
    _roomId = _buildRoomId();

    // Sirf caller naya doc banaye, receiver nahi
    final doc = await FirebaseFirestore.instance
        .collection('calls')
        .doc(_roomId)
        .get();

    if (!doc.exists) {
      await FirebaseFirestore.instance
          .collection('calls')
          .doc(_roomId)
          .set({
        'callerId': _localUserId,
        'receiverId': widget.remoteUserId,
        'type': 'video',
        'status': 'ringing',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await _webrtc.initLocalStream(video: true, audio: true);
    if (mounted) setState(() {});

    // ✅ callId pass karo — leaveRoom mein delete hoga
    await _webrtc.createOrJoinRoom(
      _roomId,
      _localUserId,
      callId: _roomId, // ✅ YEH NEW HAI
    );
  }

  Future<void> _endCall() async {
    if (_isEndingCall) return; // ✅ Double call rokna
    setState(() => _isEndingCall = true);

    // ✅ leaveRoom ke andar call doc delete hoga automatically
    await _webrtc.leaveRoom();

    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    if (!_isEndingCall) {
      _webrtc.leaveRoom(); // ✅ Dispose mein bhi cleanup
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Remote Video (Full Screen) ──
          Positioned.fill(
            child: RTCVideoView(
              _webrtc.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),

          // ── Connecting Overlay ──
          if (_isConnecting)
            Positioned.fill(
              child: Container(
                color: Colors.black87,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: NetworkImage(widget.remoteUserImage),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.remoteUserName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Connecting...',
                      style: TextStyle(color: Colors.white60, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(color: Colors.white),
                  ],
                ),
              ),
            ),

          // ── Local Video (Picture-in-Picture) ──
          Positioned(
            top: 50,
            right: 16,
            width: 100,
            height: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: RTCVideoView(
                _webrtc.localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ),

          // ── Top Bar ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.videocam, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.remoteUserName,
                      style:
                      const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const Spacer(),
                    if (_remoteJoined)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, color: Colors.green, size: 8),
                            SizedBox(width: 4),
                            Text('Connected',
                                style: TextStyle(
                                    color: Colors.green, fontSize: 12)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom Controls ──
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallButton(
                  icon: _micOn ? Icons.mic : Icons.mic_off,
                  color: _micOn ? Colors.white24 : Colors.red,
                  onTap: () {
                    _webrtc.toggleMic();
                    setState(() => _micOn = !_micOn);
                  },
                ),
                _CallButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  size: 64,
                  onTap: _endCall,
                ),
                _CallButton(
                  icon: _cameraOn ? Icons.videocam : Icons.videocam_off,
                  color: _cameraOn ? Colors.white24 : Colors.red,
                  onTap: () {
                    _webrtc.toggleCamera();
                    setState(() => _cameraOn = !_cameraOn);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable Call Button ──
class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  const _CallButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }
}