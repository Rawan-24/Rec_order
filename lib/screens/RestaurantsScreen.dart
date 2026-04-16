import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/Models/Restaurant.dart';
import 'package:grad_project/screens/RestaurantData.dart';
import 'package:grad_project/screens/Menu.dart';
import 'package:grad_project/screens/RestaurantCard.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';

class RestaurantsScreen extends StatefulWidget {
  static const String routeName = "RestaurantsScreen";
  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  final DatabaseService _dbService = DatabaseService();
  String _currentFilter = 'reset';
  final Color primaryRed = const Color(0xFFEB1B33);

  @override
  void initState() {
    super.initState();
    _checkAndSeedData();
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

  void _announceRestaurantsScreen() async {
    final lp = Provider.of<LanguageProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    await audio.stop();

    String msg = lp.isRTL
        ? "قائمة المطاعم. يمكنك الترتيب حسب التقييم أو المسافة بالصوت."
        : "Restaurant list. You can sort by rating or distance using your voice.";
    audio.speak(msg, lp.currentLanguage);
  }

  void _handleVoiceFilter(AppAudioProvider audio, LanguageProvider lp) {
    audio.toggleListening(lp.currentLanguage, (words) async {
      String command = words.toLowerCase();

      if (command.contains("rating") || command.contains("تقييم") || command.contains("أعلى")) {
        setState(() => _currentFilter = 'rating');
        audio.speak(lp.isRTL ? "تم الترتيب حسب التقييم" : "Sorting by highest rating", lp.currentLanguage);
      }
      else if (command.contains("distance") || command.contains("مسافة") || command.contains("قريب")) {
        setState(() => _currentFilter = 'distance');
        audio.speak(lp.isRTL ? "تم الترتيب حسب الأقرب" : "Sorting by distance", lp.currentLanguage);
      }
      else if (command.contains("reset") || command.contains("افتراضي") || command.contains("كل")) {
        setState(() => _currentFilter = 'reset');
        audio.speak(lp.isRTL ? "تمت إعادة الضبط" : "Filters reset to default", lp.currentLanguage);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final audio = Provider.of<AppAudioProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          lp.getText('restaurants_title'),
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort_rounded, color: Colors.black),
            onSelected: (val) => setState(() => _currentFilter = val),
            itemBuilder: (context) => [
              PopupMenuItem(value: 'rating', child: Text(lp.getText('filter_rating'))),
              PopupMenuItem(value: 'distance', child: Text(lp.getText('filter_distance'))),
              PopupMenuItem(value: 'reset', child: Text(lp.getText('filter_reset'))),
            ],
          ),
        ],
      ),
      // The "Voice Command" Button is now central to the UI
      floatingActionButton: FloatingActionButton(
        backgroundColor: audio.isListening ? Colors.green : primaryRed,
        onPressed: () => _handleVoiceFilter(audio, lp),
        child: Icon(audio.isListening ? Icons.graphic_eq : Icons.mic, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Column(
        children: [
          _buildActiveFilterIndicator(lp),
          _buildVoiceHintBar(audio, lp),
          Expanded(
            child: StreamBuilder<List<Restaurant>>(
              stream: _dbService.getRestaurantsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFFEB1B33)));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text(lp.isRTL ? "لا توجد مطاعم" : "No restaurants found"));
                }

                List<Restaurant> restaurants = List.from(snapshot.data!);

                // Refined Sorting Logic
                if (_currentFilter == 'rating') {
                  restaurants.sort((a, b) => (double.tryParse(b.rating) ?? 0).compareTo(double.tryParse(a.rating) ?? 0));
                } else if (_currentFilter == 'distance') {
                  restaurants.sort((a, b) {
                    double distA = double.tryParse(a.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
                    double distB = double.tryParse(b.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0.0;
                    return distA.compareTo(distB);
                  });
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 80), // Added bottom padding for FAB
                  itemCount: restaurants.length,
                  itemBuilder: (context, index) {
                    return RestaurantCard(
                      name: restaurants[index].name,
                      rating: restaurants[index].rating,
                      distance: restaurants[index].distance,
                      image: restaurants[index].image,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Menu(restaurant: restaurants[index])),
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

  Widget _buildActiveFilterIndicator(LanguageProvider lp) {
    if (_currentFilter == 'reset') return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.auto_awesome, size: 14, color: primaryRed),
          const SizedBox(width: 8),
          Text(
            _currentFilter == 'rating' ? lp.getText('filter_rating') : lp.getText('filter_distance'),
            style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _currentFilter = 'reset'),
            child: const Icon(Icons.close, size: 16, color: Colors.grey),
          )
        ],
      ),
    );
  }

  Widget _buildVoiceHintBar(AppAudioProvider audio, LanguageProvider lp) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: audio.isListening ? Colors.green.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: audio.isListening ? Colors.green : Colors.black12),
        ),
        child: Row(
          children: [
            Icon(Icons.tips_and_updates_rounded, color: audio.isListening ? Colors.green : Colors.teal, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                audio.isListening && audio.lastWords.isNotEmpty
                    ? audio.lastWords
                    : (lp.isRTL ? "جرب قول: 'رتب حسب التقييم'" : "Try: 'Sort by rating'"),
                style: TextStyle(
                    color: audio.isListening ? Colors.black87 : Colors.black54,
                    fontSize: 13,
                    fontStyle: audio.isListening ? FontStyle.italic : FontStyle.normal
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}