import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/ai_service.dart';
import 'TtsService.dart';
import 'LanguageProvider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AppAudioProvider — drop-in replacement, zero screen changes needed.
//
// Screens keep calling exactly what they already call:
//   audio.initSpeech()
//   audio.toggleListening(lang, onResult)
//   audio.speak(text, lang)
//   audio.stop()          ← in dispose()
//   audio.stopAll()       ← on logout
//
// The provider keeps the mic open forever between toggleListening and stop().
// ─────────────────────────────────────────────────────────────────────────────

class AppAudioProvider extends ChangeNotifier {
  final TtsService    _ttsService = TtsService();
  final SpeechToText  speech      = SpeechToText();

  TextEditingController? phoneController;
  void setPhoneController(TextEditingController c) => phoneController = c;

  // ── Public state ───────────────────────────────────────────────────────────
  bool   _isListening      = false;
  bool   _isAlwaysOn       = true;
  bool   _feedbackEnabled  = true;
  String _lastWords        = "";

  bool   get isListening   => _isListening;
  bool   get isAlwaysOn    => _isAlwaysOn;
  String get lastWords     => _lastWords;

  // ── Internal flags ─────────────────────────────────────────────────────────
  bool _isSpeaking        = false;
  bool _isRestarting      = false;
  bool _speechInitialized = false;
  int  _noMatchCount      = 0;
  bool _resultJustDelivered = false;
  // ── Stored callbacks (set by toggleListening, kept forever) ───────────────
  String?           _currentLang;
  Function(String)? _currentOnResult;
  Function(String)? _currentOnError;
  Function(String)? _pendingErrorCallback;

  // ── initSpeech — safe to call multiple times ───────────────────────────────


  Future<bool> initSpeech() async {
    if (_speechInitialized) return true;

    final status = await Permission.microphone.request();
    debugPrint("MIC PERMISSION: $status");
    if (!status.isGranted) {
      debugPrint("MICROPHONE PERMISSION DENIED");
      return false;
    }

    _speechInitialized = await speech.initialize(
      onStatus: _onStatus,
      onError:  _onError,
    );
    return _speechInitialized;
  }

// ── STT status handler ─────────────────────────────────────────────────────
  void _onStatus(String status) {
    debugPrint("MIC STATUS: $status");

    if (status == "listening") {
      _isListening = true;
      notifyListeners();
      return;
    }

    if (status == "notListening") {
      _isListening = false;
      notifyListeners();
      return;
    }

    if (status == "done") {
      _isListening = false;
      notifyListeners();

      if (!_isSpeaking && !_isRestarting) {
        if (_resultJustDelivered) {
          // Screen's 600ms callback will restart first,
          // this 3s safety net fires only if it doesn't
          _scheduleRestart(3000);
        } else {
          _scheduleRestart(300);
        }
      }
      _resultJustDelivered = false;
    }
  }

// ── STT error handler ──────────────────────────────────────────────────────
  void _onError(dynamic error) {
    debugPrint("MIC ERROR: ${error.errorMsg}");
    _isListening = false;
    notifyListeners();

    if (_isSpeaking) return;

    switch (error.errorMsg) {
      case "error_no_match":
        _scheduleRestart(3000);
        break;

      case "error_speech_timeout":
        _scheduleRestart(1000);
        break;

      case "error_client":
      // ✅ If words were captured before session died, submit them now
        if (_lastWords.isNotEmpty && _currentOnResult != null) {
          final words = _lastWords;
          _lastWords = "";
          _resultJustDelivered = true;
          notifyListeners();
          _currentOnResult!(words);  // treat partial as final
        }
        _scheduleRestart(5000);
        break;

      default:
        final cb = _pendingErrorCallback;
        _pendingErrorCallback = null;
        if (cb != null) cb(error.errorMsg);
        _scheduleRestart(2000);
    }
  }
  Future<void> onLanguageChanged(String newLang) async {
    if (_currentLang == newLang) return;
    debugPrint("Language changed to $newLang — restarting mic");
    _currentLang = newLang;

    if (speech.isListening) {
      speech.stop();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (_isAlwaysOn && _currentOnResult != null && !_isSpeaking) {
      _scheduleRestart(0);
    }
  }
// ── Single-slot restart guard ──────────────────────────────────────────────
  void _scheduleRestart(int delayMs) {
    if (_isSpeaking)              return;
    if (!_isAlwaysOn)             return;
    if (_currentOnResult == null) return;
    if (_isRestarting)            return;  // already scheduled — don't stack

    _isRestarting = true;
    Future.delayed(Duration(milliseconds: delayMs), () {
      _isRestarting = false;
      if (!_isSpeaking && _isAlwaysOn && !speech.isListening) {
        _startListeningInternal();
      }
    });
  }

  Future<void> _startListeningInternal() async {
    if (speech.isListening || _isSpeaking)  return;
    if (_currentOnResult == null)           return;
    if (_currentLang == null)               return;

    _pendingErrorCallback = _currentOnError;
    _isListening = true;
    notifyListeners();

    final locale = (_currentLang == "ar") ? "ar_EG" : "en_US";

    await speech.listen(
      localeId:      locale,
      cancelOnError: false,
// AFTER
      listenFor: const Duration(minutes: 5),
      pauseFor:  const Duration(seconds: 5),
      onResult: (result) {
        _lastWords = result.recognizedWords;
        notifyListeners();

        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          _noMatchCount         = 0;
          _isListening          = false;
          _pendingErrorCallback = null;
          _resultJustDelivered  = true;
          notifyListeners();
          _currentOnResult!(result.recognizedWords);
          // onStatus("done") fires next → _scheduleRestart → mic reopens
        }
      },
    );
  }

  // ── toggleListening — screens call this exactly as before ─────────────────
  // Stores the callbacks and opens the mic.
  // Calling it again from a new screen just updates the callbacks — mic stays open.
  Future<void> toggleListening(
      String lang,
      Function(String) onResult, {
        Function(String)? onError,
      }) async {
    _currentLang     = lang;
    _currentOnResult = onResult;
    _currentOnError  = onError;
    _noMatchCount    = 0;
    _isRestarting        = false;        // ✅ cancel any pending delayed restart
    _resultJustDelivered = false;        // ✅ clear stale flag from previous screen
    if (!_speechInitialized) await initSpeech();

    if (speech.isListening) {
      // Mic already open — callbacks updated, nothing else needed
      debugPrint("Mic already open — callbacks updated for new screen");
      return;
    }

    if (_isSpeaking) {
      // TTS playing — mic will open automatically when it finishes
      debugPrint("TTS active — mic will open after speech finishes");
      return;
    }

    await _startListeningInternal();
  }

  // ── speak() — screens call this exactly as before ─────────────────────────
  // Pauses mic → speaks → reopens mic automatically.
  Future<void> speak(String text, String langCode) async {
    if (!_feedbackEnabled) return;

    // 1. Pause mic
    _isSpeaking   = true;
    _isRestarting = false;
    if (speech.isListening) speech.stop();
    notifyListeners();

    // 2. Wire completion handler BEFORE speak() to avoid race condition
    final completer = Completer<void>();
    _ttsService.setCompletionHandler(() {
      if (!completer.isCompleted) completer.complete();
    });

    await _ttsService.speak(text, langCode);

    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () => debugPrint("TTS timeout — continuing"),
    );

    // 3. Small buffer for Android audio focus release
    await Future.delayed(const Duration(milliseconds: 200));

    // 4. Resume mic
    _isSpeaking = false;
    notifyListeners();

    if (_isAlwaysOn && _currentOnResult != null) {
      _scheduleRestart(800);
    }
  }

  // ── stop() — screens call this in dispose() ────────────────────────────────
  // Stops mic and TTS but keeps callbacks so the next screen's
  // toggleListening() call can pick up immediately.
  Future<void> stop() async {
    _isSpeaking   = false;
    _isRestarting = false;
    if (speech.isListening) speech.stop();
    _isListening          = false;
    _pendingErrorCallback = null;
    await _ttsService.stop();
    notifyListeners();
    debugPrint("AppAudioProvider: stopped.");
    // ✅ Safety net — if the parent screen's toggleListening() fires first,
    // it cancels this restart. If not, this brings the mic back automatically.
    if (_isAlwaysOn && _currentOnResult != null) {
      _scheduleRestart(1500);
    }
  }

  // ── stopAll() — logout / app close ────────────────────────────────────────
  Future<void> stopAll() async {
    _isAlwaysOn      = false;
    _isSpeaking      = false;
    _isRestarting    = false;
    _noMatchCount    = 0;
    _currentLang          = null;
    _currentOnResult      = null;
    _currentOnError       = null;
    _pendingErrorCallback = null;
    speech.stop();
    _isListening = false;
    await _ttsService.stop();
    notifyListeners();
  }

  // ── stopListening() ───────────────────────────────────────────────────────
  void stopListening() {
    _isRestarting = false;
    if (speech.isListening) speech.stop();
    _isListening          = false;
    _pendingErrorCallback = null;
    notifyListeners();
  }

  // ── setAlwaysOn ───────────────────────────────────────────────────────────
  void setAlwaysOn(bool value) {
    _isAlwaysOn = value;
    notifyListeners();
    if (!value) {
      speech.stop();
      _isListening  = false;
      _isRestarting = false;
      notifyListeners();
    } else {
      if (_currentOnResult != null) _scheduleRestart(0);
    }
  }

  void toggleAlwaysOn(String langCode, BuildContext context) {
    _isAlwaysOn = !_isAlwaysOn;
    notifyListeners();
    if (!_isAlwaysOn) stop();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  String getTtsLang(LanguageProvider lp) =>
      lp.isEnglish ? "en-US" : "ar-SA";

  void setSpeechRate(double rate) => _ttsService.setRate(rate);
  void setVolume(double volume)   => _ttsService.setVolume(volume);
  void setPitch(double pitch)     => _ttsService.setPitch(pitch);

  void setFeedbackEnabled(bool enabled) {
    _feedbackEnabled = enabled;
    notifyListeners();
  }

  Future<void> stopTts() async => await _ttsService.stop();

  String detectLanguage(String text) =>
      RegExp(r'[\u0600-\u06FF]').hasMatch(text) ? "ar" : "en";

  Future<void> processNlpCommand(String text, BuildContext context) async {
    if (text.isEmpty) return;
    final aiResponse = await AIService.sendMessage(text);
    final command = (aiResponse["command"] ?? "unknown").toString();
    debugPrint("AI COMMAND (AudioProvider): $command");
    notifyListeners();
  }
}