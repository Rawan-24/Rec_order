import 'package:flutter/material.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  // Mock data for favorites
  final List<Map<String, dynamic>> _favorites = [
    {
      "name": "Pizza Paradise",
      "cuisine": "Italian • Pizza",
      "rating": "4.8",
      "time": "20-30 min",
      "image": "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=400",
    },
    {
      "name": "Burger Bros",
      "cuisine": "American • Burgers",
      "rating": "4.5",
      "time": "15-25 min",
      "image": "https://images.unsplash.com/photo-1571091718767-18b5b1457add?w=400",
    },
    {
      "name": "Sushi Station",
      "cuisine": "Japanese • Sushi",
      "rating": "4.9",
      "time": "30-40 min",
      "image": "https://images.unsplash.com/photo-1579871494447-9811cf80d66c?w=400",
    },
  ];

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFD32F2F);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Favorite Restaurants", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _favorites.isEmpty
          ? _buildEmptyState(primaryRed)
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          return _buildFavoriteCard(_favorites[index], primaryRed);
        },
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> item, Color accent) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to Restaurant Detail
        },
        child: Column(
          children: [
            // Restaurant Image
            Stack(
              children: [
                Image.network(
                  item['image'],
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () {
                        // Logic to remove from favorites
                      },
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(item['rating'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Restaurant Details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(item['cuisine'], style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(item['time'], style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color accent) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text("No favorites yet", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          const Text("Start hearting restaurants to see them here!", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text("Explore Restaurants"),
          ),
        ],
      ),
    );
  }
}