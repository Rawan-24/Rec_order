import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/screens/personal_information.dart';

import '../services/ai_service.dart';
import 'Delivery_Address.dart';
import 'NotificationsPage.dart';
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

  // Cached user data — set once in initState, updated by stream
  Map<String, dynamic> _userData = {};

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Single subscription — never recreated on rebuild
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) {
        if (mounted) {
          setState(() {
            _userData = doc.data() as Map<String, dynamic>? ?? {};
          });
        }
      });
    }

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
    super.dispose();
  }

  // ── Intro ─────────────────────────────────────────────────────────────────
  Future<void> _speakIntro(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();
    await audio.speak(
      lp.isEnglish
          ? "Profile. Say personal info, addresses, order history, favorites, "
          "voice settings, notifications, or log out. Say go back to return."
          : "الملف الشخصي. قل معلوماتي، العناوين، سجل الطلبات، المفضلة، "
          "إعدادات الصوت، التنبيهات، أو تسجيل الخروج. قل ارجع للعودة.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );
    if (mounted) {
      _shouldListen = true;
      _startListening(lp);
    }
  }

  // ── Listen loop ───────────────────────────────────────────────────────────
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
        final response = await AIService.sendMessage(text, screen: "profile");
        final command  = (response['command'] ?? response['text'] ?? "unknown").toString();
        debugPrint("AI COMMAND (Profile): $command");

        await _handleCommand(command, lp);
        _isProcessing = false;
      },
      onError: (errorMsg) {
        debugPrint("STT real error (Profile): $errorMsg");
      },
    );
  }

  // ── Command handler ───────────────────────────────────────────────────────
  Future<void> _handleCommand(String command, LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    void pushAndResume(Widget page) {
      _shouldListen = false;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      ).then((_) {
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

      case "read_commands":
        await audio.speak(
          lp.isEnglish
              ? "You can say: personal info, addresses, order history, "
              "favorites, voice settings, notifications, logout, or go back."
              : "يمكنك قول: معلوماتي، عناويني، سجل الطلبات، المفضلة، "
              "إعدادات الصوت، التنبيهات، تسجيل الخروج، أو ارجع.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

      case "go_back":
        _shouldListen = false;
        await audio.stop();
        if (mounted) Navigator.pop(context);
        break;

      default:
        await audio.speak(
          lp.isEnglish
              ? "Say personal info, addresses, order history, favorites, "
              "voice settings, notifications, or logout."
              : "قل معلوماتي، عناويني، طلباتي، المفضلة، "
              "إعدادات الصوت، التنبيهات، أو تسجيل خروج.",
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
    final parts = name.trim().split(" ");
    if (parts.length > 1) return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    return parts[0][0].toUpperCase();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  // KEY FIX: NO Provider.of<AppAudioProvider>(context) here.
  // NO StreamBuilder — _userData is already kept fresh by the initState listener.
  // Only Consumer wraps the parts that actually need audio state.
  @override
  Widget build(BuildContext context) {
    final lp   = Provider.of<LanguageProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    const primaryRed = Color(0xFFD32F2F);

    // Read from state variable — never from a StreamBuilder
    final String displayName =
        _userData['name'] ?? lp.getText('user_name_placeholder');
    final String phone = _userData['phone'] ?? "";

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
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

                    // ── Only the avatar mic indicator needs Consumer ──────
                    Consumer<AppAudioProvider>(
                      builder: (_, audio, __) => GestureDetector(
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
                                width: 90,
                                height: 90,
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
                                    fontSize: 28,
                                    color: primaryRed,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: audio.isListening
                                      ? Colors.green
                                      : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  audio.isListening
                                      ? Icons.graphic_eq
                                      : Icons.mic,
                                  color: audio.isListening
                                      ? Colors.white
                                      : primaryRed,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Text(displayName,
                        style: const TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                            fontWeight: FontWeight.bold)),
                    Text(phone,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 20),
              _buildSection(lp.getText('account_section'), [
                _buildTile(Icons.person_outline,
                    lp.getText('personal_info_title'), () {
                      _shouldListen = false;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PersonalInformationPage()),
                      ).then((_) {
                        _shouldListen = true;
                        _isProcessing = false;
                        _speakIntro(lp);
                      });
                    }),
                _buildTile(Icons.location_on_outlined,
                    lp.getText('address'), () {
                      _shouldListen = false;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const DeliveryAddressesPage()),
                      ).then((_) {
                        _shouldListen = true;
                        _isProcessing = false;
                        _speakIntro(lp);
                      });
                    }),
                _buildTile(Icons.receipt_long_outlined,
                    lp.getText('order_history'), () {
                      _shouldListen = false;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OrderHistoryPage()),
                      ).then((_) {
                        _shouldListen = true;
                        _isProcessing = false;
                        _speakIntro(lp);
                      });
                    }),
                _buildTile(Icons.favorite_outline,
                    lp.getText('favorites resturant'), () {
                      _shouldListen = false;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FavoritesPage()),
                      ).then((_) {
                        _shouldListen = true;
                        _isProcessing = false;
                        _speakIntro(lp);
                      });
                    }),
              ]),
              const SizedBox(height: 20),
              _buildSection(lp.getText('preferences_section'), [
                _buildTile(Icons.mic_none,
                    lp.getText('voice_settings_title'), () {
                      _shouldListen = false;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VoiceSettingsPage()),
                      ).then((_) {
                        _shouldListen = true;
                        _isProcessing = false;
                        _speakIntro(lp);
                      });
                    }),
                _buildTile(Icons.notifications_none,
                    lp.getText('notifications_title'), () {
                      _shouldListen = false;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsPage()),
                      ).then((_) {
                        _shouldListen = true;
                        _isProcessing = false;
                        _speakIntro(lp);
                      });
                    }),
              ]),
              const SizedBox(height: 20),
              _buildSection("", [
                _buildTile(
                  Icons.logout,
                  lp.getText('logout'),
                      () => _performLogout(),
                  color: Colors.red,
                ),
              ]),
              const SizedBox(height: 40),
            ]),
          ),
        ],
      ),

      // ── FAB: only this rebuilds when mic state changes ────────────────────
      floatingActionButton: Consumer<AppAudioProvider>(
        builder: (_, audio, __) => FloatingActionButton(
          backgroundColor: audio.isListening ? Colors.green : primaryRed,
          onPressed: () {
            if (!audio.speech.isListening && !_isProcessing) {
              _shouldListen = true;
              _startListening(lp);
            }
          },
          child: Icon(
            audio.isListening ? Icons.graphic_eq : Icons.mic,
            color: Colors.white,
          ),
        ),
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
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey)),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04), blurRadius: 8)
            ],
          ),
          child: Column(children: tiles),
        ),
      ],
    );
  }

  Widget _buildTile(IconData icon, String title, VoidCallback onTap,
      {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? const Color(0xFFD32F2F)),
      title: Text(title, style: TextStyle(color: color ?? Colors.black87)),
      trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      onTap: onTap,
    );
  }
}