import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../services/ai_service.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

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

      // Register phone controller so AudioProvider can also write to it
      audio.setPhoneController(_phoneController);

      await audio.stop();
      await Future.delayed(const Duration(milliseconds: 500)); // ✅ add this
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

    await audio.stop();
    await audio.speak(
      lp.isEnglish
          ? "Sign up screen. Say your full name to begin, or say sign in if you already have an account."
          : "شاشة إنشاء الحساب. قل اسمك الكامل للبدء، أو قل تسجيل الدخول إذا كان لديك حساب.",
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

        final response = await AIService.sendMessage(text, screen: "sign_up");
        final command = (response['command'] ?? response['text'] ?? "unknown").toString();

        print("AI COMMAND: $command");

        switch (command) {

        // ── Full name entry ────────────────────────────────────
          case "type_name":
            final nameValue = (response['value'] ?? "").toString().trim();
            if (nameValue.isNotEmpty) {
              setState(() => _usernameController.text = nameValue);
              await audio.speak(
                lp.isEnglish
                    ? "Name entered: $nameValue. Now say your phone number."
                    : "تم إدخال الاسم: $nameValue. الآن قل رقم هاتفك.",
                lp.isEnglish ? "en-US" : "ar-SA",
              );
            }
            break;

        // ── Re-enter name ──────────────────────────────────────
          case "reenter_name":
            setState(() => _usernameController.clear());
            await audio.speak(
              lp.isEnglish
                  ? "Name cleared. Please say your full name."
                  : "تم مسح الاسم. من فضلك قل اسمك الكامل.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            break;

        // ── Phone number entry ─────────────────────────────────
          case "type_phone":
            final phoneValue = (response['value'] ?? "").toString().trim();
            if (phoneValue.isNotEmpty) {
              setState(() => _phoneController.text = phoneValue);
              await audio.speak(
                lp.isEnglish
                    ? "Phone number entered: $phoneValue. "
                    "Say sign up to continue, or say re-enter to change it."
                    : "تم إدخال الرقم: $phoneValue. "
                    "قل سجل للمتابعة، أو قل أعد الإدخال لتغييره.",
                lp.isEnglish ? "en-US" : "ar-SA",
              );
            }
            break;

        // ── Re-enter phone ─────────────────────────────────────
          case "reenter_phone":
            setState(() => _phoneController.clear());
            await audio.speak(
              lp.isEnglish
                  ? "Phone number cleared. Please say your phone number."
                  : "تم مسح الرقم. من فضلك قل رقم هاتفك.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            break;

        // ── Sign up ────────────────────────────────────────────
          case "sign_up":
            _signUp();
            break;

        // ── Go to sign in ──────────────────────────────────────
          case "open_signin":
            _shouldListen = false;
            await audio.stop();
            if (mounted) Navigator.pushReplacementNamed(context, '/SignIn');
            break;

        // ── Read back name ─────────────────────────────────────
          case "read_name":
            final currentName = _usernameController.text;
            await audio.speak(
              currentName.isEmpty
                  ? (lp.isEnglish
                  ? "No name entered yet."
                  : "لم يتم إدخال اسم بعد.")
                  : (lp.isEnglish
                  ? "Your name is $currentName"
                  : "اسمك هو $currentName"),
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            break;

        // ── Read back phone ────────────────────────────────────
          case "read_phone":
            final currentPhone = _phoneController.text;
            await audio.speak(
              currentPhone.isEmpty
                  ? (lp.isEnglish
                  ? "No phone number entered yet."
                  : "لم يتم إدخال رقم بعد.")
                  : (lp.isEnglish
                  ? "Your number is $currentPhone"
                  : "رقمك هو $currentPhone"),
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
                  ? "You can say: your full name, your phone number, "
                  "sign up, sign in, re-enter name, re-enter phone, "
                  "read my name, or read my number."
                  : "يمكنك قول: اسمك الكامل، رقم هاتفك، سجل، "
                  "تسجيل الدخول، أعد إدخال الاسم، أعد إدخال الرقم، "
                  "اقرأ اسمي، أو اقرأ رقمي.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            break;

        // ── Fallback ───────────────────────────────────────────
          default:
            await audio.speak(
              lp.isEnglish
                  ? "Say your full name, phone number, or say sign up. "
                  "You can also say re-enter to change a field."
                  : "قل اسمك الكامل أو رقم هاتفك أو قل سجل. "
                  "يمكنك أيضاً قول أعد الإدخال لتغيير أي حقل.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
        }

        _isProcessing = false;
        // ✅ Always restart mic after TTS finishes
        if (mounted && _shouldListen) {
          await Future.delayed(const Duration(milliseconds: 300));
          _startListening(lp);
        }
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
  // SIGN UP LOGIC
  // ─────────────────────────────────────────
  void _signUp() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // ── Sanitize phone before validation ──────────────────────────
    String phone = _phoneController.text.trim().replaceAll(RegExp(r'[\s\(\)\-]'), '');
    _phoneController.text = phone; // write sanitized value back

    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      await audio.speak(
        lp.isEnglish
            ? "Please make sure your name and phone number are filled in correctly."
            : "من فضلك تأكد من إدخال الاسم ورقم الهاتف بشكل صحيح.",
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
            final uid = userCredential.user?.uid;

            if (uid != null) {
              await DatabaseService().createUserProfile(
                uid,
                _usernameController.text.trim(),
                phone,
                language: lp.currentLanguage,
              );

              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('username', _usernameController.text.trim());
              await prefs.setString('phone', phone);
              await prefs.setBool('staySignedIn', true);

              _shouldListen = false;
              await audio.stop();

              if (mounted) Navigator.pushReplacementNamed(context, '/VerificationScreen');
            }
          } catch (e) {
            if (mounted) setState(() => isLoading = false);
            debugPrint("verificationCompleted error: $e");
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) setState(() => isLoading = false);
          final errorMsg = e.message ?? lp.getText('error_verification_failed');
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(errorMsg)));
          audio.speak(
            lp.getText('error_verification_failed'),
            lp.isEnglish ? "en-US" : "ar-SA",
          );
          debugPrint("verificationFailed: ${e.code} — ${e.message}");
        },
        codeSent: (String verificationId, int? resendToken) async {
          if (mounted) setState(() => isLoading = false);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', _usernameController.text.trim());
          await prefs.setString('phone', phone);

          _shouldListen = false;
          await audio.stop();

          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/VerificationScreen',
              arguments: {
                'verificationId': verificationId,
                'username': _usernameController.text.trim(),
                'phone': phone,
                'isSigningIn': false,
              },
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) setState(() => isLoading = false);
          debugPrint("codeAutoRetrievalTimeout — verificationId: $verificationId");
        },
      );
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
      debugPrint("_signUp outer catch: $e");
    }
  }
  @override
  void dispose() {
    _shouldListen = false;
    _speech.stop();
    _usernameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);

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

                // Mic icon with listening indicator
                Stack(
                  alignment: Alignment.center,
                  children: [
                    if (audio.isListening)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.15),
                        ),
                      ),
                    Container(
                      height: 110,
                      width: 110,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        audio.isListening ? Icons.mic : Icons.mic_none,
                        color: Colors.red,
                        size: 45,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),
                Text(
                  lp.getText('welcome_title'),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  lp.getText('signup_subtitle'),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // ── Full Name ──────────────────────────────────────
                Align(
                  alignment: lp.isEnglish
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Text(
                    lp.getText('full_name_label'),
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
                    controller: _usernameController,
                    textAlign:
                    lp.isEnglish ? TextAlign.left : TextAlign.right,
                    decoration: InputDecoration(
                      hintText: lp.getText('full_name_hint'),
                      prefixIcon: const Icon(Icons.person),
                      suffixIcon: _usernameController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Colors.grey),
                        onPressed: () =>
                            setState(() => _usernameController.clear()),
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return lp.getText('error_enter_username');
                      if (value.length < 3)
                        return lp.getText('error_name_short');
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: lp.isEnglish
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Text(
                    lp.isEnglish
                        ? 'Say "re-enter name" to clear and change'
                        : 'قل "أعد إدخال الاسم" لمسحه وتغييره',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Phone Number ───────────────────────────────────
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
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textAlign:
                    lp.isEnglish ? TextAlign.left : TextAlign.right,
                    decoration: InputDecoration(
                      hintText: lp.isEnglish
                          ? "+20XXXXXXXXXX"
                          : "XXXXXXXXXX02+",
                      prefixIcon: const Icon(Icons.phone),
                      suffixIcon: _phoneController.text.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Colors.grey),
                        onPressed: () =>
                            setState(() => _phoneController.clear()),
                      )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (value) {
                      if (value == null || value.isEmpty)
                        return lp.getText('error_enter_phone');
                      if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(
                          value.replaceAll(RegExp(r'\s|\(|\)|-'), '')))
                        return lp.getText('error_valid_phone_format');
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 6),
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

                const SizedBox(height: 35),

                // ── Mic status indicator ───────────────────────────
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
                        color: Colors.red,
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
                        style:
                        TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // ── Sign Up button ─────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(
                        color: Colors.white)
                        : Text(
                      lp.getText('signup_button'),
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(lp.getText('already_have_account')),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(
                          context, '/SignIn'),
                      child: Text(
                        lp.getText('signin_link'),
                        style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
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