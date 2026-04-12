import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController phoneController = TextEditingController();
  bool isLoading = false;
  final FlutterTts tts = FlutterTts();
  bool staySignedIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      speakInstructions();
    });
  }

  Future speakInstructions() async {
    // Access provider safely with listen: false inside a function
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    
    // This line uses the 'isEnglish' getter we added to the provider
    await tts.setLanguage(lp.isEnglish ? "en-US" : "ar-SA");
    await tts.speak(lp.getText('signin_voice_instructions'));
  }

  void signIn() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);

    if (!_formKey.currentState!.validate()) {
      tts.speak(lp.getText('error_invalid_phone_tts'));
      return;
    }

    setState(() { isLoading = true; });

    String phone = phoneController.text.trim();

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
          tts.speak(lp.getText('error_verification_failed'));
        },
        codeSent: (String verificationId, int? resendToken) async {
          setState(() { isLoading = false; });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool("staySignedIn", staySignedIn);

          if (mounted) {
            Navigator.pushReplacementNamed(
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
    // This is where the 'lp' variable is defined for the UI
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
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  lp.getText('signin_subtitle'),
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
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
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    textAlign: lp.isEnglish ? TextAlign.left : TextAlign.right,
                    decoration: InputDecoration(
                      hintText: lp.isEnglish ? "+966XXXXXXXXX" : "XXXXXXXXX٩٦٦+",
                      prefixIcon: const Icon(Icons.phone),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return lp.getText('error_enter_phone');
                      }
                      if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(value.replaceAll(RegExp(r'\s|\(|\)|-'), ''))) {
                        return lp.getText('error_valid_phone_format');
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 25),
                CheckboxListTile(
                  title: Text(lp.getText('stay_signed_in')),
                  value: staySignedIn,
                  activeColor: Colors.red,
                  onChanged: (bool? value) {
                    setState(() { staySignedIn = value!; });
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            lp.getText('signin_button'),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
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