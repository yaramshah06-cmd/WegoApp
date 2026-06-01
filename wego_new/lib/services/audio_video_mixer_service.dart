// ============================================================
// audio_video_mixer_service.dart
//
// Downloads a Deezer/MP3 preview clip and mixes it onto a recorded
// video using ffmpeg. The original camera-microphone audio is dropped
// (TikTok-style — only the chosen song remains in the final clip).
// ============================================================
import 'dart:io';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class AudioVideoMixerService {
  AudioVideoMixerService._();

  // Download the 30-sec preview MP3 from a remote URL (e.g. Deezer) to a
  // local file in the app's temporary directory. Returns the saved File,
  // or null on failure.
  static Future<File?> downloadPreview(String previewUrl) async {
    if (previewUrl.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(previewUrl));
      if (response.statusCode != 200) {
        debugPrint(
            'Preview download failed: ${response.statusCode} for $previewUrl');
        return null;
      }
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/song_$ts.mp3');
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return file;
    } catch (e) {
      debugPrint('Preview download error: $e');
      return null;
    }
  }

  // Mix the given audio file onto the given video file, replacing the
  // video's original audio track. Output is written to a new temp file.
  //
  // FFmpeg command:
  //   -y                  overwrite output without prompting
  //   -i <video> -i <audio>
  //   -c:v copy           keep the video stream as-is (no re-encode)
  //   -map 0:v:0          take video from the first input
  //   -map 1:a:0          take audio from the second input (the song)
  //   -shortest           stop at the end of whichever stream is shorter
  //                       (so a 10-sec recording paired with a 30-sec
  //                       preview produces a 10-sec final clip)
  //
  // Because we don't map the video's own audio (`0:a`), the camera's
  // mic recording is automatically discarded.
  //
  // Returns the mixed File on success, or null if ffmpeg fails. Callers
  // should fall back to the original video file in that case.
  static Future<File?> mixAudioIntoVideo({
    required File video,
    required File audio,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final outPath = '${dir.path}/mixed_$ts.mp4';

      // Quote the paths to survive spaces in Android temp dirs.
      final command =
          '-y -i "${video.path}" -i "${audio.path}" -c:v copy -map 0:v:0 -map 1:a:0 -shortest "$outPath"';

      final session = await FFmpegKit.execute(command);
      final rc = await session.getReturnCode();

      if (ReturnCode.isSuccess(rc)) {
        final outFile = File(outPath);
        if (await outFile.exists()) return outFile;
        debugPrint('FFmpeg reported success but output file is missing.');
        return null;
      }

      // Log failure details so we can diagnose codec/container issues.
      final logs = await session.getAllLogsAsString();
      debugPrint('FFmpeg mix failed (rc=$rc):\n$logs');
      return null;
    } catch (e) {
      debugPrint('FFmpeg mix exception: $e');
      return null;
    }
  }

  // Best-effort cleanup of song_*.mp3 and mixed_*.mp4 files left behind
  // in the temp directory. Safe to call after a successful upload.
  static Future<void> cleanupTempFiles() async {
    try {
      final dir = await getTemporaryDirectory();
      await for (final entity in dir.list()) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          if (name.startsWith('song_') || name.startsWith('mixed_')) {
            try {
              await entity.delete();
            } catch (_) {
              // Ignore; another process may still hold the file.
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Temp cleanup error: $e');
    }
  }
}
