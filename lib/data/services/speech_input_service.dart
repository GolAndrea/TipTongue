import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechInputService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;

  bool get isListening => _speech.isListening;

  Future<bool> initialize({
    required void Function(String status) onStatus,
    required void Function(String error) onError,
  }) async {
    if (_initialized) return true;
    _initialized = await _speech.initialize(
      onStatus: onStatus,
      onError: (err) => onError(err.errorMsg),
    );
    return _initialized;
  }

  Future<void> startListening({
    required String localeId,
    required void Function(String transcript, bool isFinal) onTranscript,
  }) async {
    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        onTranscript(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 20),
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  Future<void> stopListening() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }
}
