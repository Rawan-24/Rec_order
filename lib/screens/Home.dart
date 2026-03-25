import 'package:flutter/material.dart';
import 'package:grad_project/screens/RestaurantsScreen.dart';
import 'package:grad_project/screens/profile.dart';
import 'TrackOrderScreen.dart';
import 'favorites.dart';
import 'history.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // 👇 Pages for bottom navigation
  final List<Widget> _pages = [
    const HomeContent(),
    const TrackOrderScreen(),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),

      // 👇 This switches screens
      body: _pages[_selectedIndex],

      bottomNavigationBar: BottomNavigationBar(
        elevation: 10,
        backgroundColor: Colors.white,
        selectedItemColor: const Color(0xFFEB1B33),
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: "Home",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: "Orders",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}

// 👇 Your original UI moved here
class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  // Helper to build the square action cards
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),

            // Header
            Row(
              children: const [
                Text(
                  "Hello !",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Text("👋", style: TextStyle(fontSize: 24)),
              ],
            ),

            const SizedBox(height: 8),

            const Text(
              "What would you like to eat today?",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),

            const Spacer(flex: 2),

            // Voice section
            Center(
              child: Column(
                children: [
                  const Text(
                    "Tap to speak your order",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEB1B33),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 3),

            // Quick Actions
            const Text(
              "Quick Actions",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            // Row 1
            Row(
              children: [
                buildQuickAction(
                  context,
                  "Order Food",
                  Icons.restaurant,
                  const Color(0xFFEB1B33),
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RestaurantsScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                buildQuickAction(
                  context,
                  "Track Order",
                  Icons.inventory_2,
                  const Color(0xFFEB1B33),
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TrackOrderScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Row 2
            Row(
              children: [
                buildQuickAction(
                  context,
                  "Reorder",
                  Icons.history,
                  const Color(0xFFEB1B33),
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const OrderHistoryPage(),
                          ),
                    );
                  },
                ),
                const SizedBox(width: 16),
                buildQuickAction(
                  context,
                  "Favorites",
                  Icons.favorite_border,
                  const Color(0xFFEB1B33),
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FavoritesPage(),
                          ),
                    );
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