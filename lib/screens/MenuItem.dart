import 'package:flutter/material.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:grad_project/providers/AudioProvider.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/Models/CartItem.dart';
import 'package:grad_project/screens/CartProvider.dart';
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
  late LanguageProvider lp;
  String selectedSize = 'Medium';
  int quantity = 1;
  Set<String> selectedAddOns = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { _announceItem(); });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    lp = Provider.of<LanguageProvider>(context);
  }

  void _announceItem() async {
    final audio = Provider.of<AppAudioProvider>(context, listen: false);
    if (lp.isRTL) {
      await audio.speak("لقد اخترت", "ar-EG");
      await audio.speak(widget.item.name, "en-US");
      await audio.speak("السعر يبدأ من ${widget.item.price} جنيه مصري. هل تود إضافة أي شيء؟", "ar-EG");
    } else {
      audio.speak("You selected ${widget.item.name}. Price starts at ${widget.item.price} EGP. Would you like to add anything?", "en-US");
    }
  }

  void _handleVoiceSelection(AppAudioProvider audio) {
    audio.toggleListening(lp.currentLanguage, (words) async {
      String command = words.toLowerCase();

      if (command.contains("small") || command.contains("صغير")) {
        setState(() => selectedSize = 'Small');
        await audio.speak(lp.isRTL ? "تم اختيار الحجم الصغير" : "Selected small size", lp.currentLanguage);
      } else if (command.contains("medium") || command.contains("متوسط")) {
        setState(() => selectedSize = 'Medium');
        await audio.speak(lp.isRTL ? "تم اختيار الحجم المتوسط" : "Selected medium size", lp.currentLanguage);
      } else if (command.contains("large") || command.contains("كبير")) {
        setState(() => selectedSize = 'Large');
        await audio.speak(lp.isRTL ? "تم اختيار الحجم الكبير" : "Selected large size", lp.currentLanguage);
      }

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

      if (command.contains("add to cart") || command.contains("أضف للسلة") || command.contains("confirm")) {
        _addToCart();
      }
    });
  }

  void _announceAddonStatus(AppAudioProvider audio, String addon, bool added) async {
    if (lp.isRTL) {
      await audio.speak(added ? "تمت إضافة" : "تم حذف", "ar-EG");
      await audio.speak(addon, "en-US");
    } else {
      audio.speak("${added ? 'Added' : 'Removed'} $addon", "en-US");
    }
  }

  void _addToCart() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final audio = Provider.of<AppAudioProvider>(context, listen: false);

    cart.addItem(CartItem(
      id: DateTime.now().toString(),
      name: widget.item.name,
      restaurant: widget.restaurantName,
      details: "${lp.getText('size_${selectedSize.toLowerCase()}')} • ${selectedAddOns.join(', ')}",
      price: totalPrice / quantity,
      quantity: quantity,
      image: widget.item.image,
    ));

    audio.speak(lp.isRTL ? "تمت الإضافة للسلة" : "Added to cart", lp.currentLanguage);
    Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen()));
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
                    backgroundColor: const Color(0xFFF4EDE4),
                    child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
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
                  Text(widget.item.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("${widget.item.price.toStringAsFixed(2)} EGP", style: const TextStyle(fontSize: 20, color: primaryRed, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(widget.item.description, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 25),
                  Text(lp.getText('select_size'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['Small', 'Medium', 'Large'].map((size) => _buildSizeButton(size)).toList(),
                  ),
                  const SizedBox(height: 25),
                  Text(lp.getText('add_ons'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ...widget.item.availableAddOns.keys.map((addon) => _buildAddOnTile(addon, widget.item.availableAddOns[addon]!)),
                  const SizedBox(height: 25),
                  Text(lp.getText('quantity'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  _buildQuantitySelector(primaryRed),
                  const SizedBox(height: 100),
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
        IconButton(onPressed: () => setState(() { if(quantity > 1) quantity--; }), icon: const Icon(Icons.remove_circle_outline)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)), child: Text("$quantity", style: const TextStyle(fontSize: 18))),
        IconButton(onPressed: () => setState(() => quantity++), icon: Icon(Icons.add_circle_outline, color: primaryRed)),
      ],
    );
  }

  Widget _buildSizeButton(String size) {
    bool isSelected = selectedSize == size;
    return GestureDetector(
      onTap: () => setState(() => selectedSize = size),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEB1B33) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
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
      onTap: () => setState(() => isSelected ? selectedAddOns.remove(name) : selectedAddOns.add(name)),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEB1B33).withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFFEB1B33) : Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text("+${price.toStringAsFixed(2)} EGP", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.black12, width: 0.5))),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFEB1B33),
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        onPressed: _addToCart,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [const Icon(Icons.shopping_cart_outlined, color: Colors.white), const SizedBox(width: 10), Text(lp.getText('add_to_cart'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
            Text("${totalPrice.toStringAsFixed(2)} EGP", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}