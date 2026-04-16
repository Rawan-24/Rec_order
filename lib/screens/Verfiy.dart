import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';

class VerificationScreen extends StatefulWidget {
  static const String routeName = "VerificationScreen";
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool isLoading = false;
  final Color primaryRed = const Color(0xFFEB1B33);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceVerification();
    });
  }

  void _announceVerification() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop();
    String msg = lp.isRTL
        ? "من فضلك أدخل رمز التحقق المكون من ستة أرقام."
        : "Please enter the six-digit verification code.";
    audio.speak(msg, lp.currentLanguage);
  }

  @override
  void dispose() {
    for (var c in _controllers) c.dispose();
    for (var n in _focusNodes) n.dispose();
    super.dispose();
  }

  void _verifyAndNavigate() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    String otp = _controllers.map((e) => e.text).join();

    if (otp.length < 6) return;

    setState(() => isLoading = true);
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    if (args == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: args['verificationId'],
        smsCode: otp,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      await _handlePostVerification(userCredential.user, args, lp, audio);

    } on FirebaseAuthException catch (e) {
      setState(() => isLoading = false);
      String error = e.code == 'invalid-verification-code'
          ? (lp.isRTL ? "الرمز غير صحيح" : "Incorrect code")
          : (lp.isRTL ? "حدث خطأ" : "An error occurred");

      audio.speak(error, lp.currentLanguage);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _handlePostVerification(User? user, Map<String, dynamic> args, LanguageProvider lp, AppAudioProvider audio) async {
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final prefs = await SharedPreferences.getInstance();

    if (!userDoc.exists) {
      if (args['isSigningIn'] == true) {
        audio.speak(lp.isRTL ? "الحساب غير موجود، يرجى إنشاء حساب" : "Account not found, please sign up", lp.currentLanguage);
        if (mounted) Navigator.pushReplacementNamed(context, '/SignUp');
        return;
      } else {
        await DatabaseService().createUserProfile(user.uid, args['username'], args['phone'], language: lp.currentLanguage);
        await prefs.setString('username', args['username']);
      }
    } else {
      await prefs.setString('username', userDoc.data()?['username'] ?? "User");
    }

    await prefs.setBool('staySignedIn', true);
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back, color: Colors.black),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              _buildHeaderIcon(),
              const SizedBox(height: 30),
              Text(lp.getText('verify_title'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              Text("${lp.getText('verify_subtitle')}\n${args?['phone'] ?? ''}",
                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], height: 1.5)),
              const SizedBox(height: 50),

              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) => _buildOtpBox(i)),
                ),
              ),

              const SizedBox(height: 40),
              _buildResendSection(lp),
              const SizedBox(height: 40),
              _buildVerifyButton(lp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon() {
    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: primaryRed.withOpacity(0.1), blurRadius: 20)]),
      child: Icon(Icons.mark_email_read_rounded, color: primaryRed, size: 40),
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      width: 45, height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(counterText: "", border: InputBorder.none),
        onChanged: (val) {
          if (val.isNotEmpty && index < 5) {
            _focusNodes[index + 1].requestFocus();
          } else if (val.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (_controllers.every((c) => c.text.isNotEmpty)) _verifyAndNavigate();
        },
      ),
    );
  }

  Widget _buildResendSection(LanguageProvider lp) {
    return Column(
      children: [
        Text(lp.getText('no_code'), style: const TextStyle(color: Colors.grey)),
        TextButton(
          onPressed: () {}, // Resend logic here
          child: Text(lp.getText('resend_btn'), style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildVerifyButton(LanguageProvider lp) {
    return SizedBox(
      width: double.infinity, height: 60,
      child: ElevatedButton(
        onPressed: isLoading ? null : _verifyAndNavigate,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: isLoading ? const CircularProgressIndicator(color: Colors.white) : Text(lp.getText('verify_btn'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}