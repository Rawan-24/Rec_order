import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/Models/Restaurant.dart';
import 'package:grad_project/screens/RestaurantData.dart';
import 'package:grad_project/screens/Menu.dart';
import 'package:grad_project/screens/RestaurantCard.dart';
//Done
class RestaurantsScreen extends StatefulWidget {
  static const String routeName = "RestaurantsScreen";

  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
 
  final DatabaseService _dbService = DatabaseService();
  String _currentFilter = 'reset';

  @override
  void initState() {
    super.initState();
    // Trigger the upload logic automatically when the screen loads
    _checkAndSeedData();
  }
  


  Future<void> _checkAndSeedData() async {
    // Optional: You could check if the database is empty first
    // to avoid duplicating data every time the app opens.
    
    try {
      // This calls the method you added to your DatabaseService
      await _dbService.uploadMockData(RestaurantData.restaurants);
      print("Database seeded successfully from initState");
    } catch (e) {
      print("Error seeding data: $e");
    }
  }
void _applyFilter(String criteria) {
  setState(() {
    _currentFilter = criteria;
  });
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      appBar: AppBar(

        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Restaurants", style: TextStyle(color: Colors.black)),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_alt, color: Colors.black),
            onSelected: _applyFilter,
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'rating', child: Text("Highest Rating")),
              const PopupMenuItem(value: 'distance', child: Text("Nearest First")),
              const PopupMenuItem(value: 'reset', child: Text("Reset Filters")),
            ],
          ),
    
        ],
        
      ),

      // Floating Mic Button
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 70),
        child: FloatingActionButton(
          backgroundColor: const Color(0xFFEB1B33),
          onPressed: () {},
          child: const Icon(Icons.mic, color: Colors.black),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,

      // Main Content
      body: Column(
        children: [
          const SizedBox(height: 70), // Space for the floating button overhead

          // Voice search hint
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Row(
                children: [
                  Icon(Icons.mic, color: Colors.black),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Say "Show me pizza places" or tap a restaurant',
                      style: TextStyle(color: Color(0xFF616161)),
                    ),
                  )
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

    // --- THE DYNAMIC LIST ---
Expanded(
  child: StreamBuilder<List<Restaurant>>(
    stream: _dbService.getRestaurantsStream(), // Connection to Firebase
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text("Error: ${snapshot.error}"));
      }
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator(color: Color(0xFFEB1B33)));
      }

      // 1. Get the data from Firebase
      List<Restaurant> restaurants = snapshot.data ?? [];

      // 2. Apply Sorting (Rating or Distance)
      // Inside StreamBuilder sorting logic
if (_currentFilter == 'rating') {
  restaurants.sort((a, b) {
    double ratingA = double.tryParse(a.rating) ?? 0.0; // Use tryParse to avoid crashes
    double ratingB = double.tryParse(b.rating) ?? 0.0;
    return ratingB.compareTo(ratingA);
  });
}
else if (_currentFilter == 'distance') {
  restaurants.sort((a, b) {
    // tryParse is safer to prevent crashes on bad data
    double distA = double.tryParse(a.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    double distB = double.tryParse(b.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
    return distA.compareTo(distB);
  });
}

      if (restaurants.isEmpty) {
        return const Center(child: Text("No restaurants found."));
      }

      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: restaurants.length,
        itemBuilder: (context, index) {
          var restaurant = restaurants[index];
          return RestaurantCard(
            name: restaurant.name,
            rating: restaurant.rating,
            distance: restaurant.distance,
            image: restaurant.image,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Menu(restaurant: restaurant),
                ),
              );
            },
          );
        },
      );
    },
  ),
),
        ],
      ),
    );
  }
}