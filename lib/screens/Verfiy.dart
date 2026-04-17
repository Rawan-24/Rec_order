import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart'; // Ensure this import is correct

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final FlutterTts tts = FlutterTts();
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Language setup happens dynamically in _verifyAndNavigate now
  }

  @override
  void dispose() {
    for (var controller in _controllers) controller.dispose();
    for (var node in _focusNodes) node.dispose();
    super.dispose();
  }

  void _verifyAndNavigate() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    String otp = _controllers.map((e) => e.text).join();

    if (otp.length == 6) {
      setState(() { isLoading = true; });

      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;

      if (args == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lp.getText('session_expired'))));
        setState(() { isLoading = false; });
        return;
      }

      final String verificationId = args['verificationId'] ?? '';
      final String? username = args['username'];
      final String phone = args['phone'] ?? '';
      final bool isSigningIn = args['isSigningIn'] ?? false;

      try {
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: otp
        );

        UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        String uid = userCredential.user!.uid;

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

        if (!userDoc.exists) {
          if (isSigningIn) {
            // Bilingual Voice Error
            await tts.setLanguage(lp.isEnglish ? "en-US" : "ar-SA");
            tts.speak(lp.getText('account_not_found_voice'));

            if (mounted) Navigator.pushReplacementNamed(context, '/SignUp');
            return;
          } else if (username != null) {
            await DatabaseService().createUserProfile(uid, username, phone);
          }
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', userDoc.data()?['username'] ?? "User");
        }

        if (mounted) Navigator.pushReplacementNamed(context, '/home');

      } on FirebaseAuthException catch (e) {
        setState(() { isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.code == 'invalid-verification-code' ? lp.getText('wrong_code') : e.message ?? 'Error'))
        );
      } catch (e) {
        setState(() { isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lp.getText('error_occurred'))));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lp.getText('enter_6_digits'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final String displayPhone = args?['phone'] ?? "your number";

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      body: SafeArea(
        child: SingleChildScrollView( // Added scroll view to prevent overflow on small keyboards
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 25),
            child: Column(
              children: [
                Align(
                  alignment: lp.isEnglish ? Alignment.topLeft : Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(lp.isEnglish ? Icons.arrow_back : Icons.arrow_forward, color: Colors.black),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  height: 100, width: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEB1B33).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_outlined, color: Color(0xFFEB1B33), size: 40),
                ),
                const SizedBox(height: 30),
                Text(
                  lp.getText('verify_title'),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  "${lp.getText('verify_subtitle')} $displayPhone",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                Directionality(
                  textDirection: TextDirection.ltr, // Keep OTP boxes left-to-right
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) => _buildOtpBox(index)),
                  ),
                ),
                const SizedBox(height: 40),
                Text(lp.getText('no_code'), style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => print("Resending..."),
                  child: Text(
                    lp.getText('resend_btn'),
                    style: const TextStyle(color: Color(0xFFEB1B33), fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 100), // Replacement for Spacer in ScrollView
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _verifyAndNavigate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEB1B33),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                      lp.getText('verify_btn'),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
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
          color: _controllers[index].text.isNotEmpty ? const Color(0xFFEB1B33) : Colors.grey.shade300,
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
        decoration: const InputDecoration(counterText: "", border: InputBorder.none),
        onChanged: (value) {
          if (value.isNotEmpty) {
            if (index < 5) FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
            else { _focusNodes[index].unfocus(); _verifyAndNavigate(); }
          } else if (value.isEmpty && index > 0) {
            FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
          }
          setState(() {});
        },
      ),
    );
  }
}