import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

// ==========================================
// SONG MODEL
// ==========================================
// Deezer public search API ke around banaya gaya hai. Koi API key /
// authentication nahi chahiye — endpoint: https://api.deezer.com/search
// Har track ke saath ek 30-second `preview` MP3 URL milta hai jo aap
// reliably play kar sakte hain aur ffmpeg se video ke saath mix bhi kar
// sakte hain.
class SongModel {
  final String id;
  final String title;
  final String artist;
  final String albumArt;
  final String previewUrl; // 30 sec free MP3 preview (Deezer-hosted)
  final int durationMs;
  // Optional trim window — user picks which part of the 30-sec preview to use
  // (TikTok-style). Default = full preview. Both inclusive, in milliseconds
  // from start of the preview file.
  final int startMs;
  final int endMs;

  SongModel({
    required this.id,
    required this.title,
    required this.artist,
    required this.albumArt,
    required this.previewUrl,
    required this.durationMs,
    this.startMs = 0,
    int? endMs,
  }) : endMs = endMs ?? durationMs;

  int get trimDurationMs => (endMs - startMs).clamp(1, durationMs);

  SongModel copyWithTrim({required int startMs, required int endMs}) =>
      SongModel(
        id: id,
        title: title,
        artist: artist,
        albumArt: albumArt,
        previewUrl: previewUrl,
        durationMs: durationMs,
        startMs: startMs,
        endMs: endMs,
      );

  factory SongModel.fromDeezerJson(Map<String, dynamic> json) {
    final album = json['album'] as Map<String, dynamic>?;
    final artist = json['artist'] as Map<String, dynamic>?;
    return SongModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: artist?['name']?.toString() ?? '',
      albumArt: album?['cover_medium']?.toString() ??
          album?['cover']?.toString() ??
          '',
      previewUrl: json['preview']?.toString() ?? '',
      // Deezer preview file is fixed 30s regardless of full track length —
      // RangeSlider isi 30s ke andar move karega.
      durationMs: 30000,
    );
  }

  // Firestore mein post/story doc ke saath inline save karne ke liye —
  // is map ke keys directly post document mein spread ho jayenge.
  Map<String, dynamic> toFirestoreMap() => {
        'songId': id,
        'songTitle': title,
        'songArtist': artist,
        'songAlbumArt': albumArt,
        'songPreviewUrl': previewUrl,
        'songDurationMs': durationMs,
        'songStartMs': startMs,
        'songEndMs': endMs,
      };
}

// ==========================================
// DEEZER SERVICE — SEARCH (no auth required)
// ==========================================
class DeezerService {
  static const _base = 'https://api.deezer.com';
  static const _pageSize = 25;

  // Single query, single page. `index` = offset (Deezer pagination).
  static Future<List<SongModel>> search(
    String query, {
    int index = 0,
    int limit = _pageSize,
  }) async {
    try {
      final url = Uri.parse(
        '$_base/search?q=${Uri.encodeQueryComponent(query)}&index=$index&limit=$limit',
      );
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final tracks = (data['data'] as List?) ?? const [];
        return tracks
            .whereType<Map<String, dynamic>>()
            .map(SongModel.fromDeezerJson)
            .where((s) => s.previewUrl.isNotEmpty)
            .toList();
      } else {
        debugPrint(
            'Deezer search failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      debugPrint('Deezer search error: $e');
    }
    return [];
  }

  // MULTIPLE queries ko parallel chalao aur unique results merge karo.
  // Yeh category ka real "variety" deta hai — ek hi song ke half-half
  // versions ki jagah alag-alag tracks aate hain.
  static Future<List<SongModel>> searchMulti(
    List<String> queries, {
    int index = 0,
    int limitPerQuery = _pageSize,
  }) async {
    final results = await Future.wait(
      queries.map((q) => search(q, index: index, limit: limitPerQuery)),
    );

    // Dedupe by (title + artist) — Deezer akser same song ke multiple
    // re-uploads return karta hai. Same id bhi katam.
    final seen = <String>{};
    final merged = <SongModel>[];
    for (final list in results) {
      for (final s in list) {
        final key = '${s.title.toLowerCase().trim()}|'
            '${s.artist.toLowerCase().trim()}';
        if (seen.add(key) && seen.add('id:${s.id}')) {
          merged.add(s);
        }
      }
    }

    // Shuffle so har query ke songs interleave hon — ek hi artist back-to-back
    // na aaye. Deterministic-ish: title hash se sort.
    merged.sort((a, b) => a.title.hashCode.compareTo(b.title.hashCode));
    return merged;
  }

  // Backward-compat alias.
  static Future<List<SongModel>> getTrending(String query) => search(query);
}

// ==========================================
// MUSIC PICKER SCREEN
// ==========================================
class MusicPickerScreen extends StatefulWidget {
  /// Jab user song select kare tou yeh callback chale ga
  final Function(SongModel) onSongSelected;

  const MusicPickerScreen({super.key, required this.onSongSelected});

  @override
  State<MusicPickerScreen> createState() => _MusicPickerScreenState();
}

class _MusicPickerScreenState extends State<MusicPickerScreen> {
  final _searchController = TextEditingController();
  final _audioPlayer = AudioPlayer();
  final _debouncer = _Debouncer(milliseconds: 600);
  final _scrollController = ScrollController();

  List<SongModel> _songs = [];
  bool _isLoading = false;       // first page loading
  bool _isLoadingMore = false;   // appending next page
  bool _hasMore = true;          // no more results from API
  bool _isSearching = false;
  String? _playingId;
  String _selectedCategory = 'Trending';

  // Active queries set (for the selected category or free-text search) and
  // the current page index used for Deezer's `&index=` pagination.
  List<String> _activeQueries = const ['top hits'];
  int _pageIndex = 0;

  // Category -> queries. Multiple queries per category taake variety mile
  // aur ek hi song ke half-half versions na aayein. Language-specific terms
  // (urdu, punjabi, hindi, korean, mandarin) Deezer ke pas reliably alag
  // tracks return karte hain.
  final _categories = <Map<String, dynamic>>[
    {
      'label': 'Trending',
      'queries': ['top hits 2025', 'global top', 'viral songs', 'tiktok hits'],
    },
    {
      'label': 'Pakistan',
      'queries': [
        'urdu songs',
        'punjabi pakistani',
        'coke studio pakistan',
        'atif aslam',
        'rahat fateh ali khan',
        'pakistani pop',
      ],
    },
    {
      'label': 'Bollywood',
      'queries': [
        'hindi songs',
        'bollywood hits',
        'arijit singh',
        'shreya ghoshal',
        'bollywood romantic',
        'hindi new songs',
      ],
    },
    {
      'label': 'K-Pop',
      'queries': ['kpop', 'bts', 'blackpink', 'kpop hits', 'korean pop'],
    },
    {
      'label': 'Arabic',
      'queries': ['arabic songs', 'arabic pop', 'amr diab', 'arabic hits'],
    },
    {
      'label': 'English',
      'queries': ['english pop', 'top english hits', 'billboard hot', 'pop songs'],
    },
    {
      'label': 'German',
      'queries': ['deutsch pop', 'german songs', 'deutsch rap', 'schlager'],
    },
    {
      'label': 'Korean',
      'queries': ['korean songs', 'korean ballad', 'k-drama ost', 'korean indie'],
    },
    {
      'label': 'Chinese',
      'queries': ['mandopop', 'chinese songs', 'cantopop', 'jay chou', 'mandarin pop'],
    },
  ];

  static const List<String> _defaultQueries = ['top hits 2025', 'viral songs'];

  @override
  void initState() {
    super.initState();
    _activeQueries = _defaultQueries;
    _loadFirst();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // Jab user list ke 80% tak pohanch jaye, agla page laao.
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadFirst() async {
    setState(() {
      _isLoading = true;
      _pageIndex = 0;
      _hasMore = true;
      _songs = [];
    });
    final results = await DeezerService.searchMulti(
      _activeQueries,
      index: 0,
    );
    if (mounted) {
      setState(() {
        _songs = results;
        _isLoading = false;
        _hasMore = results.isNotEmpty;
        _pageIndex = DeezerService._pageSize;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    final next = await DeezerService.searchMulti(
      _activeQueries,
      index: _pageIndex,
    );

    // Dedupe against songs already shown.
    final existing = _songs.map((s) => s.id).toSet();
    final fresh = next.where((s) => !existing.contains(s.id)).toList();

    if (mounted) {
      setState(() {
        _songs = [..._songs, ...fresh];
        _isLoadingMore = false;
        // Agar fresh empty hai — chances are Deezer done. Lekin agar dedupe
        // se khali hua (sare duplicates), tab bhi index aage badhao taake
        // next page try ho sake.
        if (next.isEmpty) {
          _hasMore = false;
        } else {
          _pageIndex += DeezerService._pageSize;
        }
      });
    }
  }

  void _onSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _selectedCategory = 'Trending';
        _activeQueries = _defaultQueries;
      });
      _loadFirst();
      return;
    }
    _debouncer.run(() {
      setState(() {
        _isSearching = true;
        _activeQueries = [query];
      });
      _loadFirst();
    });
  }

  Future<void> _togglePlay(SongModel song) async {
    if (_playingId == song.id) {
      await _audioPlayer.stop();
      setState(() => _playingId = null);
    } else {
      await _audioPlayer.stop();
      if (song.previewUrl.isNotEmpty) {
        await _audioPlayer.play(UrlSource(song.previewUrl));
        setState(() => _playingId = song.id);
        // 30 sec baad auto stop
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted && _playingId == song.id) {
            setState(() => _playingId = null);
            _audioPlayer.stop();
          }
        });
      }
    }
  }

  void _selectSong(SongModel song) async {
    await _audioPlayer.stop();
    if (mounted) setState(() => _playingId = null);
    widget.onSongSelected(song);
    if (mounted) Navigator.of(context).pop(song);
  }

  // TikTok-style trim sheet — user 30-sec preview ke andar window pick karta
  // hai. Sheet "Use this part" return karta hai to wo trimmed song select
  // ho jata hai; cancel karne par kuch nahi hota.
  Future<void> _openTrimmer(SongModel song) async {
    // List ka apna preview band karo taake do players ek saath na chalein.
    await _audioPlayer.stop();
    if (mounted) setState(() => _playingId = null);

    final trimmed = await showModalBottomSheet<SongModel>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SongTrimmerSheet(song: song),
    );
    if (trimmed != null && mounted) {
      widget.onSongSelected(trimmed);
      Navigator.of(context).pop(trimmed);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Add Music',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearch,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search songs, artists...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () {
                    _searchController.clear();
                    _onSearch('');
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Category Tabs
          if (!_isSearching)
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  final isSelected = _selectedCategory == cat['label'];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategory = cat['label'] as String;
                        _isSearching = false;
                        _activeQueries =
                            List<String>.from(cat['queries'] as List);
                      });
                      _loadFirst();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.greenAccent[400]
                            : Colors.grey[850],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cat['label'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

          const SizedBox(height: 10),

          // Songs List
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: Colors.greenAccent,
              ),
            )
                : _songs.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off,
                      color: Colors.grey[700], size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No songs found',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              // +1 for the loader / "end" footer at the bottom.
              itemCount: _songs.length + 1,
              itemBuilder: (context, index) {
                // Footer slot
                if (index == _songs.length) {
                  if (_isLoadingMore) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.greenAccent,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    );
                  }
                  if (!_hasMore) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          '— end of list —',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 12),
                        ),
                      ),
                    );
                  }
                  return const SizedBox(height: 24);
                }

                final song = _songs[index];
                final isPlaying = _playingId == song.id;

                // No parent InkWell — har section ka apna gesture handler:
                //   • album art + title/artist tap  → trimmer sheet
                //   • play button tap               → preview toggle
                //   • "Add" button tap              → direct select
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      // Album art + info area → trimmer sheet
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _openTrimmer(song),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: song.albumArt.isNotEmpty
                                    ? Image.network(
                                  song.albumArt,
                                  width: 54,
                                  height: 54,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _placeholderArt(),
                                )
                                    : _placeholderArt(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      song.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      song.artist,
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Play preview button — sirf preview play/pause, song
                      // select nahi karta. HitTestBehavior.opaque taake row ke
                      // baqi gestures yahan se na nikle.
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _togglePlay(song),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isPlaying
                                ? Colors.greenAccent[400]
                                : Colors.grey[800],
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: isPlaying ? Colors.black : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Add button → direct select (no trimming, full preview).
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _selectSong(song),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.pinkAccent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Add',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderArt() {
    return Container(
      width: 54,
      height: 54,
      color: Colors.grey[850],
      child: const Icon(Icons.music_note, color: Colors.grey),
    );
  }
}

// ==========================================
// DEBOUNCER — search delay ke liye
// ==========================================
class _Debouncer {
  final int milliseconds;
  Timer? _timer;

  _Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}

// ==========================================
// SONG TRIMMER BOTTOM SHEET — TikTok jaisa
// ==========================================
// 30-sec Deezer preview ke andar user start/end window pick karta hai.
// RangeSlider thumbs drag karte hi audio us position se play hota hai
// taake user beat sun ke decide kar sake. "Use this part" press se
// trimmed SongModel return hota hai.
class _SongTrimmerSheet extends StatefulWidget {
  final SongModel song;
  const _SongTrimmerSheet({required this.song});

  @override
  State<_SongTrimmerSheet> createState() => _SongTrimmerSheetState();
}

class _SongTrimmerSheetState extends State<_SongTrimmerSheet> {
  final _player = AudioPlayer();
  late RangeValues _range;
  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _currentPos = Duration.zero;
  StreamSubscription<Duration>? _posSub;
  Timer? _loopTimer;

  // Minimum trim window — bohot chhota cut karne se kuch sunai nahi deta.
  static const int _minWindowMs = 3000;

  @override
  void initState() {
    super.initState();
    _range = RangeValues(
      widget.song.startMs.toDouble(),
      widget.song.endMs.toDouble(),
    );
    _prepareAudio();
  }

  Future<void> _prepareAudio() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setSourceUrl(widget.song.previewUrl);
      _posSub = _player.onPositionChanged.listen((d) {
        if (!mounted) return;
        setState(() => _currentPos = d);
        // Loop within trim window — agar end ms cross ho gaya, start par seek.
        if (_isPlaying && d.inMilliseconds >= _range.end.toInt()) {
          _player.seek(Duration(milliseconds: _range.start.toInt()));
        }
      });
      _player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() => _isPlaying = false);
      });
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Trimmer audio prepare error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _togglePlay() async {
    if (_isLoading) return;
    try {
      if (_isPlaying) {
        await _player.pause();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        await _player.seek(Duration(milliseconds: _range.start.toInt()));
        await _player.resume();
        if (mounted) setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint('Trimmer play error: $e');
    }
  }

  void _onRangeChanged(RangeValues v) {
    // Minimum window enforce karo.
    double start = v.start;
    double end = v.end;
    if (end - start < _minWindowMs) {
      // Jis thumb ko user move kar raha hai usko hi adjust karo.
      if (v.start != _range.start) {
        start = (end - _minWindowMs).clamp(0, end);
      } else {
        end = (start + _minWindowMs).clamp(start, widget.song.durationMs.toDouble());
      }
    }
    setState(() => _range = RangeValues(start, end));
    // Jab user start handle drag kare to audio us position se shuru kar do.
    if (v.start != _range.start && _isPlaying) {
      _player.seek(Duration(milliseconds: start.toInt()));
    }
  }

  String _fmt(int ms) {
    final s = (ms / 1000).floor();
    final m = s ~/ 60;
    final ss = (s % 60).toString().padLeft(2, '0');
    return '$m:$ss';
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _loopTimer?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dur = widget.song.durationMs.toDouble();
    final song = widget.song;
    final windowMs = (_range.end - _range.start).toInt();

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header: album art + title/artist + close
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: song.albumArt.isNotEmpty
                    ? Image.network(song.albumArt,
                        width: 56, height: 56, fit: BoxFit.cover)
                    : Container(
                        width: 56,
                        height: 56,
                        color: Colors.grey[800],
                        child: const Icon(Icons.music_note, color: Colors.grey),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Play/Pause + selected window duration
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: _togglePlay,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isPlaying
                        ? Colors.greenAccent[400]
                        : const Color(0xFF0095F6),
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: _isPlaying ? Colors.black : Colors.white,
                          size: 28,
                        ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Selected: ${_fmt(windowMs)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_fmt(_range.start.toInt())} → ${_fmt(_range.end.toInt())}',
                    style:
                        TextStyle(color: Colors.grey[400], fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Waveform-ish background + range slider
          Stack(
            alignment: Alignment.center,
            children: [
              // Fake waveform bars for visual context (real waveform extraction
              // hota to file decode karna padta — preview ke liye yeh enough).
              SizedBox(
                height: 56,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(40, (i) {
                    final h = 8.0 + (i * 7 % 40);
                    final inWindow = (i / 40) * dur >= _range.start &&
                        (i / 40) * dur <= _range.end;
                    return Container(
                      width: 3,
                      height: h,
                      decoration: BoxDecoration(
                        color: inWindow
                            ? const Color(0xFF0095F6)
                            : Colors.grey[700],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
              // Playback position indicator
              if (_isPlaying)
                Positioned(
                  left: ((_currentPos.inMilliseconds.clamp(0, dur.toInt())) /
                          dur) *
                      (MediaQuery.of(context).size.width - 32),
                  child: Container(
                    width: 2,
                    height: 56,
                    color: Colors.white,
                  ),
                ),
              // Actual range slider on top
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  rangeThumbShape: const RoundRangeSliderThumbShape(
                      enabledThumbRadius: 10),
                  rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
                  trackHeight: 4,
                  activeTrackColor: const Color(0xFF0095F6),
                  inactiveTrackColor: Colors.transparent,
                  overlayColor: const Color(0xFF0095F6).withOpacity(0.2),
                ),
                child: RangeSlider(
                  values: _range,
                  min: 0,
                  max: dur,
                  onChanged: _onRangeChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Time markers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0:00',
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 11)),
                Text(_fmt(widget.song.durationMs),
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // "Use this part" CTA
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                final trimmed = widget.song.copyWithTrim(
                  startMs: _range.start.toInt(),
                  endMs: _range.end.toInt(),
                );
                Navigator.of(context).pop(trimmed);
              },
              child: const Text(
                'Use this part',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// APNI REEL SCREEN MEIN AISE USE KARO:
// ==========================================
//
// SongModel? _selectedSong;
//
// GestureDetector(
//   onTap: () async {
//     await Navigator.push<SongModel>(
//       context,
//       MaterialPageRoute(
//         builder: (_) => MusicPickerScreen(
//           onSongSelected: (song) {
//             setState(() => _selectedSong = song);
//           },
//         ),
//       ),
//     );
//   },
//   child: Row(children: [
//     const Icon(Icons.music_note, color: Colors.white),
//     const SizedBox(width: 8),
//     Text(
//       _selectedSong?.title ?? 'Add Song',
//       style: const TextStyle(color: Colors.white),
//     ),
//   ]),
// )