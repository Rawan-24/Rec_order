import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/screens/RestaurantsScreen.dart';
import 'package:grad_project/screens/profile.dart';
import 'package:grad_project/screens/TrackOrderScreen.dart';
import 'package:grad_project/screens/favorites.dart';
import 'package:grad_project/screens/history.dart';
import 'package:grad_project/services/ai_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM NAV SHELL
// ─────────────────────────────────────────────────────────────────────────────
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeContent(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        elevation: 10,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFEB1B33),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: lp.getText('nav_home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            label: lp.getText('nav_profile'),
          ),
        ],
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// HOME CONTENT — with AI + always-on voice loop
// ─────────────────────────────────────────────────────────────────────────────
class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  bool _shouldListen = true;
  bool _isProcessing = false;

  // ─────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audio = Provider.of<AppAudioProvider>(context, listen: false);
      final lp = Provider.of<LanguageProvider>(context, listen: false);




      await Future.delayed(const Duration(milliseconds: 800));
      await audio.initSpeech();
      await _speakIntro(lp);
    });
  }

  // ─────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────
  @override
  void dispose() {
    _shouldListen = false;
    super.dispose();
  }

  // ─────────────────────────────────────────
  // INTRO
  // ─────────────────────────────────────────
  Future<void> _speakIntro(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop();
    await audio.speak(
      lp.isEnglish
          ? "Home screen. Say order food, track order, favorites, history, or profile."
          : "الشاشة الرئيسية. قل اطلب أكل، تتبع الطلب، المفضلة، السجل، أو حسابي.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    if (mounted) {
      _shouldListen = true;
      _startListening(lp);
    }
  }

  // ─────────────────────────────────────────
  // ALWAYS-ON LISTEN LOOP
  // ─────────────────────────────────────────
  void _startListening(LanguageProvider lp) async {
    if (!_shouldListen || !mounted) return;

    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    if (audio.speech.isListening) {
      debugPrint("Mic already open — skipping duplicate start");
      return;
    }

    await audio.toggleListening(
      lp.isEnglish ? "en" : "ar",

      // ── onResult ────────────────────────────────────────────
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;

        debugPrint("USER SAID: $text");

        final response = await AIService.sendMessage(text);
        final command = (response['command'] ?? "unknown").toString();

        debugPrint("AI COMMAND: $command");

        await _handleCommand(command, lp);

        _isProcessing = false;

        Future.delayed(const Duration(milliseconds: 600), () {
          if (_shouldListen && mounted) _startListening(lp);
        });
      },

      // ── onError: retry on silence / no-match ────────────────
      onError: (errorMsg) {
        // AudioProvider handles error_no_match automatically.
        // Only restart here for genuine errors.
        debugPrint("STT real error on screen: $errorMsg");
      },
    );
  }

  // ─────────────────────────────────────────
  // COMMAND HANDLER
  // ─────────────────────────────────────────
  Future<void> _handleCommand(String command, LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    switch (command) {

    // ── Open restaurants ───────────────────────────────────
      case "open_restaurants":
        _shouldListen = false;
        await audio.speak(
          lp.isEnglish ? "Opening restaurants." : "جاري فتح المطاعم.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RestaurantsScreen()),
          ).then((_) => _resumeListening(lp));
        }
        break;

    // ── Track order ────────────────────────────────────────
        case "track_active_order":
        case "open_track":
        _shouldListen = false;
        await audio.speak(
          lp.isEnglish ? "Checking your order." : "جاري تتبع طلبك.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        final id = await DatabaseService().getActiveOrderId();
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TrackOrderScreen(orderId: id ?? "")),
          ).then((_) => _resumeListening(lp));
        }
        break;

    // ── Open favorites ─────────────────────────────────────
      case "open_favorites":
        _shouldListen = false;
        await audio.speak(
          lp.isEnglish ? "Opening your favorites." : "جاري فتح المفضلة.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FavoritesPage()),
          ).then((_) => _resumeListening(lp));
        }
        break;

    // ── Open history ───────────────────────────────────────
      case "open_history":
        _shouldListen = false;
        await audio.speak(
          lp.isEnglish ? "Opening your order history." : "جاري فتح سجل الطلبات.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const OrderHistoryPage()),
          ).then((_) => _resumeListening(lp));
        }
        break;

    // ── Open profile ───────────────────────────────────────
      case "open_profile":
        _shouldListen = false;
        await audio.speak(
          lp.isEnglish ? "Opening your profile." : "جاري فتح حسابك.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfilePage()),
          ).then((_) => _resumeListening(lp));
        }
        break;

    // ── Repeat available commands ──────────────────────────
      case "read_commands":
        await audio.speak(
          lp.isEnglish
              ? "You can say: order food, track order, favorites, history, or profile."
              : "يمكنك قول: اطلب أكل، تتبع الطلب، المفضلة، السجل، أو حسابي.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

    // ── Fallback ───────────────────────────────────────────
      default:
        await audio.speak(
          lp.isEnglish
              ? "Say order food, track order, favorites, history, or profile."
              : "قل اطلب أكل، تتبع الطلب، المفضلة، السجل، أو حسابي.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
    }
  }

  // ─────────────────────────────────────────
  // RESUME after returning from pushed screen
  // ─────────────────────────────────────────
  void _resumeListening(LanguageProvider lp) {
    if (!mounted) return;
    _shouldListen = true;
    _isProcessing = false;
    _speakIntro(lp); // re-announce and restart loop
  }

  // ─────────────────────────────────────────
  // QUICK ACTION CARD
  // ─────────────────────────────────────────
  Widget _buildQuickAction(
      BuildContext context,
      String text,
      IconData icon,
      VoidCallback onTap,
      ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEB1B33),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),

            // ── Greeting ───────────────────────────────────────
            StreamBuilder<DocumentSnapshot>(
              stream: DatabaseService().getUserDataStream(),
              builder: (context, snapshot) {
                String displayName = "";
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  displayName = data['name'] ?? "";
                }
                final greeting =
                "${lp.getText('hello')} ${displayName.isEmpty ? '' : displayName}!"
                    .trim();

                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        greeting,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Text("👋", style: TextStyle(fontSize: 24)),
                  ],
                );
              },
            ),

            const SizedBox(height: 8),
            Text(
              lp.getText('home_subtitle'),
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),

            const Spacer(flex: 2),

            // ── Central mic ────────────────────────────────────
            Center(
              child: Column(
                children: [
                  // Listening status label
                  Text(
                    audio.isListening
                        ? (lp.isEnglish ? "Listening..." : "أنا بسمعك...")
                        : (lp.isEnglish ? "Tap to speak" : "اضغط للتحدث"),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: audio.isListening
                          ? const Color(0xFFEB1B33)
                          : Colors.black45,
                      fontWeight: audio.isListening
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Mic button — tap restarts the loop manually
                  GestureDetector(
                    onTap: () {
                      final lp = Provider.of<LanguageProvider>(context,
                          listen: false);
                      if (!audio.speech.isListening && !_isProcessing) {
                        _shouldListen = true;
                        _startListening(lp);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: audio.isListening ? 100 : 80,
                      height: audio.isListening ? 100 : 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEB1B33),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFEB1B33).withOpacity(0.4),
                            blurRadius: audio.isListening ? 30 : 10,
                            spreadRadius: audio.isListening ? 12 : 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        audio.isListening ? Icons.graphic_eq : Icons.mic,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Mic status pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          audio.isListening
                              ? Icons.graphic_eq
                              : Icons.mic_none,
                          size: 16,
                          color: const Color(0xFFEB1B33),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          audio.isListening
                              ? (lp.isEnglish
                              ? "Listening..."
                              : "أنا أسمعك الآن...")
                              : (lp.isEnglish
                              ? "Ready"
                              : "جاهز"),
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[700]),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 3),

            // ── Quick actions label ────────────────────────────
            Text(
              lp.getText('quick_actions'),
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // ── Row 1 ──────────────────────────────────────────
            Row(
              children: [
                _buildQuickAction(
                  context,
                  lp.getText('action_order'),
                  Icons.restaurant,
                      () async {
                    _shouldListen = false;
                    await audio.speak(
                      lp.isEnglish
                          ? "Opening restaurants."
                          : "جاري فتح المطاعم.",
                      lp.isEnglish ? "en-US" : "ar-SA",
                    );
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RestaurantsScreen()),
                      ).then((_) => _resumeListening(lp));
                    }
                  },
                ),
                const SizedBox(width: 16),
                _buildQuickAction(
                  context,
                  lp.getText('action_track'),
                  Icons.inventory_2,
                      () async {
                    _shouldListen = false;
                    await audio.speak(
                      lp.isEnglish
                          ? "Checking your order."
                          : "جاري تتبع طلبك.",
                      lp.isEnglish ? "en-US" : "ar-SA",
                    );
                    final id = await DatabaseService().getActiveOrderId();
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                TrackOrderScreen(orderId: id ?? "")),
                      ).then((_) => _resumeListening(lp));
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Row 2 ──────────────────────────────────────────
            Row(
              children: [
                _buildQuickAction(
                  context,
                  lp.getText('action_reorder'),
                  Icons.history,
                      () async {
                    _shouldListen = false;
                    await audio.speak(
                      lp.isEnglish
                          ? "Opening order history."
                          : "جاري فتح السجل.",
                      lp.isEnglish ? "en-US" : "ar-SA",
                    );
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const OrderHistoryPage()),
                      ).then((_) => _resumeListening(lp));
                    }
                  },
                ),
                const SizedBox(width: 16),
                _buildQuickAction(
                  context,
                  lp.getText('action_favorites'),
                  Icons.favorite_border,
                      () async {
                    _shouldListen = false;
                    await audio.speak(
                      lp.isEnglish
                          ? "Opening favorites."
                          : "جاري فتح المفضلة.",
                      lp.isEnglish ? "en-US" : "ar-SA",
                    );
                    if (mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FavoritesPage()),
                      ).then((_) => _resumeListening(lp));
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}