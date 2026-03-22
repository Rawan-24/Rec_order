import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

///  test number      +1 223-334-4455
/// test code            123456
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  // Create 6 controllers and 6 focus nodes for the 6 digits
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

    bool isLoading = false;

  void _verifyAndNavigate() async {
    String otp = _controllers.map((e) => e.text).join();
    
    if (otp.length == 6) {
      setState(() { isLoading = true; });

      // GET THE VERIFICATION ID PASSED FROM THE PREVIOUS SCREEN
      final verificationId = ModalRoute.of(context)!.settings.arguments as String?;

      if (verificationId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error: Verification ID missing. Please try signing in again."))
        );
        setState(() { isLoading = false; });
        return;
      }

      try {
        // Create a PhoneAuthCredential with the code
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: verificationId, 
          smsCode: otp
        );

        // Sign the user in
        await FirebaseAuth.instance.signInWithCredential(credential);
        
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      } on FirebaseAuthException catch (e) {
        setState(() { isLoading = false; });
        String errorMsg = e.code == 'invalid-verification-code'
            ? 'The code you entered is incorrect.'
            : e.message ?? 'Verification failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg)));
      } catch (e) {
        setState(() { isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("An error occurred. Please try again.")));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter all 6 digits."))
      );
    }
  
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: Column(
            children: [
              // Back Arrow
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                ),
              ),

              const SizedBox(height: 20),

              // Microphone Icon
              Container(
                height: 120,
                width: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFEB1B33).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.mic,
                  color: const Color(0xFFEB1B33),
                  size: 50,
                ),
              ),

              const SizedBox(height: 40),

              const Text(
                "Verify Phone Number",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              const Text(
                "Enter the 6-digit code sent to +1 (555) 000-0000",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),

              const SizedBox(height: 40),

              // 6 OTP Input Fields
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) => _buildOtpBox(index)),
              ),

              const SizedBox(height: 40),

              const Text(
                "Didn't receive the code?",
                style: TextStyle(color: Colors.grey),
              ),

              const SizedBox(height: 10),

              // Clickable Resend Code Button
              GestureDetector(
                onTap: () {
                  // Logic to resend code
                  print("Resending code...");
                },
                child: const Text(
                  "Resend Code",
                  style: TextStyle(
                    color: const Color(0xFFEB1B33),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              
              const Spacer(),
              
              // Verify Button
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
                    : const Text(
                        "Verify",
                        style: TextStyle(color: const Color(0xFFF4EDE4), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      height: 65,
      width: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: _controllers[index].text.isNotEmpty ? const Color(0xFFEB1B33) : Colors.transparent,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        decoration: const InputDecoration(
          counterText: "",
          border: InputBorder.none,
        ),
        onChanged: (value) {
          if (value.isNotEmpty) {
            // Move to next box
            if (index < 5) {
              FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
            } else {
              // Last box filled, close keyboard or verify
              _focusNodes[index].unfocus();
              _verifyAndNavigate();
            }
          } else if (value.isEmpty && index > 0) {
            // Move back on delete
            FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
          }
          setState(() {}); // Update border color
        },
      ),
    );
  }
}