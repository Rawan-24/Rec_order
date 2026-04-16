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

  const RestaurantCard({
    super.key,
    required this.name,
    required this.rating,
    required this.distance,
    required this.image,
    required this.onTap,
  });

  /// Handles the voice announcement with smart language switching
  Future<void> _announceRestaurant(BuildContext context) async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Stop any existing announcements (like from a previous card tap)
    await audio.stop();

    if (lp.isRTL) {
      // Logic: Speak the name (usually English/Global brand) then Arabic details
      // We don't await the first one if we want the second to follow immediately
      // in a specific sequence handled by the provider.
      await audio.speak(name, "en-US");
      await Future.delayed(const Duration(milliseconds: 400));
      await audio.speak("التقييم $rating. يبعد مسافة $distance.", "ar-EG");
    } else {
      await audio.speak("$name. Rating $rating. $distance away.", "en-US");
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFEB1B33);
    final lp = Provider.of<LanguageProvider>(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            // Trigger voice feedback immediately
            _announceRestaurant(context);
            // Navigate to restaurant details
            onTap();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section with Stack for Rating Badge
              Stack(
                children: [
                  Image.network(
                    image,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 170,
                      color: const Color(0xFFF4EDE4),
                      child: const Icon(Icons.restaurant, color: Colors.grey, size: 40),
                    ),
                  ),
                  // Rating Badge Overlay
                  Positioned(
                    top: 12,
                    right: lp.isRTL ? null : 12,
                    left: lp.isRTL ? 12 : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.orange, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.favorite_border, color: primaryRed, size: 24),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          "25-35 min", // Mock delivery time for realism
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        const SizedBox(width: 15),
                        Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text(
                          distance,
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}