import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';

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
  final Color primaryRed = const Color(0xFFEB1B33);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceSignUp();
    });
  }

  void _announceSignUp() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop();

    String msg = lp.isRTL
        ? "إنشاء حساب جديد. من فضلك أدخل اسمك ورقم هاتفك للبدء."
        : "Create a new account. Please enter your name and phone number to get started.";
    audio.speak(msg, lp.currentLanguage);
  }

  void _signUp() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) {
      audio.speak(lp.isRTL ? "يرجى إكمال البيانات" : "Please complete your info", lp.currentLanguage);
      return;
    }

    setState(() { isLoading = true; });

    String phone = _phoneController.text.trim();
    // Normalizing for Egyptian region (+20)
    if (!phone.startsWith('+')) {
      phone = phone.startsWith('0') ? "+2$phone" : "+20$phone";
    }

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
          await _finalizeUserAccount(userCredential.user, phone, lp);
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() { isLoading = false; });
          audio.speak(lp.isRTL ? "خطأ في التحقق" : "Verification error", lp.currentLanguage);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? "Error")));
        },
        codeSent: (String verificationId, int? resendToken) async {
          setState(() { isLoading = false; });
          if (mounted) {
            Navigator.pushNamed(context, '/verfiy', arguments: {
              'verificationId': verificationId,
              'username': _usernameController.text.trim(),
              'phone': phone,
              'isSigningIn': false,
            });
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      setState(() { isLoading = false; });
    }
  }

  // Helper to ensure database and local storage are synced
  Future<void> _finalizeUserAccount(User? user, String phone, LanguageProvider lp) async {
    if (user == null) return;
    String name = _usernameController.text.trim();

    await DatabaseService().createUserProfile(
        user.uid,
        name,
        phone,
        language: lp.currentLanguage
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name);
    await prefs.setBool('staySignedIn', true);

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
                children: [
                  _buildBrandingIcon(),
                  const SizedBox(height: 30),
                  Text(lp.getText('welcome_title'),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text(lp.getText('signup_subtitle'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: Colors.grey[600])),
                  const SizedBox(height: 40),

                  _buildTextField(
                    controller: _usernameController,
                    label: lp.getText('full_name_label'),
                    hint: lp.getText('full_name_hint'),
                    icon: Icons.person_rounded,
                    lp: lp,
                  ),

                  const SizedBox(height: 20),

                  _buildTextField(
                    controller: _phoneController,
                    label: lp.getText('phone_number_label'),
                    hint: "01XXXXXXXX",
                    icon: Icons.phone_android_rounded,
                    isPhone: true,
                    lp: lp,
                  ),

                  const SizedBox(height: 40),

                  _buildSignUpButton(lp),

                  const SizedBox(height: 25),
                  _buildSignInLink(lp),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrandingIcon() {
    return Container(
      height: 100, width: 100,
      decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: primaryRed.withOpacity(0.1), blurRadius: 20)]
      ),
      child: Icon(Icons.person_add_rounded, color: primaryRed, size: 40),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required LanguageProvider lp,
    bool isPhone = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
            textAlign: lp.isRTL ? TextAlign.right : TextAlign.left,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: primaryRed, size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
            ),
            validator: (val) => val!.isEmpty ? lp.getText('error_enter_data') : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpButton(LanguageProvider lp) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isLoading ? null : _signUp,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: primaryRed.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(lp.getText('signup_button'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSignInLink(LanguageProvider lp) {
    return GestureDetector(
      onTap: () => Navigator.pushReplacementNamed(context, '/signin'),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black54, fontSize: 14),
          children: [
            TextSpan(text: "${lp.getText('already_have_account')} "),
            TextSpan(text: lp.getText('signin_link'), style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}