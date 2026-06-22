import 'package:flutter/material.dart';

const Color kPurple = Color(0xFF7A1730);
const Color kTeal = Color(0xFF2EC4B6);

/// WhatsApp-style call log bubble.
/// isMine=true  → right, dark-green  ("Voice call / No answer")
/// isMine=false → left,  dark-grey   ("Missed voice call / Tap to call back")
class CallLogMessage extends StatelessWidget {
  final bool isVideoCall;
  final bool isMissedCall;
  final bool isIncomingCall;
  final bool isMine;
  final String username;
  final String avatarUrl;
  final String time;
  final Duration? duration;
  final VoidCallback? onCallback;

  const CallLogMessage({
    super.key,
    required this.isVideoCall,
    required this.isMissedCall,
    required this.isIncomingCall,
    required this.isMine,
    required this.username,
    required this.avatarUrl,
    required this.time,
    this.duration,
    this.onCallback,
  });

  @override
  Widget build(BuildContext context) {
    final bool showMissed = !isMine && isMissedCall;

    final IconData phoneIcon =
    isVideoCall ? Icons.videocam_rounded : Icons.call_rounded;

    // dark green for sent, dark grey for received (matching screenshot)
    final Color bubbleBg = isMine
        ? const Color(0xFF1F5C3A)
        : const Color(0xFF1E1E2E);

    final Color iconBg = showMissed
        ? Colors.red.withOpacity(0.18)
        : Colors.white.withOpacity(0.10);

    final Color iconColor =
    showMissed ? Colors.red : Colors.white;

    final String title = showMissed
        ? (isVideoCall ? 'Missed video call' : 'Missed voice call')
        : (isVideoCall ? 'Video call' : 'Voice call');

    String subtitle;
    if (showMissed) {
      subtitle = 'Tap to call back';
    } else if (duration != null && duration!.inSeconds > 0) {
      subtitle = _fmtDuration(duration!);
    } else {
      subtitle = 'No answer';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onTap: showMissed ? onCallback : null,
          child: Container(
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
            margin: EdgeInsets.only(
              left: isMine ? 60 : 12,
              right: isMine ? 12 : 60,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bubbleBg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: isMine
                    ? const Radius.circular(18)
                    : const Radius.circular(4),
                bottomRight: isMine
                    ? const Radius.circular(4)
                    : const Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // phone icon circle
                Container(
                  width: 40,
                  height: 40,
                  decoration:
                  BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Icon(phoneIcon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                // title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // timestamp
                Text(time,
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}