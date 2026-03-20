import 'package:flutter/material.dart';
import 'package:grad_project/screens/Restaurant.dart';
import 'package:grad_project/screens/RestaurantData.dart';
import 'package:grad_project/screens/Menu.dart';
import 'package:grad_project/screens/RestaurantCard.dart';

class RestaurantsScreen extends StatefulWidget {
  static const String routeName = "RestaurantsScreen";

  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  final List<Restaurant> allRestaurants = RestaurantData.restaurants;

  List<Restaurant> displayedRestaurants = [];

  @override
  void initState() {
    super.initState();
    displayedRestaurants = List.from(allRestaurants);
  }

  void _applyFilter(String criteria) {
    setState(() {
      if (criteria == 'rating') {
        // Sort by rating (Highest to Lowest)
        displayedRestaurants.sort((a, b) =>
            double.parse(b.rating).compareTo(double.parse(a.rating))
        );
      } else if (criteria == 'distance') {
        // Sort by distance (Nearest to Farthest)
        displayedRestaurants.sort((a, b) {
          // This removes " km" and any other text so we can parse just the number
          double distA = double.parse(a.distance.replaceAll(RegExp(r'[^0-9.]'), ''));
          double distB = double.parse(b.distance.replaceAll(RegExp(r'[^0-9.]'), ''));
          return distA.compareTo(distB);
        });
      } else {
        // Reset to original list order
        displayedRestaurants = List.from(allRestaurants);
      }
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

          // THE DYNAMIC LIST
          Expanded(
              child:ListView.builder(
                itemCount: displayedRestaurants.length,
                itemBuilder: (context, index) {

                  var restaurant = displayedRestaurants[index];

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
              )
          ),
        ],
      ),
    );
  }
}