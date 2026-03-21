import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {

  final TextEditingController phoneController = TextEditingController();
  
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
    String phone = phoneController.text;
   

  if (phone.isEmpty) {
    tts.speak("Please enter your phone number");
    return;
  }
    // Get SharedPreferences instance
    final prefs = await SharedPreferences.getInstance();

    // Save checkbox value
    await prefs.setBool("staySignedIn", staySignedIn);
    // Navigate later to home page
    Navigator.pushReplacementNamed(context, '/verfiy');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8F8F8),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 25),
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
                child: TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: "+1 (555) 000-0000",
                    prefixIcon: Icon(Icons.phone),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(20),
                  ),
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
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
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
    );
  }}