import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/Models/MenuItemModel.dart';
import 'package:grad_project/Models/Restaurant.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:grad_project/screens/MenuItem.dart';
import 'package:provider/provider.dart';

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

  void _loadMenu() async {
    List<MenuItemModel> items = await _dbService.getRestaurantMenu(widget.restaurant.id!);
    if (mounted) {
      setState(() {
        fullMenu = items;
        displayedMenu = items;
        isLoading = false;
      });
      _announceMenu();
    }
  }

  // UPDATED: Added a stop call to clear the queue before starting
  void _announceMenu() async {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Stop any previous speech (like the restaurant selection audio)
    // so it doesn't fight with this new announcement.
    await audio.stop();

    if (lp.isRTL) {
      await audio.speak("أهلاً بك في", "ar-EG");
      await Future.delayed(const Duration(milliseconds: 300));
      await audio.speak(widget.restaurant.name, "en-US");
      await Future.delayed(const Duration(milliseconds: 300));
      await audio.speak("يمكنك البحث عن الطعام بالصوت.", "ar-EG");
    } else {
      await audio.speak("Welcome to ${widget.restaurant.name}. You can search the menu using your voice.", "en-US");
    }
  }

  void _handleVoiceSearch(AppAudioProvider audio) {
    audio.toggleListening(lp.currentLanguage, (words) async {
      String command = words.toLowerCase();
      bool foundCategory = false;

      for (var cat in categories) {
        if (command.contains(cat.toLowerCase())) {
          setState(() {
            selectedCategory = cat;
            searchQuery = "";
            _filterMenu();
          });
          foundCategory = true;

          if (lp.isRTL) {
            await audio.speak("عرض قسم", "ar-EG");
            await audio.speak(cat, "en-US");
          } else {
            await audio.speak("Showing $cat", "en-US");
          }
          break;
        }
      }

      if (!foundCategory && words.isNotEmpty) {
        setState(() {
          searchQuery = words;
          _filterMenu();
        });
        if (lp.isRTL) {
          await audio.speak("البحث عن", "ar-EG");
          await audio.speak(words, "en-US");
        } else {
          await audio.speak("Searching for $words", "en-US");
        }
      }
    });
  }

  void _filterMenu() {
    setState(() {
      displayedMenu = fullMenu.where((item) {
        final matchesCategory = selectedCategory == "All" || item.category == selectedCategory;
        final matchesSearch = item.name.toLowerCase().contains(searchQuery.toLowerCase());
        return matchesCategory && matchesSearch;
      }).toList();
    });
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
              Image.network(widget.restaurant.image, height: 220, width: double.infinity, fit: BoxFit.cover),
              Positioned(
                top: 40,
                left: lp.isRTL ? null : 10,
                right: lp.isRTL ? 10 : null,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                      icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back),
                      onPressed: () async {
                        await audio.stop(); // Stop speaking if the user leaves
                        if(context.mounted) Navigator.pop(context);
                      }
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: MediaQuery.of(context).size.width / 2 - 30,
                child: FloatingActionButton(
                  backgroundColor: audio.isListening ? Colors.green : primaryRed,
                  onPressed: () => _handleVoiceSearch(audio),
                  child: Icon(audio.isListening ? Icons.graphic_eq : Icons.mic, color: Colors.white),
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
                Text(widget.restaurant.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.restaurant.description, style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _buildVoiceHint(audio),
          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (value) { searchQuery = value; _filterMenu(); },
              decoration: InputDecoration(
                hintText: lp.getText('search_menu'),
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),

          const SizedBox(height: 20),
          _buildCategorySlider(primaryRed),
          const SizedBox(height: 16),

          isLoading
              ? const Center(child: CircularProgressIndicator(color: primaryRed))
              : displayedMenu.isEmpty
              ? Center(child: Text(lp.getText('no_items_found')))
              : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedMenu.length,
            itemBuilder: (context, index) => _buildMenuCard(displayedMenu[index], audio),
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
              onPressed: () { setState(() { selectedCategory = category; _filterMenu(); }); },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
          await audio.stop(); // Stop current speech before navigating
          if (lp.isRTL) {
            await audio.speak("اختيار", "ar-EG");
            await audio.speak(item.name, "en-US");
          } else {
            await audio.speak("Selecting ${item.name}", "en-US");
          }

          if (mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => MenuItem(item: item, restaurantName: widget.restaurant.name),
            ));
          }
        },
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(item.image, height: 75, width: 75, fit: BoxFit.cover),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(lp.getText('cat_${item.category.toLowerCase()}'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 6),
                      Text("${item.price} EGP", style: const TextStyle(color: Color(0xFFEB1B33), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Icon(lp.isRTL ? Icons.arrow_back_ios : Icons.arrow_forward_ios, size: 16, color: Colors.grey),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(color: const Color(0xFFD6E0E0), borderRadius: BorderRadius.circular(30)),
        child: Row(
          children: [
            Icon(Icons.mic, color: audio.isListening ? Colors.green : Colors.teal),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  audio.isListening && audio.lastWords.isNotEmpty ? audio.lastWords : lp.getText('voice_hint_menu'),
                  style: const TextStyle(color: Colors.black54, fontSize: 13, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }
}