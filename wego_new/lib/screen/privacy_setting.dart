// lib/screen/privacy_setting.dart
//
// Real-time privacy settings screen. Pehle screen mein hardcoded
// `_Contact` list aur `_save()` ek SnackBar dikhata tha. Ab:
//
//   - State seed hoti hai `PrivacyProvider` se (jo Firestore ka live
//     listener chala raha hota hai users/{uid}/privacy/settings par).
//   - Contacts list `users/{me}/following/*` se aati hai (FollowController
//     wahi pattern likhta hai). Har contact ka asal `uid` save hota hai.
//   - Save button `PrivacyProvider.saveSettings(...)` call karta hai →
//     Firestore mein merge ho jata hai, baqi sare watchers turant reflect.
//   - "Approval required" group option hata diya gaya hai (user request).
//
// Navigate:
//   Navigator.push(context,
//     MaterialPageRoute(builder: (_) => const PrivacySettingScreen()));

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wego_marriage/providers/privacy_provider.dart';

// ─── Data Model ────────────────────────────────────────────────────────────

class _Contact {
  // ASLI Firestore UID — jise `visibleToUsers` array mein store karte hain.
  final String userId;
  final String initials;
  final String name;
  final Color avatarBg;
  final Color avatarFg;
  bool selected;

  _Contact({
    required this.userId,
    required this.initials,
    required this.name,
    required this.avatarBg,
    required this.avatarFg,
    this.selected = false,
  });
}

class _Pill {
  final String value;
  final String label;
  const _Pill(this.value, this.label);
}

// ─── Screen ────────────────────────────────────────────────────────────────

class PrivacySettingScreen extends StatefulWidget {
  const PrivacySettingScreen({super.key});

  @override
  State<PrivacySettingScreen> createState() => _PrivacySettingScreenState();
}

class _PrivacySettingScreenState extends State<PrivacySettingScreen> {
  // ── State (mirror of PrivacyProvider) ─────────────────────────────────
  String _lastSeenOpt = 'everyone';
  DateTime? _customLastSeen;
  bool _hideOnline = false;
  bool _hideLastSeen = false;
  bool _blueTick = false;
  String _groupOpt = 'everyone';
  String _bioOpt = 'everyone';

  // Real contacts from Firestore.
  List<_Contact> _contacts = [];
  bool _isLoadingContacts = true;
  bool _isSaving = false;
  bool _didSeedFromProvider = false;

  int get _selCount => _contacts.where((c) => c.selected).length;

  // ── Avatar palette pool — har contact ke liye stable color pick. ──────
  static const _palette = <List<Color>>[
    [Color(0xFFFBEAF0), Color(0xFF72243E)],
    [Color(0xFFEEEDFE), Color(0xFF3C3489)],
    [Color(0xFFFAECE7), Color(0xFF712B13)],
    [Color(0xFFE1F5EE), Color(0xFF085041)],
    [Color(0xFFE6F1FB), Color(0xFF0C447C)],
    [Color(0xFFFFF3D6), Color(0xFF8A6A00)],
    [Color(0xFFF1E1FB), Color(0xFF551B7A)],
  ];

  // ── Palette ────────────────────────────────────────────────────────────
  static const _pink = Color(0xFFD4537E);
  static const _pinkLight = Color(0xFFFBEAF0);
  static const _pinkDark = Color(0xFF72243E);
  static const _purple = Color(0xFF7F77DD);
  static const _purpleLight = Color(0xFFEEEDFE);
  static const _teal = Color(0xFF1D9E75);
  static const _tealLight = Color(0xFFE1F5EE);
  static const _coral = Color(0xFFD85A30);
  static const _coralLight = Color(0xFFFAECE7);
  static const _blue = Color(0xFF378ADD);
  static const _blueLight = Color(0xFFE6F1FB);
  static const _blueDark = Color(0xFF0C447C);
  static const _bg = Color(0xFFF6F4F8);

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  // ── Seed state from PrivacyProvider whenever it changes ────────────────
  void _seedFromProvider(PrivacyProvider privacy) {
    _lastSeenOpt = privacy.lastSeenOpt;
    _customLastSeen = privacy.customLastSeen;
    _hideOnline = privacy.hideOnline;
    _hideLastSeen = privacy.hideLastSeen;
    _blueTick = privacy.blueTick;
    // Sanitize legacy "request" value — option hata diya gaya hai.
    _groupOpt =
        privacy.groupOpt == 'request' ? 'contacts' : privacy.groupOpt;
    _bioOpt = privacy.bioOpt;
    // Sync `selected` flags onto loaded contacts.
    final whitelist = privacy.visibleToUsers.toSet();
    for (final c in _contacts) {
      c.selected = whitelist.contains(c.userId);
    }
  }

  // ── Load real contacts from `users/{me}/following` ─────────────────────
  Future<void> _loadContacts() async {
    final me = FirebaseAuth.instance.currentUser?.uid;
    if (me == null) {
      if (mounted) setState(() => _isLoadingContacts = false);
      return;
    }
    try {
      final followingSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(me)
          .collection('following')
          .limit(50)
          .get();

      final ids = followingSnap.docs.map((d) => d.id).toList();
      // Fetch each user doc in parallel (bounded — 50 items max).
      final userDocs = await Future.wait(
        ids.map((uid) => FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get()),
      );

      final list = <_Contact>[];
      for (var i = 0; i < userDocs.length; i++) {
        final doc = userDocs[i];
        if (!doc.exists) continue;
        final data = doc.data() ?? {};
        final name = (data['username'] as String? ??
                data['fullName'] as String? ??
                data['name'] as String? ??
                '')
            .trim();
        if (name.isEmpty) continue;
        final pair = _palette[i % _palette.length];
        list.add(_Contact(
          userId: doc.id,
          initials: _initials(name),
          name: name,
          avatarBg: pair[0],
          avatarFg: pair[1],
        ));
      }

      if (!mounted) return;
      setState(() {
        _contacts = list;
        _isLoadingContacts = false;
      });
    } catch (e) {
      debugPrint('PrivacySettings _loadContacts error: $e');
      if (mounted) setState(() => _isLoadingContacts = false);
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.isEmpty
          ? '?'
          : parts.first.substring(0, parts.first.length >= 2 ? 2 : 1)
              .toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  // ── Date / time picker ─────────────────────────────────────────────────
  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => _pinkTheme(ctx, child!),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (ctx, child) => _pinkTheme(ctx, child!),
    );
    if (time == null || !mounted) return;
    setState(() {
      _customLastSeen =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Widget _pinkTheme(BuildContext ctx, Widget child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _pink),
        ),
        child: child,
      );

  // ── Save ───────────────────────────────────────────────────────────────
  Future<void> _save() async {
    setState(() => _isSaving = true);
    final privacy = context.read<PrivacyProvider>();
    try {
      await privacy.saveSettings(
        lastSeenOpt: _lastSeenOpt,
        customLastSeen: _customLastSeen,
        hideOnline: _hideOnline,
        hideLastSeen: _hideLastSeen,
        blueTick: _blueTick,
        groupOpt: _groupOpt,
        bioOpt: _bioOpt,
        visibleToUsers:
            _contacts.where((c) => c.selected).map((c) => c.userId).toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Preferences saved'),
          backgroundColor: const Color(0xFF2C2C2A),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Format datetime ────────────────────────────────────────────────────
  String _fmt(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${months[dt.month - 1]} ${dt.day},  $h:$m $ampm';
  }

  // ── Build ──────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Provider ko consume karo. Pehli baar values aati hain ya unka stream
    // change ho jata hai to local state ko seed karte hain — magar SIRF
    // ek baar jab tak user ne edit shuru na kiya ho.
    final privacy = context.watch<PrivacyProvider>();
    if (!_didSeedFromProvider) {
      _seedFromProvider(privacy);
      _didSeedFromProvider = true;
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12, width: 0.5),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: Colors.black54),
          ),
        ),
        title: const Text(
          'Privacy settings',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1A1A1A)),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: Text(
              'Control who sees you and how you appear to others',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 12, color: Colors.black45, height: 1.5),
            ),
          ),

          // ── 1. Last seen ─────────────────────────────────────────────
          _card(
            iconBg: _pinkLight,
            iconColor: _pink,
            icon: Icons.access_time_rounded,
            title: 'Last seen',
            desc: 'Who can see when you were active',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pills(
                  options: const [
                    _Pill('everyone', 'Everyone'),
                    _Pill('contacts', 'My contacts'),
                    _Pill('nobody', 'Nobody'),
                    _Pill('custom', 'Custom time'),
                  ],
                  selected: _lastSeenOpt,
                  activeColor: _pink,
                  activeBg: _pinkLight,
                  activeFg: _pinkDark,
                  onSelect: (v) => setState(() => _lastSeenOpt = v),
                ),
                if (_lastSeenOpt == 'custom') ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickDateTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: _pinkLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _pink.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded,
                              size: 15, color: _pink),
                          const SizedBox(width: 8),
                          Text(
                            _customLastSeen == null
                                ? 'Tap to pick date & time'
                                : _fmt(_customLastSeen!),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _customLastSeen == null
                                  ? Colors.black38
                                  : _pinkDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── 2. Online status ─────────────────────────────────────────
          _card(
            iconBg: _purpleLight,
            iconColor: _purple,
            icon: Icons.wifi_rounded,
            title: 'Online status',
            desc: "Hide when you're active right now",
            child: Column(
              children: [
                _toggle(
                  title: 'Hide online status',
                  sub: _hideOnline
                      ? 'Your online status is hidden'
                      : "Others can see you're online",
                  value: _hideOnline,
                  onChanged: (v) => setState(() => _hideOnline = v),
                ),
                _divider(),
                _toggle(
                  title: 'Hide last seen entirely',
                  sub: _hideLastSeen
                      ? 'Last seen is fully hidden'
                      : 'Last seen is visible',
                  value: _hideLastSeen,
                  onChanged: (v) => setState(() => _hideLastSeen = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── 3. Visible to selected people ────────────────────────────
          _card(
            iconBg: _tealLight,
            iconColor: _teal,
            icon: Icons.people_alt_rounded,
            title: 'Visible to selected people',
            desc: 'Only these people see your status',
            trailing: _badge('$_selCount selected', _pinkLight, _pinkDark),
            child: Column(
              children: [
                if (_isLoadingContacts)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _pink),
                      ),
                    ),
                  )
                else if (_contacts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'No contacts yet. Follow people to see them here.',
                      style: TextStyle(color: Colors.black45, fontSize: 12),
                    ),
                  )
                else
                  ..._contacts.map(_contactRow),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── 4. Read receipts ─────────────────────────────────────────
          _card(
            iconBg: _coralLight,
            iconColor: _coral,
            icon: Icons.done_all_rounded,
            title: 'Read receipts',
            desc: 'Blue tick when message is read',
            child: _toggle(
              title: 'Turn off blue ticks',
              sub: _blueTick
                  ? 'Blue ticks are disabled'
                  : 'Read receipts are on',
              value: _blueTick,
              onChanged: (v) => setState(() => _blueTick = v),
            ),
          ),

          const SizedBox(height: 14),

          // ── 5. Group invites ─────────────────────────────────────────
          // "Approval required" hata diya — sirf everyone / contacts / nobody.
          _card(
            iconBg: _blueLight,
            iconColor: _blue,
            icon: Icons.group_rounded,
            title: 'Group invites',
            desc: 'Who can add you to groups',
            child: _pills(
              options: const [
                _Pill('everyone', 'Everyone'),
                _Pill('contacts', 'Contacts only'),
                _Pill('nobody', 'Nobody'),
              ],
              selected: _groupOpt,
              activeColor: _blue,
              activeBg: _blueLight,
              activeFg: _blueDark,
              onSelect: (v) => setState(() => _groupOpt = v),
            ),
          ),

          const SizedBox(height: 14),

          // ── 6. Bio visibility ────────────────────────────────────────
          _card(
            iconBg: _pinkLight,
            iconColor: _pink,
            icon: Icons.badge_rounded,
            title: 'Bio visibility',
            desc: 'Who can read your profile bio',
            child: _pills(
              options: const [
                _Pill('everyone', 'Everyone'),
                _Pill('contacts', 'Contacts only'),
                _Pill('nobody', 'Nobody'),
              ],
              selected: _bioOpt,
              activeColor: _pink,
              activeBg: _pinkLight,
              activeFg: _pinkDark,
              onSelect: (v) => setState(() => _bioOpt = v),
            ),
          ),

          const SizedBox(height: 26),

          // ── Save button ──────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _pink,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save preferences'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Widget helpers ─────────────────────────────────────────────────────

  Widget _divider() => Divider(
        color: Colors.black.withOpacity(0.06),
        height: 1,
        thickness: 0.5,
      );

  Widget _badge(String text, Color bg, Color fg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500, color: fg)),
      );

  Widget _card({
    required Color iconBg,
    required Color iconColor,
    required IconData icon,
    required String title,
    required String desc,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: Colors.black.withOpacity(0.06), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 1),
                    Text(desc,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45)),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _pills({
    required List<_Pill> options,
    required String selected,
    required Color activeColor,
    required Color activeBg,
    required Color activeFg,
    required ValueChanged<String> onSelect,
  }) {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: options.map((o) {
        final on = selected == o.value;
        return GestureDetector(
          onTap: () => onSelect(o.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: on ? activeBg : const Color(0xFFF3F3F3),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                  color: on ? activeColor : Colors.black12, width: 1.5),
            ),
            child: Text(
              o.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: on ? activeFg : Colors.black54,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _toggle({
    required String title,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A))),
              const SizedBox(height: 2),
              Text(sub,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black45)),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: _pink,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.black12,
        ),
      ],
    );
  }

  Widget _contactRow(_Contact c) {
    return GestureDetector(
      onTap: () => setState(() => c.selected = !c.selected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: c.avatarBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: c.selected ? _pink : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  c.initials,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.avatarFg),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(c.name,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF1A1A1A))),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: c.selected ? _pink : const Color(0xFFF3F3F3),
                shape: BoxShape.circle,
                border: Border.all(
                    color: c.selected ? _pink : Colors.black12, width: 1.5),
              ),
              child: c.selected
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: Colors.white)
                  : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }
}
