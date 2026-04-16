import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart'; // Standardized Provider

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceVerification();
    });
  }

  // FIXED: Using AppAudioProvider for voice guidance
  void _announceVerification() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop();

    if (lp.isRTL) {
      await audio.speak("الرجاء إدخال رمز التحقق المكون من ستة أرقام.", "ar-EG");
    } else {
      await audio.speak("Please enter the six digit verification code sent to your phone.", "en-US");
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) controller.dispose();
    for (var node in _focusNodes) node.dispose();
    super.dispose();
  }

  void _verifyAndNavigate() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
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
            // Voice Error if trying to sign in to non-existent account
            await audio.speak(lp.getText('account_not_found_voice'), lp.currentLanguage);
            if (mounted) Navigator.pushReplacementNamed(context, '/SignUp');
            return;
          } else if (username != null) {
            await DatabaseService().createUserProfile(uid, username, phone, language: lp.currentLanguage);
          }
        } else {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('username', userDoc.data()?['username'] ?? "User");
        }

        if (mounted) Navigator.pushReplacementNamed(context, '/home');

      } on FirebaseAuthException catch (e) {
        setState(() { isLoading = false; });
        String errorMsg = e.code == 'invalid-verification-code' ? lp.getText('wrong_code') : lp.getText('error_occurred');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
        audio.speak(errorMsg, lp.currentLanguage);
      } catch (e) {
        setState(() { isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    const primaryRed = Color(0xFFEB1B33);
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final String displayPhone = args?['phone'] ?? "";

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
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                height: 100, width: 100,
                decoration: BoxDecoration(
                  color: primaryRed.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.security, color: primaryRed, size: 40),
              ),
              const SizedBox(height: 30),
              Text(
                lp.getText('verify_title'),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                "${lp.getText('verify_subtitle')}\n$displayPhone",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 40),

              // OTP Boxes
              Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (index) => _buildOtpBox(index, primaryRed)),
                ),
              ),

              const SizedBox(height: 40),
              Text(lp.getText('no_code'), style: const TextStyle(color: Colors.grey)),
              TextButton(
                onPressed: () { /* Add Resend Logic if needed */ },
                child: Text(
                  lp.getText('resend_btn'),
                  style: const TextStyle(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 60),

              _buildVerifyButton(primaryRed, lp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index, Color color) {
    return Container(
      height: 60, width: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
        ],
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
            else {
              _focusNodes[index].unfocus();
              _verifyAndNavigate();
            }
          } else if (value.isEmpty && index > 0) {
            FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
          }
        },
      ),
    );
  }

  Widget _buildVerifyButton(Color color, LanguageProvider lp) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isLoading ? null : _verifyAndNavigate,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(
          lp.getText('verify_btn'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}