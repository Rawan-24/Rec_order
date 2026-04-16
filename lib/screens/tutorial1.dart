import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
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
  final Color primaryRed = const Color(0xFFEB1B33);

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    // Automatically start the voice flow when the screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceAndListen();
    });
  }

  /// Speaks the current slide content then automatically opens the microphone
  void _announceAndListen() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop();

    String titleKey = 'ob_title_${currentPage + 1}';
    String subKey = 'ob_sub_${currentPage + 1}';
    String message = "${lp.getText(titleKey)}. ${lp.getText(subKey)}";

    // App speaks first
    await audio.speak(message, lp.currentLanguage);

    // Once finished speaking, mic opens automatically
    if (mounted) _startAlwaysListening(lp);
  }

  /// Initializes the mic and sets up a loop to keep it active
  void _startAlwaysListening(LanguageProvider lp) async {
    bool available = await _speech.initialize(
      onError: (val) => setState(() => isListening = false),
      onStatus: (status) {
        // This loop keeps the mic "Always Open"
        if (status == 'done' || status == 'notListening') {
          setState(() => isListening = false);
          if (mounted) _startAlwaysListening(lp);
        }
      },
    );

    if (available && mounted) {
      setState(() => isListening = true);
      _speech.listen(
        localeId: lp.isEnglish ? "en-US" : "ar-EG",
        onResult: (result) {
          String text = result.recognizedWords.toLowerCase();

          // Command: NEXT
          if (text.contains("next") || text.contains("التالي") || text.contains("ثاني")) {
            nextPage();
          }
          // Command: SKIP
          else if (text.contains("skip") || text.contains("تخطي") || text.contains("عدي") || text.contains("خلاص")) {
            skip();
          }
        },
      );
    }
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
    _speech.stop(); // Release mic hardware before navigating
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const SignInScreen()),
    );
  }

  @override
  void dispose() {
    _speech.stop();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button layout
            Align(
              alignment: lp.isRTL ? Alignment.topLeft : Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, left: 15, right: 15),
                child: TextButton(
                  onPressed: skip,
                  child: Text(
                    lp.getText('skip'),
                    style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) {
                  setState(() => currentPage = index);
                  _announceAndListen();
                },
                children: [
                  _buildPage(lp.getText('ob_title_1'), lp.getText('ob_sub_1')),
                  _buildPage(lp.getText('ob_title_2'), lp.getText('ob_sub_2')),
                  _buildPage(lp.getText('ob_title_3'), lp.getText('ob_sub_3')),
                ],
              ),
            ),

            _buildDots(),
            const SizedBox(height: 35),

            // Button Action
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryRed,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 4,
                    shadowColor: primaryRed.withOpacity(0.3),
                  ),
                  onPressed: nextPage,
                  child: Text(
                    currentPage == 2 ? lp.getText('start_btn') : lp.getText('next_btn'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
            _buildVoiceIndicator(lp),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(String title, String subtitle) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (isListening) const _PulseAnimation(),
            Container(
              width: 130, height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryRed,
                boxShadow: [BoxShadow(color: primaryRed.withOpacity(0.3), blurRadius: 25, offset: const Offset(0, 8))],
              ),
              child: const Icon(Icons.mic_rounded, color: Colors.white, size: 55),
            ),
          ],
        ),
        const SizedBox(height: 50),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 45),
          child: Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[700], fontSize: 16, height: 1.4)),
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
          margin: const EdgeInsets.symmetric(horizontal: 5),
          width: currentPage == index ? 28 : 10,
          height: 10,
          decoration: BoxDecoration(
            color: currentPage == index ? primaryRed : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  Widget _buildVoiceIndicator(LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isListening ? Icons.graphic_eq : Icons.mic_none, size: 18, color: primaryRed),
          const SizedBox(width: 10),
          Text(
            isListening
                ? (lp.isRTL ? "أنا أسمعك الآن..." : "Listening...")
                : (lp.isRTL ? "جاري التحميل..." : "Initializing..."),
            style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// --- Pulse Animation Class ---
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
      opacity: Tween<double>(begin: 0.6, end: 0.0).animate(_pulseController),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.6).animate(_pulseController),
        child: Container(
          width: 130, height: 130,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEB1B33)),
        ),
      ),
    );
  }
}