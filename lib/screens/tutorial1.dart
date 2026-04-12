import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'Sign_in.dart';

class VoiceOnboardingScreen extends StatefulWidget {
  const VoiceOnboardingScreen({super.key});

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

  void startListening(LanguageProvider lp) async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => isListening = true);
      _speech.listen(
        localeId: lp.isEnglish ? "en-US" : "ar-SA",
        onResult: (result) {
          String text = result.recognizedWords.toLowerCase();
          // Logic for both English and Arabic voice commands
          if (text.contains("next") || text.contains("التالي")) {
            nextPage();
          } else if (text.contains("skip") || text.contains("تخطي")) {
            skip();
          }
        },
      );
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
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );
  }

  Widget buildPage(String title, String subtitle, LanguageProvider lp) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onLongPress: () => startListening(lp),
          onLongPressUp: stopListening,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Animated Pulse Effect when listening
              if (isListening)
                const _PulseAnimation(),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEB1B33), Color(0xFFB71C1C)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFEB1B33).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 50),
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 15),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    const primaryRed = Color(0xFFEB1B33);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: lp.isEnglish ? Alignment.topRight : Alignment.topLeft,
              child: TextButton(
                onPressed: skip,
                child: Text(lp.getText('skip')),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) => setState(() => currentPage = index),
                children: [
                  buildPage(
                    lp.getText('ob_title_1'), // "Tap & Hold to Speak"
                    lp.getText('ob_sub_1'),   // "Press the mic and speak clearly"
                    lp,
                  ),
                  buildPage(
                    lp.getText('ob_title_2'), // "Listen to Confirmations"
                    lp.getText('ob_sub_2'),   // "App will read back selections"
                    lp,
                  ),
                  buildPage(
                    lp.getText('ob_title_3'), // "Say Commands Anytime"
                    lp.getText('ob_sub_3'),   // "Try: Order pizza..."
                    lp,
                  ),
                ],
              ),
            ),
            _buildDots(),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: nextPage,
                  child: Text(
                    currentPage == 2 ? lp.getText('start_btn') : lp.getText('next_btn'),
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mic, size: 16, color: Colors.black45),
                const SizedBox(width: 6),
                Text(
                  lp.getText('voice_instruction_hint'), // 'Say "Next" or "Skip"'
                  style: const TextStyle(color: Colors.black45),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentPage == index ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: currentPage == index ? const Color(0xFFEB1B33) : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }
}

// Helper class for the pulse effect when listening
class _PulseAnimation extends StatefulWidget {
  const _PulseAnimation();
  @override
  State<_PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<_PulseAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 140 + (20 * _pulseController.value),
          height: 140 + (20 * _pulseController.value),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFEB1B33).withOpacity(0.2),
          ),
        );
      },
    );
  }
}