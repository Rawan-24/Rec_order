import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  final SpeechToText _speech = SpeechToText();

  Future<bool> init() async {
    return await _speech.initialize(
      onError: (val) => print("STT Error: $val"),
      onStatus: (status) => print("STT Status: $status"),
    );
  }

  Future<void> listen(
      String langCode,
      Function(String) onResult,
      ) async {

    bool available = await _speech.initialize(
      onError: (val) => print('STT Error: $val'),
    );

    if (!available) return;

    // ✅ FIX: dynamic locale instead of hardcoding Arabic
    String locale = (langCode == "ar") ? "ar_EG" : "en_US";

    await _speech.listen(
      localeId: locale,
      listenFor: const Duration(hours: 24),
      pauseFor: const Duration(seconds: 3),
      partialResults: true, // 🔥 ADD THIS
      listenMode: ListenMode.dictation,

      onResult: (result) {
        final text = result.recognizedWords;
        if (text.isNotEmpty) {
          onResult(text);
        }
      },
    );
  }

  void stop() {
    _speech.stop();
  }

  bool get isListening => _speech.isListening;
}