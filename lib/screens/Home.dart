import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Your existing project imports
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

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
      // Display HomeContent when index is 0, otherwise show a placeholder
      body: _selectedIndex == 0 ? const HomeContent() : _placeholderBody(_selectedIndex, lp),
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

  Widget _placeholderBody(int index, LanguageProvider lp) {
    return Center(
      child: Text(
        index == 1 ? lp.getText('nav_orders') : lp.getText('nav_profile'),
        style: const TextStyle(fontSize: 18, color: Colors.grey),
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
    // Combines Greeting and Subtitle for a smooth voice intro
    String msg = "${lp.getText('hello')}! ${lp.getText('home_subtitle')}";
    audio.speak(msg, lp.currentLanguage);
  }

  @override
  Widget build(BuildContext context) {
    // Correctly initializing providers within the build scope
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            _buildGreetingHeader(lp),
            const SizedBox(height: 8),
            Text(
              lp.getText('home_subtitle'),
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),

            const Spacer(flex: 2),

            // CENTRAL ASSISTANT SECTION
            Center(
              child: Column(
                children: [
                  Text(
                    audio.isListening
                        ? (lp.isRTL ? "أنا بسمعك..." : "Listening...")
                        : lp.getText('tap_to_speak'),
                    style: TextStyle(
                        color: audio.isListening ? const Color(0xFFEB1B33) : Colors.black45,
                        fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Pass 'lp' here to fix the Undefined Name error
                  _buildMicButton(audio, lp),
                ],
              ),
            ),

            const Spacer(flex: 3),

            Text(
                lp.getText('quick_actions'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 16),

            // QUICK ACTION GRID
            Row(
              children: [
                _actionCard(lp.getText('action_order'), Icons.restaurant, () => Navigator.pushNamed(context, '/restaurants')),
                const SizedBox(width: 16),
                _actionCard(lp.getText('action_track'), Icons.local_shipping, () => Navigator.pushNamed(context, '/track_order')),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _actionCard(lp.getText('action_reorder'), Icons.history, () => Navigator.pushNamed(context, '/history')),
                const SizedBox(width: 16),
                _actionCard(lp.getText('action_favorites'), Icons.favorite_border, () => Navigator.pushNamed(context, '/favorites')),
              ],
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildGreetingHeader(LanguageProvider lp) {
    return StreamBuilder<DocumentSnapshot>(
      stream: DatabaseService().getUserDataStream(),
      builder: (context, snapshot) {
        String name = "";
        if (snapshot.hasData && snapshot.data!.exists) {
          Map<String, dynamic> data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['name'] ?? "";
        }
        return Row(
          children: [
            Expanded(
              child: Text(
                "${lp.getText('hello')} $name!",
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Text("👋", style: TextStyle(fontSize: 24)),
          ],
        );
      },
    );
  }

  Widget _buildMicButton(AppAudioProvider audio, LanguageProvider lp) {
    return GestureDetector(
      onTap: () => audio.toggleListening(lp.currentLanguage, (val) {}),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: audio.isListening ? 95 : 75,
        height: audio.isListening ? 95 : 75,
        decoration: BoxDecoration(
          color: const Color(0xFFEB1B33),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFEB1B33).withOpacity(0.4),
              blurRadius: audio.isListening ? 25 : 8,
              spreadRadius: audio.isListening ? 12 : 2,
            )
          ],
        ),
        child: Icon(
            audio.isListening ? Icons.graphic_eq : Icons.mic,
            color: Colors.white,
            size: 32
        ),
      ),
    );
  }

  Widget _actionCard(String label, IconData icon, VoidCallback tap) {
    return Expanded(
      child: InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4)
              )
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: const Color(0xFFEB1B33), size: 30),
              const SizedBox(height: 12),
              Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)
              ),
            ],
          ),
        ),
      ),
    );
  }
}