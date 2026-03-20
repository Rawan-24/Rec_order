import 'package:flutter/material.dart';

class RestaurantCard extends StatelessWidget {
  final String name;
  final String rating;
  final String distance;
  final VoidCallback onTap;
  final String image;

  const RestaurantCard({super.key,
    required this.name,
    required this.rating,
    required this.distance,
    required this.onTap, required this.image
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Image
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                image,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.orange, size: 18),
                      Text(" $rating"),
                      const SizedBox(width: 16),
                      const Icon(Icons.location_on, size: 18, color: Colors.grey),
                      Text(" $distance"),
                    ],
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}