import 'package:flutter/material.dart';
import 'package:grad_project/providers/LanguageProvider.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/Models/CartItem.dart';
import 'package:grad_project/screens/CartProvider.dart';
import 'package:grad_project/Models/MenuItemModel.dart';
import 'package:grad_project/screens/CartScreen.dart';

//Done
class MenuItem extends StatefulWidget {
  final String restaurantName;
  final MenuItemModel item;
  const MenuItem({super.key, required this.item, required this.restaurantName});

  static const String routeName="MenuItem";
  @override
  State<MenuItem> createState() => _MenuItem();
}

class _MenuItem extends State<MenuItem> {
  late LanguageProvider lp; // Declare it here

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This runs whenever the context is ready or changes
    lp = Provider.of<LanguageProvider>(context);
  }
  // Data State
  double basePrice = 12.99;
  String selectedSize = 'Medium';
  int quantity = 1;


  Set<String> selectedAddOns = {};

  double get totalPrice {
    double total = widget.item.price; // Use price from RestaurantData

    if (selectedSize == 'Large') total += 3.0;

    for (var addon in selectedAddOns) {
      // Get price from the item's specific add-on map
      total += widget.item.availableAddOns[addon] ?? 0.0;
    }

    return total * quantity;
  }

  @override
  Widget build(BuildContext context) {
    final lp = Provider.of<LanguageProvider>(context);
    return Scaffold(
      backgroundColor: Color(0xFFF4EDE4),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image Section
            Stack(
              children: [
                Image.network(
                  widget.item.image,
                  height: 300,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Positioned(top: 40, left: 20, child: CircleAvatar(
                    backgroundColor: Color(0xFFF4EDE4),
                    child: IconButton(icon: Icon(Icons.arrow_back, color: Colors.black),
                      onPressed: () {

                        Navigator.pop(context);
                      },
                    ))),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.item.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("\$${widget.item.price.toStringAsFixed(2)}", style: const TextStyle(
                      fontSize: 20, color:  Color(0xFFEB1B33), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(widget.item.description, style: const TextStyle(color: Colors.grey)),

                  const SizedBox(height: 25),

                  // Size Selection
                  Text(lp.getText('select_size'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['Small', 'Medium', 'Large'].map((size) => _buildSizeButton(size)).toList(),
                  ),

                  const SizedBox(height: 25),

                  // Add-ons Selection
                  Text(lp.getText('add_ons'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ...widget.item.availableAddOns.keys.map((addon) =>
                      _buildAddOnTile(addon, widget.item.availableAddOns[addon]!)
                  ),

                  const SizedBox(height: 25),

                  // Quantity
                   Text(lp.getText('quantity'),style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(onPressed: () => setState(() { if(quantity > 1) quantity--; }), icon: const Icon(Icons.remove_circle_outline)),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(10)), child: Text("$quantity", style: const TextStyle(fontSize: 18))),
                      IconButton(onPressed: () => setState(() => quantity++), icon: const Icon(Icons.add_circle_outline, color:  Color(0xFFEB1B33))),
                    ],
                  ),
                  const SizedBox(height: 100), // Space for bottom bar
                ],
              ),
            )
          ],
        ),
      ),
      bottomSheet: _buildBottomBar(),
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
          color: isSelected ?  Color(0xFFEB1B33): Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          children: [
            Text(lp.getText('size_${size.toLowerCase()}'), style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
            if (size == 'Large') Text("+\$3", style: TextStyle(color: isSelected ? Colors.white70 : Colors.grey, fontSize: 12)),
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
          color: isSelected ? Colors.deepPurple.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ?  Color(0xFFEB1B33) : Colors.grey[200]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text("+\$${price.toStringAsFixed(2)}", style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
  Widget _buildBottomBar() {
    return ConstrainedBox(
      // This line overrides Flutter Web's default centering/width limits
      constraints: const BoxConstraints(minWidth: double.infinity),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black12, width: 0.5)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 25),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEB1B33),
            minimumSize: const Size(double.infinity, 60),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 0,
          ),
          onPressed: () {

            // Logic to save the actual selection to the backend
            final cart = Provider.of<CartProvider>(context, listen: false);
            print("DEBUG: Adding item from restaurant: ${cart.currentRestaurant}"); // or whatever your variable is
            print("DEBUG: Item name: ${widget.item.name}");
            cart.addItem(CartItem(

              id: DateTime.now().toString(),
              name: widget.item.name, // You can pass this via constructor later
           restaurant: widget.restaurantName,
              details: "${lp.getText('size_${selectedSize.toLowerCase()}')} • ${selectedAddOns.join(', ')}",
              price: totalPrice / quantity, // Base price per item
              quantity: quantity, image: '',
            ));
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const CartScreen()),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                  lp.getText('add_to_cart'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                "\$${totalPrice.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
