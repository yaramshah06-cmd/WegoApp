import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wego_marriage/screen/media_editing_screen.dart';
import 'app_localizations.dart';
import 'app_translations.dart';
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isRecording = false;
  bool _isFrontCamera = true;
  int _currentFilterIndex = 0;

  final List<Map<String, dynamic>> _filters = [
    {'name': 'Normal', 'icon': Icons.filter_none},
    {'name': 'Beauty', 'icon': Icons.face},
    {'name': 'Hide Face', 'icon': Icons.visibility_off},
    {'name': 'Background', 'icon': Icons.landscape},
    {'name': 'Spiderman', 'icon': Icons.stars},
    {'name': 'Vintage', 'icon': Icons.auto_awesome},
    {'name': 'B&W', 'icon': Icons.brightness_6},
    {'name': 'Warm', 'icon': Icons.wb_sunny},
  ];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras![_isFrontCamera ? 1 : 0],
        ResolutionPreset.high,
      );
      await _controller!.initialize();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _switchCamera() {
    if (_cameras == null || _cameras!.length < 2) return;
    setState(() {
      _isFrontCamera = !_isFrontCamera;
    });
    _initializeCamera();
  }

  void _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final image = await _controller!.takePicture();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MediaEditingScreen(imagePath: image.path),
          ),
        );
      }
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  void _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      await _controller!.startVideoRecording();
      setState(() => _isRecording = true);
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  void _stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) return;
    try {
      final video = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MediaEditingScreen(videoPath: video.path),
          ),
        );
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  void _openGallery() async {
    final picker = ImagePicker();
    final XFile? media = await picker.pickMedia();
    if (media != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MediaEditingScreen(imagePath: media.path),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Positioned.fill(
            child: CameraPreview(_controller!),
          ),
          // Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.flash_on, color: Colors.white),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Filter Bar
          Positioned(
            right: 0,
            top: 100,
            bottom: 150,
            child: Container(
              width: 70,
              child: ListView.builder(
                itemCount: _filters.length,
                itemBuilder: (context, index) {
                  final filter = _filters[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _currentFilterIndex = index);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: _currentFilterIndex == index
                            ? Colors.white.withOpacity(0.3)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        filter['icon'],
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Filter Search Icon
          Positioned(
            right: 20,
            top: 80,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                onPressed: () {
                  _showFilterSearch();
                },
              ),
            ),
          ),
          // Bottom Controls
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Gallery Button
                    GestureDetector(
                      onTap: _openGallery,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.photo_library,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    // Capture Button
                    GestureDetector(
                      onTap: _isRecording ? _stopRecording : _takePicture,
                      onLongPressStart: (_) => _startRecording(),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.red : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: _isRecording
                            ? const Icon(Icons.stop, color: Colors.white)
                            : null,
                      ),
                    ),
                    // Switch Camera Button
                    GestureDetector(
                      onTap: _switchCamera,
                      child: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.flip_camera_ios,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSearch() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text('Search Filters', style: TextStyle(color: Colors.white)),
        content: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search filters...',
            hintStyle: const TextStyle(color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
