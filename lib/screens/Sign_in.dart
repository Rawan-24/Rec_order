import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    speakInstructions();
  }

  Future speakInstructions() async {
    await tts.setLanguage("en-US");
    await tts.speak(
        "Sign in page. Please enter your phone number . If you don't have an account, say sign up.");
  }

  void signIn() async{
    
   

    /////////new code for authentacation
  
    if (!_formKey.currentState!.validate()) {
      tts.speak("Please enter a valid phone number");
      return;
    }



    setState(() {
      isLoading = true;
    });

    String phone = phoneController.text.trim();

 if (phone.isEmpty) {
    tts.speak("Please enter your phone number");
    return;
  } 
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Android only: Auto sign-in if it detects the SMS automatically
          await FirebaseAuth.instance.signInWithCredential(credential);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool("staySignedIn", staySignedIn);
          if (mounted) Navigator.pushReplacementNamed(context, '/home');
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() { isLoading = false; });
          String errorMsg = e.code == 'invalid-phone-number' 
              ? 'The provided phone number is not valid.' 
              : e.message ?? 'Verification failed';
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
          tts.speak("Verification failed");
        },
        codeSent: (String verificationId, int? resendToken) async {
          setState(() { isLoading = false; });
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool("staySignedIn", staySignedIn);
          
          // Navigate to verify page and PASS the verificationId
          if (mounted) {
            Navigator.pushReplacementNamed(
              context, 
              '/verfiy', 
              arguments: verificationId, // IMPORTANT: Passing ID to next screen
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          setState(() { isLoading = false; });
        },
      );
    } catch (e) {
      setState(() { isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }


  @override
  Widget build(BuildContext context) {
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
            
                /// microphone circle
                Container(
                  height: 110,
                  width: 110,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: Colors.red,
                    size: 45,
                  ),
                ),
            
                const SizedBox(height: 25),
            
                const Text(
                  "Welcome to Rec-Order",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            
                const SizedBox(height: 8),
            
                const Text(
                  "Sign in to continue",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
            
                const SizedBox(height: 40),
            
                /// Phone label
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Phone Number",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            
                const SizedBox(height: 8),
            
                /// Phone field
               /// Phone field
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
                  child: TextFormField( // Change TextField to TextFormField
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: "+15550000000", // Firebase expects no spaces/brackets
                      prefixIcon: Icon(Icons.phone),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(20),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Enter phone number";
                      }
                      // Regex checks for a '+' followed by 10 to 14 digits
                      if (!RegExp(r'^\+[1-9]\d{1,14}$').hasMatch(value.replaceAll(RegExp(r'\s|\(|\)|-'), ''))) {
                        return "Enter a valid number with country code (e.g., +15551234567)";
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 25),
            
                /// stay signed in
                CheckboxListTile(
                  title: const Text("Stay signed in"),
                  value: staySignedIn,
                  activeColor: Colors.red,
                  onChanged: (bool? value) {
                    setState(() {
                      staySignedIn = value!;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
            
                const SizedBox(height: 20),
            
                /// sign in button
/// sign in button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : signIn, // Disable when loading
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Sign In",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                  ),
                ),
                const SizedBox(height: 25),
            
                /// sign up
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
            
                    const Text("Don't have an account? "),
            
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, "/SignUp");
                      },
                      child: const Text(
                        "Sign Up",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
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
  }}