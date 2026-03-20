import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {

  final FlutterTts tts = FlutterTts();
  final stt.SpeechToText speech = stt.SpeechToText();

  bool isListening = false;

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
        }

        if (words.contains("arabic")) {
          selectLanguage("Arabic");
        }

      });
    }
  }

  void selectLanguage(String language) async {

    await confirmLanguage(language);

    await Future.delayed(const Duration(seconds: 2));

    Navigator.pushReplacementNamed(context, '/tutorial1');
  }

  Widget languageButton(String code, String text) {
    return Container(
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
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),

          TextButton(
            onPressed: () => selectLanguage(text),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),

          const Icon(
            Icons.mic,
            color: Colors.red,
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F8F8),

      body: SafeArea(
        child: Column(
          children: [

            const SizedBox(height: 40),

            /// globe icon
            Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.language,
                size: 45,
                color: Colors.red,
              ),
            ),

            const SizedBox(height: 30),

            const Text(
              "Choose Your Language",
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            const Text(
              "Select your preferred language",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 40),

            languageButton("GB", "English"),

            languageButton("SA", "العربية"),

            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [

                Icon(
                  Icons.mic,
                  color: Colors.red,
                ),

                SizedBox(width: 10),

                Text(
                  'Say "English" or "Arabic"',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),

            const Spacer(),

            Padding(
              padding: const EdgeInsets.only(bottom: 30),
              child: FloatingActionButton(
                backgroundColor: Colors.red,
                onPressed: startListening,
                child: const Icon(Icons.mic,
                color: Colors.white,
                ),
              ),
            )
          ],
        ),
      ),
    );
  } }