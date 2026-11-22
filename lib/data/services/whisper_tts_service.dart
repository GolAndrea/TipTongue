import 'package:flutter_tts/flutter_tts.dart';

/// Outputs the single suggested word at a low, soft "whisper-like" level
/// suitable for Ray-Ban Meta open-ear temple speakers or earbuds.
class WhisperTtsService {
  final FlutterTts _tts = FlutterTts();
  bool _ready = false;

  Future<void> _ensureReady() async {
    if (_ready) return;
    await _tts.setSpeechRate(0.43);
    await _tts.setPitch(0.95);
    _ready = true;
  }

  Future<void> speakWhisper({
    required String word,
    required String localeId,
    required double volume,
  }) async {
    if (word.trim().isEmpty) return;
    await _ensureReady();
    await _tts.setLanguage(localeId);
    await _tts.setVolume(volume.clamp(0.05, 1.0));
    await _tts.stop();
    await _tts.speak(word.trim());
  }

  Future<void> stop() => _tts.stop();
}
