import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart'; // Import Provider

class PersonalInformationPage extends StatefulWidget {
  const PersonalInformationPage({super.key});

  @override
  State<PersonalInformationPage> createState() => _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = true;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    // Announce the page goal
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcePage();
    });
  }

  void _announcePage() {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    String msg = lp.isRTL
        ? "معلوماتك الشخصية. يمكنك قول 'تغيير الاسم' أو 'حفظ الملف الشخصي'."
        : "Your personal information. You can say 'Change name' or 'Save profile'.";
    audio.speak(msg, lp.currentLanguage);
  }

  void _handleVoiceInput(AppAudioProvider audio, LanguageProvider lp) {
    audio.toggleListening(lp.currentLanguage, (words) {
      String command = words.toLowerCase();

      // Logic for updating specific fields via voice
      if (command.contains("name") || command.contains("اسم")) {
        String newName = words.split(RegExp(r'name|اسم')).last.trim();
        if (newName.isNotEmpty) {
          setState(() => _nameController.text = newName);
          audio.speak(lp.isRTL ? "تم تحديث الاسم" : "Name updated", lp.currentLanguage);
        }
      } else if (command.contains("phone") || command.contains("هاتف") || command.contains("موبايل")) {
        // Simple regex to extract numbers
        String newPhone = words.replaceAll(RegExp(r'[^0-9]'), '');
        if (newPhone.isNotEmpty) {
          setState(() => _phoneController.text = newPhone);
          audio.speak(lp.isRTL ? "تم تحديث الهاتف" : "Phone updated", lp.currentLanguage);
        }
      } else if (command.contains("save") || command.contains("حفظ")) {
        _updateProfile(lp);
      }
    });
  }

  Future<void> _fetchUserData() async {
    if (_user == null) return;
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _nameController.text = data['name'] ?? "";
          _emailController.text = data['email'] ?? _user.email ?? "";
          _phoneController.text = data['phone'] ?? "";
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile(LanguageProvider lp) async {
    setState(() => _isLoading = true);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    try {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).update({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
      });

      audio.speak(lp.getText('profile_update_success'), lp.currentLanguage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lp.getText('profile_update_success')), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${lp.getText('profile_update_fail')}: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "??";
    List<String> names = name.trim().split(" ");
    if (names.length > 1) {
      return "${names[0][0]}${names[1][0]}".toUpperCase();
    }
    return names[0][0].toUpperCase();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);
    const primaryRed = Color(0xFFD32F2F);

    return Scaffold(
      appBar: AppBar(
        title: Text(lp.getText('personal_info_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: () => _updateProfile(lp),
              child: Text(lp.getText('save_button'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryRed))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: () => _handleVoiceInput(audio, lp),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor: audio.isListening ? Colors.green : primaryRed,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Text(
                          _getInitials(_nameController.text),
                          style: const TextStyle(fontSize: 32, color: primaryRed, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: primaryRed, shape: BoxShape.circle),
                        child: Icon(
                            audio.isListening ? Icons.graphic_eq : Icons.mic,
                            color: Colors.white,
                            size: 20
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              audio.isListening ? "Listening..." : "Tap avatar to use voice",
              style: TextStyle(color: audio.isListening ? Colors.green : Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 30),
            _buildEditField(lp.getText('full_name_label'), _nameController, Icons.person_outline),
            const SizedBox(height: 20),
            _buildEditField(lp.getText('email_label'), _emailController, Icons.email_outlined),
            const SizedBox(height: 20),
            _buildEditField(lp.getText('phone_label'), _phoneController, Icons.phone_android_outlined),
            const SizedBox(height: 40),
            Text(
              lp.getText('data_protection_note'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: (val) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFFD32F2F)),
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
              borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
            ),
          ),
        ),
      ],
    );
  }
}