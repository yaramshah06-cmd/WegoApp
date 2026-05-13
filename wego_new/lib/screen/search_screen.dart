import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_localizations.dart';
import 'app_translations.dart';
import 'user_profile_screen.dart';

// ─────────────────────────────────────────────────────────────
// SEARCH SCREEN — FULLY FIXED VERSION
//
// FIXES:
//   1. Username search fix — 'username_lower' field pe range query
//      + fallback: saare users fetch karke client-side filter
//   2. Partial/middle name search — "ali" likhne pe "Muhammad Ali"
//      bhi aayega — client-side contains() filter se
//   3. Name search 'name', 'displayName', 'fullName' teeno fields check
// ─────────────────────────────────────────────────────────────
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late TabController _tabController;

  String _query = '';
  bool _isSearching = false;
  bool _showSuggestions = false;
  bool _showAllRecent = false;

  List<Map<String, dynamic>> _suggestions = [];

  List<Map<String, dynamic>> _forYouPosts = [];
  List<Map<String, dynamic>> _forYouUsers = [];
  List<Map<String, dynamic>> _profiles = [];
  List<Map<String, dynamic>> _audio = [];
  List<Map<String, dynamic>> _tags = [];
  List<Map<String, dynamic>> _places = [];

  List<Map<String, dynamic>> _recentSearches = [];
  bool _isLoadingHistory = true;
  List<Map<String, dynamic>> _suggestedUsers = [];

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference? get _historyRef {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('searchHistory');
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchSuggestedUsers();
    _loadSearchHistory();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    _searchController.addListener(() {
      final text = _searchController.text.trim();
      if (text.isEmpty) {
        setState(() {
          _query = '';
          _showSuggestions = false;
          _suggestions = [];
        });
      } else {
        setState(() => _showSuggestions = true);
        _fetchLiveSuggestions(text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  // ✅ FIX: USER SEARCH — partial match, username + all name fields
  // Firestore range query sirf prefix match karti hai.
  // Solution: saare users fetch karo (limit 300) aur
  // client-side pe contains() filter lagao — yeh "ali" likhne pe
  // "Muhammad Ali" aur "Alibek" dono dega.
  // ══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> _searchUsers(String query) async {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return [];

    // Helper: kisi bhi relevant field mein query ho toh true
    bool userMatches(Map<String, dynamic> data) {
      final username =
      (data['username'] as String? ?? '').toLowerCase();
      final usernameLower =
      (data['username_lower'] as String? ?? '').toLowerCase();
      final name =
      (data['name'] as String? ?? '').toLowerCase();
      final displayName =
      (data['displayName'] as String? ?? '').toLowerCase();
      final fullName =
      (data['fullName'] as String? ?? '').toLowerCase();

      // Kisi bhi field mein query contain ho — partial match
      return username.contains(lower) ||
          usernameLower.contains(lower) ||
          name.contains(lower) ||
          displayName.contains(lower) ||
          fullName.contains(lower);
    }

    final allUserDocs = <String, Map<String, dynamic>>{};

    // ── Pass 1: username_lower prefix query (fast, indexed) ──
    try {
      final end = lower.substring(0, lower.length - 1) +
          String.fromCharCode(lower.codeUnitAt(lower.length - 1) + 1);

      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('username_lower', isGreaterThanOrEqualTo: lower)
          .where('username_lower', isLessThan: end)
          .limit(30)
          .get();

      for (final d in snap.docs) {
        allUserDocs[d.id] = {...d.data(), 'id': d.id};
      }
    } catch (e) {
      debugPrint('username_lower query error (field missing?): $e');
    }

    // ── Pass 2: Fetch all users & client-side filter ──
    // Yeh "ali" → "Muhammad Ali" problem solve karta hai
    // aur username_lower field na hone pe bhi kaam karta hai
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .limit(300)
          .get();

      for (final d in snap.docs) {
        if (d.id == _uid) continue; // apna aap mat dikhao
        final data = d.data();
        if (userMatches(data)) {
          allUserDocs[d.id] = {...data, 'id': d.id};
        }
      }
    } catch (e) {
      debugPrint('Full user fetch error: $e');
    }

    // Current user ko results se hatao
    allUserDocs.remove(_uid);

    return allUserDocs.values.toList();
  }

  // ══════════════════════════════════════════════════════════
  // HISTORY LOAD
  // ══════════════════════════════════════════════════════════
  Future<void> _loadSearchHistory() async {
    if (!mounted) return;
    setState(() => _isLoadingHistory = true);

    final ref = _historyRef;
    if (ref == null) {
      if (mounted) setState(() => _isLoadingHistory = false);
      return;
    }

    try {
      final snap = await ref.limit(20).get();
      if (!mounted) return;
      final list = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        return {
          'docId': d.id,
          'type': data['type'] ?? 'query',
          'username': data['username'] ?? '',
          'name': data['name'] ?? '',
          'photoUrl': data['photoUrl'] ?? '',
          'userId': data['userId'] ?? '',
        };
      }).toList();
      setState(() {
        _recentSearches = list;
        _isLoadingHistory = false;
      });
    } catch (e) {
      debugPrint('History load error: $e');
      if (mounted) setState(() => _isLoadingHistory = false);
    }
  }

  // ══════════════════════════════════════════════════════════
  // HISTORY SAVE
  // ══════════════════════════════════════════════════════════
  Future<void> _saveSearchToFirebase(Map<String, dynamic> entry) async {
    final ref = _historyRef;
    if (ref == null) return;
    final username = (entry['username'] as String? ?? '').trim();
    if (username.isEmpty) return;

    try {
      final existing =
      await ref.where('username', isEqualTo: username).get();
      for (final doc in existing.docs) {
        await doc.reference.delete();
      }
      final docRef = await ref.add({
        'type': entry['type'] ?? 'query',
        'username': username,
        'name': (entry['name'] as String? ?? '').trim(),
        'photoUrl': (entry['photoUrl'] as String? ?? '').trim(),
        'userId': (entry['userId'] as String? ?? '').trim(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _recentSearches
            .removeWhere((r) => (r['username'] as String? ?? '') == username);
        _recentSearches.insert(0, {
          'docId': docRef.id,
          'type': entry['type'] ?? 'query',
          'username': username,
          'name': entry['name'] ?? '',
          'photoUrl': entry['photoUrl'] ?? '',
          'userId': entry['userId'] ?? '',
        });
        if (_recentSearches.length > 20) {
          _recentSearches = _recentSearches.take(20).toList();
        }
      });
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  // DELETE ONE ENTRY
  // ══════════════════════════════════════════════════════════
  Future<void> _deleteSearchEntry(Map<String, dynamic> entry) async {
    if (!mounted) return;
    setState(() => _recentSearches.remove(entry));
    final ref = _historyRef;
    if (ref == null) return;
    final docId = entry['docId'] as String? ?? '';
    if (docId.isNotEmpty) {
      try {
        await ref.doc(docId).delete();
      } catch (e) {
        debugPrint('Delete error: $e');
      }
    }
  }

  // ══════════════════════════════════════════════════════════
  // CLEAR ALL
  // ══════════════════════════════════════════════════════════
  Future<void> _clearAllHistory() async {
    final ref = _historyRef;
    if (ref == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Search History'),
        content:
        const Text('Sari search history delete ho jayegi. Sure ho?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    if (!mounted) return;
    setState(() {
      _recentSearches.clear();
      _showAllRecent = false;
    });
    try {
      final snap = await ref.get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) batch.delete(doc.reference);
      await batch.commit();
    } catch (e) {
      debugPrint('Clear all error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  // NAVIGATE TO USER PROFILE
  // ══════════════════════════════════════════════════════════
  void _openUserProfile(Map<String, dynamic> user) {
    final username = user['username'] as String? ?? '';
    final photoUrl = user['photoUrl'] as String? ?? '';
    final userId =
        user['userId'] as String? ?? user['id'] as String? ?? '';

    if (username.isEmpty && userId.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          userId: userId,
          username: username,
          avatarUrl: photoUrl,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // SEARCH TRIGGER
  // ══════════════════════════════════════════════════════════
  void _triggerSearch(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _query = trimmed;
      _showSuggestions = false;
    });
    _performFullSearch(trimmed);
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _showSuggestions = false;
      _suggestions = [];
      _forYouPosts = [];
      _forYouUsers = [];
      _profiles = [];
      _audio = [];
      _tags = [];
      _places = [];
    });
    _focusNode.requestFocus();
  }

  // ══════════════════════════════════════════════════════════
  // ✅ FIX: FULL SEARCH — uses new _searchUsers()
  // ══════════════════════════════════════════════════════════
  Future<void> _performFullSearch(String query) async {
    setState(() => _isSearching = true);
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) {
      setState(() => _isSearching = false);
      return;
    }

    try {
      // ── Users: partial match on all name/username fields ──
      final users = await _searchUsers(query);

      // ── Posts ──
      final postsSnap = await FirebaseFirestore.instance
          .collection('post')
          .limit(50)
          .get();
      final posts = postsSnap.docs.where((d) {
        final caption =
        (d.data()['caption'] as String? ?? '').toLowerCase();
        final hashtags = (d.data()['hashtags'] as List? ?? [])
            .map((e) => e.toString().toLowerCase())
            .toList();
        return caption.contains(lower) ||
            hashtags.any((h) => h.contains(lower));
      }).map((d) => {...d.data(), 'id': d.id}).toList();

      // ── Audio ──
      final audioSnap = await FirebaseFirestore.instance
          .collection('audio')
          .limit(50)
          .get();
      final audioList = audioSnap.docs
          .where((d) => (d.data()['title'] as String? ?? '')
          .toLowerCase()
          .contains(lower))
          .map((d) => {...d.data(), 'id': d.id})
          .toList();

      // ── Tags ──
      final tagsSnap = await FirebaseFirestore.instance
          .collection('hashtags')
          .limit(50)
          .get();
      final tagsList = tagsSnap.docs
          .where((d) => (d.data()['tag'] as String? ?? '')
          .toLowerCase()
          .contains(lower))
          .map((d) => {...d.data(), 'id': d.id})
          .toList();

      // ── Places ──
      final placesSnap = await FirebaseFirestore.instance
          .collection('places')
          .limit(50)
          .get();
      final placesList = placesSnap.docs
          .where((d) => (d.data()['name'] as String? ?? '')
          .toLowerCase()
          .contains(lower))
          .map((d) => {...d.data(), 'id': d.id})
          .toList();

      if (!mounted) return;
      setState(() {
        _profiles = users;
        _forYouUsers = users.take(3).toList();
        _forYouPosts = posts;
        _audio = audioList;
        _tags = tagsList;
        _places = placesList;
        _isSearching = false;
      });

      // Save to history
      final Map<String, dynamic> entryToSave;
      if (users.isNotEmpty) {
        final u = users.first;
        entryToSave = {
          'type': 'user',
          'username':
          (u['username'] as String? ?? query).trim(),
          'name': (u['name'] ??
              u['displayName'] ??
              u['fullName'] ??
              '') as String,
          'photoUrl': (u['photoUrl'] as String? ?? ''),
          'userId': (u['id'] as String? ?? ''),
        };
      } else {
        entryToSave = {
          'type': 'query',
          'username': query.trim(),
          'name': '',
          'photoUrl': '',
          'userId': '',
        };
      }
      await _saveSearchToFirebase(entryToSave);
    } catch (e) {
      debugPrint('Search error: $e');
      if (mounted) setState(() => _isSearching = false);
    }
  }

  // ══════════════════════════════════════════════════════════
  // SUGGESTED USERS
  // ══════════════════════════════════════════════════════════
  Future<void> _fetchSuggestedUsers() async {
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      QuerySnapshot snap;
      try {
        snap = await FirebaseFirestore.instance
            .collection('users')
            .orderBy('createdAt', descending: true)
            .limit(15)
            .get();
      } catch (_) {
        snap = await FirebaseFirestore.instance
            .collection('users')
            .limit(15)
            .get();
      }
      if (!mounted) return;
      final users = snap.docs
          .where((d) => d.id != currentUid)
          .take(5)
          .map((d) =>
      {...d.data() as Map<String, dynamic>, 'id': d.id})
          .toList();
      setState(() => _suggestedUsers = users);
    } catch (e) {
      debugPrint('Suggested users error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  // ✅ FIX: LIVE SUGGESTIONS — partial match
  // ══════════════════════════════════════════════════════════
  Future<void> _fetchLiveSuggestions(String query) async {
    final lower = query.toLowerCase().trim();
    if (lower.isEmpty) return;

    try {
      // Client-side partial match — same _searchUsers logic
      final results = await _searchUsers(query);
      if (!mounted) return;
      setState(() {
        _suggestions = results.take(7).toList();
      });
    } catch (e) {
      debugPrint('Suggestions error: $e');
    }
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isDark),
            Expanded(
              child: _showSuggestions
                  ? _buildSuggestionsList(isDark)
                  : _query.isEmpty
                  ? _buildEmptyState(isDark)
                  : _isSearching
                  ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF0095F6)))
                  : _buildSearchResults(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ── TOP BAR ──────────────────────────────────────────────
  Widget _buildTopBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              if (_query.isNotEmpty || _showSuggestions) {
                _clearSearch();
              } else {
                Navigator.pop(context);
              }
            },
            child: Icon(Icons.arrow_back_ios_new,
                color: isDark ? Colors.white : Colors.black, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: _buildSearchField(isDark)),
          if (_searchController.text.isNotEmpty) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _clearSearch,
              child: Text('Cancel',
                  style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchField(bool isDark) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color:
        isDark ? const Color(0xFF262626) : const Color(0xFFEFEFEF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        style: TextStyle(
            color: isDark ? Colors.white : Colors.black, fontSize: 15),
        textInputAction: TextInputAction.search,
        onSubmitted: _triggerSearch,
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[500],
              fontSize: 15),
          prefixIcon: Icon(Icons.search,
              color: isDark ? Colors.grey[600] : Colors.grey[500],
              size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
            onTap: _clearSearch,
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.grey[600]
                    : Colors.grey[400],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close,
                  color: Colors.white, size: 14),
            ),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // EMPTY STATE
  // ══════════════════════════════════════════════════════════
  Widget _buildEmptyState(bool isDark) {
    if (_isLoadingHistory) {
      return const Center(
          child:
          CircularProgressIndicator(color: Color(0xFF0095F6)));
    }
    final visibleRecent = _showAllRecent
        ? _recentSearches
        : _recentSearches.take(4).toList();

    return RefreshIndicator(
      onRefresh: _loadSearchHistory,
      color: const Color(0xFF0095F6),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_recentSearches.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Recent',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black)),
                  Row(
                    children: [
                      if (_recentSearches.length > 4)
                        GestureDetector(
                          onTap: () => setState(
                                  () => _showAllRecent = !_showAllRecent),
                          child: Text(
                            _showAllRecent ? 'Show less' : 'See all',
                            style: const TextStyle(
                                color: Color(0xFF0095F6),
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                        ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _clearAllHistory,
                        child: const Text('Clear all',
                            style: TextStyle(
                                color: Color(0xFF0095F6),
                                fontWeight: FontWeight.w500,
                                fontSize: 14)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ...visibleRecent.map((r) => _buildRecentTile(r, isDark)),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text('No recent searches',
                  style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.grey[600]
                          : Colors.grey[500])),
            ),
          ],
          if (_suggestedUsers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Text('Suggested for you',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black)),
            ),
            ..._suggestedUsers
                .map((u) => _buildSuggestedUserTile(u, isDark)),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentTile(Map<String, dynamic> r, bool isDark) {
    final isUser = (r['type'] as String? ?? '') == 'user';
    final username = r['username'] as String? ?? '';
    final name = r['name'] as String? ?? '';
    final photoUrl = r['photoUrl'] as String? ?? '';

    return ListTile(
      leading: isUser
          ? CircleAvatar(
        radius: 22,
        backgroundColor: Colors.grey[300],
        backgroundImage: photoUrl.isNotEmpty
            ? NetworkImage(photoUrl)
            : null,
        child: photoUrl.isEmpty
            ? Text(
            username.isNotEmpty
                ? username[0].toUpperCase()
                : 'U',
            style: const TextStyle(
                fontWeight: FontWeight.bold))
            : null,
      )
          : Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: isDark
                  ? Colors.grey[700]!
                  : Colors.grey[300]!),
        ),
        child: Icon(Icons.access_time,
            color: isDark
                ? Colors.grey[400]
                : Colors.grey[600],
            size: 22),
      ),
      title: Text(username,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black)),
      subtitle: name.isNotEmpty
          ? Text(name,
          style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? Colors.grey[500]
                  : Colors.grey[600]))
          : null,
      trailing: GestureDetector(
        onTap: () => _deleteSearchEntry(r),
        child: Icon(Icons.close,
            size: 18,
            color: isDark ? Colors.grey[500] : Colors.grey[500]),
      ),
      onTap: () {
        if (isUser) {
          _openUserProfile(r);
        } else {
          _searchController.text = username;
          _triggerSearch(username);
        }
      },
    );
  }

  Widget _buildSuggestedUserTile(Map<String, dynamic> u, bool isDark) {
    final username = u['username'] as String? ?? '';
    final photoUrl = u['photoUrl'] as String? ?? '';

    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundColor:
        const Color(0xFF0095F6).withOpacity(0.2),
        backgroundImage:
        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
        child: photoUrl.isEmpty
            ? Text(
          username.isNotEmpty
              ? username[0].toUpperCase()
              : 'U',
          style: const TextStyle(
              color: Color(0xFF0095F6),
              fontWeight: FontWeight.bold),
        )
            : null,
      ),
      title: Text(username,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black)),
      subtitle: const Text('Suggested for you',
          style: TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF0095F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Follow',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () =>
                setState(() => _suggestedUsers.remove(u)),
            child: Icon(Icons.close,
                size: 18,
                color: isDark
                    ? Colors.grey[500]
                    : Colors.grey[500]),
          ),
        ],
      ),
      onTap: () => _openUserProfile(u),
    );
  }

  // ── LIVE SUGGESTIONS LIST ─────────────────────────────────
  Widget _buildSuggestionsList(bool isDark) {
    if (_suggestions.isEmpty) {
      return Center(
        child: Text('No results found',
            style: TextStyle(
                color: isDark
                    ? Colors.grey[600]
                    : Colors.grey[400])),
      );
    }
    return ListView.builder(
      itemCount: _suggestions.length,
      itemBuilder: (_, i) {
        final u = _suggestions[i];
        final username = u['username'] as String? ?? '';
        final photoUrl = u['photoUrl'] as String? ?? '';
        // ✅ Show actual name in subtitle (whichever field has it)
        final displayName = (u['name'] as String? ??
            u['displayName'] as String? ??
            u['fullName'] as String? ??
            '')
            .trim();

        return ListTile(
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: Colors.grey[300],
            backgroundImage:
            photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            child: photoUrl.isEmpty
                ? Text(
                username.isNotEmpty
                    ? username[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                    fontWeight: FontWeight.bold))
                : null,
          ),
          title: Text(username,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black)),
          subtitle: displayName.isNotEmpty
              ? Text(displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.grey[500]
                      : Colors.grey[600]))
              : null,
          onTap: () {
            _saveSearchToFirebase({
              'type': 'user',
              'username': username,
              'name': displayName,
              'photoUrl': photoUrl,
              'userId': u['id'] ?? '',
            });
            _openUserProfile(u);
          },
        );
      },
    );
  }

  // ── SEARCH RESULTS ───────────────────────────────────────
  Widget _buildSearchResults(bool isDark) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: isDark ? Colors.white : Colors.black,
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorWeight: 1.5,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'For you'),
            Tab(text: 'Profiles'),
            Tab(text: 'Audio'),
            Tab(text: 'Tags'),
            Tab(text: 'Places'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildForYouTab(isDark),
              _buildProfilesTab(isDark),
              _buildAudioTab(isDark),
              _buildTagsTab(isDark),
              _buildPlacesTab(isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildForYouTab(bool isDark) {
    return ListView(
      children: [
        if (_forYouUsers.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Accounts',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black)),
          ),
          ..._forYouUsers.map((u) => _buildProfileTile(u, isDark)),
        ],
        if (_forYouPosts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Posts',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black)),
          ),
          _buildPostsGrid(isDark),
        ],
        if (_forYouUsers.isEmpty && _forYouPosts.isEmpty)
          _buildNoResults(isDark),
      ],
    );
  }

  Widget _buildProfilesTab(bool isDark) {
    if (_profiles.isEmpty) return _buildNoResults(isDark);
    return ListView.builder(
      itemCount: _profiles.length,
      itemBuilder: (_, i) =>
          _buildProfileTile(_profiles[i], isDark),
    );
  }

  Widget _buildProfileTile(Map<String, dynamic> u, bool isDark) {
    final username = u['username'] as String? ?? '';
    final photoUrl = u['photoUrl'] as String? ?? '';
    final displayName = (u['name'] as String? ??
        u['displayName'] as String? ??
        u['fullName'] as String? ??
        '')
        .trim();

    return ListTile(
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor:
        const Color(0xFF0095F6).withOpacity(0.15),
        backgroundImage:
        photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
        child: photoUrl.isEmpty
            ? Text(
          username.isNotEmpty
              ? username[0].toUpperCase()
              : 'U',
          style: const TextStyle(
              color: Color(0xFF0095F6),
              fontWeight: FontWeight.bold),
        )
            : null,
      ),
      title: Text(username,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: isDark ? Colors.white : Colors.black)),
      subtitle: displayName.isNotEmpty
          ? Text(displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? Colors.grey[500]
                  : Colors.grey[600]))
          : null,
      trailing: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0095F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Follow',
            style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
      onTap: () => _openUserProfile(u),
    );
  }

  Widget _buildAudioTab(bool isDark) {
    final list = _audio.isNotEmpty
        ? _audio
        : [
      {
        'title': '$_query - Original Audio',
        'artist': 'Unknown',
        'reels': '0'
      },
    ];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final a = list[i];
        final coverUrl = a['coverUrl'] as String? ?? '';
        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(6),
            ),
            child: coverUrl.isNotEmpty
                ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(coverUrl,
                    fit: BoxFit.cover))
                : Icon(Icons.music_note,
                color: isDark
                    ? Colors.grey[400]
                    : Colors.grey[600]),
          ),
          title: Text(a['title'] as String? ?? 'Original Audio',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black)),
          subtitle: Text(
              '${a['artist'] ?? ''} • ${a['reels'] ?? '0'} reels',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.grey[500]
                      : Colors.grey[600])),
        );
      },
    );
  }

  Widget _buildTagsTab(bool isDark) {
    final list = _tags.isNotEmpty
        ? _tags
        : [
      {'tag': '#$_query', 'count': '0'},
    ];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final t = list[i];
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            child: Center(
              child: Text('#',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: isDark ? Colors.white : Colors.black)),
            ),
          ),
          title: Text(t['tag'] as String? ?? '',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black)),
          subtitle: Text('${t['count'] ?? '0'} posts',
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.grey[500]
                      : Colors.grey[600])),
        );
      },
    );
  }

  Widget _buildPlacesTab(bool isDark) {
    final list = _places.isNotEmpty
        ? _places
        : [
      {'name': _query, 'address': ''},
    ];
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final p = list[i];
        final address = p['address'] as String? ?? '';
        return ListTile(
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.grey[800] : Colors.grey[200],
            ),
            child: Icon(Icons.location_on,
                color: isDark
                    ? Colors.grey[400]
                    : Colors.grey[600]),
          ),
          title: Text(p['name'] as String? ?? '',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black)),
          subtitle: address.isNotEmpty
              ? Text(address,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? Colors.grey[500]
                      : Colors.grey[600]))
              : null,
        );
      },
    );
  }

  Widget _buildPostsGrid(bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(1),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _forYouPosts.length,
      itemBuilder: (_, i) {
        final p = _forYouPosts[i];
        final imageUrl = p['imageUrl'] as String? ?? '';
        return GestureDetector(
          onTap: () {},
          child: Container(
            color: isDark ? Colors.grey[850] : Colors.grey[200],
            child: imageUrl.isNotEmpty && imageUrl != 'no-image'
                ? Image.network(imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image,
                    color: Colors.grey))
                : Center(
              child: Text(
                p['caption'] as String? ?? '',
                maxLines: 3,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 10,
                    color: isDark
                        ? Colors.white70
                        : Colors.black54),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoResults(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 60,
              color: isDark
                  ? Colors.white24
                  : Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No results for "$_query"',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 15)),
          const SizedBox(height: 4),
          Text('Try searching for something else',
              style: TextStyle(
                  color: isDark
                      ? Colors.grey[600]
                      : Colors.grey[500],
                  fontSize: 13)),
        ],
      ),
    );
  }
}