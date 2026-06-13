import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/ai_service.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _controllers =
  List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  late stt.SpeechToText _speech;

  bool _shouldListen = true;
  bool _isProcessing = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audio = Provider.of<AppAudioProvider>(context, listen: false);
      final lp = Provider.of<LanguageProvider>(context, listen: false);

      await Future.delayed(const Duration(milliseconds: 1200));
      await audio.initSpeech();
      await _speakIntro(lp);
    });
  }

  // ─────────────────────────────────────────
  // INTRO
  // ─────────────────────────────────────────
  Future<void> _speakIntro(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    final args =
    ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String displayPhone = args?['phone'] ?? "";

    await audio.stop();

    final phoneHint = displayPhone.isNotEmpty
        ? (lp.isEnglish
        ? "A 6-digit code was sent to $displayPhone. "
        : "تم إرسال رمز مكون من 6 أرقام إلى $displayPhone. ")
        : "";

    await audio.speak(
      lp.isEnglish
          ? "${phoneHint}Say the 6 digits of your code, or type them in. "
          "Say re-enter to clear and try again."
          : "${phoneHint}قل الأرقام الستة لرمزك، أو اكتبها. "
          "قل أعد الإدخال لمسح الرمز والمحاولة مرة أخرى.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    if (mounted) {
      _shouldListen = true;
      _startListening(lp);
    }
  }

  // ─────────────────────────────────────────
  // ALWAYS-ON LISTEN LOOP
  // ─────────────────────────────────────────
  void _startListening(LanguageProvider lp) async {
    if (!_shouldListen || !mounted) return;

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

        print("USER SAID: $text");

        final response = await AIService.sendMessage(text, screen: "otp");
        final command = (response['command'] ?? response['text'] ?? "unknown").toString();

        print("AI COMMAND: $command");

        switch (command) {

        // ── OTP digits spoken ──────────────────────────────────
        // Rasa extracts the digits and returns them as "value"
          case "type_otp":
            final otpValue = (response['value'] ?? "").toString().trim();
            // Strip any non-digit characters the STT may have added
            final digits = otpValue.replaceAll(RegExp(r'[^0-9]'), '');

            if (digits.length == 6) {
              _fillOtpBoxes(digits);
              await audio.speak(
                lp.isEnglish
                    ? "Code entered: ${digits.split('').join(' ')}. "
                    "Say verify to confirm."
                    : "تم إدخال الرمز: ${digits.split('').join(' ')}. "
                    "قل تحقق للتأكيد.",
                lp.isEnglish ? "en-US" : "ar-SA",
              );
            } else if (digits.isNotEmpty) {
              // Partial digits — fill what we have and ask for the rest
              _fillOtpBoxes(digits.padRight(6, ' ').substring(0, 6));
              await audio.speak(
                lp.isEnglish
                    ? "I heard ${digits.length} digits. "
                    "Please say all 6 digits clearly."
                    : "سمعت ${digits.length} أرقام. "
                    "من فضلك قل الأرقام الستة بوضوح.",
                lp.isEnglish ? "en-US" : "ar-SA",
              );
            } else {
              await audio.speak(
                lp.isEnglish
                    ? "I didn't catch the code. Please say all 6 digits."
                    : "لم أسمع الرمز. من فضلك قل الأرقام الستة.",
                lp.isEnglish ? "en-US" : "ar-SA",
              );
            }
            break;

        // ── Verify / submit ────────────────────────────────────
          case "submit_otp":
            _verifyAndNavigate();
            break;

        // ── Clear OTP and re-enter ─────────────────────────────
          case "reenter_otp":
            _clearOtpBoxes();
            await audio.speak(
              lp.isEnglish
                  ? "Code cleared. Please say your 6-digit code."
                  : "تم مسح الرمز. من فضلك قل رمزك المكون من 6 أرقام.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            break;

        // ── Read back current OTP ──────────────────────────────
          case "read_otp":
            final current =
            _controllers.map((c) => c.text.isEmpty ? "_" : c.text).join(" ");
            await audio.speak(
              lp.isEnglish
                  ? "Current code: $current"
                  : "الرمز الحالي: $current",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            break;

          case "go_back":
            _shouldListen = false;
            await audio.stop();
            await Future.delayed(const Duration(milliseconds: 300));
            if (mounted) Navigator.pop(context);
            break;

          case "read_commands":
            await audio.speak(
              lp.isEnglish
                  ? "Say the 6-digit code, verify to submit, "
                  "re-enter to clear, read code to hear what you entered, "
                  "or go back."
                  : "قل الرمز المكون من 6 أرقام، تحقق للإرسال، "
                  "أعد الإدخال لمسحه، اقرأ الرمز لسماعه، أو ارجع.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            break;

        // ── Fallback ───────────────────────────────────────────
          default:
            await audio.speak(
              lp.isEnglish
                  ? "Say the 6-digit code, say verify to submit, "
                  "or say re-enter to clear."
                  : "قل الرمز المكون من 6 أرقام، قل تحقق للإرسال، "
                  "أو قل أعد الإدخال لمسحه.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
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
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────
  void _fillOtpBoxes(String digits) {
    setState(() {
      for (int i = 0; i < 6; i++) {
        _controllers[i].text =
        (i < digits.length && digits[i] != ' ') ? digits[i] : '';
      }
    });
  }

  void _clearOtpBoxes() {
    setState(() {
      for (var c in _controllers) {
        c.clear();
      }
    });
    // Move focus to first box
    FocusScope.of(context).requestFocus(_focusNodes[0]);
  }

  // ─────────────────────────────────────────
  // VERIFY
  // ─────────────────────────────────────────
  void _verifyAndNavigate() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    String otp = _controllers.map((e) => e.text).join();

    if (otp.length < 6 || otp.contains(' ')) {
      await audio.speak(
        lp.isEnglish
            ? "Please enter all 6 digits first."
            : "من فضلك أدخل الأرقام الستة أولاً.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
      return;
    }

    _shouldListen = false;
    await audio.stop();
    setState(() => isLoading = true);

    final args =
    ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    if (args == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lp.getText('session_expired'))));
      setState(() => isLoading = false);
      return;
    }

    final String verificationId = args['verificationId'] ?? '';
    final String? username = args['username'];
    final String phone = args['phone'] ?? '';
    final bool isSigningIn = args['isSigningIn'] ?? false;

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId, smsCode: otp);

      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithCredential(credential);
      String uid = userCredential.user!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!userDoc.exists) {
        if (isSigningIn) {
          await audio.speak(
            lp.getText('account_not_found_voice'),
            lp.isEnglish ? "en-US" : "ar-SA",
          );
          if (mounted) Navigator.pushReplacementNamed(context, '/SignUp');
          return;
        } else if (username != null) {
          await DatabaseService().createUserProfile(uid, username, phone);
        }
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
            'username', userDoc.data()?['username'] ?? "User");
      }

      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);
      _shouldListen = true;

      final msg = e.code == 'invalid-verification-code'
          ? lp.getText('wrong_code')
          : (e.message ?? 'Error');

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));

      await audio.speak(
        lp.isEnglish
            ? "Incorrect code. Please try again."
            : "الرمز غير صحيح. من فضلك حاول مرة أخرى.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );

      _clearOtpBoxes();
      _startListening(lp);
    } catch (e) {
      setState(() => isLoading = false);
      _shouldListen = true;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(lp.getText('error_occurred'))));
      _startListening(lp);
    }
  }

  @override
  void dispose() {
    _shouldListen = false;
    _speech.stop();
    for (var c in _controllers) c.dispose();
    for (var n in _focusNodes) n.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);
    final args =
    ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final String displayPhone = args?['phone'] ?? "your number";

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: lp.isEnglish
                      ? Alignment.topLeft
                      : Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                        lp.isEnglish
                            ? Icons.arrow_back
                            : Icons.arrow_forward,
                        color: Colors.black),
                  ),
                ),
                const SizedBox(height: 20),

                // Icon with listening pulse
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (audio.isListening)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFEB1B33).withOpacity(0.15),
                        ),
                      ),
                    Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEB1B33).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        audio.isListening
                            ? Icons.graphic_eq
                            : Icons.shield_outlined,
                        color: const Color(0xFFEB1B33),
                        size: 40,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
                Text(
                  lp.getText('verify_title'),
                  style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  "${lp.getText('verify_subtitle')} $displayPhone",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 10),

                // Voice hint
                Text(
                  lp.isEnglish
                      ? 'Say the 6 digits of your code aloud'
                      : 'قل الأرقام الستة لرمزك بصوت واضح',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic),
                ),

                const SizedBox(height: 30),

                // OTP boxes — always LTR
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (i) => _buildOtpBox(i)),
                  ),
                ),

                const SizedBox(height: 20),

                // Mic status indicator
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8)
                      ]),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        audio.isListening
                            ? Icons.graphic_eq
                            : Icons.mic_none,
                        size: 18,
                        color: const Color(0xFFEB1B33),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        audio.isListening
                            ? (lp.isEnglish
                            ? "Listening..."
                            : "أنا أسمعك الآن...")
                            : (lp.isEnglish
                            ? "Initializing..."
                            : "جاري التحميل..."),
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                Text(lp.getText('no_code'),
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final audio2 = Provider.of<AppAudioProvider>(context, listen: false);
                    final lp2 = Provider.of<LanguageProvider>(context, listen: false);
                    await audio2.speak(
                      lp2.isEnglish
                          ? "Resend is not available yet. Please go back and try signing in again."
                          : "إعادة الإرسال غير متاحة حالياً. من فضلك ارجع وحاول مرة أخرى.",
                      lp2.isEnglish ? "en-US" : "ar-SA",
                    );
                  },
                  child: Text(
                    lp.getText('resend_btn'),
                    style: const TextStyle(
                        color: Color(0xFFEB1B33),
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _verifyAndNavigate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEB1B33),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(
                        color: Colors.white)
                        : Text(
                      lp.getText('verify_btn'),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      height: 60,
      width: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _controllers[index].text.isNotEmpty
              ? const Color(0xFFEB1B33)
              : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
            counterText: "", border: InputBorder.none),
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < 5) {
              FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
            } else {
              _focusNodes[index].unfocus();
              _verifyAndNavigate();
            }
          } else if (value.isEmpty && index > 0) {
            FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
          }
          setState(() {});
        },
      ),
    );
  }
}