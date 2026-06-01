import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static final CloudinaryPublic _cloudinary = CloudinaryPublic(
    'diqeeznan',       // tumhara cloud name
    'wego_marriage',   // tumhara preset
    cache: false,
  );

  // Profile Picture Upload
  static Future<String?> uploadProfilePic(File image) async {
    try {
      CloudinaryResponse res = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          folder: 'profile_pics',
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return res.secureUrl;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  // Post Image/Video Upload
  static Future<String?> uploadPost(File file, bool isVideo) async {
    try {
      CloudinaryResponse res = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder: 'posts',
          resourceType: isVideo
              ? CloudinaryResourceType.Video
              : CloudinaryResourceType.Image,
        ),
      );
      return res.secureUrl;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  // Story Upload
  static Future<String?> uploadStory(File file, bool isVideo) async {
    try {
      CloudinaryResponse res = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          file.path,
          folder: 'stories',
          resourceType: isVideo
              ? CloudinaryResourceType.Video
              : CloudinaryResourceType.Image,
        ),
      );
      return res.secureUrl;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  // Voice Message Upload
  static Future<String?> uploadVoiceMessage(File audio) async {
    try {
      CloudinaryResponse res = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          audio.path,
          folder: 'voice_messages',
          resourceType: CloudinaryResourceType.Auto,
        ),
      );
      return res.secureUrl;
    } catch (e) {
      print('Error: $e');
      return null;
    }
  }

  /// Derive a JPEG poster URL from a Cloudinary video URL.
  ///
  /// Cloudinary lets us pluck a single frame out of a video without uploading
  /// anything separately — splice the `so_0/` (start-offset 0 seconds)
  /// transformation right after `/video/upload/` and swap the trailing
  /// `.mp4` / `.mov` / `.webm` extension for `.jpg`. Result:
  ///
  ///   https://res.cloudinary.com/diqeeznan/video/upload/v1234/posts/abc.mp4
  ///   → https://res.cloudinary.com/diqeeznan/video/upload/so_0/v1234/posts/abc.jpg
  ///
  /// Returns `null` for empty / non-http / non-Cloudinary-video URLs so callers
  /// can decide their own fallback (we use this to backfill `thumbnailUrl`
  /// on legacy video posts that pre-date the new Firestore field).
  static String? videoThumbnailUrl(String videoUrl) {
    if (videoUrl.isEmpty) return null;
    if (!videoUrl.startsWith('http')) return null;
    const marker = '/video/upload/';
    final idx = videoUrl.indexOf(marker);
    if (idx < 0) return null;

    // Splice `so_0/` directly after `/video/upload/`.
    final head = videoUrl.substring(0, idx + marker.length);
    final tail = videoUrl.substring(idx + marker.length);
    var withSo = '${head}so_0/$tail';

    // Swap a known video extension for `.jpg`. Strip query string first so
    // we don't trip on `?ts=...` style suffixes.
    final qIdx = withSo.indexOf('?');
    final beforeQ = qIdx < 0 ? withSo : withSo.substring(0, qIdx);
    final afterQ = qIdx < 0 ? '' : withSo.substring(qIdx);
    final lower = beforeQ.toLowerCase();
    String swapped = beforeQ;
    for (final ext in const ['.mp4', '.mov', '.webm', '.m4v', '.avi']) {
      if (lower.endsWith(ext)) {
        swapped = beforeQ.substring(0, beforeQ.length - ext.length) + '.jpg';
        break;
      }
    }
    // If no known extension, append `.jpg` — Cloudinary will still resolve
    // the asset and convert.
    if (swapped == beforeQ && !lower.endsWith('.jpg')) {
      swapped = '$beforeQ.jpg';
    }
    return '$swapped$afterQ';
  }
}