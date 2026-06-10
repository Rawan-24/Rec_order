import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/services/ai_service.dart';
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

  bool _shouldListen = true;
  bool _isProcessing = false;
  bool isListening = false;

  final Color primaryRed = const Color(0xFFEB1B33);

  // ─────────────────────────────────────────
  // Flow states
  //   "intro"   → screen just opened, ask user if they want tutorial
  //   "playing" → a tutorial slide is being announced, waiting for input
  // ─────────────────────────────────────────
  String _flowState = "intro";

  @override
  void initState() {
    super.initState();

    // Always reset to page 0 so tutorial always starts from the beginning
    currentPage = 0;


  }

  // ─────────────────────────────────────────
  // STEP 1 — Intro: "say continue or skip"
  // ─────────────────────────────────────────
  Future<void> _runIntro() async {
    if (!mounted) return;
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop();
    _flowState = "intro";

    final msg = lp.isEnglish
        ? "This is the tutorial screen. "
        "Say continue to start the tutorial, or say skip to go to sign in."
        : "هذه شاشة الشرح. "
        "قل اكمل لبدء الشرح، أو قل تخطى للذهاب إلى تسجيل الدخول.";

    await audio.speak(msg, lp.currentLanguage);

    if (mounted) {
      _shouldListen = true;
      _startListening();
    }
  }

  // ─────────────────────────────────────────
  // STEP 2 — Announce current tutorial page, then listen
  // ─────────────────────────────────────────
  Future<void> _announceTutorialPage() async {
    if (!mounted) return;
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop();
    _flowState = "playing";

    // Jump the PageView to currentPage (always starts at 0)
    _controller.jumpToPage(currentPage);

    final titleKey = 'ob_title_${currentPage + 1}';
    final subKey = 'ob_sub_${currentPage + 1}';
    final title = lp.getText(titleKey);
    final sub = lp.getText(subKey);

    final prompt = lp.isEnglish
        ? "$title. $sub. Say continue for the next tip, or say skip to finish."
        : "$title. $sub. قل اكمل للتالي، أو قل تخطى للانتهاء.";

    await audio.speak(prompt, lp.currentLanguage);

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

    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    if (audio.speech.isListening) {
      debugPrint("Mic already open — skipping duplicate start");
      return;
    }

    await audio.toggleListening(
      lp.isEnglish ? "en" : "ar",
      // ── onResult ──────────────────────────────────────────────
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;

        setState(() => isListening = false);
        print("USER SAID: $text");

        final response = await AIService.sendMessage(text);
        final command = (response['command'] ?? "unknown").toString();

        print("AI COMMAND: $command");

        if (command == "next") {
          await _handleContinue();
        } else if (command == "skip") {
          await _handleSkip();
        } else {
          // Unrecognised — re-prompt
          final audio2 =
          Provider.of<AppAudioProvider>(context, listen: false);
          final reprompt = lp.isEnglish
              ? "Say continue or skip."
              : "قل اكمل أو تخطى.";
          await audio2.speak(reprompt, lp.currentLanguage);
        }

        _isProcessing = false;


      },
      // ── onError: retry on silence / no-match ──────────────────
      onError: (errorMsg) {
        // AudioProvider handles error_no_match automatically.
        // Only restart here for genuine errors.
        debugPrint("STT real error on screen: $errorMsg");
      },
    );

    setState(() => isListening = true);
  }

  // ─────────────────────────────────────────
  // NAVIGATION HANDLERS
  // ─────────────────────────────────────────

  /// "Continue" from intro → start tutorial at page 0
  /// "Continue" from a tutorial page → advance to next, or skip if last
  Future<void> _handleContinue() async {
    if (_flowState == "intro") {
      // User chose to hear the tutorial — jump to page 0
      currentPage = 0;
      setState(() {});
      await _announceTutorialPage();
    } else {
      // Playing a tutorial page
      if (currentPage < 2) {
        currentPage++;
        setState(() {});
        await _announceTutorialPage();
      } else {
        // Last page done — go to sign in
        await _handleSkip();
      }
    }
  }

  /// "Skip" at any point → stop and go to SignIn
  Future<void> _handleSkip() async {
    _shouldListen = false;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
      );
    }
  }

  @override
  void dispose() {
    _shouldListen = false;
    _controller.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment:
              lp.isRTL ? Alignment.topLeft : Alignment.topRight,
              child: Padding(
                padding:
                const EdgeInsets.only(top: 10, left: 15, right: 15),
                child: TextButton(
                  onPressed: _handleSkip,
                  child: Text(
                    lp.getText('skip'),
                    style: TextStyle(
                        color: primaryRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _controller,
                // Disable manual swipe — navigation is voice-only
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPage(
                      lp.getText('ob_title_1'), lp.getText('ob_sub_1')),
                  _buildPage(
                      lp.getText('ob_title_2'), lp.getText('ob_sub_2')),
                  _buildPage(
                      lp.getText('ob_title_3'), lp.getText('ob_sub_3')),
                ],
              ),
            ),

            _buildDots(),
            const SizedBox(height: 35),
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
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: primaryRed),
              child: const Icon(Icons.mic_rounded,
                  color: Colors.white, size: 55),
            ),
          ],
        ),
        const SizedBox(height: 50),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 45),
          child: Text(subtitle,
              textAlign: TextAlign.center,
              style:
              TextStyle(color: Colors.grey[700], fontSize: 16)),
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
            color: currentPage == index
                ? primaryRed
                : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      }),
    );
  }

  Widget _buildVoiceIndicator(LanguageProvider lp) {
    // Show contextual hint based on flow state
    String hint;
    if (!isListening) {
      hint = lp.isRTL ? "جاري التحميل..." : "Initializing...";
    } else if (_flowState == "intro") {
      hint = lp.isRTL ? "قل اكمل أو تخطى" : 'Say "continue" or "skip"';
    } else {
      hint = lp.isRTL ? "أنا أسمعك الآن..." : "Listening...";
    }

    return Container(
      padding:
      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              isListening ? Icons.graphic_eq : Icons.mic_none,
              size: 18,
              color: primaryRed),
          const SizedBox(width: 10),
          Text(hint),
        ],
      ),
    );
  }
}

// ───────── Pulse Animation ─────────
class _PulseAnimation extends StatefulWidget {
  const _PulseAnimation();

  @override
  State<_PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<_PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController =
    AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity:
      Tween<double>(begin: 0.6, end: 0.0).animate(_pulseController),
      child: ScaleTransition(
        scale:
        Tween<double>(begin: 1.0, end: 1.6).animate(_pulseController),
        child: Container(
          width: 130,
          height: 130,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Color(0xFFEB1B33)),
        ),
      ),
    );
  }
}