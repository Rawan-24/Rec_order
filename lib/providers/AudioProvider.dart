import 'dart:async';
import 'package:flutter/material.dart';
import 'SttService.dart';
import 'TtsService.dart';

class AppAudioProvider extends ChangeNotifier {
  final TtsService _ttsService = TtsService();
  final SttService _sttService = SttService();

  bool _isListening = false;
  String _lastWords = "";

  bool get isListening => _isListening;
  String get lastWords => _lastWords;

  // --- NEW: Added Setters to fix the VoiceSettingsPage errors ---

  /// Updates the speech rate (0.5 to 2.0)
  void setSpeechRate(double rate) {
    _ttsService.setRate(rate); // Ensure this exists in TtsService
    notifyListeners();
  }

  /// Updates the volume (0.0 to 1.0)
  void setVolume(double volume) {
    _ttsService.setVolume(volume); // Ensure this exists in TtsService
    notifyListeners();
  }

  // --- Existing Methods ---

  Future<void> speak(String text, String langCode) async {
    final completer = Completer<void>();

    _ttsService.setCompletionHandler(() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    await _ttsService.speak(text, langCode);
    return completer.future;
  }

  Future<void> stop() async {
    await _ttsService.stop();
  }

  Future<void> toggleListening(String langCode, Function(String) onFinish) async {
    _isListening = true;
    _lastWords = "";
    notifyListeners();

    try {
      await _sttService.listen(langCode, (words) {
        _lastWords = words;
        _isListening = false;
        notifyListeners();
        onFinish(words);
      });
    } catch (e) {
      _isListening = false;
      notifyListeners();
      debugPrint("STT Error: $e");
    }
  }

  void stopListening() {
    _sttService.stop();
    _isListening = false;
    notifyListeners();
  }
}