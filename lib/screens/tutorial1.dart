import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart'; // Standardized Provider
import 'Sign_in.dart';

class VoiceOnboardingScreen extends StatefulWidget {
  static const String routeName = "VoiceOnboarding";
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
    // Start by announcing the first slide
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceCurrentPage();
    });
  }

  // FIXED: Announce slide content as user navigates
  void _announceCurrentPage() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop();

    String titleKey = 'ob_title_${currentPage + 1}';
    String subKey = 'ob_sub_${currentPage + 1}';

    String message = "${lp.getText(titleKey)}. ${lp.getText(subKey)}";
    audio.speak(message, lp.currentLanguage);
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
          if (text.contains("next") || text.contains("التالي") || text.contains("ثاني")) {
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

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    const primaryRed = Color(0xFFEB1B33);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4), // Consistent with app theme
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button - Positioned based on RTL/LTR
            Align(
              alignment: lp.isRTL ? Alignment.topLeft : Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextButton(
                  onPressed: skip,
                  child: Text(
                    lp.getText('skip'),
                    style: const TextStyle(color: primaryRed, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() => currentPage = index);
                  _announceCurrentPage(); // Speak new page info
                },
                children: [
                  _buildPage(
                    lp.getText('ob_title_1'),
                    lp.getText('ob_sub_1'),
                    lp,
                  ),
                  _buildPage(
                    lp.getText('ob_title_2'),
                    lp.getText('ob_sub_2'),
                    lp,
                  ),
                  _buildPage(
                    lp.getText('ob_title_3'),
                    lp.getText('ob_sub_3'),
                    lp,
                  ),
                ],
              ),
            ),

            _buildDots(),
            const SizedBox(height: 30),

            // Main Action Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: nextPage,
                  child: Text(
                    currentPage == 2 ? lp.getText('start_btn') : lp.getText('next_btn'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Voice Command Instruction
            _buildVoiceHint(lp),
            const SizedBox(height: 25),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(String title, String subtitle, LanguageProvider lp) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onLongPress: () => startListening(lp),
          onLongPressUp: stopListening,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isListening) const _PulseAnimation(),
              _buildMicIcon(),
            ],
          ),
        ),
        const SizedBox(height: 40),
        _buildTextContent(title, subtitle),
      ],
    );
  }

  Widget _buildMicIcon() {
    return Container(
      width: 140, height: 140,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEB1B33),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEB1B33).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(Icons.mic, color: Colors.white, size: 60),
    );
  }

  Widget _buildTextContent(String title, String subtitle) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[700], fontSize: 16, height: 1.5),
          ),
        ),
      ],
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: currentPage == index ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: currentPage == index ? const Color(0xFFEB1B33) : Colors.grey.shade400,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  Widget _buildVoiceHint(LanguageProvider lp) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.record_voice_over, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Text(
          lp.getText('voice_instruction_hint'),
          style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

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
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat();
  }
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 0.0).animate(_pulseController),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.5).animate(_pulseController),
        child: Container(
          width: 140, height: 140,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEB1B33)),
        ),
      ),
    );
  }
}