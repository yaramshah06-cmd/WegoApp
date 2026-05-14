import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VoiceMessageHelper {
  static final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  static final FlutterSoundPlayer _player = FlutterSoundPlayer();
  static bool _isRecorderInitialized = false;
  static bool _isPlayerInitialized = false;
  static String? _recordedFilePath;

  // ── Recorder Initialize ──────────────────────────────────────
  static Future<void> initRecorder() async {
    if (!_isRecorderInitialized) {
      await _recorder.openRecorder();
      _isRecorderInitialized = true;
    }
  }

  static Future<void> initPlayer() async {
    if (!_isPlayerInitialized) {
      await _player.openPlayer();
      _isPlayerInitialized = true;
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

  // ── Recording Band karo ──────────────────────────────────────
  // Note: FFmpeg retire ho gayi hai. Pitch shift ab playback time par
  // _player ke speed control se simulate hoti hai (real semitone shift
  // nahi, lekin user ko similar voice-changer effect milta hai).
  static Future<String?> stopAndProcess() async {
    await _recorder.stopRecorder();
    return _recordedFilePath;
  }

  // ── Playback with pitch (speed-based fallback) ───────────────
  static Future<void> playRecorded({String? path}) async {
    final file = path ?? _recordedFilePath;
    if (file == null) return;
    await initPlayer();

    final prefs = await SharedPreferences.getInstance();
    final pitch = prefs.getInt('selected_pitch') ?? 0;
    final rate = _pitchToRate(pitch);

    await _player.startPlayer(fromURI: file, codec: Codec.aacADTS);
    try {
      await _player.setSpeed(rate);
    } catch (_) {}
  }

  static Future<void> stopPlayback() async {
    if (_isPlayerInitialized) {
      await _player.stopPlayer();
    }
  }

  // ── Pitch → Playback rate mapping ────────────────────────────
  // semitones range ~ -8..+8 → rate 0.6..1.6
  static double _pitchToRate(int semitones) {
    final r = 1.0 + (semitones * 0.06);
    if (r < 0.5) return 0.5;
    if (r > 2.0) return 2.0;
    return r;
  }

  // ── Cleanup ──────────────────────────────────────────────────
  static Future<void> dispose() async {
    if (_isRecorderInitialized) {
      await _recorder.closeRecorder();
      _isRecorderInitialized = false;
    }
    if (_isPlayerInitialized) {
      await _player.closePlayer();
      _isPlayerInitialized = false;
    }
  }
}
