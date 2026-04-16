import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/Models/Restaurant.dart';
import 'package:grad_project/screens/RestaurantData.dart';
import 'package:grad_project/screens/Menu.dart';
import 'package:grad_project/screens/RestaurantCard.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart'; // Ensure this is imported

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
    // Announce the screen when it opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceRestaurantsScreen();
    });
  }

  Future<void> _checkAndSeedData() async {
    try {
      await _dbService.uploadMockData(RestaurantData.restaurants);
    } catch (e) {
      debugPrint("Error seeding data: $e");
    }
  }

  // FIXED: Added voice announcement for the screen
  void _announceRestaurantsScreen() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop(); // Clear any audio from the Home/Splash screen

    if (lp.isRTL) {
      await audio.speak("قائمة المطاعم.", "ar-EG");
      await Future.delayed(const Duration(milliseconds: 300));
      await audio.speak("يمكنك الفرز حسب التقييم أو المسافة بالصوت.", "ar-EG");
    } else {
      await audio.speak("Restaurant list. You can sort by rating or distance using your voice.", "en-US");
    }
  }

  void _handleVoiceFilter(AppAudioProvider audio, LanguageProvider lp) {
    audio.toggleListening(lp.currentLanguage, (words) async {
      String command = words.toLowerCase();

      if (command.contains("rating") || command.contains("تقييم") || command.contains("الاعلى")) {
        _applyFilter('rating');
        await audio.speak(lp.isRTL ? "تم الترتيب حسب التقييم" : "Sorting by rating", lp.currentLanguage);
      }
      else if (command.contains("distance") || command.contains("مسافة") || command.contains("قريب")) {
        _applyFilter('distance');
        await audio.speak(lp.isRTL ? "تم الترتيب حسب الأقرب" : "Sorting by distance", lp.currentLanguage);
      }
      else if (command.contains("reset") || command.contains("اعادة") || command.contains("افتراضي")) {
        _applyFilter('reset');
        await audio.speak(lp.isRTL ? "تمت إعادة الضبط" : "Filters reset", lp.currentLanguage);
      }
    });
  }

  void _applyFilter(String criteria) {
    setState(() {
      _currentFilter = criteria;
    });
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);
    const primaryRed = Color(0xFFEB1B33);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back, color: Colors.black),
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
      // Updated FAB to handle listening state and color
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 70),
        child: FloatingActionButton(
          backgroundColor: audio.isListening ? Colors.green : primaryRed,
          onPressed: () => _handleVoiceFilter(audio, lp),
          child: Icon(audio.isListening ? Icons.graphic_eq : Icons.mic, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,
      body: Column(
        children: [
          const SizedBox(height: 70),
          _buildVoiceHintBar(audio, lp),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<Restaurant>>(
              stream: _dbService.getRestaurantsStream(),
              builder: (context, snapshot) {
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

  Widget _buildVoiceHintBar(AppAudioProvider audio, LanguageProvider lp) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFD6E0E0),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Icon(Icons.mic, color: audio.isListening ? Colors.green : Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                audio.isListening && audio.lastWords.isNotEmpty
                    ? audio.lastWords
                    : lp.getText('restaurants_voice_hint'),
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            )
          ],
        ),
      ),
    );
  }
}