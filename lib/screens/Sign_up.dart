import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final FlutterTts tts = FlutterTts();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      speakInstructions();
    });
  }

  Future speakInstructions() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    await tts.setLanguage(lp.isEnglish ? "en-US" : "ar-SA");
    await tts.speak(lp.getText('signup_voice_instructions'));
  }

  void _signUp() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) {
      tts.speak(lp.getText('error_invalid_signup_tts'));
      return;
    }

    setState(() { isLoading = true; });

    String phone = _phoneController.text.trim();

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
                phone
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
          tts.speak(lp.getText('error_verification_failed'));
        },
        codeSent: (String verificationId, int? resendToken) async {
          setState(() { isLoading = false; });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', _usernameController.text.trim());
          await prefs.setString('phone', phone);
          
          if (mounted) {
            Navigator.pushReplacementNamed(
              context, 
              '/verfiy', 
              arguments: {
                'verificationId': verificationId,
                'username': _usernameController.text.trim(),
                'phone': phone,
                'isSigningIn': false, // Explicitly tell verify screen this is sign up
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
                
                // Mic Icon to match SignIn styling
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
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                Text(
                  lp.getText('signup_subtitle'),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),

                const SizedBox(height: 40),

                /// Full Name Label
                Align(
                  alignment: lp.isEnglish ? Alignment.centerLeft : Alignment.centerRight,
                  child: Text(
                    lp.getText('full_name_label'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                    textAlign: lp.isEnglish ? TextAlign.left : TextAlign.right,
                    decoration: InputDecoration(
                      hintText: lp.getText('full_name_hint'),
                      prefixIcon: const Icon(Icons.person),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return lp.getText('error_enter_username');
                      if (value.length < 3) return lp.getText('error_name_short');
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 25),

                /// Phone Number Label
                Align(
                  alignment: lp.isEnglish ? Alignment.centerLeft : Alignment.centerRight,
                  child: Text(
                    lp.getText('phone_number_label'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                    textAlign: lp.isEnglish ? TextAlign.left : TextAlign.right,
                    decoration: InputDecoration(
                      hintText: lp.isEnglish ? "+966XXXXXXXXX" : "XXXXXXXXX٩٦٦+",
                      prefixIcon: const Icon(Icons.phone),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return lp.getText('error_enter_phone');
                      if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(value.replaceAll(RegExp(r'\s|\(|\)|-'), ''))) {
                        return lp.getText('error_valid_phone_format');
                      }
                      return null;
                    },
                  ),
                ),

                const SizedBox(height: 40),

                /// Sign Up button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          lp.getText('signup_button'),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                  ),
                ),

                const SizedBox(height: 25),

                /// Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(lp.getText('already_have_account')),
                    GestureDetector(
                      onTap: () => Navigator.pushReplacementNamed(context, '/signin'),
                      child: Text(
                        lp.getText('signin_link'),
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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