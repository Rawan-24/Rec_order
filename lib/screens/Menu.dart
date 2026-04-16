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

  // Optimized Announcement: Stops any lingering audio from previous screens
  void _announceMenu() async {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    await audio.stop(); // Clear the speech queue immediately

    if (lp.isRTL) {
      audio.speak("أهلاً بك في ${widget.restaurant.name}. يمكنك البحث عن الطعام بالصوت.", "ar-EG");
    } else {
      audio.speak("Welcome to ${widget.restaurant.name}. You can search the menu using your voice.", "en-US");
    }
  }

  void _handleVoiceSearch(AppAudioProvider audio) {
    audio.toggleListening(lp.currentLanguage, (words) async {
      String command = words.toLowerCase();
      bool foundCategory = false;

      // Check if command is a category
      for (var cat in categories) {
        if (command.contains(cat.toLowerCase())) {
          setState(() {
            selectedCategory = cat;
            searchQuery = "";
            _filterMenu();
          });
          foundCategory = true;

          String feedback = lp.isRTL ? "عرض قسم $cat" : "Showing $cat";
          audio.speak(feedback, lp.currentLanguage);
          break;
        }
      }

      // If not a category, treat it as a general search
      if (!foundCategory && words.isNotEmpty) {
        setState(() {
          searchQuery = words;
          _filterMenu();
        });
        String searchFeedback = lp.isRTL ? "البحث عن $words" : "Searching for $words";
        audio.speak(searchFeedback, lp.currentLanguage);
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
      body: CustomScrollView(
        slivers: [
          // Using a SliverAppBar for a more professional "Hero" image effect
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: primaryRed,
            leading: CircleAvatar(
              backgroundColor: Colors.white,
              child: IconButton(
                icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back, color: Colors.black),
                onPressed: () async {
                  await audio.stop();
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Image.network(widget.restaurant.image, fit: BoxFit.cover),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.restaurant.name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(widget.restaurant.description, style: const TextStyle(color: Colors.grey, fontSize: 16)),
                  const SizedBox(height: 20),

                  // Voice Assistant Status Bar
                  _buildVoiceHint(audio),

                  const SizedBox(height: 20),

                  // Text Search Backup
                  TextField(
                    onChanged: (value) { searchQuery = value; _filterMenu(); },
                    decoration: InputDecoration(
                      hintText: lp.getText('search_menu'),
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),

                  const SizedBox(height: 20),
                  _buildCategorySlider(primaryRed),
                ],
              ),
            ),
          ),

          // Menu List
          isLoading
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: primaryRed)))
              : displayedMenu.isEmpty
              ? SliverFillRemaining(child: Center(child: Text(lp.getText('no_items_found'))))
              : SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildMenuCard(displayedMenu[index], audio),
              childCount: displayedMenu.length,
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Space for FAB
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: audio.isListening ? Colors.green : primaryRed,
        onPressed: () => _handleVoiceSearch(audio),
        icon: Icon(audio.isListening ? Icons.graphic_eq : Icons.mic, color: Colors.white),
        label: Text(audio.isListening ? (lp.isRTL ? "جاري الاستماع" : "Listening...") : (lp.isRTL ? "تحدث" : "Speak"), style: const TextStyle(color: Colors.white)),
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
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) setState(() { selectedCategory = category; _filterMenu(); });
              },
              selectedColor: primaryRed,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuCard(MenuItemModel item, AppAudioProvider audio) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () async {
          await audio.stop();
          String selectionMsg = lp.isRTL ? "اختيار ${item.name}" : "Selecting ${item.name}";
          audio.speak(selectionMsg, lp.currentLanguage);

          if (mounted) {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => MenuItem(item: item, restaurantName: widget.restaurant.name),
            ));
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(15), bottomLeft: Radius.circular(15)),
                child: Image.network(item.image, height: 100, width: 100, fit: BoxFit.cover),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                      const SizedBox(height: 4),
                      Text(item.category, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 8),
                      Text("${item.price} EGP", style: const TextStyle(color: Color(0xFFEB1B33), fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                ),
              ),
              const Icon(Icons.add_circle, color: Color(0xFFEB1B33), size: 30),
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVoiceHint(AppAudioProvider audio) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(color: Colors.teal.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          Icon(Icons.tips_and_updates, color: Colors.teal[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                audio.isListening && audio.lastWords.isNotEmpty ? audio.lastWords : lp.getText('voice_hint_menu'),
                style: TextStyle(color: Colors.teal[900], fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}