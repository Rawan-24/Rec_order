import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Required for Provider.of
import 'package:grad_project/providers/LanguageProvider.dart'; // Ensure path is correct
import 'SttService.dart';
import 'TtsService.dart';

class AppAudioProvider extends ChangeNotifier {
  final TtsService _ttsService = TtsService();
  final SttService _sttService = SttService();

  bool _isListening = false;
  bool _isAlwaysOn = false;
  String _lastWords = "";

  // Getters
  bool get isListening => _isListening;
  bool get isAlwaysOn => _isAlwaysOn;
  String get lastWords => _lastWords;

  // ─── TTS Settings (For VoiceSettingsPage) ─────────────────────────

  void setSpeechRate(double rate) {
    _ttsService.setRate(rate);
    notifyListeners();
  }

  void setVolume(double volume) {
    _ttsService.setVolume(volume);
    notifyListeners();
  }

  // ─── TTS Logic ───────────────────────────────────────────────────

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

  Future<void> stopTts() async {
    await _ttsService.stop();
  }

  // ─── STT Logic (Always-On & Toggle) ──────────────────────────────

  /// Toggles the continuous "Assistant" mode
  void toggleAlwaysOn(String langCode, BuildContext context) {
    _isAlwaysOn = !_isAlwaysOn;
    notifyListeners();

    if (_isAlwaysOn) {
      _startContinuousLoop(langCode, context);
    } else {
      stopListening();
    }
  }

  /// The recursive loop that keeps the mic open
  Future<void> _startContinuousLoop(String langCode, BuildContext context) async {
    if (!_isAlwaysOn) return;

    _isListening = true;
    notifyListeners();

    try {
      await _sttService.listen(
        langCode,
            (words) {
          _lastWords = words;
          notifyListeners();

          // Trigger NLP analysis immediately as words arrive
          processNlpCommand(words, context);
        },
        onDone: () {
          if (_isAlwaysOn) {
            // Wait 500ms before restarting to save CPU/Battery
            Future.delayed(const Duration(milliseconds: 500), () {
              if (_isAlwaysOn) _startContinuousLoop(langCode, context);
            });
          }
        },
      );
    } catch (e) {
      debugPrint("Always-On STT Error: $e");
      _isAlwaysOn = false;
      _isListening = false;
      notifyListeners();
    }
  }

  /// Manual toggle (Legacy/Standard)
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
    _isAlwaysOn = false;
    notifyListeners();
  }
  Future<void> stop() async {
    // 1. Stop Speech-to-Text
    _sttService.stop();
    _isListening = false;
    _isAlwaysOn = false; // Turn off continuous mode if it's active

    // 2. Stop Text-to-Speech
    await _ttsService.stop();

    // 3. Update UI
    notifyListeners();
    debugPrint("AppAudioProvider: All audio services stopped.");
  }

  // ─── NLP Engine (The Brain) ──────────────────────────────────────

  /// Corrected: Now accesses LanguageProvider via Context
  Future<void> processNlpCommand(String text, BuildContext context) async {
    if (text.isEmpty) return;

    // Access the LanguageProvider to get translations and current lang code
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    String lowerText = text.toLowerCase();

    // Mapping intent to navigation/actions
    if (lowerText.contains("order") || lowerText.contains("طلبات")) {
      Navigator.pushNamed(context, '/orders');
      // Fetches the 'Opening your orders' translation from your AR/EN map
      speak(lp.getText("order_history_tile"), lp.currentLanguage);
    }
    else if (lowerText.contains("cart") || lowerText.contains("سلة")) {
      Navigator.pushNamed(context, '/cart');
      speak(lp.getText("cart_title"), lp.currentLanguage);
    }
    else if (lowerText.contains("track") || lowerText.contains("تتبع")) {
      Navigator.pushNamed(context, '/TrackOrderScreen');
      // Using a custom key from your language map
      speak(lp.getText("track_order_title"), lp.currentLanguage);
    }
    else if (lowerText.contains("home") || lowerText.contains("الرئيسية")) {
      Navigator.pushNamed(context, '/home');
    }

    notifyListeners();
  }
}