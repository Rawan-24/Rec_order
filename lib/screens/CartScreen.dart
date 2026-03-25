import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:grad_project/Models/CartItem.dart';
import 'package:grad_project/screens/CartProvider.dart';
import 'package:grad_project/screens/PaymentScreen.dart';
//Done
class CartScreen extends StatefulWidget {
  static const String routeName = "CartScreen";

  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {


  // 2. Pricing Constants
  final double deliveryFee = 3.99;
  final double taxRate = 0.08; // 8%

  @override
  Widget build(BuildContext context) {
    // 1. Listen to the CartProvider
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4EDE4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Your Cart", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Voice Hint Section
          _buildVoiceHeader(),

          // Scrollable List of Items
          Expanded(
            child: cart.items.isEmpty
                ? const Center(child: Text("Your cart is empty"))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cart.items.length,
              itemBuilder: (context, index) {
                final item = cart.items[index]; // This is now a CartItem object
                return _buildCartItem(item, cart);
              },
            ),
          ),

          // Bottom Summary Section
          _buildSummarySection(cart),
        ],
      ),
    );
  }

  Widget _buildVoiceHeader() {
    return Column(
      children: [
        const CircleAvatar(
          radius: 30,
          backgroundColor: Color(0xFFEB1B33),
          child: Icon(Icons.mic, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 15),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFD6E0E0),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Row(
              children: [
                Icon(Icons.mic, color: Colors.teal, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text('Say "Remove first item" or "Add more quantity"',
                      style: TextStyle(fontSize: 13, color: Colors.black54)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildCartItem(CartItem item, CartProvider cart) {
    return Card(
      key: ValueKey(item.id),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(item.restaurant, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    Text(item.details, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => cart.removeItem(item.id), // Logic to remove
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    _qtyBtn(Icons.remove, () {
                      if (item.quantity > 1) cart.updateQuantity(item.id, item.quantity - 1);
                    }),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Text("${item.quantity}", style: const TextStyle(fontSize: 16)),
                    ),
                    _qtyBtn(Icons.add, () => cart.updateQuantity(item.id, item.quantity + 1)),
                  ],
                ),
                Text(
                  "\$${(item.price * item.quantity).toStringAsFixed(2)}",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFEB1B33)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
  Widget _qtyBtn(IconData icon, VoidCallback tap) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.grey[200], shape: BoxShape.circle),
        child: Icon(icon, size: 20, color: Colors.black),
      ),
    );
  }

  Widget _buildSummarySection(CartProvider cart) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [

          _summaryRow("Subtotal", cart.subtotal),
          _summaryRow("Delivery Fee", cart.deliveryFee),
          _summaryRow("Tax", cart.tax),
          const Divider(),
          _summaryRow("Total", cart.total, isBold: true),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEB1B33),
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () {
              // Navigate to CheckOut
              Navigator.push(context, MaterialPageRoute(builder: (context) => PaymentScreen()));
            },
            child: const Text("Proceed to Checkout", style: TextStyle(color: Colors.white, fontSize: 18)),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text("\$${value.toStringAsFixed(2)}",
              style: TextStyle(fontSize: 16, fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: isBold ? const Color(0xFFEB1B33) : Colors.black)),
        ],
      ),
    );
  }
}
