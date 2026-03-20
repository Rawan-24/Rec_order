import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'Sign_in.dart';

class VoiceOnboardingScreen extends StatefulWidget {
  const VoiceOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<VoiceOnboardingScreen> createState() => _VoiceOnboardingScreenState();
}

class _VoiceOnboardingScreenState extends State<VoiceOnboardingScreen> {
  final PageController _controller = PageController();
  int currentPage = 0;

  late stt.SpeechToText _speech;
  bool isListening = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  // 🎤 Start listening
  void startListening() async {
    bool available = await _speech.initialize();

    if (available) {
      setState(() => isListening = true);

      _speech.listen(onResult: (result) {
        String text = result.recognizedWords.toLowerCase();

        if (text.contains("next")) {
          nextPage();
        } else if (text.contains("skip")) {
          skip();
        }
      });
    }
  }

  void stopListening() {
    _speech.stop();
    setState(() => isListening = false);
  }

  void nextPage() {
    if (currentPage < 2) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      skip();
    }
  }

  void skip() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const SignInScreen(),
      ),
    );
  }




  Widget buildPage(String title, String subtitle) {
    const primaryRed = Color(0xFFEB1B33);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onLongPress: startListening,
          onLongPressUp: stopListening,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFEB1B33), Color(0xFFB71C1C)],
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryRed.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              Icons.mic,
              color: Colors.white,
              size: 50,
            ),
          ),
        ),

        const SizedBox(height: 30),

        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.black54),
        ),
      ],
    );
  }

  Widget buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentPage == index ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: currentPage == index
                ? const Color(0xFFEB1B33)
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFEB1B33);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: skip,
                child: const Text("Skip"),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() => currentPage = index);
                },
                children: [
                  buildPage(
                    "Tap & Hold to Speak",
                    "Press and hold the microphone button,\nthen speak your order clearly",
                  ),
                  buildPage(
                    "Listen to Confirmations",
                    "The app will read back your selections for verification",
                  ),
                  buildPage(
                    " Say Commands Anytime",
                    "Try:Ord er pizza, Show my cart, Track order"
                  ),
                ],
              ),
            ),

            buildDots(),

            const SizedBox(height: 20),

            // Next Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: nextPage,
                  child: Text(
                    currentPage == 2 ? "Start" : "Next >",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic, size: 16, color: Colors.black45),
                SizedBox(width: 6),
                Text(
                  'Say "Next" or "Skip"',
                  style: TextStyle(color: Colors.black45),
                ),
              ],
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

}