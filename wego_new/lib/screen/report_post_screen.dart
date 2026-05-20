import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Professional-style post report screen.
/// User picks zero or more reason chips, optionally writes a free-form reason,
/// then submits. Report is saved to Firestore `reports` collection so the
/// moderation team can review it.
class ReportPostScreen extends StatefulWidget {
  final String postId;
  final String postOwnerId;
  final String postOwnerUsername;
  final String? postImageUrl;

  const ReportPostScreen({
    super.key,
    required this.postId,
    required this.postOwnerId,
    required this.postOwnerUsername,
    this.postImageUrl,
  });

  @override
  State<ReportPostScreen> createState() => _ReportPostScreenState();
}

class _ReportPostScreenState extends State<ReportPostScreen> {
  // Standard categories used by professional apps (Instagram / TikTok / FB).
  // Keep English keys stable — they get stored in Firestore.
  static const List<_Reason> _reasons = [
    _Reason(key: 'spam', label: 'Spam or misleading'),
    _Reason(key: 'nudity_sexual', label: 'Nudity or sexual content'),
    _Reason(key: 'hate_speech', label: 'Hate speech or symbols'),
    _Reason(key: 'harassment_bullying', label: 'Harassment or bullying'),
    _Reason(key: 'abusive', label: 'Abusive or offensive language'),
    _Reason(key: 'violence', label: 'Violence or dangerous acts'),
    _Reason(key: 'self_harm', label: 'Suicide or self-injury'),
    _Reason(key: 'false_information', label: 'False information'),
    _Reason(key: 'intellectual_property', label: 'Intellectual property violation'),
    _Reason(key: 'scam_fraud', label: 'Scam or fraud'),
    _Reason(key: 'illegal_goods', label: 'Sale of illegal or regulated goods'),
    _Reason(key: 'child_safety', label: 'Child safety concern'),
    _Reason(key: 'impersonation', label: 'Impersonation'),
    _Reason(key: 'privacy', label: 'Privacy violation'),
  ];

  final Set<String> _selected = {};
  final TextEditingController _customCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      !_submitting &&
      (_selected.isNotEmpty || _customCtrl.text.trim().isNotEmpty);

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _submitting = true);

    try {
      await FirebaseFirestore.instance.collection('reports').add({
        'type': 'post',
        'postId': widget.postId,
        'postOwnerId': widget.postOwnerId,
        'postOwnerUsername': widget.postOwnerUsername,
        'postImageUrl': widget.postImageUrl,
        'reporterId': user.uid,
        'reporterUsername': user.displayName ?? '',
        'reasonKeys': _selected.toList(),
        'reasonLabels': _selected
            .map((k) => _reasons.firstWhere((r) => r.key == k).label)
            .toList(),
        'customReason': _customCtrl.text.trim(),
        'status': 'pending', // moderation queue
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      await _showSuccessDialog();
      if (!mounted) return;
      Navigator.of(context).pop(); // close report screen
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit report: $e')),
      );
    }
  }

  Future<void> _showSuccessDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFE6F7EC),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF2E7D32), size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Thanks for letting us know',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your report has been submitted. Our team will review it and take action if it goes against our community guidelines.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0095F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Done',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final fg = isDark ? Colors.white : Colors.black87;
    final subFg = isDark ? Colors.white70 : Colors.black54;
    final chipBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF1F1F1);
    final selectedBg = const Color(0xFF0095F6);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0.5,
        title: const Text('Report'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Text(
                    "Why are you reporting this post?",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Your report is anonymous. If someone is in immediate danger, contact local emergency services right away.",
                    style: TextStyle(fontSize: 12, color: subFg),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _reasons.map((r) {
                      final isSel = _selected.contains(r.key);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSel) {
                              _selected.remove(r.key);
                            } else {
                              _selected.add(r.key);
                            }
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSel ? selectedBg : chipBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSel
                                  ? selectedBg
                                  : (isDark
                                      ? Colors.white24
                                      : Colors.black12),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSel) ...[
                                const Icon(Icons.check,
                                    size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                r.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: isSel ? Colors.white : fg,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Other (optional)",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _customCtrl,
                    style: TextStyle(color: fg),
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText:
                          "If none of the above fit, describe the issue in your own words…",
                      hintStyle: TextStyle(color: subFg, fontSize: 13),
                      filled: true,
                      fillColor: chipBg,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0095F6),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        isDark ? Colors.white24 : Colors.black26,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _canSubmit ? _submit : null,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Report',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Reason {
  final String key;
  final String label;
  const _Reason({required this.key, required this.label});
}
