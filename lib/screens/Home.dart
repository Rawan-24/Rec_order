import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Your existing project imports
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/screens/RestaurantsScreen.dart';
import 'package:grad_project/screens/profile.dart';
import 'package:grad_project/screens/TrackOrderScreen.dart';
import 'package:grad_project/screens/favorites.dart';
import 'package:grad_project/screens/history.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeContent(),
    const TrackOrderScreen(orderId: ''),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
            icon: const Icon(Icons.inventory_2_outlined),
            label: lp.getText('nav_orders'),
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

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  @override
  void initState() {
    super.initState();
    // Auto-greet the user when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceArrival();
    });
  }

  void _announceArrival() {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Combining "Hello" and "What would you like to eat today?"
    String msg = "${lp.getText('hello')}! ${lp.getText('home_subtitle')}";
    audio.speak(msg, lp.currentLanguage);
  }

  void _handleVoiceInteraction(BuildContext context, AppAudioProvider audio, LanguageProvider lp) async {
    await audio.toggleListening(lp.currentLanguage, (recognizedWords) async {
      String command = recognizedWords.toLowerCase();

      // Navigation Logic (English & Arabic)
      if (command.contains("اطلب") || command.contains("مطعم") || command.contains("order")) {
        audio.speak(lp.isRTL ? "حاضر، هفتحلك المطاعم" : "Opening restaurants", lp.currentLanguage);
        Navigator.push(context, MaterialPageRoute(builder: (context) => const RestaurantsScreen()));
      }
      else if (command.contains("حسابي") || command.contains("بروفايل") || command.contains("profile")) {
        audio.speak(lp.isRTL ? "فتحتلك صفحتك الشخصية" : "Opening your profile", lp.currentLanguage);
        Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
      }
      else if (command.contains("تتبع") || command.contains("فين") || command.contains("track")) {
        audio.speak(lp.isRTL ? "بنشوف طلبك فين" : "Checking your order status", lp.currentLanguage);
        String? id = await DatabaseService().getActiveOrderId();
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => TrackOrderScreen(orderId: id ?? "")));
        }
      }
      else if (command.contains("مفضل") || command.contains("favorite")) {
        audio.speak(lp.isRTL ? "إليك مطاعمك المفضلة" : "Here are your favorites", lp.currentLanguage);
        Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesPage()));
      }
    });
  }

  Widget buildQuickAction(
      BuildContext context,
      String text,
      IconData icon,
      Color iconBgColor,
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
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                text,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

            // --- GREETING SECTION ---
            StreamBuilder<DocumentSnapshot>(
              stream: DatabaseService().getUserDataStream(),
              builder: (context, snapshot) {
                String displayName = "";
                if (snapshot.hasData && snapshot.data!.exists) {
                  Map<String, dynamic> data = snapshot.data!.data() as Map<String, dynamic>;
                  displayName = data['name'] ?? "";
                }
                String fullGreeting = "${lp.getText('hello')} ${displayName.isEmpty ? '' : displayName}!".trim();

                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        fullGreeting,
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
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

            // --- CENTRAL MICROPHONE ---
            Center(
              child: Column(
                children: [
                  Text(
                    audio.isListening
                        ? (lp.isRTL ? "أنا بسمعك..." : "Listening...")
                        : lp.getText('tap_to_speak'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: audio.isListening ? const Color(0xFFEB1B33) : Colors.black45,
                      fontWeight: audio.isListening ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () => _handleVoiceInteraction(context, audio, lp),
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
                          )
                        ],
                      ),
                      child: Icon(
                        audio.isListening ? Icons.graphic_eq : Icons.mic,
                        color: Colors.white,
                        size: 35,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 3),

            Text(
              lp.getText('quick_actions'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                buildQuickAction(context, lp.getText('action_order'), Icons.restaurant, const Color(0xFFEB1B33), () {
                  audio.speak(lp.isRTL ? "طلب الطعام" : "Let's order some food", lp.currentLanguage);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RestaurantsScreen()));
                }),
                const SizedBox(width: 16),
                buildQuickAction(context, lp.getText('action_track'), Icons.inventory_2, const Color(0xFFEB1B33), () async {
                  audio.speak(lp.isRTL ? "بنشوف طلبك فين" : "Checking your order", lp.currentLanguage);
                  String? id = await DatabaseService().getActiveOrderId();
                  if (context.mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => TrackOrderScreen(orderId: id ?? "")));
                  }
                }),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                buildQuickAction(context, lp.getText('action_reorder'), Icons.history, const Color(0xFFEB1B33), () {
                  audio.speak(lp.isRTL ? "بفتح سجل الطلبات" : "Opening history", lp.currentLanguage);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const OrderHistoryPage()));
                }),
                const SizedBox(width: 16),
                buildQuickAction(context, lp.getText('action_favorites'), Icons.favorite_border, const Color(0xFFEB1B33), () {
                  audio.speak(lp.isRTL ? "مطاعمك المفضلة" : "Your favorite restaurants", lp.currentLanguage);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const FavoritesPage()));
                }),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}