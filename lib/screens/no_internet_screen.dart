import 'package:flutter/material.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart'; // Import Provider
import 'package:provider/provider.dart';

class NoInternetScreen extends StatefulWidget {
  const NoInternetScreen({super.key});

  @override
  State<NoInternetScreen> createState() => _NoInternetScreenState();
}

class _NoInternetScreenState extends State<NoInternetScreen> {

  @override
  void initState() {
    super.initState();
    // Announce the error immediately so the user knows why the app stopped
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceOfflineStatus();
    });
  }

  void _announceOfflineStatus() {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    String msg = lp.isRTL
        ? "عذراً، لا يوجد اتصال بالإنترنت. يرجى التحقق من الشبكة والمحاولة مرة أخرى."
        : "Sorry, there is no internet connection. Please check your network and try again.";

    audio.speak(msg, lp.currentLanguage);
  }

  void _handleVoiceRetry(AppAudioProvider audio, LanguageProvider lp) {
    audio.toggleListening(lp.currentLanguage, (words) {
      String command = words.toLowerCase();

      // Voice Command: Try Again
      if (command.contains("retry") || command.contains("try") || command.contains("إعادة") || command.contains("حاول")) {
        audio.speak(lp.isRTL ? "جاري محاولة الاتصال" : "Attempting to reconnect", lp.currentLanguage);
        _triggerRetry();
      }
    });
  }

  void _triggerRetry() {
    // Implement your logic to re-check connectivity or restart the app flow
    print("Retrying connection...");
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
              // Visual Indicator
              Icon(
                  audio.isListening ? Icons.graphic_eq : Icons.wifi_off_rounded,
                  size: 80,
                  color: audio.isListening ? Colors.green : primaryRed
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

              // Manual Retry Button
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

              // Voice Interaction Hint
              GestureDetector(
                onTap: () => _handleVoiceRetry(audio, lp),
                child: Column(
                  children: [
                    CircleAvatar(
                      backgroundColor: audio.isListening ? Colors.green : Colors.grey[200],
                      child: Icon(
                          Icons.mic,
                          color: audio.isListening ? Colors.white : Colors.grey[600]
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      audio.isListening ? "Listening..." : "Tap to use voice",
                      style: TextStyle(color: audio.isListening ? Colors.green : Colors.grey),
                    )
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