import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:ffmpeg_kit_flutter_audio/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceMessageHelper {
  static final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  static bool _isRecorderInitialized = false;
  static String? _recordedFilePath;

  // ── Recorder Initialize ──────────────────────────────────────
  static Future<void> initRecorder() async {
    if (!_isRecorderInitialized) {
      await _recorder.openRecorder();
      _isRecorderInitialized = true;
    }
  }

  // ── Recording Shuru karo ─────────────────────────────────────
  static Future<void> startRecording() async {
    await initRecorder();
    final dir = await getTemporaryDirectory();
    _recordedFilePath = '${dir.path}/voice_raw.aac';

    await _recorder.startRecorder(
      toFile: _recordedFilePath,
      codec: Codec.aacADTS,
    );
  }

  // ── Recording Band karo + Pitch Change karo ──────────────────
  static Future<String?> stopAndProcess() async {
    await _recorder.stopRecorder();

    if (_recordedFilePath == null) return null;

    // SharedPreferences se pitch lo
    final prefs = await SharedPreferences.getInstance();
    final pitch = prefs.getInt('selected_pitch') ?? 0;

    // Agar koi voice select nahi ki toh as-is return karo
    if (pitch == 0) return _recordedFilePath;

    // FFmpeg se pitch change karo
    final dir = await getTemporaryDirectory();
    final outputPath = '${dir.path}/voice_changed.aac';

    final command =
        '-i $_recordedFilePath -af "asetrate=44100*${_pitchMultiplier(pitch)},aresample=44100" -y $outputPath';

    await FFmpegKit.execute(command);

    final outputFile = File(outputPath);
    if (await outputFile.exists()) {
      return outputPath; // Changed voice file
    }

    return _recordedFilePath; // Fallback original
  }

  // ── Pitch Multiplier Calculate karo ─────────────────────────
  static double _pitchMultiplier(int semitones) {
    return semitones >= 0
        ? 1.0 + (semitones * 0.06)
        : 1.0 + (semitones * 0.06);
  }

  // ── Cleanup ──────────────────────────────────────────────────
  static Future<void> dispose() async {
    await _recorder.closeRecorder();
    _isRecorderInitialized = false;
  }
}