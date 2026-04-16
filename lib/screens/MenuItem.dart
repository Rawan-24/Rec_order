import 'package:flutter/material.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/Models/CartItem.dart';
import 'package:grad_project/screens/CartProvider.dart'; // Ensure this path is correct
import 'package:grad_project/Models/MenuItemModel.dart';
import 'package:grad_project/screens/CartScreen.dart';

class MenuItem extends StatefulWidget {
  final String restaurantName;
  final MenuItemModel item;
  const MenuItem({super.key, required this.item, required this.restaurantName});

  static const String routeName = "MenuItem";
  @override
  State<MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<MenuItem> {
  // Use 'late' carefully; it is initialized in didChangeDependencies
  late LanguageProvider lp;
  String selectedSize = 'Medium';
  int quantity = 1;
  Set<String> selectedAddOns = {};

  @override
  void initState() {
    super.initState();
    // Start announcement after the first frame to ensure context is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _announceItem();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize lp here so it updates if the language changes
    lp = Provider.of<LanguageProvider>(context);
  }

  void _announceItem() async {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Stop any previous speech (like the menu selection audio)
    await audio.stop();

    if (lp.isRTL) {
      audio.speak("لقد اخترت ${widget.item.name}. السعر يبدأ من ${widget.item.price} جنيه مصري. هل تود إضافة أي شيء؟", "ar-EG");
    } else {
      audio.speak("You selected ${widget.item.name}. Price starts at ${widget.item.price} EGP. Would you like to add anything?", "en-US");
    }
  }

  void _handleVoiceSelection(AppAudioProvider audio) {
    audio.toggleListening(lp.currentLanguage, (words) async {
      String command = words.toLowerCase();

      // Size Selection Logic
      if (command.contains("small") || command.contains("صغير")) {
        setState(() => selectedSize = 'Small');
        audio.speak(lp.isRTL ? "تم اختيار الحجم الصغير" : "Selected small size", lp.currentLanguage);
      } else if (command.contains("medium") || command.contains("متوسط")) {
        setState(() => selectedSize = 'Medium');
        audio.speak(lp.isRTL ? "تم اختيار الحجم المتوسط" : "Selected medium size", lp.currentLanguage);
      } else if (command.contains("large") || command.contains("كبير")) {
        setState(() => selectedSize = 'Large');
        audio.speak(lp.isRTL ? "تم اختيار الحجم الكبير" : "Selected large size", lp.currentLanguage);
      }

      // Add-ons Detection Logic
      for (var addon in widget.item.availableAddOns.keys) {
        if (command.contains(addon.toLowerCase())) {
          setState(() {
            if (selectedAddOns.contains(addon)) {
              selectedAddOns.remove(addon);
              _announceAddonStatus(audio, addon, false);
            } else {
              selectedAddOns.add(addon);
              _announceAddonStatus(audio, addon, true);
            }
          });
        }
      }

      // Confirmation Command
      if (command.contains("add to cart") || command.contains("أضف للسلة") || command.contains("confirm") || command.contains("تأكيد")) {
        _addToCart();
      }
    });
  }

  void _announceAddonStatus(AppAudioProvider audio, String addon, bool added) async {
    if (lp.isRTL) {
      // Combines Arabic instruction with the (likely English) addon name
      audio.speak(added ? "تمت إضافة $addon" : "تم حذف $addon", "ar-EG");
    } else {
      audio.speak("${added ? 'Added' : 'Removed'} $addon", "en-US");
    }
  }

  void _addToCart() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    // Stop current listening/speaking before moving screens
    await audio.stop();

    cart.addItem(CartItem(
      id: DateTime.now().toString(),
      name: widget.item.name,
      restaurant: widget.restaurantName,
      details: "${lp.getText('size_${selectedSize.toLowerCase()}')} • ${selectedAddOns.join(', ')}",
      price: totalPrice / quantity, // Calculate unit price for the cart model
      quantity: quantity,
      image: widget.item.image,
    ));

    audio.speak(lp.isRTL ? "تمت الإضافة للسلة" : "Added to cart", lp.currentLanguage);

    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
    }
  }

  double get totalPrice {
    double total = widget.item.price;
    if (selectedSize == 'Large') total += 50.0;
    for (var addon in selectedAddOns) {
      total += widget.item.availableAddOns[addon] ?? 0.0;
    }
    return total * quantity;
  }

  @override
  Widget build(BuildContext context) {
    final audio = Provider.of<AppAudioProvider>(context);
    const primaryRed = Color(0xFFEB1B33);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Image.network(widget.item.image, height: 300, width: double.infinity, fit: BoxFit.cover),
                Positioned(
                  top: 40,
                  left: lp.isRTL ? null : 20,
                  right: lp.isRTL ? 20 : null,
                  child: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: IconButton(
                        icon: Icon(lp.isRTL ? Icons.arrow_forward : Icons.arrow_back, color: Colors.black),
                        onPressed: () async {
                          await audio.stop();
                          if (mounted) Navigator.pop(context);
                        }
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  right: lp.isRTL ? null : 20,
                  left: lp.isRTL ? 20 : null,
                  child: FloatingActionButton(
                    backgroundColor: audio.isListening ? Colors.green : primaryRed,
                    onPressed: () => _handleVoiceSelection(audio),
                    child: Icon(audio.isListening ? Icons.graphic_eq : Icons.mic, color: Colors.white),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.item.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("${widget.item.price.toStringAsFixed(2)} EGP", style: const TextStyle(fontSize: 22, color: primaryRed, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(widget.item.description, style: const TextStyle(color: Colors.black54, fontSize: 15)),

                  const SizedBox(height: 30),
                  Text(lp.getText('select_size'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['Small', 'Medium', 'Large'].map((size) => _buildSizeButton(size)).toList(),
                  ),

                  const SizedBox(height: 30),
                  Text(lp.getText('add_ons'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ...widget.item.availableAddOns.keys.map((addon) => _buildAddOnTile(addon, widget.item.availableAddOns[addon]!)),

                  const SizedBox(height: 30),
                  Text(lp.getText('quantity'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  _buildQuantitySelector(primaryRed),
                  const SizedBox(height: 120), // Added bottom spacing for the bottomSheet
                ],
              ),
            )
          ],
        ),
      ),
      bottomSheet: _buildBottomBar(),
    );
  }

  Widget _buildQuantitySelector(Color primaryRed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
            onPressed: () => setState(() { if(quantity > 1) quantity--; }),
            icon: const Icon(Icons.remove_circle_outline, size: 30)
        ),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
            child: Text("$quantity", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))
        ),
        IconButton(
            onPressed: () => setState(() => quantity++),
            icon: Icon(Icons.add_circle_outline, color: primaryRed, size: 30)
        ),
      ],
    );
  }

  Widget _buildSizeButton(String size) {
    bool isSelected = selectedSize == size;
    return GestureDetector(
      onTap: () => setState(() => selectedSize = size),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: MediaQuery.of(context).size.width * 0.28,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEB1B33) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Colors.transparent : Colors.grey[300]!),
          boxShadow: isSelected ? [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
        ),
        child: Column(
          children: [
            Text(lp.getText('size_${size.toLowerCase()}'), style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
            if (size == 'Large') Text("+50 EGP", style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildAddOnTile(String name, double price) {
    bool isSelected = selectedAddOns.contains(name);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedAddOns.remove(name);
          } else {
            selectedAddOns.add(name);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEB1B33).withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? const Color(0xFFEB1B33) : Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank, color: isSelected ? const Color(0xFFEB1B33) : Colors.grey),
                const SizedBox(width: 12),
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              ],
            ),
            Text("+${price.toStringAsFixed(2)} EGP", style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20))
      ),
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 30),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEB1B33),
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 0,
        ),
        onPressed: _addToCart,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
                children: [
                  const Icon(Icons.shopping_basket, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(lp.getText('add_to_cart'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
                ]
            ),
            Text("${totalPrice.toStringAsFixed(2)} EGP", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}