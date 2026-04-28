import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/Models/MenuItemModel.dart';
import 'package:grad_project/Models/Restaurant.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/screens/MenuItem.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/services/ai_service.dart';
class Menu extends StatefulWidget {
  static const String routeName = "Menu";
  final Restaurant restaurant;
  const Menu({super.key, required this.restaurant});

  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  late LanguageProvider lp;
  final DatabaseService _dbService = DatabaseService();
  final List<String> categories = ["All", "Pizza", "Pasta", "Salads", "Drinks"];

  List<MenuItemModel> fullMenu = [];
  List<MenuItemModel> displayedMenu = [];
  String selectedCategory = "All";
  String searchQuery = "";
  bool isLoading = true;

  bool _shouldListen = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadMenu();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    lp = Provider.of<LanguageProvider>(context);
  }

  @override
  void dispose() {
    _shouldListen = false;
    super.dispose();
  }

  Future<void> _loadMenu() async {
    debugPrint("Fetching menu for Restaurant ID: ${widget.restaurant.id}");
    if (widget.restaurant.id == null || widget.restaurant.id!.isEmpty) {
      if (mounted) setState(() => isLoading = false);
      return;
    }
    try {
      List<MenuItemModel> items =
      await _dbService.getRestaurantMenu(widget.restaurant.id!);
      if (mounted) {
        setState(() {
          fullMenu = items;
          displayedMenu = items;
          isLoading = false;
        });
        await _announceMenuScreen();
      }
    } catch (e) {
      debugPrint("Error loading menu: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ─────────────────────────────────────────
  // ANNOUNCE FULL MENU SCREEN TO BLIND USER
  // ─────────────────────────────────────────
  Future<void> _announceMenuScreen() async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop();

    // 1. Welcome + restaurant name
    if (lp.isEnglish) {
      await audio.speak(
        "Welcome to ${widget.restaurant.name}. ${widget.restaurant.description}.",
        "en-US",
      );
    } else {
      await audio.speak("أهلاً بك في", "ar-SA");
      await Future.delayed(const Duration(milliseconds: 200));
      await audio.speak(widget.restaurant.name, "en-US");
      await Future.delayed(const Duration(milliseconds: 200));
      await audio.speak(widget.restaurant.description, "ar-SA");
    }

    await Future.delayed(const Duration(milliseconds: 400));

    // 2. Menu count
    await audio.speak(
      lp.isEnglish
          ? "${fullMenu.length} items on the menu."
          : "${fullMenu.length} عناصر في القائمة.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    await Future.delayed(const Duration(milliseconds: 300));

    // 3. Read all menu items
    await _speakMenuItems(displayedMenu);

    await Future.delayed(const Duration(milliseconds: 400));

    // 4. Instructions
    await audio.speak(
      lp.isEnglish
          ? "Say an item name to select it. Say a category like pizza, pasta, salads, or drinks to filter. Say go back to return."
          : "قل اسم العنصر لتحديده. قل تصنيف مثل بيتزا أو باستا أو سلطات أو مشروبات للفلترة. قل ارجع للعودة.",
      lp.isEnglish ? "en-US" : "ar-SA",
    );

    // 5. Start listening loop
    if (mounted) {
      _shouldListen = true;
      _startListening();
    }
  }

  // ─────────────────────────────────────────
  // READ MENU ITEMS LIST ALOUD
  // ─────────────────────────────────────────
  Future<void> _speakMenuItems(List<MenuItemModel> items) async {
    if (!mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    if (items.isEmpty) {
      await audio.speak(
        lp.isEnglish ? "No items found." : "لا توجد عناصر.",
        lp.isEnglish ? "en-US" : "ar-SA",
      );
      return;
    }

    for (int i = 0; i < items.length; i++) {
      if (!mounted) return;
      final item = items[i];
      await Future.delayed(const Duration(milliseconds: 250));

      if (lp.isEnglish) {
        await audio.speak(
          "Item ${i + 1}: ${item.name}. "
              "${item.description}. "
              "Price: ${item.price.toStringAsFixed(2)} Egyptian pounds. "
              "Category: ${item.category}.",
          "en-US",
        );
      } else {
        await audio.speak("العنصر ${i + 1}:", "ar-SA");
        await Future.delayed(const Duration(milliseconds: 150));
        await audio.speak(item.name, "en-US");
        await Future.delayed(const Duration(milliseconds: 150));
        await audio.speak(
          "${item.description}. السعر: ${item.price.toStringAsFixed(2)} جنيه مصري. التصنيف: ${item.category}.",
          "ar-SA",
        );
      }
    }
  }

  // ─────────────────────────────────────────
  // PERSISTENT LISTEN LOOP
  // ─────────────────────────────────────────
  void _startListening() async {
    if (!_shouldListen || !mounted) return;
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (audio.speech.isListening) return;

    await audio.toggleListening(
      lp.currentLanguage,
          (text) async {
        if (_isProcessing || !_shouldListen) return;
        _isProcessing = true;
        debugPrint("USER SAID (Menu): $text");

        // ── Route through Rasa NLU ──────────────────────────────
        final aiResponse = await AIService.sendMessage(text);
        final command = (aiResponse["command"] ?? "unknown").toString();
        final value   = (aiResponse["value"]   ?? "").toString().trim();
        debugPrint("RASA COMMAND (Menu): $command | VALUE: $value");

        // ── Handle commands ─────────────────────────────────────
        switch (command) {

        // Select a named menu item
          case "select_menu_item":
            final match = _findMenuItem(fullMenu, value.isNotEmpty ? value : text);

            if (match != null) {
              _shouldListen = false;
              await audio.speak(
                lp.isEnglish
                    ? "Opening ${match.name}."
                    : "جاري فتح ${match.name}.",
                lp.isEnglish ? "en-US" : "ar-SA",
              );
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MenuItem(
                      item: match,
                      restaurantName: widget.restaurant.name,
                    ),
                  ),
                ).then((_) {
                  _shouldListen = true;
                  _isProcessing = false;
                  _announceMenuScreen();
                });
              }
              return;
            } else {
              await audio.speak(
                lp.isEnglish
                    ? "Sorry, I couldn't find that item in this menu."
                    : "عذراً، لم أجد هذا العنصر في القائمة.",
                lp.isEnglish ? "en-US" : "ar-SA",
              );
            }
            break;
        // Category filters
          case "filter_category":
            final cat = value.isNotEmpty ? value : "All";
            setState(() {
              selectedCategory = cat;
              _filterMenu();
            });
            await audio.speak(
              lp.isEnglish
                  ? "Showing $cat."
                  : "عرض ${_translateCategory(cat)}.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            await _speakMenuItems(displayedMenu);
            break;

        // Search menu
          case "search_menu":
            setState(() {
              searchQuery = value;
              _filterMenu();
            });
            await audio.speak(
              lp.isEnglish
                  ? "Searching for $value. ${displayedMenu.length} results."
                  : "البحث عن $value. ${displayedMenu.length} نتائج.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            await _speakMenuItems(displayedMenu);
            break;

        // Go back
          case "go_back":
            _shouldListen = false;
            await audio.speak(
              lp.isEnglish ? "Going back." : "جاري الرجوع.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
            await audio.stop();
            if (mounted) Navigator.pop(context);
            return;

          default:
            await audio.speak(
              lp.isEnglish
                  ? "Say an item name, a category, or go back."
                  : "قل اسم عنصر أو تصنيف أو ارجع.",
              lp.isEnglish ? "en-US" : "ar-SA",
            );
        }

        _isProcessing = false;
        Future.delayed(const Duration(milliseconds: 600), () {
          if (_shouldListen && mounted) _startListening();
        });
      },
      onError: (_) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_shouldListen && mounted && !_isProcessing) _startListening();
        });
      },
    );
  }
  String _translateCategory(String cat) {
    switch (cat) {
      case "Pizza":
        return "بيتزا";
      case "Pasta":
        return "باستا";
      case "Salads":
        return "سلطات";
      case "Drinks":
        return "مشروبات";
      default:
        return "الكل";
    }
  }

  void _filterMenu() {
    setState(() {
      displayedMenu = fullMenu.where((item) {
        final matchesCategory =
            selectedCategory == "All" || item.category == selectedCategory;
        final matchesSearch =
        item.name.toLowerCase().contains(searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }
  MenuItemModel? _findMenuItem(List<MenuItemModel> items, String value) {
    final normalizedValue = _normalize(value);
    final translitValue = _transliterateMenuItem(normalizedValue);

    for (final item in items) {
      final normalizedName = _normalize(item.name);
      final translitName = _transliterateMenuItem(normalizedName);

      // 1. Exact match (all combinations)
      if (normalizedName == normalizedValue) return item;
      if (translitName == translitValue) return item;
      if (normalizedName == translitValue) return item;
      if (translitName == normalizedValue) return item;

      // 2. Full phrase contains the item name
      //    Handles: "عايزه اطلب باستا كاربونارا" → contains "pasta carbonara"
      if (normalizedValue.contains(normalizedName)) return item;
      if (normalizedValue.contains(translitName)) return item;
      if (translitValue.contains(normalizedName)) return item;
      if (translitValue.contains(translitName)) return item;

      // 3. Partial — item name contains what user said
      if (normalizedName.contains(normalizedValue)) return item;
      if (translitName.contains(translitValue)) return item;
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

  String _transliterateMenuItem(String text) {
    // ⚠️ Full phrases MUST come before individual words
    return text
    // ── Full item names first ──
        .replaceAll('باستا كاربونارا', 'pasta carbonara')
        .replaceAll('باستا الفريدو', 'pasta alfredo')
        .replaceAll('بيبروني بيتزا', 'pepperoni pizza')
        .replaceAll('مارغريتا بيتزا', 'margherita pizza')
        .replaceAll('سلطه يونانيه', 'greek salad')
        .replaceAll('سلطة يونانية', 'greek salad')
        .replaceAll('سلطه سيزر', 'caesar salad')
        .replaceAll('سلطة سيزر', 'caesar salad')
    // ── Individual words after ──
        .replaceAll('باستا', 'pasta')
        .replaceAll('بيتزا', 'pizza')
        .replaceAll('بيبروني', 'pepperoni')
        .replaceAll('مارغريتا', 'margherita')
        .replaceAll('كاربونارا', 'carbonara')
        .replaceAll('الفريدو', 'alfredo')
        .replaceAll('سلطه', 'salad')
        .replaceAll('سلطة', 'salad')
        .replaceAll('يونانيه', 'greek')
        .replaceAll('يونانية', 'greek')
        .replaceAll('سيزر', 'caesar');
  }
  @override
  Widget build(BuildContext context) {
    final audio = Provider.of<AppAudioProvider>(context);
    const primaryRed = Color(0xFFEB1B33);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      body: ListView(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Image.network(
                widget.restaurant.image,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 220,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image,
                      size: 60, color: Colors.grey),
                ),
              ),
              Positioned(
                top: 40,
                left: lp.isRTL ? null : 10,
                right: lp.isRTL ? 10 : null,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: Icon(
                        lp.isRTL ? Icons.arrow_forward : Icons.arrow_back),
                    onPressed: () async {
                      _shouldListen = false;
                      await audio.stop();
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: MediaQuery.of(context).size.width / 2 - 30,
                child: FloatingActionButton(
                  backgroundColor:
                  audio.isListening ? Colors.green : primaryRed,
                  onPressed: () {
                    if (!audio.speech.isListening && !_isProcessing) {
                      _shouldListen = true;
                      _startListening();
                    }
                  },
                  child: Icon(
                      audio.isListening ? Icons.graphic_eq : Icons.mic,
                      color: Colors.white),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.restaurant.name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.restaurant.description,
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildVoiceHint(audio),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (value) {
                searchQuery = value;
                _filterMenu();
              },
              decoration: InputDecoration(
                hintText: lp.getText('search_menu'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ),

          const SizedBox(height: 20),
          _buildCategorySlider(primaryRed),
          const SizedBox(height: 16),

          if (isLoading)
            const Center(child: CircularProgressIndicator(color: primaryRed))
          else if (displayedMenu.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.no_food, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    Text(lp.getText('no_items_found'),
                        style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayedMenu.length,
              itemBuilder: (context, index) =>
                  _buildMenuCard(displayedMenu[index], audio),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCategorySlider(Color primaryRed) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((category) {
          bool isSelected = selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ElevatedButton(
              onPressed: () async {
                setState(() {
                  selectedCategory = category;
                  _filterMenu();
                });
                final audio =
                Provider.of<AppAudioProvider>(context, listen: false);
                await audio.speak(
                  lp.isEnglish
                      ? "Showing $category."
                      : "عرض ${_translateCategory(category)}.",
                  lp.isEnglish ? "en-US" : "ar-SA",
                );
                await _speakMenuItems(displayedMenu);
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                backgroundColor: isSelected ? primaryRed : Colors.white,
                foregroundColor: isSelected ? Colors.white : Colors.black,
              ),
              child: Text(category),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuCard(MenuItemModel item, AppAudioProvider audio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: () async {
          _shouldListen = false;
          await audio.stop();
          if (lp.isEnglish) {
            await audio.speak(
              "Selected ${item.name}. ${item.description}. Price: ${item.price.toStringAsFixed(2)} Egyptian pounds.",
              "en-US",
            );
          } else {
            await audio.speak("اخترت", "ar-SA");
            await Future.delayed(const Duration(milliseconds: 150));
            await audio.speak(item.name, "en-US");
            await Future.delayed(const Duration(milliseconds: 150));
            await audio.speak(
                "${item.description}. السعر: ${item.price.toStringAsFixed(2)} جنيه مصري.",
                "ar-SA");
          }
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MenuItem(
                    item: item, restaurantName: widget.restaurant.name),
              ),
            ).then((_) {
              _shouldListen = true;
              _isProcessing = false;
              _announceMenuScreen();
            });
          }
        },
        child: Card(
          elevation: 2,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    item.image,
                    height: 75,
                    width: 75,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 75,
                      width: 75,
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(lp.getText('cat_${item.category.toLowerCase()}'),
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text("${item.price} EGP",
                          style: const TextStyle(
                              color: Color(0xFFEB1B33),
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Icon(lp.isRTL ? Icons.arrow_back_ios : Icons.arrow_forward_ios,
                    size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceHint(AppAudioProvider audio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding:
        const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
            color: const Color(0xFFD6E0E0),
            borderRadius: BorderRadius.circular(30)),
        child: Row(
          children: [
            Icon(Icons.mic,
                color: audio.isListening ? Colors.green : Colors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                audio.isListening && audio.lastWords.isNotEmpty
                    ? audio.lastWords
                    : lp.getText('voice_hint_menu'),
                style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}