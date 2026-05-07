import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'app_localizations.dart';
import 'app_translations.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  MODEL
// ─────────────────────────────────────────────────────────────────────────────
class UserModel {
  final String uid;
  final String name;
  final int age;
  final String city;
  final String gender;
  final String? photoUrl;
  final double? latitude;
  final double? longitude;
  double? distance;

  final bool isReadyToMatch;
  final String privacyLevel;
  final DateTime? lastHeartbeat;
  final int intentionScore;

  UserModel({
    required this.uid,
    required this.name,
    required this.age,
    required this.city,
    required this.gender,
    this.photoUrl,
    this.latitude,
    this.longitude,
    this.distance,
    this.isReadyToMatch = false,
    this.privacyLevel = 'open',
    this.lastHeartbeat,
    this.intentionScore = 0,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      name: d['name'] ?? d['fullName'] ?? '',
      age: (d['age'] ?? 0) is int
          ? d['age']
          : int.tryParse(d['age'].toString()) ?? 0,
      city: d['city'] ?? d['location'] ?? '',
      gender: d['gender'] ?? '',
      photoUrl: d['photoUrl'] ?? d['profileImage'],
      latitude: (d['latitude'] as num?)?.toDouble(),
      longitude: (d['longitude'] as num?)?.toDouble(),
      isReadyToMatch: d['is_ready_to_match'] ?? false,
      privacyLevel: d['privacy_level'] ?? 'open',
      lastHeartbeat: (d['last_heartbeat'] as Timestamp?)?.toDate(),
      intentionScore: d['intention_score'] ?? 0,
    );
  }

  String get activeStatus {
    if (lastHeartbeat == null) return 'offline';
    final diff = DateTime.now().difference(lastHeartbeat!);
    if (diff.inMinutes < 2) return 'now';
    if (diff.inMinutes < 5) return 'recent';
    return 'offline';
  }

  Color get statusColor {
    switch (activeStatus) {
      case 'now':
        return Colors.green;
      case 'recent':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String statusLabel(BuildContext context) {
    switch (activeStatus) {
      case 'now':    return context.tr('status_now_label');
      case 'recent': return context.tr('status_recent_label');
      default:       return context.tr('status_away_label');
    }
  }
  bool get isVisible =>
      isReadyToMatch &&
          (privacyLevel == 'open' || privacyLevel == 'semi') &&
          activeStatus != 'offline';
}

// ─────────────────────────────────────────────────────────────────────────────
//  SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AdvancedFilterScreen extends StatefulWidget {
  const AdvancedFilterScreen({Key? key}) : super(key: key);

  @override
  State<AdvancedFilterScreen> createState() => _AdvancedFilterScreenState();
}

class _AdvancedFilterScreenState extends State<AdvancedFilterScreen>
    with SingleTickerProviderStateMixin {
  final _uidCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  RangeValues _ageRange = const RangeValues(18, 35);
  double _maxDistance = 50;
  String _selectedGender = 'Women';

  bool _onlyReadyToMatch = true;
  String _statusFilter = 'all';

  bool _isLoading = false;
  bool _hasSearched = false;
  List<UserModel> _results = [];
  String? _errorMsg;

  Position? _currentPosition;
  bool _locationFetched = false;

  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  static const int _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  final _purpleColor = const Color(0xFF6C47E8);
  final _lightPurple = const Color(0xFFF0EBFF);
  final _bgColor = const Color(0xFFF7F6FB);

  String _tr(String key) => context.tr(key);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchMoreResults();
      }
    });

    _initLocation();
    _addIntentionScore();
  }

  Future<void> _addIntentionScore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'intention_score': FieldValue.increment(5),
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _uidCtrl.dispose();
    _nameCtrl.dispose();
    _locationCtrl.dispose();
    _animCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ✅ FIX 1: desiredAccuracy deprecated → LocationSettings
  Future<void> _initLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationFetched = true);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      setState(() {
        _currentPosition = pos;
        _locationFetched = true;
      });
    } catch (_) {
      setState(() => _locationFetched = true);
    }
  }

  double _calcDistanceKm(UserModel u) {
    if (_currentPosition == null || u.latitude == null || u.longitude == null) {
      return 0;
    }
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      u.latitude!,
      u.longitude!,
    ) /
        1000;
  }

  Future<void> _doSearch() async {
    setState(() {
      _isLoading = true;
      _hasSearched = false;
      _results = [];
      _errorMsg = null;
      _lastDocument = null;
      _hasMore = true;
    });
    await _fetchPage(isFirstPage: true);
  }

  Future<void> _fetchPage({bool isFirstPage = false}) async {
    if (!_hasMore) return;
    if (_isFetchingMore && !isFirstPage) return;
    if (!isFirstPage) setState(() => _isFetchingMore = true);

    try {
      final uid = _uidCtrl.text.trim().replaceAll('@', '').toLowerCase();
      final name = _nameCtrl.text.trim().toLowerCase();
      final location = _locationCtrl.text.trim().toLowerCase();

      Query query = FirebaseFirestore.instance.collection('users');
      query = query.where('privacy_level', whereIn: ['open', 'semi']);

      if (_onlyReadyToMatch) {
        query = query.where('is_ready_to_match', isEqualTo: true);
      }

      if (_selectedGender != 'Everyone') {
        query =
            query.where('gender', isEqualTo: _selectedGender.toLowerCase());
      }

      query = query
          .where('age', isGreaterThanOrEqualTo: _ageRange.start.toInt())
          .where('age', isLessThanOrEqualTo: _ageRange.end.toInt())
          .orderBy('age');

      if (_lastDocument != null) {
        query = query.startAfterDocument(_lastDocument!);
      }

      final snapshot = await query.limit(_pageSize).get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
          _isFetchingMore = false;
          _hasSearched = true;
        });
        return;
      }

      _lastDocument = snapshot.docs.last;

      List<UserModel> fetched =
      snapshot.docs.map((d) => UserModel.fromFirestore(d)).toList();

      final myUid = FirebaseAuth.instance.currentUser?.uid;
      List<UserModel> filtered = fetched.where((u) {
        if (u.uid == myUid) return false;

        if (uid.isNotEmpty) {
          final uidMatch = u.uid.toLowerCase().contains(uid);
          final nameAsUid =
          u.name.toLowerCase().replaceAll(' ', '_').contains(uid);
          if (!uidMatch && !nameAsUid) return false;
        }

        if (name.isNotEmpty && !u.name.toLowerCase().contains(name)) {
          return false;
        }

        if (location.isNotEmpty && !u.city.toLowerCase().contains(location)) {
          return false;
        }

        if (_statusFilter == 'now' && u.activeStatus != 'now') return false;
        if (_statusFilter == 'recent' &&
            u.activeStatus != 'now' &&
            u.activeStatus != 'recent') return false;

        return true;
      }).toList();

      for (var u in filtered) {
        u.distance = _calcDistanceKm(u);
      }
      if (_currentPosition != null) {
        filtered =
            filtered.where((u) => (u.distance ?? 0) <= _maxDistance).toList();
      }

      if (snapshot.docs.length < _pageSize) _hasMore = false;

      setState(() {
        _results.addAll(filtered);
        _isLoading = false;
        _isFetchingMore = false;
        _hasSearched = true;
      });

      if (isFirstPage) _animCtrl.forward(from: 0);
    } on FirebaseException catch (e) {
      setState(() {
        _errorMsg = '${_tr('firebase_error')} ${e.message}';
        _isLoading = false;
        _isFetchingMore = false;
        _hasSearched = true;
      });
    } catch (_) {
      setState(() {
        _errorMsg = _tr('generic_error');
        _isLoading = false;
        _isFetchingMore = false;
        _hasSearched = true;
      });
    }
  }

  Future<void> _fetchMoreResults() async {
    if (!_hasMore || _isFetchingMore || _isLoading) return;
    await _fetchPage(isFirstPage: false);
  }

  void _clearAll() {
    setState(() {
      _uidCtrl.clear();
      _nameCtrl.clear();
      _locationCtrl.clear();
      _ageRange = const RangeValues(18, 35);
      _maxDistance = 50;
      _selectedGender = 'Women';
      _onlyReadyToMatch = true;
      _statusFilter = 'all';
      _results = [];
      _hasSearched = false;
      _errorMsg = null;
      _lastDocument = null;
      _hasMore = true;
    });
    _animCtrl.reset();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_tr('filters_cleared')),
        backgroundColor: _purpleColor,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel(_tr('active_status')),
                  _buildStatusFilterRow(),
                  const SizedBox(height: 12),
                  _buildReadyToggle(),
                  const SizedBox(height: 16),
                  _sectionLabel(_tr('search_by_uid')),
                  _buildUidField(),
                  const SizedBox(height: 6),
                  _hint(_tr('uid_example')),
                  const SizedBox(height: 16),
                  _sectionLabel(_tr('full_name')),
                  _buildTextField(
                    controller: _nameCtrl,
                    hint: _tr('name_hint'),
                    icon: Icons.person_outline_rounded,
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel(_tr('location_city')),
                  _buildTextField(
                    controller: _locationCtrl,
                    hint: _tr('location_hint'),
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 16),
                  _sectionLabel(_tr('age_range')),
                  _buildAgeCard(),
                  const SizedBox(height: 16),
                  _sectionLabel(_tr('max_distance')),
                  _buildDistanceCard(),
                  const SizedBox(height: 16),
                  _sectionLabel(_tr('show_me')),
                  _buildGenderRow(),
                  const SizedBox(height: 24),
                  _buildSearchButton(),
                  const SizedBox(height: 24),
                  if (_hasSearched || _isLoading) _buildResults(),
                  if (_isFetchingMore)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: _purpleColor, strokeWidth: 2)),
                    ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusFilterRow() {
    final options = [
      {'value': 'all', 'labelKey': 'status_all', 'color': Colors.grey},
      {'value': 'now', 'labelKey': 'status_now', 'color': Colors.green},
      {'value': 'recent', 'labelKey': 'status_recent', 'color': Colors.amber},
    ];
    return Row(
      children: options.map((o) {
        final isSelected = _statusFilter == o['value'];
        return Expanded(
          child: GestureDetector(
            onTap: () =>
                setState(() => _statusFilter = o['value'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin:
              EdgeInsets.only(right: o['value'] != 'recent' ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                // ✅ FIX 2: withOpacity → withValues
                color: isSelected
                    ? (o['color'] as Color).withValues(alpha: 0.15)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? (o['color'] as Color)
                      : const Color(0xFFE4DFF5),
                  width: 1.5,
                ),
              ),
              child: Text(
                _tr(o['labelKey'] as String),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? (o['color'] as Color)
                      : const Color(0xFF7A6FB0),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReadyToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // ✅ FIX 3: withOpacity → withValues
        color: _onlyReadyToMatch
            ? _purpleColor.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _onlyReadyToMatch ? _purpleColor : const Color(0xFFE4DFF5),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.bolt,
              color: _onlyReadyToMatch ? _purpleColor : Colors.grey,
              size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tr('show_active_only'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _onlyReadyToMatch
                        ? const Color(0xFF2D1F6E)
                        : Colors.grey[600],
                  ),
                ),
                Text(
                  _tr('ready_to_match_subtitle'),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          // ✅ FIX 4: activeColor deprecated → thumbColor + trackColor via WidgetStateProperty
          Switch(
            value: _onlyReadyToMatch,
            onChanged: (v) => setState(() => _onlyReadyToMatch = v),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return _purpleColor;
              return Colors.grey[400];
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return _purpleColor.withValues(alpha: 0.5);
              }
              return Colors.grey[300];
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6C47E8), Color(0xFF5A3AD1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            // ✅ FIX 5: withOpacity → withValues
            color: _purpleColor.withValues(alpha: 0.3),
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
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                // ✅ FIX 6: withOpacity → withValues
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _tr('advanced_filter_title'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700),
            ),
          ),
          GestureDetector(
            onTap: _clearAll,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                // ✅ FIX 7: withOpacity → withValues
                color: Colors.white.withValues(alpha: 0.2),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _tr('clear_all'),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9B8EC4),
            letterSpacing: 1.2)),
  );

  Widget _hint(String text) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(text,
        style: const TextStyle(
            fontSize: 11, color: Color(0xFFB0A8D0))),
  );

  Widget _buildUidField() {
    return TextField(
      controller: _uidCtrl,
      style: const TextStyle(fontSize: 15, color: Color(0xFF2D1F6E)),
      decoration: InputDecoration(
        hintText: _tr('uid_hint'),
        hintStyle: const TextStyle(color: Color(0xFFC0B8E0)),
        prefixIcon: const Icon(Icons.search_rounded,
            color: Color(0xFF9B8EC4), size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFFE4DFF5), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFFE4DFF5), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _purpleColor, width: 1.5),
        ),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontSize: 15, color: Color(0xFF2D1F6E)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFC0B8E0)),
        prefixIcon: Icon(icon, color: const Color(0xFF9B8EC4), size: 20),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFFE4DFF5), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
          const BorderSide(color: Color(0xFFE4DFF5), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _purpleColor, width: 1.5),
        ),
        contentPadding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      ),
    );
  }

  Widget _buildAgeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE8FC), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_tr('age'),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3D2A8A))),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: _purpleColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_ageRange.start.toInt()} – ${_ageRange.end.toInt()} ${_tr('age_yrs')}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _purpleColor,
              inactiveTrackColor: const Color(0xFFDDD8F5),
              thumbColor: _purpleColor,
              // ✅ FIX 8: withOpacity → withValues
              overlayColor: _purpleColor.withValues(alpha: 0.15),
              trackHeight: 5,
              thumbShape:
              const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: RangeSlider(
              values: _ageRange,
              min: 18,
              max: 60,
              divisions: 42,
              onChanged: (v) => setState(() => _ageRange = v),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('18',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB0A8D0))),
              Text('60+',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB0A8D0))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE8FC), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_tr('distance'),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF3D2A8A))),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: _purpleColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_maxDistance.toInt()} km',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (!_locationFetched)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(_tr('getting_location'),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFFB0A8D0))),
            )
          else if (_currentPosition == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(_tr('location_unavailable'),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFFE57373))),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(_tr('location_detected'),
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF66BB6A))),
            ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: _currentPosition != null
                  ? _purpleColor
                  : const Color(0xFFD0C8F0),
              inactiveTrackColor: const Color(0xFFDDD8F5),
              thumbColor: _currentPosition != null
                  ? _purpleColor
                  : const Color(0xFFD0C8F0),
              // ✅ FIX 9: withOpacity → withValues
              overlayColor: _purpleColor.withValues(alpha: 0.15),
              trackHeight: 5,
              thumbShape:
              const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _maxDistance,
              min: 1,
              max: 500,
              divisions: 499,
              onChanged: (v) => setState(() => _maxDistance = v),
            ),
          ),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1 km',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB0A8D0))),
              Text('500 km',
                  style: TextStyle(fontSize: 11, color: Color(0xFFB0A8D0))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderRow() {
    final options = [
      {'value': 'Women', 'labelKey': 'gender_women'},
      {'value': 'Men', 'labelKey': 'gender_men'},
      {'value': 'Everyone', 'labelKey': 'gender_everyone'},
    ];
    return Row(
      children: options.map((g) {
        final isSelected = _selectedGender == g['value'];
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedGender = g['value']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin:
              EdgeInsets.only(right: g['value'] != 'Everyone' ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? _purpleColor : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? _purpleColor
                      : const Color(0xFFE4DFF5),
                  width: 1.5,
                ),
              ),
              child: Text(
                _tr(g['labelKey']!),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color:
                  isSelected ? Colors.white : const Color(0xFF7A6FB0),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSearchButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _doSearch,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C47E8), Color(0xFF9B67F5)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              // ✅ FIX 10: withOpacity → withValues
              color: _purpleColor.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: _isLoading
            ? const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                color: Colors.white, strokeWidth: 2.5),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              _tr('search_matches'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: _purpleColor));
    }
    if (_errorMsg != null) return _errorWidget(_errorMsg!);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Color(0xFFF0EDF8), thickness: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_tr('results'),
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3D2A8A))),
              Text('${_results.length} ${_tr('results_found')}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9B8EC4))),
            ],
          ),
          const SizedBox(height: 12),
          if (_results.isEmpty)
            _emptyState()
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final delay = Duration(milliseconds: i * 60);
                return FutureBuilder(
                  future: Future.delayed(delay),
                  builder: (_, snap) => AnimatedOpacity(
                    opacity: snap.connectionState == ConnectionState.done
                        ? 1
                        : 0,
                    duration: const Duration(milliseconds: 300),
                    child: _userCard(_results[i]),
                  ),
                );
              },
            ),
          if (!_hasMore && _results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(_tr('no_more_results'),
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFFB0A8D0))),
              ),
            ),
        ],
      ),
    );
  }

  Widget _userCard(UserModel u) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDE8FC), width: 1.5),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: u.statusColor, width: 2),
                ),
                child: ClipOval(
                  child: u.photoUrl != null && u.photoUrl!.isNotEmpty
                      ? Image.network(u.photoUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback(u))
                      : _avatarFallback(u),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: u.statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${u.name}, ${u.age}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D1F6E))),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 13, color: Color(0xFF9B8EC4)),
                    const SizedBox(width: 3),
                    Text(u.city,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF9B8EC4))),
                    if (u.distance != null && u.distance! > 0) ...[
                      const SizedBox(width: 6),
                      Text('• ${u.distance!.toStringAsFixed(1)} km',
                          style: TextStyle(
                              fontSize: 11, color: _purpleColor)),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  u.statusLabel(context),
                  style: TextStyle(
                      fontSize: 11,
                      color: u.statusColor,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _lightPurple,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _tr('match_btn'),
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _purpleColor),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  // ✅ FIX 11: withOpacity → withValues
                  color: u.privacyLevel == 'open'
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  u.privacyLevel == 'open'
                      ? _tr('privacy_open')
                      : _tr('privacy_semi'),
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: u.privacyLevel == 'open'
                          ? Colors.green[700]
                          : Colors.amber[700]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(UserModel u) {
    return Container(
      color: _lightPurple,
      child: Center(
        child: Text(
          u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _purpleColor),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded,
                size: 52,
                // ✅ FIX 12: withOpacity → withValues
                color: _purpleColor.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(_tr('no_users_found'),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7A6FB0))),
            const SizedBox(height: 6),
            Text(_tr('adjust_filters'),
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFFB0A8D0))),
          ],
        ),
      ),
    );
  }

  Widget _errorWidget(String msg) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE53935), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFFB71C1C))),
          ),
        ],
      ),
    );
  }
}