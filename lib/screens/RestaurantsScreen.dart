import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/Models/Restaurant.dart';
import 'package:grad_project/screens/RestaurantData.dart';
import 'package:grad_project/screens/Menu.dart';
import 'package:grad_project/screens/RestaurantCard.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';

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
    _checkAndSeedData();
  }

  Future<void> _checkAndSeedData() async {
    try {
      await _dbService.uploadMockData(RestaurantData.restaurants);
      print("Database seeded successfully");
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
    final lp = Provider.of<LanguageProvider>(context);
    const primaryRed = Color(0xFFEB1B33);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lp.getText('restaurants_title'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_alt, color: Colors.black),
            onSelected: _applyFilter,
            itemBuilder: (context) => [
              PopupMenuItem(value: 'rating', child: Text(lp.getText('filter_rating'))),
              PopupMenuItem(value: 'distance', child: Text(lp.getText('filter_distance'))),
              PopupMenuItem(value: 'reset', child: Text(lp.getText('filter_reset'))),
            ],
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 70),
        child: FloatingActionButton(
          backgroundColor: primaryRed,
          onPressed: () {},
          child: const Icon(Icons.mic, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,
      body: Column(
        children: [
          const SizedBox(height: 70),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Colors.black),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lp.getText('restaurants_voice_hint'),
                      style: const TextStyle(color: Color(0xFF616161)),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<Restaurant>>(
              stream: _dbService.getRestaurantsStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("${lp.getText('error_loading')}: ${snapshot.error}"));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: primaryRed));
                }

                List<Restaurant> restaurants = snapshot.data ?? [];

                // Sorting Logic
                if (_currentFilter == 'rating') {
                  restaurants.sort((a, b) {
                    double ratingA = double.tryParse(a.rating) ?? 0.0;
                    double ratingB = double.tryParse(b.rating) ?? 0.0;
                    return ratingB.compareTo(ratingA);
                  });
                } else if (_currentFilter == 'distance') {
                  restaurants.sort((a, b) {
                    double distA = double.tryParse(a.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
                    double distB = double.tryParse(b.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
                    return distA.compareTo(distB);
                  });
                }

                if (restaurants.isEmpty) {
                  return Center(child: Text(lp.getText('no_restaurants_found')));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: restaurants.length,
                  itemBuilder: (context, index) {
                    var restaurant = restaurants[index];
                    return RestaurantCard(
                      name: restaurant.name,
                      rating: restaurant.rating,
                      distance: restaurant.distance, // Ensure distance string is localized in DB if needed
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