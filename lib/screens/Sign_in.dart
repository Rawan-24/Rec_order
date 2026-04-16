import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart'; // Standardized Provider

class SignInScreen extends StatefulWidget {
  static const String routeName = "SignInScreen";
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();
  bool isLoading = false;
  bool staySignedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceSignIn();
    });
  }

  // FIXED: Using AppAudioProvider for synchronized speech
  void _announceSignIn() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop(); // Clear any previous audio

    if (lp.isRTL) {
      await audio.speak("أهلاً بك في تطبيق سي أند سيرف.", "ar-EG");
      await Future.delayed(const Duration(milliseconds: 300));
      await audio.speak("من فضلك أدخل رقم هاتفك لتسجيل الدخول.", "ar-EG");
    } else {
      await audio.speak("Welcome to Say and Serve. Please enter your phone number to sign in.", "en-US");
    }
  }

  void signIn() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) {
      await audio.speak(lp.isRTL ? "رقم الهاتف غير صحيح" : "Invalid phone number", lp.currentLanguage);
      return;
    }

    setState(() { isLoading = true; });

    String phone = phoneController.text.trim();
    // Ensure international format for Firebase if the user forgets the '+'
    if (!phone.startsWith('+')) {
      phone = "+20$phone"; // Defaulting to Egypt for your graduation project context
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          String uid = userCredential.user!.uid;

          final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
          final prefs = await SharedPreferences.getInstance();

          if (userDoc.exists) {
            await prefs.setString('username', userDoc.data()?['username'] ?? "User");
          }

          await prefs.setBool("staySignedIn", staySignedIn);
          if (mounted) Navigator.pushReplacementNamed(context, '/home');
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() { isLoading = false; });
          String errorMsg = e.code == 'invalid-phone-number'
              ? lp.getText('error_invalid_phone_msg')
              : e.message ?? lp.getText('error_verification_failed');

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
          audio.speak(lp.isRTL ? "فشل التحقق من الرقم" : "Verification failed", lp.currentLanguage);
        },
        codeSent: (String verificationId, int? resendToken) async {
          setState(() { isLoading = false; });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool("staySignedIn", staySignedIn);

          if (mounted) {
            Navigator.pushNamed( // Using pushNamed to allow going back to fix phone number
              context,
              '/verfiy',
              arguments: {
                'verificationId': verificationId,
                'phone': phone,
                'isSigningIn': true,
              },
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          if (mounted) setState(() { isLoading = false; });
        },
      );
    } catch (e) {
      if (mounted) setState(() { isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    const primaryRed = Color(0xFFEB1B33);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4), // Standardized background
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Visual Mic Branding
                Container(
                  height: 110, width: 110,
                  decoration: BoxDecoration(
                    color: primaryRed.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: primaryRed, size: 45),
                ),
                const SizedBox(height: 25),
                Text(
                  lp.getText('welcome_title'),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  lp.getText('signin_subtitle'),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // Form Field Section
                Align(
                  alignment: lp.isRTL ? Alignment.centerRight : Alignment.centerLeft,
                  child: Text(
                    lp.getText('phone_number_label'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 8),
                _buildPhoneField(lp),

                const SizedBox(height: 25),
                CheckboxListTile(
                  title: Text(lp.getText('stay_signed_in')),
                  value: staySignedIn,
                  activeColor: primaryRed,
                  onChanged: (bool? value) {
                    setState(() { staySignedIn = value!; });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 20),

                // Sign In Button
                _buildSignInButton(primaryRed, lp),

                const SizedBox(height: 25),
                _buildSignUpLink(lp, primaryRed),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField(LanguageProvider lp) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: TextFormField(
        controller: phoneController,
        keyboardType: TextInputType.phone,
        textAlign: lp.isRTL ? TextAlign.right : TextAlign.left,
        decoration: InputDecoration(
          hintText: lp.isRTL ? "٠١XXXXXXXX" : "01XXXXXXXX",
          prefixIcon: const Icon(Icons.phone_iphone, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) return lp.getText('error_enter_phone');
          return null;
        },
      ),
    );
  }

  Widget _buildSignInButton(Color color, LanguageProvider lp) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isLoading ? null : signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
          lp.getText('signin_button'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSignUpLink(LanguageProvider lp, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(lp.getText('no_account_text')),
        const SizedBox(width: 5),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, "/SignUp"),
          child: Text(
            lp.getText('signup_link'),
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        )
      ],
    );
  }
}