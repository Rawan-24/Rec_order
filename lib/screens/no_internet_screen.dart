import 'package:flutter/material.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:provider/provider.dart';

import '../services/ai_service.dart';

class NoInternetScreen extends StatefulWidget {
  const NoInternetScreen({super.key});

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> {
  bool _shouldListen = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audio = Provider.of<AppAudioProvider>(context, listen: false);
      final lp = Provider.of<LanguageProvider>(context, listen: false);
      await Future.delayed(const Duration(milliseconds: 500));
      await audio.initSpeech();
      await _speakIntro(lp);
    });
  }

  @override
  void dispose() {
    _shouldListen = false;
    super.dispose();
  }

  Future<void> _speakIntro(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();
    await audio.speak(
      lp.isEnglish
          ? "No internet connection. Please check your network and say retry to try again."
          : "لا يوجد اتصال بالإنترنت. تحقق من الشبكة وقل إعادة المحاولة للمحاولة مجدداً.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
    if (mounted) {
      _shouldListen = true;
      _startListening(lp);
    }
  }

  void _startListening(LanguageProvider lp) async {
    if (!_shouldListen || !mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (audio.speech.isListening) return;

    await audio.toggleListening(
      lp.isEnglish ? "en" : "ar",
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;

        final response = await AIService.sendMessage(text);
        final command = (response['command'] ?? "unknown").toString();

        if (command == "retry_connection") {
          await audio.speak(
            lp.isEnglish ? "Retrying connection." : "جاري إعادة المحاولة.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
          _triggerRetry();
        } else {
          await audio.speak(
            lp.isEnglish ? "Say retry to try again." : "قل إعادة المحاولة للمحاولة مجدداً.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        }

        _isProcessing = false;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_shouldListen && mounted) _startListening(lp);
        });
      },
      onError: (errorMsg) {
        // AudioProvider handles error_no_match automatically.
        // Only restart here for genuine errors.
        debugPrint("STT real error on screen: $errorMsg");
      },
    );
  }

  void _triggerRetry() {
    debugPrint("Retrying connection...");
    // Implement your connectivity re-check here
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);
    const primaryRed = Color(0xFFD32F2F);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (audio.isListening)
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.green.withOpacity(0.15),
                      ),
                    ),
                  Icon(
                    audio.isListening ? Icons.graphic_eq : Icons.wifi_off_rounded,
                    size: 80,
                    color: audio.isListening ? Colors.green : primaryRed,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                lp.getText('no_internet_title'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                lp.getText('no_internet_msg'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _triggerRetry,
                icon: const Icon(Icons.refresh),
                label: Text(lp.getText('try_again')),
              ),
              const SizedBox(height: 20),
              // Mic status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      audio.isListening ? Icons.graphic_eq : Icons.mic_none,
                      color: audio.isListening ? Colors.green : Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      audio.isListening
                          ? (lp.isEnglish ? "Listening..." : "أنا أسمعك...")
                          : (lp.isEnglish ? "Say \"retry\"" : "قل \"إعادة المحاولة\""),
                      style: TextStyle(
                        color: audio.isListening ? Colors.green : Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}