import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;


class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();

  bool isListening = false;
  bool isSaving = false; // New state for database updates

  @override
  void initState() {
    super.initState();
    speakInstruction();
  }

  Future speakInstruction() async {
    await tts.setLanguage("en-US");
    await tts.speak("Choose your language. Say English or Arabic.");
  }

  Future confirmLanguage(String lang) async {
    await tts.speak("$lang selected");
  }

  void startListening() async {
    bool available = await speech.initialize();
    if (available) {
      setState(() => isListening = true);
      speech.listen(onResult: (result) {
        String words = result.recognizedWords.toLowerCase();
        if (words.contains("english")) {
          selectLanguage("English");
        } else if (words.contains("arabic") || words.contains("العربية")) {
          selectLanguage("Arabic");
        }
      });
    }
  }

  void selectLanguage(String code) async { // 'code' is now 'en' or 'ar'
    if (isSaving) return;

    setState(() => isSaving = true);
    speech.stop();

    try {
      final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

      // Update Provider & Database with the code ('en' / 'ar')
      languageProvider.setLanguage(code);
      await DatabaseService().updateUserLanguage(code);

      // Set TTS and Confirmation display based on the choice
      if (code == 'ar') {
        await tts.setLanguage("ar-SA");
        await confirmLanguage("العربية");
      } else {
        await tts.setLanguage("en-US");
        await confirmLanguage("English");
      }

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pushReplacementNamed(context, '/tutorial1');

    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }
  Widget languageButton(String code, String text) {
    String langCode = (text == "English") ? "en" : "ar";
    return InkWell(onTap: isSaving ? null : () => selectLanguage(langCode),
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
            Text(
              code,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            Text(
              text,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            const Icon(Icons.mic, color: Colors.red),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.language, size: 45, color: Colors.red),
            ),
            const SizedBox(height: 30),
            const Text(
              "Choose Your Language",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold
              ,color: Colors.black,),

            ),
            const SizedBox(height: 10),
            const Text(
              "Select your preferred language",
              style: TextStyle(fontSize: 16, color: Colors.black54,),
            ),
            const SizedBox(height: 40),
            languageButton("GB", "English"),
            languageButton("SA", "Arabic"),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, color: isListening ? Colors.green : Colors.red),
                const SizedBox(width: 10),
                Text(
                  isListening ? 'Listening...' : 'Say "English" or "Arabic"',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: FloatingActionButton(
                backgroundColor: isListening ? Colors.green : Colors.red,
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