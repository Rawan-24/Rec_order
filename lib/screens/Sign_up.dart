import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart'; // Standardized Provider

class SignUpPage extends StatefulWidget {
  static const String routeName = "SignUpPage";
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceSignUp();
    });
  }

  // FIXED: Using AppAudioProvider for synchronized speech
  void _announceSignUp() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop(); // Clear any previous audio from SignIn/Splash

    if (lp.isRTL) {
      await audio.speak("إنشاء حساب جديد.", "ar-EG");
      await Future.delayed(const Duration(milliseconds: 300));
      await audio.speak("من فضلك أدخل اسمك ورقم هاتفك للبدء.", "ar-EG");
    } else {
      await audio.speak("Create a new account. Please enter your name and phone number to get started.", "en-US");
    }
  }

  void _signUp() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) {
      await audio.speak(lp.isRTL ? "يرجى التأكد من البيانات" : "Please check your information", lp.currentLanguage);
      return;
    }

    setState(() { isLoading = true; });

    String phone = _phoneController.text.trim();
    // Auto-prefix for Egyptian numbers to make the demo smoother
    if (!phone.startsWith('+')) {
      phone = "+20$phone";
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          String? uid = userCredential.user?.uid;

          if (uid != null) {
            await DatabaseService().createUserProfile(
                uid,
                _usernameController.text.trim(),
                phone,
                language: lp.currentLanguage
            );

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('username', _usernameController.text.trim());
            await prefs.setString('phone', phone);
            await prefs.setBool('staySignedIn', true);

            if (mounted) Navigator.pushReplacementNamed(context, '/home');
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() { isLoading = false; });
          String errorMsg = e.message ?? lp.getText('error_verification_failed');
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
          audio.speak(lp.isRTL ? "حدث خطأ في التحقق" : "Verification failed", lp.currentLanguage);
        },
        codeSent: (String verificationId, int? resendToken) async {
          setState(() { isLoading = false; });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', _usernameController.text.trim());
          await prefs.setString('phone', phone);

          if (mounted) {
            Navigator.pushNamed( // Allow back navigation to fix typos
              context,
              '/verfiy',
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
      backgroundColor: const Color(0xFFF4EDE4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),

                // Mic Icon Branding
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
                  lp.getText('signup_subtitle'),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // Name Field
                _buildLabel(lp.getText('full_name_label'), lp),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _usernameController,
                  hint: lp.getText('full_name_hint'),
                  icon: Icons.person_outline,
                  lp: lp,
                  validator: (value) {
                    if (value == null || value.isEmpty) return lp.getText('error_enter_username');
                    if (value.length < 3) return lp.getText('error_name_short');
                    return null;
                  },
                ),

                const SizedBox(height: 25),

                // Phone Field
                _buildLabel(lp.getText('phone_number_label'), lp),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _phoneController,
                  hint: lp.isRTL ? "٠١XXXXXXXX" : "01XXXXXXXX",
                  icon: Icons.phone_iphone,
                  lp: lp,
                  isPhone: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) return lp.getText('error_enter_phone');
                    return null;
                  },
                ),

                const SizedBox(height: 40),

                // Sign Up button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                      lp.getText('signup_button'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(lp.getText('already_have_account')),
                    const SizedBox(width: 5),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, '/signin'),
                      child: Text(
                        lp.getText('signin_link'),
                        style: const TextStyle(color: primaryRed, fontWeight: FontWeight.bold),
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

  Widget _buildLabel(String text, LanguageProvider lp) {
    return Align(
      alignment: lp.isRTL ? Alignment.centerRight : Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required LanguageProvider lp,
    required String? Function(String?) validator,
    bool isPhone = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: TextFormField(
        controller: controller,
        textAlign: lp.isRTL ? TextAlign.right : TextAlign.left,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
        validator: validator,
      ),
    );
  }
}