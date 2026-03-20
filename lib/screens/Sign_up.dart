import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;

  void _signUp() async {
    if (_formKey.currentState!.validate()) {
      // Save user info in SharedPreferences (for demo purposes)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', _usernameController.text);
      await prefs.setString('phone', _phoneController.text);
      await prefs.setString('password', _passwordController.text);

      // Optionally, auto sign in
      await prefs.setBool('staySignedIn', true);

      // Navigate to home
      Navigator.pushReplacementNamed(context, '/home');
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

                const Text(
                  "Welcome to Rec-Order",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Create your account",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height: 40),

                /// Full Name
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Full Name",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                    decoration: const InputDecoration(
                      hintText: "Enter your name",
                      prefixIcon: Icon(Icons.person),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(20),
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? "Enter username" : null,
                  ),
                ),

                const SizedBox(height: 25),

                /// Phone Number
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Phone Number",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                    decoration: const InputDecoration(
                      hintText: "+1 (555) 000-0000",
                      prefixIcon: Icon(Icons.phone),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(20),
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? "Enter phone number" : null,
                  ),
                ),

                const SizedBox(height: 25),

                /// Password
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Password",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: "Enter password",
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(20),
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? "Enter password" : null,
                  ),
                ),

                const SizedBox(height: 30),

                /// Sign Up button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _signUp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      "Sign Up",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                /// Sign in link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [

                    const Text("Already have an account? "),

                    GestureDetector(
                      onTap: () {
                        Navigator.pushReplacementNamed(context, '/signin');
                      },
                      child: const Text(
                        "Sign In",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
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
  }}