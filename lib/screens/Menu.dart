import 'package:flutter/material.dart';
import 'package:grad_project/DatabaseService.dart';
import 'package:grad_project/Models/MenuItemModel.dart';
import 'package:grad_project/Models/Restaurant.dart';
import 'package:grad_project/screens/MenuItem.dart';
//Done
class Menu extends StatefulWidget {

  static const String routeName = "Menu";

  final Restaurant restaurant;

  const Menu({
    super.key,
    required this.restaurant,

  });
  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  // 1. Full Data Source
final DatabaseService _dbService = DatabaseService(); // Add this
  final List<String> categories = ["All", "Pizza", "Pasta", "Salads", "Drinks"];

  // 2. State variables for filtering
  List<MenuItemModel> fullMenu = [];
  List<MenuItemModel> displayedMenu = [];
  String selectedCategory = "All";
  String searchQuery = "";
bool isLoading = true;

  @override
  void initState() {
    super.initState();
_loadMenu();
    fullMenu = widget.restaurant.menu;
    displayedMenu = fullMenu;
  }
void _loadMenu() async {
    // 1. Fetch from Firestore using the ID of the restaurant passed to this screen
    List<MenuItemModel> items = await _dbService.getRestaurantMenu(widget.restaurant.id!);
    
    // 2. Update the UI
    setState(() {
      fullMenu = items;
      displayedMenu = items;
      isLoading = false;
    });
  }
  // 3. Logic to filter both by Search and Category
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      body: ListView(
        children: [
          /// Top Image Section
          Stack(
            clipBehavior: Clip.none,
            children: [
              Image.network(
                widget.restaurant.image,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 40,
                left: 10,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: MediaQuery.of(context).size.width / 2 - 30,
                child: FloatingActionButton(
                  backgroundColor: const Color(0xFFEB1B33),
                  onPressed: () {},
                  child: const Icon(Icons.mic, color: Colors.black),
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          /// Restaurant Info
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

          /// Voice Hint
          _buildVoiceHint(),

          const SizedBox(height: 20),

          /// Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (value) {
                searchQuery = value;
                _filterMenu();
              },
              decoration: InputDecoration(
                hintText: "Search menu items",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          /// Category Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((category) {
                bool isSelected = selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(left: 16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      selectedCategory = category;
                      _filterMenu();
                    },
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      backgroundColor: isSelected ? const Color(0xFFEB1B33) : Colors.white,
                      foregroundColor: isSelected ? Colors.white : Colors.black,
                      elevation: 2,
                    ),
                    child: Text(category),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 16),

          /// Menu List
         isLoading 
  ? const Center(child: CircularProgressIndicator(color: Color(0xFFEB1B33)))
  : displayedMenu.isEmpty 
    ? const Center(child: Text("No items found"))
    : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedMenu.length,
            itemBuilder: (context, index) {
              var item = displayedMenu[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: GestureDetector(
                  onTap: () {
                    // Navigate to MenuItem screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MenuItem(item: item,),
                      ),
                    );
                  },
                  child: Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              item.image,
                              height: 70, width: 70, fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(item.category, overflow: TextOverflow.ellipsis, maxLines: 1),
                                const SizedBox(height: 4),
                                Text("\$${item.price}", style: const TextStyle(color: Color(0xFFEB1B33), fontWeight: FontWeight.bold)),
                              ],

                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildVoiceHint() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFD6E0E0),
          borderRadius: BorderRadius.circular(30),
        ),
        child: const Row(
          children: [
            Icon(Icons.mic, color: Colors.teal),
            SizedBox(width: 10),
            Expanded(
              child: Text('Say "Add Margherita pizza" or tap an item',
                  style: TextStyle(color: Colors.black54, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}