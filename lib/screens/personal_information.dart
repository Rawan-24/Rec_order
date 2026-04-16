import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';

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
  final Color primaryRed = const Color(0xFFEB1B33);

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcePage();
    });
  }

  void _announcePage() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop();
    String msg = lp.isRTL
        ? "هنا يمكنك تعديل بياناتك. قل 'تغيير الاسم' أو 'حفظ'."
        : "Profile settings. Say 'Change name' or 'Save profile'.";
    audio.speak(msg, lp.currentLanguage);
  }

  void _handleVoiceInput(AppAudioProvider audio, LanguageProvider lp) {
    audio.toggleListening(lp.currentLanguage, (words) async {
      String command = words.toLowerCase();

      // Improved Name Detection
      if (command.contains("name") || command.contains("اسم")) {
        // Regex to remove the "command" words and keep the actual name
        String newName = words.replaceAll(RegExp(r'(change|update|name|تغيير|اسم|عدل)', caseSensitive: false), '').trim();
        if (newName.isNotEmpty) {
          setState(() => _nameController.text = newName);
          audio.speak(lp.isRTL ? "تم تغيير الاسم إلى $newName" : "Name changed to $newName", lp.currentLanguage);
        }
      }
      // Improved Phone Detection (removes spaces from spoken numbers)
      else if (command.contains("phone") || command.contains("هاتف") || command.contains("موبايل") || command.contains("رقم")) {
        String newPhone = words.replaceAll(RegExp(r'[^0-9]'), '');
        if (newPhone.isNotEmpty) {
          setState(() => _phoneController.text = newPhone);
          audio.speak(lp.isRTL ? "تم تحديث الرقم" : "Phone updated", lp.currentLanguage);
        }
      }
      // Save command
      else if (command.contains("save") || command.contains("حفظ") || command.contains("تحديث")) {
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
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile(LanguageProvider lp) async {
    if (_nameController.text.isEmpty) return;

    setState(() => _isLoading = true);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    try {
      await FirebaseFirestore.instance.collection('users').doc(_user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      audio.speak(lp.isRTL ? "تم حفظ البيانات بنجاح" : "Profile saved successfully", lp.currentLanguage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(lp.isRTL ? "تم التحديث" : "Profile Updated"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return "??";
    List<String> names = name.trim().split(" ");
    if (names.length > 1) {
      return "${names[0][0]}${names[1][0]}".toUpperCase();
    }
    return names[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(lp.isRTL ? "المعلومات الشخصية" : "Personal Info",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          if (!_isLoading)
            IconButton(
              onPressed: () => _updateProfile(lp),
              icon: Icon(Icons.check, color: primaryRed),
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryRed))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          children: [
            const SizedBox(height: 30),
            // Avatar with Voice Animation
            Center(
              child: GestureDetector(
                onTap: () => _handleVoiceInput(audio, lp),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: audio.isListening ? Colors.green : primaryRed.withOpacity(0.2),
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: primaryRed.withOpacity(0.1),
                        child: Text(
                          _getInitials(_nameController.text),
                          style: TextStyle(fontSize: 32, color: primaryRed, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 5,
                      child: CircleAvatar(
                        radius: 18,
                        backgroundColor: audio.isListening ? Colors.green : primaryRed,
                        child: Icon(audio.isListening ? Icons.graphic_eq : Icons.mic, color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              audio.isListening ? (lp.isRTL ? "أنا أسمعك..." : "I'm listening...") : (lp.isRTL ? "اضغط للمتحدث الصوتي" : "Tap for Voice Assistant"),
              style: TextStyle(color: audio.isListening ? Colors.green : Colors.grey, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 40),

            _buildEditField(lp.isRTL ? "الاسم بالكامل" : "Full Name", _nameController, Icons.person_outline),
            const SizedBox(height: 20),
            _buildEditField(lp.isRTL ? "البريد الإلكتروني" : "Email Address", _emailController, Icons.email_outlined, isEnabled: false),
            const SizedBox(height: 20),
            _buildEditField(lp.isRTL ? "رقم الهاتف" : "Phone Number", _phoneController, Icons.phone_android_outlined),

            const SizedBox(height: 50),
            _buildSecurityNote(lp),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityNote(LanguageProvider lp) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 20, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              lp.isRTL ? "بياناتك محمية ومخزنة بشكل آمن" : "Your data is encrypted and stored securely.",
              style: const TextStyle(color: Colors.blueGrey, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, IconData icon, {bool isEnabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 14)),
        ),
        TextField(
          controller: controller,
          enabled: isEnabled,
          onChanged: (val) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: isEnabled ? primaryRed : Colors.grey),
            filled: true,
            fillColor: isEnabled ? Colors.white : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.black.withOpacity(0.05))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: primaryRed, width: 1.5)),
          ),
        ),
      ],
    );
  }
}