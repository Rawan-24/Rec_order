import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';

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
  final Color primaryRed = const Color(0xFFEB1B33);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceSignIn();
    });
  }

  void _announceSignIn() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop();
    String msg = lp.isRTL
        ? "أهلاً بك في تطبيق رك اوردر .من فضلك أدخل رقم هاتفك لتسجيل الدخول."
        : "Welcome to Rec Order. Please enter your phone number to sign in.";
    audio.speak(msg, lp.currentLanguage);
  }

  void signIn() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) {
      audio.speak(lp.isRTL ? "من فضلك أدخل رقم صحيح" : "Please enter a valid number", lp.currentLanguage);
      return;
    }

    setState(() { isLoading = true; });

    String phone = phoneController.text.trim();
    // Normalizing the phone number for the Egyptian context of your project
    if (!phone.startsWith('+')) {
      if (phone.startsWith('0')) {
        phone = "+2$phone";
      } else {
        phone = "+20$phone";
      }
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          await _handlePostSignIn(userCredential.user);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() { isLoading = false; });
          audio.speak(lp.isRTL ? "حدث خطأ في التحقق" : "Verification failed", lp.currentLanguage);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Error")));
        },
        codeSent: (String verificationId, int? resendToken) async {
          setState(() { isLoading = false; });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool("staySignedIn", staySignedIn);

          if (mounted) {
            Navigator.pushNamed(context, '/verfiy', arguments: {
              'verificationId': verificationId,
              'phone': phone,
              'isSigningIn': true,
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      setState(() { isLoading = false; });
    }
  }

  Future<void> _handlePostSignIn(User? user) async {
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool("staySignedIn", staySignedIn);

    // Fetch user name for the personalized greeting later
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists) {
      await prefs.setString('username', userDoc.data()?['name'] ?? "User");
    }

    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 30),
                  Text(lp.getText('welcome_title'),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black87)),
                  const SizedBox(height: 10),
                  Text(lp.getText('signin_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                  const SizedBox(height: 40),

                  _buildPhoneInputField(lp),
                  const SizedBox(height: 15),

                  Theme(
                    data: ThemeData(unselectedWidgetColor: primaryRed),
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(lp.getText('stay_signed_in'), style: const TextStyle(fontSize: 14)),
                      value: staySignedIn,
                      activeColor: primaryRed,
                      onChanged: (val) => setState(() => staySignedIn = val!),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ),

                  const SizedBox(height: 30),
                  _buildSignInButton(lp),
                  const SizedBox(height: 25),
                  _buildSignUpLink(lp),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      height: 120, width: 120,
      decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: primaryRed.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))]
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.mic_rounded, color: primaryRed, size: 50),
          Positioned(
            bottom: 25,
            child: Container(width: 30, height: 4, decoration: BoxDecoration(color: primaryRed.withOpacity(0.2), borderRadius: BorderRadius.circular(10))),
          )
        ],
      ),
    );
  }

  Widget _buildPhoneInputField(LanguageProvider lp) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: phoneController,
        keyboardType: TextInputType.phone,
        style: const TextStyle(letterSpacing: 1.5, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: lp.isRTL ? "رقم الهاتف" : "Phone Number",
          hintStyle: const TextStyle(letterSpacing: 0, fontWeight: FontWeight.normal, color: Colors.grey),
          prefixIcon: Icon(Icons.phone_android_rounded, color: primaryRed),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        ),
        validator: (val) => val!.isEmpty ? lp.getText('error_enter_phone') : null,
      ),
    );
  }

  Widget _buildSignInButton(LanguageProvider lp) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isLoading ? null : signIn,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          elevation: 5,
          shadowColor: primaryRed.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(lp.getText('signin_button'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSignUpLink(LanguageProvider lp) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, "/SignUp"),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black54, fontSize: 14),
          children: [
            TextSpan(text: "${lp.getText('no_account_text')} "),
            TextSpan(text: lp.getText('signup_link'), style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}