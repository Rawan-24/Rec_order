import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  final SpeechToText _speech = SpeechToText();

  /// [langCode] should be 'ar' or 'en' (matches your LanguageProvider values).
  Future<void> listen(String langCode, Function(String) onResult) async {
    bool available = await _speech.initialize();
    if (available) {
      // Map the app's simple lang code to the locale expected by speech_to_text
      final String localeId = (langCode == 'ar') ? 'ar_EG' : 'en_US';
      _speech.listen(
        localeId: localeId,
        onResult: (val) => onResult(val.recognizedWords),
      );
    }
  }

  void stop() => _speech.stop();
}
