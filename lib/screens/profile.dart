import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/screens/personal_information.dart';

import '../services/ai_service.dart';
import 'Delivery_Address.dart';
import 'Home.dart';
import 'Language_Selection.dart';
import 'NotificationsPage.dart';
import 'PaymentMethodsPage.dart';
import 'Sign_in.dart';
import 'VoiceSettingsPage.dart';
import 'favorites.dart';
import 'history.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _shouldListen = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audio = Provider.of<AppAudioProvider>(context, listen: false);
      final lp = Provider.of<LanguageProvider>(context, listen: false);
      await Future.delayed(const Duration(milliseconds: 500));
      await audio.initSpeech();
      await _speakIntro(lp);
    });
  }

  @override
  void dispose() {
    _shouldListen = false;
    super.dispose();
  }
  Future<void> _speakIntro(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();
    await audio.speak(
      lp.isEnglish
          ? "Profile. Say personal info, addresses, notifications, "
          "voice settings, or log out. Say go back to return."
          : "الملف الشخصي. قل معلوماتي، العناوين، التنبيهات، "
          "إعدادات الصوت، أو تسجيل الخروج. قل ارجع للعودة.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
    if (mounted) {
      _shouldListen = true;
      _startListening(lp);
    }
  }



  void _startListening(LanguageProvider lp) async {
    if (!_shouldListen || !mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (audio.speech.isListening) return;

    await audio.toggleListening(
      lp.isEnglish ? "en" : "ar",
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;

        debugPrint("USER SAID (Profile): $text");
        final response = await AIService.sendMessage(text);
        final command = (response['command'] ?? "unknown").toString();
        debugPrint("AI COMMAND (Profile): $command");

        await _handleCommand(command, lp);

        _isProcessing = false;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_shouldListen && mounted) _startListening(lp);
        });
      },
      onError: (errorMsg) {
        // AudioProvider handles error_no_match automatically.
        // Only restart here for genuine errors.
        debugPrint("STT real error on screen: $errorMsg");
      },
    );
  }

  Future<void> _handleCommand(String command, LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    void pushAndResume(Widget page) {
      _shouldListen = false;
      Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) {
        _shouldListen = true;
        _isProcessing = false;
        _speakIntro(lp);
      });
    }

    switch (command) {
      case "open_personal_info":
        await audio.speak(
          lp.isEnglish ? "Opening personal information." : "جاري فتح المعلومات الشخصية.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        pushAndResume(const PersonalInformationPage());
        break;

      case "open_addresses":
        await audio.speak(
          lp.isEnglish ? "Opening your addresses." : "جاري فتح العناوين.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        pushAndResume(const DeliveryAddressesPage());
        break;

      case "open_history":
        await audio.speak(
          lp.isEnglish ? "Opening order history." : "جاري فتح سجل الطلبات.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        pushAndResume(const OrderHistoryPage());
        break;

      case "open_favorites":
        await audio.speak(
          lp.isEnglish ? "Opening favorites." : "جاري فتح المفضلة.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        pushAndResume(const FavoritesPage());
        break;

      case "open_voice_settings":
        await audio.speak(
          lp.isEnglish ? "Opening voice settings." : "جاري فتح إعدادات الصوت.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        pushAndResume(const VoiceSettingsPage());
        break;

      case "open_notifications":
        await audio.speak(
          lp.isEnglish ? "Opening notifications." : "جاري فتح التنبيهات.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        pushAndResume(const NotificationsPage());
        break;

      case "logout":
        _shouldListen = false;
        await audio.speak(
          lp.isEnglish ? "Logging you out." : "جاري تسجيل الخروج.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        await _performLogout();
        break;

      case "go_back":
        _shouldListen = false;

        if (mounted) Navigator.pop(context);
        break;

      default:
        await audio.speak(
          lp.isEnglish
              ? "Say personal info, addresses, order history, favorites, voice settings, notifications, or logout."
              : "قل معلوماتي، عناويني، طلباتي، المفضلة، إعدادات الصوت، التنبيهات، أو تسجيل خروج.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
    }
  }

  Future<void> _performLogout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
            (route) => false,
      );
    }
  }

  String _getInitials(String name) {
    if (name.isEmpty) return "??";
    List<String> names = name.trim().split(" ");
    if (names.length > 1) return "${names[0][0]}${names[1][0]}".toUpperCase();
    return names[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    const primaryRed = Color(0xFFD32F2F);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: primaryRed));
          }

          var userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          String displayName = userData['name'] ?? lp.getText('user_name_placeholder');

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: primaryRed,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: primaryRed,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        // Mic + Avatar
                        GestureDetector(
                          onTap: () {
                            if (!audio.speech.isListening && !_isProcessing) {
                              _shouldListen = true;
                              _startListening(lp);
                            }
                          },
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (audio.isListening)
                                Container(
                                  width: 90, height: 90,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.2),
                                  ),
                                ),
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.white,
                                child: Text(
                                  _getInitials(displayName),
                                  style: const TextStyle(
                                      fontSize: 28, color: primaryRed, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: audio.isListening ? Colors.green : Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    audio.isListening ? Icons.graphic_eq : Icons.mic,
                                    color: audio.isListening ? Colors.white : primaryRed,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(displayName,
                            style: const TextStyle(
                                fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold)),
                        Text(userData['phone'] ?? "",
                            style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),
                  _buildSection(lp.getText('account_section'), [
                    _buildTile(Icons.person_outline, lp.getText('personal_info_title'), () {
                      final lp2 = Provider.of<LanguageProvider>(context, listen: false);
                      _shouldListen = false;
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const PersonalInformationPage()))
                          .then((_) {
                        _shouldListen = true;
                        _isProcessing = false;
                        _speakIntro(lp2);
                      });
                    }),
                    _buildTile(Icons.location_on_outlined, lp.getText('address'), () {
                      final lp2 = Provider.of<LanguageProvider>(context, listen: false);
                      _shouldListen = false;
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const DeliveryAddressesPage()))
                          .then((_) {
                        _shouldListen = true;
                        _isProcessing = false;
                        _speakIntro(lp2);
                      });
                    }),
                    _buildTile(Icons.receipt_long_outlined, lp.getText('order_history'), () {
                      final lp2 = Provider.of<LanguageProvider>(context, listen: false);
                      _shouldListen = false;
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const OrderHistoryPage()))
                          .then((_) {
                        _shouldListen = true;
                        _isProcessing = false;
                        _speakIntro(lp2);
                      });
                    }),
                    _buildTile(Icons.favorite_outline, lp.getText('favorites resturant'), () {
                      final lp2 = Provider.of<LanguageProvider>(context, listen: false);
                      _shouldListen = false;
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const FavoritesPage()))
                          .then((_) {
                        _shouldListen = true;
                        _isProcessing = false;
                        _speakIntro(lp2);
                      });
                    }),
                  ]),
                  const SizedBox(height: 20),
                  _buildSection(lp.getText('preferences_section'), [
                    _buildTile(Icons.mic_none, lp.getText('voice_settings_title'), () {
                      final lp2 = Provider.of<LanguageProvider>(context, listen: false);
                      _shouldListen = false;
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const VoiceSettingsPage()))
                          .then((_) {
                        _shouldListen = true;
                        _isProcessing = false;
                        _speakIntro(lp2);
                      });
                    }),
                    _buildTile(Icons.notifications_none, lp.getText('notifications_title'), () {
                      final lp2 = Provider.of<LanguageProvider>(context, listen: false);
                      _shouldListen = false;
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const NotificationsPage()))
                          .then((_) {
                        _shouldListen = true;
                        _isProcessing = false;
                        _speakIntro(lp2);
                      });
                    }),
                  ]),
                  const SizedBox(height: 20),
                  _buildSection("", [
                    _buildTile(Icons.logout, lp.getText('logout'),
                            () => _performLogout(),
                        color: Colors.red),
                  ]),
                  const SizedBox(height: 40),
                ]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(title,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }

  Widget _buildTile(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFFD32F2F)),
      title: Text(title, style: TextStyle(color: color ?? Colors.black87)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}