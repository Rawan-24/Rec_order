import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:provider/provider.dart';

import '../services/ai_service.dart';
import 'package:permission_handler/permission_handler.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  bool isSaving = false;
  bool _shouldListen = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audio = Provider.of<AppAudioProvider>(context, listen: false);

      await audio.initSpeech();
      await _speakIntro();
    });
  }

  Future<void> _speakIntro() async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop();
    await audio.speak("Welcome. To use English, say English.", "en-US");
    await audio.speak("مرحباً. لاستخدام العربية، قل عربي", "ar-SA");

    if (mounted) {
      _shouldListen = true;
      _startListening();
    }
  }

  // ─────────────────────────────────────────
  // ALWAYS-ON LISTEN LOOP  (same pattern as SignIn)
  // ─────────────────────────────────────────
  void _startListening() async {
    if (!_shouldListen || !mounted) return;

    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    if (audio.speech.isListening) {
      debugPrint("Mic already open — skipping duplicate start");
      return;
    }

    // Request mic permission if not yet granted
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    await audio.toggleListening(
      "en", // language selection screen always listens in English first
      // ── onResult ──────────────────────────────────────────────
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;

        print("USER SAID: $text");

        final response = await AIService.sendMessage(text);
        final command = (response['command'] ?? "unknown").toString();

        print("AI COMMAND: $command");

        if (command == "language_en") {
          await selectLanguage("en");
        } else if (command == "language_ar") {
          await selectLanguage("ar");
        } else {
          // Unrecognised — re-prompt and keep listening
          if (mounted) {
            final audio2 =
            Provider.of<AppAudioProvider>(context, listen: false);
            await audio2.speak(
              'Say "English" or "Arabic" — قل إنجليزي أو عربي',
              "en-US",
            );
          }
        }

        _isProcessing = false;

        // Restart mic after each result (mirrors SignIn pattern)
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_shouldListen && mounted) _startListening();
        });
      },
      // ── onError: retry on silence / no-match ──────────────────
      onError: (errorMsg) {
        // AudioProvider handles error_no_match automatically.
        // Only restart here for genuine errors.
        debugPrint("STT real error on screen: $errorMsg");
      },
    );
  }

  Future<void> selectLanguage(String code) async {
    if (isSaving || !mounted) return;

    _shouldListen = false;
    setState(() => isSaving = true);

    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false);

    try {
      await audio.stop();
      languageProvider.setLanguage(code);
      await DatabaseService().updateUserLanguage(code);

      final confirmMsg =
      code == 'ar' ? "تم اختيار اللغة العربية" : "English selected";
      await audio.speak(confirmMsg, code == 'ar' ? "ar-SA" : "en-US");

      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) Navigator.pushReplacementNamed(context, '/tutorial1');
    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        _shouldListen = true;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
        _startListening();
      }
    }
  }

  @override
  void dispose() {
    _shouldListen = false;
    super.dispose();
  }

  // ─────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────
  Widget _languageButton(String flag, String text, String langCode) {
    return InkWell(
      onTap: isSaving ? null : () => selectLanguage(langCode),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        height: 75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(flag,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
            Text(text,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
            const Icon(Icons.mic, color: Colors.red),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audio = Provider.of<AppAudioProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xffF8F8F8),
      body: SafeArea(
        child: isSaving
            ? const Center(
            child: CircularProgressIndicator(color: Colors.red))
            : Column(
          children: [
            const SizedBox(height: 40),
            Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle),
              child:
              const Icon(Icons.language, size: 45, color: Colors.red),
            ),
            const SizedBox(height: 30),
            const Text("Choose Your Language",
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Select your preferred language",
                style:
                TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 40),
            _languageButton("🇬🇧", "English", "en"),
            _languageButton("🇪🇬", "Arabic", "ar"),
            const SizedBox(height: 40),
            // ── Mic status indicator ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic,
                    color: audio.isListening
                        ? Colors.green
                        : Colors.red),
                const SizedBox(width: 10),
                Text(
                  audio.isListening
                      ? (audio.lastWords.isEmpty
                      ? "Listening..."
                      : audio.lastWords)
                      : 'Say "English" or "Arabic"',
                  style: const TextStyle(
                      fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: FloatingActionButton(
                backgroundColor:
                audio.isListening ? Colors.green : Colors.red,
                onPressed: _startListening,
                child: const Icon(Icons.mic, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}