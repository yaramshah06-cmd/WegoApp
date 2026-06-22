import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key});

  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedFile;
  bool _isVideo = false;
  bool _isPosting = false;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickFromGallery({required bool video}) async {
    try {
      final XFile? file = video
          ? await _picker.pickVideo(source: ImageSource.gallery)
          : await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file != null && mounted) {
        setState(() {
          _pickedFile = file;
          _isVideo = video;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick file: $e')),
        );
      }
    }
  }

  Future<void> _pickFromCamera({required bool video}) async {
    try {
      final XFile? file = video
          ? await _picker.pickVideo(source: ImageSource.camera)
          : await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
      if (file != null && mounted) {
        setState(() {
          _pickedFile = file;
          _isVideo = video;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open camera: $e')),
        );
      }
    }
  }

  void _showSourceSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[600] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Pick photo from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery(video: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Pick video from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromGallery(video: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromCamera(video: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_call),
              title: const Text('Record a video'),
              onTap: () {
                Navigator.pop(ctx);
                _pickFromCamera(video: true);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _share() async {
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a photo or video first')),
      );
      return;
    }

    setState(() => _isPosting = true);

    // TODO: Replace this with your actual upload / backend call.
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() => _isPosting = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post shared successfully')),
    );
    Navigator.pop(context, {
      'path': _pickedFile!.path,
      'caption': _captionController.text.trim(),
      'isVideo': _isVideo,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Post',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isPosting ? null : _share,
            child: _isPosting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Share',
                    style: TextStyle(
                      color: Color(0xFF0095F6),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media preview / picker tile
            GestureDetector(
              onTap: _showSourceSheet,
              child: Container(
                width: double.infinity,
                height: 320,
                color: isDark ? Colors.white10 : const Color(0xFFF2F2F2),
                child: _pickedFile == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo_outlined,
                            size: 48,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap to choose a photo or video',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )
                    : (_isVideo
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.movie,
                                    size: 56, color: Color(0xFF0095F6)),
                                const SizedBox(height: 8),
                                Text(
                                  _pickedFile!.name,
                                  style: TextStyle(
                                    color: isDark ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Image.file(
                            File(_pickedFile!.path),
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )),
              ),
            ),

            const SizedBox(height: 16),

            // Caption field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _captionController,
                maxLines: 4,
                minLines: 2,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: 'Write a caption...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),

            const Divider(height: 1),

            // Quick options (placeholders)
            _buildOptionRow(Icons.location_on_outlined, 'Add location'),
            _buildOptionRow(Icons.person_add_alt_1_outlined, 'Tag people'),
            _buildOptionRow(Icons.music_note_outlined, 'Add music'),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionRow(IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label — coming soon')),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: isDark ? Colors.white70 : Colors.black87),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right,
                color: isDark ? Colors.white38 : Colors.black38),
          ],
        ),
      ),
    );
  }
}
