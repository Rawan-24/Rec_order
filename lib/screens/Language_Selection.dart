import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart'; // Ensure this matches your file name
import 'package:provider/provider.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    // Use the central provider to speak instructions on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audio = Provider.of<AppAudioProvider>(context, listen: false);
      audio.speak("Choose your language. Say English or Arabic.", "en");
    });
  }

  void startListening() {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Default to 'en' for language selection logic
    audio.toggleListening("en", (words) {
      String command = words.toLowerCase();
      if (command.contains("english")) {
        selectLanguage("en");
      } else if (command.contains("arabic") || command.contains("العربية")) {
        selectLanguage("ar");
      }
    });
  }

  void selectLanguage(String code) async {
    if (isSaving) return;

    setState(() => isSaving = true);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    try {
      // 1. Update Database & Provider
      languageProvider.setLanguage(code);
      await DatabaseService().updateUserLanguage(code);

      // 2. Audio Confirmation
      String confirmMsg = (code == 'ar') ? "تم اختيار اللغة العربية" : "English selected";
      await audio.speak(confirmMsg, code);

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pushReplacementNamed(context, '/tutorial1');
    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Widget languageButton(String flag, String text, String langCode) {
    return InkWell(
      onTap: isSaving ? null : () => selectLanguage(langCode),
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
            Text(flag, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
            Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
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
            ? const Center(child: CircularProgressIndicator(color: Colors.red))
            : Column(
          children: [
            const SizedBox(height: 40),
            Container(
              height: 100, width: 100,
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.language, size: 45, color: Colors.red),
            ),
            const SizedBox(height: 30),
            const Text("Choose Your Language", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Select your preferred language", style: TextStyle(fontSize: 16, color: Colors.black54)),
            const SizedBox(height: 40),

            languageButton("GB", "English", "en"),
            languageButton("SA", "Arabic", "ar"),

            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, color: audio.isListening ? Colors.green : Colors.red),
                const SizedBox(width: 10),
                Text(
                  audio.isListening ? (audio.lastWords.isEmpty ? "Listening..." : audio.lastWords) : 'Say "English" or "Arabic"',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: FloatingActionButton(
                backgroundColor: audio.isListening ? Colors.green : Colors.red,
                onPressed: startListening,
                child: const Icon(Icons.mic, color: Colors.white),
              ),
            )
          ],
        ),
      ),
    );
  }
}