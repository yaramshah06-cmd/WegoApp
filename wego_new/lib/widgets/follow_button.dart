import 'package:flutter/material.dart';
import 'package:wego_marriage/services/follow_controller.dart';

// ════════════════════════════════════════════════════════════════════════════
//  FollowButton — Shared Follow / Follow back / Following pill jo
//  FollowController ke saath wired hai. Saare screens (notifications,
//  comments tile trailing, user profile etc) ek hi widget use karein taake
//  state har jagah sync rahe — ek bar follow ho jaye to har screen pe
//  "Following" turant dikhe, dobara follow karne ki zaroorat na pade.
//
//  Behavior:
//    • notifier(targetUid) listen karta hai → state changes pe rebuild.
//    • Tap → FollowController.toggle(targetUid) (optimistic + Firestore).
//    • Label: I follow them → "Following"
//             They follow me, I don't → "Follow back"
//             Neither → "Follow"
//
//  Compact variant — notification rows ke chote trailing slot ke liye.
// ════════════════════════════════════════════════════════════════════════════

class FollowButton extends StatefulWidget {
  final String targetUid;
  final bool compact;
  final Color primaryColor;

  const FollowButton({
    super.key,
    required this.targetUid,
    this.compact = false,
    this.primaryColor = const Color(0xFF0095F6),
  });

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  bool _followsMe = false;

  @override
  void initState() {
    super.initState();
    FollowController.instance.watch(widget.targetUid);
    FollowController.instance.doesFollowMe(widget.targetUid).then((v) {
      if (mounted) setState(() => _followsMe = v);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.targetUid.isEmpty) return const SizedBox.shrink();

    final notifier = FollowController.instance.notifier(widget.targetUid);
    final loaded =
        FollowController.instance.loadedNotifier(widget.targetUid);

    return ValueListenableBuilder<bool>(
      valueListenable: loaded,
      builder: (context, isLoaded, __) {
        return ValueListenableBuilder<bool>(
          valueListenable: notifier,
          builder: (context, isFollowing, _) {
            // "Follow back" tab tak na dikhayein jab tak Firestore se pehla
            // snapshot na aa jaye — warna A jab B ka notification kholega
            // tou ek frame ke liye "Follow back" flicker hota hai chahe
            // A pehle se follow karta ho ("Following" expected). Loaded
            // hone tak safe default "Follow" rahe.
            final String label = isFollowing
                ? 'Following'
                : ((isLoaded && _followsMe) ? 'Follow back' : 'Follow');

            final bg =
                isFollowing ? Colors.transparent : widget.primaryColor;
            final fg = isFollowing ? Colors.grey.shade700 : Colors.white;
            final border = isFollowing
                ? Border.all(color: Colors.grey.shade400)
                : null;

            final padding = widget.compact
                ? const EdgeInsets.symmetric(horizontal: 12, vertical: 6)
                : const EdgeInsets.symmetric(horizontal: 18, vertical: 8);
            final fontSize = widget.compact ? 12.0 : 14.0;

            return GestureDetector(
              onTap: () =>
                  FollowController.instance.toggle(widget.targetUid),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                  border: border,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: fg,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
