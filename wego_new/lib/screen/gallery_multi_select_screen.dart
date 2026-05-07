import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'app_localizations.dart';
import 'app_translations.dart';
class GalleryMultiSelectScreen extends StatefulWidget {
  const GalleryMultiSelectScreen({super.key});

  @override
  State<GalleryMultiSelectScreen> createState() => _GalleryMultiSelectScreenState();
}

class _GalleryMultiSelectScreenState extends State<GalleryMultiSelectScreen> {
  final List<XFile> _selectedMedia = [];
  List<XFile> _allMedia = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGallery();
  }

  Future<void> _loadGallery() async {
    final picker = ImagePicker();
    try {
      final media = await picker.pickMultipleMedia();
      if (mounted) {
        setState(() {
          _allMedia = media;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleSelection(XFile media) {
    setState(() {
      if (_selectedMedia.contains(media)) {
        _selectedMedia.remove(media);
      } else {
        _selectedMedia.add(media);
      }
    });
  }

  void _handleNext() {
    if (_selectedMedia.isEmpty) return;
    Navigator.pop(context, _selectedMedia);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            _buildTab('Photos', true),
            const SizedBox(width: 20),
            _buildTab('Albums', false),
          ],
        ),
        actions: [
          if (_selectedMedia.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_selectedMedia.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: _allMedia.length,
                    itemBuilder: (context, index) {
                      final media = _allMedia[index];
                      final isSelected = _selectedMedia.contains(media);
                      final isVideo = media.path.toLowerCase().endsWith('.mp4') ||
                          media.path.toLowerCase().endsWith('.mov');

                      return GestureDetector(
                        onTap: () => _toggleSelection(media),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Media thumbnail
                            Image.file(
                              File(media.path),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.broken_image, color: Colors.grey),
                                );
                              },
                            ),
                            // Video indicator
                            if (isVideo)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.play_arrow, color: Colors.white, size: 12),
                                      SizedBox(width: 2),
                                      Text('0:14', style: TextStyle(color: Colors.white, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ),
                            // Selection overlay
                            if (isSelected)
                              Container(
                                color: Colors.blue.withOpacity(0.3),
                              ),
                            // Selection number
                            if (isSelected)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: const BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${_selectedMedia.indexOf(media) + 1}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
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
                // Bottom bar with preview and Next button
                if (_selectedMedia.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black,
                    child: Row(
                      children: [
                        // Preview of first selected item
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              File(_selectedMedia.first.path),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Count
                        Text(
                          '${_selectedMedia.length} selected',
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Spacer(),
                        // Next button
                        ElevatedButton(
                          onPressed: _handleNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                          child: const Text(
                            'Next',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildTab(String title, bool isActive) {
    return GestureDetector(
      onTap: () {
        // Handle tab switch
      },
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (isActive)
            Container(
              margin: const EdgeInsets.only(top: 4),
              height: 2,
              width: 30,
              color: Colors.white,
            ),
        ],
      ),
    );
  }
}
