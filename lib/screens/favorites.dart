import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/Models/FavoriteModel.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart'; // Import Provider
import 'package:provider/provider.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late LanguageProvider lp;

  @override
  void initState() {
    super.initState();
    // Greet and explain the page
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announcePage();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    lp = Provider.of<LanguageProvider>(context);
  }

  void _announcePage() {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    String msg = lp.isRTL
        ? "قائمة المطاعم المفضلة لديك. يمكنك الضغط على المطعم للطلب أو حذفه من المفضلة."
        : "Your favorite restaurants. Tap to order or remove them from your list.";
    audio.speak(msg, lp.currentLanguage);
  }

  void _handleVoiceCommand(BuildContext context, AppAudioProvider audio) {
    audio.toggleListening(lp.currentLanguage, (words) {
      String command = words.toLowerCase();
      // Example: "Remove all" or "Go back"
      if (command.contains("ارجع") || command.contains("back")) {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String userId = user?.uid ?? "";
    const primaryRed = Color(0xFFD32F2F);
    final audio = Provider.of<AppAudioProvider>(context);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(lp.getText('favorites resturant'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: userId.isEmpty
          ? Center(child: Text(lp.getText('login_to_see_favs')))
          : StreamBuilder<List<FavoriteModel>>(
        stream: DatabaseService().getFavorites(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("${lp.getText('error')}: ${snapshot.error}"));
          }

          final favorites = snapshot.data ?? [];

          if (favorites.isEmpty) {
            return _buildEmptyState(primaryRed);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              return _buildFavoriteCard(favorites[index], primaryRed, userId, audio);
            },
          );
        },
      ),
      // Voice interaction FAB
      floatingActionButton: FloatingActionButton(
        backgroundColor: audio.isListening ? Colors.green : primaryRed,
        onPressed: () => _handleVoiceCommand(context, audio),
        child: Icon(audio.isListening ? Icons.graphic_eq : Icons.mic, color: Colors.white),
      ),
    );
  }

  Widget _buildFavoriteCard(FavoriteModel item, Color accent, String userId, AppAudioProvider audio) {
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
          // Provide audio feedback for the selected restaurant
          String msg = lp.isRTL ? "فتحت صفحة ${item.name}" : "Opening ${item.name}";
          audio.speak(msg, lp.currentLanguage);
          // Navigate to Restaurant Detail
        },
        child: Column(
          children: [
            Stack(
              children: [
                Image.network(
                  item.image,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 160,
                    color: Colors.grey[200],
                    child: const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                      icon: const Icon(Icons.favorite, color: Colors.red),
                      onPressed: () {
                        String removeMsg = lp.isRTL
                            ? "تم حذف ${item.name} من المفضلة"
                            : "Removed ${item.name} from favorites";
                        audio.speak(removeMsg, lp.currentLanguage);
                        DatabaseService().toggleFavorite(userId, item, true);
                      },
                    ),
                  ),
                ),
                // ... rating tag stays the same
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(item.cuisine,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                    ],
                  ),
                  // ... time icon stays same
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
          Text(lp.getText('no_favorites'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
            ),
            child:  Text(lp.getText('explore_restaurants')),
          ),
        ],
      ),
    );
  }
}