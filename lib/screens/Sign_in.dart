import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../providers/AudioProvider.dart';
import '../services/ai_service.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _isProcessing = false;
  final FlutterTts tts = FlutterTts();

  late stt.SpeechToText _speech;

  bool _shouldListen = true;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();
  bool isLoading = false;
  bool staySignedIn = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audio = Provider.of<AppAudioProvider>(context, listen: false);
      final lp = Provider.of<LanguageProvider>(context, listen: false);

      audio.setPhoneController(phoneController);

      await Future.delayed(const Duration(milliseconds: 1500));
      await audio.initSpeech();
      _speakIntro(lp);
    });
  }

  void _startListening(LanguageProvider lp) async {
    if (!_shouldListen) return;

    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    if (audio.speech.isListening) {
      debugPrint("Mic already open — skipping duplicate start");
      return;
    }

    await audio.toggleListening(
      lp.isEnglish ? "en" : "ar",
      // ── onResult ──────────────────────────────────────────────
          (text) async {
        if (_isProcessing) return;
        _isProcessing = true;

        print("USER SAID: $text");

        final response = await AIService.sendMessage(text);
        final command = (response['command'] ?? "unknown").toString();

        print("AI COMMAND: $command");

        switch (command) {

        // ── Phone number entry ─────────────────────────────────
          case "type_phone":
            final phoneValue = (response['value'] ?? "").toString().trim();
            if (phoneValue.isNotEmpty) {
              setState(() {
                phoneController.text = phoneValue;
              });
              await audio.speak(
                lp.isEnglish
                    ? "Phone number entered: $phoneValue. "
                    "Say sign in to continue, or say re-enter to change it."
                    : "تم إدخال الرقم: $phoneValue. "
                    "قل تسجيل الدخول للمتابعة، أو قل أعد الإدخال لتغييره.",
                lp.isEnglish ? "en-US" : "ar-SA",
              );
            }
            break;

        // ── Re-enter / retype / change phone ──────────────────
        // Triggered when user says "re-enter", "retype", "change",
        // "wrong number", "clear", etc.
          case "reenter_phone":
            setState(() {
              phoneController.clear();
            });
            await audio.speak(
              lp.isEnglish
                  ? "Phone number cleared. Please say your phone number."
                  : "تم مسح الرقم. من فضلك قل رقم هاتفك.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            break;

        // ── Sign in ────────────────────────────────────────────
          case "sign_in":
            signIn();
            break;

        // ── Navigate to sign up ────────────────────────────────
          case "open_signup":
          case "sign_up": // ← add this line
            _shouldListen = false;
            _isProcessing = true;
            await audio.stop();
            if (mounted) Navigator.pushReplacementNamed(context, "/SignUp");
            break;
        // ── Stay-signed-in toggle ──────────────────────────────
          case "toggle_stay_signed_in_on":
            setState(() => staySignedIn = true);
            await audio.speak(
              lp.isEnglish
                  ? "Stay signed in enabled"
                  : "تم تفعيل البقاء مسجلاً",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            break;

          case "toggle_stay_signed_in_off":
            setState(() => staySignedIn = false);
            await audio.speak(
              lp.isEnglish
                  ? "Stay signed in disabled"
                  : "تم إيقاف البقاء مسجلاً",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            break;

        // ── Read back current phone ────────────────────────────
          case "read_phone":
            final currentPhone = phoneController.text;
            final readMsg = currentPhone.isEmpty
                ? (lp.isEnglish
                ? "No phone number entered yet."
                : "لم يتم إدخال رقم بعد.")
                : (lp.isEnglish
                ? "Your number is $currentPhone"
                : "رقمك هو $currentPhone");
            await audio.speak(readMsg, lp.isEnglish ? "en-US" : "ar-SA");
            break;

        // ── Fallback ───────────────────────────────────────────
          default:
            await audio.speak(
              lp.isEnglish
                  ? "Say sign in, sign up, or your phone number. "
                  "You can also say re-enter to change your number."
                  : "قل تسجيل الدخول أو إنشاء حساب أو أدخل رقم هاتفك. "
                  "يمكنك أيضاً قول أعد الإدخال لتغيير الرقم.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
        }

        _isProcessing = false;

        Future.delayed(const Duration(milliseconds: 600), () {
          if (_shouldListen && mounted) {
            _startListening(lp);
          }
        });
      },
      // ── onError: retry on silence / no-match ──────────────────
      onError: (errorMsg) {
        debugPrint("STT error in SignIn: $errorMsg — scheduling retry");
        if (!_shouldListen || !mounted || _isProcessing) return;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_shouldListen && mounted && !_isProcessing) {
            _startListening(lp);
          }
        });
      },
    );
  }

  Future<void> _speakIntro(LanguageProvider lp) async {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.speak(
      lp.isEnglish
          ? "Sign in screen. Say your phone number, or say sign up to create an account."
          : "شاشة تسجيل الدخول. قل رقم هاتفك، أو قل إنشاء حساب.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    if (mounted) {
      _startListening(lp);
    }
  }

  @override
  void dispose() {
    _shouldListen = false;
    _speech.stop();
    phoneController.dispose();
    super.dispose();
  }
  void signIn() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Sanitize phone before validation
    String phone = phoneController.text.trim()
        .replaceAll(RegExp(r'[\s\(\)\-]'), '');
    phoneController.text = phone;

    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      await audio.speak(
        lp.isEnglish
            ? "Please enter a valid phone number."
            : "من فضلك أدخل رقم هاتف صحيح.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            UserCredential userCredential =
            await FirebaseAuth.instance.signInWithCredential(credential);
            String uid = userCredential.user!.uid;

            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get();
            final prefs = await SharedPreferences.getInstance();

            if (userDoc.exists) {
              await prefs.setString(
                  'username', userDoc.data()?['username'] ?? "User");
            }
            await prefs.setBool("staySignedIn", staySignedIn);

            _shouldListen = false;
            await audio.stop();

            if (mounted) Navigator.pushReplacementNamed(context, '/home');
          } catch (e) {
            if (mounted) setState(() => isLoading = false);
            debugPrint("verificationCompleted error: $e");
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) setState(() => isLoading = false);
          String errorMsg = e.code == 'invalid-phone-number'
              ? lp.getText('error_invalid_phone_msg')
              : e.message ?? lp.getText('error_verification_failed');
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(errorMsg)));
          audio.speak(lp.getText('error_verification_failed'),
              lp.isEnglish ? "en-US" : "ar-SA");
          debugPrint("verificationFailed: ${e.code} — ${e.message}");
        },
        codeSent: (String verificationId, int? resendToken) async {
          if (mounted) setState(() => isLoading = false);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool("staySignedIn", staySignedIn);

          _shouldListen = false;
          await audio.stop();

          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/VerificationScreen',
              arguments: {
                'verificationId': verificationId,
                'phone': phone,
                'isSigningIn': true,
              },
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) setState(() => isLoading = false);
          debugPrint("codeAutoRetrievalTimeout: $verificationId");
        },
      );
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
      debugPrint("signIn outer catch: $e");
    }
  }
  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xffF8F8F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  height: 110,
                  width: 110,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.red, size: 45),
                ),
                const SizedBox(height: 25),
                Text(
                  lp.getText('welcome_title'),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  lp.getText('signin_subtitle'),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                Align(
                  alignment: lp.isEnglish
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Text(
                    lp.getText('phone_number_label'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    textAlign:
                    lp.isEnglish ? TextAlign.left : TextAlign.right,
                    decoration: InputDecoration(
                      hintText: lp.isEnglish
                          ? "+966XXXXXXXXX"
                          : "XXXXXXXXX٩٦٦+",
                      prefixIcon: const Icon(Icons.phone),
                      // Clear button shown when there's text
                      suffixIcon: phoneController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() => phoneController.clear());
                        },
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                    onChanged: (_) => setState(() {}), // refresh suffix icon
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return lp.getText('error_enter_phone');
                      }
                      if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(
                          value.replaceAll(RegExp(r'\s|\(|\)|-'), ''))) {
                        return lp.getText('error_valid_phone_format');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // ── Voice hint below the phone field ──
                Align(
                  alignment: lp.isEnglish
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Text(
                    lp.isEnglish
                        ? 'Say "re-enter" to clear and change your number'
                        : 'قل "أعد الإدخال" لمسح الرقم وتغييره',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic),
                  ),
                ),
                const SizedBox(height: 20),
                CheckboxListTile(
                  title: Text(lp.getText('stay_signed_in')),
                  value: staySignedIn,
                  activeColor: Colors.red,
                  onChanged: (bool? value) {
                    setState(() {
                      staySignedIn = value!;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : signIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(
                        color: Colors.white)
                        : Text(
                      lp.getText('signin_button'),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(lp.getText('no_account_text')),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, "/SignUp"),
                      child: Text(
                        lp.getText('signup_link'),
                        style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}