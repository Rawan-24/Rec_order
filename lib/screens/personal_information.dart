import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';

import '../services/ai_service.dart';

class PersonalInformationPage extends StatefulWidget {
  const PersonalInformationPage({super.key});

  @override
  State<PersonalInformationPage> createState() =>
      _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage> {
  final TextEditingController _nameController  = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading    = true;
  bool _shouldListen = true;
  bool _isProcessing = false;

  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audio = Provider.of<AppAudioProvider>(context, listen: false);
      final lp    = Provider.of<LanguageProvider>(context, listen: false);
      await Future.delayed(const Duration(milliseconds: 500));
      await audio.initSpeech();
      await _speakIntro(lp);
    });
  }

  @override
  void dispose() {
    _shouldListen = false;
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Fetch name + phone saved at sign-up ─────────────────────────────────
  Future<void> _fetchUserData() async {
    if (_user == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          // 'username' is what createUserProfile stores; fall back to 'name'
          _nameController.text  = (data['username'] ?? data['name'] ?? '').toString();
          _phoneController.text = (data['phone'] ?? '').toString();
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

  // ── Save updated name + phone back to Firestore ──────────────────────────
  Future<void> _updateProfile(LanguageProvider lp) async {
    if (_user == null) return;
    setState(() => _isLoading = true);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .update({
        'username': _nameController.text.trim(),
        'name':     _nameController.text.trim(), // keep both keys in sync
        'phone':    _phoneController.text.trim(),
      });

      await audio.speak(
        lp.getText('profile_update_success'),
        lp.currentLanguage,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(lp.getText('profile_update_success')),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("${lp.getText('profile_update_fail')}: $e"),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Voice intro ──────────────────────────────────────────────────────────
  Future<void> _speakIntro(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();
    await audio.speak(
      lp.isEnglish
          ? "Personal information. "
          "Say my name is, followed by your name to update it. "
          "Say my phone is, followed by your number. "
          "Say save to save, or say go back."
          : "المعلومات الشخصية. "
          "قل اسمي ثم اسمك لتحديثه. "
          "قل هاتفي ثم رقمك. "
          "قل احفظ لحفظ ملفك، أو قل ارجع.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
    if (mounted) {
      _shouldListen = true;
      _startListening(lp);
    }
  }

  // ── Local pre-parser: catches name/phone patterns without Rasa ──────────
  Map<String, dynamic>? _tryParseLocally(String text) {
    final lower = text.toLowerCase().trim();

    // Phone — English: "my phone is ...", "my phone number is ...", "my number is ..."
    final phoneRegex = RegExp(
      r'(?:my\s+)?(?:phone(?:\s+number)?|number)\s+(?:is\s+)?([+\d\s\-\(\)]+)',
      caseSensitive: false,
    );
    // Phone — Arabic: هاتفي / رقمي / رقم هاتفي
    final phoneRegexAr = RegExp(
      r'(?:هاتفي|رقمي|رقم هاتفي)\s+(?:هو\s+)?([+\d\s\-\(\)]+)',
    );
    final phoneMatch =
        phoneRegex.firstMatch(text) ?? phoneRegexAr.firstMatch(text);
    if (phoneMatch != null) {
      final raw = phoneMatch.group(1)!.trim().replaceAll(RegExp(r'\s+'), '');
      if (raw.isNotEmpty) return {'command': 'type_phone', 'value': raw};
    }

    // Name — English: "my name is ...", "I'm ...", "I am ..."
    final nameRegex = RegExp(
      r"(?:my\s+name\s+is|i(?:'?m|\s+am))\s+(.+)",
      caseSensitive: false,
    );
    // Name — Arabic: اسمي / اسمي هو
    final nameRegexAr = RegExp(r'اسمي\s+(?:هو\s+)?(.+)');
    final nameMatch =
        nameRegex.firstMatch(text) ?? nameRegexAr.firstMatch(text);
    if (nameMatch != null) {
      final name = nameMatch.group(1)!.trim();
      if (name.isNotEmpty) return {'command': 'type_name', 'value': name};
    }

    // Save
    if (lower == 'save' ||
        lower.contains('save profile') ||
        lower == 'احفظ' ||
        lower.contains('احفظ')) {
      return {'command': 'save_profile'};
    }

    // Go back
    if (lower.contains('go back') ||
        lower.contains('ارجع') ||
        lower.contains('رجوع')) {
      return {'command': 'go_back'};
    }

    return null; // fall through to Rasa
  }

  // ── Continuous listen loop ───────────────────────────────────────────────
  void _startListening(LanguageProvider lp) async {
    if (!_shouldListen || !mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (audio.speech.isListening) return;

    await audio.toggleListening(
      lp.isEnglish ? "en" : "ar",
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;

        debugPrint("USER SAID (PersonalInfo): $text");

        // Try local patterns first — bypass Rasa for common inputs
        final local = _tryParseLocally(text);
        final Map<String, dynamic> response;
        if (local != null) {
          debugPrint("LOCAL MATCH (PersonalInfo): $local");
          response = local;
        } else {
          response = await AIService.sendMessage(text, screen: "personal_info");
        }

        final command = (response['command'] ?? response['text'] ?? "unknown").toString();
        debugPrint("AI COMMAND (PersonalInfo): $command");

        await _handleCommand(command, response, lp);

        _isProcessing = false;

      },
      onError: (errorMsg) {
        // AudioProvider handles error_no_match automatically.
        // Only restart here for genuine errors.
        debugPrint("STT real error on screen: $errorMsg");
      },
    );
  }

  // ── Command handler ──────────────────────────────────────────────────────
  Future<void> _handleCommand(
      String command,
      Map<String, dynamic> response,
      LanguageProvider lp,
      ) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    switch (command) {

      case "type_name":
        final name = (response['value'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          setState(() => _nameController.text = name);
          await audio.speak(
            lp.isEnglish ? "Name set to $name." : "تم تعيين الاسم إلى $name.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        } else {
          await audio.speak(
            lp.isEnglish
                ? "Please say your name after saying my name is."
                : "قل اسمك بعد كلمة اسمي.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        }
        break;

      case "type_phone":
        final phone = (response['value'] ?? '').toString().trim();
        if (phone.isNotEmpty) {
          setState(() => _phoneController.text = phone);
          await audio.speak(
            lp.isEnglish ? "Phone number updated." : "تم تحديث رقم الهاتف.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        }
        break;

      case "read_name":
        final n = _nameController.text.trim();
        await audio.speak(
          lp.isEnglish
              ? (n.isNotEmpty ? "Your name is $n." : "Name field is empty.")
              : (n.isNotEmpty ? "اسمك هو $n." : "حقل الاسم فارغ."),
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

      case "read_phone":
        final p = _phoneController.text.trim();
        await audio.speak(
          lp.isEnglish
              ? (p.isNotEmpty ? "Your phone is $p." : "Phone field is empty.")
              : (p.isNotEmpty ? "رقمك هو $p." : "حقل الهاتف فارغ."),
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

      case "reenter_name":
        setState(() => _nameController.clear());
        await audio.speak(
          lp.isEnglish
              ? "Name cleared. Say my name is, followed by your name."
              : "تم مسح الاسم. قل اسمي ثم اسمك.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

      case "reenter_phone":
        setState(() => _phoneController.clear());
        await audio.speak(
          lp.isEnglish
              ? "Phone cleared. Say my phone is, followed by your number."
              : "تم مسح الرقم. قل هاتفي ثم رقمك.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

      case "save_profile":
        await _updateProfile(lp);
        break;

      case "read_commands":
        await audio.speak(
          lp.isEnglish
              ? "You can say: my name is, my phone is, read my name, read my phone, clear name, clear phone, save, or go back."
              : "يمكنك قول: اسمي، هاتفي، اقرأ اسمي، اقرأ رقمي، امسح الاسم، امسح الرقم، احفظ، أو ارجع.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

      case "go_back":
        _shouldListen = false;
        await audio.stop();
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) Navigator.pop(context);
        break;

      default:
        await audio.speak(
          lp.isEnglish
              ? "Say my name is, my phone is, save, or go back."
              : "قل اسمي، هاتفي، احفظ، أو ارجع.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "??";
    final parts = name.trim().split(" ");
    if (parts.length > 1) return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    return parts[0][0].toUpperCase();
  }

  // ── UI ───────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lp    = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);
    const primaryRed = Color(0xFFD32F2F);

    return Scaffold(
      appBar: AppBar(
        title: Text(lp.getText('personal_info_title'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: () => _updateProfile(lp),
              child: Text(
                lp.getText('save_button'),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
          child: CircularProgressIndicator(color: primaryRed))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Avatar — tap to restart mic
            Center(
              child: GestureDetector(
                onTap: () {
                  if (!audio.speech.isListening && !_isProcessing) {
                    _shouldListen = true;
                    _startListening(lp);
                  }
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundColor:
                      audio.isListening ? Colors.green : primaryRed,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Text(
                          _getInitials(_nameController.text),
                          style: const TextStyle(
                              fontSize: 32,
                              color: primaryRed,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                            color: primaryRed,
                            shape: BoxShape.circle),
                        child: Icon(
                          audio.isListening
                              ? Icons.graphic_eq
                              : Icons.mic,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Live transcription
            Text(
              audio.isListening
                  ? (audio.lastWords.isEmpty
                  ? (lp.isEnglish
                  ? "Listening..."
                  : "أنا أسمعك...")
                  : audio.lastWords)
                  : (lp.isEnglish
                  ? "Tap mic or speak to edit fields"
                  : "اضغط الميكروفون أو تكلم لتعديل الحقول"),
              style: TextStyle(
                  color: audio.isListening ? Colors.green : Colors.grey,
                  fontSize: 13),
            ),

            const SizedBox(height: 30),

            // Name field
            _buildEditField(
              lp.getText('full_name_label'),
              _nameController,
              Icons.person_outline,
              hint: lp.isEnglish ? "e.g. Ahmed Ali" : "مثال: أحمد علي",
            ),

            const SizedBox(height: 20),

            // Phone field
            _buildEditField(
              lp.getText('phone_label'),
              _phoneController,
              Icons.phone_android_outlined,
              hint: "+20XXXXXXXXXX",
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 40),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: () => _updateProfile(lp),
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  lp.getText('save_button'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryRed,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              lp.getText('data_protection_note'),
              textAlign: TextAlign.center,
              style:
              const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(
      String label,
      TextEditingController controller,
      IconData icon, {
        String hint = '',
        TextInputType keyboardType = TextInputType.text,
      }) {
    const primaryRed = Color(0xFFD32F2F);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: primaryRed),
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
              borderSide: const BorderSide(color: primaryRed, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}