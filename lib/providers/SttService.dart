import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  final SpeechToText _speech = SpeechToText();

  /// Added [onDone] as an optional named parameter to support the recursive loop
  Future<void> listen(
      String langCode,
      Function(String) onResult,
      {Function? onDone}
      ) async {
    // Initialize with a status listener to detect when the engine stops
    bool available = await _speech.initialize(
      onStatus: (status) {
        // 'done' or 'notListening' means the hardware is free to be restarted
        if (status == 'done' || status == 'notListening') {
          if (onDone != null) {
            onDone();
          }
        }
      },
      onError: (val) => print('STT Error: $val'),
    );

    if (available) {
      // Map the app's simple lang code to the locale expected by speech_to_text
      final String localeId = (langCode == 'ar') ? 'ar_EG' : 'en_US';

      await _speech.listen(
        localeId: localeId,
        onResult: (val) => onResult(val.recognizedWords),
        // Ensures the mic doesn't close too quickly during short pauses
        listenMode: ListenMode.confirmation,
      );
    }
  }

  void stop() => _speech.stop();
}