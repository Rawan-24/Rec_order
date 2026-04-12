import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
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

  final List<Widget> _pages = [
    const HomeContent(),
    const TrackOrderScreen(orderId: ''),
    const ProfilePage(),
  ];

  void _onItemTapped(int index) async {
    if (index == 1) { // If "Orders" tab is clicked
      String? id = await DatabaseService().getActiveOrderId();
      setState(() {
        _selectedIndex = index;
        // You might need to update your _pages list dynamically
        // or pass the ID to a state variable.
      });
    } else {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

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

            // --- DATABASE INTEGRATION: Fetching User Name ---
            StreamBuilder<DocumentSnapshot>(
              stream: DatabaseService().getUserDataStream(),
              builder: (context, snapshot) {
                String displayName = "";

                if (snapshot.hasData && snapshot.data!.exists) {
                  Map<String, dynamic> data = snapshot.data!.data() as Map<String, dynamic>;
                  displayName = data['name'] ?? "";
                }

                return Row(
                  children: [
                    Text(
                      displayName.isEmpty ? "Hello !" : "Hello $displayName!",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text("👋", style: TextStyle(fontSize: 24)),
                  ],
                );
              },
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
                  InkWell(
                    onTap: () {
                      // Logic for voice ordering can go here
                    },
                    child: Container(
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
                  ),
                ],
              ),
            ),

            const Spacer(flex: 3),

            const Text(
              "Quick Actions",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

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
                      MaterialPageRoute(builder: (context) => const RestaurantsScreen()),
                    );
                  },
                ),
                const SizedBox(width: 16),
                buildQuickAction(
                  context,
                  "Track Order",
                  Icons.inventory_2,
                  const Color(0xFFEB1B33),
                      () async { // Added 'async' here
                    // 1. Show a loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(color: Color(0xFFEB1B33)),
                      ),
                    );

                    // 2. Get the ID from your DatabaseService
                    // Make sure this method exists in your DatabaseService.dart!
                    String? id = await DatabaseService().getActiveOrderId();

                    // 3. Remove the loading indicator
                    if (context.mounted) Navigator.pop(context);

                    // 4. Navigate with the actual ID
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TrackOrderScreen(orderId: id ?? ""),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

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
                      MaterialPageRoute(builder: (context) => const OrderHistoryPage()),
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
                      MaterialPageRoute(builder: (context) => const FavoritesPage()),
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