// ============================================================
// create_content_screen.dart  — VIDEO THUMBNAIL FIX + POLL + STICKER FEATURE
// ============================================================
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wego_marriage/services/cloudinary_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart' as vt;
import 'package:wego_marriage/services/local_storage_service.dart';
import 'xp_service.dart';
import 'app_localizations.dart';
import 'app_translations.dart';
// ─── Enums ───────────────────────────────────────────────────
enum ContentMode { post, story, reel }

enum PostVisibility { everyone, onlyMe, closeFriends }

// ─── Color Filter Model ──────────────────────────────────────
class PhotoFilter {
  final String name;
  final ColorFilter? colorFilter;
  const PhotoFilter({required this.name, this.colorFilter});
}

// ✅ POLL: Poll Model
class PollData {
  final String question;
  final List<String> options;

  const PollData({required this.question, required this.options});

  Map<String, dynamic> toMap() => {
    'question': question,
    'options': options,
    'votes': {for (var o in options) o: 0},
    'voters': {},
  };
}
class TaggedUser {
  final String uid;
  final String username;
  final String displayName;
  final String photoUrl;

  const TaggedUser({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.photoUrl,
  });
}
// ✅ STICKER: Sticker Model
class StickerItem {
  final String emoji;
  final String label;
  final String category;

  const StickerItem({
    required this.emoji,
    required this.label,
    required this.category,
  });
}

// ✅ STICKER: All sticker categories and data
class StickerData {
  static const List<String> categories = [
    'All', 'Love', 'Wedding', 'Celebration', 'Nature', 'Food', 'Travel', 'Expressions'
  ];

  static const List<StickerItem> allStickers = [
    // Love
    StickerItem(emoji: '❤️', label: 'Heart', category: 'Love'),
    StickerItem(emoji: '💕', label: 'Two Hearts', category: 'Love'),
    StickerItem(emoji: '💖', label: 'Sparkling Heart', category: 'Love'),
    StickerItem(emoji: '💗', label: 'Growing Heart', category: 'Love'),
    StickerItem(emoji: '💘', label: 'Arrow Heart', category: 'Love'),
    StickerItem(emoji: '💝', label: 'Ribbon Heart', category: 'Love'),
    StickerItem(emoji: '💞', label: 'Revolving Hearts', category: 'Love'),
    StickerItem(emoji: '💓', label: 'Beating Heart', category: 'Love'),
    StickerItem(emoji: '🥰', label: 'Smiling with Hearts', category: 'Love'),
    StickerItem(emoji: '😍', label: 'Heart Eyes', category: 'Love'),
    StickerItem(emoji: '😘', label: 'Kiss', category: 'Love'),
    StickerItem(emoji: '💋', label: 'Kiss Mark', category: 'Love'),

    // Wedding
    StickerItem(emoji: '💍', label: 'Ring', category: 'Wedding'),
    StickerItem(emoji: '👰', label: 'Bride', category: 'Wedding'),
    StickerItem(emoji: '🤵', label: 'Groom', category: 'Wedding'),
    StickerItem(emoji: '💒', label: 'Wedding', category: 'Wedding'),
    StickerItem(emoji: '🎂', label: 'Wedding Cake', category: 'Wedding'),
    StickerItem(emoji: '🥂', label: 'Champagne', category: 'Wedding'),
    StickerItem(emoji: '🌹', label: 'Rose', category: 'Wedding'),
    StickerItem(emoji: '💐', label: 'Bouquet', category: 'Wedding'),
    StickerItem(emoji: '👫', label: 'Couple', category: 'Wedding'),
    StickerItem(emoji: '👨‍👩‍👧', label: 'Family', category: 'Wedding'),
    StickerItem(emoji: '🕊️', label: 'Dove', category: 'Wedding'),
    StickerItem(emoji: '✨', label: 'Sparkles', category: 'Wedding'),

    // Celebration
    StickerItem(emoji: '🎉', label: 'Party Popper', category: 'Celebration'),
    StickerItem(emoji: '🎊', label: 'Confetti', category: 'Celebration'),
    StickerItem(emoji: '🎈', label: 'Balloon', category: 'Celebration'),
    StickerItem(emoji: '🎁', label: 'Gift', category: 'Celebration'),
    StickerItem(emoji: '🏆', label: 'Trophy', category: 'Celebration'),
    StickerItem(emoji: '🥳', label: 'Party Face', category: 'Celebration'),
    StickerItem(emoji: '🎶', label: 'Music', category: 'Celebration'),
    StickerItem(emoji: '🎵', label: 'Note', category: 'Celebration'),
    StickerItem(emoji: '⭐', label: 'Star', category: 'Celebration'),
    StickerItem(emoji: '🌟', label: 'Glowing Star', category: 'Celebration'),
    StickerItem(emoji: '🎯', label: 'Target', category: 'Celebration'),
    StickerItem(emoji: '🎀', label: 'Ribbon', category: 'Celebration'),

    // Nature
    StickerItem(emoji: '🌸', label: 'Cherry Blossom', category: 'Nature'),
    StickerItem(emoji: '🌺', label: 'Hibiscus', category: 'Nature'),
    StickerItem(emoji: '🌼', label: 'Blossom', category: 'Nature'),
    StickerItem(emoji: '🌻', label: 'Sunflower', category: 'Nature'),
    StickerItem(emoji: '🍀', label: 'Clover', category: 'Nature'),
    StickerItem(emoji: '🌈', label: 'Rainbow', category: 'Nature'),
    StickerItem(emoji: '☀️', label: 'Sun', category: 'Nature'),
    StickerItem(emoji: '🌙', label: 'Moon', category: 'Nature'),
    StickerItem(emoji: '⚡', label: 'Lightning', category: 'Nature'),
    StickerItem(emoji: '🦋', label: 'Butterfly', category: 'Nature'),
    StickerItem(emoji: '🐦', label: 'Bird', category: 'Nature'),
    StickerItem(emoji: '🌿', label: 'Herb', category: 'Nature'),

    // Food
    StickerItem(emoji: '🍕', label: 'Pizza', category: 'Food'),
    StickerItem(emoji: '🍔', label: 'Burger', category: 'Food'),
    StickerItem(emoji: '🍜', label: 'Noodles', category: 'Food'),
    StickerItem(emoji: '🍣', label: 'Sushi', category: 'Food'),
    StickerItem(emoji: '🍩', label: 'Donut', category: 'Food'),
    StickerItem(emoji: '🍦', label: 'Ice Cream', category: 'Food'),
    StickerItem(emoji: '☕', label: 'Coffee', category: 'Food'),
    StickerItem(emoji: '🧁', label: 'Cupcake', category: 'Food'),
    StickerItem(emoji: '🍰', label: 'Cake Slice', category: 'Food'),
    StickerItem(emoji: '🍓', label: 'Strawberry', category: 'Food'),
    StickerItem(emoji: '🍇', label: 'Grapes', category: 'Food'),
    StickerItem(emoji: '🥑', label: 'Avocado', category: 'Food'),

    // Travel
    StickerItem(emoji: '✈️', label: 'Airplane', category: 'Travel'),
    StickerItem(emoji: '🏖️', label: 'Beach', category: 'Travel'),
    StickerItem(emoji: '🏔️', label: 'Mountain', category: 'Travel'),
    StickerItem(emoji: '🗺️', label: 'Map', category: 'Travel'),
    StickerItem(emoji: '🌍', label: 'Globe', category: 'Travel'),
    StickerItem(emoji: '🏕️', label: 'Camping', category: 'Travel'),
    StickerItem(emoji: '🚢', label: 'Ship', category: 'Travel'),
    StickerItem(emoji: '🎡', label: 'Ferris Wheel', category: 'Travel'),
    StickerItem(emoji: '🗼', label: 'Tower', category: 'Travel'),
    StickerItem(emoji: '🏝️', label: 'Island', category: 'Travel'),
    StickerItem(emoji: '🚀', label: 'Rocket', category: 'Travel'),
    StickerItem(emoji: '🌅', label: 'Sunrise', category: 'Travel'),

    // Expressions
    StickerItem(emoji: '😂', label: 'Laughing', category: 'Expressions'),
    StickerItem(emoji: '😎', label: 'Cool', category: 'Expressions'),
    StickerItem(emoji: '🤩', label: 'Star Struck', category: 'Expressions'),
    StickerItem(emoji: '😇', label: 'Angel', category: 'Expressions'),
    StickerItem(emoji: '🤔', label: 'Thinking', category: 'Expressions'),
    StickerItem(emoji: '😴', label: 'Sleeping', category: 'Expressions'),
    StickerItem(emoji: '🤗', label: 'Hugging', category: 'Expressions'),
    StickerItem(emoji: '😤', label: 'Determined', category: 'Expressions'),
    StickerItem(emoji: '🙌', label: 'Raise Hands', category: 'Expressions'),
    StickerItem(emoji: '👏', label: 'Clapping', category: 'Expressions'),
    StickerItem(emoji: '🤝', label: 'Handshake', category: 'Expressions'),
    StickerItem(emoji: '👍', label: 'Thumbs Up', category: 'Expressions'),
  ];

  static List<StickerItem> getByCategory(String category) {
    if (category == 'All') return allStickers;
    return allStickers.where((s) => s.category == category).toList();
  }
}

// ─────────────────────────────────────────────────────────────
//  Helper: show an image from XFile (web-safe)
// ─────────────────────────────────────────────────────────────
class _XFileImage extends StatefulWidget {
  final XFile file;
  final BoxFit fit;
  const _XFileImage({required this.file, this.fit = BoxFit.cover});

  @override
  State<_XFileImage> createState() => _XFileImageState();
}

class _XFileImageState extends State<_XFileImage> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await widget.file.readAsBytes();
    if (mounted) setState(() => _bytes = b);
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes == null) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    return Image.memory(_bytes!, fit: widget.fit);
  }
}

// ─── Main Entry Screen ───────────────────────────────────────
class CreateContentScreen extends StatefulWidget {
  final ContentMode initialMode;
  const CreateContentScreen({super.key, this.initialMode = ContentMode.post});

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  late ContentMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showMediaPickerSheet());
  }

  void _showMediaPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _MediaPickerSheet(
        mode: _mode,
        onModeChanged: (m) => setState(() => _mode = m),
        onMediaSelected: (file, isVideo) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _MediaEditorScreen(
                file: file,
                isVideo: isVideo,
                mode: _mode,
              ),
            ),
          );
        },
        onTextSelected: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _TextCreatorScreen(mode: _mode),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, color: Colors.white54, size: 60),
            const SizedBox(height: 16),
            Text(context.tr('opening_camera'), style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 24),
            TextButton(
              onPressed: _showMediaPickerSheet,
              child: Text(context.tr('choose_media'), style: TextStyle(color: Colors.blue, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Media Picker Sheet ───────────────────────────────────────
class _MediaPickerSheet extends StatefulWidget {
  final ContentMode mode;
  final ValueChanged<ContentMode> onModeChanged;
  final Function(XFile file, bool isVideo) onMediaSelected;
  final VoidCallback onTextSelected;

  const _MediaPickerSheet({
    required this.mode,
    required this.onModeChanged,
    required this.onMediaSelected,
    required this.onTextSelected,
  });

  @override
  State<_MediaPickerSheet> createState() => _MediaPickerSheetState();
}

class _MediaPickerSheetState extends State<_MediaPickerSheet>
    with WidgetsBindingObserver {
  late ContentMode _mode;
  final ImagePicker _picker = ImagePicker();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _cameraPermissionGranted = false;
  bool _cameraInitialized = false;
  bool _isFrontCamera = false;
  bool _isCameraLoading = true;
  bool _isCapturing = false;
  bool _isRecording = false;
  bool _alsoShareEnabled = false;

  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 1.0;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb) _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _startCamera(_cameras[_isFrontCamera ? 1 : 0]);
    }
  }

  Future<void> _initCamera() async {
    setState(() => _isCameraLoading = true);
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (mounted)
        setState(() {
          _cameraPermissionGranted = false;
          _isCameraLoading = false;
        });
      return;
    }
    _cameraPermissionGranted = true;
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _isCameraLoading = false);
        return;
      }
      final camIndex = _isFrontCamera && _cameras.length > 1 ? 1 : 0;
      await _startCamera(_cameras[camIndex]);
    } catch (e) {
      debugPrint('Camera init error: $e');
      if (mounted) setState(() => _isCameraLoading = false);
    }
  }

  Future<void> _startCamera(CameraDescription camera) async {
    await _cameraController?.dispose();
    _cameraController = null;
    if (mounted)
      setState(() {
        _cameraInitialized = false;
        _isCameraLoading = true;
      });
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    _cameraController = controller;
    try {
      await controller.initialize();
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      if (mounted) {
        setState(() {
          _cameraInitialized = true;
          _isCameraLoading = false;
          _minZoom = minZoom;
          _maxZoom = maxZoom;
          _currentZoom = minZoom;
          _baseZoom = minZoom;
        });
      }
    } catch (e) {
      debugPrint('Camera start error: $e');
      if (mounted) setState(() => _isCameraLoading = false);
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    _isFrontCamera = !_isFrontCamera;
    await _startCamera(_cameras[_isFrontCamera ? 1 : 0]);
  }

  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraInitialized || _isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final file = await _cameraController!.takePicture();
      if (mounted) widget.onMediaSelected(file, false);
    } catch (e) {
      debugPrint('Take photo error: $e');
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  Future<void> _startVideoRecording() async {
    if (_cameraController == null || !_cameraInitialized || _isRecording) return;
    try {
      final audioStatus = await Permission.microphone.request();
      if (!audioStatus.isGranted) return;
      await _cameraController!.startVideoRecording();
      if (mounted) setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('Start video error: $e');
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_cameraController == null || !_isRecording) return;
    try {
      final file = await _cameraController!.stopVideoRecording();
      if (mounted) {
        setState(() => _isRecording = false);
        widget.onMediaSelected(file, true);
      }
    } catch (e) {
      debugPrint('Stop video error: $e');
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _pickFromGallery() async {
    if (_mode == ContentMode.reel) {
      final file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null && mounted) widget.onMediaSelected(file, true);
    } else {
      _showPickTypeSheet();
    }
  }

  Future<void> _pickImage() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null && mounted) widget.onMediaSelected(file, false);
  }

  Future<void> _pickVideo() async {
    final file = await _picker.pickVideo(source: ImageSource.gallery);
    if (file != null && mounted) widget.onMediaSelected(file, true);
  }

  void _showPickTypeSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            _sheetTile(Icons.image, context.tr('photo'), () async {
              Navigator.pop(ctx);
              await _pickImage();
            }),
            _sheetTile(Icons.videocam, context.tr('video'), () async {
              Navigator.pop(ctx);
              await _pickVideo();
            }),
            _sheetTile(Icons.text_fields, context.tr('text'), () {
              Navigator.pop(ctx);
              widget.onTextSelected();
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 16)),
      onTap: onTap,
    );
  }

  Widget _buildCameraPreview() {
    if (kIsWeb) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, color: Colors.white24, size: 80),
            const SizedBox(height: 16),
            Text(
              context.tr('camera_web_not_available'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white38, fontSize: 14),
            ),
          ],
        ),
      );
    }
    if (_isCameraLoading) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white54));
    }
    if (!_cameraPermissionGranted) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography, color: Colors.white38, size: 64),
            const SizedBox(height: 16),
            Text(context.tr('camera_permission_denied'),
                style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async => await openAppSettings(),
              child: Text(context.tr('go_to_settings'),
                  style: const TextStyle(color: Colors.blue, fontSize: 15)),
            ),
          ],
        ),
      );
    }
    if (!_cameraInitialized || _cameraController == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt, color: Colors.white24, size: 64),
            const SizedBox(height: 12),
            Text(context.tr('camera_failed_to_start'),
                style: TextStyle(color: Colors.white38, fontSize: 14)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _initCamera,
              child: Text(context.tr('try_again'),
                  style: const TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onScaleStart: (_) => _baseZoom = _currentZoom,
      onScaleUpdate: (details) async {
        if (_cameraController == null || !_cameraInitialized) return;
        final newZoom =
        (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
        if ((newZoom - _currentZoom).abs() < 0.01) return;
        _currentZoom = newZoom;
        await _cameraController!.setZoomLevel(_currentZoom);
        if (mounted) setState(() {});
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: OverflowBox(
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _cameraController!.value.previewSize?.height ?? 100,
                  height: _cameraController!.value.previewSize?.width ?? 100,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            ),
          ),
          if (_currentZoom > _minZoom + 0.05)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '${_currentZoom.toStringAsFixed(1)}x',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child:
                    const Icon(Icons.close, color: Colors.white, size: 28),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      if (_cameraController == null ||
                          !_cameraInitialized) return;
                      final mode =
                          _cameraController!.value.flashMode;
                      await _cameraController!.setFlashMode(
                        mode == FlashMode.off
                            ? FlashMode.auto
                            : FlashMode.off,
                      );
                      setState(() {});
                    },
                    child: Icon(
                      _cameraController?.value.flashMode == FlashMode.off
                          ? Icons.flash_off
                          : Icons.flash_auto,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: _flipCamera,
                    child: const Icon(Icons.flip_camera_ios,
                        color: Colors.white, size: 26),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildCameraPreview(),
                  if (_isRecording)
                    Positioned(
                      top: 16,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.circle,
                                  color: Colors.red, size: 10),
                              const SizedBox(width: 6),
                              Text(
                                'REC',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
    ),

                  Positioned(
                    right: 12,
                    top: 0,
                    bottom: 0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _sideIcon('Aa'),
                        const SizedBox(height: 24),
                        _sideIconWidget(const Icon(Icons.all_inclusive,
                            color: Colors.white, size: 22)),
                        const SizedBox(height: 24),
                        _sideIconWidget(const Icon(Icons.grid_view_outlined,
                            color: Colors.white, size: 22)),
                        const SizedBox(height: 24),
                        _sideIconWidget(const Icon(
                            Icons.face_retouching_natural,
                            color: Colors.white,
                            size: 22)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: _pickFromGallery,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.photo_library,
                              color: Colors.white, size: 28),
                        ),
                      ),
                      GestureDetector(
                        onTap: _isRecording ? null : _takePhoto,
                        onLongPressStart: (_) => _startVideoRecording(),
                        onLongPressEnd: (_) => _stopVideoRecording(),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: _isRecording ? 86 : 76,
                          height: _isRecording ? 86 : 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isRecording
                                  ? Colors.red
                                  : Colors.white,
                              width: _isRecording ? 5 : 4,
                            ),
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: _isRecording
                                  ? Colors.red
                                  : (_isCapturing
                                  ? Colors.grey
                                  : Colors.white),
                              shape: _isRecording
                                  ? BoxShape.rectangle
                                  : BoxShape.circle,
                              borderRadius: _isRecording
                                  ? BorderRadius.circular(8)
                                  : null,
                            ),
                            child: _isCapturing
                                ? const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.black, strokeWidth: 2))
                                : null,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onTextSelected,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: const BoxDecoration(
                              color: Colors.white24,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.text_fields,
                              color: Colors.white, size: 26),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRecording
                        ? context.tr('finger_up_to_save_video')
                        : context.tr('tap_photo_hold_video'),
                    style:
                    const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: ContentMode.values.map((m) {
                      final selected = _mode == m;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _mode = m);
                          widget.onModeChanged(m);
                        },
                        child: Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            m.name.toUpperCase(),
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.white38,
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sideIcon(String text) => SizedBox(
    width: 36,
    height: 36,
    child: Center(
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600))),
  );

  Widget _sideIconWidget(Widget icon) =>
      SizedBox(width: 36, height: 36, child: Center(child: icon));

String _getFilterName(String filterName) {
switch (filterName) {
case 'Normal':
return context.tr('normal');
case 'Clarendon':
return context.tr('clarendon');
case 'Gingham':
return context.tr('gingham');
case 'Moon':
return context.tr('moon');
case 'Lark':
return context.tr('lark');
case 'Reyes':
return context.tr('reyes');
case 'Juno':
return context.tr('juno');
case 'Slumber':
return context.tr('slumber');
default:
return filterName;
}
}
}

// ─── Media Editor Screen ──────────────────────────────────────
class _MediaEditorScreen extends StatefulWidget {
  final XFile file;
  final bool isVideo;
  final ContentMode mode;

  const _MediaEditorScreen(
      {required this.file, required this.isVideo, required this.mode});

  @override
  State<_MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends State<_MediaEditorScreen> {
  int _selectedFilter = 0;
  Uint8List? _imageBytes;

  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoError = false;

  Uint8List? _videoThumb;

  final List<PhotoFilter> _filters = [
    const PhotoFilter(name: 'Normal'),
    PhotoFilter(
        name: 'Clarendon',
        colorFilter: const ColorFilter.matrix([
          1.2, 0, 0, 0, 10, 0, 1.2, 0, 0, 10, 0, 0, 1.2, 0, 10, 0, 0, 0, 1, 0,
        ])),
    PhotoFilter(
        name: 'Gingham',
        colorFilter: const ColorFilter.matrix([
          1.1, 0, 0, 0, -10, 0, 1.1, 0, 0, -10, 0, 0, 1.1, 0, -10, 0, 0, 0,
          1, 0,
        ])),
    PhotoFilter(
        name: 'Moon',
        colorFilter: const ColorFilter.matrix([
          0.3, 0.6, 0.1, 0, 0, 0.3, 0.6, 0.1, 0, 0, 0.3, 0.6, 0.1, 0, 0, 0,
          0, 0, 1, 0,
        ])),
    PhotoFilter(
        name: 'Lark',
        colorFilter: const ColorFilter.matrix([
          1.2, 0, 0, 0, 20, 0, 1.0, 0, 0, 0, 0, 0, 0.9, 0, -10, 0, 0, 0, 1, 0,
        ])),
    PhotoFilter(
        name: 'Reyes',
        colorFilter: const ColorFilter.matrix([
          1.0, 0.1, 0.1, 0, 15, 0, 1.0, 0, 0, 15, 0, 0, 0.8, 0, 10, 0, 0, 0,
          1, 0,
        ])),
    PhotoFilter(
        name: 'Juno',
        colorFilter: const ColorFilter.matrix([
          1.1, 0, 0, 0, 5, 0, 1.2, 0, 0, -5, 0, 0, 1.0, 0, 0, 0, 0, 0, 1, 0,
        ])),
    PhotoFilter(
        name: 'Slumber',
        colorFilter: const ColorFilter.matrix([
          0.9, 0.1, 0, 0, 10, 0, 0.9, 0.1, 0, 10, 0, 0, 0.8, 0, 20, 0, 0, 0,
          1, 0,
        ])),
  ];

  static const _identityFilter = ColorFilter.matrix([
    1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0,
  ]);

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initVideoPlayer();
      _loadVideoThumb();
    } else {
      _loadBytes();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _loadBytes() async {
    final b = await widget.file.readAsBytes();
    if (mounted) setState(() => _imageBytes = b);
  }

  Future<void> _loadVideoThumb() async {
    try {
      final thumb = await vt.VideoThumbnail.thumbnailData(
        video: widget.file.path,
        imageFormat: vt.ImageFormat.JPEG,
        maxWidth: 120,
        quality: 70,
      );
      if (mounted) setState(() => _videoThumb = thumb);
    } catch (e) {
      debugPrint('Video thumb error: $e');
    }
  }

  Future<void> _initVideoPlayer() async {
    try {
      final controller =
      VideoPlayerController.file(File(widget.file.path));
      _videoController = controller;
      await controller.initialize();
      controller.setLooping(true);
      controller.play();
      if (mounted) setState(() => _videoInitialized = true);
    } catch (e) {
      debugPrint('Video player error: $e');
      if (mounted) setState(() => _videoError = true);
    }
  }

  void _goToNext() {
    _videoController?.pause();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PostDetailsScreen(
          file: widget.file,
          imageBytes: _imageBytes,
          videoThumbnail: _videoThumb,
          isVideo: widget.isVideo,
          mode: widget.mode,
          filterIndex: _selectedFilter,
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (widget.isVideo) {
      if (_videoError) {
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.white38, size: 60),
                const SizedBox(height: 8),
                Text(
                  context.tr('video_preview_failed'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }
      if (!_videoInitialized || _videoController == null) {
        return Container(
          color: Colors.black,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  context.tr('video_loading'),
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
          ),
        );
      }
      return Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _videoController!.value.isPlaying
                      ? _videoController!.pause()
                      : _videoController!.play();
                });
              },
              child: AnimatedOpacity(
                opacity:
                _videoController!.value.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                      color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.play_arrow,
                      color: Colors.white, size: 36),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12)),
              child: ValueListenableBuilder(
                valueListenable: _videoController!,
                builder: (context, VideoPlayerValue value, child) {
                  String fmt(Duration d) =>
                      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
                  return Text(
                    '${fmt(value.position)} / ${fmt(value.duration)}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12),
                  );
                },
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _videoController!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFF0095F6),
                bufferedColor: Colors.white30,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      );
    }
    if (_imageBytes == null) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }
    return Image.memory(_imageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity);
  }

  Widget _buildThumb(int i) {
    if (widget.isVideo) {
      if (_videoThumb != null) {
        return Image.memory(_videoThumb!, fit: BoxFit.cover);
      }
      return Container(
        color: Colors.grey[700],
        child: const Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                color: Colors.white54, strokeWidth: 2),
          ),
        ),
      );
    }
    if (_imageBytes == null) return Container(color: Colors.grey[800]);
    return Image.memory(_imageBytes!, fit: BoxFit.cover);
  }

  String _getFilterName(String filterName) {
    switch (filterName) {
      case 'Normal':
        return context.tr('normal');
      case 'Clarendon':
        return context.tr('clarendon');
      case 'Gingham':
        return context.tr('gingham');
      case 'Moon':
        return context.tr('moon');
      case 'Lark':
        return context.tr('lark');
      case 'Reyes':
        return context.tr('reyes');
      case 'Juno':
        return context.tr('juno');
      case 'Slumber':
        return context.tr('slumber');
      default:
        return filterName;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = _filters[_selectedFilter];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.mode == ContentMode.story
              ? context.tr('new_story')
              : widget.mode == ContentMode.reel
              ? context.tr('new_reel')
              : context.tr('new_post'),
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _goToNext,
            child: Text(context.tr('next'),
                style: TextStyle(
                    color: Color(0xFF0095F6),
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ColorFiltered(
              colorFilter: filter.colorFilter ?? _identityFilter,
              child: _buildPreview(),
            ),
          ),
          Container(
            color: Colors.black,
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final selected = _selectedFilter == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedFilter = i),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: ColorFiltered(
                              colorFilter:
                              _filters[i].colorFilter ?? _identityFilter,
                              child: _buildThumb(i),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getFilterName(_filters[i].name),
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Post Details Screen ──────────────────────────────────────
class _PostDetailsScreen extends StatefulWidget {
  final XFile file;
  final Uint8List? imageBytes;
  final Uint8List? videoThumbnail;
  final bool isVideo;
  final ContentMode mode;
  final int filterIndex;

  const _PostDetailsScreen({
    required this.file,
    required this.imageBytes,
    this.videoThumbnail,
    required this.isVideo,
    required this.mode,
    required this.filterIndex,
  });

  @override
  State<_PostDetailsScreen> createState() => _PostDetailsScreenState();
}

class _PostDetailsScreenState extends State<_PostDetailsScreen> {
  final TextEditingController _captionController = TextEditingController();
  PostVisibility _visibility = PostVisibility.everyone;
  String _location = '';
  List<String> _hashtags = [];
  bool _hideLikeCount = false;
  bool _hideShareCount = false;
  bool _turnOffCommenting = false;
  List<TaggedUser> _taggedUsers = [];
  bool _isUploading = false;
  Map<String, dynamic>? _linkedReel;
  String? _currentPostId;
  PollData? _poll;

  bool _alsoShareEnabled = false; // ← YE ADD KARO
  bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    final cleaned = url.trim().replaceAll('"', '');
    try {
      final uri = Uri.parse(cleaned);
      return uri.hasScheme &&
          (uri.scheme == 'http' || uri.scheme == 'https') &&
          uri.host.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
  // ✅ STICKER: Selected stickers list
  List<StickerItem> _selectedStickers = [];

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _openHashtagSheet() {
    final controller =
    TextEditingController(text: _hashtags.join(' '));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('add_hashtags'),
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: context.tr('hashtags_hint'),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.tag),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                '#wedding',
                '#love',
                '#marriage',
                '#couple',
                '#bridal',
                '#groom',
                '#bride',
                '#forever'
              ]
                  .map((h) => ActionChip(
                label: Text(h),
                onPressed: () {
                  final current = controller.text;
                  if (!current.contains(h))
                    controller.text =
                        '$current $h'.trim();
                },
              ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0095F6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final tags = controller.text
                      .split(' ')
                      .where((t) =>
                  t.startsWith('#') && t.length > 1)
                      .toList();
                  setState(() => _hashtags = tags);
                  Navigator.pop(ctx);
                },
                child: Text(context.tr('done'),
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── LocationIQ Real World Search ────────────────────────────
  void _openLocationSheet() {
    final TextEditingController _locationSearchController = TextEditingController();
    List<Map<String, dynamic>> _locationResults = [];
    bool _isSearchingLocation = false;
    String _lastLocationQuery = '';

    Future<void> _searchLocations(String query, StateSetter setSheetState) async {
      if (query.trim().length < 2) {
        setSheetState(() {
          _locationResults = [];
          _isSearchingLocation = false;
        });
        return;
      }

      setSheetState(() => _isSearchingLocation = true);
      _lastLocationQuery = query.trim();

      try {
        final uri = Uri.parse(
          'https://us1.locationiq.com/v1/search.php'
              '?key=pk.ca34a76e067147457252bc4876b5c3b7'
              '&q=${Uri.encodeComponent(query.trim())}'
              '&format=json'
              '&limit=10'
              '&addressdetails=1',
        );

        final response = await http.get(
          uri,
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List<dynamic> data = json.decode(response.body);
          if (_lastLocationQuery == query.trim() && mounted) {
            setSheetState(() {
              _locationResults = data
                  .map((item) => {
                'display_name': item['display_name'] ?? '',
                'lat': item['lat'] ?? '',
                'lon': item['lon'] ?? '',
                'type': item['type'] ?? '',
                'address': item['address'] ?? {},
              })
                  .toList();
              _isSearchingLocation = false;
            });
          }
        } else {
          if (mounted) setSheetState(() => _isSearchingLocation = false);
        }
      } catch (e) {
        debugPrint('LocationIQ error: $e');
        if (mounted) setSheetState(() => _isSearchingLocation = false);
      }
    }

    String _getLocationIcon(String type) {
      switch (type.toLowerCase()) {
        case 'city':
        case 'town':
        case 'village':
          return '🏙️';
        case 'country':
          return '🌍';
        case 'state':
        case 'county':
          return '📍';
        case 'restaurant':
        case 'cafe':
        case 'fast_food':
          return '🍽️';
        case 'hotel':
        case 'hostel':
          return '🏨';
        case 'airport':
          return '✈️';
        case 'hospital':
          return '🏥';
        case 'school':
        case 'university':
          return '🏫';
        case 'park':
          return '🌳';
        case 'mosque':
        case 'church':
        case 'temple':
          return '🕌';
        default:
          return '📍';
      }
    }

    String _formatDisplayName(Map<String, dynamic> result) {
      final address = result['address'] as Map<String, dynamic>? ?? {};
      final parts = <String>[];

      final name = address['amenity'] ??
          address['tourism'] ??
          address['shop'] ??
          address['office'] ??
          address['leisure'];
      if (name != null) parts.add(name as String);

      final city = address['city'] ??
          address['town'] ??
          address['village'] ??
          address['suburb'];
      if (city != null) parts.add(city as String);

      final state = address['state'];
      if (state != null) parts.add(state as String);

      final country = address['country'];
      if (country != null) parts.add(country as String);

      if (parts.isEmpty) {
        final full = result['display_name'] as String? ?? '';
        final segments = full.split(', ');
        if (segments.length <= 3) return full;
        return segments.take(3).join(', ');
      }

      return parts.take(3).join(', ');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.black87, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        context.tr('add_location'),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      if (_location.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            setState(() => _location = '');
                            Navigator.pop(ctx);
                          },
                          child: const Text(
                            'Remove',
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Search field
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TextField(
                      controller: _locationSearchController,
                      autofocus: true,
                      onChanged: (val) => _searchLocations(val, setSheetState),
                      decoration: InputDecoration(
                        hintText: context.tr('location_hint'),
                        hintStyle:
                        const TextStyle(color: Colors.grey, fontSize: 14),
                        prefixIcon: const Icon(Icons.search,
                            color: Colors.grey, size: 22),
                        suffixIcon: _locationSearchController.text.isNotEmpty
                            ? GestureDetector(
                          onTap: () {
                            _locationSearchController.clear();
                            setSheetState(() {
                              _locationResults = [];
                              _isSearchingLocation = false;
                            });
                          },
                          child: const Icon(Icons.close,
                              color: Colors.grey, size: 18),
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 4),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Results
                Expanded(
                  child: _isSearchingLocation
                      ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                            color: Color(0xFF0095F6)),
                        SizedBox(height: 12),
                        Text(
                          'Locations dhundh raha hoon...',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                      : _locationSearchController.text.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF0F0F0),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.public,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Poori duniya ki locations',
                          style: TextStyle(
                            color: Colors.black54,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Pakistan, USA, China, UK — kahi bhi search karo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                      : _locationResults.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_off,
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          '"${_locationSearchController.text}" nahi mila',
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Doosra naam try karein',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding:
                    const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _locationResults.length,
                    itemBuilder: (_, i) {
                      final result = _locationResults[i];
                      final displayName =
                      _formatDisplayName(result);
                      final fullName =
                          result['display_name'] as String? ?? '';
                      final type =
                          result['type'] as String? ?? '';
                      final icon = _getLocationIcon(type);

                      return ListTile(
                        contentPadding:
                        const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        leading: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F3FF),
                            borderRadius:
                            BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              icon,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        onTap: () {
                          setState(() => _location = displayName);
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context)
                              .clearSnackBars();
                          ScaffoldMessenger.of(context)
                              .showSnackBar(
                            SnackBar(
                              content: Text(
                                  '📍 $displayName add ho gaya!'),
                              backgroundColor:
                              const Color(0xFF0095F6),
                              duration:
                              const Duration(seconds: 2),
                              behavior:
                              SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(10),
                              ),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openVisibilitySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text(context.tr('who_can_see_this'),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold))),
            _visibilityOption(Icons.public, context.tr('everyone'),
                context.tr('visible_to_all_users'), PostVisibility.everyone, ctx),
            _visibilityOption(
                Icons.people,
                context.tr('close_friends'),
                context.tr('only_people_you_follow'),
                PostVisibility.closeFriends,
                ctx,
                color: const Color(0xFF3DDC84)),
            _visibilityOption(Icons.lock, context.tr('only_me'),
                context.tr('no_one_else_can_see'), PostVisibility.onlyMe, ctx,
                color: Colors.orange),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _visibilityOption(IconData icon, String title, String subtitle,
      PostVisibility value, BuildContext ctx,
      {Color? color}) {
    final selected = _visibility == value;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: (color ?? Colors.blue).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20)),
        child: Icon(icon, color: color ?? Colors.blue, size: 22),
      ),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle:
      Text(subtitle, style: const TextStyle(fontSize: 12)),
      trailing: selected
          ? const Icon(Icons.check_circle, color: Color(0xFF0095F6))
          : const Icon(Icons.radio_button_unchecked,
          color: Colors.grey),
      onTap: () {
        setState(() => _visibility = value);
        Navigator.pop(ctx);
      },
    );
  }

  void _openTagPeopleSheet() {
    final TextEditingController _searchController = TextEditingController();
    List<Map<String, dynamic>> _searchResults = [];
    bool _isSearching = false;
    String _lastQuery = '';

    Future<void> _searchUsers(String query, StateSetter setSheetState) async {
      if (query.trim().isEmpty) {
        setSheetState(() { _searchResults = []; _isSearching = false; });
        return;
      }
      setSheetState(() => _isSearching = true);
      _lastQuery = query.trim();

      try {
        final qLower = query.trim().toLowerCase();

        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('username_lower', isGreaterThanOrEqualTo: qLower)
            .where('username_lower', isLessThan: '${qLower}z')
            .limit(20)
            .get();

        final Map<String, Map<String, dynamic>> merged = {};
        for (final doc in snapshot.docs) {
          if (!merged.containsKey(doc.id)) {
            merged[doc.id] = {'uid': doc.id, ...doc.data() as Map<String, dynamic>};
          }
        }

        final alreadyTagged = _taggedUsers.map((u) => u.uid).toSet();
        final currentUid = FirebaseAuth.instance.currentUser?.uid;

        final filtered = merged.values.where((u) =>
        !alreadyTagged.contains(u['uid']) &&
            u['uid'] != currentUid
        ).toList();

        if (mounted && _lastQuery == query.trim()) {
          setSheetState(() {
            _searchResults = filtered;
            _isSearching = false;
          });
        }
      } catch (e) {
        debugPrint('User search error: $e');
        if (mounted) setSheetState(() => _isSearching = false);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.88,
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.arrow_back, color: Colors.black87, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Text('Tag People', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const Spacer(),
                      if (_taggedUsers.isNotEmpty)
                        TextButton(
                          onPressed: () { setState(() => _taggedUsers.clear()); setSheetState(() {}); },
                          child: const Text('Clear all', style: TextStyle(color: Colors.red, fontSize: 13)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(14)),
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (val) => _searchUsers(val, setSheetState),
                      decoration: InputDecoration(
                        hintText: 'Username ya naam search karein...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                        prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 22),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? GestureDetector(
                          onTap: () { _searchController.clear(); setSheetState(() { _searchResults = []; _isSearching = false; }); },
                          child: const Icon(Icons.close, color: Colors.grey, size: 18),
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (_taggedUsers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tagged (${_taggedUsers.length})', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8, runSpacing: 6,
                          children: _taggedUsers.map((u) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F3FF),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFF0095F6), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: const Color(0xFF0095F6),
                                    backgroundImage: u.photoUrl.isNotEmpty ? NetworkImage(u.photoUrl) : null,
                                    child: u.photoUrl.isEmpty
                                        ? Text(u.username.isNotEmpty ? u.username[0].toUpperCase() : '?',
                                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))
                                        : null,
                                  ),
                                  const SizedBox(width: 6),
                                  Text('@${u.username}', style: const TextStyle(color: Color(0xFF0095F6), fontSize: 13, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 6),
                                  GestureDetector(
                                    onTap: () { setState(() => _taggedUsers.removeWhere((tu) => tu.uid == u.uid)); setSheetState(() {}); },
                                    child: const Icon(Icons.close, size: 14, color: Color(0xFF0095F6)),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 6),
                ],
                Expanded(
                  child: _isSearching
                      ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(color: Color(0xFF0095F6)), SizedBox(height: 12), Text('Dhundh raha hoon...', style: TextStyle(color: Colors.grey, fontSize: 14))]))
                      : _searchController.text.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 80, height: 80, decoration: const BoxDecoration(color: Color(0xFFF0F0F0), shape: BoxShape.circle), child: const Icon(Icons.person_search, size: 40, color: Colors.grey)),
                        const SizedBox(height: 16),
                        const Text('Username ya naam search karein', style: TextStyle(color: Colors.black54, fontSize: 15, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        const Text('Firebase se real users milenge', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  )
                      : _searchResults.isEmpty
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text('"${_searchController.text}" nahi mila', style: const TextStyle(color: Colors.black54, fontSize: 15, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        const Text('Doosra naam ya username try karein', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      ],
                    ),
                  )
                      : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _searchResults.length,
                    itemBuilder: (_, i) {
                      final user = _searchResults[i];
                      final uid = user['uid'] as String? ?? '';
                      final username = user['username'] as String? ?? '';
                      final displayName = user['displayName'] as String? ?? username;
                      final photoUrl = (user['photoUrl'] as String? ?? '')
                          .trim()
                          .replaceAll('"', '');
                      final isCurrentUser = uid == FirebaseAuth.instance.currentUser?.uid;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: const Color(0xFF0095F6),
                          backgroundImage: _isValidUrl(photoUrl) ? NetworkImage(photoUrl) : null,
                          child: !_isValidUrl(photoUrl)
                              ? Text(
                            username.isNotEmpty ? username[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          )
                              : null,
                        ),
                        title: Text(displayName.isNotEmpty ? displayName : username, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('@$username', style: const TextStyle(color: Color(0xFF0095F6), fontSize: 13)),
                            if (isCurrentUser) const Text('Yeh aap hain', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                        trailing: isCurrentUser
                            ? const SizedBox.shrink()
                            : GestureDetector(
                          onTap: () {
                            setState(() {
                              _taggedUsers.add(TaggedUser(uid: uid, username: username, displayName: displayName, photoUrl: photoUrl));
                            });
                            setSheetState(() => _searchResults.removeAt(i));
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('@$username tag ho gaya! ✅'),
                              backgroundColor: const Color(0xFF0095F6),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(16),
                            ));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(color: const Color(0xFF0095F6), borderRadius: BorderRadius.circular(20)),
                            child: const Text('Tag', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0095F6),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        _taggedUsers.isEmpty ? 'Done' : 'Done  •  ${_taggedUsers.length} user${_taggedUsers.length > 1 ? 's' : ''} tagged',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ✅ STICKER: Full sticker picker sheet
  void _openStickerSheet() {
    String _selectedCategory = 'All';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final stickers =
          StickerData.getByCategory(_selectedCategory);
          return Container(
            height: MediaQuery.of(ctx).size.height * 0.75,
            padding: const EdgeInsets.only(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 12),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.arrow_back,
                            color: Colors.black87),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Stickers',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      const Spacer(),
                      // Selected sticker count badge
                      if (_selectedStickers.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0095F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_selectedStickers.length} selected',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Caption mein add karne ke liye tap karo',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 13),
                  ),
                ),

                const SizedBox(height: 14),

                // Category tabs — horizontal scroll
                SizedBox(
                  height: 36,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: StickerData.categories.length,
                    itemBuilder: (_, i) {
                      final cat = StickerData.categories[i];
                      final isSelected = _selectedCategory == cat;
                      return GestureDetector(
                        onTap: () =>
                            setSheetState(() => _selectedCategory = cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin:
                          const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF0095F6)
                                : const Color(0xFFF0F0F0),
                            borderRadius:
                            BorderRadius.circular(20),
                          ),
                          child: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.black54,
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 14),
                const Divider(height: 1),

                // Sticker grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: stickers.length,
                    itemBuilder: (_, i) {
                      final sticker = stickers[i];
                      final isSelected = _selectedStickers
                          .any((s) => s.emoji == sticker.emoji);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedStickers.removeWhere(
                                      (s) => s.emoji == sticker.emoji);
                            } else {
                              _selectedStickers.add(sticker);
                              // Also append sticker emoji to caption
                              final current =
                                  _captionController.text;
                              _captionController.text =
                              current.isEmpty
                                  ? sticker.emoji
                                  : '$current ${sticker.emoji}';
                            }
                          });
                          setSheetState(() {});

                          // Show mini feedback
                          ScaffoldMessenger.of(context)
                              .clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isSelected
                                    ? '${sticker.emoji} remove ho gaya'
                                    : '${sticker.emoji} caption mein add ho gaya!',
                                style: const TextStyle(fontSize: 15),
                              ),
                              duration: const Duration(seconds: 1),
                              backgroundColor: isSelected
                                  ? Colors.red[400]
                                  : const Color(0xFF0095F6),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(10)),
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFE8F3FF)
                                : const Color(0xFFF8F8F8),
                            borderRadius:
                            BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF0095F6)
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [
                              BoxShadow(
                                color: const Color(0xFF0095F6)
                                    .withValues(alpha: 0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                                : [],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                sticker.emoji,
                                style:
                                const TextStyle(fontSize: 30),
                                textAlign: TextAlign.center,
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 2,
                                  right: 2,
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0095F6),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 11),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Done button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0095F6),
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                            BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        _selectedStickers.isEmpty
                            ? 'Done'
                            : 'Done  •  ${_selectedStickers.length} sticker${_selectedStickers.length > 1 ? 's' : ''} added',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Poll sheet
  void _openPollSheet() {
    final questionController =
    TextEditingController(text: _poll?.question ?? '');
    final opt1Controller =
    TextEditingController(text: _poll?.options[0] ?? 'Yes');
    final opt2Controller =
    TextEditingController(text: _poll?.options[1] ?? 'No');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom:
            MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Create Poll',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_poll != null)
                    TextButton(
                      onPressed: () {
                        setState(() => _poll = null);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Remove',
                          style:
                          TextStyle(color: Colors.red)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Apna sawaal likho aur options set karo',
                style:
                TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFE0E0E0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0095F6)
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                              Icons.poll_outlined,
                              color: Color(0xFF0095F6),
                              size: 20),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Poll Question',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: questionController,
                      autofocus: true,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText:
                        'Apna sawaal yahan likhein...\nMisaal: Kya aap shaadi ke liye tayar hain?',
                        hintStyle: const TextStyle(
                            color: Colors.grey, fontSize: 14),
                        border: OutlineInputBorder(
                            borderRadius:
                            BorderRadius.circular(10)),
                        contentPadding:
                        const EdgeInsets.all(12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Poll Options',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Colors.black87),
              ),
              const SizedBox(height: 10),
              _pollOptionField(
                controller: opt1Controller,
                label: 'Option 1',
                color: const Color(0xFF4CAF50),
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(height: 10),
              _pollOptionField(
                controller: opt2Controller,
                label: 'Option 2',
                color: const Color(0xFFF44336),
                icon: Icons.cancel_outlined,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0095F6),
                    padding:
                    const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final q =
                    questionController.text.trim();
                    final o1 = opt1Controller.text.trim();
                    final o2 = opt2Controller.text.trim();
                    if (q.isEmpty) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(
                          content: Text(
                              'Sawaal likhna zaruri hai!')));
                      return;
                    }
                    setState(() => _poll = PollData(
                      question: q,
                      options: [
                        o1.isNotEmpty ? o1 : 'Yes',
                        o2.isNotEmpty ? o2 : 'No',
                      ],
                    ));
                    Navigator.pop(ctx);
                  },
                  child: const Text(
                    'Poll Add Karo',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pollOptionField({
    required TextEditingController controller,
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
        TextStyle(color: color, fontWeight: FontWeight.w600),
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          BorderSide(color: color.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          BorderSide(color: color.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  void _openLinkReelSheet() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin:
              const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Link a Reel',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  if (_linkedReel != null)
                    TextButton(
                      onPressed: () {
                        setState(() => _linkedReel = null);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Remove',
                          style:
                          TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('posts')
                    .where('authorid',
                    isEqualTo: currentUser.uid)
                    .where('isVideo', isEqualTo: true)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF0095F6)));
                  }
                  final docs =
                      snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment:
                        MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam_off,
                              size: 64,
                              color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          const Text(
                              'Aap ki koi bhi Reel nahi hai',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16,
                                  fontWeight:
                                  FontWeight.w500)),
                          const SizedBox(height: 6),
                          const Text(
                              'Pehle ek Reel post karein',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 13)),
                        ],
                      ),
                    );
                  }
                  return GridView.builder(
                    controller: scrollController,
                    padding:
                    const EdgeInsets.all(12),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                      childAspectRatio: 0.7,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final data = docs[i].data()
                      as Map<String, dynamic>;
                      final docId = docs[i].id;
                      final isSelected =
                          _linkedReel?['id'] == docId;
                      final thumbUrl =
                          data['thumbnailUrl'] as String? ??
                              '';
                      final imageUrl =
                          data['imageUrl'] as String? ?? '';
                      final displayUrl =
                      thumbUrl.isNotEmpty
                          ? thumbUrl
                          : imageUrl;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _linkedReel = {
                            'id': docId,
                            'imageUrl': imageUrl,
                            'thumbnailUrl': thumbUrl,
                            'text': data['text'] ?? '',
                            'username':
                            data['username'] ?? '',
                            'photoUrl':
                            data['photoUrl'] ?? '',
                          });
                          Navigator.pop(ctx);
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius:
                              BorderRadius.circular(6),
                              child: displayUrl.isNotEmpty
                                  ? Image.network(
                                displayUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_,
                                    __,
                                    ___) =>
                                    Container(
                                        color: Colors
                                            .grey[200],
                                        child: const Icon(
                                            Icons.videocam,
                                            color: Colors
                                                .grey)),
                              )
                                  : Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                      Icons.videocam,
                                      color: Colors.grey,
                                      size: 32)),
                            ),
                            const Center(
                                child: Icon(
                                    Icons.play_circle_filled,
                                    color: Colors.white70,
                                    size: 28)),
                            if (isSelected)
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius:
                                  BorderRadius.circular(6),
                                  border: Border.all(
                                      color:
                                      const Color(0xFF0095F6),
                                      width: 3),
                                  color: const Color(0xFF0095F6)
                                      .withValues(alpha: 0.2),
                                ),
                                child: const Center(
                                    child: Icon(
                                        Icons.check_circle,
                                        color:
                                        Color(0xFF0095F6),
                                        size: 32)),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openMoreOptionsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
                bottom:
                MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                    child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.symmetric(
                            vertical: 10),
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius:
                            BorderRadius.circular(2)))),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(children: [
                    GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.arrow_back)),
                    const SizedBox(width: 16),
                    const Text('More options',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
                const Divider(),
                const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text('How others can interact',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey,
                            fontSize: 13))),
                _moreOptionTile(
                    ctx: ctx,
                    setModalState: setModalState,
                    icon: Icons.favorite_border,
                    title: 'Hide like count',
                    subtitle: 'Sirf aap ko likes ki ginti nazar ayegi.',
                    value: _hideLikeCount,
                    onChanged: (v) async {
                      setModalState(() => _hideLikeCount = v);
                      setState(() => _hideLikeCount = v);
                      // Agar post already upload ho chuki hai toh
                      // _currentPostId set hoga — warna share pe save hoga
                      if (_currentPostId != null) {
                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(_currentPostId)
                            .update({'hideLikeCount': v});
                      }
                    }),
                _moreOptionTile(
                    ctx: ctx,
                    setModalState: setModalState,
                    icon: Icons.send_outlined,
                    title: 'Hide share count',
                    subtitle: 'Share count post pe nazar nahi ayega.',
                    value: _hideShareCount,
                    onChanged: (v) async {
                      setModalState(() => _hideShareCount = v);
                      setState(() => _hideShareCount = v);
                      if (_currentPostId != null) {
                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(_currentPostId)
                            .update({'hideShareCount': v});
                      }
                    }),
                _moreOptionTile(
                    ctx: ctx,
                    setModalState: setModalState,
                    icon: Icons.chat_bubble_outline,
                    title: 'Turn off commenting',
                    subtitle: 'Is post pe koi comment nahi kar sakega.',
                    value: _turnOffCommenting,
                    onChanged: (v) async {
                      setModalState(() => _turnOffCommenting = v);
                      setState(() => _turnOffCommenting = v);
                      if (_currentPostId != null) {
                        await FirebaseFirestore.instance
                            .collection('posts')
                            .doc(_currentPostId)
                            .update({'turnOffCommenting': v});
                      }
                    }),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _moreOptionTile(
      {required BuildContext ctx,
        required StateSetter setModalState,
        required IconData icon,
        required String title,
        required String subtitle,
        required bool value,
        required ValueChanged<bool> onChanged}) {
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: Colors.black87),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13)),
                  ])),
          const SizedBox(width: 8),
          Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFF0095F6)),
        ],
      ),
    );
  }

  String get _visibilityLabel {
    switch (_visibility) {
      case PostVisibility.everyone:
        return 'Everyone';
      case PostVisibility.onlyMe:
        return 'Only Me';
      case PostVisibility.closeFriends:
        return 'Close Friends';
    }
  }

  IconData get _visibilityIcon {
    switch (_visibility) {
      case PostVisibility.everyone:
        return Icons.public;
      case PostVisibility.onlyMe:
        return Icons.lock;
      case PostVisibility.closeFriends:
        return Icons.people;
    }
  }

  void _share() async {
    if (_isUploading) return;
    setState(() => _isUploading = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) throw Exception('Login nahi hai');
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final userData = userDoc.data() as Map<String, dynamic>;
      final isStory = widget.mode == ContentMode.story;
      String imageUrl = '';
      if (widget.imageBytes != null) {
        final tempDir = await getTemporaryDirectory();
        final tempFile = File(
            '${tempDir.path}/post_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(widget.imageBytes!);
        final uploadedUrl = isStory
            ? await CloudinaryService.uploadStory(tempFile, widget.isVideo)
            : await CloudinaryService.uploadPost(tempFile, widget.isVideo);
        if (uploadedUrl == null) {
          throw Exception('Cloudinary upload failed');
        }
        imageUrl = uploadedUrl;
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      // ✅ STICKER: Build caption with stickers
      final stickerEmojis = _selectedStickers
          .map((s) => s.emoji)
          .join(' ');
      final captionText = _captionController.text.trim();

      // Close friends ke liye following list fetch karo
      List<String> allowedUids = [];
      if (_visibility == PostVisibility.closeFriends) {
        final followingSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .collection('following')
            .get();
        allowedUids = followingSnap.docs.map((d) => d.id).toList();
        // Author khud bhi dekh sake
        allowedUids.add(currentUser.uid);
      }

      final visibilityStr = _visibility == PostVisibility.everyone
          ? 'everyone'
          : _visibility == PostVisibility.closeFriends
              ? 'close_friends'
              : 'only_me';

      // ── STORY branch: write to `stories` collection ──
      if (isStory) {
        await FirebaseFirestore.instance.collection('stories').add({
          'userId': currentUser.uid,
          'username': userData['username'] ?? '',
          'avatarUrl': userData['photoUrl'] ?? '',
          'imageUrl': imageUrl,
          'isVideo': widget.isVideo,
          'caption': captionText,
          'createdAt': FieldValue.serverTimestamp(),
          'visibility': visibilityStr,
          'allowedUids': allowedUids,
        });

        await XPService.addXP(currentUser.uid, XPAction.postBanana);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Story share ho gayi! ✅'),
            backgroundColor: Color(0xFF0095F6),
            duration: Duration(seconds: 2),
          ));
          int count = 0;
          Navigator.of(context).popUntil((_) => count++ >= 3);
        }
        return;
      }

      final postRef = await FirebaseFirestore.instance.collection('posts').add({
        'authorid': currentUser.uid,
        'username': userData['username'] ?? '',
        'photoUrl': userData['photoUrl'] ?? '',
        'text': [
          captionText,
          if (_hashtags.isNotEmpty) _hashtags.join(' '),
        ].where((s) => s.isNotEmpty).join('\n'),
        'imageUrl': imageUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'visibility': visibilityStr,
        // ✅ NEW: Allowed UIDs for close_friends filtering
        'allowedUids': allowedUids,
        'isVideo': widget.isVideo,
        'location': _location,
        'hashtags': _hashtags,
        'hideLikeCount': _hideLikeCount,
        'turnOffCommenting': _turnOffCommenting,
        'taggedUsers': _taggedUsers
            .map((u) => {
          'uid': u.uid,
          'username': u.username,
          'photoUrl': u.photoUrl
        })
            .toList(),
        'hasTaggedUsers': _taggedUsers.isNotEmpty,
        if (_poll != null) 'poll': _poll!.toMap(),
        'hasPoll': _poll != null,
        'stickers': _selectedStickers
            .map((s) => {
          'emoji': s.emoji,
          'label': s.label,
          'category': s.category,
        })
            .toList(),
        'hasStickers': _selectedStickers.isNotEmpty,
        'stickerEmojis': stickerEmojis,
      });

      // 🎁 +100 XP for creating a post
      await XPService.addXP(currentUser.uid, XPAction.postBanana);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Post share ho gaya! ✅'),
          backgroundColor: Color(0xFF0095F6),
          duration: Duration(seconds: 2),
        ));
        int count = 0;
        Navigator.of(context).popUntil((_) => count++ >= 3);
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red));
    }
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Draft saved!')));
    int count = 0;
    Navigator.of(context).popUntil((_) => count++ >= 3);
  }

  Widget _buildThumbnail() {
    if (widget.imageBytes != null) {
      return Image.memory(widget.imageBytes!,
          fit: BoxFit.cover, width: 100, height: 130);
    }
    if (widget.isVideo) {
      if (widget.videoThumbnail != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(widget.videoThumbnail!, fit: BoxFit.cover),
            const Center(
                child: Icon(Icons.play_circle_filled,
                    color: Colors.white70, size: 32)),
          ],
        );
      }
      return Container(
        width: 100,
        height: 130,
        color: Colors.grey[800],
        child: const Center(
            child: CircularProgressIndicator(
                color: Colors.white54, strokeWidth: 2)),
      );
    }
    return Container(
        width: 100,
        height: 130,
        color: Colors.grey[300],
        child: const Icon(Icons.image, color: Colors.grey));
  }

  // Poll preview widget
  Widget _buildPollPreview() {
    if (_poll == null) return const SizedBox.shrink();
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8F3FF), Color(0xFFF0F8FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: const Color(0xFF0095F6), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0095F6)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.poll,
                      color: Color(0xFF0095F6), size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Poll',
                  style: TextStyle(
                    color: Color(0xFF0095F6),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _poll = null),
                  child: const Icon(Icons.close,
                      color: Colors.grey, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _poll!.question,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ..._poll!.options.asMap().entries.map((entry) {
              final isFirst = entry.key == 0;
              final optColor = isFirst
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFF44336);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: optColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: optColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFirst
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      color: optColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      entry.value,
                      style: TextStyle(
                        color: optColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ✅ STICKER: Sticker preview in post details
  Widget _buildStickerPreview() {
    if (_selectedStickers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFFFFCA28), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '🎨  Stickers',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF795548)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _openStickerSheet,
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                        color: Color(0xFF0095F6),
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _selectedStickers.map((s) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFFFCA28)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(s.emoji,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 4),
                      Text(s.label,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedStickers.removeWhere(
                                    (item) =>
                                item.emoji == s.emoji);
                            // Remove from caption too
                            _captionController.text =
                                _captionController.text
                                    .replaceAll(' ${s.emoji}', '')
                                    .replaceAll(s.emoji, '')
                                    .trim();
                          });
                        },
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeTitle = widget.mode == ContentMode.story
        ? context.tr('new_story')
        : widget.mode == ContentMode.reel
        ? context.tr('new_reel')
        : context.tr('new_post');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(modeTitle,
            style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                            width: 100,
                            height: 130,
                            child: _buildThumbnail()),
                      ),
                      Positioned(
                        bottom: 8,
                        left: 0,
                        right: 0,
                        child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius:
                                  BorderRadius.circular(12)),
                              child: Text(context.tr('edit_cover'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11)),
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _captionController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            hintText: context.tr('caption_hint'),
                            hintStyle: const TextStyle(
                                color: Colors.grey,
                                fontSize: 15),
                            border: InputBorder.none,
                          ),
                          style:
                          const TextStyle(fontSize: 15),
                        ),
                        if (_hashtags.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                                top: 4),
                            child: Text(
                              _hashtags.join(' '),
                              style: const TextStyle(
                                color: Color(0xFF0095F6),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  if (widget.mode != ContentMode.story) ...[
                    _actionChip(
                        icon: Icons.tag,
                        label: context.tr('add_hashtags'),
                        onTap: _openHashtagSheet,
                        active: _hashtags.isNotEmpty),
                    const SizedBox(width: 8),
                  ],
                  _actionChip(
                      icon: Icons.play_circle_outline,
                      label: context.tr('link_reel'),
                      onTap: _openLinkReelSheet,
                      active: _linkedReel != null),
                  const SizedBox(width: 8),
                  _actionChip(
                    icon: Icons.poll_outlined,
                    label: context.tr('add_poll'),
                    onTap: _openPollSheet,
                    active: _poll != null,
                  ),
                  const SizedBox(width: 8),
                  _actionChipWithBadge(
                    icon: Icons.emoji_emotions_outlined,
                    label: context.tr('add_stickers'),
                    onTap: _openStickerSheet,
                    active: _selectedStickers.isNotEmpty,
                    badgeCount: _selectedStickers.length,
                  ),
                ],
              ),
            ),
            if (_hashtags.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16),
                child: Wrap(
                  spacing: 6,
                  children: _hashtags
                      .map((h) => Chip(
                    label: Text(h,
                        style: const TextStyle(
                            color: Color(0xFF0095F6),
                            fontSize: 12)),
                    backgroundColor:
                    const Color(0xFFE8F3FF),
                    materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
                    padding: EdgeInsets.zero,
                  ))
                      .toList(),
                ),
              ),
            if (_linkedReel != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF0095F6),
                        width: 1.5),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius:
                        BorderRadius.circular(6),
                        child: SizedBox(
                          width: 52,
                          height: 70,
                          child: _linkedReel!['thumbnailUrl']
                              ?.isNotEmpty ==
                              true ||
                              _linkedReel!['imageUrl']
                                  ?.isNotEmpty ==
                                  true
                              ? Image.network(
                            (_linkedReel!['thumbnailUrl']
                                ?.isNotEmpty ==
                                true
                                ? _linkedReel![
                            'thumbnailUrl']
                                : _linkedReel![
                            'imageUrl'])
                            as String,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                Container(
                                  color: Colors.grey[300],
                                  child: const Icon(
                                      Icons.videocam,
                                      color: Colors.grey),
                                ),
                          )
                              : Container(
                              color: Colors.grey[300],
                              child: const Icon(
                                  Icons.videocam,
                                  color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            const Text('Linked Reel',
                                style: TextStyle(
                                    color: Color(0xFF0095F6),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(
                              (_linkedReel!['text']
                              as String?)
                                  ?.isNotEmpty ==
                                  true
                                  ? _linkedReel!['text']
                              as String
                                  : 'No caption',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _linkedReel = null),
                        child: const Icon(Icons.close,
                            color: Colors.grey, size: 20),
                      ),
                    ],
                  ),
                ),
              ),

            // Poll preview
            _buildPollPreview(),

            // ✅ STICKER: Sticker preview
            _buildStickerPreview(),

            const Divider(height: 1),
            _settingRow(
                icon: Icons.person_outline,
                title: context.tr('tag_people'),
                trailing: _taggedUsers.isEmpty
                    ? null
                    : Text(
                  '${_taggedUsers.length} tagged',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                onTap: _openTagPeopleSheet),
            if (widget.mode != ContentMode.story) ...[
              _settingRow(
                  icon: Icons.location_on_outlined,
                  title: context.tr('add_location'),
                  trailing: _location.isEmpty
                      ? null
                      : Text(_location,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 14)),
                  onTap: _openLocationSheet),
            ],
            _settingRow(
                icon: _visibilityIcon,
                title: context.tr('post_visibility'),
                trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_visibilityLabel,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 14)),
                      const Icon(Icons.chevron_right,
                          color: Colors.grey, size: 20),
                    ]),
                onTap: _openVisibilitySheet),
            InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => StatefulBuilder(
                    builder: (ctx, setSheet) => Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 40, height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.tr('also_share_on'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.mode == ContentMode.story
                                ? 'Is story ko apni post feed mein bhi share karo'
                                : 'Is ${widget.mode.name} ko apni story mein bhi share karo',
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          StreamBuilder<DocumentSnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                .snapshots(),
                            builder: (context, snapshot) {
                              final data = snapshot.data?.data() as Map<String, dynamic>?;
                              final username = data?['username'] as String? ?? '';
                              final photoUrl = (data?['photoUrl'] as String? ?? '').trim().replaceAll('"', '');
                              final shareLabel = widget.mode == ContentMode.story
                                  ? 'Share on Post'
                                  : 'Share on Story';

                              return GestureDetector(
                                onTap: () {
                                  setState(() => _alsoShareEnabled = !_alsoShareEnabled);
                                  setSheet(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _alsoShareEnabled
                                        ? const Color(0xFFE8F3FF)
                                        : const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _alsoShareEnabled
                                          ? const Color(0xFF0095F6)
                                          : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: const Color(0xFF0095F6),
                                        backgroundImage: photoUrl.isNotEmpty
                                            ? NetworkImage(photoUrl)
                                            : null,
                                        child: photoUrl.isEmpty
                                            ? Text(
                                          username.isNotEmpty
                                              ? username[0].toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18),
                                        )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              username.isNotEmpty ? '@$username' : 'Your Profile',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 15,
                                                  color: Colors.black87),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              shareLabel,
                                              style: const TextStyle(
                                                  color: Colors.grey, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        width: 26,
                                        height: 26,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _alsoShareEnabled
                                              ? const Color(0xFF0095F6)
                                              : Colors.transparent,
                                          border: Border.all(
                                            color: _alsoShareEnabled
                                                ? const Color(0xFF0095F6)
                                                : Colors.grey,
                                            width: 2,
                                          ),
                                        ),
                                        child: _alsoShareEnabled
                                            ? const Icon(Icons.check,
                                            color: Colors.white, size: 16)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0095F6),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(
                                _alsoShareEnabled ? 'Done ✅' : 'Done',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new, size: 22, color: Colors.black87),
                    const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    context.tr('also_share_on'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                    ),
                    if (_alsoShareEnabled)
                      Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F3FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.mode == ContentMode.story ? 'Post ✓' : 'Story ✓',
                          style: const TextStyle(
                              color: Color(0xFF0095F6),
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                  ],
                ),
              ),
            ),
            if (widget.mode != ContentMode.story)
              _settingRow(
                icon: Icons.more_horiz,
                title: context.tr('advanced_settings'),
                trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_hideLikeCount ||
                          _turnOffCommenting ||
                          _hideShareCount)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xFFE8F3FF),
                              borderRadius:
                              BorderRadius.circular(10)),
                          child: Text(
                            [
                              if (_hideLikeCount) 'Likes hidden',
                              if (_hideShareCount) 'Shares hidden',
                              if (_turnOffCommenting) 'Comments off'
                            ].join(' · '),
                            style: const TextStyle(
                                color: Color(0xFF0095F6),
                                fontSize: 11),
                          ),
                        ),
                      const Icon(Icons.chevron_right,
                          color: Colors.grey, size: 20),
                    ]),
                onTap: _openMoreOptionsSheet,
              ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side:
                          const BorderSide(color: Colors.grey),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                        ),
                        onPressed: _saveDraft,
                        child: Text(context.tr('save'),
                            style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                      )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0095F6),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                        ),
                        onPressed: _isUploading ? null : _share,
                        child: _isUploading
                            ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2))
                            : Text(
                          context.tr('share'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _actionChip(
      {required IconData icon,
        required String label,
        required VoidCallback onTap,
        bool active = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFFE8F3FF)
              : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? const Color(0xFF0095F6)
                  : Colors.transparent),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon,
              size: 16,
              color: active
                  ? const Color(0xFF0095F6)
                  : Colors.black87),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: active
                      ? const Color(0xFF0095F6)
                      : Colors.black87)),
        ]),
      ),
    );
  }

  // ✅ STICKER: Action chip with badge count
  Widget _actionChipWithBadge(
      {required IconData icon,
        required String label,
        required VoidCallback onTap,
        bool active = false,
        int badgeCount = 0}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: active
                  ? const Color(0xFFFFF8E1)
                  : const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: active
                      ? const Color(0xFFFFCA28)
                      : Colors.transparent),
            ),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 16,
                      color: active
                          ? const Color(0xFF795548)
                          : Colors.black87),
                  const SizedBox(width: 4),
                  Text(label,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: active
                              ? const Color(0xFF795548)
                              : Colors.black87)),
                ]),
          ),
          if (active && badgeCount > 0)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFCA28),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _settingRow(
      {required IconData icon,
        required String title,
        Widget? trailing,
        required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 22, color: Colors.black87),
          const SizedBox(width: 14),
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500))),
          if (trailing != null) trailing,
          if (trailing == null)
            const Icon(Icons.chevron_right,
                color: Colors.grey, size: 20),
        ]),
      ),
    );
  }
}

// ─── Text Creator Screen ──────────────────────────────────────
class _TextCreatorScreen extends StatefulWidget {
  final ContentMode mode;
  const _TextCreatorScreen({required this.mode});

  @override
  State<_TextCreatorScreen> createState() =>
      _TextCreatorScreenState();
}

class _TextCreatorScreenState extends State<_TextCreatorScreen> {
  final TextEditingController _textController =
  TextEditingController();
  Color _bgColor = const Color(0xFF1A1A2E);
  double _fontSize = 28;
  bool _isBold = false;
  bool _isItalic = false;
  Color _textColor = Colors.white;

  final List<Color> _bgColors = [
    const Color(0xFF1A1A2E),
    const Color(0xFFB21A1A),
    const Color(0xFF1A4B1A),
    const Color(0xFF1A1A4B),
    const Color(0xFF4B1A4B),
    const Color(0xFF4B3A1A),
    Colors.black,
    Colors.white,
  ];

  final List<Color> _textColors = [
    Colors.white,
    Colors.black,
    Colors.yellow,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.pink,
  ];

  void _goNext() {
    if (_textController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(context.tr('caption_required'))));
      return;
    }
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => _TextPostDetailsScreen(
              text: _textController.text,
              bgColor: _bgColor,
              textColor: _textColor,
              isBold: _isBold,
              fontSize: _fontSize,
              mode: widget.mode,
            )));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context)),
        title: Text(
            'Create ${widget.mode.name[0].toUpperCase()}${widget.mode.name.substring(1)}',
            style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(
              onPressed: _goNext,
              child: Text(context.tr('next'),
                  style: TextStyle(
                      color: Color(0xFF0095F6),
                      fontWeight: FontWeight.w600))),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: _bgColor,
                  borderRadius: BorderRadius.circular(16)),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: TextField(
                    controller: _textController,
                    maxLines: null,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _textColor,
                      fontSize: _fontSize,
                      fontWeight: _isBold
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontStyle: _isItalic
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    decoration: InputDecoration(
                      hintText: context.tr('caption_hint'),
                      hintStyle: TextStyle(
                          color: Colors.white38, fontSize: 28),
                      border: InputBorder.none,
                    ),
                    autofocus: true,
                  ),
                ),
              ),
            ),
          ),
          Container(
            color: const Color(0xFF1A1A1A),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(children: [
                  const Text('Text: ',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  ..._textColors.map((c) => GestureDetector(
                    onTap: () =>
                        setState(() => _textColor = c),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin:
                      const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _textColor == c
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2)),
                    ),
                  )),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Text(context.tr('bg_color_label'),
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  ..._bgColors.map((c) => GestureDetector(
                    onTap: () =>
                        setState(() => _bgColor = c),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin:
                      const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: _bgColor == c
                                  ? Colors.white
                                  : Colors.grey,
                              width: 2)),
                    ),
                  )),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  IconButton(
                      onPressed: () =>
                          setState(() => _isBold = !_isBold),
                      icon: Icon(Icons.format_bold,
                          color: _isBold
                              ? Colors.white
                              : Colors.white38)),
                  IconButton(
                      onPressed: () =>
                          setState(() => _isItalic = !_isItalic),
                      icon: Icon(Icons.format_italic,
                          color: _isItalic
                              ? Colors.white
                              : Colors.white38)),
                  const Spacer(),
                  const Text('Size',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  Slider(
                    value: _fontSize,
                    min: 14,
                    max: 48,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    onChanged: (v) =>
                        setState(() => _fontSize = v),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Text Post Details Screen ─────────────────────────────────
class _TextPostDetailsScreen extends StatefulWidget {
  final String text;
  final Color bgColor;
  final Color textColor;
  final bool isBold;
  final double fontSize;
  final ContentMode mode;

  const _TextPostDetailsScreen({
    required this.text,
    required this.bgColor,
    required this.textColor,
    required this.isBold,
    required this.fontSize,
    required this.mode,
  });

  @override
  State<_TextPostDetailsScreen> createState() =>
      _TextPostDetailsScreenState();
}

class _TextPostDetailsScreenState
    extends State<_TextPostDetailsScreen> {
  PostVisibility _visibility = PostVisibility.everyone;
  String _location = '';

  String get _visibilityLabel {
    switch (_visibility) {
      case PostVisibility.everyone:
        return 'Everyone';
      case PostVisibility.onlyMe:
        return 'Only Me';
      case PostVisibility.closeFriends:
        return 'Close Friends';
    }
  }

  void _share() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          'Text ${widget.mode.name} shared! Visibility: $_visibilityLabel'),
      backgroundColor: const Color(0xFF0095F6),
    ));
    int count = 0;
    Navigator.of(context).popUntil((_) => count++ >= 3);
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Draft saved!')));
    int count = 0;
    Navigator.of(context).popUntil((_) => count++ >= 3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
        title: Text(
            'New ${widget.mode.name[0].toUpperCase()}${widget.mode.name.substring(1)}',
            style: const TextStyle(
                color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              height: 200,
              decoration: BoxDecoration(
                  color: widget.bgColor,
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text(widget.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: widget.textColor,
                          fontSize: widget.fontSize,
                          fontWeight: widget.isBold
                              ? FontWeight.bold
                              : FontWeight.normal))),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('Audience'),
              trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_visibilityLabel,
                        style:
                        const TextStyle(color: Colors.grey)),
                    const Icon(Icons.chevron_right,
                        color: Colors.grey),
                  ]),
              onTap: _showVisibilitySheet,
            ),
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('Add location'),
              trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_location.isNotEmpty)
                      Text(_location,
                          style: const TextStyle(
                              color: Colors.grey)),
                    const Icon(Icons.chevron_right,
                        color: Colors.grey),
                  ]),
              onTap: _showLocationSheet,
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(8)),
                        ),
                        onPressed: _saveDraft,
                        child: Text(context.tr('save'),
                            style:
                            TextStyle(color: Colors.black87)),
                      )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0095F6),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(8)),
                        ),
                        onPressed: _share,
                        child: Text(context.tr('share'),
                            style: TextStyle(color: Colors.white)),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVisibilitySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2))),
            const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Who can see this?',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold))),
            _visOpt(ctx, Icons.public, 'Everyone',
                'Visible to everyone', PostVisibility.everyone),
            _visOpt(ctx, Icons.people, 'Close Friends',
                'Only your followers', PostVisibility.closeFriends,
                Colors.green),
            _visOpt(ctx, Icons.lock, 'Only Me',
                'Only you can see this', PostVisibility.onlyMe,
                Colors.orange),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _visOpt(BuildContext ctx, IconData icon, String title,
      String sub, PostVisibility val,
      [Color? color]) {
    return ListTile(
      leading: Icon(icon, color: color ?? Colors.blue),
      title: Text(title),
      subtitle: Text(sub),
      trailing: _visibility == val
          ? const Icon(Icons.check_circle,
          color: Color(0xFF0095F6))
          : const Icon(Icons.radio_button_unchecked,
          color: Colors.grey),
      onTap: () {
        setState(() => _visibility = val);
        Navigator.pop(ctx);
      },
    );
  }

  void _showLocationSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
          BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Add Location',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search city or location...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 8),
            ...[
              'Rawalpindi, Pakistan',
              'Islamabad, Pakistan',
              'Lahore, Pakistan',
              'Karachi, Pakistan'
            ].map((loc) => ListTile(
              leading: const Icon(Icons.location_city,
                  color: Colors.grey),
              title: Text(loc),
              onTap: () {
                setState(() => _location = loc);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }
}