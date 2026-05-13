import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const VoiceMatchApp());
}

class VoiceMatchApp extends StatelessWidget {
  const VoiceMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceMatch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0A0A0F),
      ),
      home: const VoiceMatchScreen(),
    );
  }
}

// ─── Data Models ────────────────────────────────────────────────────────────

class VoiceProfile {
  final String name;
  final String desc;
  final String initials;
  int pitch;

  VoiceProfile({
    required this.name,
    required this.desc,
    required this.initials,
    required this.pitch,
  });
}

class Category {
  final String key;
  final String label;
  final Color accent;
  final Color tabBg;
  final Color tabBorder;
  final Color activeTabBg;
  final Color cardSelectedBg;
  final LinearGradient placeholderGradient;
  final List<VoiceProfile> profiles;

  const Category({
    required this.key,
    required this.label,
    required this.accent,
    required this.tabBg,
    required this.tabBorder,
    required this.activeTabBg,
    required this.cardSelectedBg,
    required this.placeholderGradient,
    required this.profiles,
  });
}

// ─── Main Screen ─────────────────────────────────────────────────────────────

class VoiceMatchScreen extends StatefulWidget {
  const VoiceMatchScreen({super.key});

  @override
  State<VoiceMatchScreen> createState() => _VoiceMatchScreenState();
}

class _VoiceMatchScreenState extends State<VoiceMatchScreen> {
  int _currentCatIdx = 0;
  int _selectedProfileIdx = 0;
  bool _micActive = false;
  double _pitch = 40;

  // ─── Har profile ka real pitch value (semitones) ──────────────────────────
  final Map<String, int> voicePitchMap = {
    'Aryan': -4,
    'Bilal': -3,
    'Hassan': -1,
    'Omar': -6,
    'Ayesha': 4,
    'Sana': 6,
    'Noor': 3,
    'Hira': 7,
    'Chacha Ji': -8,
    'Khalid sb.': -9,
    'Riaz': -5,
    'Tariq': -8,
    'Chachi Ji': 2,
    'Rubina': 3,
    'Shahida': 4,
    'Farida': 2,
  };

  final List<Category> _categories = [
    Category(
      key: 'boy',
      label: 'Boy Voices',
      accent: const Color(0xFF5B9CF6),
      tabBg: const Color(0xFF0D1B3E),
      tabBorder: const Color(0xFF1E3A6E),
      activeTabBg: const Color(0xFF1A3A7A),
      cardSelectedBg: const Color(0xFF0D1525),
      placeholderGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0D1B3E), Color(0xFF1A3A7A)],
      ),
      profiles: [
        VoiceProfile(name: 'Aryan', desc: 'Deep, confident tone', initials: 'AR', pitch: 40),
        VoiceProfile(name: 'Bilal', desc: 'Smooth & casual voice', initials: 'BL', pitch: 35),
        VoiceProfile(name: 'Hassan', desc: 'Young & energetic', initials: 'HS', pitch: 55),
        VoiceProfile(name: 'Omar', desc: 'Serious & mature', initials: 'OM', pitch: 25),
      ],
    ),
    Category(
      key: 'girl',
      label: 'Girl Voices',
      accent: const Color(0xFFF67BB5),
      tabBg: const Color(0xFF3E0D2A),
      tabBorder: const Color(0xFF6E1E46),
      activeTabBg: const Color(0xFF7A1A4A),
      cardSelectedBg: const Color(0xFF1E0A14),
      placeholderGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF3E0D2A), Color(0xFF7A1A4A)],
      ),
      profiles: [
        VoiceProfile(name: 'Ayesha', desc: 'Soft & sweet voice', initials: 'AY', pitch: 70),
        VoiceProfile(name: 'Sana', desc: 'Cheerful & bubbly', initials: 'SN', pitch: 80),
        VoiceProfile(name: 'Noor', desc: 'Calm & elegant', initials: 'NR', pitch: 65),
        VoiceProfile(name: 'Hira', desc: 'Playful & bright', initials: 'HR', pitch: 85),
      ],
    ),
    Category(
      key: 'uncle',
      label: 'Uncle Voices',
      accent: const Color(0xFFC4A84F),
      tabBg: const Color(0xFF1E1E0D),
      tabBorder: const Color(0xFF3D3A1E),
      activeTabBg: const Color(0xFF3A3614),
      cardSelectedBg: const Color(0xFF1A1508),
      placeholderGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1E1E0D), Color(0xFF3A3614)],
      ),
      profiles: [
        VoiceProfile(name: 'Chacha Ji', desc: 'Warm uncle tone', initials: 'CJ', pitch: 20),
        VoiceProfile(name: 'Khalid sb.', desc: 'Wise & composed', initials: 'KS', pitch: 15),
        VoiceProfile(name: 'Riaz', desc: 'Friendly & relaxed', initials: 'RZ', pitch: 30),
        VoiceProfile(name: 'Tariq', desc: 'Bold & authoritative', initials: 'TQ', pitch: 18),
      ],
    ),
    Category(
      key: 'aunty',
      label: 'Aunty Voices',
      accent: const Color(0xFFB57FF6),
      tabBg: const Color(0xFF2A0D3E),
      tabBorder: const Color(0xFF4A1E6E),
      activeTabBg: const Color(0xFF4A1A7A),
      cardSelectedBg: const Color(0xFF130A1E),
      placeholderGradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2A0D3E), Color(0xFF4A1A7A)],
      ),
      profiles: [
        VoiceProfile(name: 'Chachi Ji', desc: 'Warm & caring voice', initials: 'CH', pitch: 60),
        VoiceProfile(name: 'Rubina', desc: 'Gentle & soft', initials: 'RB', pitch: 68),
        VoiceProfile(name: 'Shahida', desc: 'Lively & expressive', initials: 'SH', pitch: 72),
        VoiceProfile(name: 'Farida', desc: 'Calm & mature', initials: 'FR', pitch: 58),
      ],
    ),
  ];

  Category get _currentCat => _categories[_currentCatIdx];
  VoiceProfile get _currentProfile => _currentCat.profiles[_selectedProfileIdx];

  void _switchCategory(int idx) {
    setState(() {
      _currentCatIdx = idx;
      _selectedProfileIdx = 0;
      _pitch = _currentCat.profiles[0].pitch.toDouble();
      _micActive = false;
    });
  }

  void _selectProfile(int idx) {
    if (idx == _selectedProfileIdx) return;
    setState(() {
      _selectedProfileIdx = idx;
      _pitch = _currentCat.profiles[idx].pitch.toDouble();
      _micActive = false;
    });
  }

  void _toggleMic() {
    setState(() {
      _micActive = !_micActive;
    });
  }

  // ─── Updated _applyVoice: SharedPreferences mein save karta hai ───────────
  void _applyVoice() async {
    final prefs = await SharedPreferences.getInstance();
    final pitch = voicePitchMap[_currentProfile.name] ?? 0;

    await prefs.setInt('selected_pitch', pitch);
    await prefs.setString('selected_voice_name', _currentProfile.name);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _currentCat.accent.withAlpha(38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: _currentCat.accent, size: 20),
              const SizedBox(width: 10),
              Text(
                '${_currentProfile.name} voice applied!',
                style: TextStyle(color: _currentCat.accent, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      // 1 second baad automatically back jaao
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = _currentCat;
    final accent = cat.accent;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'VoiceMatch',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Wego Voice Changer',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Category Tabs ────────────────────────────────────────
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final c = _categories[i];
                  final isActive = i == _currentCatIdx;
                  final icons = [
                    Icons.person_rounded,
                    Icons.person_2_rounded,
                    Icons.man_rounded,
                    Icons.woman_rounded,
                  ];
                  return GestureDetector(
                    onTap: () => _switchCategory(i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      decoration: BoxDecoration(
                        color: isActive ? c.activeTabBg : c.tabBg,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: isActive ? c.accent : c.tabBorder,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(icons[i], size: 14, color: isActive ? c.accent : c.accent.withAlpha(178)),
                          const SizedBox(width: 5),
                          Text(
                            c.label.split(' ')[0],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isActive ? c.accent : c.accent.withAlpha(178),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // ── Section Label ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  cat.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: Color(0xFF555555),
                  ),
                ),
              ),
            ),

            // ── Profile Grid ─────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: cat.profiles.length,
                        itemBuilder: (ctx, i) {
                          final p = cat.profiles[i];
                          final isSelected = i == _selectedProfileIdx;
                          return GestureDetector(
                            onTap: () => _selectProfile(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: isSelected ? cat.cardSelectedBg : const Color(0xFF12121F),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected ? accent : const Color(0xFF1E1E2E),
                                  width: 1,
                                ),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Placeholder image
                                      Container(
                                        height: 110,
                                        decoration: BoxDecoration(
                                          gradient: cat.placeholderGradient,
                                        ),
                                        child: Center(
                                          child: Text(
                                            p.initials,
                                            style: TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w700,
                                              color: accent,
                                              letterSpacing: -1,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFFE0E0E0),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              p.desc,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF555555),
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Selected badge
                                  if (isSelected)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check, size: 13, color: Colors.white),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Voice Bar ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF12121F),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1E1E2E)),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Active Voice',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF666666), fontWeight: FontWeight.w500),
                                ),
                                Text(
                                  '${_currentProfile.name} — ${_currentProfile.desc.split(' ')[0]}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: accent,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Text(
                                  'Pitch',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF555555)),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      trackHeight: 4,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                      activeTrackColor: accent,
                                      inactiveTrackColor: const Color(0xFF2A2A3E),
                                      thumbColor: accent,
                                      overlayColor: accent.withAlpha(38),
                                    ),
                                    child: Slider(
                                      value: _pitch,
                                      min: 0,
                                      max: 100,
                                      onChanged: (v) {
                                        setState(() {
                                          _pitch = v;
                                          _currentProfile.pitch = v.round();
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                SizedBox(
                                  width: 28,
                                  child: Text(
                                    _pitch.round().toString(),
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF555555)),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Mic Button ────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: _toggleMic,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 52,
                          decoration: BoxDecoration(
                            color: cat.activeTabBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _micActive
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: accent,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _micActive ? 'Playing...' : 'Play',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: accent,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Waveform bars
                              Row(
                                children: List.generate(5, (i) {
                                  return _WaveBar(
                                    active: _micActive,
                                    color: accent,
                                    delay: Duration(milliseconds: i * 100),
                                  );
                                }),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ── Apply Button ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: _applyVoice,
                        child: Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withAlpha(89),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_rounded, color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Apply Voice',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Animated Wave Bar ────────────────────────────────────────────────────────

class _WaveBar extends StatefulWidget {
  final bool active;
  final Color color;
  final Duration delay;

  const _WaveBar({required this.active, required this.color, required this.delay});

  @override
  State<_WaveBar> createState() => _WaveBarState();
}

class _WaveBarState extends State<_WaveBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() => setState(() {}));
    _anim = Tween<double>(begin: 4, end: 18).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(_WaveBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        Future.delayed(widget.delay, () {
          if (mounted) _ctrl.repeat(reverse: true);
        });
      } else {
        _ctrl.stop();
        _ctrl.animateTo(0);
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: _anim.value,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}