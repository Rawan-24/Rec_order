import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
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
    // Auto-announce instructions when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final audio = Provider.of<AppAudioProvider>(context, listen: false);
      audio.speak("Choose your language. Say English or Arabic.", "en");
    });
  }

  // UPDATED: Logic to handle voice selection
  void _toggleVoiceSelection() {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Default to 'en' for initial detection during selection
    audio.toggleListening("en", (words) {
      String command = words.toLowerCase();
      if (command.contains("english")) {
        selectLanguage("en");
      } else if (command.contains("arabic") || command.contains("العربية") || command.contains("عربي")) {
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
      // 1. Update Provider and Firestore
      languageProvider.setLanguage(code);
      await DatabaseService().updateUserLanguage(code);

      // 2. Audio Confirmation in the selected language
      String confirmMsg = (code == 'ar') ? "تم اختيار اللغة العربية" : "English selected";
      audio.speak(confirmMsg, code);

      // 3. Small delay so the user hears the confirmation before transition
      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        // Navigate to your next screen (Tutorial or Home)
        Navigator.pushReplacementNamed(context, '/tutorial1');
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error saving language: $e"))
        );
      }
    }
  }

  Widget languageButton(String flag, String text, String langCode) {
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
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(flag, style: const TextStyle(fontSize: 24)), // Flag emoji
            Text(text, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
            const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 18),
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
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle
              ),
              child: const Icon(Icons.language, size: 45, color: Colors.red),
            ),
            const SizedBox(height: 30),
            const Text(
                "Choose Your Language",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            const Text(
                "إختر لغتك المفضلة",
                style: TextStyle(fontSize: 18, color: Colors.black54)
            ),
            const SizedBox(height: 40),

            languageButton("🇬🇧", "English", "en"),
            languageButton("🇪🇬", "العربية", "ar"),

            const SizedBox(height: 40),

            // Status Text
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                    audio.isListening ? Icons.graphic_eq : Icons.mic_none,
                    color: audio.isListening ? Colors.green : Colors.grey
                ),
                const SizedBox(width: 10),
                Text(
                  audio.isListening
                      ? "Listening..."
                      : 'Say "English" or "Arabic"',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: FloatingActionButton(
                backgroundColor: audio.isListening ? Colors.green : Colors.red,
                onPressed: _toggleVoiceSelection,
                child: Icon(
                    audio.isListening ? Icons.stop : Icons.mic,
                    color: Colors.white
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}