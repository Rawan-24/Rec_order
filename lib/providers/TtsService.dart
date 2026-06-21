import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();

  double _rate = 0.5;
  double _volume = 1.0;
  double _pitch = 1.0;

  bool _initialized = false;

  VoidCallback? _onComplete;

  // ─────────────────────────────
  // INIT
  // ─────────────────────────────
  Future<void> init() async {
    if (_initialized) return;

    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(_rate);
    await _tts.setVolume(_volume);
    await _tts.setPitch(_pitch);

    // ✅ Wire ALL handlers — Android sometimes fires cancel instead of complete
    _tts.setCompletionHandler(() {
      debugPrint("TTS: completionHandler fired");
      _onComplete?.call();
    });

    _tts.setCancelHandler(() {
      debugPrint("TTS: cancelHandler fired");
      _onComplete?.call(); // treat cancel as done
    });

    _tts.setErrorHandler((msg) {
      debugPrint("TTS: errorHandler fired: $msg");
      _onComplete?.call(); // treat error as done
    });

    _initialized = true;
  }

  // ─────────────────────────────
  // SPEAK
  // ─────────────────────────────
  Future<void> speak(String text, String langCode) async {
    await init();

    final String lang =
    langCode.contains("ar") ? "ar-EG" : "en-US";

    await _tts.setLanguage(lang);
    await _tts.setSpeechRate(_rate);
    await _tts.setVolume(_volume);
    await _tts.setPitch(_pitch);

    await _tts.speak(text);
  }

  // ─────────────────────────────
  // STOP
  // ─────────────────────────────
  Future<void> stop() async {
    await _tts.stop();
  }

  // ─────────────────────────────
  // SETTINGS
  // ─────────────────────────────
  void setRate(double rate) {
    _rate = rate;
  }

  void setVolume(double volume) {
    _volume = volume;
  }

  void setPitch(double pitch) {
    _pitch = pitch;
  }

  // ─────────────────────────────
  // COMPLETION HANDLER (FIXED)
  // ─────────────────────────────
  void setCompletionHandler(VoidCallback handler) {
    _onComplete = handler;
  }
}