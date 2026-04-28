import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';

class RestaurantCard extends StatelessWidget {
  final String name;
  final String rating;
  final String distance;
  final String image;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  const RestaurantCard({
    super.key,
    required this.name,
    required this.rating,
    required this.distance,
    required this.image,
    required this.onTap,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  Future<void> _announceRestaurant(BuildContext context) async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop();

    if (lp.isRTL) {
      audio.speak(name, "en-US");
      await Future.delayed(const Duration(milliseconds: 400));
      audio.speak(
        "التقييم $rating. يبعد مسافة $distance.",
        "ar-EG",
      );
    } else {
      audio.speak(
        "$name. Rating $rating. It is $distance away.",
        "en-US",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFEB1B33);

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          _announceRestaurant(context);
          onTap();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Using a Stack to place the heart button over the image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    image,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 160,
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.broken_image,
                          size: 50,
                          color: Colors.grey,
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 160,
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: primaryRed,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // The Heart Toggle Button
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2), // Makes white icon visible on light images
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.white,
                        size: 26,
                      ),
                      onPressed: onFavoriteToggle,
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      const Icon(
                        Icons.star,
                        color: Colors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        rating,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(
                        Icons.location_on,
                        size: 18,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        distance,
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
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
}