import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../services/ai_service.dart';
import 'SttService.dart';
import 'TtsService.dart';

class AppAudioProvider extends ChangeNotifier {
  final TtsService _ttsService = TtsService();
  final SttService _sttService = SttService();

  final SpeechToText speech = SpeechToText();

  TextEditingController? phoneController;

  void setPhoneController(TextEditingController controller) {
    phoneController = controller;
  }

  bool _isListening = false;
  bool _isAlwaysOn = false;
  String _lastWords = "";
  bool _feedbackEnabled = true;
  Function(String)? _pendingErrorCallback;

  bool get isListening => _isListening;
  bool get isAlwaysOn => _isAlwaysOn;
  String get lastWords => _lastWords;

  // ─────────────────────────────────────────
  // INIT SPEECH
  // ─────────────────────────────────────────
  Future<bool> initSpeech() async {
    return await speech.initialize(
      onStatus: (status) {
        debugPrint("MIC STATUS: $status");
        if (status == "done" || status == "notListening") {
          _isListening = false;
          notifyListeners();
        }
      },
      onError: (error) {
        debugPrint("MIC ERROR: $error");
        _isListening = false;
        notifyListeners();

        final cb = _pendingErrorCallback;
        _pendingErrorCallback = null;
        if (cb != null) cb(error.errorMsg);
      },
    );
  }

  String getTtsLang(LanguageProvider lp) {
    return lp.isEnglish ? "en-US" : "ar-SA";
  }

  // ─────────────────────────────────────────
  // TTS SETTINGS
  // ─────────────────────────────────────────
  void setSpeechRate(double rate) {
    _ttsService.setRate(rate);
    notifyListeners();
  }

  void setVolume(double volume) {
    _ttsService.setVolume(volume);
    notifyListeners();
  }

  // ─────────────────────────────────────────
  // TTS — 10s timeout so speak() never hangs
  // ─────────────────────────────────────────

  void setFeedbackEnabled(bool enabled) {
    _feedbackEnabled = enabled;
    notifyListeners();
  }
  Future<void> speak(String text, String langCode) async {
    if (!_feedbackEnabled) return;
    final completer = Completer<void>();

    try {
      _ttsService.setCompletionHandler(() {
        if (!completer.isCompleted) completer.complete();
      });
    } catch (_) {}

    await _ttsService.speak(text, langCode);

    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint("TTS completion timed out — continuing anyway");
      },
    );
  }

  Future<void> stopTts() async {
    await _ttsService.stop();
  }

  // ─────────────────────────────────────────
  // ALWAYS ON MODE
  // ─────────────────────────────────────────
  void toggleAlwaysOn(String langCode, BuildContext context) {
    _isAlwaysOn = !_isAlwaysOn;
    notifyListeners();

    if (_isAlwaysOn) {
      _startContinuousLoop(langCode, context);
    } else {
      stopListening();
    }
  }

  Future<void> _startContinuousLoop(
      String langCode,
      BuildContext context,
      ) async {
    if (!_isAlwaysOn) return;

    _isListening = true;
    notifyListeners();

    try {
      await _sttService.listen(
        langCode,
            (words) {
          _lastWords = words;
          notifyListeners();
          processNlpCommand(words, context);
        },
      );

      Future.delayed(const Duration(seconds: 3), () {
        if (_isAlwaysOn) _startContinuousLoop(langCode, context);
      });
    } catch (e) {
      debugPrint("STT Error: $e");
      _isAlwaysOn = false;
      _isListening = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────
  // MANUAL LISTEN
  // ─────────────────────────────────────────
  Future<void> toggleListening(
      String lang,
      Function(String) onResult, {
        Function(String)? onError,
      }) async {
    if (speech.isListening) {
      debugPrint("Mic already open — skipping duplicate start");
      return;
    }

    _pendingErrorCallback = onError;

    _isListening = true;
    notifyListeners();

    String locale = (lang == "ar") ? "ar_EG" : "en_US";

    await speech.listen(
      localeId: locale,
      cancelOnError: false,
      onResult: (result) {
        _lastWords = result.recognizedWords;
        notifyListeners();

        if (result.finalResult) {
          _isListening = false;
          _pendingErrorCallback = null;
          notifyListeners();
          onResult(result.recognizedWords);
        }
      },
    );
  }


  String detectLanguage(String text) {
    final arabicRegex = RegExp(r'[\u0600-\u06FF]');
    if (arabicRegex.hasMatch(text)) return "ar";
    return "en";
  }

  // ─────────────────────────────────────────
  // STOP LISTENING
  // ─────────────────────────────────────────
  void stopListening() {
    _sttService.stop();
    speech.stop();

    _isListening = false;
    _isAlwaysOn = false;
    _pendingErrorCallback = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────
  // STOP EVERYTHING
  // ─────────────────────────────────────────
  Future<void> stop() async {
    _sttService.stop();
    speech.stop();

    _isListening = false;
    _isAlwaysOn = false;
    _pendingErrorCallback = null;

    await _ttsService.stop();

    notifyListeners();
    debugPrint("AppAudioProvider: All audio services stopped.");
  }

  // ─────────────────────────────────────────
  // NLP ENGINE
  // Used only by always-on mode (_startContinuousLoop).
  // The manual listen screens (SignIn, SignUp, Home, Verification)
  // handle their own switch — this is the shared fallback for
  // any screen that uses toggleAlwaysOn() instead.
  // ─────────────────────────────────────────
  Future<void> processNlpCommand(String text, BuildContext context) async {
    if (text.isEmpty) return;

    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final aiResponse = await AIService.sendMessage(text);
    final command = (aiResponse["command"] ?? "unknown").toString();

    debugPrint("AI COMMAND (AudioProvider): $command");

    speech.stop();
    _sttService.stop();

    switch (command) {

    // ── Auth navigation ──────────────────────────────────────
      case "sign_in":
        Navigator.pushNamed(context, '/SignIn');
        break;

      case "open_signup":
      case "sign_up":
        Navigator.pushNamed(context, '/SignUp');
        break;

    // ── Tutorial ─────────────────────────────────────────────
      case "next":
        Navigator.pushNamed(context, '/next');
        break;

      case "skip":
        Navigator.pushNamed(context, '/home');
        break;

    // ── Language ─────────────────────────────────────────────
      case "language_en":
        lp.setLanguage("en");
        await speak("English selected", "en-US");
        break;

      case "language_ar":
        lp.setLanguage("ar");
        await speak("تم اختيار اللغة العربية", "ar-SA");
        break;

    // ── Stay signed in ───────────────────────────────────────
      case "toggle_stay_signed_in_on":
        await speak(
          lp.isEnglish ? "Stay signed in enabled" : "تم تفعيل البقاء مسجلاً",
          getTtsLang(lp),
        );
        break;

      case "toggle_stay_signed_in_off":
        await speak(
          lp.isEnglish
              ? "Stay signed in disabled"
              : "تم إيقاف البقاء مسجلاً",
          getTtsLang(lp),
        );
        break;

    // ── Phone field ──────────────────────────────────────────
      case "read_phone":
        final currentPhone = phoneController?.text ?? "";
        await speak(
          currentPhone.isEmpty
              ? (lp.isEnglish
              ? "No phone number entered yet."
              : "لم يتم إدخال رقم بعد.")
              : (lp.isEnglish
              ? "Your number is $currentPhone"
              : "رقمك هو $currentPhone"),
          getTtsLang(lp),
        );
        break;

      case "type_phone":
        String phoneValue = (aiResponse["value"] ?? "").toString().trim();
        if (!phoneValue.startsWith('+')) phoneValue = "+$phoneValue";

        if (phoneController != null) {
          phoneController!.text = phoneValue;
          notifyListeners();
        }
        await speak(
          lp.isEnglish
              ? "Phone number entered: $phoneValue."
              : "تم إدخال الرقم: $phoneValue.",
          getTtsLang(lp),
        );
        break;

      case "reenter_phone":
        phoneController?.clear();
        notifyListeners();
        await speak(
          lp.isEnglish
              ? "Phone number cleared. Please say your number."
              : "تم مسح الرقم. من فضلك قل رقمك.",
          getTtsLang(lp),
        );
        break;

    // ── Home screen navigation ───────────────────────────────
      case "open_restaurants":
        await speak(
          lp.isEnglish ? "Opening restaurants." : "جاري فتح المطاعم.",
          getTtsLang(lp),
        );
        Navigator.pushNamed(context, '/restaurants');
        break;

      case "open_track":
        await speak(
          lp.isEnglish ? "Checking your order." : "جاري تتبع طلبك.",
          getTtsLang(lp),
        );
        Navigator.pushNamed(context, '/trackOrder');
        break;

      case "open_favorites":
        await speak(
          lp.isEnglish ? "Opening favorites." : "جاري فتح المفضلة.",
          getTtsLang(lp),
        );
        Navigator.pushNamed(context, '/favorites');
        break;

      case "open_history":
        await speak(
          lp.isEnglish ? "Opening order history." : "جاري فتح السجل.",
          getTtsLang(lp),
        );
        Navigator.pushNamed(context, '/history');
        break;

      case "open_profile":
        await speak(
          lp.isEnglish ? "Opening your profile." : "جاري فتح حسابك.",
          getTtsLang(lp),
        );
        Navigator.pushNamed(context, '/profile');
        break;
      case "select_restaurant":
        final restaurantName = (aiResponse["value"] ?? "").toString().trim();
        await speak(
          lp.isEnglish
              ? "Opening $restaurantName."
              : "جاري فتح $restaurantName.",
          getTtsLang(lp),
        );
        Navigator.pushNamed(context, '/menu', arguments: restaurantName);
        break;

      case "prompt_restaurant_name":
        await speak(
          lp.isEnglish
              ? "Which restaurant would you like to order from?"
              : "من أي مطعم تريد الطلب؟",
          getTtsLang(lp),
        );
        break;
      case "read_commands":
        await speak(
          lp.isEnglish
              ? "You can say: order food, track order, favorites, history, or profile."
              : "يمكنك قول: اطلب أكل، تتبع الطلب، المفضلة، السجل، أو حسابي.",
          getTtsLang(lp),
        );
        break;

    // ── Fallback ─────────────────────────────────────────────
      default:
        await speak(
          lp.isEnglish
              ? "Say sign in, sign up, or a home screen command."
              : "قل تسجيل الدخول أو إنشاء حساب أو أمر من الشاشة الرئيسية.",
          getTtsLang(lp),
        );
    }

    notifyListeners();

    Future.delayed(const Duration(milliseconds: 600), () {
      if (_isAlwaysOn) {
        _startContinuousLoop(
          lp.isEnglish ? "en-US" : "ar-EG",
          context,
        );
      }
    });
  }
}