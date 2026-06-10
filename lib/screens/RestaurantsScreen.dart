import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/Models/Restaurant.dart';
import 'package:grad_project/screens/Menu.dart';
import 'package:grad_project/screens/RestaurantCard.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';

import '../Models/FavoriteModel.dart';
import '../services/ai_service.dart';

class RestaurantsScreen extends StatefulWidget {
  static const String routeName = "RestaurantsScreen";
  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  final DatabaseService _dbService = DatabaseService();
  String _currentFilter = 'reset';
  List<Restaurant> _loadedRestaurants = [];
  List<FavoriteModel> _currentFavorites = [];

  bool _shouldListen = true;
  bool _isProcessing = false;

  // ── FIX 1: Cache streams so StreamBuilder never sees a new stream on rebuild ──
  late final Stream<List<Restaurant>> _restaurantsStream;
  late final Stream<List<FavoriteModel>> _favoritesStream;

  @override
  void initState() {
    super.initState();

    // Initialise streams ONCE here, not inside build()
    _restaurantsStream = _dbService.getRestaurantsStream();

    final user = FirebaseAuth.instance.currentUser;
    _favoritesStream = _dbService.getFavorites(user?.uid ?? "");

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkAndSeedData();
      if (!mounted) return;
      final audio = Provider.of<AppAudioProvider>(context, listen: false);
      final lp = Provider.of<LanguageProvider>(context, listen: false);

      await audio.initSpeech();
      await _speakIntro(lp);
    });
  }

  @override
  void dispose() {
    _shouldListen = false;
    super.dispose();
  }

  Future<void> _checkAndSeedData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      await _dbService.seedRestaurantData();
    } catch (e) {
      debugPrint("Seed error: $e");
    }
  }

  Future<void> _speakIntro(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();

    await audio.speak(
      lp.isEnglish ? "Restaurants screen." : "شاشة المطاعم.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );


    await _speakRestaurantList(lp);


    await audio.speak(
      lp.isEnglish
          ? "Say a restaurant name to open it. "
          "Say add [name] to favorites to mark it. "
          "Say sort by rating, sort by distance, or go back."
          : "قل اسم المطعم لفتحه. قل أضف [اسم] إلى المفضلة. "
          "قل رتب حسب التقييم، رتب حسب المسافة، أو ارجع.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    if (mounted) {
      _shouldListen = true;
      _startListening(lp);
    }
  }

  Future<void> _speakRestaurantList(LanguageProvider lp) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    if (_loadedRestaurants.isEmpty) {
      await audio.speak(
        lp.isEnglish ? "No restaurants available." : "لا توجد مطاعم متاحة.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
      return;
    }

    await audio.speak(
      lp.isEnglish
          ? "${_loadedRestaurants.length} restaurants available."
          : "${_loadedRestaurants.length} مطاعم متاحة.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    for (int i = 0; i < _loadedRestaurants.length; i++) {
      if (!mounted) return;
      final r = _loadedRestaurants[i];

      if (lp.isEnglish) {
        await audio.speak(
          "Restaurant ${i + 1}: ${r.name}. "
              "Rated ${r.rating} out of 5. "
              "${r.distance} away. "
              "${r.description}.",
          "en-US",
        );
      } else {
        await audio.speak("المطعم ${i + 1}:", "ar-SA");

        await audio.speak(r.name, "en-US");

        await audio.speak(
          "التقييم ${r.rating} من 5. يبعد ${r.distance}. ${r.description}.",
          "ar-SA",
        );
      }
    }
  }

  Map<String, dynamic>? _tryParseLocally(String text) {
    final lower = text.toLowerCase().trim();

    final bool isFavIntent =
        (lower.contains('add') &&
            (lower.contains('favorit') || lower.contains('favourit'))) ||
            (lower.contains('أضف') && lower.contains('مفضلة')) ||
            (lower.contains('إضافة') && lower.contains('مفضلة'));

    if (isFavIntent) {
      for (final r in _loadedRestaurants) {
        if (lower.contains(r.name.toLowerCase())) {
          return {'command': 'add_to_favorites', 'value': r.name};
        }
      }
      return {'command': 'add_to_favorites', 'value': ''};
    }

    if (lower.contains('go back') ||
        lower == 'ارجع' ||
        lower.contains('ارجع') ||
        lower.contains('رجوع')) {
      return {'command': 'go_back'};
    }

    return null;
  }

  void _startListening(LanguageProvider lp) async {
    if (!_shouldListen || !mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (audio.speech.isListening) return;

    await audio.toggleListening(
      lp.isEnglish ? "en" : "ar",
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;

        debugPrint("USER SAID (Restaurants): $text");

        final local = _tryParseLocally(text);
        final Map<String, dynamic> response;
        if (local != null) {
          debugPrint("LOCAL MATCH (Restaurants): $local");
          response = local;
        } else {
          response = await AIService.sendMessage(text);
        }

        final command = (response['command'] ?? "unknown").toString();
        debugPrint("FINAL COMMAND (Restaurants): $command");
        await _handleCommand(command, response, lp);

        _isProcessing = false;

      },
      onError: (errorMsg) {
        // AudioProvider handles error_no_match automatically.
        // Only restart here for genuine errors.
        debugPrint("STT real error on screen: $errorMsg");
      },
    );
  }

  Future<void> _handleCommand(
      String command,
      Map<String, dynamic> response,
      LanguageProvider lp,
      ) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    switch (command) {
      case "add_to_favorites":
        final restaurantName = (response['value'] ?? "").toString().trim();

        if (restaurantName.isEmpty) {
          await audio.speak(
            lp.isEnglish
                ? "Which restaurant would you like to add to favorites? "
                "Available: ${_loadedRestaurants.map((r) => r.name).join(', ')}."
                : "أي مطعم تريد إضافته إلى المفضلة؟ "
                "المتاحة: ${_loadedRestaurants.map((r) => r.name).join('، ')}.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
          break;
        }

        final matchFav = _loadedRestaurants
            .where((r) =>
            r.name.toLowerCase().contains(restaurantName.toLowerCase()))
            .toList();

        if (matchFav.isNotEmpty) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            final restaurant = matchFav.first;
            final alreadyFav = _currentFavorites.any(
                  (f) => f.name.toLowerCase() == restaurant.name.toLowerCase(),
            );

            if (alreadyFav) {
              await audio.speak(
                lp.isEnglish
                    ? "${restaurant.name} is already in your favorites."
                    : "${restaurant.name} موجود بالفعل في المفضلة.",
                lp.isEnglish ? "en-US" : "ar-SA",
              );
            } else {
              final favModel = FavoriteModel(
                id: restaurant.id ?? restaurant.name,
                name: restaurant.name,
                image: restaurant.image,
                cuisine: restaurant.description,
                rating: restaurant.rating,
                time: restaurant.distance,
              );
              await _dbService.toggleFavorite(user.uid, favModel, false);
              await audio.speak(
                lp.isEnglish
                    ? "Added ${restaurant.name} to favorites."
                    : "تمت إضافة ${restaurant.name} إلى المفضلة.",
                lp.isEnglish ? "en-US" : "ar-SA",
              );
            }
          }
        } else {
          await audio.speak(
            lp.isEnglish
                ? "Restaurant not found. Say a name from the list."
                : "المطعم غير موجود. قل اسماً من القائمة.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        }
        break;

      case "filter_by_rating":
        setState(() => _currentFilter = 'rating');
        await audio.speak(
          lp.isEnglish
              ? "Sorted by rating. Highest rated first."
              : "تم الترتيب حسب التقييم.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        await _speakRestaurantList(lp);
        break;

      case "filter_by_distance":
        setState(() => _currentFilter = 'distance');
        await audio.speak(
          lp.isEnglish ? "Sorted by distance. Nearest first." : "تم الترتيب حسب المسافة.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        await _speakRestaurantList(lp);
        break;

      case "reset_filter":
        setState(() => _currentFilter = 'reset');
        await audio.speak(
          lp.isEnglish
              ? "Filter cleared. Showing all restaurants."
              : "تمت إعادة الضبط.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        await _speakRestaurantList(lp);
        break;

      case "read_commands":
        await audio.speak(
          lp.isEnglish
              ? "Commands: say a restaurant name to open it. "
              "Add [name] to favorites. "
              "Sort by rating. Sort by distance. Reset. Go back."
              : "الأوامر: قل اسم المطعم. أضف [اسم] إلى المفضلة. "
              "رتب حسب التقييم. رتب حسب المسافة. إعادة الضبط. ارجع.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

      case "select_restaurant":
        final restaurantName = (response['value'] ?? "").toString().trim();
        if (restaurantName.isEmpty) {
          await audio.speak(
            lp.isEnglish ? "Which restaurant would you like?" : "أي مطعم تريد؟",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
          break;
        }

        // ✅ Use findRestaurant with normalization + contains both ways
        final match = _findRestaurant(_loadedRestaurants, restaurantName);

        if (match != null && mounted) {
          _shouldListen = false;
          await audio.speak(
            lp.isEnglish ? "Opening ${match.name}." : "جاري فتح ${match.name}.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => Menu(restaurant: match)),
          ).then((_) {
            if (!mounted) return;
            _shouldListen = true;
            _isProcessing = false;

          });
        } else {
          await audio.speak(
            lp.isEnglish
                ? "Restaurant not found. Available: ${_loadedRestaurants.map((r) => r.name).join(', ')}."
                : "المطعم غير موجود. المتاحة: ${_loadedRestaurants.map((r) => r.name).join('، ')}.",
            lp.isEnglish ? "en-US" : "ar-SA",
          );
        }
        break;

      case "prompt_restaurant_name":
        await audio.speak(
          lp.isEnglish
              ? "Which restaurant? Available: ${_loadedRestaurants.map((r) => r.name).join(', ')}."
              : "أي مطعم؟ المتاحة: ${_loadedRestaurants.map((r) => r.name).join('، ')}.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        break;

      case "go_back":
        _shouldListen = false;
        await audio.speak(
          lp.isEnglish ? "Going back." : "جاري الرجوع.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
        if (mounted) Navigator.pop(context);
        break;

      default:
        await audio.speak(
          lp.isEnglish
              ? "Say a restaurant name, add to favorites, sort by rating, "
              "sort by distance, or go back."
              : "قل اسم مطعم، أضف إلى المفضلة، رتب حسب التقييم، "
              "رتب حسب المسافة، أو ارجع.",
          lp.isEnglish ? "en-US" : "ar-SA",
        );
    }
  }

  void _applyFilter(String criteria) => setState(() => _currentFilter = criteria);

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
          icon: Icon(
              lp.isRTL ? Icons.arrow_forward : Icons.arrow_back,
              color: Colors.black),
          onPressed: () async {
            _shouldListen = false;
            await audio.speak(
              lp.isEnglish ? "Going back." : "جاري الرجوع.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            if (mounted) Navigator.pop(context);
          },
        ),
        title: Text(
          lp.getText('restaurants_title'),
          style: const TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_alt, color: Colors.black),
            onSelected: _applyFilter,
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 'rating',
                  child: Text(lp.getText('filter_rating'))),
              PopupMenuItem(
                  value: 'distance',
                  child: Text(lp.getText('filter_distance'))),
              PopupMenuItem(
                  value: 'reset',
                  child: Text(lp.getText('filter_reset'))),
            ],
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(top: 70),
        child: FloatingActionButton(
          backgroundColor: audio.isListening ? Colors.green : primaryRed,
          onPressed: () {
            if (!audio.speech.isListening && !_isProcessing) {
              _shouldListen = true;
              _startListening(
                  Provider.of<LanguageProvider>(context, listen: false));
            }
          },
          child: Icon(
            audio.isListening ? Icons.graphic_eq : Icons.mic,
            color: Colors.white,
          ),
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
              // ── FIX 1: Use the cached stream field, not a new call ──
              stream: _restaurantsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  // ── FIX 2: Only show spinner on the very first load,
                  //    not on every rebuild ──
                  return const Center(
                      child: CircularProgressIndicator(color: primaryRed));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.wifi_off,
                            size: 52, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          lp.isEnglish
                              ? "Could not load restaurants."
                              : "تعذّر تحميل المطاعم.",
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh),
                          label: Text(lp.isEnglish
                              ? "Retry"
                              : "إعادة المحاولة"),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: primaryRed),
                        ),
                      ],
                    ),
                  );
                }

                final seen = <String>{};
                final restaurants = (snapshot.data ?? [])
                    .where((r) => seen.add(r.id ?? r.name))
                    .toList();

                // Safe to assign here since StreamBuilder's builder is
                // called in the build phase; no setState needed.
                _loadedRestaurants = List.from(restaurants);

                if (restaurants.isEmpty) {
                  return Center(
                    child: Text(
                      lp.isEnglish
                          ? "No restaurants found."
                          : "لا توجد مطاعم.",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                List<Restaurant> sorted = List.from(restaurants);
                if (_currentFilter == 'rating') {
                  sorted.sort((a, b) =>
                      (double.tryParse(b.rating) ?? 0)
                          .compareTo(double.tryParse(a.rating) ?? 0));
                } else if (_currentFilter == 'distance') {
                  sorted.sort((a, b) {
                    double dA = double.tryParse(
                        a.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                        0;
                    double dB = double.tryParse(
                        b.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                        0;
                    return dA.compareTo(dB);
                  });
                }

                final User? user = FirebaseAuth.instance.currentUser;

                // ── FIX 3: Single StreamBuilder for favorites OUTSIDE
                //    the list, not one per card ──
                return StreamBuilder<List<FavoriteModel>>(
                  stream: _favoritesStream, // cached stream
                  builder: (context, favSnapshot) {
                    // ── FIX 4: Update _currentFavorites WITHOUT setState ──
                    // StreamBuilder already triggers a rebuild when data
                    // arrives, so we just read the value directly.
                    final favs = favSnapshot.data ?? [];
                    _currentFavorites = favs;

                    return ListView.builder(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final restaurant = sorted[index];
                        bool isFav =
                        favs.any((f) => f.name == restaurant.name);

                        return RestaurantCard(
                          name: restaurant.name,
                          rating: restaurant.rating,
                          distance: restaurant.distance,
                          image: restaurant.image,
                          isFavorite: isFav,
                          onFavoriteToggle: () async {
                            if (user != null) {
                              _dbService.toggleFavorite(
                                user.uid,
                                FavoriteModel(
                                  id: restaurant.id ?? restaurant.name,
                                  name: restaurant.name,
                                  image: restaurant.image,
                                  cuisine: restaurant.description,
                                  rating: restaurant.rating,
                                  time: restaurant.distance,
                                ),
                                isFav,
                              );
                              await audio.speak(
                                isFav
                                    ? (lp.isEnglish
                                    ? "Removed ${restaurant.name} from favorites."
                                    : "تم حذف ${restaurant.name} من المفضلة.")
                                    : (lp.isEnglish
                                    ? "Added ${restaurant.name} to favorites."
                                    : "تمت إضافة ${restaurant.name} إلى المفضلة."),
                                lp.isEnglish ? "en-US" : "ar-SA",
                              );
                            }
                          },
                          onTap: () async {
                            _shouldListen = false;
                            await audio.speak(
                              lp.isEnglish
                                  ? "Opening ${restaurant.name}. ${restaurant.description}."
                                  : "جاري فتح ${restaurant.name}.",
                              lp.isEnglish ? "en-US" : "ar-SA",
                            );
                            if (mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        Menu(restaurant: restaurant)),
                              ).then((_) {
                                if (!mounted) return;
                                _shouldListen = true;
                                _isProcessing = false;

                              });
                            }
                          },
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
  Restaurant? _findRestaurant(List<Restaurant> restaurants, String value) {
    final normalizedValue = _normalize(value);
    final translitValue = _transliterate(normalizedValue);

    for (final r in restaurants) {
      final normalizedName = _normalize(r.name);
      final translitName = _transliterate(normalizedName);

      // 1. Exact match (all combinations)
      if (normalizedName == normalizedValue) return r;
      if (translitName == translitValue) return r;
      if (normalizedName == translitValue) return r;
      if (translitName == normalizedValue) return r;

      // 2. Full phrase contains the restaurant name
      //    Handles: "عايزه اطلب من باستا هاوس" → contains "pasta house"
      if (normalizedValue.contains(normalizedName)) return r;
      if (normalizedValue.contains(translitName)) return r;
      if (translitValue.contains(normalizedName)) return r;
      if (translitValue.contains(translitName)) return r;

      // 3. Partial input — name contains what user said
      if (normalizedName.contains(normalizedValue)) return r;
      if (translitName.contains(translitValue)) return r;
    }

    return null;
  }

  String _normalize(String text) {
    return text
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
  }

  String _transliterate(String text) {
    // ⚠️ CRITICAL: Full phrases MUST come before individual words
    // to prevent 'بار' matching inside 'سالاد بار' early
    return text
    // ── Full restaurant names first ──
        .replaceAll('فريش سالاد بار', 'fresh salad bar')
        .replaceAll('بيتزا بارادايس', 'pizza paradise')
        .replaceAll('بيتزا باراديس', 'pizza paradise')
        .replaceAll('باستا هاوس', 'pasta house')
    // ── Individual words after ──
        .replaceAll('بيتزا', 'pizza')
        .replaceAll('باستا', 'pasta')
        .replaceAll('بارادايس', 'paradise')
        .replaceAll('باراديس', 'paradise')
        .replaceAll('فريش', 'fresh')
        .replaceAll('سالاد', 'salad')
        .replaceAll('هاوس', 'house')
        .replaceAll('بار', 'bar')       // ← short word, must come LAST
        .replaceAll('كافيه', 'cafe')
        .replaceAll('كافيتيريا', 'cafeteria')
        .replaceAll('برجر', 'burger')
        .replaceAll('شيك', 'shake')
        .replaceAll('جريل', 'grill')
        .replaceAll('كيتشن', 'kitchen')
        .replaceAll('هوت', 'hot')
        .replaceAll('دوج', 'dog');
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
            Icon(
              audio.isListening ? Icons.graphic_eq : Icons.mic,
              color: audio.isListening ? Colors.green : Colors.teal,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                audio.isListening
                    ? (audio.lastWords.isEmpty
                    ? (lp.isEnglish ? "Listening..." : "أنا أسمعك...")
                    : audio.lastWords)
                    : lp.getText('restaurants_voice_hint'),
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}