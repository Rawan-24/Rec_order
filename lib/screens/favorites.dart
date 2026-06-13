import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/Models/FavoriteModel.dart';

import '../Models/Restaurant.dart';
import '../services/ai_service.dart';
import 'Menu.dart';
import 'RestaurantsScreen.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  bool _shouldListen = true;
  bool _isProcessing = false;
  bool _navigating   = false;

  List<FavoriteModel> _loadedFavorites = [];

  // ── Single stream subscription — never recreated ──────────────────────────
  late final Stream<List<FavoriteModel>> _favStream;

  @override
  void initState() {
    super.initState();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Cache the stream once — do NOT call getFavorites() again in build()
      _favStream = DatabaseService().getFavorites(user.uid);
      _favStream.listen((favs) {
        if (mounted) setState(() => _loadedFavorites = favs);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final audio = Provider.of<AppAudioProvider>(context, listen: false);
      final lp    = Provider.of<LanguageProvider>(context, listen: false);
      await Future.delayed(const Duration(milliseconds: 500));
      await audio.initSpeech();
      await _speakIntro(lp);
    });
  }

  @override
  void dispose() {
    _shouldListen = false;
    super.dispose();
  }

  // ── Intro ─────────────────────────────────────────────────────────────────
  Future<void> _speakIntro(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();

    await audio.speak(
      lp.isEnglish ? "Your favorite restaurants." : "مطاعمك المفضلة.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    // Use the already-loaded list — no extra Firestore call here
    await _speakFavoritesList(lp);

    await Future.delayed(const Duration(milliseconds: 300));

    await audio.speak(
      lp.isEnglish
          ? "Say a restaurant name to open it, or say go back."
          : "قل اسم المطعم لفتحه، أو قل ارجع.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    if (mounted) {
      _shouldListen = true;
      _startListening(lp);
    }
  }

  Future<void> _speakFavoritesList(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    if (_loadedFavorites.isEmpty) {
      await audio.speak(
        lp.isEnglish
            ? "You have no favorite restaurants yet."
            : "لا توجد مطاعم مفضلة حتى الآن.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
      return;
    }

    await audio.speak(
      lp.isEnglish
          ? "You have ${_loadedFavorites.length} favorite "
          "restaurant${_loadedFavorites.length == 1 ? '' : 's'}."
          : "لديك ${_loadedFavorites.length} مطاعم مفضلة.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    for (int i = 0; i < _loadedFavorites.length; i++) {
      if (!mounted) return;
      final f = _loadedFavorites[i];
      await Future.delayed(const Duration(milliseconds: 300));
      if (lp.isEnglish) {
        await audio.speak(
          "${i + 1}: ${f.name}. Rated ${f.rating} out of 5. ${f.cuisine}.",
          "en-US",
        );
      } else {
        await audio.speak("${i + 1}:", "ar-SA");
        await Future.delayed(const Duration(milliseconds: 150));
        await audio.speak(f.name, "en-US");
        await Future.delayed(const Duration(milliseconds: 150));
        await audio.speak("التقييم ${f.rating} من 5. ${f.cuisine}.", "ar-SA");
      }
    }
  }

  // ── Keyword pre-filter ────────────────────────────────────────────────────
  Map<String, String>? _quickCommandFromText(String text) {
    final t = text.toLowerCase().trim();

    if (t == "go back" || t == "back" || t == "return" ||
        t == "ارجع" || t == "رجوع") {
      return {"command": "go_back"};
    }

    for (final fav in _loadedFavorites) {
      if (t.contains(fav.name.toLowerCase())) {
        return {"command": "select_restaurant", "value": fav.name};
      }
    }

    if ((t.contains("select") || t.contains("open") || t.contains("choose")) &&
        (t.contains("restaurant") || t.contains("مطعم")) &&
        !_loadedFavorites.any((f) => t.contains(f.name.toLowerCase()))) {
      return {"command": "clarify_restaurant"};
    }

    return null;
  }

  // ── Listen loop ───────────────────────────────────────────────────────────
  void _startListening(LanguageProvider lp) async {
    if (!_shouldListen || !mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (audio.speech.isListening) return;

    await audio.toggleListening(
      lp.isEnglish ? "en" : "ar",
          (text) async {
        if (_navigating || _isProcessing || !_shouldListen) return;
        _isProcessing = true;

        debugPrint("USER SAID (Favorites): $text");

        final quick = _quickCommandFromText(text);
        Map<String, dynamic> response;

        if (quick != null) {
          response = quick;
        } else {
          response = await AIService.sendMessage(text, screen: "favorites");
        }

        await _handleCommand(response, lp);
        _isProcessing = false;
      },
      onError: (errorMsg) {
        debugPrint("STT real error (Favorites): $errorMsg");
      },
    );
  }

  // ── Command handler ───────────────────────────────────────────────────────
  Future<void> _handleCommand(
      Map<String, dynamic> response, LanguageProvider lp) async {
    if (_navigating || !mounted) return;

    final audio   = Provider.of<AppAudioProvider>(context, listen: false);
    final command = (response['command'] ?? 'unknown').toString();

    switch (command) {

      case "select_restaurant":
        final value = (response['value'] ?? '').toString().toLowerCase();
        final match = _loadedFavorites.firstWhere(
              (f) => f.name.toLowerCase().contains(value) ||
              value.contains(f.name.toLowerCase()),
          orElse: () => FavoriteModel.empty(),
        );

        if (match.id.isEmpty) {
          await audio.speak(
            lp.isEnglish
                ? "I couldn't find that restaurant in your favorites."
                : "لم أجد هذا المطعم في مفضلتك.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
          break;
        }
        await _openFavorite(match, audio, lp);
        break;

      case "clarify_restaurant":
        final names = _loadedFavorites.map((f) => f.name).join(', ');
        await audio.speak(
          lp.isEnglish
              ? "Which restaurant? Your favorites are: $names."
              : "أي مطعم؟ مفضلتك: $names.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

      case "go_back":
        _shouldListen = false;
        await audio.stop();
        if (mounted) Navigator.pop(context);
        break;

      case "open_restaurants":
        _shouldListen = false;
        await audio.speak(
          lp.isEnglish ? "Opening restaurants." : "جاري فتح المطاعم.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const RestaurantsScreen()),
          );
        }
        break;

      default:
        await audio.speak(
          lp.isEnglish
              ? "Say a restaurant name to open it, or say go back."
              : "قل اسم المطعم لفتحه، أو قل ارجع.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
    }
  }

  // ── Open favorite ─────────────────────────────────────────────────────────
  Future<void> _openFavorite(
      FavoriteModel item, AppAudioProvider audio, LanguageProvider lp) async {
    if (_navigating) return;
    _navigating   = true;
    _shouldListen = false;
    _isProcessing = true;

    await audio.stop();
    await audio.speak(
      lp.isEnglish ? "Opening ${item.name}" : "فتحت صفحة ${item.name}",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    final restaurant = Restaurant(
      id: item.id,
      name: item.name,
      image: item.image,
      rating: item.rating,
      description: item.cuisine,
      distance: item.time,
      menu: const [],
    );

    if (!mounted) { _navigating = false; return; }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => Menu(restaurant: restaurant)),
    ).then((_) {
      _navigating   = false;
      _shouldListen = true;
      _isProcessing = false;
      final lp2 = Provider.of<LanguageProvider>(context, listen: false);
      _speakIntro(lp2);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  // KEY FIX: NO Provider.of<AppAudioProvider>(context) here.
  // Only Consumer wraps the parts that actually need audio state.
  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    final user = FirebaseAuth.instance.currentUser;
    final String userId = user?.uid ?? "";
    const primaryRed = Color(0xFFEB1B33);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(lp.getText('favorites resturant'),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),

      // ── FAB: only this rebuilds when mic state changes ────────────────────
      floatingActionButton: Consumer<AppAudioProvider>(
        builder: (_, audio, __) => FloatingActionButton(
          backgroundColor: audio.isListening ? Colors.green : primaryRed,
          onPressed: () {
            if (!audio.speech.isListening && !_isProcessing) {
              _shouldListen = true;
              _startListening(lp);
            }
          },
          child: Icon(
            audio.isListening ? Icons.graphic_eq : Icons.mic,
            color: Colors.white,
          ),
        ),
      ),

      // ── Body: uses _loadedFavorites state — no StreamBuilder here ─────────
      body: userId.isEmpty
          ? Center(child: Text(lp.getText('login_to_see_favs')))
          : _loadedFavorites.isEmpty
          ? _buildEmptyState(primaryRed, lp)
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _loadedFavorites.length,
        itemBuilder: (context, index) =>
            _buildFavoriteCard(_loadedFavorites[index], primaryRed, userId, lp),
      ),
    );
  }

  Widget _buildFavoriteCard(
      FavoriteModel item, Color accent, String userId, LanguageProvider lp) {
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
          final audio = Provider.of<AppAudioProvider>(context, listen: false);
          _openFavorite(item, audio, lp);
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
                  errorBuilder: (_, __, ___) => Container(
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
                        final audio = Provider.of<AppAudioProvider>(
                            context, listen: false);
                        audio.speak(
                          lp.isEnglish
                              ? "Removed ${item.name} from favorites"
                              : "تم حذف ${item.name} من المفضلة",
                          lp.isEnglish ? "en-US" : "ar-SA",
                        );
                        DatabaseService().toggleFavorite(userId, item, true);
                      },
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(item.cuisine,
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 14)),
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

  Widget _buildEmptyState(Color accent, LanguageProvider lp) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(lp.getText('no_favorites'),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () {
              _shouldListen = false;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const RestaurantsScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: accent, foregroundColor: Colors.white),
            child: Text(lp.getText('explore_restaurants')),
          ),
        ],
      ),
    );
  }
}