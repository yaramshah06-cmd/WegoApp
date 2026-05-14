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
}