import 'package:flutter/material.dart';

class PersonalInformationPage extends StatefulWidget {
  const PersonalInformationPage({super.key});

  @override
  State<PersonalInformationPage> createState() => _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
  // Controllers for input fields
  final TextEditingController _nameController =
  TextEditingController(text: "Sarah Kim");
  final TextEditingController _emailController =
  TextEditingController(text: "sarah.kim@example.com");
  final TextEditingController _phoneController =
  TextEditingController(text: "+1 (555) 123-4567");

  @override
  void dispose() {
    // ✅ Important to avoid memory leaks
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFD32F2F);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Personal Information",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              // Save logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Profile Updated Successfully!"),
                ),
              );
            },
            child: const Text(
              "SAVE",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 👇 Profile picture
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: primaryRed.withOpacity(0.1),
                    child: const Text(
                      "SK",
                      style: TextStyle(
                        fontSize: 32,
                        color: primaryRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: primaryRed,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // 👇 Input fields
            _buildEditField(
              "Full Name",
              _nameController,
              Icons.person_outline,
            ),
            const SizedBox(height: 20),

            _buildEditField(
              "Email Address",
              _emailController,
              Icons.email_outlined,
            ),
            const SizedBox(height: 20),

            _buildEditField(
              "Phone Number",
              _phoneController,
              Icons.phone_android_outlined,
            ),

            const SizedBox(height: 40),

            const Text(
              "Your data is encrypted and used only to improve your ordering experience.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 👇 Reusable input field
  Widget _buildEditField(
      String label,
      TextEditingController controller,
      IconData icon,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(
              icon,
              color: const Color(0xFFD32F2F),
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFD32F2F),
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}