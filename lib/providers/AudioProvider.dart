import 'dart:async';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/ai_service.dart';
import 'LanguageProvider.dart';
import 'TtsService.dart';

class AppAudioProvider extends ChangeNotifier with WidgetsBindingObserver {
  final TtsService _ttsService = TtsService();
  final SpeechToText speech = SpeechToText();

  TextEditingController? phoneController;

  bool _isListening = false;
  bool _isAlwaysOn = true;
  bool _feedbackEnabled = true;
  bool _isSpeaking = false;
  bool _isStarting = false;
  bool _speechInitialized = false;
  bool _resultJustDelivered = false;
  String _lastWords = '';

  Timer? _restartTimer;
  Completer<void>? _activeSpeechCompleter;
  int _speakToken = 0;

  String? _currentLang;
  Function(String)? _currentOnResult;
  Function(String)? _currentOnError;
  Function(String)? _pendingErrorCallback;

  AppAudioProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  bool get isListening => _isListening;
  bool get isAlwaysOn => _isAlwaysOn;
  String get lastWords => _lastWords;

  void setPhoneController(TextEditingController c) => phoneController = c;

  Future<bool> initSpeech() async {
    if (_speechInitialized) return true;

    final status = await Permission.microphone.request();
    debugPrint('MIC PERMISSION: $status');
    if (!status.isGranted) {
      debugPrint('MICROPHONE PERMISSION DENIED');
      return false;
    }

    try {
      _speechInitialized = await speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
    } catch (e) {
      debugPrint('MIC INITIALIZE FAILED: $e');
      _speechInitialized = false;
    }

    return _speechInitialized;
  }

  void _onStatus(String status) {
    debugPrint('MIC STATUS: $status');

    if (status == 'listening') {
      _setListening(true);
      return;
    }

    if (status == 'notListening') {
      _setListening(false);
      if (!_isSpeaking && !_isStarting) {
        _scheduleRestart(300);
      }
      return;
    }

    if (status == 'done') {
      _setListening(false);
      if (!_isSpeaking) {
        _scheduleRestart(_resultJustDelivered ? 800 : 300);
      }
      _resultJustDelivered = false;
    }
  }

  void _onError(dynamic error) {
    final errorMsg = _speechErrorMessage(error);
    debugPrint('MIC ERROR: $errorMsg');
    _setListening(false);

    if (_isPermanentSpeechError(error)) {
      _speechInitialized = false;
    }

    if (_isSpeaking) return;

    switch (errorMsg) {
      case 'error_no_match':
      case 'error_speech_timeout':
        _scheduleRestart(500);
        break;
      case 'error_client':
        _submitPartialWordsIfAvailable();
        _scheduleRestart(1200);
        break;
      default:
        final cb = _pendingErrorCallback;
        _pendingErrorCallback = null;
        cb?.call(errorMsg);
        _scheduleRestart(1200);
    }
  }

  Future<void> onLanguageChanged(String newLang) async {
    if (_currentLang == newLang) return;

    debugPrint('Language changed to $newLang - restarting mic');
    _currentLang = newLang;
    _cancelRestart();

    if (speech.isListening) {
      await speech.stop();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (_isAlwaysOn && _currentOnResult != null && !_isSpeaking) {
      _scheduleRestart(0);
    }
  }

  Future<void> toggleListening(
    String lang,
    Function(String) onResult, {
    Function(String)? onError,
  }) async {
    _currentLang = lang;
    _currentOnResult = onResult;
    _currentOnError = onError;
    _resultJustDelivered = false;
    _cancelRestart();

    if (!_speechInitialized && !await initSpeech()) return;

    if (speech.isListening) {
      debugPrint('Mic already open - callbacks updated for new screen');
      return;
    }

    if (_isSpeaking) {
      debugPrint('TTS active - mic will open after speech finishes');
      return;
    }

    await _startListeningInternal();
  }

  Future<void> speak(String text, String langCode) async {
    if (!_feedbackEnabled) return;

    final token = ++_speakToken;
    _completeActiveSpeech();
    _cancelRestart();

    _isSpeaking = true;
    if (speech.isListening) await speech.stop();
    _setListening(false);
    notifyListeners();

    await _ttsService.stop();

    final completer = Completer<void>();
    _activeSpeechCompleter = completer;
    _ttsService.setCompletionHandler(() {
      if (_speakToken == token && !completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      await _ttsService.speak(text, langCode);
      await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () => debugPrint('TTS timeout - continuing'),
      );
      await Future.delayed(const Duration(milliseconds: 200));
    } catch (e) {
      debugPrint('TTS ERROR: $e');
    } finally {
      if (_activeSpeechCompleter == completer) {
        _activeSpeechCompleter = null;
      }
      _finishSpeakingIfCurrent(token);
    }
  }

  Future<void> stop() async {
    _speakToken++;
    _completeActiveSpeech();
    _cancelRestart();
    _isSpeaking = false;

    if (speech.isListening) await speech.stop();
    _setListening(false);
    _pendingErrorCallback = null;
    await _ttsService.stop();

    if (_isAlwaysOn && _currentOnResult != null) {
      _scheduleRestart(500);
    }
  }

  Future<void> stopAll() async {
    _speakToken++;
    _completeActiveSpeech();
    _cancelRestart();
    _isAlwaysOn = false;
    _isSpeaking = false;
    _currentLang = null;
    _currentOnResult = null;
    _currentOnError = null;
    _pendingErrorCallback = null;

    await speech.stop();
    _setListening(false);
    await _ttsService.stop();
    notifyListeners();
  }

  void stopListening() {
    _isAlwaysOn = false;
    _cancelRestart();
    if (speech.isListening) speech.stop();
    _setListening(false);
    _pendingErrorCallback = null;
    notifyListeners();
  }

  void setAlwaysOn(bool value) {
    _isAlwaysOn = value;
    notifyListeners();

    if (!value) {
      _cancelRestart();
      speech.stop();
      _setListening(false);
      return;
    }

    if (_currentOnResult != null) {
      _scheduleRestart(0);
    }
  }

  void toggleAlwaysOn(String langCode, BuildContext context) {
    setAlwaysOn(!_isAlwaysOn);
  }

  String getTtsLang(LanguageProvider lp) => lp.isEnglish ? 'en-US' : 'ar-SA';

  void setSpeechRate(double rate) => _ttsService.setRate(rate);
  void setVolume(double volume) => _ttsService.setVolume(volume);
  void setPitch(double pitch) => _ttsService.setPitch(pitch);

  void setFeedbackEnabled(bool enabled) {
    _feedbackEnabled = enabled;
    notifyListeners();
  }

  Future<void> stopTts() async {
    _speakToken++;
    _completeActiveSpeech();
    _isSpeaking = false;
    await _ttsService.stop();
    notifyListeners();

    if (_isAlwaysOn && _currentOnResult != null) {
      _scheduleRestart(500);
    }
  }

  String detectLanguage(String text) {
    return RegExp(r'[\u0600-\u06FF]').hasMatch(text) ? 'ar' : 'en';
  }

  Future<void> processNlpCommand(String text, BuildContext context) async {
    if (text.isEmpty) return;

    final aiResponse = await AIService.sendMessage(text);
    final command = (aiResponse['command'] ?? 'unknown').toString();
    debugPrint('AI COMMAND (AudioProvider): $command');
    notifyListeners();
  }

  Future<void> _startListeningInternal() async {
    if (_isStarting || speech.isListening || _isSpeaking) return;
    if (_currentOnResult == null || _currentLang == null) return;

    _cancelRestart();

    if (!_speechInitialized && !await initSpeech()) {
      _setListening(false);
      return;
    }

    _isStarting = true;
    _pendingErrorCallback = _currentOnError;
    _setListening(true);

    final locale = _currentLang == 'ar' ? 'ar_EG' : 'en_US';

    try {
      await speech.listen(
        localeId: locale,
        cancelOnError: false,
        listenFor: const Duration(minutes: 30),
        pauseFor: const Duration(seconds: 8),
        onResult: (result) {
          _lastWords = result.recognizedWords;
          notifyListeners();

          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            final onResult = _currentOnResult;
            _pendingErrorCallback = null;
            _resultJustDelivered = true;
            _setListening(false);
            onResult?.call(result.recognizedWords);
          }
        },
      );
    } catch (e) {
      debugPrint('MIC LISTEN FAILED: $e');
      _speechInitialized = false;
      _pendingErrorCallback = null;
      _setListening(false);
      _scheduleRestart(1200);
    } finally {
      _isStarting = false;
    }
  }

  void _scheduleRestart(int delayMs) {
    if (_isSpeaking) return;
    if (!_isAlwaysOn) return;
    if (_currentOnResult == null || _currentLang == null) return;

    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(milliseconds: delayMs), () {
      _restartTimer = null;
      if (!_isSpeaking &&
          _isAlwaysOn &&
          _currentOnResult != null &&
          _currentLang != null &&
          !speech.isListening) {
        _startListeningInternal();
      }
    });
  }

  void _setListening(bool value) {
    if (_isListening == value) return;
    _isListening = value;
    notifyListeners();
  }

  void _cancelRestart() {
    _restartTimer?.cancel();
    _restartTimer = null;
  }

  void _completeActiveSpeech() {
    final completer = _activeSpeechCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
    _activeSpeechCompleter = null;
  }

  void _finishSpeakingIfCurrent(int token) {
    if (_speakToken != token) return;

    _isSpeaking = false;
    notifyListeners();

    if (_isAlwaysOn && _currentOnResult != null) {
      _scheduleRestart(500);
    }
  }

  void _submitPartialWordsIfAvailable() {
    final onResult = _currentOnResult;
    if (_lastWords.isEmpty || onResult == null) return;

    final words = _lastWords;
    _lastWords = '';
    _resultJustDelivered = true;
    notifyListeners();
    onResult(words);
  }

  String _speechErrorMessage(dynamic error) {
    try {
      final msg = error.errorMsg;
      if (msg != null) return msg.toString();
    } catch (_) {
      // Fall back to the generic object string below.
    }
    return error.toString();
  }

  bool _isPermanentSpeechError(dynamic error) {
    try {
      return error.permanent == true;
    } catch (_) {
      return false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isAlwaysOn && _currentOnResult != null && !_isSpeaking) {
        _scheduleRestart(500);
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _cancelRestart();
      if (speech.isListening) speech.stop();
      _setListening(false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speakToken++;
    _completeActiveSpeech();
    _cancelRestart();
    unawaited(speech.stop());
    unawaited(_ttsService.stop());
    super.dispose();
  }
}
