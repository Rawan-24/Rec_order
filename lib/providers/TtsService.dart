import 'dart:ui';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  // Track settings locally within the service
  double _currentRate = 0.5;
  double _currentVolume = 1.0;

  void setCompletionHandler(VoidCallback handler) {
    _tts.setCompletionHandler(handler);
  }

  // NEW: Setter for Speech Rate
  Future<void> setRate(double rate) async {
    _currentRate = rate;
    await _tts.setSpeechRate(rate);
  }

  // NEW: Setter for Volume
  Future<void> setVolume(double volume) async {
    _currentVolume = volume;
    await _tts.setVolume(volume);
  }

  Future<void> speak(String text, String langCode) async {
    final String ttsLang = langCode.contains('ar') ? 'ar-EG' : 'en-US';

    await _tts.setLanguage(ttsLang);
    await _tts.setPitch(1.0);

    // UPDATED: Use the stored rate and volume instead of hardcoded values
    await _tts.setSpeechRate(_currentRate);
    await _tts.setVolume(_currentVolume);

    await _tts.speak(text);
  }

  Future<void> stop() async => await _tts.stop();
}